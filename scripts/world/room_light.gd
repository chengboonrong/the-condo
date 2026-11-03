class_name RoomLight
extends OmniLight3D
## Ceiling light bound to WorldState.lights[room_id]. Flicker is presentation-only; the state stays authoritative.

var room_id: StringName
var base_energy := 1.0
var _flicker_left := 0.0
var _next_toggle := 0.0
var _rng := RandomNumberGenerator.new()  # presentation RNG, never feeds the simulation
var _fixture: MeshInstance3D


func setup(id: StringName, energy: float, fixture: MeshInstance3D) -> void:
	room_id = id
	base_energy = energy
	_fixture = fixture


func _ready() -> void:
	EventBus.light_changed.connect(_on_light_changed)
	EventBus.light_flicker_requested.connect(_on_flicker)
	_set_lit(WorldState.is_light_on(room_id), 1.0)


func _on_light_changed(id: StringName, on: bool) -> void:
	if id == room_id and _flicker_left <= 0.0:
		_set_lit(on, 1.0)


func _on_flicker(id: StringName, duration: float) -> void:
	if id == room_id:
		_flicker_left = duration


func _process(delta: float) -> void:
	if _flicker_left <= 0.0:
		return
	_flicker_left -= delta
	if _flicker_left <= 0.0:
		_set_lit(WorldState.is_light_on(room_id), 1.0)
		return
	if Settings.get_value("reduced_flashing"):
		# Slow dim instead of strobing.
		_set_lit(true, 0.35 + 0.2 * sin(Time.get_ticks_msec() * 0.004))
		return
	_next_toggle -= delta
	if _next_toggle <= 0.0:
		_next_toggle = _rng.randf_range(0.04, 0.18)
		_set_lit(_rng.randf() > 0.45, _rng.randf_range(0.3, 1.1))


func _set_lit(on: bool, scale: float) -> void:
	visible = on
	light_energy = base_energy * scale
	if _fixture:
		var mat := _fixture.material_override as StandardMaterial3D
		mat.emission_energy_multiplier = 2.0 * scale if on else 0.0
