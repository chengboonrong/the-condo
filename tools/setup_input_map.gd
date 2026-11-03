# Writes the game's input actions into project.godot.
# Run: godot --headless --path . --script res://tools/setup_input_map.gd
extends SceneTree

const KEYS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT],
	&"crouch": [KEY_CTRL, KEY_C],
	&"interact": [KEY_E],
	&"flashlight": [KEY_F],
	&"pause": [KEY_ESCAPE],
	&"debug_overlay": [KEY_F3],
	&"debug_event_1": [KEY_F5],
	&"debug_event_2": [KEY_F6],
	&"debug_event_3": [KEY_F7],
	&"debug_event_4": [KEY_F8],
	&"debug_event_5": [KEY_F9],
	&"debug_skip_beat": [KEY_F10],
}


func _initialize() -> void:
	for action: StringName in KEYS:
		var events: Array[InputEvent] = []
		for key: Key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			ev.device = -1
			events.append(ev)
		if action == &"interact":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_LEFT
			mouse.device = -1
			events.append(mouse)
		if action == &"flashlight":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = MOUSE_BUTTON_RIGHT
			mouse.device = -1
			events.append(mouse)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("input map saved: ", error_string(err))
	quit(0 if err == OK else 1)
