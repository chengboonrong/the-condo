class_name PauseMenu
extends CanvasLayer
## Esc (or a lost pointer lock on the web, or the window losing focus) pauses the whole tree and shows
## this menu: resume, the settings, restart, quit. Everything else stops, including the simulation.

var _panel: Control
var _quit: Button
var _capture_on_close := true


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0, 0, 0, 0.82)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var frame := PanelContainer.new()  # same look as the note panel
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.position = Vector2(-300, -330)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.09, 0.1, 0.97)
	style.set_content_margin_all(36)
	style.border_color = Color(0.5, 0.45, 0.35, 0.6)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	_panel.add_child(frame)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(528, 0)
	box.add_theme_constant_override("separation", 12)
	frame.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	_button(box, "Resume", close)
	_slider(box, "Brightness", "brightness", 0.5, 1.8, 0.05)
	_slider(box, "Mouse sensitivity", "mouse_sensitivity", 0.0008, 0.006, 0.0001)  # 0.0001 steps reach the 0.0025 default
	_slider(box, "Volume", "master_volume", 0.0, 1.0, 0.05)
	_check(box, "Invert mouse Y", "invert_y")
	_check(box, "Captions for sounds (dialogue always shows)", "subtitles")
	_check(box, "Reduced flashing", "reduced_flashing")
	_button(box, "Restart", func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	_quit = _button(box, "Quit", func() -> void: get_tree().quit())
	_quit.visible = not OS.has_feature("web")  # a browser tab is closed, not quit
	visible = false


func is_open() -> bool:
	return visible


## capture: take the mouse back on close (false from the start card, which needs a free cursor).
func open(capture := true) -> void:
	_capture_on_close = capture
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	visible = false
	get_tree().paused = false
	if _capture_on_close:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # a click on Resume is the gesture browsers need


func _unhandled_input(event: InputEvent) -> void:
	# Not on the web: a key press can't take pointer lock back, so only the Resume click closes the menu.
	if visible and event.is_action_pressed("pause") and not OS.has_feature("web"):
		close()
		get_viewport().set_input_as_handled()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	_style(b)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _style(b: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"normal": Color(0.17, 0.17, 0.18), "hover": Color(0.27, 0.25, 0.22), "pressed": Color(0.12, 0.12, 0.13), "focus": Color(0, 0, 0, 0)}[state]
		st.set_content_margin_all(8)
		if state == "focus":
			st.border_color = Color(0.75, 0.65, 0.45)
			st.set_border_width_all(1)
		b.add_theme_stylebox_override(state, st)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> HSlider:
	var label := Label.new()
	label.text = text
	parent.add_child(label)
	var s := HSlider.new()
	s.name = key
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Settings.get_value(key))
	s.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
	parent.add_child(s)
	return s


## A toggle that says its state in words ("Reduced flashing: Off"): clearer than a dim checkbox.
func _check(parent: Control, text: String, key: String) -> Button:
	var c := Button.new()
	c.name = key
	c.toggle_mode = true
	c.alignment = HORIZONTAL_ALIGNMENT_LEFT
	c.add_theme_font_size_override("font_size", 18)
	_style(c)
	c.toggled.connect(func(on: bool) -> void:
		c.text = "%s: %s" % [text, "On" if on else "Off"]
		Settings.set_value(key, on))
	c.set_pressed_no_signal(bool(Settings.get_value(key)))
	c.text = "%s: %s" % [text, "On" if c.button_pressed else "Off"]
	parent.add_child(c)
	return c
