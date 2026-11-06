extends TestCase
## Phase 5: the story on the simulation core. Every beat moves on by itself if the player does nothing,
## the reveal never happens in front of the player, and both endings come from the player's choice.

var stage: HorrorStage
var rt: HorrorRuntime
var lines: Array[String] = []  # story lines (line_requested): always shown
var subtitles: Array[String] = []  # sound captions (subtitle_requested): the setting decides
var sounds: Array = []  # [id, position] of every sound_requested


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


func _listen() -> void:
	EventBus.line_requested.connect(_on_line)
	EventBus.subtitle_requested.connect(_on_subtitle)
	EventBus.sound_requested.connect(_on_sound)


func _on_line(text: String, _seconds: float) -> void:
	lines.append(text)


func _on_subtitle(text: String, _seconds: float) -> void:
	subtitles.append(text)


func _on_sound(id: StringName, pos: Vector3, _db: float) -> void:
	sounds.append([id, pos])


func _done() -> bool:
	if EventBus.line_requested.is_connected(_on_line):
		EventBus.line_requested.disconnect(_on_line)
		EventBus.subtitle_requested.disconnect(_on_subtitle)
		EventBus.sound_requested.disconnect(_on_sound)
	rt.free()
	return true


## Exactly `seconds` of sim time, in 0.1 s steps (_until's float sum overshoots by a step).
func _wait(seconds: float) -> void:
	for i in roundi(seconds * 10.0):
		rt.step(0.1)


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


func test_from_the_road_the_flat_opens_quiet_and_asking() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	_listen()
	_wait(1.0)
	eq(WorldState.objective, "How did you get home?", "the first objective is a question")
	_wait(11.0)
	eq(lines, ["[Your phone says 12:41 AM. The clock on the wall says 11:47.]", "[Your uniform is still damp from the fog.]"], "found, not told, in order")
	check(lines.size() == 2 and not subtitles.has(lines[0]) and not subtitles.has(lines[1]), "story lines, not sound captions: always shown")
	_wait(7.9)
	check(WorldState.event_history.is_empty(), "nothing happens in the quiet")
	eq(WorldState.objective, "How did you get home?", "the question stays for the whole quiet")
	_wait(0.5)
	eq(WorldState.objective, "Wash up, then get some sleep.", "then the usual objective, without the mamak")
	eq(lines.size(), 2, "and the opening lines are not said again")
	return _done()


func test_lying_down_early_holds_the_ring_until_the_quiet_ends() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"saved"
	_wait(5.0)
	EventBus.object_interacted.emit(&"bed")
	check(not _until(func() -> bool: return story.beat == &"ringing", 14.8), "no ring before 20 s")
	check(_until(func() -> bool: return story.beat == &"ringing", 5.0), "it rings once the quiet is over")
	eq(WorldState.objective, "Answer the intercom.", "and the question does not come back over it")
	return _done()


func test_washing_during_the_question_leaves_get_some_sleep() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"alive"
	_wait(5.0)
	EventBus.object_interacted.emit(&"sink")
	_wait(1.0)
	eq(WorldState.objective, "How did you get home?", "washing doesn't answer the question")
	_wait(14.4)
	eq(WorldState.objective, "Get some sleep.", "at the end of the quiet")
	return _done()


func test_inspecting_the_footprints_ends_the_question() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	_wait(5.0)
	EventBus.object_interacted.emit(&"footprints")
	eq(WorldState.objective, "Wash up, then get some sleep.", "the question gives way")
	_wait(1.0)
	EventBus.object_interacted.emit(&"bed")  # lie down at 6 s
	check(not _until(func() -> bool: return story.beat == &"ringing", 13.8), "the quiet still holds the ring")
	return _done()


func test_opened_directly_the_flat_opens_as_today() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &""
	_listen()
	_wait(1.0)
	eq(WorldState.objective, "You're home from your shift at the mamak. Wash up, then get some sleep.", "today's objective")
	EventBus.object_interacted.emit(&"bed")
	check(_until(func() -> bool: return story.beat == &"ringing", 4.2), "the intercom rings 4 s after lying down, as today")
	eq(lines, [], "no new lines")
	return _done()


## Plays the flat on from the start, doing nothing, until the bedroom's first knock has sounded in the `knocked` beat.
func _to_the_first_knock(story: StoryDirector, wall: Vector3, sound: StringName) -> void:
	check(_until(func() -> bool: return story.beat == &"knocked", 280.0), "the do-nothing player reaches the knocks")
	check(_until(func() -> bool: return sounds.any(func(s: Array) -> bool: return s[1] == wall and s[0] == sound), 10.0), "and the knock has sounded")


func test_from_the_road_the_bedroom_knocks_sound_like_the_roof() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	_listen()
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	_to_the_first_knock(story, wall, &"thump3")
	check(not sounds.has([&"knock3", wall]), "the story's knocks are the roof's, not a knuckle's")
	_wait(46.0)  # still out of the bedroom: the second try
	check(sounds.count([&"thump3", wall]) >= 2 and not sounds.has([&"knock3", wall]), "and so is the second knock")
	_place(Vector3(8.5, 0, 0.5))  # in the bedroom (the point this file's other tests use)
	_until(func() -> bool: return false, 5.0)
	eq(lines.count(StoryDirector.SMELL), 1, "her smell, once, as a story line")
	check(not subtitles.has(StoryDirector.SMELL), "not a sound caption: shown with captions off")
	EventBus.object_interacted.emit(&"bedroom_wall")
	check(sounds.has([&"thump1", wall]), "the wall answers like the roof")
	check(not sounds.has([&"knock1", wall]), "and not with a knuckle")
	_wait(10.0)
	eq(lines.count(StoryDirector.SMELL), 1, "and the smell is not said again before the answer")
	eq(StoryDirector.SMELL, Penanggal.SMELL, "the road's own line")
	return _done()


func test_touching_the_wall_early_brings_the_smell_just_before_the_answer() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"saved"
	_listen()
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	_to_the_first_knock(story, wall, &"thump3")
	EventBus.object_interacted.emit(&"bedroom_wall")  # at once: not 4 s in the bedroom first
	_wait(9.0)
	eq(lines.count(StoryDirector.SMELL), 1, "the smell comes before the answer")
	check(subtitles.has("[The wall is cold. Something on the other side knocks back. Once.]"), "and the answer after it")
	eq(story.beat, &"disturbance", "the story moved on")
	return _done()


func test_opened_directly_the_knocks_are_knocks() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &""
	_listen()
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	_to_the_first_knock(story, wall, &"knock3")
	_place(Vector3(8.5, 0, 0.5))
	_until(func() -> bool: return false, 5.0)
	EventBus.object_interacted.emit(&"bedroom_wall")
	check(sounds.has([&"knock1", wall]), "the wall answers with a knock")
	check(not sounds.any(func(s: Array) -> bool: return String(s[0]).begins_with("thump")), "no thump at all")
	_wait(10.0)
	eq(lines, [], "no smell, no new lines")
	return _done()


func test_the_look_back_line_plays_once() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"alive"
	_listen()
	story.debug_skip()  # act 2
	WorldState.set_variant(&"entrance_shoes", &"moved")
	EventBus.object_interacted.emit(&"shoes_moved")
	eq(WorldState.objective, "Things move when you aren't looking. Keep looking.", "the objective")
	_wait(20.0)  # the queue: her smell, the wall, the shoes, then this
	eq(_shifts_done(), 0, "before any shift")
	eq(lines.count(StoryDirector.REVERSAL), 1, "with the first 'Keep looking'")
	check(not subtitles.has(StoryDirector.REVERSAL), "a story line, not a sound caption")
	var done_before := _shifts_done()
	check(_until(func() -> bool: return _shifts_done() > done_before, 120.0), "a shift completes")
	_wait(1.0)
	eq(lines.count(StoryDirector.REVERSAL), 1, "never twice")
	return _done()


func test_the_look_back_line_comes_with_the_first_shift_too() -> bool:
	for road: StringName in [&"saved", &""]:
		WorldState.reset()
		sounds.clear()
		lines.clear()
		var story := _setup(ApartmentLayout.SPAWN)
		story.road = road
		_listen()
		story.debug_skip()  # act 2
		check(_until(func() -> bool: return _shifts_done() > 0, 120.0), "a shift completes for %s" % road)
		_wait(1.0)
		eq(lines.count(StoryDirector.REVERSAL), 1 if road != &"" else 0, "the reversal for road %s" % road)
		_done()
	return true


func test_the_downstairs_knock_back_follows_the_road() -> bool:
	for road: StringName in [&"caught", &""]:
		WorldState.reset()
		sounds.clear()
		var story := _setup(Vector3(8.0, 0, -16.0))  # B-11-07
		story.road = road
		_listen()
		for i in 3:
			story.debug_skip()
		EventBus.object_interacted.emit(&"mirror_wall")
		var pos: Vector3 = ApartmentLayout.ANCHORS[&"knock_mirror"]["pos"]
		check(sounds.has([&"thump3" if road != &"" else &"knock3", pos]), "the knock back for road %s" % road)
		check(sounds.any(func(s: Array) -> bool: return String(s[0]).begins_with("thump")) == (road != &""), "roof or knuckle, not both (%s)" % road)
		_done()
	return true


func _shifts_done() -> int:
	return WorldState.event_history.filter(func(e: Dictionary) -> bool: return e["id"] == &"shift" and e["result"] == &"completed").size()
