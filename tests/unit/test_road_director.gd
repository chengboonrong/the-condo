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
var died: Array[StringName] = []


## A mission that never finishes and counts its ticks.
class Counter extends RoadMission:
	var ticks := 0

	func tick(_delta: float) -> bool:
		ticks += 1
		return false


func _setup() -> void:
	stage = RoadStage.new()
	var list: Array[RoadMission] = [Idle.new()]
	d = RoadDirector.new(stage, 1147, list)
	cues.clear()
	closed.clear()
	died.clear()
	EventBus.road_cue.connect(_on_cue)
	EventBus.choices_closed.connect(_on_closed)
	EventBus.player_died.connect(_on_died)


func _teardown() -> void:
	EventBus.road_cue.disconnect(_on_cue)
	EventBus.choices_closed.disconnect(_on_closed)
	EventBus.player_died.disconnect(_on_died)


func _on_cue(cue: StringName) -> void:
	cues.append(cue)


func _on_closed(choice_id: StringName) -> void:
	closed.append(choice_id)


func _on_died(cause: StringName) -> void:
	died.append(cause)


func _run(seconds: float) -> void:
	for i in roundi(seconds / 0.1):
		d.step(0.1)


func test_score_decides_the_outcome() -> bool:
	_setup()
	eq(d.outcome(), &"alive", "nothing broken")
	d.break_rule(&"a")
	eq(d.outcome(), &"alive", "1: all alive")
	d.break_rule(&"b")
	eq(d.score(), 2, "weights add up")
	eq(d.outcome(), &"saved", "2: he gets Mei out")
	d.break_rule(&"c", 3)
	eq(d.score(), 5, "a weight counts as its weight")
	eq(d.outcome(), &"saved", "5: still saved")
	d.break_rule(&"e")
	eq(d.outcome(), &"caught", "6: caught")
	d.end()
	eq(d.ending, &"caught", "end() keeps the outcome")
	_teardown()
	return true


func test_his_own_rules_kill_at_once() -> bool:
	for rule: StringName in RoadDirector.DEADLY:
		_setup()
		d.break_rule(rule, 3)
		eq(d.dead, rule, "%s kills him" % rule)
		eq([d.broken.size(), d.score()], [0, 0], "%s: and counts for nothing" % rule)
		eq(died, [rule], "%s: player_died once, with the rule" % rule)
		eq(cues, [], "%s: no rule_broken cue" % rule)
		_teardown()
	return true


## What the others' rules weigh: an overtake 1 (up to three), Mei opening her door 2, Mei looking back 2 (up to twice).
func test_the_others_mistakes_reach_every_ending() -> bool:
	_setup()
	d.break_rule(&"overtook")
	eq([d.score(), d.outcome(), d.dead], [1, &"alive", &""], "one overtake: all three get down")
	d.break_rule(&"mei_opened", 2)
	eq([d.score(), d.outcome(), d.dead], [3, &"saved", &""], "an overtake and Mei opening: he gets Mei out")
	d.break_rule(&"overtook")
	d.break_rule(&"overtook")
	d.break_rule(&"mei_looked", 2)
	d.break_rule(&"mei_looked", 2)
	eq([d.score(), d.outcome(), d.dead], [9, &"caught", &""], "everything they can do wrong: caught")
	_teardown()
	return true


func test_the_others_rules_still_count() -> bool:
	_setup()
	d.break_rule(&"overtook")
	eq([d.dead, d.score()], [&"", 1], "overtaking only counts")
	_teardown()
	return true


func test_dying_closes_the_choice_without_a_break() -> bool:
	_setup()
	d.ask(&"c", PackedStringArray(["a", "b"]), 3.0, PackedInt32Array([0]), &"overtook")
	d.die(&"answered")
	eq(d.pending, &"", "nothing open")
	eq(closed, [&"c"], "the choice is closed")
	eq(d.score(), 0, "and breaks nothing")
	_teardown()
	return true


func test_after_death_only_time_and_the_ride_go_on() -> bool:
	var count := Counter.new()
	var list: Array[RoadMission] = [count]
	var core := RoadDirector.new(RoadStage.new(), 1147, list)
	core.car_speed = 5.0
	core.drive(5.0)
	core.step(0.1)
	core.die(&"answered")
	var ticks := count.ticks
	var time := WorldState.time
	var car_s := core.car_s
	for i in 10:
		core.step(0.1)
	eq(count.ticks, ticks, "the mission is not ticked")
	near(WorldState.time - time, 1.0, 0.001, "time goes on")
	near(core.car_s - car_s, 5.0, 0.001, "and so does the car")
	return true


## In the car he dies with the car braking at the usual rate; not in it (the couple drive off from the lift without him),
## the car goes on.
func test_a_death_brakes_the_car_he_is_in() -> bool:
	for seated in [true, false]:
		var core := RoadDirector.new(RoadStage.new(), 1147, [Idle.new()] as Array[RoadMission])
		core.seated = seated
		core.car_speed = 9.0
		core.drive(9.0)
		core.step(0.1)
		core.die(&"turned_round")
		for i in 10:
			core.step(0.1)
		near(core.car_speed, 9.0 - RoadDirector.ACCEL * 1.0 if seated else 9.0, 0.001, "seated %s: a second after it" % seated)
		for i in 40:
			core.step(0.1)
		near(core.car_speed, 0.0 if seated else 9.0, 0.001, "seated %s: and later" % seated)
	return true


func test_death_comes_once_and_never_after_the_ending() -> bool:
	_setup()
	var ended: Array[StringName] = []
	var on_end := func(e: StringName) -> void: ended.append(e)
	EventBus.road_ended.connect(on_end)
	d.die(&"answered")
	d.die(&"looked_back")
	eq([d.dead, died], [&"answered", [&"answered"]], "a second death emits nothing")
	d.end(&"alive")
	EventBus.road_ended.disconnect(on_end)
	eq([d.ending, ended], [&"", []], "and no ending follows a death")
	_teardown()

	_setup()
	d.end(&"alive")
	d.die(&"answered")
	eq([d.dead, died], [&"", []], "no death once the road has ended")
	_teardown()
	return true


func test_a_death_in_a_step_stops_that_steps_mission() -> bool:
	_setup()
	var count := Counter.new()
	var list: Array[RoadMission] = [count]
	d = RoadDirector.new(stage, 1147, list)
	d.step(0.1)
	var ticks := count.ticks
	d.ask(&"c", PackedStringArray(["a"]), 0.05, PackedInt32Array([0]), &"answered")
	d.step(0.1)
	eq([d.dead, count.ticks], [&"answered", ticks], "the choice runs out and kills him: the mission isn't ticked after")
	_teardown()
	return true


func test_restore_sets_the_count_and_its_fog() -> bool:
	_setup()
	d.restore([{"rule": &"overtook", "weight": 1, "t": 0.0, "mission": 1}, {"rule": &"mei_opened", "weight": 2, "t": 0.0, "mission": 3}])
	eq(d.score(), 3, "the kept count")
	near(d.fog, 0.36, 0.001, "and its fog")
	near(d.her_near, 0.36, 0.001, "and how near she is")
	_teardown()
	return true


func test_broken_at_start_is_the_count_when_the_mission_began() -> bool:
	_setup()
	var first := Recorder.new()
	var list: Array[RoadMission] = [first, Idle.new()]
	d = RoadDirector.new(stage, 1147, list)
	d.step(0.1)
	d.break_rule(&"overtook")
	first.done = true
	d.step(0.1)
	d.step(0.1)
	eq(d.mission_index, 1, "(the next mission)")
	d.break_rule(&"overtook")
	eq(d.broken_at_start.size(), 1, "the count when it began, not now")
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


func test_a_line_is_queued_until_it_is_said() -> bool:
	_setup()
	d.say("first", 1.0)
	d.say("second")
	check(d.is_queued("first") and d.is_queued("second"), "both wait")
	d.step(0.1)
	check(not d.is_queued("first") and d.is_queued("second"), "the first is out, the second waits its turn")
	_run(2.0)
	check(not d.is_queued("second") and not d.is_queued("never said"), "then none")
	_teardown()
	return true


func test_end_keeps_a_decided_ending() -> bool:
	_setup()
	var ended: Array[StringName] = []
	var on_end := func(e: StringName) -> void: ended.append(e)
	EventBus.road_ended.connect(on_end)
	d.break_rule(&"a")
	var decided := d.outcome()
	d.break_rule(&"b")
	d.end(decided)
	EventBus.road_ended.disconnect(on_end)
	eq([d.ending, ended], [&"alive", [&"alive"]], "a break after the ending was decided doesn't change it")
	_teardown()
	return true
