extends TestCase
## Mission 4, the car dies: on the long straight the engine and the lights die, Hafiz walks off to find help, and he
## and Mei wait while something thumps on the roof, speaks in Hafiz's voice and knocks on her window. The rules: don't
## open the door, and don't answer.

const RECALL := "[Bang Din: \"If the car dies, stay inside. Don't open the door. Don't answer, even if it sounds like your own mother.\"]"
const VOICE := "[Outside, in Hafiz's voice: \"Bro! Open the door, I found help!\"]"
const MEI := "Mei: \"That's him! I'm opening—\""
const MEI_LIGHT := "Mei: \"Eh, look. Got a light down there.\""
const KEPT_CUES: Array[StringName] = [
	&"lights_dying", &"crank", &"crank", &"hafiz_leaves", &"insects_stop", &"thump", &"her_on_roof", &"thump", &"thump",
	&"mei_reaches_door", &"knock_window", &"knock_window", &"knock_window", &"light_on",
]

var d: RoadDirector
var cues: Array[StringName] = []
var lines: Array = []  # [text, speaker]
var asked: Array = []  # [choice id, options]
var ended: Array[StringName] = []
var prompt_before_leaving := false  # the door's prompt was up before hafiz_leaves
var stopped_at := NAN  # car_s the step the car stood still
var stopped_after := NAN  # seconds from lights_dying to then
var _dying_at := NAN


func _setup() -> void:
	WorldState.reset()
	var list: Array[RoadMission] = [StallMission.new()]
	d = RoadDirector.new(RoadStage.new(), 1147, list)
	d.start_at(0)  # as if every mission before it was kept
	cues.clear()
	lines.clear()
	asked.clear()
	ended.clear()
	prompt_before_leaving = false
	stopped_at = NAN
	stopped_after = NAN
	_dying_at = NAN
	EventBus.road_cue.connect(_on_cue)
	EventBus.line_requested.connect(_on_line)
	EventBus.road_line.connect(_on_speaker)
	EventBus.choices_requested.connect(_on_asked)
	EventBus.road_ended.connect(_on_ended)


func _teardown() -> void:
	EventBus.road_cue.disconnect(_on_cue)
	EventBus.line_requested.disconnect(_on_line)
	EventBus.road_line.disconnect(_on_speaker)
	EventBus.choices_requested.disconnect(_on_asked)
	EventBus.road_ended.disconnect(_on_ended)


func _on_cue(cue: StringName) -> void:
	if cue != &"rule_broken":
		cues.append(cue)
	if cue == &"lights_dying":
		_dying_at = WorldState.time


func _on_line(text: String, _seconds: float) -> void:
	lines.append([text, &""])


func _on_speaker(speaker: StringName, _seconds: float) -> void:
	lines.back()[1] = speaker


func _on_asked(choice_id: StringName, options: PackedStringArray) -> void:
	asked.append([choice_id, Array(options)])


func _on_ended(ending: StringName) -> void:
	ended.append(ending)


## Plays the mission to the end. `answers` by choice id, one second after it opens (-1 or missing: silence); the door
## is used `door` times, one second apart, once its prompt is up.
func _play(answers: Dictionary, door := 0, limit := 300.0) -> void:
	var open_for := 0.0
	var door_for := 0.0
	for i in roundi(limit / 0.1):
		if d.ending != &"":
			return
		if d.pending != &"":
			open_for += 0.1
			if open_for >= 1.0 and answers.get(d.pending, -1) >= 0:
				EventBus.choice_made.emit(d.pending, answers[d.pending])
		else:
			open_for = 0.0
		if not cues.has(&"hafiz_leaves") and WorldState.prompts.get(&"car_door_inside", "") != "":
			prompt_before_leaving = true
		if door > 0 and cues.has(&"hafiz_leaves"):
			door_for += 0.1
			if door_for >= 1.0:
				door_for = 0.0
				door -= 1
				EventBus.object_interacted.emit(&"car_door_inside")
		var moving := d.car_speed > 0.0
		d.step(0.1)
		if moving and d.car_speed == 0.0 and is_nan(stopped_at):
			stopped_at = d.car_s
			stopped_after = WorldState.time - _dying_at


func _rules() -> Array:
	return d.broken.map(func(b: Dictionary) -> Array: return [b["rule"], b["weight"]])


func test_keeping_breaks_nothing() -> bool:
	_setup()
	eq([d.seated, d.car_s, d.car_speed], [true, 1800.0, 9.0], "skipped to: seated, cruising at 1800")
	_play({&"answer_voice": 1, &"stop_mei": 0})
	eq(d.score(), 0, "nothing broken")
	eq(cues, KEPT_CUES, "every cue, in order")
	eq(asked, [[&"answer_voice", ["\"Hafiz? That you?\"", "Stay quiet."]], [&"stop_mei", ["\"Mei, don't. That's not him.\"", "\"Okay, open.\""]]], "the two choices, word for word")
	eq(lines.filter(func(l: Array) -> bool: return l[0] == RECALL).size(), 1, "Bang Din's rule, once")
	check(lines.any(func(l: Array) -> bool: return l == [VOICE, &""]), "the voice outside, bracketed, with no speaker in the car")
	check(lines.any(func(l: Array) -> bool: return l == [MEI, &"mei"]), "Mei, who thinks it is him")
	check(lines.back() == [MEI_LIGHT, &"mei"], "and Mei sees the light, last, before the mission is over")
	eq(lines.filter(func(l: Array) -> bool: return String(l[0]).begins_with("Hafiz: \"") and l[1] == &"hafiz").size(), 2, "Hafiz's two lines before he goes")
	eq(ended, [&"alive"], "the mission is done")
	eq([WorldState.objective, WorldState.prompts.get(&"car_door_inside", "")], ["", ""], "its objective and the door's prompt go with it")
	_teardown()
	return true


func test_the_door_prompt_comes_only_after_hafiz_leaves() -> bool:
	_setup()
	for i in 600:
		if cues.has(&"hafiz_leaves"):
			break
		if WorldState.prompts.get(&"car_door_inside", "") != "":
			prompt_before_leaving = true
		EventBus.object_interacted.emit(&"car_door_inside")  # he tries the door all the while
		d.step(0.1)
	check(cues.has(&"hafiz_leaves"), "(Hafiz leaves)")
	check(not prompt_before_leaving, "no prompt on the door before then")
	eq(d.broken, [] as Array[Dictionary], "and trying it does nothing")
	eq(WorldState.prompts.get(&"car_door_inside", ""), "Open the door", "from then, the door can be opened")
	eq(WorldState.objective, "Stay in the car. Don't open the door. Don't answer.", "the objective")
	_teardown()
	return true


func test_opening_the_door_costs_two_once() -> bool:
	_setup()
	_play({&"answer_voice": 1, &"stop_mei": 0}, 2)
	eq(_rules(), [[&"opened_door", 2]], "one broken rule, weight 2, for two tries")
	eq(cues.count(&"door_cracked"), 1, "the door opens a hand's width and is slapped shut once")
	check(cues.find(&"door_cracked") > cues.find(&"hafiz_leaves"), "after Hafiz has gone")
	eq(WorldState.prompts.get(&"car_door_inside", ""), "", "the prompt is gone after it")
	_teardown()
	_setup()  # the prompt goes at once, not at the mission's end
	_play({&"answer_voice": 1, &"stop_mei": 0}, 1, 60.0)
	eq(cues.count(&"door_cracked"), 1, "(opened once)")
	eq(WorldState.prompts.get(&"car_door_inside", ""), "", "and the prompt is gone straight after")
	_teardown()
	return true


## Once the light is on and Mei has pointed at it, the door is the way on, not a break: its prompt goes.
func test_the_door_prompt_goes_when_the_light_comes_on() -> bool:
	_setup()
	while not cues.has(&"light_on") and WorldState.time < 300.0:
		if d.pending != &"":
			EventBus.choice_made.emit(d.pending, 1 if d.pending == &"answer_voice" else 0)
		d.step(0.1)
	eq(WorldState.prompts.get(&"car_door_inside", ""), "", "no prompt on the door once the light is on")
	EventBus.object_interacted.emit(&"car_door_inside")
	eq(d.broken, [] as Array[Dictionary], "and using it breaks nothing")
	_teardown()
	return true


func test_silence_lets_mei_open() -> bool:
	_setup()
	_play({&"answer_voice": 1})
	eq(_rules(), [[&"mei_opened", 1]], "she opens it")
	eq(cues.count(&"mei_door_cracked"), 1, "and it is slapped shut")
	check(cues.find(&"mei_door_cracked") < cues.find(&"knock_window"), "before the knocks")
	_teardown()
	_setup()
	_play({&"answer_voice": 1, &"stop_mei": 1})
	eq(_rules(), [[&"mei_opened", 1]], "\"Okay, open.\" lets her too")
	_teardown()
	_setup()
	_play({})
	eq(_rules(), [[&"mei_opened", 1]], "staying quiet for the voice keeps that rule")
	_teardown()
	_setup()
	_play({&"answer_voice": 0, &"stop_mei": 0})
	eq(_rules(), [[&"answered", 1]], "answering the voice breaks it")
	_teardown()
	return true


func test_the_light_is_150_m_on() -> bool:
	_setup()
	_play({&"answer_voice": 1, &"stop_mei": 0}, 0, 30.0)
	near(stopped_at, 2000.0, 2.0, "the car stands on the long straight, about where the next mission takes it up")
	near(stopped_after, 4.0, 0.15, "its speed eases to nothing over 4 s")
	near(d.light_s, stopped_at + 150.0, 0.001, "the light is 150 m on from where it stood")
	_teardown()
	_setup()
	eq(d.light_s, -1.0, "skipped to: no light yet")
	d.car_s = 1995.0  # later than the stall's own start: it dies at once, and stands a little further on
	_play({&"answer_voice": 1, &"stop_mei": 0}, 0, 30.0)
	check(stopped_at > 2000.0, "past the usual stop (%.1f)" % stopped_at)
	near(d.light_s, stopped_at + 150.0, 0.001, "still 150 m on")
	_teardown()
	return true
