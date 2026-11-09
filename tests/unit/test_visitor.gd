extends TestCase
## Someone at the door: the lift chimes, footsteps come up the corridor to the front door, the feet show
## under it, then go without a sound. A story knock ends it. Once Rosnah has warned him (answered_intercom), opening
## the door or a light left on when the feet stop kills him; unwarned, opening the door ends the visit as before.

## Ends its first update with a kill, as the visitor does when he breaks its rule.
class KillerEvent extends HorrorEvent:
	func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
		run["kill"] = &"lights_on"
		return true


var sched: EventScheduler
var ctx: EventContext
var trail: Array = []  # every sound, feet request and caption, in the order they happened


func _setup(room: StringName, pos: Vector3, yaw := 0.0, act := 2) -> void:
	ApartmentLayout.apply_initial_state()
	WorldState.act = act
	WorldState.set_player_room(room)
	ctx = EventContext.new()
	ctx.graph = RoomGraph.new(WorldState.variants)
	ctx.stage = HorrorStage.new(ctx.graph)
	ctx.stage.position = pos
	ctx.stage.yaw = yaw
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 7
	sched = EventScheduler.new(ctx)
	sched.load_dir("res://resources/horror_events")
	trail.clear()
	EventBus.sound_requested.connect(_on_sound)
	EventBus.door_feet_requested.connect(_on_feet)
	EventBus.subtitle_requested.connect(_on_caption)


func _teardown() -> void:
	EventBus.sound_requested.disconnect(_on_sound)
	EventBus.door_feet_requested.disconnect(_on_feet)
	EventBus.subtitle_requested.disconnect(_on_caption)


func _on_sound(id: StringName, pos: Vector3, db: float) -> void:
	trail.append(["sound", id, pos, db])


func _on_feet(shown: bool) -> void:
	trail.append(["feet", shown])


func _on_caption(text: String, _duration: float) -> void:
	trail.append(["caption", text])


func _run_for(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		WorldState.advance_time(0.1)
		sched.tick(0.1)
		t += 0.1


## Until the feet are under the door (the walk's length is the event's to choose), as far as a minute.
func _run_until_feet() -> void:
	var t := 0.0
	while not trail.has(["feet", true]) and t < 60.0:
		_run_for(0.1)
		t += 0.1


## He has heard Rosnah's warning: the door and the lights can kill him.
func _arm() -> void:
	WorldState.set_flag(&"answered_intercom")


func _lights_off() -> void:
	for room: StringName in ApartmentLayout.APARTMENT_ROOMS:
		WorldState.set_light(room, false)


func test_the_visitor_comes_to_the_door_and_waits() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	eq(run["state"], EventScheduler.State.RUNNING, "a visit starts in the living room with the door shut")
	eq(run["room"], &"corridor", "it happens in the corridor")
	_run_until_feet()
	var sounds := trail.filter(func(e: Array) -> bool: return e[0] == "sound")
	eq(sounds[0][1], &"lift_ding", "the lift chimes first")
	var steps := sounds.filter(func(e: Array) -> bool: return e[1] == &"footstep")
	check(steps.size() >= 8, "footsteps come along the corridor")
	for i in range(1, steps.size()):
		check((steps[i][2] as Vector3).distance_to(VisitorEvent.DOOR) < (steps[i - 1][2] as Vector3).distance_to(VisitorEvent.DOOR), "step %d is closer to the door" % i)
		check(steps[i][3] >= steps[i - 1][3], "step %d is no quieter" % i)
	check((steps[-1][2] as Vector3).distance_to(VisitorEvent.DOOR) < 0.6, "the last step is at the front door")
	check(sounds.all(func(e: Array) -> bool: return e[3] < 0.0), "every sound under the knock's 0 dB")
	var shown := trail.find(["feet", true])
	check(shown > trail.rfind(steps[-1]), "the feet show after the last step")
	_run_for(30.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "the visit ends by itself")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet"), [["feet", true], ["feet", false]], "the feet go")
	check(trail.slice(shown).all(func(e: Array) -> bool: return e[0] != "sound"), "without a sound")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "caption").map(func(e: Array) -> String: return e[1]),
		["[A lift chimes down the corridor]", "[Footsteps in the corridor, coming closer]", "[The footsteps stop outside your door]"],
		"captions for the sounds only")
	_teardown()
	return true


func test_the_visitors_door_is_the_layouts_front_door() -> bool:
	var doorway := Vector3.ZERO
	for c: Dictionary in ApartmentLayout.CONNECTIONS:
		if c["door"] == &"main_door":
			doorway = c["pos"]
	near(VisitorEvent.DOOR.x, doorway.x, 0.0001, "the visitor's door x is main_door's doorway")
	near(VisitorEvent.DOOR.z, doorway.z, 0.0001, "the visitor's door z is main_door's doorway")
	near(VisitorEvent.LAST_STEP.x, doorway.x, 0.0001, "the last step is in line with the door")
	check(VisitorEvent.LAST_STEP.z > VisitorEvent.DOOR.z and VisitorEvent.LAST_STEP.z < VisitorEvent.WALK_Z,
		"the last step is between the door and the corridor's walking line (%.2f)" % VisitorEvent.LAST_STEP.z)
	return true


func test_the_visitor_needs_the_door_shut_and_the_player_inside() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	WorldState.set_door(&"main_door", true, &"player")
	eq(sched.start(&"visitor")["reason"], "door_open", "not with the front door open")
	_teardown()
	for c: Array in [[&"corridor", Vector3(8, 0, 11.2), "player_not_inside"], [&"bedroom", Vector3(7.7, 0, 1.0), "player_not_inside"],
			[&"entrance", Vector3(1.5, 0, 9.0), "player_at_door"]]:
		_setup(c[0], c[1])
		eq(sched.start(&"visitor")["reason"], c[2], "%s: %s" % [c[0], c[2]])
		_teardown()
	for act in [1, 3]:
		_setup(&"living", Vector3(6.5, 0, 8.4), 0.0, act)
		eq(sched.start(&"visitor")["reason"], "act", "act %d: act 2 only" % act)
		_teardown()
	return true


func test_unwarned_the_door_ends_the_visit_as_before() -> bool:
	for when: String in ["on the way", "at the door"]:
		_setup(&"living", Vector3(6.5, 0, 8.4))  # no warning; the living light is on
		var run := sched.start(&"visitor")
		if when == "on the way":
			_run_for(4.0)
		else:
			_run_until_feet()
		WorldState.set_door(&"main_door", true, &"player")
		_run_for(0.2)
		eq(run["state"], EventScheduler.State.COMPLETED, "%s: opening the door ends it, nobody there" % when)
		check(not run.has("kill"), "%s: and nobody dies" % when)
		if when == "at the door":
			eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "the feet are gone")
		_teardown()
	return true


func test_opening_the_door_while_the_feet_are_there_kills() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	_arm()
	_lights_off()
	var run := sched.start(&"visitor")
	_run_until_feet()
	eq(run["state"], EventScheduler.State.RUNNING, "(the feet are there, and he lives: every light is off)")
	WorldState.set_door(&"main_door", true, &"player")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "opening the door ends the visit")
	eq(run.get("kill"), &"front_door", "and kills him")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "the feet are taken away with the run")
	_teardown()
	return true


## The way round the lights: open the door before the feet stop and nothing can be checked.
func test_opening_the_door_while_the_footsteps_come_kills() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	_arm()
	_lights_off()
	var run := sched.start(&"visitor")
	_run_for(4.0)
	check(trail.any(func(e: Array) -> bool: return e[0] == "sound" and e[1] == &"footstep") and not trail.has(["feet", true]), "(the footsteps are coming)")
	WorldState.set_door(&"main_door", true, &"player")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "opening the door ends the visit")
	eq(run.get("kill"), &"front_door", "and kills him")
	_teardown()
	return true


## The peephole shows the empty corridor and kills nothing, and it is not the end of the visit: it goes on to the lights
## check, so looking cannot skip the rule. The look comes through EventBus, as it does in the game.
func test_peeking_no_longer_ends_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	_arm()
	var rt := HorrorRuntime.new()
	rt.setup(ctx.stage, 3)
	var run := rt.scheduler.start(&"visitor")
	for i in 40:
		rt.step(0.1)
	EventBus.object_interacted.emit(&"peephole")  # on the way
	for i in 5:
		rt.step(0.1)
	eq(run["state"], EventScheduler.State.RUNNING, "looking through the peephole does not end the visit")
	check(not run.has("kill") and rt.dead == &"", "and does not kill him")
	var t := 0.0
	while not run.has("kill") and t < 60.0:  # the living light is on: the lights check gets him
		rt.step(0.1)
		t += 0.1
	eq(rt.dead, &"lights_on", "the visit runs on to the lights check")
	rt.free()
	_teardown()
	return true


## A visitor's kill ends the step: the director, due to evaluate in it, does not, so nothing new begins under the card.
func test_a_visitor_kill_begins_nothing_else_in_its_step() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var rt := HorrorRuntime.new()
	rt.setup(ctx.stage, 3)
	var killer := KillerEvent.new()
	killer.id = &"killer"
	rt.scheduler.register(killer)
	rt.scheduler.start(&"killer")
	rt.director._next_eval = 0.0  # due now
	var evals := rt.director.eval_count
	rt.step(0.1)
	eq(rt.dead, &"lights_on", "the kill is his death")
	eq(rt.director.eval_count, evals, "the director does not evaluate after it")
	check(rt.scheduler.running.is_empty() and rt.scheduler.queue.is_empty(), "and nothing is running or waiting")
	rt.free()
	_teardown()
	return true


func test_a_room_light_on_when_the_feet_stop_kills() -> bool:
	for room: StringName in ApartmentLayout.APARTMENT_ROOMS:
		_setup(&"living", Vector3(6.5, 0, 8.4))
		_arm()
		_lights_off()
		WorldState.set_light(room, true)
		var run := sched.start(&"visitor")
		_run_until_feet()
		eq(run["state"], EventScheduler.State.COMPLETED, "%s light on: the visit ends when the feet stop" % room)
		eq(run.get("kill"), &"lights_on", "%s light on: it knew he was home" % room)
		_teardown()
	return true


func test_the_phone_light_counts() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	_arm()
	_lights_off()
	ctx.stage.phone_light = true
	var run := sched.start(&"visitor")
	_run_until_feet()
	eq(run.get("kill"), &"lights_on", "the phone's light is a light")
	_teardown()
	return true


func test_every_light_off_he_lives() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	_arm()
	_lights_off()
	check(WorldState.is_light_on(&"corridor"), "(the corridor's light is on: it is not his)")
	var run := sched.start(&"visitor")
	_run_until_feet()
	eq(run["state"], EventScheduler.State.RUNNING, "the feet are under the door and nothing happens")
	_run_for(30.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "the visit ends by itself")
	check(not run.has("kill"), "and he lives")
	_teardown()
	return true


## Unwarned, the lights do not matter: the living room's is on, and the feet go.
func test_unwarned_the_lights_do_not_matter() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	ctx.stage.phone_light = true
	var run := sched.start(&"visitor")
	_run_until_feet()
	_run_for(30.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "the visit ends by itself")
	check(not run.has("kill"), "with a light on and no warning he lives")
	_teardown()
	return true


## Rosnah says "if you hear footsteps outside", so the time that counts runs from the first footstep, not the chime, to the
## feet stopping. It must reach every switch from anywhere he can be with every light on
## (docs/superpowers/specs/2026-11-09-game-over-design.md, "Hide from the footsteps"): the worst start the visit allows
## (prepare: the entrance, living room or kitchen, at least MIN_DISTANCE from the door; every 0.25 m along the rooms'
## edges, where the worst start is), the shortest tour of the six switches at the walking pace, through the doorways,
## and two seconds to spare.
func test_the_walk_is_long_enough_to_switch_every_light_off() -> bool:
	var event: VisitorEvent = load("res://resources/horror_events/visitor.tres")
	var first_footstep_to_feet := event.steps * VisitorEvent.STEP_TIME  # the first step at FIRST_STEP, then one STEP_TIME each
	var graph := RoomGraph.new({})
	var switches: Array = []  # [position, room]
	for room: StringName in ApartmentLayout.APARTMENT_ROOMS:
		var at: Vector3 = ApartmentLayout.LIGHTS[room]["switch"]
		switches.append([at, ApartmentLayout.room_at(at, {})])
	var between: Array = []  # between[i][j]: the walk from switch i to switch j
	for i in switches.size():
		between.append(switches.map(func(to: Array) -> float: return _walk(graph, switches[i][0], switches[i][1], to[0], to[1])))
	var all: Array = range(switches.size())
	var worst := 0.0
	var worst_from := ""
	for room: StringName in [&"entrance", &"living", &"kitchen"]:
		for rect: Rect2 in ApartmentLayout.ROOMS[room]["rects"]:
			for start: Vector2 in _edge_points(rect):
				if start.distance_to(Vector2(VisitorEvent.DOOR.x, VisitorEvent.DOOR.z)) < VisitorEvent.MIN_DISTANCE:
					continue
				var first: Array = switches.map(func(to: Array) -> float: return _walk(graph, Vector3(start.x, 0, start.y), room, to[0], to[1]))
				var tour := _tour(first, between, -1, all) / PlayerController.WALK_SPEED
				if tour > worst:
					worst = tour
					worst_from = "%s %s" % [room, start]
	print("    switching every light off from the worst start (%s): %.1f m, %.2f s; first footstep to feet: %.2f s (chime to feet %.2f s)" % [
		worst_from, worst * PlayerController.WALK_SPEED, worst, first_footstep_to_feet, VisitorEvent.FIRST_STEP + first_footstep_to_feet])
	check(first_footstep_to_feet >= worst + 2.0, "the walk from the first footstep (%.2f s) is %.2f s short of the %.2f s he needs from %s, plus 2 s" % [
		first_footstep_to_feet, worst + 2.0 - first_footstep_to_feet, worst, worst_from])
	return true


## Every step stays in the corridor, between the front door and the lift.
func test_every_step_is_in_the_corridor_between_the_door_and_the_lift() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.check(&"visitor")
	var path: Array = run["steps"]
	check(path.size() == (load("res://resources/horror_events/visitor.tres") as VisitorEvent).steps, "one position for every step")
	for p: Vector3 in path:
		eq(ApartmentLayout.room_at(p, WorldState.variants), &"corridor", "step at %s is in the corridor" % p)
		check(p.x >= VisitorEvent.DOOR.x and p.x < ApartmentLayout.LIFT_POS.x, "step at %s is between the door and the lift" % p)
	_teardown()
	return true


## The shortest walk past every switch in `left` (indices into the switches), from the start (`at` = -1; `first[j]` is its
## walk to switch j) or from switch `at` (`between[at][j]`), in any order.
func _tour(first: Array, between: Array, at: int, left: Array) -> float:
	if left.is_empty():
		return 0.0
	var best := INF
	for k in left.size():
		var j: int = left[k]
		var rest := left.duplicate()
		rest.remove_at(k)
		best = minf(best, (first[j] if at < 0 else between[at][j]) + _tour(first, between, j, rest))
	return best


## Points every 0.25 m along the four edges of a rect (the corners included).
func _edge_points(rect: Rect2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in roundi(rect.size.x / 0.25) + 1:
		out.append(Vector2(rect.position.x + i * 0.25, rect.position.y))
		out.append(Vector2(rect.position.x + i * 0.25, rect.end.y))
	for i in roundi(rect.size.y / 0.25) + 1:
		out.append(Vector2(rect.position.x, rect.position.y + i * 0.25))
		out.append(Vector2(rect.end.x, rect.position.y + i * 0.25))
	return out


## The distance walked from a to b, through the doorways of the rooms between (ApartmentLayout.CONNECTIONS' positions).
func _walk(graph: RoomGraph, a: Vector3, a_room: StringName, b: Vector3, b_room: StringName) -> float:
	var rooms := graph.path(a_room, b_room)
	var total := 0.0
	var at := a
	for i in rooms.size() - 1:
		var door: Vector3 = graph.connection(rooms[i], rooms[i + 1])["pos"]
		total += Vector2(at.x, at.z).distance_to(Vector2(door.x, door.z))
		at = door
	return total + Vector2(at.x, at.z).distance_to(Vector2(b.x, b.z))


func test_a_story_knock_preempts_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	_run_until_feet()
	sched.request(&"knock_wall", {"anchor": &"knock_entrance_door"})
	eq(run["state"], EventScheduler.State.CANCELLED, "the act 3 knock pre-empts the visit (same channel)")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "and takes the feet away")
	_teardown()
	return true
