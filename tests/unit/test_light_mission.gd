extends TestCase
## Mission 5, don't look back: he gets out of the dead car, and he and Mei walk 150 m down the road to the light at a
## closed fruit stall while something follows behind them. The rules: don't look back, and keep Mei from looking.
## 30 m short of the light the road's count decides how it ends; that ending plays, and the road is over.

const RECALL := "[Bang Din: \"When it goes quiet, walk to the light. Whatever is behind you, don't look back.\"]"
const VOICE := "[Behind you, Hafiz's voice: \"Mei! Wait for me!\"]"
const OPTIONS := ["\"Don't look. Hold my hand.\"", "\"Maybe it's him.\""]
const BESIDE := 3.3  # metres across: where he stands up beside his door (the car in its lane, 1.5 m to its left)
const WALK := 2.2  # m/s

var d: RoadDirector
var stage: RoadStage
var cues: Array[StringName] = []
var cue_s := {}  # cue -> his s along the road when it first came
var lines: Array = []  # [text, speaker]
var asked: Array = []  # [choice id, options]
var asked_s: Array[float] = []  # his s along the road as each was asked
var ended: Array[StringName] = []
var walk_ended_s := NAN  # his s when the walk was over
var prompt_was := ""  # the door's prompt before he got out


func _setup(from_the_car := true) -> void:
	WorldState.reset()
	stage = RoadStage.new()
	var list: Array[RoadMission] = [LightMission.new()]
	d = RoadDirector.new(stage, 1147, list)
	d.start_at(0)  # as if every mission before it was kept: standing beside the car
	if from_the_car:
		d.seated = true  # as Mission 4 leaves him
	stage.position = RoadLayout.point(d.car_s - 0.5, BESIDE)
	cues.clear()
	cue_s.clear()
	lines.clear()
	asked.clear()
	asked_s.clear()
	ended.clear()
	walk_ended_s = NAN
	prompt_was = ""
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
	if cue == &"rule_broken":
		return
	cues.append(cue)
	if not cue_s.has(cue):
		cue_s[cue] = RoadLayout.closest_s(stage.position)


func _on_line(text: String, _seconds: float) -> void:
	lines.append([text, &""])


func _on_speaker(speaker: StringName, _seconds: float) -> void:
	lines.back()[1] = speaker


func _on_asked(choice_id: StringName, options: PackedStringArray) -> void:
	asked.append([choice_id, Array(options)])
	asked_s.append(RoadLayout.closest_s(stage.position))


func _on_ended(ending: StringName) -> void:
	ended.append(ending)


func _mission() -> LightMission:
	return d.missions[0] as LightMission


## Plays the mission to the end, walking down the road at WALK while the walk lasts. `answers` by choice id, one second
## after it opens (missing: silence). He gets out half a second after the door's prompt shows. `looks`: metres walked
## at which he looks straight back for a second.
func _play(answers: Dictionary, looks: Array = [], limit := 300.0) -> void:
	var open_for := 0.0
	var prompt_for := 0.0
	var start_s := RoadLayout.closest_s(stage.position)
	var look_until := -1.0
	for i in roundi(limit / 0.1):
		if d.ending != &"":
			return
		if d.pending != &"":
			open_for += 0.1
			if open_for >= 1.0 and answers.has(d.pending):
				EventBus.choice_made.emit(d.pending, answers[d.pending])
		else:
			open_for = 0.0
		var prompt: String = WorldState.prompts.get(&"car_door_inside", "")
		if prompt != "":
			prompt_was = prompt
			prompt_for += 0.1
			if prompt_for >= 0.5:
				EventBus.object_interacted.emit(&"car_door_inside")
		var m := _mission()
		var s := RoadLayout.closest_s(stage.position)
		if m.beat == &"walk":
			for at: float in looks:
				if s - start_s >= at and s - start_s - WALK * 0.1 < at:
					look_until = WorldState.time + 1.0
			stage.view_yaw = PI if WorldState.time < look_until else 0.0
			stage.position = RoadLayout.point(s + WALK * 0.1, BESIDE)
		d.step(0.1)
		if m.beat != &"walk" and m.beat != &"get_out" and is_nan(walk_ended_s):
			walk_ended_s = RoadLayout.closest_s(stage.position)


func _rules() -> Array:
	return d.broken.map(func(b: Dictionary) -> Array: return [b["rule"], b["weight"]])


func test_getting_out_and_keeping_every_rule() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	eq(prompt_was, "Get out", "the door's prompt, from his seat")
	check(cues.size() > 0 and cues[0] == &"get_out", "using it gets him out first (%s)" % [cues])
	check(not d.seated, "and he stands")
	eq(d.score(), 0, "nothing broken: getting out is not a break")
	eq(lines.filter(func(l: Array) -> bool: return l == [RECALL, &""]).size(), 1, "Bang Din's rule, once, as a thought")
	check(cues.has(&"her_behind"), "she follows behind them")
	eq(asked, [[&"mei_look_1", OPTIONS], [&"mei_look_2", OPTIONS]], "Mei wants to look twice: the choices, word for word")
	var way := d.light_s - (d.car_s - 0.5)  # from beside his door to the light
	if asked_s.size() == 2:
		near(asked_s[0] - (d.car_s - 0.5), 0.3 * way, 0.5, "the first 30 % of the way")
		near(asked_s[1] - (d.car_s - 0.5), 0.65 * way, 0.5, "the second 65 %")
	eq(lines.filter(func(l: Array) -> bool: return l == [VOICE, &""]).size(), 2, "the voice behind them each time, with no speaker turn")
	check(not cues.has(&"mei_looks"), "she never looks")
	check(cues.has(&"hafiz_at_stall") and not cues.has(&"light_out") and not cues.has(&"phone_rings"), "Hafiz waits at the stall")
	check(lines.any(func(l: Array) -> bool: return l == ["Hafiz: \"Eh! Found this uncle, he's going down. Jom.\"", &"hafiz"]), "and says so")
	check(cues.find(&"card_on") > cues.find(&"hafiz_at_stall"), "then the card")
	check(lines.back() == ["[The lorry takes the three of you down the mountain.]", &""], "and how it ends, last")
	eq(ended, [&"alive"], "all three alive")
	eq([WorldState.objective, WorldState.prompts.get(&"car_door_inside", "")], ["", ""], "its objective and the prompt go with it")
	_teardown()
	return true


func test_skipped_to_he_stands_beside_the_car() -> bool:
	_setup(false)
	eq([d.seated, d.car_s, d.car_speed, d.light_s], [false, 2000.0, 0.0, 2150.0], "skipped to: standing, the car at 2000, the light at 2150")
	d.step(0.1)
	eq(_mission().beat, &"walk", "he walks at once")
	eq(WorldState.prompts.get(&"car_door_inside", ""), "", "with no door to get out of")
	eq(WorldState.objective, "Walk to the light. Don't look back.", "the objective")
	eq(d.look_rule, &"looked_back", "and his look is watched")
	_teardown()
	return true


func test_looking_back_costs_three_twice_at_most() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0}, [10.0, 30.0, 50.0])  # back to the front between each
	eq(_rules(), [[&"looked_back", 3], [&"looked_back", 3]], "three looks back: 3 each, twice at the most")
	_teardown()
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0}, [128.0])  # past the point where the ending is decided
	eq(_rules(), [], "once the ending is decided, a look back costs nothing")
	_teardown()
	return true


func test_silence_lets_mei_look() -> bool:
	_setup()
	_play({})
	eq(_rules(), [[&"mei_looked", 1], [&"mei_looked", 1]], "both unanswered: she looks back twice")
	eq(cues.count(&"mei_looks"), 2, "and is seen to")
	_teardown()
	_setup()
	_play({&"mei_look_1": 1, &"mei_look_2": 0})
	eq(_rules(), [[&"mei_looked", 1]], "\"Maybe it's him.\" lets her too")
	_teardown()
	return true


func test_reaching_the_light_ends_the_road() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	near(walk_ended_s, d.light_s - 4.0, WALK * 0.1 + 0.01, "the walk is done 4 m short of the light")
	near(cue_s[&"hafiz_at_stall"], d.light_s - 30.0, WALK * 0.1 + 0.01, "decided 30 m short: Hafiz is there, waiting")
	eq(ended, [&"alive"], "the road ends, alive, once")
	_teardown()
	return true


func test_two_get_out_alone() -> bool:
	_setup()
	d.break_rule(&"answered", 3)  # as if broken earlier on the road
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	check(not cues.has(&"hafiz_at_stall"), "nobody at the stall")
	var order := [&"phone_rings", &"lorry_stops", &"card_on"].map(func(c: StringName) -> int: return cues.find(c))
	check(order[0] >= 0 and order[0] < order[1] and order[1] < order[2], "his phone rings on the table, a lorry stops, the card (%s)" % [order])
	check(lines.any(func(l: Array) -> bool: return l == ["Mei: \"That's his phone…\"", &"mei"]), "Mei knows his phone")
	check(lines.back() == ["[The lorry takes the two of you down the mountain.]", &""], "and the two of them go down")
	eq(ended, [&"saved"], "he gets Mei out")
	_teardown()
	return true


func test_caught_ends_before_the_light() -> bool:
	_setup()
	d.break_rule(&"answered", 7)  # score 7 before the walk
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	near(cue_s[&"light_out"], d.light_s - 30.0, WALK * 0.1 + 0.01, "the light dies 30 m short")
	near(walk_ended_s, d.light_s - 30.0, WALK * 0.1 + 0.01, "and the walk is over there")
	check(lines.any(func(l: Array) -> bool: return l == ["Hafiz: \"Mei? Bro?\"", &"hafiz"]), "Hafiz, out of the fog ahead")
	var order := [&"light_out", &"her_catches_hafiz", &"her_comes"].map(func(c: StringName) -> int: return cues.find(c))
	check(order[0] >= 0 and order[0] < order[1] and order[1] < order[2], "she catches Hafiz, then comes for them (%s)" % [order])
	check(not cues.has(&"card_on"), "the card is hers to bring, with no caption")
	eq(ended, [&"caught"], "all three caught")
	_teardown()
	return true
