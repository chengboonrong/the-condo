# Renders stills of the road down the mountain, one PNG per shot, plus a contact sheet (needs a window, not --headless).
#   tools/road_stills.sh /tmp/road-stills/after [shot ...]   (the window size and the override.cfg it needs)
#   godot --path . --script res://tools/road_stills.gd -- --out=<dir> [--before=<dir>] [shot ...]
# With --before, each cell of sheet.png pairs the same still from that directory (left) with the new one (right).
# Each shot starts its mission as the road's --mission flag does (RoadDirector.start_at); the simulation stands still.
extends SceneTree

# [name, mission index (or its class name), s, metres across (+ left), yaw from down the road (+ left), pitch, fog 0 to
#  1, phone light, optional: the director's ride fields to set after start_at; seated, the yaw is from the car's
#  forward instead. "pull_in" in it: the slow car then pulls into its lay-by, and these fields are set once it has
#  stopped; "play_out" in it: seconds the shot's cues play out for before it is taken; optional: who is saying a
#  line, so the couple turn (&"": no one); optional: road cues to send after the ride's fields (and once he stands
#  where the shot has him), as the mission's begin() would, a number among them being seconds to let them play out;
#  optional: where she is, held still: seconds into a glimpse cued where the car is, played on a frame at a time as
#  Mission 2 drives (slowing from the car's speed), [metres ahead of the camera, metres up], "roof": on the car's
#  roof, "behind": behind him, "lunge": right behind him as he looks back, "lunge_back": LUNGE_BACK s after that, or
#  "cued": wherever the cues left her]
# Cues stay played (a dead car stays dead), so the shots that send the stall's come last, and the walk's after them.
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
	["slow_car", 1, 0.0, 0.0, 0.0, -0.03, 0.0, false, {"seated": true, "car_s": 140.0, "car_speed": 4.0, "slow_gap": 12.0}],  # behind it, in the headlights
	["overtake", 1, 0.0, 0.0, 0.16, -0.03, 0.12, false, {"seated": true, "car_s": 140.0, "car_speed": 8.0, "lane": 0.0, "slow_gap": 8.0}],  # pulling out, level with its tail, in the headlights
	["lay_by", 1, 0.0, 0.0, 0.45, -0.03, 0.0, false, {"seated": true, "car_s": 634.0, "car_speed": 9.0, "lane": 0.9, "slow_gap": 12.0, "pull_in": {"car_s": 647.0, "lane": 0.9}}],  # it has pulled in, dark: they edge by (the keeper's, in switchback 1)
	["couple", 0, 615.0, 0.0, -0.15, -0.12, 0.0, false, {"seated": true, "car_s": 615.0, "car_speed": 9.0}],  # Hafiz and Mei from his seat
	["mei_turns", 0, 615.0, 0.0, -0.15, -0.12, 0.0, false, {"seated": true, "car_s": 615.0, "car_speed": 9.0}, &"mei"],  # Mei turns to him
	["mirror_fourth", "CountMission", 0.0, 0.0, -0.33, 0.07, 0.0, false, {"seated": true, "car_s": 900.0, "car_speed": 9.0},
		&"", [&"mirror_on"]],  # from his seat, the rear-view mirror and who sits beside him in it
	# her glimpses after overtakes 1, 2 and 3, cued where Mission 2 cued them on runs (the valley on the left at 523, the
	# hill at 740): in the windscreen as she keeps pace (_strip, 0.4 s in), and in the front door's window as she goes
	["her_glimpse_1", 1, 0.0, 0.0, 0.0, 0.03, 0.12, false, {"seated": true, "car_s": 523.0, "car_speed": 14.0, "her_near": 0.12}, &"", [], 1.1],
	["her_glimpse_2_strip", 1, 0.0, 0.0, 0.0, 0.03, 0.24, false, {"seated": true, "car_s": 523.0, "car_speed": 14.0, "her_near": 0.24}, &"", [], 0.4],
	["her_glimpse_2", 1, 0.0, 0.0, 0.0, 0.03, 0.24, false, {"seated": true, "car_s": 523.0, "car_speed": 14.0, "her_near": 0.24}, &"", [], 1.1],
	["her_glimpse_3_strip", 1, 0.0, 0.0, 0.0, 0.03, 0.36, false, {"seated": true, "car_s": 523.0, "car_speed": 14.0, "her_near": 0.36}, &"", [], 0.4],
	["her_glimpse_3", 1, 0.0, 0.0, 0.0, 0.03, 0.36, false, {"seated": true, "car_s": 523.0, "car_speed": 14.0, "her_near": 0.36}, &"", [], 1.1],
	["her_glimpse_1_hill", 1, 0.0, 0.0, 0.0, 0.03, 0.12, false, {"seated": true, "car_s": 740.0, "car_speed": 14.0, "her_near": 0.12}, &"", [], 1.0],
	["her_glimpse_2_hill_strip", 1, 0.0, 0.0, 0.0, 0.03, 0.24, false, {"seated": true, "car_s": 740.0, "car_speed": 14.0, "her_near": 0.24}, &"", [], 0.4],
	["her_glimpse_2_hill", 1, 0.0, 0.0, 0.0, 0.03, 0.24, false, {"seated": true, "car_s": 740.0, "car_speed": 14.0, "her_near": 0.24}, &"", [], 1.1],
	["her_glimpse_3_hill_strip", 1, 0.0, 0.0, 0.0, 0.03, 0.36, false, {"seated": true, "car_s": 740.0, "car_speed": 14.0, "her_near": 0.36}, &"", [], 0.4],
	["her_glimpse_3_hill", 1, 0.0, 0.0, 0.0, 0.03, 0.36, false, {"seated": true, "car_s": 740.0, "car_speed": 14.0, "her_near": 0.36}, &"", [], 1.1],
	["her_full", 0, 796.0, 1.8, 0.0, 0.0, 0.12, false, {"car_s": 793.0}, &"", [], [6.0, 0.0]],  # checking only, never published: in the parked car's lights
	["her_close", 0, 800.0, 1.0, 0.0, 0.0, 0.6, true, {}, &"", [], [0.6, 0.0]],  # where she stops, by his phone's light
	# the car has died on the long straight and Hafiz has gone: she is on the roof, her insides at his window, seen by
	# his phone's light
	["her_roof", "StallMission", 0.0, 0.0, 1.1, 0.12, 0.0, true, {"seated": true, "car_s": 2000.0, "car_speed": 0.0, "play_out": 4.5}, &"",
		[&"lights_dying", &"hafiz_leaves", &"insects_stop"], "roof"],
	# then it goes quiet, and from his seat the light shows far down the road past Mei, who leans in to see it
	["light_seen", "StallMission", 0.0, 0.0, 0.0, 0.02, 0.0, false,
		{"seated": true, "car_s": 2000.0, "car_speed": 0.0, "light_s": 2150.0, "play_out": 8.0}, &"mei",
		[&"lights_dying", &"hafiz_leaves", &"insects_stop", &"light_on"]],
	# the walk to the light (Mission 5), the light 150 m on from the car: Mei a metre to his left in his phone's light
	["walk_mei", "LightMission", 2100.0, 3.3, PI / 2.0, -0.04, 0.0, true, {}, &"", [], "behind"],
	["walk_mei_looks", "LightMission", 2100.0, 3.3, PI / 2.0, -0.04, 0.0, true, {}, &"", [&"mei_looks", 0.8], "behind"],  # and as she looks back
	# the light ahead as he walks to it, from 75 m, 35 m and 8 m: the haze gives way to the bulb at the closed stall
	["walk_light", "LightMission", 2075.0, 3.3, 0.0, 0.0, 0.0, true, {}, &"", [], "behind"],
	["walk_near", "LightMission", 2115.0, 3.3, 0.0, 0.0, 0.0, true, {}, &"", [], "behind"],
	# checking only, never published: he looks back on the walk after one counted look, and she is right behind him, by
	# her own fill alone and with his phone light on
	["lunge", "LightMission", 2100.0, 3.3, PI, 0.0, 0.36, false, {"her_near": 0.36}, &"", [], "lunge"],
	["lunge_phone", "LightMission", 2100.0, 3.3, PI, 0.0, 0.36, true, {"her_near": 0.36}, &"", [], "lunge"],
	["lunge_back", "LightMission", 2100.0, 3.3, PI, 0.0, 0.36, false, {"her_near": 0.36}, &"", [], "lunge_back"],  # and as she pulls back
	["stall", "LightMission", 2142.0, 3.3, 0.15, -0.12, 0.0, false],
	# checking only, never published: each ending (saved first: alive takes the phone off the table)
	["ending_saved", "LightMission", 2146.0, 3.3, 0.35, -0.3, 0.24, false, {}, &"", [&"phone_rings", 0.5]],  # his phone rings on the table
	# where alive is decided, 30 m short of the light in the clearest fog: just before, as Hafiz sets off up the road out
	# of the fog below, and 2 s on
	["alive_before", "LightMission", 2120.0, 3.3, 0.0, 0.0, 0.0, true],
	["alive_decided", "LightMission", 2120.0, 3.3, 0.0, 0.0, 0.0, true, {}, &"", [&"hafiz_at_stall"]],
	["alive_2s", "LightMission", 2120.0, 3.3, 0.0, 0.0, 0.0, true, {}, &"", [&"hafiz_at_stall", 2.0]],
	# there: his torch comes on near them, the lorry he flagged down passes them, and it has pulled up past the stall
	["alive_torch", "LightMission", 2146.0, 3.3, 0.0, 0.0, 0.0, false, {}, &"", [&"hafiz_at_stall", 16.5]],
	["alive_pass", "LightMission", 2146.0, 3.3, -0.35, 0.0, 0.0, false, {}, &"", [&"hafiz_at_stall", 8.0, &"walk_over", &"lorry_flagged", 14.5]],
	["ending_alive", "LightMission", 2146.0, 3.3, 0.0, 0.0, 0.0, false, {}, &"", [&"hafiz_at_stall", 7.0, &"walk_over", &"lorry_flagged", 19.5]],
	# caught at its thickest fog, the breaker's, at level gaze: she is on Hafiz, the pool spreading; then she comes
	["ending_caught", "LightMission", 2120.0, 3.3, 0.0, 0.0, 1.0, true, {"her_near": 1.0}, &"",
		[&"her_behind", 1.0, &"light_out", 6.0, &"her_catches_hafiz", 6.0], "cued"],
	["her_comes", "LightMission", 2120.0, 3.3, 0.0, 0.0, 1.0, true, {"her_near": 1.0}, &"",
		[&"her_behind", 1.0, &"light_out", 6.0, &"her_catches_hafiz", 6.5, &"her_comes", 0.15], "cued"],
]
## Checking only: shots whose luminance is measured where Hafiz, the pool and she are, against the road round them.
const PROBED := [&"ending_caught", &"her_comes"]
const LUNGE_BACK := 0.8  # seconds after the lunge that lunge_back is taken: the hold, then 0.3 s pulling back
const CELL := Vector2i(640, 360)
const PATCH := 4  # pixels each side of a probed point
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
	var bus = root.get_node("EventBus")
	for i in shots.size():
		var s: Array = shots[i]
		var mission: int = s[1] if s[1] is int else road.director.missions.find_custom(
			func(m: RefCounted) -> bool: return m.get_script().get_global_name() == s[1])
		road.car.mirror.set_on(false)  # every shot starts with it off; a shot's cues turn it on
		road.director.start_at(mission)
		road.director.fog = s[6]
		var ride: Dictionary = s[8] if s.size() > 8 else {}
		for key: String in ride:
			if key != "pull_in" and key != "play_out":
				road.director.set(key, ride[key])
		road.to_the_light()  # what the walk to the light sets as it begins (the simulation, which does, stands still)
		await process_frame  # the road follows the core's ride in its _process: the car, and his seat
		await process_frame
		if not player.is_seated():
			player.global_position = layout.point(s[2], s[3])
			player.set_look(builder.yaw_along(s[2]) + s[4], s[5])
		var cued: bool = s.size() > 11 and s[11] is String and s[11] == "cued"
		road.lorry.visible = false  # off the road unless a shot's cues bring it
		road.lorry.set_process(false)
		road.her.set_process(true)  # the cues play out with her moving
		for cue: Variant in (s[10] if s.size() > 10 else []):  # once the car is there: Hafiz gets out of it
			if cue is float:
				await create_timer(cue).timeout
			else:
				bus.road_cue.emit(cue)
		if cued:
			road.her.set_process(false)  # held where the cues left her
		if ride.has("pull_in"):  # the slow car pulls in and goes dark, and the couple go by it
			road.slow_car.pull_in()
			road.director.slow_gap = NAN
			while road.slow_car.speed > 0.0:
				await process_frame
			for key: String in ride["pull_in"]:
				road.director.set(key, ride["pull_in"][key])
			await process_frame
			await process_frame
		if ride.has("play_out"):  # the cues play out: the car dies, Hafiz walks off
			await create_timer(ride["play_out"]).timeout
		if player.is_seated():
			player.set_look(PI + s[4], s[5])
		player.phone_light.visible = s[7]
		if s.size() > 9:
			road.couple.turn_to(s[9], 60.0)
			await create_timer(1.0).timeout  # the turn takes Couple.TURN
		var her = road.her
		if not cued:
			her.hide_her()
			her.set_process(true)
		if s.size() > 11 and not cued:
			if s[11] is String and s[11] == "behind":
				her.behind(player)
			elif s[11] is String and s[11].begins_with("lunge"):
				her.behind(player)
				her.lunge(player.camera)
				if s[11] == "lunge_back":  # played on a frame at a time, so what hangs from her trails as she goes
					for k in roundi(LUNGE_BACK * 60.0):
						her._process(1.0 / 60.0)
			elif s[11] is String:  # "roof"
				her.on_roof(road.car)
			elif s[11] is float:
				her.show_glimpse()
				her.set_process(false)  # played on by hand, as the car drives
				var cue: float = road.director.car_s
				var speed: float = road.director.car_speed
				var accel: float = load("res://scripts/road/road_director.gd").ACCEL
				for k in range(1, roundi(s[11] * 60.0) + 1):  # she keeps pace with the car, then stops dead: a frame
					var t := k / 60.0  # at a time, as played, so what hangs from her trails as she goes and swings after
					road.director.car_s = cue + speed * t - 0.5 * accel * t * t
					road.director.car_speed = speed - accel * t
					her._process(1.0 / 60.0)
				await process_frame  # the car and his seat follow the core
				await process_frame
			else:
				var cam: Camera3D = player.camera
				her.come_for(cam)
				var ahead: Vector3 = cam.global_basis.z.slide(Vector3.UP).normalized() * -s[11][0]
				her._base = cam.global_position + ahead + Vector3.UP * s[11][1]
			her._process(0.0)
			her.set_process(false)  # held there
		road.look.settle()
		for f in 10:  # the fog follows the director on the next frame; also lets the grade's ramp texture refresh
			await process_frame
		var img := root.get_texture().get_image()
		img.save_png("%s/%s.png" % [out, s[0]])
		if PROBED.has(StringName(s[0])):
			_probe(s[0], img, road, layout)
		if s.size() > 9:  # the line ends, and they face the road again before the next shot
			road.couple.turn_to(s[9], 0.0)
			await create_timer(1.0).timeout
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


## Prints the mean luma (0-255, Rec. 709 of the sRGB pixels) of a patch where Hafiz's chest, the pool, she and his
## fallen phone's light are drawn, and of the road round the pool: 1.6 m to its right (to its left is the edge line),
## and 2 m nearer and further along the road.
func _probe(shot: String, img: Image, road: Node3D, layout: Script) -> void:
	var cam: Camera3D = road.player.camera
	var pool: Vector3 = road.her.pool.global_position
	var s: float = layout.closest_s(pool)
	var across: float = layout.across(pool, s)
	var points := {
		"hafiz": road.couple.hafiz_out.global_transform * Vector3(0.0, 1.1, 0.0),
		"pool": pool,
		"her": road.her.global_position,
		"phone": road.endings.dropped_light.global_position,
		"road_right": layout.point(s, across - 1.6),
		"road_near": layout.point(s - 2.0, across),
		"road_far": layout.point(s + 2.0, across),
	}
	var line := "probe %s:" % shot
	var k := img.get_width() / cam.get_viewport().get_visible_rect().size.x  # the window stretches the canvas
	for key: String in points:
		var at := Vector2i(cam.unproject_position(points[key]) * k)
		var sum := 0.0
		var n := 0
		for y in range(at.y - PATCH, at.y + PATCH + 1):
			for x in range(at.x - PATCH, at.x + PATCH + 1):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					var c := img.get_pixel(x, y)
					sum += 255.0 * (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
					n += 1
		line += " %s=%.0f@%s" % [key, sum / maxf(n, 1.0), at]
	print(line)
