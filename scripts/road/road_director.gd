class_name RoadDirector
extends RefCounted
## The road's simulation core. It runs the missions in order and keeps one weighted count of the rules he breaks,
## which decides how the road ends. Headless and deterministic: no nodes, and randomness only from rng.
## Each step, in this order: time, captions, the open choice's timer, the look rule, the current mission, the ride.
## A dead director only advances time and the ride.
## The presentation reads the state below each frame; one-off moments go out on EventBus (road_cue, the choices,
## line_requested and road_line, road_ended, player_died).

const ALIVE_MAX := 1  # a score up to this: all three get down alive
const SAVED_MAX := 5  # up to this: he gets Mei out; above it, all three are caught
const DEADLY: Array[StringName] = [&"turned_round", &"counted_her", &"answered", &"opened_door", &"looked_back"]  # his own rules: breaking one kills him
const CHOICE_SECONDS := 3.0  # how long a choice stays open
const CLOCK_START := 6  # minutes past midnight when the road starts
const NONE := -2  # answer(): the choice is still open, or was never asked
const ACCEL := 2.5  # m/s², the car speeding up, slowing down and braking for a stop
const LANE_SPEED := 1.5  # m/s across, changing lanes
const CENTRE := 0.8  # rad: a look must come back this close to forward before it can break again
const LINE_GAP := 0.3  # seconds between one line ending and the next showing

var stage: RoadStage
var rng := RandomNumberGenerator.new()
var missions: Array[RoadMission] = []

# The ride, and what the presentation reads each frame.
var car_s := 0.0
var car_speed := 0.0
var lane := RoadLayout.LANE
var seated := false
var fog := 0.0  # 0 to 1: every broken rule thickens it
var her_near := 0.0  # 0 to 1: every broken rule brings her closer
var slow_gap := NAN  # metres from the couple's car to the slow car ahead; NAN when there is none
var light_s := -1.0  # where the light down the road is: 150 m on from where the car died (Mission 4); -1 until then
var mission_index := 0
var pending: StringName = &""  # the open choice
var look_rule: StringName = &""  # the rule his look is watched for
var broken: Array[Dictionary] = []  # {"rule", "weight", "t", "mission"}
var broken_at_start: Array[Dictionary] = []  # `broken` as it was when the current mission began: what a retry keeps
var progress: Array[Dictionary] = []  # {"t", "mission", "beat"}: every beat change
var ending: StringName = &""
var dead: StringName = &""  # the rule that killed him; once set, only time and the ride go on
var retried := false  # a Try again (restore): the mission he died in starts without what he has already seen
var closing := 0.0  # 0 to 1: on the walk, how near she has come because he stood still

var _begun := false
var _lines: Array = []  # queued [text, seconds, speaker]
var _line_left := 0.0
var _answers := {}  # choice_id -> the answer's index, -1 for silence
var _keeps := PackedInt32Array()
var _choice_rule: StringName = &""
var _choice_weight := 1
var _choice_left := 0.0
var _look_left := 0.0
var _look_right := 0.0
var _look_hold := 0.0
var _look_weight := 1
var _look_max := 1
var _look_count := 0
var _look_held := 0.0
var _look_armed := true
var _target_speed := 0.0
var _stop_s := NAN
var _lane_to := RoadLayout.LANE


func _init(road_stage: RoadStage, seed_value: int, mission_list: Array[RoadMission] = default_missions()) -> void:
	stage = road_stage
	rng.seed = seed_value
	missions = mission_list
	for m: RoadMission in missions:
		m.d = self
	# The clock reads 12:06 AM now: 19 minutes after the 11:47 PM it counts from.
	WorldState.clock_anchor = WorldState.time - (CLOCK_START + 24 * 60 - (23 * 60 + 47)) * 60.0
	EventBus.choice_made.connect(_on_choice_made)
	EventBus.object_interacted.connect(_on_interacted)


## The road's missions in order. Each mission's task appends its own.
static func default_missions() -> Array[RoadMission]:
	var list: Array[RoadMission] = [LiftMission.new(), SlowCarMission.new(), CountMission.new(), StallMission.new(),
		LightMission.new()]
	return list


func step(delta: float) -> void:
	WorldState.advance_time(delta)
	if dead != &"":
		_ride(delta)
		return
	_speak(delta)
	if pending != &"":
		_choice_left -= delta
		if _choice_left <= 0.0:
			_close(-1)
	_watch(delta)
	if mission_index < missions.size() and dead == &"":
		var m := missions[mission_index]
		if not _begun:
			_begun = true
			broken_at_start = broken.duplicate(true)
			m.begin()
		m.beat_t += delta
		if m.tick(delta):
			_leave()
			mission_index += 1
			if mission_index >= missions.size():
				end()
	_ride(delta)


## The state as if every mission before `index` was kept: for tools, stills and `--mission=N`. The current mission is
## left first. Past the last mission, the road ends.
func start_at(index: int) -> void:
	_leave()
	_drop_choice()
	stop_look()
	closing = 0.0
	broken_at_start = broken.duplicate(true)
	_lines.clear()
	_line_left = 0.0
	_target_speed = 0.0
	_stop_s = NAN
	_lane_to = RoadLayout.LANE
	mission_index = index
	if index >= missions.size():
		end()
	else:
		missions[index].set_up_skipped()


## Debug and tools: the current mission is over, as if kept, and the next one starts.
func debug_skip() -> void:
	start_at(mission_index + 1)


## A line someone says or thinks, after the ones already queued. It always shows, whatever the captions setting;
## sound captions go on EventBus.subtitle_requested instead. Spoken lines name their speaker (&"hafiz", &"mei").
func say(text: String, seconds := 3.5, speaker: StringName = &"") -> void:
	_lines.append([text, seconds, speaker])


## Whether `text` is still waiting its turn to be said, and so not yet on the screen.
func is_queued(text: String) -> bool:
	return _lines.any(func(line: Array) -> bool: return line[0] == text)


## Opens a choice of 1 to 3 options for `seconds`. `keeps` lists the answers that keep `rule` (-1: silence keeps it);
## any other answer breaks it. Asking again forgets the old answer. One choice at a time: an ask while another is open
## is a mistake, and closes that one as silence.
func ask(choice_id: StringName, options: PackedStringArray, seconds: float, keeps: PackedInt32Array, rule: StringName = &"", weight := 1) -> void:
	if options.is_empty() or options.size() > 3:
		push_error("ask(%s): %d options, but a choice has 1 to 3" % [choice_id, options.size()])
		return
	if pending != &"":
		push_error("ask(%s) while %s is open: that one closes as silence" % [choice_id, pending])
		_close(-1)
	_answers.erase(choice_id)
	pending = choice_id
	_keeps = keeps
	_choice_rule = rule
	_choice_weight = weight
	_choice_left = seconds
	EventBus.choices_requested.emit(choice_id, options)


## NONE while the choice is open (or never asked), -1 for silence, otherwise the answer's index.
func answer(choice_id: StringName) -> int:
	return _answers.get(choice_id, NONE)


## Breaks `rule` when his look has been past `left` (to his left) or `right` (to his right) for `hold` seconds, at
## most `max_count` times. After a break it can only break again once he has looked back towards the front.
func watch_look(rule: StringName, left: float, right: float, hold: float, weight: int, max_count: int) -> void:
	look_rule = rule
	_look_left = left
	_look_right = right
	_look_hold = hold
	_look_weight = weight
	_look_max = max_count
	_look_count = 0
	_look_held = 0.0
	_look_armed = true


func stop_look() -> void:
	look_rule = &""


## One of his own rules kills him at once, and counts for nothing.
func break_rule(rule: StringName, weight := 1) -> void:
	if DEADLY.has(rule):
		die(rule)
		return
	broken.append({"rule": rule, "weight": weight, "t": snappedf(WorldState.time, 0.1), "mission": mission_index})
	fog = minf(1.0, fog + 0.12 * weight)
	her_near = minf(1.0, her_near + 0.12 * weight)
	EventBus.road_cue.emit(&"rule_broken")


## He dies of `cause`, once, and never after the ending. The open choice closes without a break and the mission is left.
## In the car, it brakes (a car he is not in goes on: the couple drive off from the lift without him).
func die(cause: StringName) -> void:
	if dead != &"" or ending != &"":
		return
	dead = cause
	_drop_choice()
	stop_look()
	_leave()
	if seated:
		drive(0.0)
	EventBus.player_died.emit(cause)


## A retry: the count as it was kept, with the fog and her nearness it had by then.
func restore(kept: Array[Dictionary]) -> void:
	retried = true
	broken = kept.duplicate(true)
	fog = minf(1.0, 0.12 * score())
	her_near = fog


func score() -> int:
	var total := 0
	for b: Dictionary in broken:
		total += b["weight"]
	return total


func outcome() -> StringName:
	var n := score()
	if n <= ALIVE_MAX:
		return &"alive"
	return &"saved" if n <= SAVED_MAX else &"caught"


## The road is over, once only, and never after he died. `decided`: an ending already played, kept even if a rule breaks after it was
## decided; without it, the count decides.
func end(decided: StringName = &"") -> void:
	if ending != &"" or dead != &"":
		return
	ending = decided if decided != &"" else outcome()
	EventBus.road_ended.emit(ending)


## The car speeds up or slows down to `speed`. It cancels a stop.
func drive(speed: float) -> void:
	_target_speed = speed
	_stop_s = NAN


## The car brakes in time to stand exactly at s, which must be ahead of it.
func stop_at(s: float) -> void:
	if s < car_s:
		push_error("stop_at(%.1f): the car is already past it, at %.1f" % [s, car_s])
		return
	_stop_s = s


func lane_to(across: float) -> void:
	_lane_to = across


func _speak(delta: float) -> void:
	_line_left -= delta
	if _line_left <= 0.0 and not _lines.is_empty():
		var line: Array = _lines.pop_front()
		EventBus.line_requested.emit(line[0], line[1])
		if line[2] != &"":
			EventBus.road_line.emit(line[2], line[1])
		_line_left = float(line[1]) + LINE_GAP


## Missions never listen to EventBus themselves: the current one hears what he uses from here.
func _on_interacted(object_id: StringName) -> void:
	if _begun:
		missions[mission_index].interacted(object_id)


## The current mission is no longer current: it clears what it put up.
func _leave() -> void:
	if _begun:
		_begun = false
		missions[mission_index].leave()


func _on_choice_made(choice_id: StringName, index: int) -> void:
	if choice_id == pending:
		_close(index)


## The open choice, if any, closes with no answer and no break.
func _drop_choice() -> void:
	if pending != &"":
		var id := pending
		pending = &""
		EventBus.choices_closed.emit(id)


func _close(index: int) -> void:
	var id := pending
	pending = &""
	_answers[id] = index
	EventBus.choices_closed.emit(id)
	if _choice_rule != &"" and not _keeps.has(index):
		break_rule(_choice_rule, _choice_weight)


func _watch(delta: float) -> void:
	if look_rule == &"":
		return
	var yaw := stage.relative_yaw()
	if absf(yaw) <= CENTRE:
		_look_armed = true
	if _look_armed and _look_count < _look_max and (yaw > _look_left or yaw < -_look_right):
		_look_held += delta
		if _look_held >= _look_hold:
			_look_count += 1
			_look_armed = false
			break_rule(look_rule, _look_weight)
	else:
		_look_held = 0.0


func _ride(delta: float) -> void:
	car_speed = move_toward(car_speed, _target_speed, ACCEL * delta)
	if not is_nan(_stop_s):
		car_speed = minf(car_speed, sqrt(2.0 * ACCEL * maxf(_stop_s - car_s, 0.0)))  # braking in time
		if car_s + car_speed * delta >= _stop_s:
			car_s = _stop_s
			car_speed = 0.0
			_target_speed = 0.0
			_stop_s = NAN
	car_s += car_speed * delta
	lane = move_toward(lane, _lane_to, LANE_SPEED * delta)
