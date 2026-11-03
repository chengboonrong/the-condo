class_name PlayerController
extends CharacterBody3D
## First-person movement: walk, sprint, crouch, mouse look, phone light, footsteps.

const WALK_SPEED := 2.2
const SPRINT_SPEED := 3.8
const CROUCH_SPEED := 1.2
const ACCEL := 14.0
const GRAVITY := 9.8
const STAND_HEIGHT := 1.75
const CROUCH_HEIGHT := 1.0
const EYE_DROP := 0.13  # eyes sit this far below the top of the capsule
const STEP_LENGTH := 0.65

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var phone_light: SpotLight3D = $Head/Camera3D/PhoneLight
@onready var interaction: InteractionSystem = $Head/Camera3D/InteractionSystem
@onready var shape: CollisionShape3D = $CollisionShape3D

var input_enabled := true
## Tests and the benchmark drive the player through this instead of the keyboard (x = strafe, y = forward).
var scripted_move := Vector2.ZERO
var use_scripted_move := false
var crouching := false
var yaw := 0.0
var pitch := 0.0
var _height := STAND_HEIGHT
var _stride := 0.0
var _bob := 0.0


func _ready() -> void:
	_apply_height(STAND_HEIGHT)
	phone_light.visible = false


func set_look(new_yaw: float, new_pitch: float = 0.0) -> void:
	yaw = new_yaw
	pitch = clampf(new_pitch, -1.45, 1.45)
	rotation.y = yaw
	head.rotation.x = pitch


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = Settings.get_value("mouse_sensitivity")
		var invert := -1.0 if Settings.get_value("invert_y") else 1.0
		# screen_relative: same feel at any window size (relative is scaled by the canvas_items stretch)
		set_look(yaw - event.screen_relative.x * sens, pitch - event.screen_relative.y * sens * invert)
	elif event.is_action_pressed("flashlight"):
		toggle_phone_light()


func toggle_phone_light() -> void:
	phone_light.visible = not phone_light.visible
	EventBus.sound_requested.emit(&"switch", camera.global_position, -18.0)


func is_phone_light_on() -> bool:
	return phone_light.visible


func _physics_process(delta: float) -> void:
	var move := scripted_move if use_scripted_move else Vector2.ZERO
	var wants_crouch := false
	var wants_sprint := false
	if input_enabled and not use_scripted_move:
		move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
		wants_crouch = Input.is_action_pressed(&"crouch")
		wants_sprint = Input.is_action_pressed(&"sprint")
	_update_crouch(wants_crouch, delta)

	var speed := CROUCH_SPEED if crouching else (SPRINT_SPEED if wants_sprint and move.y > 0.1 else WALK_SPEED)
	var dir := (transform.basis * Vector3(move.x, 0, -move.y))
	dir.y = 0
	var target := dir.limit_length(1.0) * speed
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_update_steps(delta)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _update_crouch(wants: bool, delta: float) -> void:
	if wants:
		crouching = true
	elif crouching:
		# Stand only if the full capsule fits above us.
		var space := STAND_HEIGHT - _height
		crouching = space > 0.01 and test_move(global_transform, Vector3.UP * space)
	var goal := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	if not is_equal_approx(_height, goal):
		_apply_height(move_toward(_height, goal, 4.0 * delta))


func _apply_height(h: float) -> void:
	_height = h
	var capsule := shape.shape as CapsuleShape3D
	capsule.height = h
	shape.position.y = h * 0.5
	head.position.y = h - EYE_DROP


func _update_steps(delta: float) -> void:
	var speed := horizontal_speed()
	if speed < 0.2 or not is_on_floor():
		_bob = move_toward(_bob, 0.0, delta * 2.0)
		camera.position.y = _bob
		return
	_stride += speed * delta
	_bob = sin(_stride / STEP_LENGTH * PI) * 0.025 * (speed / WALK_SPEED)
	camera.position.y = _bob
	if _stride >= STEP_LENGTH * 2.0:
		_stride = 0.0
		var vol := -22.0 if crouching else (-10.0 if speed > WALK_SPEED + 0.5 else -15.0)
		EventBus.sound_requested.emit(&"player_step", global_position, vol)
