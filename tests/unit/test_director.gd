extends TestCase
## Phase 3: behaviour signals, explainable utility scores, tension pacing, the entity FSM, determinism.

## A walk through the flat: [seconds, position, yaw]. Used for the pacing and determinism runs.
const TRACE := [
	[0.0, Vector3(6.5, 0, 8.4), 0.0],
	[20.0, Vector3(1.5, 0, 4.5), PI / 2],  # kitchen
	[45.0, Vector3(6.5, 0, 7.0), 0.0],  # living
	[70.0, Vector3(6.5, 0, 3.25), -PI / 2],  # hallway
	[90.0, Vector3(8.5, 0, 0.5), 0.0],  # bedroom
	[150.0, Vector3(4.25, 0, 0.5), PI],  # bathroom
	[200.0, Vector3(6.5, 0, 7.0), PI],  # living, facing the balcony
]


func _runtime(seed_value: int, act: int, pos: Vector3, yaw := 0.0) -> HorrorRuntime:
	WorldState.reset()
	ApartmentLayout.apply_initial_state()
	WorldState.act = act
	var stage := HorrorStage.new(RoomGraph.new(WorldState.variants))
	_place(stage, pos, yaw)
	var rt := HorrorRuntime.new()
	rt.setup(stage, seed_value)
	return rt


func _place(stage: HorrorStage, pos: Vector3, yaw: float) -> void:
	stage.position = pos
	stage.yaw = yaw
	WorldState.set_player_room(ApartmentLayout.room_at(pos, WorldState.variants))


func _run(rt: HorrorRuntime, seconds: float, trace: Array = []) -> void:
	var t := 0.0
	var next := 0
	while t < seconds:
		if next < trace.size() and t >= float(trace[next][0]):
			_place(rt.ctx.stage, trace[next][1], trace[next][2])
			next += 1
		rt.step(0.1)
		t += 0.1


func test_profiler_signals() -> bool:
	var rt := _runtime(1, 1, Vector3(6.5, 0, 7.0))
	var p := rt.profiler
	_run(rt, 60.0)
	check(p.signal_value("idle") > 0.8, "standing still reads as idle (%.2f)" % p.signal_value("idle"))
	check(p.signal_value("light_dependence") > 0.5, "the living room light is on")
	rt.ctx.stage.speed = 2.0
	_run(rt, 30.0)
	check(p.signal_value("idle") < 0.5, "walking lowers idle (%.2f)" % p.signal_value("idle"))
	for i in 4:
		rt.ctx.stage.yaw += PI  # a sharp turn, then a pause
		_run(rt, 2.0)
	check(p.signal_value("look_behind") >= 0.75, "four quick turns read as looking behind (%.2f)" % p.signal_value("look_behind"))

	var investigated: Array = []
	var on_inv := func(room_id: StringName) -> void: investigated.append(room_id)
	EventBus.sound_investigated.connect(on_inv)
	p.note_stimulus(&"bedroom")  # two rooms away
	_place(rt.ctx.stage, Vector3(6.5, 0, 3.25), 0.0)  # step into the hallway, towards it
	_run(rt, 0.2)
	EventBus.sound_investigated.disconnect(on_inv)
	eq(investigated, [&"bedroom"], "moving towards a sound counts as investigating")
	near(p.signal_value("curiosity"), 1.0 / BehaviorProfiler.OUTCOME_WINDOW, 0.001, "one investigation in the window")
	p.note_stimulus(&"living")
	_place(rt.ctx.stage, Vector3(8.5, 0, 0.5), 0.0)  # into the bedroom, away from it
	_run(rt, 0.2)
	near(p.signal_value("avoidance"), 1.0 / BehaviorProfiler.OUTCOME_WINDOW, 0.001, "moving away counts as avoiding")

	check(p.room_avoidance(&"kitchen") > 0.8, "never-visited kitchen is avoided (%.2f)" % p.room_avoidance(&"kitchen"))
	check(p.room_avoidance(&"living") < 0.1, "the living room is not (%.2f)" % p.room_avoidance(&"living"))
	rt.free()
	return true


func test_scores_add_up_and_follow_behaviour() -> bool:
	var rt := _runtime(2, 3, Vector3(4.0, 0, 3.25), PI / 2)  # hallway, facing west
	rt.profiler.signals["look_behind"] = 1.0
	var scored := rt.director.score_all()
	var by_id := {}
	for s: Dictionary in scored:
		by_id[s["id"]] = s
	check(not by_id.has(&"phone_ring"), "story-only events are never scored")
	for s: Dictionary in scored:
		if s.has("total"):
			var sum := 0.0
			for v: float in s["parts"].values():
				sum += v
			near(s["total"], sum, 0.0001, "%s total is the sum of its parts" % s["id"])
	check(by_id[&"silhouette"].has("total"), "silhouette is possible behind the player")
	near(by_id[&"silhouette"]["parts"]["behavior"], 1.5, 0.0001, "look-behind drives the silhouette score")
	near(by_id[&"silhouette"]["parts"]["narrative"], 0.5, 0.0001, "act 3 bonus")
	rt.free()
	return true


func test_pacing_respects_gaps_and_one_beat_at_a_time() -> bool:
	var rt := _runtime(3, 3, Vector3(6.5, 0, 7.0))
	var starts: Array[float] = []
	var ends: Array[float] = []
	var overlap := [false]
	rt.scheduler.run_started.connect(func(_r: Dictionary) -> void:
		starts.append(WorldState.time)
		if rt.scheduler.running.size() > 1:
			overlap[0] = true)
	rt.scheduler.run_finished.connect(func(_r: Dictionary) -> void: ends.append(WorldState.time))
	_run(rt, 600.0, TRACE)
	check(starts.size() >= 6, "the director keeps events coming (%d in 10 min)" % starts.size())
	check(starts.size() <= 40, "but not constantly (%d in 10 min)" % starts.size())
	var mix := {}
	for e: Dictionary in WorldState.event_history:
		mix[e["id"]] = mix.get(e["id"], 0) + 1
	print("    pacing: %d events in 10 min of act 3, tension %.2f, mix %s" % [starts.size(), rt.director.tension, mix])
	check(mix.size() >= 4, "the director varies its events")
	check(not overlap[0], "never two events at once")
	for i in range(1, starts.size()):
		check(starts[i] - ends[i - 1] >= HorrorDirector.GAP_MIN - 0.01, "recovery gap before event %d (%.1fs)" % [i, starts[i] - ends[i - 1]])
	check(rt.director.tension <= 1.0, "tension stays bounded")
	check(rt.director.decisions.size() == starts.size(), "every adaptive start is logged with its scores")
	rt.free()
	return true


## An idle player in the lit living room, in act 2, far from the front door: the visitor is a candidate and,
## because its intensity fits act 2's 0.3 headroom, it reaches the director's top three and gets picked.
func test_the_visitor_is_a_candidate_for_an_idle_player() -> bool:
	var rt := _runtime(1, 2, Vector3(6.5, 0, 8.4))
	rt.director.paused = true
	_run(rt, 60.0)  # a minute of standing in the lit room reads as idle
	var scored := rt.director.score_all().filter(func(s: Dictionary) -> bool: return s.has("total"))
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["total"] > b["total"])
	var visitor := {}
	var rank := 0
	for i in scored.size():
		if scored[i]["id"] == &"visitor":
			visitor = scored[i]
			rank = i + 1
	check(visitor.has("total"), "the visitor is valid in the living room, door shut, act 2 (%s)" % [visitor])
	if visitor.has("total"):
		check(visitor["parts"]["behavior"] > 0.5, "standing still in the light drives it (%.2f)" % visitor["parts"]["behavior"])
		check(rank <= HorrorDirector.TOP_K, "it ranks in the director's top %d (rank %d, total %.2f, %s)" % [HorrorDirector.TOP_K, rank, visitor["total"], visitor["parts"]])
	rt.free()
	# 20 seeded first decisions from that same state: the visitor is among the three drawn from each, and wins some
	var picked := 0
	for seed_value in range(1, 21):
		var r := _runtime(seed_value, 2, Vector3(6.5, 0, 8.4))
		r.director.paused = true
		_run(r, 60.0)
		r.director.paused = false
		var t := 0.0
		while r.director.decisions.is_empty() and t < 60.0:
			r.step(0.1)
			t += 0.1
		if r.director.decisions.is_empty():
			failures.append("seed %d: the director made no decision in a minute" % seed_value)
		else:
			var d: Dictionary = r.director.decisions[0]
			check((d["scores"] as Array).any(func(s: Dictionary) -> bool: return s["id"] == &"visitor"), "seed %d: the visitor is among the top three (%s)" % [seed_value, d["scores"].map(func(s: Dictionary) -> StringName: return s["id"])])
			if d["chosen"] == &"visitor":
				picked += 1
		r.free()
	print("    visitor: rank %d (total %.2f); picked in %d of 20 seeded decisions" % [rank, visitor.get("total", 0.0), picked])
	check(picked >= 1, "the director picks the visitor at least once in 20 decisions (picked %d)" % picked)
	return true


func test_entity_never_enters_the_player_room() -> bool:
	var rt := _runtime(4, 2, Vector3(6.5, 0, 7.0))
	_run(rt, 0.2)
	eq(WorldState.entity_state, &"observing", "act 2 wakes it")
	eq(rt.graph.distance(WorldState.player_room, WorldState.entity_room), EntityController.WATCH_DISTANCE, "it watches from two rooms away")
	_run(rt, 40.0)
	eq(WorldState.entity_state, &"observing", "act 2 never approaches")
	WorldState.act = 3
	var rooms: Array[StringName] = []
	var turn := func(id: StringName, at: Vector3, _db: float) -> void:  # he turns to the sound, as he must
		if id == &"rattle":
			var stage := rt.ctx.stage
			stage.yaw = atan2(-(at.x - stage.position.x), -(at.z - stage.position.z))
	EventBus.sound_requested.connect(turn)
	for i in 1200:
		rt.step(0.1)
		rooms.append(WorldState.entity_room)
		if WorldState.entity_room == WorldState.player_room:
			break
	EventBus.sound_requested.disconnect(turn)
	check(not rooms.has(WorldState.player_room), "never in the player's room")
	check(rooms.has(&"hallway") or rooms.has(&"entrance"), "it came next door")
	rt.entity.notice()
	eq(WorldState.entity_state, &"retreating", "seen → retreats")
	eq(rt.graph.distance(WorldState.player_room, WorldState.entity_room), 2, "as far as it can get (two rooms from the living room)")
	_run(rt, EntityController.RETREAT_TIME + 0.2)
	eq(WorldState.entity_state, &"observing", "then watches again")
	_place(rt.ctx.stage, ApartmentLayout.room_center(WorldState.entity_room), 0.0)
	rt.step(0.1)
	eq(WorldState.entity_state, &"retreating", "walking into its room makes it leave")
	check(WorldState.entity_room != WorldState.player_room, "and it is gone")
	rt.free()
	return true


func _simulate(seed_value: int) -> Array:
	var rt := _runtime(seed_value, 3, Vector3(6.5, 0, 8.4))
	_run(rt, 300.0, TRACE)
	var out := [WorldState.event_history.duplicate(true), rt.director.decisions.duplicate(true), WorldState.entity_room]
	rt.free()
	return out


func test_same_seed_same_decisions() -> bool:
	var a := _simulate(1147)
	var b := _simulate(1147)
	check(not (a[0] as Array).is_empty(), "the run produced events")
	eq(var_to_str(a), var_to_str(b), "same seed and trace → identical events, scores and entity")
	var c := _simulate(99)
	check(var_to_str(a) != var_to_str(c), "a different seed changes the run")
	return true
