extends TestCase
## Phase 2: event lifecycle, preconditions, cooldowns, mutual exclusion, pre-emption, failure recovery.

var sched: EventScheduler
var ctx: EventContext
var sounds: Array = []


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
	sounds.clear()
	EventBus.sound_requested.connect(_on_sound)


func _teardown() -> void:
	EventBus.sound_requested.disconnect(_on_sound)


func _on_sound(id: StringName, pos: Vector3, _db: float) -> void:
	sounds.append([id, pos])


func _run_for(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		WorldState.advance_time(0.1)
		sched.tick(0.1)
		t += 0.1


func test_definitions_are_sane() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	eq(sched.events.size(), 6, "six events loaded")
	for id: StringName in sched.events:
		var ev: HorrorEvent = sched.events[id]
		check(ev.min_act <= ev.max_act, "%s act range" % id)
		check(ev.duration > 0.0 and ev.cooldown >= 0.0, "%s timing" % id)
		check(not ev.channels.is_empty(), "%s has a channel" % id)
	_teardown()
	return true


func test_lifecycle_runs_to_completion() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"knock_wall")
	eq(run["state"], EventScheduler.State.RUNNING, "knock starts")
	check(sounds.size() == 1 and sounds[0][0] == &"knock3", "knock sound requested")
	_run_for(2.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "knock completes")
	eq(sched.running.size(), 0, "nothing left running")
	eq(WorldState.event_history[-1]["result"], &"completed", "history records the result")
	_teardown()
	return true


func test_act_gate_and_cooldown() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4), 0.0, 1)
	eq(sched.start(&"knock_wall")["reason"], "act", "adaptive events wait for act 2")
	eq(sched.start(&"knock_wall", {"ignore_act": true})["state"], EventScheduler.State.RUNNING, "debug keys skip the act gate")
	_run_for(2.0)
	eq(sched.start(&"knock_wall", {"ignore_act": true})["reason"], "cooldown", "cooldown blocks a repeat")
	_run_for(24.0)
	eq(sched.start(&"knock_wall", {"ignore_act": true})["state"], EventScheduler.State.RUNNING, "allowed after the cooldown")
	_teardown()
	return true


func test_shared_channel_blocks_equal_priority() -> bool:
	_setup(&"bedroom", Vector3(7.7, 0, 1.0))
	eq(sched.start(&"footsteps")["state"], EventScheduler.State.RUNNING, "footsteps start")
	eq(sched.start(&"knock_wall")["reason"], "busy:footsteps", "knock shares audio_major")
	eq(sched.start(&"light_flicker")["state"], EventScheduler.State.IDLE, "bedroom light is off, so no flicker")
	_teardown()
	return true


func test_story_preempts_and_queues() -> bool:
	_setup(&"bedroom", Vector3(7.7, 0, 1.0))
	var steps := sched.start(&"footsteps")
	var story := sched.request(&"knock_wall", {"anchor": &"knock_bedroom_north"})
	eq(steps["state"], EventScheduler.State.CANCELLED, "story knock pre-empts adaptive footsteps")
	eq(story["state"], EventScheduler.State.RUNNING, "story knock runs")
	var second := sched.request(&"knock_wall", {"anchor": &"knock_bedroom_west"})
	eq(second["state"], EventScheduler.State.IDLE, "equal priority waits")
	check(sched.is_queued(&"knock_wall"), "second knock is queued")
	_run_for(2.0)
	check(sched.is_running(&"knock_wall") and not sched.is_queued(&"knock_wall"), "queued knock starts once the first ends")
	_teardown()
	return true


func test_failures_leave_the_world_valid() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"light_flicker", {"chance_off": 1.0})
	run["failed"] = true
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.FAILED, "flicker failed")
	eq(WorldState.is_light_on(&"living"), true, "a failed flicker leaves the light on")
	_run_for(40.0)
	run = sched.start(&"light_flicker", {"chance_off": 1.0})
	_run_for(3.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "flicker completed")
	eq(WorldState.is_light_on(&"living"), false, "a completed flicker can switch it off")

	ctx.stage.position = Vector3(4.0, 0, 3.25)
	WorldState.set_player_room(&"hallway")
	run = sched.start(&"door_slam", {"door": &"bedroom_door", "timeout": 0.5})
	eq(WorldState.is_door_open(&"bedroom_door"), false, "door slammed")
	run["failed"] = true
	_run_for(0.2)
	eq(WorldState.is_door_open(&"bedroom_door"), true, "a failed slam puts the door back")
	_teardown()
	return true


func test_doors_never_move_next_to_the_player() -> bool:
	_setup(&"hallway", Vector3(6.75, 0, 3.0))
	eq(sched.start(&"door_slam", {"door": &"bedroom_door"})["reason"], "player_too_close", "no slam within reach")
	_teardown()
	return true


func test_silhouette_only_appears_out_of_view() -> bool:
	_setup(&"hallway", Vector3(4.0, 0, 3.25), -PI / 2)  # facing east, down the hallway
	eq(sched.start(&"silhouette")["reason"], "no_hidden_anchor", "everything near is in view")
	ctx.stage.yaw = PI / 2  # turn to face west
	var run := sched.start(&"silhouette")
	eq(run["state"], EventScheduler.State.RUNNING, "appears behind the player")
	check(ctx.stage.is_behind(run["position"]), "anchor is behind")
	sched.mark(&"silhouette", "seen")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "vanishes once seen")
	_teardown()
	return true


func test_footsteps_stop_at_the_doorway() -> bool:
	_setup(&"bedroom", Vector3(8.5, 0, 0.0))
	var run := sched.start(&"footsteps", {"from": &"living"})
	eq(run["state"], EventScheduler.State.RUNNING, "footsteps start")
	_run_for(8.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "footsteps finish")
	var steps := sounds.filter(func(s: Array) -> bool: return s[0] == &"footstep")
	eq(steps.size(), (run["steps"] as Array).size(), "one sound per step")
	var last: Vector3 = steps[-1][1]
	check(last.distance_to(Vector3(6.75, 0.05, 2.5)) < 0.01, "last step is at the bedroom doorway, not inside")
	_teardown()
	return true


func test_phone_rings_until_answered() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4), 0.0, 1)
	var run := sched.request(&"phone_ring", {"anchor": &"phone_intercom", "stop_flag": &"answered"})
	eq(run["state"], EventScheduler.State.RUNNING, "story ring starts in act 1")
	_run_for(8.0)
	var rings := sounds.filter(func(s: Array) -> bool: return s[0] == &"intercom_ring")
	eq(rings.size(), 3, "rings at 0, 3.6 and 7.2 s")
	eq(rings[0][1], ApartmentLayout.ANCHORS[&"phone_intercom"]["pos"], "from the intercom")
	WorldState.set_flag(&"answered")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "answering stops it")
	_teardown()
	return true
