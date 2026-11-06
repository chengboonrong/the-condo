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
	eq(d.look_rule, &"turned_round", "and his look is watched")
	_run(12.0)
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
	eq(d.score(), 0, "nothing broken")
	eq([d.look_rule, WorldState.objective], [&"", ""], "the look watch and the objective end with it")
	eq(ended, [&"alive"], "the road ends after it, all alive")
	_teardown()
	return true


func test_turning_to_her_breaks_once() -> bool:
	_setup({&"count": 0})
	stage.view_yaw = -1.3  # to his right, where she sits
	_run(10.0)
	eq(_rules(), [&"turned_round"], "turning to her breaks the rule")
	eq(cues.count(&"fourth_glimpse"), 1, "and he sees her, once")
	stage.view_yaw = 0.0
	_run(1.0)
	stage.view_yaw = -1.3
	_run(5.0)
	eq(_rules(), [&"turned_round"], "a second look doesn't break it again")
	eq(cues.count(&"fourth_glimpse"), 1, "nor show her again")
	stage.view_yaw = 0.0
	_finish()
	eq(d.score(), 1, "one broken rule in all")
	_teardown()
	return true


func test_looking_out_of_his_own_window_is_allowed() -> bool:
	_setup({&"count": 0})
	stage.view_yaw = 1.6  # to his left, out of his own window
	_run(10.0)
	eq(_rules(), [], "his own window: no break")
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
	eq(cues.slice(-2), [&"fourth_gone", &"mirror_off"], "and the mission ends as kept")
	_teardown()
	return true


func test_four_counts_her() -> bool:
	_setup({&"count": 1})
	_finish()
	eq(_rules(), [&"counted_her"], "\"Four.\" counts her")
	eq(asked, [&"count"], "and isn't asked again")
	var counting := captions.find(COUNTING)
	check(counting > 0 and captions.find(THREE) == counting + 1, "Mei counts heads, then: three?")
	check(d.progress.any(func(p: Dictionary) -> bool: return p["beat"] == &"counting"), "the counting beat")
	check(not d.progress.any(func(p: Dictionary) -> bool: return p["beat"] == &"asked_again"), "no asked_again")
	eq(cues.slice(-3), [&"brake", &"fourth_gone", &"mirror_off"], "the seat is still empty after")
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
