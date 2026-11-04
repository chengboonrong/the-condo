# Renders a contact sheet of every room for a quick visual check (needs a window, not --headless).
#   godot --path . --script res://tools/screenshots.gd -- --out=/tmp/condo_sheet.png
extends SceneTree

# [label, x, z, yaw, pitch, lights on, variants]
const SHOTS := [
	["living (spawn)", 6.5, 8.4, 0.0, -0.1, [], {}],
	["living → entrance", 7.5, 7.2, PI / 2, -0.05, [], {}],
	["entrance → front door", 1.6, 7.7, PI, -0.1, [&"entrance"], {}],
	["kitchen", 1.9, 6.4, 0.25, -0.15, [&"kitchen"], {}],
	["hallway", 3.6, 3.25, -PI / 2, -0.05, [&"hallway"], {}],
	["bathroom", 4.4, 2.0, 0.15, -0.2, [&"bathroom"], {}],
	["bedroom, window", 7.2, 1.9, 0.1, 0.0, [&"bedroom"], {}],
	["bedroom, dark + phone light", 7.2, 1.9, 0.1, 0.0, [], {}],
	["corridor → lift", 1.5, 11.3, -PI / 2, 0.0, [], {}],
	["the reveal: window is a door", 7.6, 1.2, 0.0, 0.0, [&"bedroom"], {&"bedroom": &"door"}],
	["the gap (long), looking back", 7.7, -12.5, PI, 0.0, [], {&"bedroom": &"door", &"gap": &"long"}],
	["B-11-07", 7.75, -14.6, 0.0, -0.1, [], {&"bedroom": &"door"}],
]
const W := 640
const H := 360


func _initialize() -> void:
	var out := "/tmp/condo_sheet.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	root.size = Vector2i(1280, 720)
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	while not main.loaded:  # the shader warm-up moves its own camera around first
		await process_frame
	main.hud.visible = false
	var world := root.get_node("WorldState")  # autoload names don't resolve in --script files
	var player = main.player  # untyped: project class names can't be referenced from the startup script
	var initial_lights: Dictionary = world.lights.duplicate()
	player.set_physics_process(false)
	var sheet := Image.create(W * 4, H * 3, false, Image.FORMAT_RGB8)
	for i in SHOTS.size():
		var s: Array = SHOTS[i]
		for area: StringName in s[6]:
			world.set_variant(area, s[6][area])
		for room: StringName in initial_lights:
			world.set_light(room, initial_lights[room] or (s[5] as Array).has(room))
		player.phone_light.visible = s[0].contains("phone")
		player.global_position = Vector3(s[1], 0, s[2])
		player.set_look(s[3], s[4])
		for f in 8:
			await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(W, H)
		sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i % 4) * W, (i / 4) * H))
		print("shot ", i, ": ", s[0])
	sheet.save_png(out)
	print("saved ", out)
	main.queue_free()
	await process_frame
	quit()
