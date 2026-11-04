class_name Hud
extends CanvasLayer
## Crosshair, interaction prompt, objective, clock, subtitles, inspection panel and the start card.

signal started

var player: PlayerController
var _prompt: Label
var _objective: Label
var _clock: Label
var _subtitle: Label
var _subtitle_left := 0.0
var _inspect: PanelContainer
var _inspect_title: Label
var _inspect_text: Label
var _start: Control
var _crosshair: ColorRect
var _ending: ColorRect
var _ending_title: Label
var _ending_text: Label
var _ending_in := -1.0  # seconds until the ending card fades in


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.55)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	root.add_child(_crosshair)

	_prompt = _label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.position = Vector2(-300, 28)
	_prompt.size = Vector2(600, 40)

	_objective = _label(root, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_objective.position = Vector2(32, 26)
	_objective.size = Vector2(700, 60)
	_objective.modulate = Color(0.85, 0.85, 0.8, 0.9)

	_clock = _label(root, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_clock.position = Vector2(-232, 26)
	_clock.size = Vector2(200, 40)
	_clock.modulate = Color(0.95, 0.4, 0.35, 0.9)

	_subtitle = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_subtitle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_subtitle.position = Vector2(-560, -150)
	_subtitle.size = Vector2(1120, 110)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	_build_inspect(root)
	_build_start(root)
	_build_ending(root)
	# The HUD only displays; clicks belong to the game's _unhandled_input (start, interact, phone light).
	for c: Node in root.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	EventBus.subtitle_requested.connect(show_subtitle)
	EventBus.inspect_requested.connect(show_inspect)
	EventBus.ending_reached.connect(func(_id: StringName) -> void: _ending_in = 3.0)


func bind(p: PlayerController) -> void:
	player = p
	player.interaction.target_changed.connect(func(prompt: String) -> void:
		_prompt.text = "[E]  %s" % prompt if prompt != "" else "")
	player.input_enabled = false


func _label(parent: Control, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _build_inspect(root: Control) -> void:
	_inspect = PanelContainer.new()
	_inspect.set_anchors_preset(Control.PRESET_CENTER)
	_inspect.custom_minimum_size = Vector2(620, 0)
	_inspect.position = Vector2(-310, -160)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	style.set_content_margin_all(28)
	style.border_color = Color(0.5, 0.45, 0.35, 0.6)
	style.set_border_width_all(1)
	_inspect.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_inspect.add_child(box)
	_inspect_title = _label(box, 26, HORIZONTAL_ALIGNMENT_LEFT)
	_inspect_text = _label(box, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_inspect_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspect_text.custom_minimum_size = Vector2(560, 0)
	var hint := _label(box, 16, HORIZONTAL_ALIGNMENT_RIGHT)
	hint.text = "[E] close"
	hint.modulate = Color(1, 1, 1, 0.5)
	_inspect.visible = false
	root.add_child(_inspect)


func _build_start(root: Control) -> void:
	_start = ColorRect.new()
	(_start as ColorRect).color = Color(0, 0, 0, 0.94)
	_start.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_start)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-360, -150)
	box.custom_minimum_size = Vector2(720, 300)
	box.add_theme_constant_override("separation", 18)
	_start.add_child(box)
	var title := _label(box, 46, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "THE CONDO: 11:47 PM"
	var body := _label(box, 18, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Headphones recommended. Contains flickering lights, sudden sounds and themes of isolation.\nReduced flashing and brightness are in the pause menu (Esc)."
	body.modulate = Color(1, 1, 1, 0.7)
	var click := _label(box, 22, HORIZONTAL_ALIGNMENT_CENTER)
	click.text = "Click to begin"


func _build_ending(root: Control) -> void:
	_ending = ColorRect.new()
	_ending.color = Color(0, 0, 0, 0.96)
	_ending.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending.visible = false
	root.add_child(_ending)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.position = Vector2(-380, -200)
	box.custom_minimum_size = Vector2(760, 400)
	box.add_theme_constant_override("separation", 22)
	_ending.add_child(box)
	_ending_title = _label(box, 44, HORIZONTAL_ALIGNMENT_CENTER)
	_ending_text = _label(box, 20, HORIZONTAL_ALIGNMENT_CENTER)
	_ending_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ending_text.modulate = Color(1, 1, 1, 0.8)
	var again := _label(box, 18, HORIZONTAL_ALIGNMENT_CENTER)
	again.text = "Thank you for playing.\nClick to play again."
	again.modulate = Color(1, 1, 1, 0.5)


func is_ending_shown() -> bool:
	return _ending.visible


func _unhandled_input(event: InputEvent) -> void:
	if _ending.visible:
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()
		return
	if _start.visible:
		if event is InputEventMouseButton and event.pressed:
			start()
			get_viewport().set_input_as_handled()
		return
	if _inspect.visible and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		close_inspect()
		get_viewport().set_input_as_handled()


## Leaves the start card and starts the game (a click, or the release smoke check).
func start() -> void:
	_start.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.input_enabled = true
	started.emit()


func show_subtitle(text: String, duration: float) -> void:
	if not Settings.get_value("subtitles") and not text.begins_with("\""):
		return  # sound captions are optional; dialogue (quoted) always shows
	_subtitle.text = text
	_subtitle_left = duration


func show_inspect(title: String, text: String) -> void:
	_inspect_title.text = title
	_inspect_text.text = text
	_inspect.visible = true
	_crosshair.visible = false
	_prompt.visible = false
	player.input_enabled = false
	player.interaction.enabled_input = false


func close_inspect() -> void:
	_inspect.visible = false
	_crosshair.visible = true
	_prompt.visible = true
	player.input_enabled = true
	# Re-enable on the next frame so the closing key press doesn't re-open the object.
	player.interaction.set_deferred(&"enabled_input", true)


func is_inspecting() -> bool:
	return _inspect.visible


func _process(delta: float) -> void:
	if _ending_in > 0.0:
		_ending_in -= delta
		if _ending_in <= 0.0:
			var e: Array = StoryDirector.ENDINGS[WorldState.ending]
			_ending_title.text = e[0]
			_ending_text.text = e[1]
			_inspect.visible = false
			_ending.visible = true
	if _subtitle_left > 0.0:
		_subtitle_left -= delta
		if _subtitle_left <= 0.0:
			_subtitle.text = ""
	var minutes := WorldState.clock_minutes()
	var h := minutes / 60
	_clock.text = "%d:%02d %s" % [12 if h % 12 == 0 else h % 12, minutes % 60, "AM" if h < 12 else "PM"]
