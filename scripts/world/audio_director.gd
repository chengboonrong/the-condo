class_name AudioDirector
extends Node3D
## Plays EventBus.sound_requested through a pool of positional players, plus ambient beds.
## Tension (0–1) raises the drone; WorldState.behavior["tension"] is written by the director.
## Looping beds (drone, hum, tap) loop via their .import settings (edit/loop_mode=2).

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

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()  # presentation only
var _drone: AudioStreamPlayer
var _tap: AudioStreamPlayer3D


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


func _on_variant(area_id: StringName, variant: StringName) -> void:
	if area_id == &"bathroom_tap":
		if variant == &"running":
			_tap.play()
		else:
			_tap.stop()


