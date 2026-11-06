extends TestCase
## The road down the mountain, built in code: its fog, its culling, its signs, its colliders, its grade and its lights.


func _builder() -> RoadBuilder:
	var road := RoadBuilder.new()
	tree.root.add_child(road)
	return road


## Metres from the centreline, on the map, of a point beside the road.
func _off_centre(pos: Vector3) -> float:
	var c := RoadLayout.point(RoadLayout.closest_s(pos))
	return Vector2(pos.x - c.x, pos.z - c.z).length()


func test_the_road_builds_with_its_fog() -> bool:
	var road := _builder()
	check(road.environment != null and road.environment.fog_enabled, "the road has fog")
	road.set_fog(0.0)
	near(road.environment.fog_density, 0.035, 0.0001, "no rule broken: the clearest fog")
	road.set_fog(1.0)
	near(road.environment.fog_density, 0.11, 0.0001, "every rule broken: the thickest")
	road.set_fog(0.5)
	check(road.environment.fog_density > 0.035 and road.environment.fog_density < 0.11, "in between, in between")
	check(not road.materials().is_empty(), "it lists the materials it made, for the warm-up")
	road.queue_free()
	return true


func test_far_scenery_is_culled() -> bool:
	var road := _builder()
	var multimeshes := road.find_children("*", "MultiMeshInstance3D", true, false)
	check(multimeshes.size() > 20, "the trees come in chunks (%d)" % multimeshes.size())
	check(road.signs.size() > 10, "and so do the signs (%d)" % road.signs.size())
	var far: Array[String] = []
	for g: GeometryInstance3D in multimeshes + road.signs:
		if g.visibility_range_end <= 0.0 or g.visibility_range_end > 160.0:
			far.append("%s: %.0f" % [g.name, g.visibility_range_end])
	eq(far, [] as Array[String], "drawn at any distance")
	road.queue_free()
	return true


func test_signs_say_only_checked_text() -> bool:
	var road := _builder()
	var labels := road.find_children("*", "Label3D", true, false)
	check(labels.size() >= 10, "the road has its signs (%d lines)" % labels.size())
	for l: Label3D in labels:
		check(RoadBuilder.SIGN_TEXTS.has(l.text), "an unchecked sign text: %s" % l.text)
		check(road.signs.has(l), "a label that is not on a sign: %s" % l.text)
	for dropped: String in ["SELEKOH TAJAM", "GUNAKAN GEAR RENDAH", "DILARANG MEMOTONG"]:
		check(not RoadBuilder.SIGN_TEXTS.has(dropped), "%s could not be confirmed" % dropped)
	road.queue_free()
	return true


## Ten players at once, one every 322 m from the bus stop down, each walking sideways for 6 s one way, then 6 s the
## other. The players don't collide with each other (layer 2, mask 1).
func test_the_player_cannot_leave_the_road() -> bool:
	var road := _builder()
	var players: Array[PlayerController] = []
	for i in 10:
		var s := 2900.0 * i / 9.0
		var p: PlayerController = load("res://scenes/player/player.tscn").instantiate()
		tree.root.add_child(p)
		p.global_position = RoadLayout.point(s) + Vector3.UP * 0.05
		p.set_look(RoadBuilder.yaw_along(s))
		p.use_scripted_move = true
		players.append(p)
	for side: float in [-1.0, 1.0]:  # to his left, then to his right
		for p in players:
			p.scripted_move = Vector2(side, 0.0)
		for f in 360:
			await tree.physics_frame
		for p in players:
			var at := p.global_position
			var s := RoadLayout.closest_s(at)
			var off := _off_centre(at)
			check(off <= RoadLayout.WIDTH / 2.0 + 2.5, "s %.0f, %s: %.2f m off the centreline" % [s, "left" if side < 0.0 else "right", off])
			check(off >= 3.0, "s %.0f: he did walk sideways (%.2f m)" % [s, off])
			check(absf(at.y - RoadLayout.point(s).y) < 0.3, "s %.0f: on the road, not through it (%.2f)" % [s, at.y - RoadLayout.point(s).y])
	for p in players:
		p.queue_free()
	road.queue_free()
	return true


func test_the_road_has_its_own_grade() -> bool:
	var was := Journey.change_scenes
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	eq(road.look.grade_override, &"road", "the road's grade")
	var env := road.builder.environment
	var grade: Dictionary = Look.GRADES[&"road"]
	near(env.adjustment_saturation, grade["saturation"], 0.001, "its saturation")
	near(env.adjustment_contrast, grade["contrast"], 0.001, "its contrast")
	var ramp: Gradient = (env.adjustment_color_correction as GradientTexture1D).gradient
	eq(ramp.get_color(0), grade["black"], "its black")
	eq(ramp.get_color(1), grade["white"], "its white")
	near(grade["saturation"], 0.5, 0.001, "starting value: saturation")
	near(grade["contrast"], 1.06, 0.001, "starting value: contrast")
	road.queue_free()
	Journey.change_scenes = was
	return true


func test_the_road_scene_puts_him_at_the_exit_in_its_fog() -> bool:
	var was := Journey.change_scenes
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	await tree.process_frame
	check(road.player.global_position.distance_to(RoadLayout.EXIT) < 0.3, "he starts at the staff exit")
	var facing := -road.player.global_basis.z
	var down := RoadLayout.tangent(RoadLayout.closest_s(RoadLayout.EXIT))
	check(Vector2(facing.x, facing.z).normalized().dot(Vector2(down.x, down.z).normalized()) > 0.99, "facing down the road")
	road.director.fog = 1.0
	await tree.process_frame
	near(road.builder.environment.fog_density, 0.11, 0.0001, "the fog follows the core's every frame")
	road.queue_free()
	Journey.change_scenes = was
	return true


func test_road_lights_fit_the_per_object_limit() -> bool:
	var road := _builder()
	var limit: int = ProjectSettings.get_setting("rendering/limits/opengl/max_lights_per_object")
	var lights: Array = road.find_children("*", "OmniLight3D", true, false)
	check(lights.size() >= 6, "the lamps and the tunnel are lit (%d lights)" % lights.size())
	var over: Array[String] = []
	for g: GeometryInstance3D in road.find_children("*", "GeometryInstance3D", true, false):
		var box: AABB = g.global_transform * g.get_aabb()
		var n := lights.filter(func(l: OmniLight3D) -> bool: return box.intersects(AABB(l.global_position - Vector3.ONE * l.omni_range, Vector3.ONE * l.omni_range * 2.0))).size()
		if n > limit:
			over.append("%s: %d" % [g.name, n])
	eq(over, [] as Array[String], "meshes reached by more than %d lights" % limit)
	road.queue_free()
	return true
