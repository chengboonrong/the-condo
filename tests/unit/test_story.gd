extends TestCase
## Phase 5: the story on the simulation core. Every beat moves on by itself if the player does nothing,
## the reveal never happens in front of the player, and both endings come from the player's choice.

var stage: HorrorStage
var rt: HorrorRuntime


func _setup(pos: Vector3) -> StoryDirector:
	ApartmentLayout.apply_initial_state()
	stage = HorrorStage.new(RoomGraph.new(WorldState.variants))
	_place(pos)
	rt = HorrorRuntime.new()
	rt.setup(stage, 3)
	rt.start_story()
	return rt.story


func _place(pos: Vector3) -> void:
	stage.position = pos
	WorldState.set_player_room(ApartmentLayout.room_at(pos, WorldState.variants))


## Steps until cond() holds or `limit` sim seconds pass. Returns whether it held.
func _until(cond: Callable, limit: float) -> bool:
	var end := WorldState.time + limit
	while WorldState.time < end:
		rt.step(0.1)
		if cond.call():
			return true
	return false


func _done() -> bool:
	rt.free()
	return true


func test_a_player_who_does_nothing_still_gets_to_act_3() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	check(_until(func() -> bool: return story.beat == &"ringing", 151.0), "the intercom rings without going to bed")
	check(_until(func() -> bool: return story.beat == &"knocked", 110.0), "unanswered, the knocks come anyway")
	check(_until(func() -> bool: return WorldState.act == WorldState.Act.DISTURBANCE, 121.0), "act 2 starts without touching the wall")
	check(_until(func() -> bool: return WorldState.act == WorldState.Act.IMPOSSIBLE, StoryDirector.ACT2_MAX + 1.0), "act 3 starts without enough signs")
	check(_until(func() -> bool: return WorldState.get_variant(&"bedroom") == &"door", 90.0), "the window becomes a door while the player waits by the front door")
	eq(story.beat, &"revealed", "and the story knows")
	return _done()


func test_the_reveal_waits_until_the_player_leaves_the_bedroom() -> bool:
	var story := _setup(Vector3(8.5, 0, 0.5))  # in the bedroom
	story.debug_skip()  # act 2
	story.debug_skip()  # act 3: knocking at the front door
	check(_until(func() -> bool: return story.beat == &"reveal_pending", 61.0), "the player stays in the bedroom: the reveal is asked for anyway")
	_until(func() -> bool: return false, 40.0)
	eq(WorldState.get_variant(&"bedroom"), &"default", "nothing changes around the player")
	var knocks := WorldState.event_history.filter(func(e: Dictionary) -> bool: return e["id"] == &"knock_wall" and e["t"] > story.beat_started)
	check(not knocks.is_empty(), "knocks at the front door call them out")
	_place(Vector3(1.0, 0, 8.0))  # they go to the front door
	check(_until(func() -> bool: return story.beat == &"revealed", 31.0), "the reveal happens behind their back")
	return _done()


func test_noticing_a_moved_thing_puts_it_back() -> bool:
	var story := _setup(Vector3(6.5, 0, 7.0))  # living room
	story.debug_skip()
	WorldState.set_variant(&"living_chair", &"turned")
	WorldState.advance_time(120.0)
	EventBus.object_interacted.emit(&"chair_turned")
	eq(WorldState.get_variant(&"living_chair"), &"default", "the chair is turned back")
	eq(story.noticed, 1, "and it counts as a sign")
	eq(WorldState.clock_minutes(), 23 * 60 + 49, "putting it back is not a shift: the clock keeps going")
	return _done()


func test_both_endings_and_the_decision_fail_safe() -> bool:
	for ending: StringName in [&"downstairs", &"vacant", &""]:
		WorldState.reset()
		var story := _setup(Vector3(8.0, 0, -16.0))  # B-11-07
		for i in 3:
			story.debug_skip()
		eq(WorldState.act, WorldState.Act.DECISION, "act 4")
		match ending:
			&"downstairs":
				EventBus.object_interacted.emit(&"mirror_wall")
			&"vacant":
				EventBus.object_interacted.emit(&"lift_button")
			&"":
				_until(func() -> bool: return WorldState.ending != &"", StoryDirector.DECISION_WAIT + 1.0)
		eq(WorldState.ending, ending if ending != &"" else &"downstairs", "ending for %s" % (ending if ending != &"" else &"waiting"))
		eq(WorldState.act, WorldState.Act.ENDED, "the story is over")
		check(rt.scheduler.running.is_empty() and rt.scheduler.queue.is_empty(), "and no event is left running")
		rt.free()
	return true
