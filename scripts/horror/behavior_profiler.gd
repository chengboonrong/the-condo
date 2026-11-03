class_name BehaviorProfiler
extends RefCounted
## Turns player samples into bounded 0–1 signals for the director. Memory is fixed-size: exponential
## moving averages, a decayed time per room, and the outcomes of the last few suspicious sounds.
## These are behaviour proxies only; they do not measure fear.
##
## Sample (from GameStage or a simulated bot): room, yaw, speed, near_door, lit, phone_light.

const SAMPLE_INTERVAL := 0.1
const ROOM_HALF_LIFE := 90.0
const OUTCOME_WINDOW := 8
const STIMULUS_WINDOW := 10.0
const LOOK_BEHIND_ANGLE := 2.2  # rad turned within one second
const LOOK_BEHIND_COOLDOWN := 1.5

var graph: RoomGraph
var signals := {
	"curiosity": 0.0,  # share of recent sounds the player went towards
	"avoidance": 0.0,  # share of recent sounds the player moved away from
	"look_behind": 0.0,  # recent sharp turns, scaled
	"hesitation": 0.0,  # lingering near doors without going through
	"light_dependence": 0.0,  # time spent lit (room light or phone light)
	"idle": 0.0,  # time spent standing still
}
var room_time: Dictionary = {}  # room -> decayed seconds
var outcomes: Array[float] = []  # 1 = investigated, 0.5 = ignored, 0 = fled
var _stimuli: Array[Dictionary] = []
var _yaws: Array[float] = []
var _look_behind_acc := 0.0
var _last_look_behind := -INF
var _accum := 0.0


func _init(room_graph: RoomGraph) -> void:
	graph = room_graph


## Feed every simulation tick; sampling happens at 10 Hz.
func observe(delta: float, sample: Dictionary) -> void:
	_accum += delta
	while _accum >= SAMPLE_INTERVAL:
		_accum -= SAMPLE_INTERVAL
		_sample(sample)


## A suspicious sound happened in room_id; the next samples decide how the player reacted.
func note_stimulus(room_id: StringName) -> void:
	var here := WorldState.player_room
	if room_id == &"" or room_id == here:
		return  # same-room sounds tell us nothing about approach or avoidance
	_stimuli.append({"room": room_id, "t": WorldState.time, "dist": graph.distance(here, room_id)})
	if _stimuli.size() > OUTCOME_WINDOW:
		_stimuli.pop_front()


func signal_value(name: String) -> float:
	return signals.get(name, 0.0)


## 0 = visited about as much as any room, 1 = avoided. Needs a minute of history before it says anything.
func room_avoidance(room_id: StringName) -> float:
	if not ApartmentLayout.APARTMENT_ROOMS.has(room_id):
		return 0.0
	var total := 0.0
	for r: StringName in ApartmentLayout.APARTMENT_ROOMS:
		total += room_time.get(r, 0.0)
	if total < 1.0:
		return 0.0
	var expected := total / ApartmentLayout.APARTMENT_ROOMS.size()
	var familiarity := clampf(total / 60.0, 0.0, 1.0)
	return clampf(1.0 - room_time.get(room_id, 0.0) / expected, 0.0, 1.0) * familiarity


func most_avoided(candidates: Array) -> StringName:
	var best: StringName = &""
	var best_score := -1.0
	for r: StringName in candidates:
		var s := room_avoidance(r)
		if s > best_score:
			best = r
			best_score = s
	return best


func summary() -> Dictionary:
	var out := signals.duplicate()
	var avoid := {}
	for r: StringName in ApartmentLayout.APARTMENT_ROOMS:
		avoid[r] = snappedf(room_avoidance(r), 0.01)
	out["room_avoidance"] = avoid
	return out


func _sample(s: Dictionary) -> void:
	var dt := SAMPLE_INTERVAL
	var room: StringName = s.get("room", &"")
	var decay := exp(-dt * log(2.0) / ROOM_HALF_LIFE)
	for r: StringName in room_time.keys():
		room_time[r] *= decay
	if room != &"":
		room_time[room] = room_time.get(room, 0.0) + dt
	var speed: float = s.get("speed", 0.0)
	_ema("idle", 1.0 if speed < 0.25 else 0.0, 30.0)
	_ema("light_dependence", 1.0 if s.get("lit", false) or s.get("phone_light", false) else 0.0, 60.0)
	_ema("hesitation", 1.0 if s.get("near_door", false) and speed < 0.6 else 0.0, 20.0)
	_track_look_behind(float(s.get("yaw", 0.0)))
	_resolve_stimuli(room)


func _ema(key: String, value: float, tau: float) -> void:
	var k := 1.0 - exp(-SAMPLE_INTERVAL / tau)
	signals[key] += (value - signals[key]) * k


func _track_look_behind(yaw: float) -> void:
	_yaws.append(yaw)
	if _yaws.size() > int(1.0 / SAMPLE_INTERVAL) + 1:
		_yaws.pop_front()
	_look_behind_acc *= exp(-SAMPLE_INTERVAL / 60.0)
	if absf(angle_difference(_yaws[0], yaw)) > LOOK_BEHIND_ANGLE and WorldState.time - _last_look_behind > LOOK_BEHIND_COOLDOWN:
		_last_look_behind = WorldState.time
		_look_behind_acc += 1.0
	signals["look_behind"] = clampf(_look_behind_acc / 4.0, 0.0, 1.0)


func _resolve_stimuli(room: StringName) -> void:
	for st: Dictionary in _stimuli.duplicate():
		var d := graph.distance(room, st["room"])
		var outcome := -1.0
		if d < int(st["dist"]):
			outcome = 1.0
			EventBus.sound_investigated.emit(st["room"])
		elif d > int(st["dist"]):
			outcome = 0.0
		elif WorldState.time - float(st["t"]) > STIMULUS_WINDOW:
			outcome = 0.5
		if outcome >= 0.0:
			_stimuli.erase(st)
			outcomes.append(outcome)
			if outcomes.size() > OUTCOME_WINDOW:
				outcomes.pop_front()
	var investigated := outcomes.count(1.0)
	var fled := outcomes.count(0.0)
	signals["curiosity"] = float(investigated) / OUTCOME_WINDOW
	signals["avoidance"] = float(fled) / OUTCOME_WINDOW
