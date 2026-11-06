class_name Playthrough
extends RefCounted
## Simulated playthroughs: a rule-based bot drives the simulation core (HorrorRuntime on a HorrorStage,
## no physics, no rendering) from the start card to an ending. These are bots, not people; their results
## are never reported as human playtests.
##
##   explorer  investigates every suspicious event, reads everything, lights every room, knocks back
##   avoider   moves away from suspicious sounds and keeps out of dark rooms; follows an objective only
##             once it has been stuck on it for a while; runs for the lift
##   passive   waits; every minute takes one step towards the objective; rarely interacts
##
## run(profile, seed, road_ending) returns the record the brief asks for: event sequence and count, director scores,
## progression, completion and the errors/warnings logged during the run.

const DT := 0.1
const WALK := 2.2
const LIMIT := 40.0 * 60.0  # sim seconds before we call it stuck
const RELUCTANCE := 45.0  # avoider: seconds on an objective before it gives in
const PASSIVE_STEP := 60.0
## From the bedroom end of the long corridor to the B-11-07 end.
const GAP_LOOP: Array[Vector3] = [Vector3(7.72, 0, -2.7), Vector3(-1.3, 0, -2.7), Vector3(-1.3, 0, -8.7), Vector3(7.72, 0, -8.7)]


class Catch extends Logger:
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		var text := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
		if error_type == ERROR_TYPE_WARNING:
			warnings.append(text)
		else:
			errors.append(text)

	func _log_message(_message: String, _error: bool) -> void:
		pass


var profile: String
var rt: HorrorRuntime
var stage: HorrorStage
var rng := RandomNumberGenerator.new()  # the bot's own choices, apart from the simulation RNG
var actions: Array[Dictionary] = []  # {"go": Vector3} / {"use": id} / {"wait": s} / {"turn": rad}
var objects := {}  # id -> [pos, requires, has_text]
var read := {}
var sound_room: StringName = &""
var sound_at := -INF
var events: Array[Dictionary] = []
var decisions: Array[Dictionary] = []
var violations: Array[String] = []
var heard_last_call := false  # the intercom's last call went out (only after some roads of the road)
var heard_look_back := false  # the look-back line was said
var _next_turn := 8.0
var _passive_next := PASSIVE_STEP


## `road_ending` is how the road ended (&"" = the flat opened directly). Journey carries it for the run, because the
## story reads it as it is created; the old value is put back afterwards.
static func run(profile_name: String, seed_value: int, road_ending: StringName = &"") -> Dictionary:
	var was := Journey.road_ending
	Journey.road_ending = road_ending
	var result := Playthrough.new()._run(profile_name, seed_value)
	Journey.road_ending = was
	result["road"] = road_ending
	return result


func _run(profile_name: String, seed_value: int) -> Dictionary:
	profile = profile_name
	rng.seed = seed_value * 31 + profile.hash()
	WorldState.reset()
	ApartmentLayout.apply_initial_state()
	stage = HorrorStage.new(RoomGraph.new(WorldState.variants))
	stage.position = ApartmentLayout.SPAWN
	WorldState.set_player_room(ApartmentLayout.room_at(stage.position, WorldState.variants))
	rt = HorrorRuntime.new()
	rt.setup(stage, seed_value)
	for o: Array in ApartmentBuilder.OBJECTS:
		objects[o[0]] = [o[1], o[6] if o.size() > 6 else {}, o[5] != ""]
	var catch := Catch.new()
	OS.add_logger(catch)
	rt.scheduler.run_started.connect(_on_run_started)
	rt.scheduler.run_finished.connect(func(r: Dictionary) -> void:
		events.append({"t": snappedf(WorldState.time, 0.1), "id": r["id"], "room": r["room"], "result": RESULT_NAMES[r["state"]], "priority": r["priority"]}))
	rt.director.decided.connect(func(d: Dictionary) -> void: decisions.append(d))
	rt.start_story()
	EventBus.sound_requested.connect(_on_sound)
	EventBus.line_requested.connect(_on_line)

	var max_eval := 0
	while WorldState.ending == &"" and WorldState.time < LIMIT:
		_act(DT)
		rt.step(DT)
		max_eval = maxi(max_eval, rt.director.max_eval_usec)
		if WorldState.entity_room != &"" and WorldState.entity_room == WorldState.player_room and WorldState.entity_state != &"retreating":
			violations.append("entity in the player's room at %.1fs" % WorldState.time)
	OS.remove_logger(catch)
	EventBus.sound_requested.disconnect(_on_sound)
	EventBus.line_requested.disconnect(_on_line)
	var result := {
		"profile": profile, "seed": seed_value, "ending": WorldState.ending, "time": snappedf(WorldState.time, 0.1),
		"events": events, "decisions": decisions, "progress": rt.story.progress, "signs": rt.story.signs(),
		"clues": WorldState.clues.keys(), "errors": catch.errors, "warnings": catch.warnings,
		"violations": violations, "max_eval_usec": max_eval, "behavior": rt.profiler.summary(),
		"last_call": heard_last_call, "look_back": heard_look_back,
	}
	rt.free()
	return result


const RESULT_NAMES := {3: "completed", 4: "cancelled", 5: "failed"}


# ── moving ────────────────────────────────────────────────────────────────────────────────────────

func _act(dt: float) -> void:
	stage.speed = 0.0
	if actions.is_empty():
		_decide()
		if actions.is_empty():
			return
	var a: Dictionary = actions[0]
	if a.has("wait"):
		a["wait"] -= dt
		if a["wait"] <= 0.0:
			actions.pop_front()
	elif a.has("turn"):
		stage.yaw += a["turn"]
		actions.pop_front()
	elif a.has("use"):
		actions.pop_front()
		if _exists(a["use"]):
			read[a["use"]] = true
			EventBus.object_interacted.emit(a["use"])
	elif a.has("go"):
		var target: Vector3 = a["go"]
		var to := Vector3(target.x - stage.position.x, 0, target.z - stage.position.z)
		var step := WALK * dt
		if a.has("door") and to.length() < 1.0:
			WorldState.set_door(a["door"], true, &"player")  # like a player, it opens doors it walks through
		if to.length() <= step:
			stage.position = Vector3(target.x, 0, target.z)
			actions.pop_front()
		else:
			stage.position += to.normalized() * step
			stage.yaw = atan2(-to.x, -to.z)
			stage.speed = WALK
		var room := ApartmentLayout.room_at(stage.position, WorldState.variants)
		if room != &"":
			WorldState.set_player_room(room)
			if profile != "passive" and not WorldState.is_light_on(room) and ApartmentLayout.LIGHTS.get(room, {}).get("switch") != null:
				WorldState.set_light(room, true)  # explorers light rooms; avoiders only enter lit ones


## Queues a walk along the room graph to a point (through doorways, round the long corridor).
func _go(target: Vector3) -> void:
	var here := WorldState.player_room
	var dest := ApartmentLayout.room_at(target, WorldState.variants)
	var rooms := rt.graph.path(here, dest)
	if rooms.is_empty():
		return
	var long := WorldState.get_variant(&"gap") == &"long"
	for i in rooms.size() - 1:
		var a: StringName = rooms[i]
		var b: StringName = rooms[i + 1]
		if a == &"gap" and long:
			_loop(b == &"bedroom")  # walk round the long corridor before leaving it
		var c := rt.graph.connection(a, b)
		actions.append({"go": c["pos"], "door": c["door"]} if c["door"] != &"" else {"go": c["pos"]})
	if dest == &"gap" and long and rooms.size() >= 2:
		_loop(rooms[-2] == &"mirror_room")
	actions.append({"go": target})


func _loop(towards_bedroom: bool) -> void:
	var pts := GAP_LOOP.duplicate()
	if towards_bedroom:
		pts.reverse()
	for p: Vector3 in pts:
		actions.append({"go": p})


func _go_room(room_id: StringName) -> void:
	_go(ApartmentLayout.LIFT_POS if room_id == &"corridor" and WorldState.act == WorldState.Act.DECISION else ApartmentLayout.room_center(room_id, WorldState.variants))


func _use(id: StringName) -> void:
	var pos: Vector3 = objects[id][0]
	_go(Vector3(pos.x, 0, pos.z))
	actions.append({"use": id})


func _exists(id: StringName) -> bool:
	return ApartmentLayout.requires_met(objects[id][1], WorldState.variants)


func _on_sound(id: StringName, _pos: Vector3, _db: float) -> void:
	heard_last_call = heard_last_call or id == &"intercom_road"


func _on_line(text: String, _seconds: float) -> void:
	heard_look_back = heard_look_back or text == StoryDirector.REVERSAL


func _on_run_started(run: Dictionary) -> void:
	if run["room"] != &"" and run["id"] != &"shift":
		sound_room = run["room"]
		sound_at = WorldState.time


# ── deciding ──────────────────────────────────────────────────────────────────────────────────────

func _decide() -> void:
	match profile:
		"explorer":
			_explorer()
		"avoider":
			_avoider()
		"passive":
			_passive()


func _story_action() -> bool:
	var s := rt.story
	match s.beat:
		&"home":
			_use(&"bed" if WorldState.has_flag(&"washed") else &"sink")
			return true
		&"ringing":
			if rt.scheduler.is_running(&"phone_ring"):
				_use(&"intercom")
				return true
		&"knocked":
			_use(&"bedroom_wall")
			return true
		&"front_door", &"reveal_pending":
			_go_room(&"entrance")
			return true
		&"revealed":
			_go_room(&"gap")
			return true
		&"in_gap":
			_go_room(&"mirror_room")
			return true
		&"decision":
			if rt.scheduler.is_running(&"phone_ring") and not WorldState.has_flag(&"answered_mirror"):
				_use(&"intercom_mirror")
				return true
			if profile == "explorer" and not WorldState.has_flag(&"answered_mirror") and s.beat_time() < 40.0:
				actions.append({"wait": 1.0})  # it wants to hear the call before choosing
				return true
			_use(&"lift_button" if profile == "avoider" else &"mirror_wall")
			return true
	return false


func _notice_visible() -> bool:
	for id: StringName in StoryDirector.NOTICE:
		if _exists(id) and stage.can_see(objects[id][0]):
			_use(id)
			return true
	return false


func _explorer() -> void:
	if WorldState.time >= _next_turn:
		_next_turn = WorldState.time + 8.0 + rng.randf() * 6.0
		actions.append({"turn": PI})  # a look over the shoulder
	if sound_room != &"" and WorldState.time - sound_at < 15.0 and sound_room != WorldState.player_room:
		var r := sound_room
		sound_room = &""
		_go_room(r)  # investigate every suspicious event
		actions.append({"wait": 2.0})
		return
	if _notice_visible() or _story_action():
		return
	var unread: Array = objects.keys().filter(func(id: StringName) -> bool:
		return objects[id][2] and not read.has(id) and _exists(id) and rt.graph.is_reachable(WorldState.player_room, ApartmentLayout.room_at(objects[id][0], WorldState.variants)))
	if not unread.is_empty() and WorldState.act >= WorldState.Act.DISTURBANCE:
		unread.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
		_use(unread[rng.randi() % unread.size()])
		return
	if WorldState.has_flag(&"answered_intercom") and not WorldState.clues.has(&"own_unit"):
		_use(&"intercom")
		return
	var rooms := rt.graph.rooms_within(WorldState.player_room, 2)
	_go_room(rooms[rng.randi() % rooms.size()])
	actions.append({"wait": 3.0})


func _avoider() -> void:
	var here := WorldState.player_room
	if sound_room != &"" and WorldState.time - sound_at < 10.0 and rt.graph.distance(here, sound_room) <= 1:
		var away := _farthest_lit(sound_room)
		sound_room = &""
		if away != here:
			_go_room(away)  # move away from the sound
			actions.append({"wait": 4.0})
			return
	var reluctant := rt.story.beat_time() >= RELUCTANCE or rt.story.beat == &"decision"
	var target := rt.story.hint_room()
	if target != &"" and (reluctant or WorldState.is_light_on(target)) and _story_action():
		return
	if _notice_visible():
		return
	for id: StringName in objects:
		if objects[id][2] and not read.has(id) and _exists(id) and ApartmentLayout.room_at(objects[id][0], WorldState.variants) == here:
			_use(id)  # reads what is in front of it, nothing more
			return
	actions.append({"wait": 3.0})


func _farthest_lit(from: StringName) -> StringName:
	var best := WorldState.player_room
	var best_d := -1
	for r: StringName in rt.graph.rooms():
		var d := rt.graph.distance(from, r)
		if d < 999 and d > best_d and WorldState.is_light_on(r):
			best = r
			best_d = d
	return best


func _passive() -> void:
	var target := rt.story.hint_room()
	var here := WorldState.player_room
	if rt.story.beat == &"decision":
		actions.append({"wait": 5.0})  # it never makes the choice
		return
	if target == here and rt.story.beat_time() >= 20.0 and _story_action():
		return
	if target != &"" and target != here and WorldState.time >= _passive_next:
		_passive_next = WorldState.time + PASSIVE_STEP
		var path := rt.graph.path(here, target)
		if path.size() >= 2:
			var c := rt.graph.connection(path[0], path[1])
			actions.append({"go": c["pos"], "door": c["door"]} if c["door"] != &"" else {"go": c["pos"]})
			if path[1] == &"gap" and WorldState.get_variant(&"gap") == &"long":
				_loop(path[0] == &"mirror_room")
			actions.append({"go": ApartmentLayout.room_center(path[1], WorldState.variants)})
			return
	actions.append({"wait": 5.0})
