class_name InteractionSystem
extends RayCast3D
## Finds what the player is looking at and forwards "interact" to it.
## Interactable protocol: any collider with get_prompt() -> String and interact(player). Empty prompt = not interactable now.

signal target_changed(prompt: String)

const REACH := 2.2

var target: Object = null
var enabled_input := true
var _prompt := ""


func _ready() -> void:
	target_position = Vector3(0, 0, -REACH)
	collision_mask = 1
	enabled = true


func _physics_process(_delta: float) -> void:
	var hit: Object = get_collider() if is_colliding() else null
	if hit != null and not hit.has_method("interact"):
		hit = null
	var prompt := ""
	if hit != null:
		prompt = hit.get_prompt()
		if prompt == "":
			hit = null
	target = hit
	if prompt != _prompt:
		_prompt = prompt
		target_changed.emit(prompt)


func _unhandled_input(event: InputEvent) -> void:
	if enabled_input and event.is_action_pressed("interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_interact()


func try_interact() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	target.interact(owner)
	return true
