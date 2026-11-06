extends TestCase
## The road's shader warm-up behind the start card: every material the road can draw has been drawn once by the time
## the card can be clicked, whether it is shown yet or not, her in the mirror and the signs' lines included.


func test_every_road_material_is_warmed() -> bool:
	var was := Journey.change_scenes
	Journey.change_scenes = false
	var road: Node = load(Journey.ROAD_SCENE).instantiate()  # untyped: warmed_materials() is checked at run time
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	check(road.loaded, "the start card can be clicked")
	var warmed: Dictionary = road.warmed_materials()
	var walked := road.find_children("*", "GeometryInstance3D", true, false)  # hidden or not
	check(walked.any(func(g: Node) -> bool: return g is Label3D), "the walk takes in the signs' lines")
	check(walked.any(func(g: Node) -> bool: return road.her.is_ancestor_of(g)) and not road.her.visible, "and her, hidden")
	check(walked.any(func(g: Node) -> bool: return road.car.mirror.fourth.is_ancestor_of(g)), "and the fourth, only ever seen in the mirror")
	var missing: Array[String] = []
	for g: GeometryInstance3D in walked:
		for m: RID in _materials(g):
			if not warmed.has(m):
				missing.append(String(road.get_path_to(g)))
	eq(missing, [], "every material under the road is drawn in the warm-up")
	road.queue_free()
	Journey.change_scenes = was
	return true


## The renderer's material for each surface `g` draws: a mesh's whatever overrides it, a multimesh's, and the one a
## sign's line (Label3D) makes for itself; and the overlay.
static func _materials(g: GeometryInstance3D) -> Array[RID]:
	var out: Array[RID] = []
	if g is MeshInstance3D:
		var m := g as MeshInstance3D
		for i in m.get_surface_override_material_count():
			if m.get_active_material(i) != null:
				out.append(m.get_active_material(i).get_rid())
	elif g is MultiMeshInstance3D:
		var mesh := (g as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			var mat := g.material_override if g.material_override != null else mesh.surface_get_material(i)
			if mat != null:
				out.append(mat.get_rid())
	elif g is Label3D:
		for i in RenderingServer.mesh_get_surface_count(g.get_base()):
			out.append(RenderingServer.mesh_surface_get_material(g.get_base(), i))
	else:
		out.append(RID())  # a kind of geometry this walk does not know: never warmed, so it shows as missing
	if g.material_overlay != null:
		out.append(g.material_overlay.get_rid())
	return out
