extends TestCase
## Phase 4: each of the five safety checks refuses on its own, safe shifts apply, and the shift event
## (adaptive and story) only ever goes through RoomTransformer.

var stage: HorrorStage
var tf: RoomTransformer


func _setup(pos: Vector3, yaw := 0.0) -> void:
	ApartmentLayout.apply_initial_state()
	stage = HorrorStage.new(RoomGraph.new(WorldState.variants))
	tf = RoomTransformer.new(stage.graph, stage)
	_place(pos, yaw)


func _place(pos: Vector3, yaw := 0.0) -> void:
	stage.position = pos
	stage.yaw = yaw
	WorldState.set_player_room(ApartmentLayout.room_at(pos, WorldState.variants))


func test_affected_rooms_follow_the_layout() -> bool:
	eq(RoomTransformer.affected_rooms(&"bedroom"), [&"bedroom", &"gap", &"mirror_room"] as Array[StringName], "the reveal changes the bedroom and makes the gap and B-11-07")
	eq(RoomTransformer.affected_rooms(&"gap"), [&"gap"] as Array[StringName], "the long gap only changes the gap")
	eq(RoomTransformer.affected_rooms(&"living_chair"), [&"living"] as Array[StringName], "an object shift changes its room")
	return true


func test_each_check_refuses() -> bool:
	_setup(Vector3(8.5, 0, 0.5))  # in the bedroom
	eq(tf.check(&"bedroom", &"door"), "player_inside", "1. not while the player is in the bedroom")
	_place(Vector3(6.75, 0, 3.25))  # hallway; the bedroom door is open
	eq(tf.check(&"bedroom", &"door"), "visible", "2. not while the bedroom can be seen")
	WorldState.set_door(&"bedroom_door", false, &"test")
	eq(tf.check(&"bedroom", &"door"), "", "safe once the door is shut")
	eq(tf.check(&"bedroom", &"default"), "already_default", "no-op shifts are refused")
	eq(tf.check(&"bedroom", &"attic"), "unknown_variant", "only predefined variants")

	# 4. a player standing where no room exists afterwards would be trapped in the void
	stage.position = Vector3(30, 0, 30)
	eq(tf.check(&"bedroom", &"door"), "would_trap_player", "4. never leave the player outside every room")
	stage.position = Vector3(6.75, 0, 3.25)

	# 5. story objects must stay reachable
	eq(tf.apply(&"bedroom", &"door"), "", "reveal applies")
	tf.required_rooms = [&"mirror_room"]
	eq(tf.check(&"bedroom", &"default"), "story_blocked:mirror_room", "5. never remove the room the story needs")
	tf.required_rooms = []
	eq(tf.check(&"bedroom", &"default"), "", "fine once the story no longer needs it")
	return true


func test_safe_shift_applies_and_resets_the_clock() -> bool:
	_setup(Vector3(6.5, 0, 7.0))  # living room
	WorldState.set_door(&"bedroom_door", false, &"test")
	WorldState.advance_time(600.0)
	eq(WorldState.clock_minutes(), 23 * 60 + 57, "ten minutes in")
	eq(tf.apply(&"bedroom", &"door"), "", "the window becomes a door")
	eq(WorldState.get_variant(&"bedroom"), &"door", "applied")
	eq(WorldState.clock_minutes(), 23 * 60 + 47, "and it is 11:47 PM again")
	check(stage.graph.is_reachable(&"living", &"mirror_room"), "B-11-07 is now reachable from the living room")
	return true


func _scheduler() -> EventScheduler:
	var ctx := EventContext.new()
	ctx.graph = stage.graph
	ctx.stage = stage
	ctx.rng = RandomNumberGenerator.new()
	ctx.rng.seed = 3
	ctx.transformer = tf
	var s := EventScheduler.new(ctx)
	s.load_dir("res://resources/horror_events")
	return s


func test_adaptive_shift_only_moves_unseen_things() -> bool:
	_setup(Vector3(6.5, 0, 7.0))  # living: the shoes (entrance) are in view, the chair is here
	WorldState.act = 2
	var sched := _scheduler()
	var run := sched.start(&"shift")
	eq(run["state"], EventScheduler.State.RUNNING, "something can shift")
	eq(run["area"], &"bathroom_tap", "only the tap is out of sight")
	eq(WorldState.get_variant(&"bathroom_tap"), &"running", "the tap is running now")
	_place(Vector3(4.25, 0, 0.5))  # the bathroom
	for i in 500:
		WorldState.advance_time(0.1)
		sched.tick(0.1)
	var again := sched.start(&"shift")
	check(again["state"] == EventScheduler.State.RUNNING and again["area"] != &"bathroom_tap", "never the room the player is in (%s)" % again.get("area", again["reason"]))
	return true


func test_story_shift_waits_until_safe() -> bool:
	_setup(Vector3(8.5, 0, 0.5))  # in the bedroom
	var sched := _scheduler()
	var run := sched.request(&"shift", {"area": &"bedroom", "variant": &"door"}, 20)
	eq(run["reason"], "player_inside", "the reveal waits while the player is in the bedroom")
	_place(Vector3(6.75, 0, 3.25))  # hallway, door open: they could see it
	sched.tick(0.1)
	check(sched.is_queued(&"shift"), "still waiting while the bedroom is in view")
	WorldState.set_door(&"bedroom_door", false, &"test")
	sched.tick(0.1)
	eq(WorldState.get_variant(&"bedroom"), &"door", "applied as soon as it is safe")
	check(not sched.is_queued(&"shift"), "and no longer queued")
	return true
