# Renders the trailer's stills, one PNG per shot, plus a contact sheet (needs a window, not --headless).
#   godot --path . --script res://tools/stills.gd -- --out=/tmp/condo-stills/after [--before=/tmp/condo-stills/before] [--act=2] [--road=caught]
# With --before, each cell of sheet.png pairs the same still from that directory (left) with the new one (right).
# --act=N shoots every still in act N (default 1), so in that act's colour grade; each shot settles the grade first.
# door_feet and peephole are the visitor's, an act 2 event: they are meant for --act=2.
# --road=alive|saved|caught shoots the flat as that road ending leaves it: the red earth by the front door is built, and
# the wake card is waited out. footprints is meant for it (without it, the same view of a bare floor).
extends SceneTree

# [name, x, z, yaw, pitch, lights on, variants, figure or null, phone light, fov or 0 for the default, faces away]
const SHOTS := [
	["living", 6.5, 8.4, 0.0, 0.15, [], {}, null, false, 0.0, false],
	["footprints", 6.5, 8.4, 1.88, -0.35, [], {}, null, true, 0.0, false],
	["entrance", 2.75, 7.25, 2.24, -0.1, [&"entrance"], {}, null, false, 0.0, false],
	["bedroom_wall", 7.2, 2.1, 0.149, -0.12, [], {}, null, true, 0.0, false],
	["shoes", 2.7, 9.6, 0.7, -0.5, [&"entrance"], {}, null, false, 0.0, false],
	["shoes_moved", 2.7, 9.6, 0.7, -0.5, [&"entrance"], {&"entrance_shoes": &"moved"}, null, false, 0.0, false],
	["chair_turned", 5.5, 7.0, 0.723, -0.3, [], {&"living_chair": &"turned"}, null, false, 0.0, false],
	["tap", 4.4, 0.3, 2.137, -0.35, [], {&"bathroom_tap": &"running"}, null, true, 0.0, false],
	["hallway_figure", 4.6, 3.25, -PI / 2, 0.0, [&"hallway"], {}, Vector3(9.6, 0, 3.25), false, 0.0, false],
	["kitchen_figure", 1.5, 6.5, 0.114, -0.05, [], {}, Vector3(1.1, 0, 3.0), true, 0.0, false],
	["clock", 5.3, 5.6, 0.0, 0.28, [], {}, null, false, 28.0, false],
	["bedroom_lit", 7.2, 1.9, 0.1, 0.0, [&"bedroom"], {}, null, false, 0.0, false],
	["b1107", 7.75, -14.6, 0.0, -0.1, [], {&"bedroom": &"door"}, null, false, 0.0, false],
	["still_gap", 7.7, -2.6, 0.0, 0.0, [], {&"bedroom": &"door"}, Vector3(7.7, 0, -11.2), false, 0.0, true],
	# The visitor's two looks (act 2): the feet are set by name below, and so is the HUD's lens view. Nothing of the reveal.
	["door_feet", 3.5, 7.8, 2.386, -0.45, [], {}, null, false, 0.0, false],
	["peephole", 1.5, 9.0, 0.0, 0.0, [], {}, null, false, 0.0, false],
]
const CELL := Vector2i(640, 360)
const COLUMNS := 3


func _initialize() -> void:
	var out := "/tmp/condo-stills/after"
	var before := ""
	var act := 1
	var road := &""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg.begins_with("--before="):
			before = arg.trim_prefix("--before=")
		elif arg.begins_with("--act="):
			act = arg.trim_prefix("--act=").to_int()
		elif arg.begins_with("--road="):
			road = StringName(arg.trim_prefix("--road="))
	DirAccess.make_dir_recursive_absolute(out)
	root.get_node("Journey").road_ending = road  # before main loads: the flat builds the red earth only after a road ending
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	while not main.loaded:  # the shader warm-up moves its own camera around first
		await process_frame
	var world := root.get_node("WorldState")  # autoload names don't resolve in --script files
	world.set_act(act)
	var layout = load("res://scripts/world/apartment_layout.gd")
	var player = main.player  # untyped: project class names can't be referenced from the startup script
	var hud = main.hud
	var sil = main.silhouette
	var bus := root.get_node("EventBus")
	var peephole = main.builder.doors[&"main_door"].get_node("peephole")
	var initial_lights: Dictionary = world.lights.duplicate()
	var areas := {}  # every area some shot varies, so each shot starts from the defaults
	for s: Array in SHOTS:
		for area: StringName in s[6]:
			areas[area] = true
	player.set_physics_process(false)
	sil.set_physics_process(false)  # no sighting and no stinger while the figure is on show
	main.set_physics_process(false)  # the simulation stands still: no director event (a slam, a visit) lands in a shot
	hud._start.visible = false
	hud._objective.text = ""
	hud._crosshair.visible = false
	hud._prompt.visible = false
	hud._clock.visible = false
	while hud.is_card_shown():  # after a road ending main shows "11:47 PM" and fades it out over 1.5 s
		await process_frame
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
			sil.look_at(Vector3(s[1], 0, s[2]), Vector3.UP, not s[10])  # the model faces +Z: true turns it to the camera, false its back
			sil._set_alpha(0.95)
			sil._fading = false  # warm_up() left it fading: shoot it solid, as it is first seen
			sil.visible = true
		else:
			sil.visible = false
		# The grade follows the player's room, which main only updates on the next physics tick: set it now so
		# settle() jumps to this shot's grade (B-11-07's for b1107) instead of easing there over 4 s.
		world.set_player_room(layout.room_at(player.global_position, world.variants))
		main.look.settle()
		if s[0] == "door_feet":
			bus.door_feet_requested.emit(true)
		elif s[0] == "peephole":
			hud.show_peephole(peephole.view)
		for f in 10:  # also lets the grade's ramp texture refresh (deferred) before the capture
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, s[0]])
		if s[0] == "door_feet":
			bus.door_feet_requested.emit(false)
		elif s[0] == "peephole":
			hud._leave_peephole()
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
