class_name Look
extends Node
## The picture's look. The 3D view is drawn at about TARGET_LINES lines and scaled up with bilinear filtering,
## which softens it; the HUD is 2D and stays sharp. The film grain is snapped to the same 3D pixels.
## The scale is a whole divisor of the window height and follows the window, so the look is the same at any size.

const TARGET_LINES := 450.0  # up to 540 if thin things shimmer or a moved object gets hard to see

var environment: Environment  # the world's; Main sets it before add_child
var film: ShaderMaterial  # the HUD's grain and vignette; Main sets it before add_child


## Window pixels per 3D pixel for a window this tall: the whole number that leaves the nearest to TARGET_LINES lines.
static func divisor_for(height: int) -> int:
	return maxi(1, roundi(height / TARGET_LINES))


func _ready() -> void:
	Settings.changed.connect(_apply_filter)
	get_window().size_changed.connect(_apply_filter)
	_apply_filter()


func _apply_filter() -> void:
	var window := get_window()
	var d := divisor_for(window.size.y) if Settings.get_value("filter") else 1
	window.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	# Settings.changed fires for every setting (a brightness drag included), and resizing the 3D buffers is not free.
	if not is_equal_approx(window.scaling_3d_scale, 1.0 / d):
		window.scaling_3d_scale = 1.0 / d
	film.set_shader_parameter("pixel_size", float(d))
