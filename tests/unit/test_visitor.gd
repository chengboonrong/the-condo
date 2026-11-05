extends TestCase
## Someone at the door: the lift chimes, footsteps come up the corridor to the front door, the feet show
## under it, then go without a sound. Opening the door, looking through the peephole or a story knock end it.

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


func test_the_visitor_comes_to_the_door_and_waits() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	eq(run["state"], EventScheduler.State.RUNNING, "a visit starts in the living room with the door shut")
	eq(run["room"], &"corridor", "it happens in the corridor")
	_run_for(14.0)
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


func test_opening_the_door_or_peeking_ends_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	_run_for(14.0)
	WorldState.set_door(&"main_door", true, &"player")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "opening the door ends it: nobody there")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "and the feet are gone")
	_teardown()
	_setup(&"living", Vector3(6.5, 0, 8.4))
	run = sched.start(&"visitor")
	_run_for(4.0)  # still walking
	var at := trail.size()
	sched.mark(&"visitor", "peeked")
	_run_for(5.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "looking through the peephole ends it, even on the way")
	check(trail.slice(at).all(func(e: Array) -> bool: return e[0] != "sound"), "the steps stop when you look")
	check(not trail.has(["feet", true]) or trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1] == ["feet", false], "no feet left under the door")
	_teardown()
	return true


func test_a_story_knock_preempts_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	_run_for(14.0)
	sched.request(&"knock_wall", {"anchor": &"knock_entrance_door"})
	eq(run["state"], EventScheduler.State.CANCELLED, "the act 3 knock pre-empts the visit (same channel)")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "and takes the feet away")
	_teardown()
	return true
