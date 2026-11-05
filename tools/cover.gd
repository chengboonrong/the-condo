# Renders the itch.io cover (630x500) from a game still: the still, cropped to fill around --focus (0 = left edge,
# 1 = right edge), with the title in the game's own UI font, as on the trailer's cards (needs a window, not --headless).
#   godot --path . --script res://tools/cover.gd -- --still=<abs>.png --out=<abs>.png [--focus=0.5]
extends SceneTree

const SIZE := Vector2i(630, 500)
const RED := Color(0.95, 0.4, 0.35)  # the HUD clock's red, as on the trailer's 11:47 PM card
## [text, font size, colour, top in pixels]
const LINES := [
	["THE CONDO", 76, Color(1, 1, 1), 18],
	["11:47 PM", 44, RED, 98],
]


func _initialize() -> void:
	var still_path := ""
	var out := ""
	var focus := 0.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--still="):
			still_path = arg.trim_prefix("--still=")
		elif arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--focus="):
			focus = arg.trim_prefix("--focus=").to_float()
	var still := Image.load_from_file(still_path)
	if still == null or still.is_empty() or out == "":
		push_error("usage: -- --still=<abs>.png --out=<abs>.png [--focus=0.5]")
		quit(1)
		return
	var h := still.get_height()
	var w := mini(roundi(h * SIZE.x / float(SIZE.y)), still.get_width())
	var x := clampi(roundi(focus * still.get_width() - w / 2.0), 0, still.get_width() - w)
	var crop := still.get_region(Rect2i(x, 0, w, h))
	crop.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)

	var vp := SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(crop)
	vp.add_child(bg)
	for line: Array in LINES:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(0, line[3])
		label.size = Vector2(SIZE.x, 0)
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_constant_override("outline_size", 8)  # as the trailer's cards over the picture
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		vp.add_child(label)
	for f in 3:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_png(out)
	if err != OK:
		push_error("could not save %s: %s" % [out, error_string(err)])
		quit(1)
		return
	print("saved ", out)
	quit()
