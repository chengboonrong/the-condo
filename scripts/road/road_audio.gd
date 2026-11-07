class_name RoadAudio
extends Node
## The road's sounds. EventBus.sound_requested plays through a pool of positional players, as AudioDirector plays the
## flat's, with asphalt under his feet. The loops (the engine, the insects, the slow car, the indicator, the phone) are
## only ever started, changed and stopped with set_loop. A sound in his head (the sting when he looks back) is played
## with play_here. Levels: docs/architecture.md, "Audio levels".

const SOUNDS := {
	&"switch": preload("res://assets/audio/switch.wav"),  # his phone light
	&"car_door_open": preload("res://assets/audio/car_door_open.wav"),
	&"car_door_close": preload("res://assets/audio/car_door_close.wav"),
	&"lorry_pass": preload("res://assets/audio/lorry_pass.wav"),
	&"lorry_brake": preload("res://assets/audio/lorry_brake.wav"),  # its air brakes, pulling up
	&"rev": preload("res://assets/audio/rev.wav"),  # the hatchback, opened up for the overtake
	&"wet_flap": preload("res://assets/audio/wet_flap.wav"),  # her
	&"drip": preload("res://assets/audio/drip.wav"),
	&"rattle": preload("res://assets/audio/rattle.wav"),  # her breath
	&"engine_sputter": preload("res://assets/audio/engine_sputter.wav"),  # the hatchback dying
	&"starter_crank": preload("res://assets/audio/starter_crank.wav"),  # and not starting
	&"thump_roof": preload("res://assets/audio/thump_roof.wav"),  # something landing on it
	&"knock_glass": preload("res://assets/audio/knock_glass.wav"),  # on Mei's window
	&"stinger": preload("res://assets/audio/stinger.wav"),  # the flat's, as he looks back and she is right behind him
	&"shriek": preload("res://assets/audio/shriek.wav"),  # and hers
}
const STEPS := [
	preload("res://assets/audio/road_step_1.wav"), preload("res://assets/audio/road_step_2.wav"),
	preload("res://assets/audio/road_step_3.wav"), preload("res://assets/audio/road_step_4.wav"),
]
## Seamless loops (edit/loop_mode=2 in their .import files).
const LOOPS := {
	&"engine_loop": preload("res://assets/audio/engine_loop.wav"),
	&"old_engine_loop": preload("res://assets/audio/old_engine_loop.wav"),
	&"insects_loop": preload("res://assets/audio/insects_loop.wav"),
	&"indicator": preload("res://assets/audio/indicator.wav"),
	&"phone_ring_mobile": preload("res://assets/audio/phone_ring_mobile.wav"),
	&"lorry_idle": preload("res://assets/audio/lorry_idle.wav"),  # its diesel, standing
}
const POOL_SIZE := 8

var loops: Dictionary = {}  # loop id -> its AudioStreamPlayer, from the first time set_loop starts it
var here: Dictionary = {}  # sound id -> its AudioStreamPlayer, from the first time play_here plays it

var _pool: Array[AudioStreamPlayer3D] = []
var _next := 0
var _rng := RandomNumberGenerator.new()  # presentation only


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = 3.0
		p.max_distance = 30.0
		p.attenuation_filter_cutoff_hz = 6000.0
		add_child(p)
		_pool.append(p)
	EventBus.sound_requested.connect(play_at)


func play_at(sound_id: StringName, pos: Vector3, volume_db: float) -> void:
	var step := sound_id == &"player_step"
	var stream: AudioStream = STEPS[_rng.randi() % STEPS.size()] if step else SOUNDS.get(sound_id)
	if stream == null:
		push_warning("unknown sound %s" % sound_id)
		return
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = _rng.randf_range(0.94, 1.06) if step else 1.0
	p.play()


## One of SOUNDS in his head, from the start: not positional, so it is heard at exactly `volume_db` and never meets
## the +3 dB cap (max_db) that a positional player at his camera holds whatever it is played at.
func play_here(sound_id: StringName, volume_db: float) -> void:
	if not SOUNDS.has(sound_id):
		push_warning("unknown sound %s" % sound_id)
		return
	var p: AudioStreamPlayer = here.get(sound_id)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = SOUNDS[sound_id]
		add_child(p)
		here[sound_id] = p
	p.volume_db = volume_db
	p.play()


## Starts, changes or stops one of LOOPS. A loop that is already playing keeps going: only its level and pitch change.
func set_loop(id: StringName, on: bool, volume_db: float, pitch := 1.0) -> void:
	if not LOOPS.has(id):
		push_warning("unknown loop %s" % id)
		return
	var p: AudioStreamPlayer = loops.get(id)
	if p == null:
		if not on:
			return
		p = AudioStreamPlayer.new()
		p.stream = LOOPS[id]
		add_child(p)
		loops[id] = p
	p.volume_db = volume_db
	p.pitch_scale = pitch
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()
