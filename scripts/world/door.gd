class_name Door
extends AnimatableBody3D
## Hinged door. State lives in WorldState.doors; this node only animates it. Doors never lock.

const OPEN_ANGLE := deg_to_rad(95.0)
const SPEED := 2.4  # rad/s; events slam faster

var door_id: StringName
var swing := -1
var _angle := 0.0
var _target := 0.0
var _speed := SPEED


func setup(id: StringName, data: Dictionary) -> void:
	door_id = id
	swing = data["swing"]
	position = data["hinge"]  # every door sits in an x-axis wall; the panel extends along +x


func _ready() -> void:
	EventBus.door_changed.connect(_on_door_changed)
	_target = OPEN_ANGLE if WorldState.is_door_open(door_id) else 0.0
	_angle = _target
	_apply()


func get_prompt() -> String:
	return "Close door" if WorldState.is_door_open(door_id) else "Open door"


func interact(_player: Node) -> void:
	WorldState.set_door(door_id, not WorldState.is_door_open(door_id), &"player")
	EventBus.object_interacted.emit(door_id)


func is_moving() -> bool:
	return not is_equal_approx(_angle, _target)


func _on_door_changed(id: StringName, open: bool, source: StringName) -> void:
	if id != door_id:
		return
	_target = OPEN_ANGLE if open else 0.0
	var slam := source != &"player" and source != &"restore" and not open  # a restore closes quietly
	_speed = SPEED * (2.5 if slam else 1.0)
	var sound := &"door_slam" if slam else (&"door_open" if open else &"door_close")
	# The player opens doors all the time; that must stay well under a slam (docs/architecture.md, Audio levels).
	# A door opening by itself is a scare: up with the slam, still under the stinger.
	var gain := 0.0
	if sound == &"door_open":
		gain = -11.0 if source == &"player" else -4.0
	EventBus.sound_requested.emit(sound, global_position + global_basis.x * 0.45 + Vector3.UP, gain)


func _physics_process(delta: float) -> void:
	if is_moving():
		_angle = move_toward(_angle, _target, _speed * delta)
		_apply()


func _apply() -> void:
	rotation.y = -swing * _angle
