class_name AudioDirector
extends Node3D
## Plays EventBus.sound_requested through a pool of positional players, plus ambient beds.
## Tension (0–1) raises the drone; WorldState.behavior["tension"] is written by the director.
## Looping beds (drone, hum, tap, the home beds) loop via their .import settings (edit/loop_mode=2).
## The home beds of act 1, a neighbour's TV through the east wall, the fridge and the ceiling fan, drop out one at a
## time from act 2 and never come back (BEDS, bed_due): the silence is the signal, so no sting marks it.

const SOUNDS := {
	&"knock3": preload("res://assets/audio/knock3.wav"),
	&"knock1": preload("res://assets/audio/knock1.wav"),
	&"door_open": preload("res://assets/audio/door_open.wav"),
	&"door_close": preload("res://assets/audio/door_close.wav"),
	&"door_slam": preload("res://assets/audio/door_slam.wav"),
	&"switch": preload("res://assets/audio/switch.wav"),
	&"buzz": preload("res://assets/audio/buzz.wav"),
	&"intercom_ring": preload("res://assets/audio/intercom_ring.wav"),
	&"stinger": preload("res://assets/audio/stinger.wav"),
	&"lift_ding": preload("res://assets/audio/lift_ding.wav"),
}
const STEPS := [
	preload("res://assets/audio/footstep_1.wav"), preload("res://assets/audio/footstep_2.wav"),
	preload("res://assets/audio/footstep_3.wav"), preload("res://assets/audio/footstep_4.wav"),
]
const POOL_SIZE := 14
## Each bed fades out for good once due (bed_due): `act` and `after` (s into that act) say when, `fade` how long.
## db = its heard level in docs/architecture.md "Audio levels" minus the file's loudest 100 ms.
const BEDS := {
	&"tv": {"stream": preload("res://assets/audio/tv_murmur.wav"), "pos": Vector3(10.4, 1.0, 1.0), "db": -22.5,
		"act": 2, "after": 0.0, "fade": 1.5},  # when the wall has just knocked back
	&"fridge": {"stream": preload("res://assets/audio/fridge.wav"), "pos": Vector3(0.45, 1.0, 2.95), "db": -26.0,
		"act": 2, "after": 75.0, "fade": 1.5},
	&"fan": {"stream": preload("res://assets/audio/fan.wav"), "pos": Vector3(6.5, 2.4, 7.0), "db": -18.5,
		"act": 3, "after": 15.0, "fade": 3.0},  # winds down: pitch and blades too
}

var beds: Dictionary = {}  # bed id -> AudioStreamPlayer3D
var builder: ApartmentBuilder  # the fan's blades slow with its sound

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()  # presentation only
var _drone: AudioStreamPlayer
var _tap: AudioStreamPlayer3D
var _act := 0  # the act _process last saw, and the WorldState.time it began at
var _act_began := 0.0
var _stopped: Dictionary = {}  # bed id -> true once its fade has begun


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_distance = 30.0
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		_pool.append(p)
	_drone = AudioStreamPlayer.new()
	_drone.stream = preload("res://assets/audio/drone.wav")
	_drone.volume_db = -28.0
	add_child(_drone)
	_drone.play()
	for pos: Vector3 in [Vector3(0, 2.5, 11.2), Vector3(14, 2.5, 11.2)]:
		var hum := AudioStreamPlayer3D.new()
		hum.stream = preload("res://assets/audio/hum.wav")
		hum.position = pos
		hum.volume_db = -20.0
		hum.unit_size = 2.0
		add_child(hum)
		hum.play()
	_tap = AudioStreamPlayer3D.new()
	_tap.stream = preload("res://assets/audio/tap_running.wav")
	_tap.position = Vector3(3.25, 0.95, 1.0)
	_tap.volume_db = -8.0
	add_child(_tap)
	for id: StringName in BEDS:
		var p := AudioStreamPlayer3D.new()
		p.stream = BEDS[id]["stream"]
		p.position = BEDS[id]["pos"]
		p.volume_db = BEDS[id]["db"]
		p.unit_size = 6.0
		p.max_distance = 18.0
		add_child(p)
		p.play()
		beds[id] = p
	EventBus.sound_requested.connect(play_at)
	EventBus.variant_changed.connect(_on_variant)


func play_at(sound_id: StringName, pos: Vector3, volume_db: float) -> void:
	var stream: AudioStream
	if sound_id == &"footstep" or sound_id == &"player_step":
		stream = STEPS[_rng.randi() % STEPS.size()]
	else:
		stream = SOUNDS.get(sound_id)
	if stream == null:
		push_warning("unknown sound %s" % sound_id)
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(0.94, 1.06) if sound_id == &"footstep" or sound_id == &"player_step" else 1.0
	p.play()


func _process(_delta: float) -> void:
	var tension: float = WorldState.behavior.get("tension", 0.0)
	_drone.volume_db = lerpf(-30.0, -12.0, tension)
	if WorldState.act != _act:
		_act = WorldState.act
		_act_began = WorldState.time
	for id: StringName in beds:
		if not _stopped.has(id) and bed_due(BEDS[id], _act, WorldState.time - _act_began):
			_stopped[id] = true
			_stop_bed(id)


## Due once its act is over, or `after` seconds into it. Skipping acts (F10) stops several at once.
static func bed_due(bed: Dictionary, act: int, seconds_in_act: float) -> bool:
	return act > bed["act"] or (act == bed["act"] and seconds_in_act >= bed["after"])


## Fades the bed to nothing, then stops it; the fan winds down, its pitch and blades too. The tween pauses with
## the tree, so the pause menu freezes a fade.
func _stop_bed(id: StringName) -> void:
	var p: AudioStreamPlayer3D = beds[id]
	var fade: float = BEDS[id]["fade"]
	var tween := create_tween().set_parallel()
	tween.tween_property(p, "volume_db", -60.0, fade)
	if id == &"fan":
		tween.tween_property(p, "pitch_scale", 0.6, fade)
		tween.tween_property(builder, "fan_speed", 0.0, fade)
	tween.chain().tween_callback(p.stop)


func _on_variant(area_id: StringName, variant: StringName) -> void:
	if area_id == &"bathroom_tap":
		if variant == &"running":
			_tap.play()
		else:
			_tap.stop()


