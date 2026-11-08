extends TestCase
## Mission 5, don't look back: he gets out of the dead car, and he and Mei walk 150 m down the road to the light at a
## closed fruit stall while something follows behind them. The rules: don't look back, keep Mei from looking, and keep
## walking: she comes in as he slows, breathes down his neck once she is half way, and catches him if he stands still for
## 5 s (the clock starts once Bang Din has said so). 30 m short of the light the road's count decides how it ends; that
## ending plays, and the road is over.

const RECALL := "[Bang Din: \"When it goes quiet, walk to the light. Whatever is behind you, don't look back.\"]"
const KEEP_WALKING := "[Bang Din: \"And keep walking. Stop, and it catches up.\"]"
const VOICE := "[Behind you, Hafiz's voice: \"Mei! Wait for me!\"]"
const LOOKS := "[Mei looks back.]"
const OPTIONS := ["\"Don't look. Hold my hand.\"", "\"Maybe it's him.\""]
const BESIDE := 3.3  # metres across: where he stands up beside his door (the car in its lane, 1.5 m to its left)
const WALK := 2.2  # m/s
const HAFIZ := "Hafiz: \"Eh! Found this uncle, he's going down. Jom.\""

var d: RoadDirector
var stage: RoadStage
var cues: Array[StringName] = []
var cue_s := {}  # cue -> his s along the road when it first came
var cue_t := {}  # cue -> the time it first came
var said_t := {}  # line -> the time it was first said
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
	cue_t.clear()
	said_t.clear()
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
		cue_t[cue] = WorldState.time


func _on_line(text: String, _seconds: float) -> void:
	lines.append([text, &""])
	if not said_t.has(text):
		said_t[text] = WorldState.time


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


## `seconds` of 0.1 s steps from beside the car, he creeping on at `pace` m/s along the road (0: the stage stays put).
func _creep(pace: float, seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		if pace > 0.0:
			stage.position = RoadLayout.point(RoadLayout.closest_s(stage.position) + pace * 0.1, BESIDE)
		d.step(0.1)


## Stands still, as he does when the walk is skipped to, until Bang Din has said keep walking: the still clock waits for it.
func _hear_keep_walking() -> void:
	for i in 100:
		if said_t.has(KEEP_WALKING):
			return
		d.step(0.1)


func _rules() -> Array:
	return d.broken.map(func(b: Dictionary) -> Array: return [b["rule"], b["weight"]])


func test_getting_out_and_keeping_every_rule() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	eq(prompt_was, "Get out", "the door's prompt, from his seat")
	check(cues.size() > 0 and cues[0] == &"get_out", "using it gets him out first (%s)" % [cues])
	check(not d.seated, "and he stands")
	eq(d.score(), 0, "nothing broken: getting out is not a break")
	eq(d.dead, &"", "and he is alive")
	eq(lines.filter(func(l: Array) -> bool: return l == [RECALL, &""]).size(), 1, "Bang Din's rule, once, as a thought")
	check(cues.has(&"her_behind"), "she follows behind them")
	eq(asked, [[&"mei_look_1", OPTIONS], [&"mei_look_2", OPTIONS]], "Mei wants to look twice: the choices, word for word")
	var way := d.light_s - (d.car_s - 0.5)  # from beside his door to the light
	if asked_s.size() == 2:
		near(asked_s[0] - (d.car_s - 0.5), 0.3 * way, 0.5, "the first 30 % of the way")
		near(asked_s[1] - (d.car_s - 0.5), 0.65 * way, 0.5, "the second 65 %")
	eq(lines.filter(func(l: Array) -> bool: return l == [VOICE, &""]).size(), 2, "the voice behind them each time, with no speaker turn")
	check(not cues.has(&"mei_looks"), "she never looks")
	check(cues.has(&"hafiz_at_stall") and not cues.has(&"light_out") and not cues.has(&"phone_rings") and not cues.has(&"lorry_stops"), "Hafiz comes to the stall")
	var order := [&"hafiz_at_stall", &"walk_over", &"lorry_flagged", &"card_on"].map(func(c: StringName) -> int: return cues.find(c))
	check(order[0] >= 0 and order[0] < order[1] and order[1] < order[2] and order[2] < order[3], "they get there, the lorry he flagged down comes, then the card (%s)" % [order])
	near(said_t.get(HAFIZ, INF) - cue_t.get(&"lorry_flagged", -INF), LightMission.ALIVE_HAFIZ, 0.11, "once it has pulled up, he says so")
	check(lines.any(func(l: Array) -> bool: return l == [HAFIZ, &"hafiz"]), "in his voice")
	check(lines.back() == ["[The lorry takes the three of you down the mountain.]", &""], "and how it ends, last")
	eq(ended, [&"alive"], "all three alive")
	eq([WorldState.objective, WorldState.prompts.get(&"car_door_inside", "")], ["", ""], "its objective and the prompt go with it")
	_teardown()
	return true


## Seated in the dead car, he is told where to go before he gets out: nothing else says the door is the way on now.
func test_from_his_seat_he_is_told_to_walk_to_the_light() -> bool:
	_setup()
	d.step(0.1)
	d.step(0.1)
	eq(_mission().beat, &"get_out", "he has not got out yet")
	eq(WorldState.objective, LightMission.OBJECTIVE, "the objective is up")
	check(said_t.has(RECALL), "and Bang Din's rule comes back to him")
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


func test_looking_back_kills_him() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0}, [10.0, 30.0, 50.0])
	eq([d.dead, d.score()], [&"looked_back", 0], "a look back kills him, and counts for nothing")
	eq(cues.count(&"her_lunges"), 0, "and she makes no lunge of it")
	_teardown()
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0}, [128.0])  # past the point where the ending is decided
	eq(_rules(), [], "once the ending is decided, a look back costs nothing")
	eq(d.dead, &"", "and does not kill him")
	_teardown()
	return true


func test_letting_mei_look_costs_two_each() -> bool:
	_setup()
	_play({})
	eq(_rules(), [[&"mei_looked", 2], [&"mei_looked", 2]], "both unanswered: she looks back twice")
	eq([d.score(), d.dead], [4, &""], "it costs four, and not his life")
	eq(cues.count(&"mei_looks"), 2, "and is seen to")
	eq(lines.filter(func(l: Array) -> bool: return l == [LOOKS, &""]).size(), 2, "and told, with no speaker: she is out of his view ahead")
	_teardown()
	_setup()
	_play({&"mei_look_1": 1, &"mei_look_2": 0})
	eq(_rules(), [[&"mei_looked", 2]], "\"Maybe it's him.\" lets her too")
	_teardown()
	return true


func test_reaching_the_light_ends_the_road() -> bool:
	_setup()
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	near(walk_ended_s, d.light_s - 4.0, WALK * 0.1 + 0.01, "the walk is done 4 m short of the light")
	eq(cues.count(&"walk_over"), 1, "said once")
	near(cue_s.get(&"walk_over", INF), d.light_s - 4.0, WALK * 0.1 + 0.01, "there")
	near(cue_s[&"hafiz_at_stall"], d.light_s - 30.0, WALK * 0.1 + 0.01, "decided 30 m short: Hafiz walks up to the stall")
	near(cue_s.get(&"lorry_flagged", INF), d.light_s - 4.0, WALK * 0.1 + 0.01, "and the lorry he flagged down comes once they are there")
	eq(ended, [&"alive"], "the road ends, alive, once")
	_teardown()
	return true


func test_two_get_out_alone() -> bool:
	_setup()
	d.break_rule(&"overtook", 3)  # as if broken earlier on the road
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
	d.break_rule(&"overtook", 7)  # score 7 before the walk
	_play({&"mei_look_1": 0, &"mei_look_2": 0})
	near(cue_s[&"light_out"], d.light_s - 30.0, WALK * 0.1 + 0.01, "the light dies 30 m short")
	near(walk_ended_s, d.light_s - 30.0, WALK * 0.1 + 0.01, "and the walk is over there")
	near(cue_s.get(&"walk_over", INF), d.light_s - 30.0, WALK * 0.1 + 0.01, "said there")
	eq(cues.count(&"walk_over"), 1, "once")
	check(lines.any(func(l: Array) -> bool: return l == ["Hafiz: \"Mei? Bro?\"", &"hafiz"]), "Hafiz, out of the fog ahead")
	var order := [&"light_out", &"her_catches_hafiz", &"her_comes"].map(func(c: StringName) -> int: return cues.find(c))
	check(order[0] >= 0 and order[0] < order[1] and order[1] < order[2], "she catches Hafiz, then comes for them (%s)" % [order])
	check(not cues.has(&"card_on"), "the card is hers to bring, with no caption")
	eq(ended, [&"caught"], "all three caught")
	_teardown()
	return true


func test_every_choice_closes_after_three_seconds() -> bool:
	_setup(false)  # standing beside the car: he walks at once
	var s := RoadLayout.closest_s(stage.position)
	for i in 1000:
		if d.pending != &"":
			break
		s += WALK * 0.1
		stage.position = RoadLayout.point(s, BESIDE)
		d.step(0.1)
	eq(d.pending, &"mei_look_1", "the first choice is open")
	for i in 29:
		d.step(0.1)
	eq(d.pending, &"mei_look_1", "and still open after 2.9 s")
	for i in 2:
		d.step(0.1)
	eq(d.pending, &"", "closed after 3.1 s")
	_teardown()
	return true


## Seated, Bang Din's rule comes back to him, and straight after it what to do on the walk.
func test_bang_din_says_keep_walking() -> bool:
	_setup()
	for i in 70:
		d.step(0.1)
	eq(lines.slice(0, 2), [[RECALL, &""], [KEEP_WALKING, &""]], "keep walking follows the rule, a thought with no speaker")
	_teardown()
	return true


func test_standing_still_for_five_seconds_kills_him() -> bool:
	_setup(false)  # standing beside the car: he walks at once
	_hear_keep_walking()
	check(said_t.has(KEEP_WALKING), "Bang Din says it (%.1f s)" % said_t.get(KEEP_WALKING, -1.0))
	eq([d.dead, d.closing], [&"", 0.0], "standing still while he is told to keep walking costs nothing")
	_creep(0.0, 4.9)
	eq(d.dead, &"", "alive 4.9 s after")
	near(d.closing, 0.98, 0.001, "and she is that near")
	_creep(0.0, 0.1)
	eq(d.dead, &"stood_still", "dead 5.0 s after")
	near(WorldState.time - said_t[KEEP_WALKING], LightMission.STILL_SECONDS, 0.001, "to the step")
	eq(d.score(), 0, "and it counts for nothing")
	_teardown()
	return true


func test_she_breathes_down_his_neck_once_each_time_she_is_half_way() -> bool:
	_setup(false)
	_hear_keep_walking()
	_creep(0.0, 2.4)
	eq(cues.count(&"she_closes"), 0, "not yet at 2.4 s, with her under half way")
	_creep(0.0, 0.3)
	eq(cues.count(&"she_closes"), 1, "past half way: her breath, once")
	_creep(0.0, 2.0)
	eq(cues.count(&"she_closes"), 1, "and not again as she comes on")
	_creep(WALK, 0.1)
	_creep(0.0, 3.0)
	eq(cues.count(&"she_closes"), 2, "once he has walked and stopped again, she does")
	eq(d.dead, &"", "alive")
	_teardown()
	return true


func test_walking_slowly_brings_her_closer_and_walking_sends_her_back() -> bool:
	_setup(false)
	_hear_keep_walking()
	_creep(0.2, 2.5)  # under MIN_PACE
	near(d.closing, 0.5, 0.05, "half the time to the kill: she is half way")
	_creep(WALK, 0.1)
	eq(d.closing, 0.0, "one step at a walk and she is back")
	eq(d.dead, &"", "and he is alive")
	_teardown()
	return true


func test_no_still_check_once_the_ending_is_decided() -> bool:
	_setup(false)
	for i in 2000:  # at a walk to 0.4 m short of where it is decided
		if RoadLayout.closest_s(stage.position) >= d.light_s - LightMission.DECIDE - 0.4:
			break
		_creep(WALK, 0.1)
	_creep(0.2, 1.0)
	check(d.closing > 0.0, "slow, she comes in (%.2f)" % d.closing)
	for i in 100:
		if _mission()._decided != &"":
			break
		_creep(0.2, 0.1)
	check(_mission()._decided != &"", "and then it is decided")
	eq(d.closing, 0.0, "the step the ending is decided, she is back")
	_creep(0.0, 10.0)
	eq(d.dead, &"", "standing still 10 s now does not kill him")
	eq(d.closing, 0.0, "nor bring her in")
	_teardown()
	return true
