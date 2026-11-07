extends TestCase
## The road's core over a stub mission that never ends: the rule count and the outcome, the choices and the look rule.


## A mission that never finishes, so the director stays on it.
class Idle extends RoadMission:
	func tick(_delta: float) -> bool:
		return false


var stage: RoadStage
var d: RoadDirector
var cues: Array[StringName] = []
var closed: Array[StringName] = []


func _setup() -> void:
	stage = RoadStage.new()
	var list: Array[RoadMission] = [Idle.new()]
	d = RoadDirector.new(stage, 1147, list)
	cues.clear()
	closed.clear()
	EventBus.road_cue.connect(_on_cue)
	EventBus.choices_closed.connect(_on_closed)


func _teardown() -> void:
	EventBus.road_cue.disconnect(_on_cue)
	EventBus.choices_closed.disconnect(_on_closed)


func _on_cue(cue: StringName) -> void:
	cues.append(cue)


func _on_closed(choice_id: StringName) -> void:
	closed.append(choice_id)


func _run(seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		d.step(0.1)


func test_score_decides_the_outcome() -> bool:
	_setup()
	eq(d.outcome(), &"alive", "nothing broken")
	d.break_rule(&"a")
	d.break_rule(&"b")
	eq(d.score(), 2, "weights add up")
	eq(d.outcome(), &"alive", "2: all alive")
	d.break_rule(&"c")
	eq(d.outcome(), &"saved", "3: he gets Mei out")
	d.break_rule(&"d", 3)
	eq(d.score(), 6, "a weight counts as its weight")
	eq(d.outcome(), &"saved", "6: still saved")
	d.break_rule(&"e")
	eq(d.outcome(), &"caught", "7: caught")
	d.end()
	eq(d.ending, &"caught", "end() keeps the outcome")
	_teardown()
	return true


func test_a_broken_rule_costs_fog_and_brings_her_closer() -> bool:
	_setup()
	_run(1.0)
	d.break_rule(&"overtook", 2)
	near(d.fog, 0.24, 0.0001, "fog +0.24")
	near(d.her_near, 0.24, 0.0001, "her_near +0.24")
	eq(cues, [&"rule_broken"], "one cue")
	eq(d.broken.size(), 1, "one record")
	eq(d.broken[0]["rule"], &"overtook", "of the rule")
	eq(d.broken[0]["weight"], 2, "its weight")
	near(d.broken[0]["t"], 1.0, 0.05, "when")
	eq(d.broken[0]["mission"], 0, "and in which mission")
	d.break_rule(&"x", 10)
	eq([d.fog, d.her_near], [1.0, 1.0], "both capped at 1")
	_teardown()
	return true


func test_choices_silence_and_keeps() -> bool:
	_setup()
	var three := PackedStringArray(["one", "two", "three"])
	d.ask(&"a", three, 5.0, PackedInt32Array([0, -1]), &"r", 2)
	eq(d.pending, &"a", "open")
	_run(4.9)
	eq(d.answer(&"a"), RoadDirector.NONE, "no answer while it is open")
	_run(0.3)
	eq(d.answer(&"a"), -1, "5 s of silence")
	eq(d.score(), 0, "silence keeps this one")
	eq(closed, [&"a"], "and the core closes it")
	eq(d.pending, &"", "nothing open")

	d.ask(&"b", three, 5.0, PackedInt32Array([0]), &"r", 2)
	EventBus.choice_made.emit(&"b", 1)
	eq(d.answer(&"b"), 1, "answered 1")
	eq(d.score(), 2, "a non-keeping answer breaks the rule by itself")
	eq(closed, [&"a", &"b"], "closed on the answer")
	EventBus.choice_made.emit(&"b", 0)
	eq(d.answer(&"b"), 1, "a late answer changes nothing")
	EventBus.choice_made.emit(&"zzz", 0)
	eq(d.answer(&"zzz"), RoadDirector.NONE, "an unknown choice is ignored")
	eq(d.score(), 2, "and breaks nothing")

	d.ask(&"c", three, 5.0, PackedInt32Array([0]), &"r", 3)
	_run(5.2)
	eq(d.answer(&"c"), -1, "silence")
	eq(d.score(), 5, "breaks a rule silence doesn't keep")
	_teardown()
	return true


func test_look_rule_needs_a_hold_and_a_return() -> bool:
	_setup()
	d.watch_look(&"turned", 2.2, 1.0, 0.4, 1, 1)
	stage.view_yaw = 1.5  # out of his own window, on a fresh watch
	_run(5.0)
	eq(d.score(), 0, "his own window is allowed")
	stage.view_yaw = -1.2  # towards her side
	_run(0.3)
	eq(d.score(), 0, "a glance (0.3 s) is not a break")
	stage.view_yaw = 0.0
	_run(0.2)
	stage.view_yaw = -1.2
	_run(0.5)
	eq(d.score(), 1, "held 0.5 s: one break")
	_run(10.0)
	eq(d.score(), 1, "held 10 s: still one")
	stage.view_yaw = 0.0
	_run(0.5)
	stage.view_yaw = -1.2
	_run(1.0)
	eq(d.score(), 1, "max_count 1: never a second")
	d.stop_look()
	eq(d.look_rule, &"", "stopped")
	_run(2.0)
	eq(d.score(), 1, "a stopped rule breaks no more")
	_teardown()

	_setup()
	d.watch_look(&"turned", 2.2, 1.0, 0.4, 1, 1)
	stage.view_yaw = 2.3
	_run(0.5)
	eq(d.score(), 1, "past 2.2 on his own side: a break")
	_teardown()

	_setup()
	d.watch_look(&"back", 1.9, 1.9, 0.25, 3, 2)
	eq(d.look_rule, &"back", "watching")
	stage.view_yaw = PI
	_run(0.3)
	eq(d.score(), 3, "back 0.3 s: 3")
	_run(5.0)
	eq(d.score(), 3, "stays back: no more")
	stage.view_yaw = -1.5
	_run(1.0)
	stage.view_yaw = PI
	_run(1.0)
	eq(d.score(), 3, "not back within 0.8 rad in between: no second break")
	stage.view_yaw = 0.3
	_run(0.2)
	stage.view_yaw = PI
	_run(0.5)
	eq(d.score(), 6, "centre, then back again: 6")
	stage.view_yaw = 0.0
	_run(0.2)
	stage.view_yaw = -PI + 0.1
	_run(0.5)
	eq(d.score(), 6, "a third look: still 6")
	_teardown()
	return true


## A look rule can name a cue to give each time it breaks, right after `rule_broken`: the presentation's scare.
func test_a_look_rule_can_name_its_cue() -> bool:
	_setup()
	d.watch_look(&"r", 1.9, 1.9, 0.25, 3, 2, &"x")
	stage.view_yaw = PI
	_run(0.3)
	eq(cues, [&"rule_broken", &"x"], "the first look back: the break, then its cue")
	stage.view_yaw = 0.0
	_run(0.2)
	stage.view_yaw = PI
	_run(0.5)
	eq(cues, [&"rule_broken", &"x", &"rule_broken", &"x"], "a second look: the same")
	stage.view_yaw = 0.0
	_run(0.2)
	stage.view_yaw = PI
	_run(0.5)
	eq(cues.size(), 4, "a third look: nothing more")
	_teardown()

	_setup()
	d.watch_look(&"r", 1.9, 1.9, 0.25, 3, 2)
	stage.view_yaw = PI
	_run(0.3)
	eq(cues, [&"rule_broken"], "named no cue: the break alone")
	_teardown()
	return true


func test_view_yaw_wraps() -> bool:
	_setup()
	stage.view_yaw = TAU + 0.1
	near(stage.relative_yaw(), 0.1, 0.0001, "a full turn and a bit is a bit")
	stage.view_yaw = -TAU - 3.0
	near(stage.relative_yaw(), -3.0, 0.0001, "the other way too")
	stage.view_yaw = TAU + 0.1
	d.watch_look(&"back", 1.9, 1.9, 0.25, 3, 2)
	_run(5.0)
	eq(d.score(), 0, "facing forward after a full turn is not looking back")
	_teardown()
	return true


func test_road_clock_starts_after_midnight() -> bool:
	_setup()
	eq(WorldState.clock_minutes(), RoadDirector.CLOCK_START, "12:06 AM")
	eq(RoadDirector.CLOCK_START, 6, "(six minutes past midnight)")
	_run(60.0)
	eq(WorldState.clock_minutes(), 7, "a minute later, 12:07 AM")
	_teardown()
	return true


func test_road_core_leaves_no_connections() -> bool:
	var choice_before := EventBus.choice_made.get_connections().size()
	var used_before := EventBus.object_interacted.get_connections().size()
	var core := RoadDirector.new(RoadStage.new(), 1147)
	core.step(0.1)
	check(EventBus.choice_made.get_connections().size() > choice_before, "(the director listens for answers)")
	check(EventBus.object_interacted.get_connections().size() > used_before, "(the director passes the car door on)")
	core = null
	eq(EventBus.choice_made.get_connections().size(), choice_before, "choice_made has no road connection left")
	eq(EventBus.object_interacted.get_connections().size(), used_before, "object_interacted has none either")
	return true


## A mission that records what it hears and when it is left; `done` ends it.
class Recorder extends RoadMission:
	var heard: Array[StringName] = []
	var left := 0
	var done := false

	func interacted(id: StringName) -> void:
		heard.append(id)

	func leave() -> void:
		left += 1

	func tick(_delta: float) -> bool:
		return done


func test_only_the_current_mission_hears_and_it_is_told_when_it_is_left() -> bool:
	var a := Recorder.new()
	var b := Recorder.new()
	var list: Array[RoadMission] = [a, b]
	var core := RoadDirector.new(RoadStage.new(), 1147, list)
	EventBus.object_interacted.emit(&"early")
	core.step(0.1)
	EventBus.object_interacted.emit(&"x")
	eq([a.heard, b.heard], [[&"x"], []], "before it begins nobody hears; then only the current one")
	a.done = true
	core.step(0.1)
	eq(a.left, 1, "a finished mission is left")
	core.step(0.1)
	EventBus.object_interacted.emit(&"y")
	core.debug_skip()
	eq(b.left, 1, "and so is a skipped one")
	EventBus.object_interacted.emit(&"z")
	eq([a.heard, b.heard, a.left], [[&"x"], [&"y"], 1], "a mission that is over hears nothing and is left once")
	return true


func test_a_choice_asked_again_is_open_again() -> bool:
	_setup()
	var two := PackedStringArray(["one", "two"])
	d.ask(&"k", two, 5.0, PackedInt32Array([0]))
	EventBus.choice_made.emit(&"k", 0)
	eq(d.answer(&"k"), 0, "answered")
	d.ask(&"k", two, 5.0, PackedInt32Array([0]))
	eq([d.pending, d.answer(&"k")], [&"k", RoadDirector.NONE], "asked again: open, and no answer yet")
	_teardown()
	return true


func test_an_overlapping_ask_closes_the_open_one_as_silence() -> bool:
	_setup()
	var catch := Playthrough.Catch.new()
	OS.add_logger(catch)
	var two := PackedStringArray(["one", "two"])
	d.ask(&"x", two, 5.0, PackedInt32Array([0]), &"r", 2)
	d.ask(&"y", two, 5.0, PackedInt32Array([0]))
	OS.remove_logger(catch)
	eq(catch.errors.size(), 1, "logged")
	eq([d.answer(&"x"), closed, d.score()], [-1, [&"x"], 2], "the open one closes as silence, which breaks its rule")
	eq(d.pending, &"y", "and the new one is open")
	_teardown()
	return true


func test_a_choice_has_one_to_three_options() -> bool:
	_setup()
	var catch := Playthrough.Catch.new()
	OS.add_logger(catch)
	d.ask(&"none", PackedStringArray(), 5.0, PackedInt32Array([0]))
	d.ask(&"four", PackedStringArray(["a", "b", "c", "d"]), 5.0, PackedInt32Array([0]))
	OS.remove_logger(catch)
	eq([catch.errors.size(), d.pending], [2, &""], "none or four: logged, and nothing opens")
	_teardown()
	return true


func test_stop_at_behind_the_car_is_refused() -> bool:
	_setup()
	d.car_s = 105.0
	var catch := Playthrough.Catch.new()
	OS.add_logger(catch)
	d.stop_at(100.0)
	OS.remove_logger(catch)
	d.step(0.1)
	eq(catch.errors.size(), 1, "logged")
	check(d.car_s >= 105.0, "and the car is not pulled back (%.1f)" % d.car_s)
	_teardown()
	return true


func test_start_at_resets_the_ride_and_the_captions() -> bool:
	_setup()
	var lines: Array[String] = []
	var on_line := func(text: String, _seconds: float) -> void: lines.append(text)
	EventBus.line_requested.connect(on_line)
	d.say("a long one", 30.0)
	d.drive(9.0)
	d.lane_to(-RoadLayout.LANE)
	_run(2.0)
	d.start_at(0)
	d.say("the next one")
	_run(10.0)
	EventBus.line_requested.disconnect(on_line)
	eq(lines, ["a long one", "the next one"], "the next mission's first line doesn't wait out a skipped one")
	eq([d.car_speed, d.lane], [0.0, RoadLayout.LANE], "nor does it keep the skipped mission's speed or lane")
	_teardown()
	return true


func test_end_keeps_a_decided_ending() -> bool:
	_setup()
	var ended: Array[StringName] = []
	var on_end := func(e: StringName) -> void: ended.append(e)
	EventBus.road_ended.connect(on_end)
	d.break_rule(&"a", 2)
	var decided := d.outcome()
	d.break_rule(&"b")
	d.end(decided)
	EventBus.road_ended.disconnect(on_end)
	eq([d.ending, ended], [&"alive", [&"alive"]], "a break after the ending was decided doesn't change it")
	_teardown()
	return true
