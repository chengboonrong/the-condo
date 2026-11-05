# Renders the trailer's stills, one PNG per shot, plus a contact sheet (needs a window, not --headless).
#   godot --path . --script res://tools/stills.gd -- --out=/tmp/condo-stills/after [--before=/tmp/condo-stills/before]
# With --before, each cell of sheet.png pairs the same still from that directory (left) with the new one (right).
extends SceneTree

# [name, x, z, yaw, pitch, lights on, variants, figure or null, phone light, fov or 0 for the default]
const SHOTS := [
	["living", 6.5, 8.4, 0.0, 0.15, [], {}, null, false, 0.0],
	["entrance", 2.75, 7.25, 2.24, -0.1, [&"entrance"], {}, null, false, 0.0],
	["bedroom_wall", 7.2, 2.1, 0.149, -0.12, [], {}, null, true, 0.0],
	["shoes", 2.7, 9.6, 0.7, -0.5, [&"entrance"], {}, null, false, 0.0],
	["shoes_moved", 2.7, 9.6, 0.7, -0.5, [&"entrance"], {&"entrance_shoes": &"moved"}, null, false, 0.0],
	["chair_turned", 5.5, 7.0, 0.723, -0.3, [], {&"living_chair": &"turned"}, null, false, 0.0],
	["tap", 4.4, 0.3, 2.137, -0.35, [], {&"bathroom_tap": &"running"}, null, true, 0.0],
	["hallway_figure", 4.6, 3.25, -PI / 2, 0.0, [&"hallway"], {}, Vector3(9.6, 0, 3.25), false, 0.0],
	["kitchen_figure", 1.5, 6.5, 0.114, -0.05, [], {}, Vector3(1.1, 0, 3.0), true, 0.0],
	["clock", 5.3, 5.6, 0.0, 0.28, [], {}, null, false, 28.0],
	["bedroom_lit", 7.2, 1.9, 0.1, 0.0, [&"bedroom"], {}, null, false, 0.0],
	["b1107", 7.75, -14.6, 0.0, -0.1, [], {&"bedroom": &"door"}, null, false, 0.0],
]
const CELL := Vector2i(640, 360)
const COLUMNS := 3


func _initialize() -> void:
	var out := "/tmp/condo-stills/after"
	var before := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--before="):
			before = arg.trim_prefix("--before=")
	DirAccess.make_dir_recursive_absolute(out)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	while not main.loaded:  # the shader warm-up moves its own camera around first
		await process_frame
	var world := root.get_node("WorldState")  # autoload names don't resolve in --script files
	var player = main.player  # untyped: project class names can't be referenced from the startup script
	var hud = main.hud
	var sil = main.silhouette
	var initial_lights: Dictionary = world.lights.duplicate()
	var areas := {}  # every area some shot varies, so each shot starts from the defaults
	for s: Array in SHOTS:
		for area: StringName in s[6]:
			areas[area] = true
	player.set_physics_process(false)
	sil.set_physics_process(false)  # no sighting and no stinger while the figure is on show
	hud._start.visible = false
	hud._objective.text = ""
	hud._crosshair.visible = false
	hud._prompt.visible = false
	hud._clock.visible = false
	var fov: float = player.camera.fov
	var paired := before != ""
	var cell_w := CELL.x * (2 if paired else 1)
	var rows := ceili(SHOTS.size() / float(COLUMNS))
	var sheet := Image.create(cell_w * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGB8)
	for i in SHOTS.size():
		var s: Array = SHOTS[i]
		for room: StringName in initial_lights:
			world.set_light(room, initial_lights[room] or (s[5] as Array).has(room))
		for area: StringName in areas:
			world.set_variant(area, (s[6] as Dictionary).get(area, &"default"))
		player.global_position = Vector3(s[1], 0, s[2])
		player.set_look(s[3], s[4])
		player.phone_light.visible = s[8]
		player.camera.fov = s[9] if s[9] > 0.0 else fov
		if s[7] != null:
			sil.global_position = s[7]
			sil.look_at(Vector3(s[1], 0, s[2]), Vector3.UP, true)
			sil._set_alpha(0.95)
			sil._fading = false  # warm_up() left it fading: shoot it solid, as it is first seen
			sil.visible = true
		else:
			sil.visible = false
		for f in 10:
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, s[0]])
		img.convert(Image.FORMAT_RGB8)
		img.resize(CELL.x, CELL.y)
		var at := Vector2i((i % COLUMNS) * cell_w, (i / COLUMNS) * CELL.y)
		if paired:
			var old := Image.load_from_file("%s/%s.png" % [before, s[0]])
			if old == null or old.is_empty():
				push_warning("no before still: %s" % s[0])
			else:
				old.convert(Image.FORMAT_RGB8)
				old.resize(CELL.x, CELL.y)
				sheet.blit_rect(old, Rect2i(Vector2i.ZERO, CELL), at)
			at.x += CELL.x
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), at)
		print("still ", i, ": ", s[0])
	sheet.save_png("%s/sheet.png" % out)
	print("saved ", out)
	main.queue_free()
	await process_frame
	quit()
