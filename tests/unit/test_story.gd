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
	eq(lines.count(StoryDirector.SMELL), 1, "and the smell is not said again with the answer")
	eq(StoryDirector.SMELL, Penanggal.SMELL, "the road's own line")
	return _done()


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


## Captions that wait for their turn (they come with no sound at that moment) keep the order they were said in, 3.0 s
## and the 0.3 s gap apart.
func test_sound_captions_keep_their_order() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	var at: Array = []  # [text, sim time] of ours
	var on_caption := func(text: String, _seconds: float) -> void:
		if text.begins_with("[Said"):
			at.append([text, WorldState.time])
	EventBus.subtitle_requested.connect(on_caption)
	story.say("[Said first]", 3.0)
	story.say("[Said second]", 3.0)
	_wait(4.0)
	EventBus.subtitle_requested.disconnect(on_caption)
	eq(at.map(func(a: Array) -> String: return a[0]), ["[Said first]", "[Said second]"], "in the order they were said")
	near(float(at[1][1]) - float(at[0][1]), 3.3, 0.15, "3.3 s apart: the first one's 3.0 s and the gap")
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
	EventBus.object_interacted.emit(_moved_object())
	_wait(12.0)
	eq(lines.count(StoryDirector.REVERSAL), 0, "no look-back line without the road")
	eq(lines, [], "no new lines at all")
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
		check(StoryDirector.ending_card(id, &"alive")[1].ends_with("Something else came down the mountain too."), "alive: %s" % id)
	return true


func test_the_last_call_points_back_once() -> bool:
	var mei := "\"Eh, you going down ah? Jom, we got space.\""
	var hafiz := "\"Wah, so late still working ah? Kesian, bro.\""
	for road: StringName in [&"caught", &"saved", &"alive", &""]:
		WorldState.reset()
		sounds.clear()
		lines.clear()
		subtitles.clear()
		var story := _setup(ApartmentLayout.SPAWN)
		story.road = road
		_listen()
		WorldState.set_flag(&"answered_intercom")
		EventBus.object_interacted.emit(&"intercom")
		EventBus.object_interacted.emit(&"intercom")
		_wait(10.0)
		var calls := 1 if road in [&"caught", &"saved"] else 0
		eq(sounds.filter(func(s: Array) -> bool: return s[0] == &"intercom_road").size(), calls, "the wind and the engine, road %s" % road)
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
	EventBus.object_interacted.emit(&"intercom")  # pressed again at once, while her lines are queued
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
	check(_until(func() -> bool: return _last_calls() > 0, 10.0), "he waits in the entrance: the last call plays by itself")
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


func test_the_last_call_stays_pending_when_he_leaves_the_entrance() -> bool:
	var mei := "\"Eh, you going down ah? Jom, we got space.\""
	var story := _rosnah_answers(&"caught", ENTRANCE)
	EventBus.object_interacted.emit(&"intercom")  # while she talks
	_wait(2.0)
	_place(ApartmentLayout.SPAWN)  # he walks out of the entrance, to the living room
	check(_until(func() -> bool: return story._lines.is_empty() and story._line_left <= 0.0, 30.0), "her call is over")
	_wait(30.0)
	eq(_last_calls(), 0, "nothing plays while he is away from the entrance")
	_place(ENTRANCE)  # and back, with nobody speaking
	_wait(5.0)
	eq(_last_calls(), 0, "nor when he walks back in: it waits for his press")
	eq(lines.count(mei), 0, "no road line either")
	EventBus.object_interacted.emit(&"intercom")  # his next press, with nobody speaking
	eq(_last_calls(), 1, "it plays at the press")
	_wait(10.0)
	eq(_last_calls(), 1, "once")
	eq(lines.count(mei), 1, "with Mei's line, once")
	return _done()


func test_a_pending_last_call_never_plays_after_an_ending() -> bool:
	_rosnah_answers(&"caught", ENTRANCE)
	EventBus.object_interacted.emit(&"intercom")  # while she talks: pending
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
