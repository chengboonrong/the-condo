extends TestCase
## The Blender models: their budgets, where they stand, their variants, the shader warm-up and the clock.

# Triangles each model may have. Each object task adds its ids.
const TRIS := {&"wall_clock": 1500, &"work_shoes": 2000, &"shoe_rack": 2000, &"dining_table": 6000, &"dining_chair": 2500}
# Floor footprints: node name -> [centre x, centre z, size x, size z] of the collider it replaces.
const FOOTPRINTS := {
	&"shoe_rack": [0.25, 8.0, 0.4, 1.0],
	&"shoes_moved": [2.3, 8.5, 0.28, 0.32],
	&"dining_table": [4.5, 6.2, 1.1, 0.75],
	&"chair_turned": [3.45, 5.2, 0.42, 0.42],
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
