extends TestCase
## Mission 3, the extra passenger: a fourth sits beside him, seen only in the rear-view mirror. He must not turn round
## to look at her, and must not count her.

const RECALL := "[Bang Din: \"If they say there's one more in the car, don't turn to look. And don't count her.\"]"
const COUNT := [
	"Mei: \"Eh, how many of us ah? I want to buy drinks at the R&R.\"",
	"Hafiz: \"Four people in this small car, also nobody talk.\"",
]
const THREE := "Mei: \"Three? Then who's sitting—\""
const COUNTING := "Mei: \"Four meh? Wait, I count. One, two...\""
const OBJECTIVE := "Don't turn round. Don't count her."

var stage: RoadStage
var d: RoadDirector
var cues: Array[StringName] = []
var captions: Array[String] = []
var asked: Array[StringName] = []
var ended: Array[StringName] = []
var _answers := {}  # choice id -> his answer, given a step after it opens; ids not here stay silent
var _open: StringName = &""


## A mission after this one that never finishes, so the director stays on it.
class Idle extends RoadMission:
	func tick(_delta: float) -> bool:
		return false


## The count mission alone, started as `--mission` starts it. `answers`: what he says to each choice.
func _setup(answers := {}, then_idle := false) -> void:
	stage = RoadStage.new()
	var list: Array[RoadMission] = [CountMission.new()]
	if then_idle:
		list.append(Idle.new())
	d = RoadDirector.new(stage, 1147, list)
	d.start_at(0)
	_answers = answers
	_open = &""
	cues.clear()
	captions.clear()
	asked.clear()
	ended.clear()
	EventBus.road_cue.connect(_on_cue)
	EventBus.line_requested.connect(_on_caption)
	EventBus.choices_requested.connect(_on_choices)
	EventBus.road_ended.connect(_on_ended)


func _teardown() -> void:
	EventBus.road_cue.disconnect(_on_cue)
	EventBus.line_requested.disconnect(_on_caption)
	EventBus.choices_requested.disconnect(_on_choices)
	EventBus.road_ended.disconnect(_on_ended)


func _on_cue(cue: StringName) -> void:
	cues.append(cue)


func _on_caption(text: String, _seconds: float) -> void:
	captions.append(text)


func _on_choices(choice_id: StringName, _options: PackedStringArray) -> void:
	asked.append(choice_id)
	_open = choice_id


func _on_ended(ending: StringName) -> void:
	ended.append(ending)


func _run(seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		_step()


## To the end of the mission, at most two minutes.
func _finish() -> void:
	for i in 1200:
		if d.mission_index > 0:
			return
		_step()


func _step() -> void:
	d.step(0.1)
	if _open != &"" and _answers.has(_open):
		EventBus.choice_made.emit(_open, _answers[_open])
	_open = &""


func _rules() -> Array:
	return d.broken.map(func(b: Dictionary) -> StringName: return b["rule"])


func test_keeping_breaks_nothing() -> bool:
	_setup({&"count": 0})
	eq([d.seated, d.car_s, d.car_speed, is_nan(d.slow_gap)], [true, 900.0, CountMission.CRUISE_SPEED, true],
		"set up as if the earlier missions were kept: seated at s 900, cruising, no slow car")
	_run(0.2)
	eq(cues, [&"mirror_on"], "the mirror comes on")
	eq(d.look_rule, &"", "but his look is not watched yet: he has not been told")
	_run(12.0)
	eq(d.look_rule, &"turned_round", "his look is watched once Bang Din has said it")
	var recall := captions.find(RECALL)
	check(recall > 0, "Bang Din's rule, word for word")
	check(captions.slice(0, recall).any(func(c: String) -> bool: return c.contains("your friend")), "after the couple talk about \"your friend\"")
	eq(WorldState.objective, OBJECTIVE, "the objective")
	_finish()
	var asking := captions.find(COUNT[0])
	check(asking > recall and captions.find(COUNT[1]) == asking + 1, "Mei asks how many, and Hafiz counts four")
	check(captions.find(THREE) > asking, "then Mei: three?")
	check(not captions.has(COUNTING), "with no counting first")
	eq(asked, [&"count"], "asked once")
	eq(cues, [&"mirror_on", &"brake", &"fourth_gone", &"mirror_off"], "the cues in order")
	_run(0.3)  # the thought is said on the step after the mission ends
	eq(captions.back(), CountMission.NOBODY, "and nobody says anything: Hafiz drives faster")
	eq(d.score(), 0, "nothing broken")
	eq(d.dead, &"", "and he is alive")
	eq([d.look_rule, WorldState.objective], [&"", ""], "the look watch and the objective end with it")
	eq(ended, [&"alive"], "the road ends after it, all alive")
	_teardown()
	return true


## "Your friend so quiet one" makes him turn, and nobody has told him the rule yet: that costs nothing.
func test_turning_before_bang_din_says_the_rule_costs_nothing() -> bool:
	_setup({&"count": 0})
	stage.view_yaw = -1.3  # to his right, where she sits, held from the start
	_run(8.0)
	eq(captions.find(RECALL), -1, "(Bang Din has not said it yet)")
	eq(_rules(), [], "turning to her breaks nothing")
	eq(d.dead, &"", "and does not kill him")
	check(not cues.has(&"fourth_glimpse"), "and shows her to him no more than before")
	_run(4.0)  # he is still turned when the rule is said: now it breaks
	check(captions.has(RECALL), "(Bang Din has said it)")
	eq(d.dead, &"turned_round", "turning to her after it kills him")
	_teardown()
	return true


func test_turning_to_her_kills_him() -> bool:
	_setup({&"count": 0})
	_run(10.0)  # the rule is said at 9 s
	stage.view_yaw = -1.3  # to his right, where she sits
	_run(2.0)
	eq([d.dead, d.score()], [&"turned_round", 0], "turning to her kills him, and counts for nothing")
	_teardown()
	return true


func test_looking_out_of_his_own_window_is_allowed() -> bool:
	_setup({&"count": 0})
	stage.view_yaw = 1.6  # to his left, out of his own window
	_run(13.0)  # past the rule's being said
	eq(_rules(), [], "his own window: no break")
	eq(d.dead, &"", "and no death")
	check(not cues.has(&"fourth_glimpse"), "and no glimpse of her")
	_teardown()
	return true


func test_why_asks_again_and_silence_keeps() -> bool:
	_setup({&"count": 2})  # "Why you ask?", then nothing
	_finish()
	eq(asked, [&"count", &"count_again"], "asked again")
	check(d.progress.any(func(p: Dictionary) -> bool: return p["beat"] == &"asked_again"), "the asked_again beat")
	eq(d.answer(&"count_again"), -1, "he says nothing")
	check(not captions.has(COUNTING), "so Mei doesn't count")
	eq(d.score(), 0, "which keeps the rule")
	eq(d.dead, &"", "and he lives")
	eq(cues.slice(-2), [&"fourth_gone", &"mirror_off"], "and the mission ends as kept")
	_teardown()
	return true


func test_four_kills_him() -> bool:
	_setup({&"count": 1})
	_finish()
	eq(d.dead, &"counted_her", "\"Four.\" counts her: he dies")
	eq(asked, [&"count"], "and isn't asked again")
	check(not captions.has(COUNTING), "Mei counts no heads")
	_teardown()
	return true


func test_a_skip_leaves_no_mirror_look_or_objective() -> bool:
	_setup({}, true)
	_run(12.0)
	eq([cues, d.look_rule, WorldState.objective], [[&"mirror_on"], &"turned_round", OBJECTIVE], "(the mirror, the look watch, the objective)")
	d.debug_skip()
	eq([cues, d.look_rule, WorldState.objective], [[&"mirror_on", &"mirror_off"], &"", ""], "skipped: none of them stays up")
	_teardown()
	return true
