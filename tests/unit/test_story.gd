extends TestCase
## Phase 5: the story on the simulation core. Every beat moves on by itself if the player does nothing,
## the reveal never happens in front of the player, and both endings come from the player's choice.

const ENTRANCE := Vector3(1.5, 0, 8.5)  # by the intercom
const CRACKLE := "[The speaker crackles. Wind, and an engine idling.]"
const WALL_ANSWER := "[The wall is cold. Something on the other side knocks back. Once.]"

var stage: HorrorStage
var rt: HorrorRuntime
var lines: Array[String] = []  # story lines (line_requested): always shown
var subtitles: Array[String] = []  # sound captions (subtitle_requested): the setting decides
var sounds: Array = []  # [id, position] of every sound_requested
var heard: Array[String] = []  # lines and sound captions together, in the order they went out


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
	heard.append(text)


func _on_subtitle(text: String, _seconds: float) -> void:
	subtitles.append(text)
	heard.append(text)


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
		if ending != &"":
			check(_until(func() -> bool: return story.choice_open(), StoryDirector.DECISION_WAIT), "the choice opens")
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
	eq(WorldState.objective, StoryDirector.ROAD_OBJECTIVE, "then the road's objective: he is still lost")
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
	eq(WorldState.objective, StoryDirector.ROAD_WASHED, "at the end of the quiet")
	return _done()


func test_inspecting_the_footprints_ends_the_question() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	_wait(5.0)
	EventBus.object_interacted.emit(&"footprints")
	eq(WorldState.objective, StoryDirector.ROAD_OBJECTIVE, "the question gives way")
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
	eq(lines, ["[You lie down. Somewhere in the building, a lift hums and stops.]"], "no new lines: only the old one, now shown whatever the captions setting")
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
	eq(lines.count(StoryDirector.SMELL), 1, "and the smell is not said again with the answer")
	eq(StoryDirector.SMELL, Penanggal.SMELL, "the road's own line")
	return _done()


## The bedroom's knocks after the intercom's call are played louder while he is at the front door, to stand out from
## the flat's room tone there, 9.6 m and more from that wall. The next try is played as before.
func test_the_knocks_after_the_call_are_louder_than_the_next() -> bool:
	var story := _setup(ENTRANCE)  # by the intercom, all the way: never the bedroom
	story.road = &"caught"  # from the road, as the game is played: the beat plays thump3 (opened directly, knock3)
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	var knocks: Array[float] = []  # the play level of each set of thumps from the bedroom wall
	var on_sound := func(id: StringName, pos: Vector3, db: float) -> void:
		if pos == wall and id == &"thump3":
			knocks.append(db)
	EventBus.sound_requested.connect(on_sound)
	check(_until(func() -> bool: return knocks.size() == 1, 290.0), "the do-nothing player hears the first knocks")
	eq(story.beat, &"knocked", "after the call")
	check(_until(func() -> bool: return knocks.size() == 2, 50.0), "and the next try, out of the bedroom")
	EventBus.sound_requested.disconnect(on_sound)
	if knocks.size() == 2:
		eq(knocks[0], StoryDirector.KNOCK_AT_CALL_DB, "the knocks after the call")
		eq(knocks[1], 2.0, "the next try, as before")
		check(knocks[0] > knocks[1], "the knocks after the call are the louder")
	return _done()


## Anywhere nearer that wall than the front door, the knocks after the call are played as before: louder, they would
## be at the +3 dB cap there and peak over the limit (docs/architecture.md, "The key sounds").
func test_away_from_the_front_door_the_knocks_after_the_call_are_as_before() -> bool:
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	for place: Vector3 in [Vector3(8.5, 0, 0.5), ApartmentLayout.SPAWN]:  # in the bedroom, in the living room
		WorldState.reset()
		var story := _setup(place)
		var room := WorldState.player_room
		var knocks: Array[float] = []
		var on_sound := func(id: StringName, pos: Vector3, db: float) -> void:
			if pos == wall and id == &"knock3":  # the flat opened directly: knock3
				knocks.append(db)
		EventBus.sound_requested.connect(on_sound)
		check(_until(func() -> bool: return knocks.size() == 1, 290.0), "the do-nothing player hears them (%s)" % room)
		EventBus.sound_requested.disconnect(on_sound)
		eq(story.beat, &"knocked", "after the call (%s)" % room)
		if knocks.size() == 1:
			eq(knocks[0], 2.0, "the knocks after the call (%s)" % room)
		_done()
	return true


## The wall's answer is a sound caption that comes with its sound: it shows at once, not after the spoken lines
## queued before it.
func test_the_wall_answer_shows_with_its_knock() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	_listen()
	for i in 3:
		story.say("Line %d" % i, 3.5, true)
	story._wall_answers()
	_wait(0.5)
	eq(subtitles.count(WALL_ANSWER), 1, "the wall's caption has come, with the lines still queued")
	eq(lines.size(), 1, "and only the first of the spoken lines")
	return _done()


## What is said keeps its order whatever its kind: one queue, so a caption said between spoken lines is not shown
## alongside the first of them. Each comes out after the one before it, that one's seconds and the 0.3 s gap later.
func test_sound_captions_keep_their_order() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	var said := [["[Said first]", 3.0, false], ["\"Said second\"", 2.0, true], ["[Said third]", 2.5, false], ["[Said fourth]", 3.0, false]]
	var at: Array = []  # [text, sim time] of ours, whichever signal carried them
	var on_text := func(text: String, _seconds: float) -> void:
		if text.contains("Said"):
			at.append([text, WorldState.time])
	EventBus.subtitle_requested.connect(on_text)
	EventBus.line_requested.connect(on_text)
	for s: Array in said:
		story.say(s[0], s[1], s[2])
	_wait(10.0)
	EventBus.subtitle_requested.disconnect(on_text)
	EventBus.line_requested.disconnect(on_text)
	eq(at.map(func(a: Array) -> String: return a[0]), said.map(func(s: Array) -> String: return s[0]), "in the order they were said")
	for i in range(1, mini(at.size(), said.size())):
		near(float(at[i][1]) - float(at[i - 1][1]), float(said[i - 1][1]) + 0.3, 0.15, "%s comes after %s's seconds and the gap" % [said[i][0], said[i - 1][0]])
	return _done()


func test_touching_the_wall_early_brings_the_smell_after_the_answer() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"saved"
	_listen()
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	_to_the_first_knock(story, wall, &"thump3")
	_place(Vector3(8.5, 0, 0.5))
	EventBus.object_interacted.emit(&"bedroom_wall")  # at once: not 4 s in the bedroom first
	_wait(9.0)
	var answer := heard.find(WALL_ANSWER)
	var smell := heard.find(StoryDirector.SMELL)
	check(answer >= 0, "the answer's caption shows")
	check(smell > answer, "and her smell follows it, so the caption is with its sound")
	eq(lines.count(StoryDirector.SMELL), 1, "once")
	eq(story.beat, &"disturbance", "the story moved on")
	return _done()


func test_the_fail_safe_answer_brings_no_smell_to_someone_elsewhere() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)  # the living room, all the way
	story.road = &"caught"
	_listen()
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	_to_the_first_knock(story, wall, &"thump3")
	check(_until(func() -> bool: return story.beat == &"disturbance", 125.0), "the wall answers by itself at 120 s")
	_wait(10.0)
	check(sounds.has([&"thump1", wall]), "the answer sounds")
	eq(lines.count(StoryDirector.SMELL), 0, "but no smell: he is not by the bedroom wall")
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


## The thing a shift has moved that he can notice (&"" = none yet).
func _moved_object() -> StringName:
	for id: StringName in StoryDirector.NOTICE:
		if WorldState.get_variant(StoryDirector.NOTICE[id][0]) != &"default":
			return id
	return &""


## What he thinks or recognises is a story line, shown whatever "Captions for sounds" says, not a sound caption.
func test_his_recognition_of_his_own_voice_is_a_story_line() -> bool:
	var story := _setup(Vector3(8.0, 0, -16.0))  # B-11-07
	_listen()
	for i in 3:
		story.debug_skip()
	check(_until(func() -> bool: return rt.scheduler.is_running(&"phone_ring"), 10.0), "the intercom rings")
	EventBus.object_interacted.emit(&"intercom_mirror")
	_wait(15.0)
	eq(lines.count("[It's your voice.]"), 1, "he knows the voice, as a story line")
	check(not subtitles.has("[It's your voice.]"), "and it is no sound caption")
	return _done()


func test_the_look_back_line_plays_once_when_he_notices_something_moved() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"alive"
	_listen()
	story.debug_skip()  # act 2
	check(_until(func() -> bool: return _moved_object() != &"" and _shifts_done() > 0, 400.0), "a shift moves something while he is not looking")
	_wait(12.0)  # long enough for a queued line to be said
	eq(lines.count(StoryDirector.REVERSAL), 0, "the shift itself says nothing: nothing visible happened")
	var moved := _moved_object()
	check(moved != &"", "and the thing is still moved")
	EventBus.object_interacted.emit(moved)
	eq(WorldState.get_variant(StoryDirector.NOTICE[moved][0]), &"default", "he puts it back")
	_wait(12.0)
	eq(lines.count(StoryDirector.REVERSAL), 1, "the look-back line comes with his first notice")
	check(not subtitles.has(StoryDirector.REVERSAL), "a story line, not a sound caption")
	var notice := heard.find(StoryDirector.NOTICE[moved][1])
	check(notice >= 0 and heard.find(StoryDirector.REVERSAL) > notice, "after the notice line")
	for id: StringName in StoryDirector.NOTICE:  # a second notice, whatever the signs
		if id != moved:
			WorldState.set_variant(StoryDirector.NOTICE[id][0], &"moved")
			EventBus.object_interacted.emit(id)
			break
	_wait(12.0)
	eq(lines.count(StoryDirector.REVERSAL), 1, "never twice")
	return _done()


func test_the_look_back_line_comes_with_the_first_notice_even_after_enough_signs() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"saved"
	_listen()
	story.debug_skip()  # act 2
	story.noticed = StoryDirector.SIGNS_NEEDED  # no "Keep looking" objective any more
	WorldState.set_variant(&"entrance_shoes", &"moved")
	EventBus.object_interacted.emit(&"shoes_moved")
	_wait(10.0)
	eq(lines.count(StoryDirector.REVERSAL), 1, "the notice is what brings it, not the objective")
	return _done()


func test_opened_directly_nothing_is_said_when_he_notices() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &""
	_listen()
	story.debug_skip()  # act 2
	check(_until(func() -> bool: return _moved_object() != &"", 400.0), "a shift moves something")
	var moved := _moved_object()
	EventBus.object_interacted.emit(moved)
	_wait(12.0)
	eq(lines.count(StoryDirector.REVERSAL), 0, "no look-back line without the road")
	eq(lines, [StoryDirector.NOTICE[moved][1]], "no new lines but what he sees")
	return _done()


func test_the_downstairs_knock_back_follows_the_road() -> bool:
	for road: StringName in [&"caught", &""]:
		WorldState.reset()
		sounds.clear()
		var story := _setup(Vector3(8.0, 0, -16.0))  # B-11-07
		story.road = road
		_listen()
		for i in 3:
			story.debug_skip()
		_until(func() -> bool: return story.choice_open(), StoryDirector.DECISION_WAIT)
		EventBus.object_interacted.emit(&"mirror_wall")
		var pos: Vector3 = ApartmentLayout.ANCHORS[&"knock_mirror"]["pos"]
		check(sounds.has([&"thump3" if road != &"" else &"knock3", pos]), "the knock back for road %s" % road)
		check(sounds.any(func(s: Array) -> bool: return String(s[0]).begins_with("thump")) == (road != &""), "roof or knuckle, not both (%s)" % road)
		_done()
	return true


func test_ending_cards_follow_the_road() -> bool:
	for id: StringName in [&"downstairs", &"vacant"]:
		eq(StoryDirector.ending_card(id, &""), StoryDirector.ENDINGS[id], "%s opened directly: as today" % id)
		for road: StringName in [&"caught", &"saved", &"alive"]:
			eq(StoryDirector.ending_card(id, road)[0], StoryDirector.ENDINGS[id][0], "%s/%s keeps its title" % [id, road])
	check(StoryDirector.ending_card(&"downstairs", &"caught")[1].ends_with("You never got home."), "caught: he never got home")
	check(StoryDirector.ending_card(&"vacant", &"caught")[1].contains("Its tenant was one of three people found on the old road down the mountain."), "caught: the notice")
	check(StoryDirector.ending_card(&"downstairs", &"saved")[1].ends_with("He's been knocking all night."), "saved: Hafiz")
	check(StoryDirector.ending_card(&"vacant", &"saved")[1].ends_with("Some nights you still hear him knocking."), "saved: Hafiz")
	for id: StringName in [&"downstairs", &"vacant"]:
		var alive: String = StoryDirector.ending_card(id, &"alive")[1]
		check(alive.contains("Something else came down the mountain too."), "alive: %s" % id)
		check(alive.ends_with("On the road it had Hafiz's voice. Tonight it has yours."), "alive: the voice was his, %s" % id)
	return true


func test_after_the_road_he_washes_the_mountain_off_and_cannot_remember_getting_home() -> bool:
	for road: StringName in [&"caught", &"saved", &"alive"]:
		WorldState.reset()
		lines.clear()
		var story := _setup(ApartmentLayout.SPAWN)
		story.road = road
		_listen()
		_wait(StoryDirector.QUIET + 1.0)
		eq(WorldState.objective, StoryDirector.ROAD_OBJECTIVE, "road %s: the road's objective" % road)
		EventBus.object_interacted.emit(&"sink")
		eq(WorldState.objective, StoryDirector.ROAD_WASHED, "road %s: washed" % road)
		EventBus.object_interacted.emit(&"bed")
		_wait(12.0)
		var memory: String = StoryDirector.LAST_MEMORY[road]
		check(memory.contains("fruit stall" if road == &"caught" else "lorry"), "road %s: the road's last thing" % road)
		eq(lines.slice(-3), [StoryDirector.ROAD_WASH, memory, "[Somewhere in the building, a lift hums and stops.]"], "road %s: earth, the memory, the lift" % road)
		check(not lines.any(func(l: String) -> bool: return l.contains("teh tarik")), "road %s: no mamak at the sink" % road)
		_done()
	return true


func test_the_choice_opens_only_after_the_call_and_the_call_follows_the_road() -> bool:
	for road: StringName in [&"caught", &"saved", &"alive", &""]:
		for answer: bool in [true, false]:
			WorldState.reset()
			lines.clear()
			subtitles.clear()
			var story := _setup(Vector3(8.0, 0, -16.0))  # B-11-07
			story.road = road
			_listen()
			for i in 3:
				story.debug_skip()
			EventBus.object_interacted.emit(&"mirror_wall")
			EventBus.object_interacted.emit(&"lift_button")
			eq(WorldState.ending, &"", "%s/%s: no choice before the call" % [road, answer])
			check(not WorldState.prompts.has(&"mirror_wall"), "%s/%s: the wall only says touch" % [road, answer])
			if answer:
				check(_until(func() -> bool: return rt.scheduler.is_running(&"phone_ring"), 10.0), "%s: the intercom rings" % road)
				check(not story.choice_open(), "%s: ringing is not the choice" % road)
				EventBus.object_interacted.emit(&"intercom_mirror")
				check(story.choice_open(), "%s: answered, the choice opens" % road)
			else:
				check(not _until(func() -> bool: return story.choice_open(), 39.5), "%s: unanswered, not before 40 s" % road)
				check(_until(func() -> bool: return story.choice_open(), 1.0), "%s: unanswered, at 40 s" % road)
			eq(WorldState.prompts.get(&"mirror_wall"), "Answer it: knock back three times", "%s/%s: knock" % [road, answer])
			eq(WorldState.prompts.get(&"lift_button"), "Don't answer: take the lift", "%s/%s: lift" % [road, answer])
			_wait(30.0)
			var rule := "[Don't answer, Bang Din said. Even if it sounds like %s.]" % ("Hafiz" if road == &"saved" else "you")
			eq(lines.count(rule), 1 if road != &"" else 0, "%s/%s: Bang Din's rule after the road only" % [road, answer])
			if answer:
				var hafiz := road == &"saved"
				eq(subtitles.has(StoryDirector.HAFIZ_CALL), hafiz, "%s: Hafiz calls only after saved" % road)
				eq(lines.has("[It's Hafiz's voice.]"), hafiz, "%s: he knows Hafiz's voice" % road)
				eq(lines.has("[It's your voice.]"), not hafiz, "%s: or his own" % road)
				check(lines.find(rule) > lines.find("[It's Hafiz's voice.]" if hafiz else "[It's your voice.]") or road == &"", "%s: the rule after the voice: %s" % [road, lines])
			story.debug_skip()  # ends it: a story left open would still take the next one's wall
			_done()
	return true


func test_the_last_call_points_back_once() -> bool:
	var mei := "\"Eh, you going down ah? Jom, we got space.\""
	var hafiz := "\"Wah, so late still working ah? Kesian, bro.\""
	for road: StringName in [&"caught", &"saved", &"alive", &""]:
		_rosnah_answers(road, ENTRANCE)  # he does not touch the intercom again
		_wait(30.0)
		var calls := 1 if road in [&"caught", &"saved"] else 0
		eq(sounds.filter(func(s: Array) -> bool: return s[0] == &"intercom_road").size(), calls, "the wind and the engine, by itself, road %s" % road)
		eq(subtitles.count(CRACKLE), calls, "the crackle goes with the sound, as a sound caption, road %s" % road)
		eq(lines.count(CRACKLE), 0, "so it follows the captions setting, road %s" % road)
		eq(lines.count(mei), 1 if road == &"caught" else 0, "Mei's line, road %s" % road)
		eq(lines.count(hafiz), 1 if road == &"saved" else 0, "Hafiz's line, road %s" % road)
		_done()
	return true


## The flat from the road, he stands in the entrance, lies down, answers the ringing intercom: Rosnah's call is
## about 17 s of lines. Returns the story with the sounds, lines and subtitles cleared.
func _rosnah_answers(road: StringName, at: Vector3) -> StoryDirector:
	WorldState.reset()
	var story := _setup(at)
	story.road = road
	_listen()
	_wait(5.0)
	EventBus.object_interacted.emit(&"bed")
	check(_until(func() -> bool: return story.beat == &"ringing" and rt.scheduler.is_running(&"phone_ring"), 40.0), "the intercom rings")
	EventBus.object_interacted.emit(&"intercom")
	eq(story.beat, &"complained", "answered the real way")
	sounds.clear()
	lines.clear()
	subtitles.clear()
	heard.clear()
	return story


func _last_calls() -> int:
	return sounds.filter(func(s: Array) -> bool: return s[0] == &"intercom_road").size()


func test_the_last_call_waits_for_rosnah_to_finish() -> bool:
	var mei := "\"Eh, you going down ah? Jom, we got space.\""
	var story := _rosnah_answers(&"caught", ENTRANCE)
	eq(WorldState.player_room, &"entrance", "he stands by the intercom")
	var inspected: Array[String] = []
	var on_inspect := func(_title: String, text: String) -> void: inspected.append(text)
	EventBus.inspect_requested.connect(on_inspect)
	EventBus.object_interacted.emit(&"intercom")  # pressed at once, while her lines are queued
	_wait(5.0)
	EventBus.object_interacted.emit(&"intercom")  # and again, while she is still talking
	eq(_last_calls(), 0, "no wind and engine over her voice")
	eq(lines.count(mei), 0, "no last-call line while she talks")
	check(_until(func() -> bool: return story._lines.is_empty() and story._line_left > 0.0, 30.0), "her last line is on screen, the queue empty")
	inspected.clear()
	EventBus.object_interacted.emit(&"intercom")  # pressed while her last line is still showing
	eq(_last_calls(), 0, "nor over her last line")
	eq(lines.count(mei), 0, "no last-call line over her last line")
	check(inspected.size() == 1 and inspected[0].begins_with("LAST CALL  23:47"), "an early press still shows the inspect text")
	check(_until(func() -> bool: return _last_calls() > 0, 10.0), "the last call plays by itself")
	check(heard.has("[The line goes dead.]") and story._lines.size() == 2 and story._line_left <= 0.0, "once her last line has gone")
	_wait(10.0)
	eq(_last_calls(), 1, "once")
	eq(subtitles.count(CRACKLE), 1, "with the crackle, once")
	eq(lines.count(mei), 1, "with Mei's line, once")
	check(heard.find("[The line goes dead.]") < heard.find(CRACKLE) and heard.find(CRACKLE) < heard.find(mei), "in order: her call, the crackle, Mei")
	EventBus.object_interacted.emit(&"intercom")  # and never again
	_wait(10.0)
	eq(_last_calls(), 1, "pressing again plays nothing more")
	EventBus.inspect_requested.disconnect(on_inspect)
	return _done()


func test_the_last_call_plays_by_itself_wherever_he_is() -> bool:
	var mei := "\"Eh, you going down ah? Jom, we got space.\""
	var story := _rosnah_answers(&"caught", ENTRANCE)
	_wait(2.0)
	_place(ApartmentLayout.SPAWN)  # he walks out of the entrance, to the living room
	eq(_last_calls(), 0, "(her call is not over)")
	check(_until(func() -> bool: return _last_calls() > 0, 30.0), "it plays once her call is over, though he is away from the entrance")
	_wait(10.0)
	eq(_last_calls(), 1, "once")
	eq(lines.count(mei), 1, "with Mei's line, once")
	check(heard.find("[The line goes dead.]") < heard.find(CRACKLE) and heard.find(CRACKLE) < heard.find(mei), "in order: her call, the crackle, Mei")
	var inspected: Array[String] = []
	var on_inspect := func(_title: String, text: String) -> void: inspected.append(text)
	EventBus.inspect_requested.connect(on_inspect)
	_place(ENTRANCE)
	EventBus.object_interacted.emit(&"intercom")  # a later press shows the log, and plays nothing again
	_wait(10.0)
	check(inspected.size() == 1 and inspected[0].begins_with("LAST CALL  23:47"), "a later press shows the LAST CALL log")
	eq(_last_calls(), 1, "and the recording does not play again")
	eq(lines.count(mei), 1, "nor Mei's line")
	EventBus.inspect_requested.disconnect(on_inspect)
	return _done()


## It must not play over a knock: one that starts as her call ends holds it until the knock is done (1.6 s).
func test_the_last_call_waits_for_a_knock() -> bool:
	var story := _rosnah_answers(&"saved", ENTRANCE)
	check(_until(func() -> bool: return story._lines.is_empty() and story._line_left <= 1.0, 30.0), "her last line is nearly over")
	rt.scheduler.request(&"knock_wall", {"anchor": &"knock_entrance_door", "volume_db": 3.0}, 20)
	check(rt.scheduler.is_running(&"knock_wall"), "(a knock starts)")
	var steps := 0
	var knocking := true
	while _last_calls() == 0 and steps < 300:
		rt.step(0.1)
		steps += 1
		knocking = rt.scheduler.is_running(&"knock_wall")
	eq(_last_calls(), 1, "the last call plays")
	check(not knocking, "not over the knock")
	check(steps >= 14, "it waited for the knock: its last line had 1 s to go, the knock lasts 1.6 s (%d steps)" % steps)
	return _done()


func test_a_pending_last_call_never_plays_after_an_ending() -> bool:
	_rosnah_answers(&"caught", ENTRANCE)  # the last call is pending until her lines are done
	WorldState.set_ending(&"downstairs")
	_wait(40.0)
	eq(_last_calls(), 0, "the story is over: no last call")
	return _done()


func test_a_road_without_a_last_call_never_leaves_one_pending() -> bool:
	for road: StringName in [&"alive", &""]:
		_rosnah_answers(road, ENTRANCE)
		EventBus.object_interacted.emit(&"intercom")  # while she talks
		_wait(40.0)
		EventBus.object_interacted.emit(&"intercom")
		_wait(10.0)
		eq(_last_calls(), 0, "no last call for road %s" % road)
		eq(subtitles.count(CRACKLE) + lines.count(CRACKLE), 0, "no crackle for road %s" % road)
		_done()
	return true


func test_the_quiet_starts_on_the_first_tick_whatever_came_first() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	story.debug_skip()  # before any tick
	_wait(25.0)
	check(not story.quiet(), "the quiet ends 20 s after the first tick")
	return _done()


func _shifts_done() -> int:
	return WorldState.event_history.filter(func(e: Dictionary) -> bool: return e["id"] == &"shift" and e["result"] == &"completed").size()
