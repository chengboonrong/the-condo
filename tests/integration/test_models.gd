extends TestCase
## The Blender models: their budgets, where they stand, their variants, the shader warm-up and the clock.

# Triangles each model may have. Each object task adds its ids.
const TRIS := {&"wall_clock": 1500, &"work_shoes": 2000, &"shoe_rack": 2000}
# Floor footprints: node name -> [centre x, centre z, size x, size z] of the collider it replaces.
const FOOTPRINTS := {
	&"shoe_rack": [0.25, 8.0, 0.4, 1.0],
	&"shoes_moved": [2.3, 8.5, 0.28, 0.32],
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
