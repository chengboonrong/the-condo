extends TestCase
## The Blender models: their budgets, where they stand, their variants, the shader warm-up and the clock.

# Triangles each model may have. Each object task adds its ids.
const TRIS := {&"wall_clock": 1500, &"work_shoes": 2000, &"shoe_rack": 2000, &"dining_table": 6000, &"dining_chair": 2500,
	&"basin": 4000, &"tap_water": 300, &"intercom": 1000, &"front_door": 3000, &"bed": 8000, &"fridge": 4000,
	&"ceiling_fan": 3000, &"tv_cabinet": 6000,
	&"figure": 12000, &"apron_hung": 1500, &"hatchback": 14000, &"old_sedan": 8000}
# Floor footprints: node name -> [centre x, centre z, size x, size z] of the collider it replaces.
const FOOTPRINTS := {
	&"shoe_rack": [0.25, 8.0, 0.4, 1.0],
	&"shoes_moved": [2.3, 8.5, 0.28, 0.32],
	&"dining_table": [4.5, 6.2, 1.1, 0.75],
	&"chair_turned": [3.45, 5.2, 0.42, 0.42],
	&"basin": [3.3, 1.0, 0.38, 0.48],
	&"bed": [8.95, 0.2, 1.8, 2.0],  # its headboard stands a little past the base
	&"bed_b1107": [6.55, -16.3, 1.8, 2.0],
	&"fridge": [0.4, 2.95, 0.7, 0.7],
	&"tv_cabinet": [6.5, 4.3, 2.0, 0.45],  # the TV stands a few cm proud of its front
}


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame
	return main


static func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = m.global_transform * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func test_every_model_is_within_budget() -> bool:
	var ids: Array[StringName] = []
	for file in DirAccess.get_files_at("res://assets/models"):
		if file.get_extension() == "glb":
			ids.append(StringName(file.get_basename()))
	ids.sort()
	var budgeted: Array[StringName] = []
	budgeted.assign(TRIS.keys())
	budgeted.sort()
	eq(ids, budgeted, "models with a triangle budget")
	for id: StringName in ids:
		var node := ApartmentBuilder.model(id)
		var tris := 0
		for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				var arrays := m.mesh.surface_get_arrays(s)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += (indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
				var mat := m.get_active_material(s) as BaseMaterial3D
				for t in BaseMaterial3D.TEXTURE_MAX:
					var tex := mat.get_texture(t) if mat else null
					if tex:
						check(maxi(tex.get_width(), tex.get_height()) <= 1024, "%s: %s texture %d is %dx%d" % [id, m.name, t, tex.get_width(), tex.get_height()])
		check(tris <= TRIS.get(id, 0), "%s: %d triangles, budget %d" % [id, tris, TRIS.get(id, 0)])
		node.free()
	return true


func test_models_stand_where_they_collide() -> bool:
	var main := await _main()
	for name: StringName in FOOTPRINTS:
		var a := _aabb(main.builder.models[name])
		var f: Array = FOOTPRINTS[name]
		near(a.get_center().x, f[0], 0.05, "%s centre x" % name)
		near(a.get_center().z, f[1], 0.05, "%s centre z" % name)
		near(a.size.x, f[2], 0.08, "%s size x" % name)
		near(a.size.z, f[3], 0.08, "%s size z" % name)
		near(a.position.y, 0.0, 0.02, "%s stands on the floor" % name)
	main.queue_free()
	return true


func test_turned_chair_faces_the_hallway() -> bool:
	var main := await _main()
	WorldState.set_variant(&"living_chair", &"turned")
	await tree.process_frame
	var chair: Node3D = main.builder.models[&"chair_turned"]
	check(chair.visible, "the turned chair shows while the chair is turned")
	check(chair.global_basis.z.dot(Vector3.FORWARD) > 0.95, "its front points north, through the hallway opening")
	var backs := ApartmentBuilder.COLLIDERS.filter(func(c: Array) -> bool: return c[2] == {&"living_chair": &"turned"})
	eq(backs.size(), 1, "one collider for the turned chair's back")
	for back: Array in backs:
		check(back[0].z > 5.3, "its back is on the south side")
	WorldState.set_variant(&"living_chair", &"default")
	main.queue_free()
	return true


func test_the_chair_model_has_its_back_behind_its_front() -> bool:
	var chair := ApartmentBuilder.model(&"dining_chair")
	var z_sum := 0.0
	var count := 0
	for m: MeshInstance3D in chair.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D()
		var n: Node = m
		while n != chair:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		for v: Vector3 in m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := xf * v
			if p.y > 0.6:
				z_sum += p.z
				count += 1
	check(count > 0, "the chair has a back above 0.6 m")
	check(count > 0 and z_sum / count < 0.0, "the back sits behind the +Z front, as every model's front does")
	chair.free()
	return true


func test_colliders_do_not_outgrow_their_models() -> bool:
	var main := await _main()
	for c: Array in ApartmentBuilder.COLLIDERS:
		var model_top := -INF
		for node: Node3D in main.builder.models.values():
			var a := _aabb(node)
			if absf(c[0].x - a.get_center().x) <= a.size.x / 2.0 + 0.05 and absf(c[0].z - a.get_center().z) <= a.size.z / 2.0 + 0.05:
				model_top = maxf(model_top, a.end.y)
		check(model_top > 0.0, "a model stands at the collider at %s" % c[0])
		check(c[0].y + c[1].y / 2.0 <= model_top + 0.01, "the collider at %s ends at %.3f m, above its model (%.3f m)" % [c[0], c[0].y + c[1].y / 2.0, model_top])
	main.queue_free()
	return true


func test_the_stream_is_clear_water_that_starts_at_the_tap() -> bool:
	var main := await _main()
	var water: Node3D = main.builder.models[&"tap_water"]
	check(not water.visible, "the water is off until the tap is left running")
	WorldState.set_variant(&"bathroom_tap", &"running")
	await tree.process_frame
	check(water.visible, "the water shows while the tap is left running")
	var meshes := water.find_children("*", "MeshInstance3D", true, false)
	eq(meshes.size(), 1, "the stream is one mesh")
	var stream := meshes[0] as MeshInstance3D
	var mat := stream.get_active_material(0) as BaseMaterial3D
	eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_ALPHA, "the stream is plain alpha, like the game's other glass and water")
	eq(stream.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "the stream casts no shadow")
	near(mat.albedo_color.a, 0.6, 0.01, "its alpha")
	check(mat.albedo_texture == null, "its colour is plain, not baked")
	var tap: Array = ApartmentBuilder.OBJECTS.filter(func(o: Array) -> bool: return o[0] == &"tap")[0]
	check(AABB(tap[1] - tap[2] / 2.0, tap[2]).has_point(water.position), "the spout at %s is inside the tap's click box" % water.position)
	WorldState.set_variant(&"bathroom_tap", &"default")
	main.queue_free()
	return true


func test_front_door_model_fills_its_panel() -> bool:
	var main := await _main()
	var door: Door = main.builder.doors[&"main_door"]
	var shape := door.get_child(0) as CollisionShape3D
	var panel := door.get_node_or_null("front_door") as Node3D
	check(shape != null, "the collision shape is the door's first child")
	check(panel != null, "the front door's model is a child of the door")
	if shape == null or panel == null:
		main.queue_free()
		return true
	var a := AABB()
	var first := true
	for m: MeshInstance3D in panel.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = door.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		a = b if first else a.merge(b)
		first = false
	var size := (shape.shape as BoxShape3D).size
	for axis in 2:  # width and height are the panel's alone: the hardware lies inside them
		near(a.get_center()[axis], shape.position[axis], 0.005, "model centre, axis %d" % axis)
		near(a.size[axis], size[axis], 0.005, "model size, axis %d" % axis)
	# The levers, the deadbolt and the peephole stand out of both faces, the same 4.5 cm each way: the depth is the panel's and
	# then some, about the same plane.
	near(a.get_center().z, shape.position.z, 0.005, "model centre, depth")
	check(a.position.z <= shape.position.z - size.z / 2.0 + 0.005 and a.end.z >= shape.position.z + size.z / 2.0 - 0.005, "the panel is as thick as its collider")
	check(a.size.z < size.z + 0.16, "the hardware stands out %.3f m in all, not more than 0.16 m" % (a.size.z - size.z))
	main.queue_free()
	return true


func test_intercoms_sit_on_their_walls_inside_their_click_boxes() -> bool:
	var main := await _main()
	# node name -> the x of the wall's middle; both walls face east
	for entry: Array in [[&"intercom", 0.0], [&"intercom_mirror", 5.5]]:
		var name: StringName = entry[0]
		check(main.builder.models.has(name), "%s is a placed model" % name)
		if not main.builder.models.has(name):
			continue
		var a := _aabb(main.builder.models[name])
		var click: Array = ApartmentBuilder.OBJECTS.filter(func(o: Array) -> bool: return o[0] == name)[0]
		check(AABB(click[1] - click[2] / 2.0, click[2]).has_point(a.get_center()), "%s: its centre %s is inside the click box" % [name, a.get_center()])
		near(a.position.x, entry[1] + ApartmentLayout.WALL_T / 2.0, 0.005, "%s: its back is on the wall, not floating off it" % name)
		near(a.size.z, 0.09, 0.01, "%s: it is 9 cm wide, along the wall" % name)
		check(a.size.y > 0.22 and a.size.y < 0.3, "%s: it is 22 cm tall and its cord hangs a little lower (%.3f m in all)" % [name, a.size.y])
	var mirror: Node3D = main.builder.models.get(&"intercom_mirror")
	if mirror:
		check(not mirror.visible, "B-11-07's intercom is hidden until the reveal")
		WorldState.set_variant(&"bedroom", &"door")
		await tree.process_frame
		check(mirror.visible, "and shown once the window is a door")
		WorldState.set_variant(&"bedroom", &"default")
	main.queue_free()
	return true


func test_each_bed_has_its_headboard_towards_the_wall_with_its_room_door() -> bool:
	var main := await _main()
	# The mirror room is the bedroom turned half round: its bed's headboard stands as far from its wall with the door
	# in it (gap_door and mirror_door sit in them) as the bedroom's does, and on the side of the bed that faces it.
	var wall := {&"bed": ApartmentLayout.DOORS[&"gap_door"]["hinge"].z, &"bed_b1107": ApartmentLayout.DOORS[&"mirror_door"]["hinge"].z}
	var gap := {}
	for name: StringName in wall:
		var node: Node3D = main.builder.models[name]
		var z_sum := 0.0
		var count := 0
		for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for v: Vector3 in m.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var p := m.global_transform * v
				if p.y > 0.8:  # only the headboard stands this high
					z_sum += p.z
					count += 1
		check(count > 0, "%s has a headboard above 0.8 m" % name)
		var head_z := z_sum / maxf(count, 1.0)
		gap[name] = absf(head_z - wall[name])
		check(absf(head_z - wall[name]) < absf(node.global_position.z - wall[name]), "%s: the headboard is the end nearer its wall with the door" % name)
	near(gap[&"bed"], gap[&"bed_b1107"], 0.15, "the headboards' distance from their walls")
	main.queue_free()
	return true


func test_the_beds_mattress_clears_its_collider() -> bool:
	var main := await _main()
	# The collider's top (0.5 m) must lie under the sheet, or the game's visibility test (GameStage.can_see) would hide what
	# stands on the bed's far side: the lowest vertex over the mattress's interior (the rails are lower, the pillows and the
	# blanket higher) has to be at least as high.
	for name: StringName in [&"bed", &"bed_b1107"]:
		var node: Node3D = main.builder.models[name]
		var rows := ApartmentBuilder.COLLIDERS.filter(func(c: Array) -> bool: return Vector2(c[0].x, c[0].z).distance_to(Vector2(node.global_position.x, node.global_position.z)) < 0.01)
		eq(rows.size(), 1, "one collider under %s" % name)
		if rows.size() != 1:
			continue
		var top: float = rows[0][0].y + rows[0][1].y / 2.0
		var lowest := INF
		for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
			for s in m.mesh.get_surface_count():
				for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var at: Vector3 = m.global_transform * v
					var off := at - node.global_position
					if absf(off.x) < 0.78 and absf(off.z) < 0.9 and at.y > 0.36:
						lowest = minf(lowest, at.y)
		check(lowest < INF, "%s has a mattress over its interior" % name)
		check(lowest >= top, "%s: the lowest vertex over the mattress is %.4f m, under its collider's top (%.4f m)" % [name, lowest, top])
	main.queue_free()
	return true


func test_the_notice_hangs_on_the_fridge_door() -> bool:
	var main := await _main()
	# The management notice is a thin box on the fridge's door (the click box is drawn as one). Rays through its area, from the
	# front, must meet the door's flat face a few mm behind the notice's back: not inside it, not floating off it, and not a
	# magnet or a handle's recess in the way.
	var notice: Array = ApartmentBuilder.OBJECTS.filter(func(o: Array) -> bool: return o[0] == &"notice_fridge")[0]
	var back_x: float = notice[1].x - notice[2].x / 2.0
	var hits: Array[float] = []
	for m: MeshInstance3D in main.builder.models[&"fridge"].find_children("*", "MeshInstance3D", true, false):
		var triangles := m.mesh.generate_triangle_mesh()
		var inverse := m.global_transform.affine_inverse()
		for i in 5:
			for j in 5:
				var at := Vector3(back_x + 0.3, notice[1].y + (i / 4.0 - 0.5) * notice[2].y, notice[1].z + (j / 4.0 - 0.5) * notice[2].z)
				var hit := triangles.intersect_ray(inverse * at, inverse.basis * Vector3.LEFT)
				if not hit.is_empty():
					hits.append((m.global_transform * (hit["position"] as Vector3)).x)
	eq(hits.size(), 25, "rays through the notice that meet the fridge")
	if hits.size() == 25:
		var door_x: float = hits.max()
		check(door_x <= back_x + 0.0005, "the door's face (x %.4f) pokes through the notice's back (x %.4f)" % [door_x, back_x])
		check(door_x >= back_x - 0.005, "the door's face (x %.4f) is %.1f mm behind the notice's back (x %.4f): it floats" % [door_x, (back_x - door_x) * 1000.0, back_x])
		near(hits.min(), door_x, 0.0005, "the door is flat under the notice")
	main.queue_free()
	return true


func test_models_follow_their_variants() -> bool:
	var main := await _main()
	for m: Array in ApartmentBuilder.MODELS:
		var node: Node3D = main.builder.models[m[0]]
		for area: StringName in m[3]:
			for v: StringName in ApartmentLayout.VARIANT_AREAS[area]["variants"]:
				WorldState.set_variant(area, v)
				await tree.process_frame
				eq(node.visible, ApartmentLayout.requires_met(m[3], WorldState.variants), "%s with %s=%s" % [m[0], area, v])
		for area: StringName in m[3]:
			WorldState.set_variant(area, &"default")
	main.queue_free()
	return true


func test_warm_up_shows_every_model() -> bool:
	var main := await _main()
	main.builder.warm_up_models()
	for name: StringName in main.builder.models:
		check(main.builder.models[name].visible, "%s visible while warming up" % name)
	main.builder.refresh_variants()
	for m: Array in ApartmentBuilder.MODELS:
		if not m[3].is_empty():
			eq(main.builder.models[m[0]].visible, ApartmentLayout.requires_met(m[3], WorldState.variants), "%s after warming up" % m[0])
	main.queue_free()
	return true


func test_every_borrowed_file_is_credited() -> bool:
	var readme := FileAccess.get_file_as_string("res://README.md")
	for dir in DirAccess.get_directories_at("res://art"):
		var path := "res://art/%s/vendor/SOURCE.md" % dir
		if not FileAccess.file_exists(path):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.begins_with("URL: "):
				var url := line.trim_prefix("URL: ").strip_edges()
				check(readme.contains(url), "%s is not credited in README.md" % url)
	return true


func test_clock_hands_read_the_game_clock() -> bool:
	var main := await _main()
	await tree.process_frame
	var clock: Node3D = main.builder.models[&"wall_clock"]
	var hour: Node3D = clock.get_node("HourHand")
	var minute: Node3D = clock.get_node("MinuteHand")
	near(hour.rotation.z, -TAU * (11.0 + 47.0 / 60.0) / 12.0, 0.01, "hour hand at 11:47")
	near(minute.rotation.z, -TAU * 47.0 / 60.0, 0.01, "minute hand at 11:47")
	for hand: Node3D in [hour, minute]:
		check(hand.position.distance_to(Vector3(0.0, 0.0, 0.024)) < 0.001, "%s pivots on the dial centre" % hand.name)
		var box: AABB = (hand as MeshInstance3D).get_aabb()
		check(box.end.y > 0.05 and box.end.y > -2.0 * box.position.y, "%s points up from its pivot" % hand.name)
	main.queue_free()
	return true


func test_fan_turns_under_the_ceiling() -> bool:
	var main := await _main()
	var fan: Node3D = main.builder.models[&"ceiling_fan"]
	var blades := fan.get_node("Blades") as Node3D
	near(_aabb(fan).end.y, ApartmentLayout.CEILING, 0.02, "hangs from the ceiling")
	near(blades.global_position.y, ApartmentLayout.CEILING - 0.2, 0.001, "the blades turn on the downrod, 0.2 m under the canopy")
	var r := blades.rotation.y
	for i in 10:
		await tree.process_frame
	check(not is_equal_approx(blades.rotation.y, r), "turns")
	main.queue_free()
	return true


func test_the_tv_screen_lies_on_its_click_box() -> bool:
	var main := await _main()
	var tv: Array = ApartmentBuilder.OBJECTS.filter(func(o: Array) -> bool: return o[0] == &"tv")[0]
	var screen := main.builder.models[&"tv_cabinet"].get_node_or_null("TvScreen") as MeshInstance3D
	check(screen != null, "the TV model has a TvScreen mesh of its own")
	if screen == null:
		main.queue_free()
		return true
	var a: AABB = screen.global_transform * screen.get_aabb()
	var box := AABB(tv[1] - tv[2] / 2.0, tv[2])
	# The click box is no longer drawn, so the glass is what the player sees there: a few mm behind its front face, and as wide
	# and as tall as it is.
	var gap := box.end.z - a.end.z
	check(gap >= 0.0 and gap <= 0.008, "the glass is %.4f m behind the click box's front, not 0 to 8 mm" % gap)
	near(a.size.z, 0.0, 0.0005, "the glass is flat")
	for axis in 2:
		check(a.position[axis] <= box.position[axis] and a.end[axis] >= box.end[axis], "the glass covers the click box along axis %d (%.3f to %.3f, box %.3f to %.3f)" % [axis, a.position[axis], a.end[axis], box.position[axis], box.end[axis]])
	var mat := screen.get_active_material(0) as BaseMaterial3D
	check(mat.albedo_texture == null, "the glass has no texture")
	near(mat.roughness, 0.1, 0.02, "the glass is glossy")
	main.queue_free()
	return true


func test_figure_is_a_person_in_an_apron() -> bool:
	var main := await _main()
	var sil: Silhouette = main.silhouette
	sil.global_transform = Transform3D()
	var a := _aabb(sil)
	check(a.size.y >= 1.65 and a.size.y <= 1.75, "about 1.7 m tall, %.3f m (body_points check 0.1, 1.0 and 1.6 m)" % a.size.y)
	near(a.position.y, 0.0, 0.02, "it stands on the floor")
	near(a.get_center().x, 0.0, 0.05, "its origin is between its feet")
	var aprons := 0
	for m: MeshInstance3D in sil.find_children("*", "MeshInstance3D", true, false):
		eq(m.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s casts no shadow" % m.name)
		for s in m.mesh.get_surface_count():
			var own := m.mesh.surface_get_material(s)
			var name := own.resource_name if own else ""
			check(name == "body" or name == "apron", "%s surface %d is the body or the apron, not %s" % [m.name, s, name])
			var drawn := m.get_surface_override_material(s)
			check(drawn == (sil._apron if name == "apron" else sil._material), "%s surface %d (%s) is drawn with the figure's own fading material" % [m.name, s, name])
			if drawn == sil._apron:
				aprons += 1
	check(aprons >= 1, "it wears the apron")
	check(sil._apron.albedo_texture != null, "the apron keeps its stains (the model's texture)")
	for mat: BaseMaterial3D in [sil._material, sil._apron]:
		eq(mat.depth_draw_mode, BaseMaterial3D.DEPTH_DRAW_ALWAYS, "seen from behind, the apron never shows through the body")
	check(sil._apron.render_priority > sil._material.render_priority,
		"the body draws (and writes its depth) before the apron, so while it fades the apron neither ghosts through nor cuts the shirt out")
	main.queue_free()
	return true


func test_the_rack_apron_is_the_figures_apron() -> bool:
	var main := await _main()
	var hung: Node3D = main.builder.models[&"apron_hung"]
	var textures: Array[Texture2D] = []
	for m: MeshInstance3D in hung.find_children("*", "MeshInstance3D", true, false):
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as BaseMaterial3D
			eq(mat.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "the rack apron is opaque")
			textures.append(mat.albedo_texture)
	var worn: Texture2D = main.silhouette._apron.albedo_texture
	check(not textures.is_empty() and textures.all(func(t: Texture2D) -> bool: return t != null and worn != null and t.get_image().get_data() == worn.get_image().get_data()),
		"one apron: the rack's and the figure's have the same stains")
	var a := _aabb(hung)
	near(a.end.y, 1.7 + 0.0125, 0.01, "it hangs over the rack's rail, not above or through it")
	check(a.position.z > 6.0 and a.end.z < 7.6, "between the rack's posts (z %.2f to %.2f)" % [a.position.z, a.end.z])
	check(a.position.y > 0.3, "its ends hang clear of the floor")
	main.queue_free()
	return true
