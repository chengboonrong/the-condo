extends TestCase
## Mission 2, the slow car: an old car with nobody at the wheel crawls ahead and Hafiz wants to potong it. Three
## attempts. Answering the third option, or saying nothing, lets him overtake, and the same car is ahead again.

const RECALL := "[Bang Din: \"A slow car with nobody driving, you follow it. However long. Never potong.\"]"
const MEI := "Mei: \"Eh… isn't that the same car?\""
const OPTIONS := {
	&"overtake_1": ["\"Don't, bro. Just follow it.\"", "\"Eh… got nobody driving that car.\"", "\"Ya lah, go.\""],
	&"overtake_2": ["\"Follow it lah. No rush.\"", "\"Bang Din says never potong a car like that.\"", "\"Faster, go.\""],
	&"overtake_3": ["\"Bro, please. Stay behind it.\"", "\"Look properly. Nobody at the wheel.\"", "\"Okay, last time. Go.\""],
}

var stage: RoadStage
var d: RoadDirector
var cues: Array[StringName] = []
var cue_log: Array = []  # [cue, world time, slow_gap then, lane then]
var lines: Array = []  # [text, speaker] in the order they were said
var asked: Array = []  # [choice id, options, world time]
var ended: Array[StringName] = []
var end_lane := NAN  # the lane when the road ended
var low_gap := INF  # the smallest slow_gap seen
var low_lane := INF
var top_speed := 0.0


func _setup() -> void:
	WorldState.reset()
	stage = RoadStage.new()
	var list: Array[RoadMission] = [SlowCarMission.new()]
	d = RoadDirector.new(stage, 1147, list)
	d.start_at(0)  # as if the lift was kept
	cues.clear()
	cue_log.clear()
	lines.clear()
	asked.clear()
	ended.clear()
	end_lane = NAN
	low_gap = INF
	low_lane = INF
	top_speed = 0.0
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
	cues.append(cue)
	cue_log.append([cue, WorldState.time, d.slow_gap, d.lane])


func _on_line(text: String, _seconds: float) -> void:
	lines.append([text, &""])


func _on_speaker(speaker: StringName, _seconds: float) -> void:
	lines.back()[1] = speaker  # road_line follows its line_requested at once


func _on_asked(choice_id: StringName, options: PackedStringArray) -> void:
	asked.append([choice_id, options, WorldState.time])


func _on_ended(ending: StringName) -> void:
	ended.append(ending)
	end_lane = d.lane


## Plays the mission to the end. `answers[n - 1]` is the answer to the n-th attempt, one second after it opens; -1
## stays silent.
func _play(answers: Array, limit := 400.0) -> void:
	var open_for := 0.0
	for i in roundi(limit / 0.1):
		if d.ending != &"":
			return
		if d.pending != &"":
			open_for += 0.1
			var n := int(String(d.pending).trim_prefix("overtake_"))
			if open_for >= 1.0 and answers[n - 1] >= 0:
				EventBus.choice_made.emit(d.pending, answers[n - 1])
		else:
			open_for = 0.0
		_step()


func _step() -> void:
	d.step(0.1)
	if not is_nan(d.slow_gap):
		low_gap = minf(low_gap, d.slow_gap)
	low_lane = minf(low_lane, d.lane)
	top_speed = maxf(top_speed, d.car_speed)


## Steps until the cue comes, at most `limit` seconds. True if it came.
func _until(cue: StringName, limit: float) -> bool:
	for i in roundi(limit / 0.1):
		if cues.has(cue):
			return true
		_step()
	return cues.has(cue)


func _times(cue: StringName) -> Array:
	return cue_log.filter(func(c: Array) -> bool: return c[0] == cue)


func _rules() -> Array:
	return d.broken.map(func(b: Dictionary) -> StringName: return b["rule"])


func test_keeping_all_three_breaks_nothing() -> bool:
	_setup()
	_play([0, 1, 0])
	eq(d.score(), 0, "nothing broken")
	eq(cues, [&"slow_car_seen", &"slow_car_gone"], "seen once, then gone: no signal, no overtake, no glimpse")
	check(is_nan(d.slow_gap), "no slow car at the end")
	eq(asked.map(func(a: Array) -> StringName: return a[0]), [&"overtake_1", &"overtake_2", &"overtake_3"], "three attempts")
	eq(ended, [&"alive"], "the mission is done, and nobody was hurt")
	eq(WorldState.objective, "", "the objective goes with it")
	_teardown()
	return true


func test_silence_lets_him_overtake() -> bool:
	_setup()
	_play([-1, -1, -1])
	eq(_rules(), [&"overtook", &"overtook", &"overtook"], "three overtakes")
	eq(d.score(), 3, "score 3")
	check(d.fog > 0.359, "the fog is thicker by three breaks (%.3f)" % d.fog)
	eq(cues.count(&"overtake"), 3, "three overtake cues")
	eq(cues.count(&"indicator"), 3, "each signalled first")
	eq(cues.count(&"slow_car_ahead"), 3, "and the same car is ahead after each")
	eq(cues.back(), &"slow_car_gone", "then it pulls in")
	eq(ended, [&"saved"], "three broken rules: Mei is saved")
	_teardown()
	return true


func test_after_an_overtake_it_is_ahead_again() -> bool:
	_setup()
	_play([2, 0, 0])
	eq(_rules(), [&"overtook"], "one overtake")
	check(low_gap < -10.0, "he is past it: the gap went to %.1f" % low_gap)
	eq(cues.count(&"overtake"), 1, "one overtake")
	var ahead := _times(&"slow_car_ahead")
	eq(ahead.size(), 1, "and it is ahead again")
	near(ahead[0][2], 40.0, 0.5, "40 m ahead when it shows")
	check(ahead[0][1] - _times(&"overtake")[0][1] > 20.0, "after the pass, about 20 s later")
	check(lines.any(func(l: Array) -> bool: return l[0] == MEI and l[1] == &"mei"), "Mei asks if it is the same car")
	_teardown()
	return true


func test_her_glimpse_follows_each_overtake() -> bool:
	_setup()
	_play([0, 0, 0])
	eq(cues.count(&"her_glimpse"), 0, "none when he kept the rule")
	_teardown()
	_setup()
	_play([0, 0, 2])
	eq(cues.count(&"her_glimpse"), 1, "one for the one overtake")
	var glimpse: Array = _times(&"her_glimpse")[0]
	var passed: Array = _times(&"overtake")[0]
	check(glimpse[1] > passed[1], "after it")
	check(glimpse[2] < -10.0, "once the slow car is well behind (%.1f m)" % glimpse[2])
	near(glimpse[3], RoadLayout.LANE, 0.1, "and he is back in his own lane")
	_teardown()
	_setup()
	_play([-1, -1, -1])
	eq(cues.count(&"her_glimpse"), 3, "one for each of three")
	_teardown()
	return true


func test_the_slow_car_comes_up_and_he_follows_it() -> bool:
	_setup()
	eq([d.seated, d.car_s, d.car_speed], [true, 0.0, 9.0], "skipped to: seated, cruising from the start")
	check(is_nan(d.slow_gap), "no slow car yet")
	for i in 70:
		_step()
	near(d.car_speed, 9.0, 0.01, "he cruises at 9 m/s")
	check(is_nan(d.slow_gap), "for 8 s with nothing ahead")
	for i in 20:
		_step()
	check(not is_nan(d.slow_gap) and d.slow_gap < 60.0 and d.slow_gap > 45.0, "then it shows, about 60 m ahead (%.1f)" % d.slow_gap)
	check(not cues.has(&"slow_car_seen"), "(not seen yet)")
	check(_until(&"slow_car_seen", 30.0), "he catches up")
	near(d.slow_gap, 12.0, 1.0, "to 12 m")
	near(d.car_speed, 4.0, 0.2, "at its 4 m/s")
	eq(WorldState.objective, "Keep him behind the slow car.", "the objective")
	for i in 100:  # a while behind it: it stays 12 m ahead and the car crawls
		_step()
	near(d.slow_gap, 12.0, 1.0, "still 12 m behind it")
	near(d.car_speed, 4.0, 0.2, "still crawling")
	_teardown()
	return true


func test_the_rule_recall_and_each_attempt_word_for_word() -> bool:
	_setup()
	_play([-1, -1, -1])
	eq(lines.filter(func(l: Array) -> bool: return l[0] == RECALL).size(), 1, "Bang Din's rule, once")
	for n in 3:
		var id := StringName("overtake_%d" % (n + 1))
		var a := asked.filter(func(x: Array) -> bool: return x[0] == id)
		eq(a.size(), 1, "%s is asked once" % id)
		eq(Array(a[0][1]), OPTIONS[id], "%s's options" % id)
	_teardown()
	return true


func test_each_attempt_is_about_forty_seconds_after_the_last() -> bool:
	for answers: Array in [[0, 0, 0], [-1, -1, -1], [2, 2, 2]]:  # kept, then overtaking after silence, then at once
		_setup()
		_play(answers)
		eq(asked.size(), 3, "%s: three attempts" % [answers])
		for n in [1, 2]:
			var gap: float = asked[n][2] - asked[n - 1][2]
			check(gap > 30.0 and gap < 50.0, "%s: attempt %d opens %.0f s after attempt %d" % [answers, n + 1, gap, n])
		_teardown()
	return true


func test_the_couple_edge_past_the_lay_by_and_are_in_their_lane_when_it_ends() -> bool:
	_setup()
	_play([0, 0, 0])
	near(low_lane, SlowCarMission.PASSING_LANE, 0.01, "they edge over to clear the parked car")
	eq(ended, [&"alive"], "(the mission is over)")
	near(end_lane, RoadLayout.LANE, 0.001, "and back in their own lane, so the next mission never starts at the lay-by's")
	_teardown()
	_setup()
	_play([-1, -1, -1])
	near(end_lane, RoadLayout.LANE, 0.001, "after three overtakes too")
	_teardown()
	return true


func test_hafiz_is_more_impatient_and_every_spoken_line_names_its_speaker() -> bool:
	_setup()
	_play([0, 0, 0])
	var heard := lines.duplicate()
	_teardown()
	_setup()
	_play([2, 2, 2])  # the lines of an overtake too
	heard.append_array(lines)
	var hafiz := heard.filter(func(l: Array) -> bool: return String(l[0]).begins_with("Hafiz: \""))
	check(hafiz.size() >= 9, "he has a line before each attempt, a grumble after each kept one and a word for each overtake (%d lines)" % hafiz.size())
	for l: Array in heard:
		var text: String = l[0]
		if text.begins_with("Hafiz: \""):
			eq(l[1], &"hafiz", "(%s)" % text)
		elif text.begins_with("Mei: \""):
			eq(l[1], &"mei", "(%s)" % text)
		else:
			eq(l[1], &"", "a thought or a memory has no speaker: %s" % text)
	_teardown()
	return true


func test_the_overtake_swings_across_and_back() -> bool:
	_setup()
	_play([2, 0, 0])
	var signal_at: float = _times(&"indicator")[0][1]
	var swing_at: float = _times(&"overtake")[0][1]
	check(swing_at - signal_at >= 2.0, "the indicator ticks %.1f s before he pulls out" % (swing_at - signal_at))
	near(low_lane, -RoadLayout.LANE, 0.01, "he goes right across, into the other lane")
	near(top_speed, 14.0, 0.01, "at 14 m/s")
	_teardown()
	return true


func test_a_skip_clears_the_slow_car_and_the_objective() -> bool:
	_setup()
	check(_until(&"slow_car_seen", 40.0), "(the slow car is up)")
	check(not is_nan(d.slow_gap) and WorldState.objective != "", "(and the objective is up)")
	d.debug_skip()
	check(is_nan(d.slow_gap), "skipped: no slow car")
	eq(WorldState.objective, "", "and no objective")
	_teardown()
	return true
