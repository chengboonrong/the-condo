# Renders stills of the road down the mountain, one PNG per shot, plus a contact sheet (needs a window, not --headless).
#   tools/road_stills.sh /tmp/road-stills/after [shot ...]   (the window size and the override.cfg it needs)
#   godot --path . --script res://tools/road_stills.gd -- --out=<dir> [--before=<dir>] [shot ...]
# With --before, each cell of sheet.png pairs the same still from that directory (left) with the new one (right).
# Each shot starts its mission as the road's --mission flag does (RoadDirector.start_at); the simulation stands still.
extends SceneTree

# [name, mission index, s, metres across (+ left), yaw from down the road (+ left), pitch, fog 0 to 1, phone light,
#  optional: the director's ride fields to set after start_at; seated, the yaw is from the car's forward instead]
const SHOTS := [
	["road_exit", 0, -63.0, -1.0, 0.75, -0.05, 0.0, false],  # the staff exit in the resort's back wall, its lamp, its bin
	["road_stop", 0, -14.0, -0.5, 0.3, -0.06, 0.0, false],  # the bus stop under its lamp
	["road_bend", 0, 636.0, 1.8, -0.25, -0.08, 0.5, true],  # into the first switchback, by the phone's light
	["road_tunnel", 0, 244.0, 1.8, 0.0, 0.0, 0.0, false],  # the tunnel's mouth, lit inside
	["road_tunnel_in", 0, 290.0, 1.8, 0.0, 0.05, 0.0, false],  # inside it, its light strips
	["road_awas40", 0, 35.0, 1.0, 0.75, 0.15, 0.0, true],  # the first AWAS board, on the hill side, by the phone's light
	["road_awas431", 0, 426.5, 2.0, 0.8, 0.05, 0.0, true],  # the one behind the rail, before switchback 1
	["road_city", 0, 360.0, 1.8, 0.0, 0.0, 0.0, false],  # down the road towards KL's glow, in the clearest fog
	["car_arrives", 0, 2.0, 3.4, PI - 0.15, -0.03, 0.0, false, {"car_s": -10.0, "car_speed": 9.0}],  # from the stop
	["back_seat", 0, 615.0, 0.0, -0.25, -0.04, 0.0, false, {"seated": true, "car_s": 615.0, "car_speed": 9.0}],  # chevrons 20-40 m on
]
const CELL := Vector2i(640, 360)
const COLUMNS := 2


func _initialize() -> void:
	var out := "/tmp/road-stills/after"
	var before := ""
	var names: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--before="):
			before = arg.trim_prefix("--before=")
		else:
			names.append(arg)
	var shots := SHOTS.filter(func(s: Array) -> bool: return names.is_empty() or names.has(s[0]))
	if shots.size() < names.size():
		push_error("unknown shot in %s" % [names])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("Journey").change_scenes = false  # autoload names don't resolve in --script files
	var road: Node3D = load("res://scenes/road.tscn").instantiate()
	root.add_child(road)
	while not road.loaded:
		await process_frame
	var layout = load("res://scripts/road/road_layout.gd")  # untyped: project class names can't be referenced here
	var builder = load("res://scripts/road/road_builder.gd")
	var player = road.player
	var hud = road.hud
	player.set_physics_process(false)
	road.set_physics_process(false)  # the simulation stands still: no mission moves on in a shot
	hud._start.visible = false
	hud._objective.text = ""
	hud._crosshair.visible = false
	hud._prompt.visible = false
	hud._clock.visible = false
	var paired := before != ""
	var cell_w := CELL.x * (2 if paired else 1)
	var sheet := Image.create(cell_w * COLUMNS, CELL.y * ceili(shots.size() / float(COLUMNS)), false, Image.FORMAT_RGB8)
	for i in shots.size():
		var s: Array = shots[i]
		road.director.start_at(s[1])
		road.director.fog = s[6]
		var ride: Dictionary = s[8] if s.size() > 8 else {}
		for key: String in ride:
			road.director.set(key, ride[key])
		await process_frame  # the road follows the core's ride in its _process: the car, and his seat
		await process_frame
		if player.is_seated():
			player.set_look(PI + s[4], s[5])
		else:
			player.global_position = layout.point(s[2], s[3])
			player.set_look(builder.yaw_along(s[2]) + s[4], s[5])
		player.phone_light.visible = s[7]
		road.look.settle()
		for f in 10:  # the fog follows the director on the next frame; also lets the grade's ramp texture refresh
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
	road.queue_free()
	await process_frame
	quit()
