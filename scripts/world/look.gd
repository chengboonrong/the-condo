class_name Look
extends Node
## The picture's look. The 3D view is drawn at about TARGET_LINES lines and scaled up with bilinear filtering,
## which softens it; the HUD is 2D and stays sharp. The film grain is snapped to the same 3D pixels.
## The scale is a whole divisor of the window height and follows the window, so the look is the same at any size.
## The colour grade is the Environment's own adjustment: warm and full at home, a step colder and greyer each act,
## and B-11-07 the greyest place in the game. It eases between grades and never cuts.

const TARGET_LINES := 450.0  # up to 540 if thin things shimmer or a moved object gets hard to see
const EASE_SECONDS := 4.0
## saturation and contrast are the adjustment's; black and white are the two ends of its colour-correction ramp,
## so a bluer white tints the lights and a lifted black tints the shadows. Keys 1-4 are the acts.
const GRADES := {
	1: {"saturation": 1.08, "contrast": 1.02, "black": Color(0.0, 0.0, 0.0), "white": Color(1.0, 0.96, 0.88)},
	2: {"saturation": 0.62, "contrast": 1.08, "black": Color(0.0, 0.015, 0.03), "white": Color(0.88, 0.95, 1.0)},
	3: {"saturation": 0.54, "contrast": 1.10, "black": Color(0.0, 0.018, 0.035), "white": Color(0.86, 0.94, 1.0)},
	4: {"saturation": 0.46, "contrast": 1.12, "black": Color(0.0, 0.02, 0.04), "white": Color(0.84, 0.93, 1.0)},
	&"mirror_room": {"saturation": 0.34, "contrast": 1.14, "black": Color(0.0, 0.02, 0.04), "white": Color(0.82, 0.92, 1.0)},
}

var environment: Environment  # the world's; Main sets it before add_child
var film: ShaderMaterial  # the HUD's grain and vignette; Main sets it before add_child

var _ramp := Gradient.new()  # the colour-correction ramp: black at 0, white at 1
var _shown: Dictionary  # the grade last written to the environment
var _from: Dictionary  # where the ease started
var _target: Dictionary  # where it is going
var _progress := 1.0  # 0 to 1 through the ease; 1 is a still grade


## Window pixels per 3D pixel for a window this tall: the whole number that leaves the nearest to TARGET_LINES lines.
static func divisor_for(height: int) -> int:
	return maxi(1, roundi(height / TARGET_LINES))


func _ready() -> void:
	Settings.changed.connect(_apply_filter)
	get_window().size_changed.connect(_apply_filter)
	_apply_filter()
	# On from the first frame, so the warm-up compiles the adjustment and nothing compiles mid-game.
	var texture := GradientTexture1D.new()
	texture.gradient = _ramp
	environment.adjustment_color_correction = texture
	environment.adjustment_enabled = true
	settle()


## The grade for where the player is: B-11-07's, else the act's (the ending keeps act 4's).
func target_grade() -> Dictionary:
	if WorldState.player_room == &"mirror_room":
		return GRADES[&"mirror_room"]
	return GRADES[clampi(WorldState.act, 1, 4)]


## Jumps to the target grade now and ends any ease.
func settle() -> void:
	_target = target_grade()
	_progress = 1.0
	_show(_target)


# Polled, not driven by EventBus.act_changed: WorldState.reset() sets the act without emitting it, and the room
# is only known on the physics tick. A still grade writes nothing, so the ramp texture is not re-uploaded.
func _process(delta: float) -> void:
	var target := target_grade()
	if target != _target:
		_from = _shown
		_target = target
		_progress = 0.0
	if _progress >= 1.0:
		return
	_progress = minf(1.0, _progress + delta / EASE_SECONDS)
	var w := smoothstep(0.0, 1.0, _progress)
	_show({
		"saturation": lerpf(_from["saturation"], _target["saturation"], w),
		"contrast": lerpf(_from["contrast"], _target["contrast"], w),
		"black": (_from["black"] as Color).lerp(_target["black"], w),
		"white": (_from["white"] as Color).lerp(_target["white"], w),
	})


func _show(grade: Dictionary) -> void:
	_shown = grade
	environment.adjustment_saturation = grade["saturation"]
	environment.adjustment_contrast = grade["contrast"]
	_ramp.set_color(0, grade["black"])
	_ramp.set_color(1, grade["white"])


func _apply_filter() -> void:
	var window := get_window()
	var d := divisor_for(window.size.y) if Settings.get_value("filter") else 1
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# Settings.changed fires for every setting (a brightness drag included), and resizing the 3D buffers is not free.
	if not is_equal_approx(window.scaling_3d_scale, 1.0 / d):
		window.scaling_3d_scale = 1.0 / d
	film.set_shader_parameter("pixel_size", float(d))
