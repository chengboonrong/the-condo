class_name Hud
extends CanvasLayer
## Crosshair, interaction prompt, objective, clock, subtitles, the road's choices, inspection panel, the peephole's
## lens, the start card and a black card for scene changes.

signal started

const FILM_SHADER := """
shader_type canvas_item;
uniform float grain = 0.035;
uniform float vignette = 0.55;
uniform float pixel_size = 1.0;  // window pixels per 3D pixel, set by Look

float hash(vec2 p) {  // Dave Hoskins' hash12 (MIT): no sin(), so no patterns on mobile GPUs
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.82);
	float v = smoothstep(0.3, 0.75, length(d)) * vignette;
	// New grain 24 times a second, like film, one value per 3D pixel: pixel_size window pixels share a hash
	// input. The frame number wraps at 256: unbounded, the offset grows so large that float32 rounding turns
	// the grain into a tile repeating every 97 px after ~30 minutes.
	float n = hash(floor(FRAGCOORD.xy / pixel_size) + mod(floor(TIME * 24.0), 256.0) * 61.7);
	// Grain over the picture, then the vignette darkens both: (1 - v) * mix(picture, n, grain). The grain
	// fades into the dark corners with everything else instead of standing out there.
	float a = max(v + grain * (1.0 - v), 0.0001);
	COLOR = vec4(vec3(n * grain * (1.0 - v) / a), a);
}
"""
## The peephole's fisheye over its camera's flat picture, inside a round black mask.
const LENS_SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float half_fov = 1.0472;  // the view camera's, vertically, in radians: what the rim shows
uniform float radius = 0.45;  // of the round glass, in screen heights
uniform float rim = 0.8;  // how much the glass darkens at its edge

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);  // from the centre, in screen heights
	float r = length(p) / radius;  // 1 at the rim
	// An even fisheye: the angle off the axis grows with r, up to half_fov at the rim. The flat picture puts
	// that angle at tan(angle) from its centre, so the middle is magnified, the edges squeezed and straight
	// lines bow; the rim lands on the picture's top and bottom edges. Outside the glass r is clamped to the rim:
	// tan has its pole past r = 1.29 at 140 degrees, and texture() on inf or NaN is undefined (the mask hides it).
	vec2 src = p / max(length(p), 1e-5) * 0.5 * tan(min(r, 1.0) * half_fov) / tan(half_fov);
	vec3 c = texture(screen, src / vec2(aspect, 1.0) + 0.5).rgb;
	c *= 1.0 - rim * smoothstep(0.45, 1.0, r);
	c *= 1.0 - smoothstep(1.0 - 2.0 * SCREEN_PIXEL_SIZE.y / radius, 1.0, r);  // a 2 px soft edge
	COLOR = vec4(c, 1.0);
}
"""

var player: PlayerController
var film_material := ShaderMaterial.new()  # Look sets its pixel_size
var _prompt: Label
var _objective: Label
var _clock: Label
var _caption: Label
var _caption_left := 0.0
var _subtitle: Label
var _subtitle_left := 0.0
var _choices: VBoxContainer
var _choice_labels: Array[Label] = []
var _choice_id: StringName = &""
var _choice_count := 0
var _chosen := false  # a key has answered the open choice; the rest wait for the next one
var _inspect: PanelContainer
var _inspect_title: Label
var _inspect_text: Label
var _start: Control
var _click: Label
var _can_start := false
var _started := false
var _card: ColorRect
var _card_label: Label
var _card_tween: Tween
var _crosshair: ColorRect
var _ending: ColorRect
var _ending_title: Label
var _ending_text: Label
var _ending_in := -1.0  # seconds until the ending card fades in
var _lens: ColorRect
var _lens_material := ShaderMaterial.new()
var _lens_hint: Label
var _peeping := false


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# The peephole's lens: over the 3D view and under the film, so the grain stays screen-fine on top of it.
	_lens = ColorRect.new()
	_lens.set_anchors_preset(Control.PRESET_FULL_RECT)
	var lens_shader := Shader.new()
	lens_shader.code = LENS_SHADER
	_lens_material.shader = lens_shader
	_lens.material = _lens_material
	_lens.visible = false
	root.add_child(_lens)

	# Film grain and a vignette over the 3D view, under the text. The grain also hides the banding that
	# 8-bit dark gradients show on most screens.
	var film := ColorRect.new()
	film.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = FILM_SHADER
	film_material.shader = shader
	film.material = film_material
	root.add_child(film)

	_lens_hint = _label(root, 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_lens_hint.text = "[E] step back"
	_lens_hint.modulate = Color(1, 1, 1, 0.5)
	_lens_hint.visible = false
	_anchor(_lens_hint, Control.PRESET_BOTTOM_RIGHT, Rect2(-232, -60, 200, 30))

	_crosshair = ColorRect.new()
	_crosshair.color = Color(1, 1, 1, 0.55)
	_crosshair.size = Vector2(4, 4)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position -= Vector2(2, 2)
	root.add_child(_crosshair)

	_prompt = _label(root, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor(_prompt, Control.PRESET_CENTER, Rect2(-300, 28, 600, 40))

	_objective = _label(root, 20, HORIZONTAL_ALIGNMENT_LEFT)
	_objective.position = Vector2(32, 26)
	_objective.size = Vector2(700, 60)
	_objective.modulate = Color(0.85, 0.85, 0.8, 0.9)

	_clock = _label(root, 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_anchor(_clock, Control.PRESET_TOP_RIGHT, Rect2(-232, 26, 200, 40))
	_clock.modulate = Color(0.95, 0.4, 0.35, 0.9)

	_build_card(root)  # over the labels above, under the captions and the subtitles
	_caption = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor(_caption, Control.PRESET_CENTER_BOTTOM, Rect2(-560, -190, 1120, 40))
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN  # a second line goes up, not down into the subtitle
	_subtitle = _label(root, 24, HORIZONTAL_ALIGNMENT_CENTER)
	_anchor(_subtitle, Control.PRESET_CENTER_BOTTOM, Rect2(-560, -150, 1120, 110))
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_build_choices(root)

	_build_inspect(root)
	_build_start(root)
	_build_ending(root)
	# The HUD only displays; clicks belong to the game's _unhandled_input (start, interact, phone light).
	for c: Node in root.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.objective_changed.connect(func(t: String) -> void: _objective.text = t)
	EventBus.subtitle_requested.connect(show_subtitle)
	EventBus.line_requested.connect(show_subtitle.bind(true))
	EventBus.inspect_requested.connect(show_inspect)
	EventBus.peephole_requested.connect(show_peephole)
	EventBus.door_changed.connect(func(id: StringName, open: bool, _source: StringName) -> void:
		if _peeping and open and id == &"main_door":  # the view is on the door: it would swing into the flat
			close_peephole())
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


## Anchors c to a preset and places rect relative to the anchor point. Once c is in the sized root,
## assigning position would measure from the root's corner instead, and put c off screen.
static func _anchor(c: Control, preset: Control.LayoutPreset, rect: Rect2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = rect.position.x
	c.offset_top = rect.position.y
	c.offset_right = rect.end.x
	c.offset_bottom = rect.end.y


## The road's choices, numbered, at the bottom centre just above the caption line. Longer options push the box up.
func _build_choices(root: Control) -> void:
	_choices = VBoxContainer.new()
	root.add_child(_choices)
	_anchor(_choices, Control.PRESET_CENTER_BOTTOM, Rect2(-560, -340, 1120, 140))
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.visible = false
	for i in 3:
		var l := _label(_choices, 22, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate = Color(0.95, 0.92, 0.85)
		_choice_labels.append(l)


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


func _build_card(root: Control) -> void:
	_card = ColorRect.new()
	_card.color = Color.BLACK
	_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	root.add_child(_card)
	_card_label = _label(_card, 56, HORIZONTAL_ALIGNMENT_CENTER)
	_card_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


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
	title.text = "11:47PM"
	var body := _label(box, 18, HORIZONTAL_ALIGNMENT_CENTER)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "Headphones recommended. Contains blood and gore, flickering lights, sudden sounds and themes of isolation.\nReduced flashing and brightness: press Esc now or at any time."
	body.modulate = Color(1, 1, 1, 0.7)
	_click = _label(box, 22, HORIZONTAL_ALIGNMENT_CENTER)
	_click.text = "Loading…"


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
	# E or Esc steps back from a note or the peephole first, whatever card is up (tests look behind the start card).
	if is_inspecting() and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		if _peeping:
			close_peephole()
		else:
			close_inspect()
		get_viewport().set_input_as_handled()
		return
	if _choices.visible and not _chosen:
		for i in _choice_count:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				_chosen = true
				get_viewport().set_input_as_handled()
				EventBus.choice_made.emit(_choice_id, i)
				return
	if _ending.visible:
		if event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			Journey.restart()
		return
	if _start.visible and _can_start and event is InputEventMouseButton and event.pressed:
		start()
		get_viewport().set_input_as_handled()


## Main calls this once the shaders are compiled (see Main._compile_shaders).
func allow_start() -> void:
	_can_start = true
	_click.text = "Click to begin"


## Leaves the start card and starts the game (a click, or the release smoke check). Once only: a second call does nothing.
func start() -> void:
	if _started:
		return
	_started = true
	_start.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.input_enabled = true
	started.emit()


## A black card with centred text over everything but the subtitles. It replaces the start card, which a player
## who comes from the road has already passed: it hides the start card, so a card shown before the start makes
## the start unclickable.
func show_card(text: String) -> void:
	if _card_tween != null:
		_card_tween.kill()
	_card.modulate.a = 1.0
	_card_label.text = text
	_card.visible = true
	_start.visible = false


## Fades the card out over `seconds`.
func hide_card(seconds: float) -> void:
	if _card_tween != null:
		_card_tween.kill()
	if seconds <= 0.0:
		_card.visible = false
		return
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 0.0, seconds)
	_card_tween.tween_callback(func() -> void: _card.visible = false)


func is_card_shown() -> bool:
	return _card.visible


func card_text() -> String:
	return _card_label.text


## Shows a choice until close_choices: the HUD never closes one by itself. Keys 1–3 answer it, once.
func show_choices(choice_id: StringName, options: PackedStringArray) -> void:
	_choice_id = choice_id
	_choice_count = mini(options.size(), _choice_labels.size())
	_chosen = false
	for i in _choice_labels.size():
		_choice_labels[i].visible = i < _choice_count
		_choice_labels[i].text = "[%d]  %s" % [i + 1, options[i]] if i < _choice_count else ""
	_choices.visible = true


func close_choices(choice_id: StringName) -> void:
	if choice_id == _choice_id:
		_choices.visible = false
		_choice_id = &""


func is_choosing() -> bool:
	return _choices.visible


## A spoken line (`always`: someone says or thinks it, or it is quoted) shows whatever the captions setting, on the
## subtitle. Any other text is a sound caption: it shows only with "Captions for sounds" on, on the line above, so it
## never cuts a spoken line short. Each line keeps its own timer, and a new text replaces the one on its line.
func show_subtitle(text: String, duration: float, always := false) -> void:
	if always or text.begins_with("\""):
		_subtitle.text = text
		_subtitle_left = duration
	elif Settings.get_value("subtitles"):
		_caption.text = text
		_caption_left = duration


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


## True while reading a note or looking through the peephole: time runs, the player is held.
func is_inspecting() -> bool:
	return _inspect.visible or _peeping


## Looks through the peephole: the view is its camera, bent by the lens, and the player is held as for a note.
func show_peephole(view: Camera3D) -> void:
	_lens_material.set_shader_parameter("half_fov", deg_to_rad(view.fov) * 0.5)
	view.make_current()
	set_lens(true)
	_peeping = true
	_crosshair.visible = false
	_prompt.visible = false
	player.input_enabled = false
	player.interaction.enabled_input = false


func close_peephole() -> void:
	_leave_peephole()
	close_inspect()


func is_peeping() -> bool:
	return _peeping


## Shows the lens and its hint alone; Main's shader warm-up draws them once.
func set_lens(on: bool) -> void:
	_lens.visible = on
	_lens_hint.visible = on


## The player's own view back, without letting the player go (the ending card keeps them held).
func _leave_peephole() -> void:
	_peeping = false
	set_lens(false)
	player.camera.make_current()


func is_on_start_card() -> bool:
	return _start.visible


func _process(delta: float) -> void:
	if _ending_in > 0.0:
		_ending_in -= delta
		if _ending_in <= 0.0:
			var e := StoryDirector.ending_card(WorldState.ending, Journey.road_ending)
			_ending_title.text = e[0]
			_ending_text.text = e[1]
			_inspect.visible = false
			if _peeping:
				_leave_peephole()
			_ending.visible = true
	if _subtitle_left > 0.0:
		_subtitle_left -= delta
		if _subtitle_left <= 0.0:
			_subtitle.text = ""
	if _caption_left > 0.0:
		_caption_left -= delta
		if _caption_left <= 0.0:
			_caption.text = ""
	var minutes := WorldState.clock_minutes()
	var h := minutes / 60
	_clock.text = "%d:%02d %s" % [12 if h % 12 == 0 else h % 12, minutes % 60, "AM" if h < 12 else "PM"]
