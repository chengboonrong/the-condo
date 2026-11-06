extends TestCase
## The penanggal: where she shows, how long, how she catches someone and comes for the camera, that she never passes
## through the car, and that her warm-up draws everything she is drawn with.


func _her() -> Penanggal:
	var her := Penanggal.new()
	tree.root.add_child(her)
	return her


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Metres to the left of the road's centreline.
static func _across(pos: Vector3) -> float:
	var s := RoadLayout.closest_s(pos)
	var t := RoadLayout.tangent(s)
	return (pos - RoadLayout.point(s)).dot(Vector3(t.z, 0.0, -t.x).normalized())


## Switchback 1 (s 631 to 726) turns the road round, so along the road is not a straight line.
func test_behind_keeps_her_distance() -> bool:
	var her := _her()
	var walker := Node3D.new()
	tree.root.add_child(walker)
	for her_near: float in [0.0, 1.0]:
		var distance := lerpf(18.0, 4.0, her_near)
		walker.global_position = RoadLayout.point(700.0, 1.0)
		her.hide_her()
		her.behind(walker, distance)
		await _frames(2)
		near(RoadLayout.closest_s(her.global_position), 700.0 - distance, 0.5, "her_near %.0f: %.0f m behind him along the road" % [her_near, distance])
		check(her.global_position.y - RoadLayout.point(700.0 - distance).y > 2.3, "her_near %.0f: high enough that nothing of hers reaches the road" % her_near)
		for i in 120:  # he walks on 6 m
			walker.global_position = RoadLayout.point(700.0 + 6.0 * (i + 1) / 120.0, 1.0)
			await tree.process_frame
		await _frames(30)
		near(RoadLayout.closest_s(her.global_position), 706.0 - distance, 0.5, "her_near %.0f: and she keeps it as he walks" % her_near)
		near(_across(her.global_position), 1.0, 0.3, "her_near %.0f: on his line" % her_near)
	her.hide_her()
	check(not her.visible, "hide_her hides her")
	return true


func test_glimpse_is_brief_and_off_the_road() -> bool:
	var her := _her()
	her.director = RoadDirector.new(RoadStage.new(), 1147)
	her.director.car_s = 500.0
	her.director.her_near = 0.12  # after one overtake
	var lines := []
	var on_line := func(text: String, _seconds: float) -> void: lines.append(text)
	EventBus.line_requested.connect(on_line)
	for glimpse in 2:
		her.show_glimpse()
		var ahead := RoadLayout.closest_s(her.global_position) - 500.0
		check(ahead >= 25.0 and ahead <= 35.0, "glimpse %d: 25-35 m ahead of the car (%.1f)" % [glimpse, ahead])
		var shown := 0
		var on_road := 0
		for i in 180:
			if her.visible:
				shown += 1
				if absf(_across(her.global_position)) <= RoadLayout.WIDTH / 2.0:
					on_road += 1
			await tree.process_frame
		check(shown > 60 and shown <= 78, "glimpse %d: seen for over 1 s and at most 1.3 s (%.2f s)" % [glimpse, shown / 60.0])
		eq(on_road, 0, "glimpse %d: frames over the road" % glimpse)
	EventBus.line_requested.disconnect(on_line)
	eq(lines, [Penanggal.SMELL], "the smell, after her first glimpse only")
	return true


func test_catch_ends_on_the_ground() -> bool:
	var her := _her()
	var victim := Node3D.new()
	tree.root.add_child(victim)
	victim.global_transform = CarRig.on_road(800.0, 1.0)  # standing on the road, facing down it
	her.behind(victim, 6.0)
	await _frames(2)
	var feet := victim.global_position
	var sounds: Array[StringName] = []
	var on_sound := func(id: StringName, _pos: Vector3, _db: float) -> void: sounds.append(id)
	EventBus.sound_requested.connect(on_sound)
	her.catch(victim)
	await _frames(120)
	EventBus.sound_requested.disconnect(on_sound)
	var up := victim.global_basis.y.normalized()
	check(absf(up.dot(Vector3.UP)) < sin(deg_to_rad(15.0)), "2 s on, he lies on the ground (up %s)" % up)
	near(victim.global_position.distance_to(feet), 0.0, 0.01, "fallen where he stood")
	check(her.pool.is_visible_in_tree(), "a pool")
	check(her.pool.global_position.distance_to(feet + up * Penanggal.SHOULDERS) < 0.4, "under his shoulders")
	check(her.global_position.y - her.pool.global_position.y > 0.9, "she stays over him, off the ground")
	check(not sounds.is_empty(), "she is heard")
	for id: StringName in sounds:
		check(RoadAudio.SOUNDS.has(id) and id != &"stinger", "%s: one of the road's sounds, and no sting" % id)
	return true


func test_come_for_stops_short_of_the_camera() -> bool:
	var her := _her()
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.global_position = RoadLayout.point(900.0) + Vector3.UP * 1.6
	her.global_position = camera.global_position + Vector3(0.0, 0.0, 10.0)
	her.visible = true
	var reached := [0]
	her.reached.connect(func() -> void: reached[0] += 1)
	her.come_for(camera)
	await _frames(60)
	near(her.global_position.distance_to(camera.global_position), 4.0, 0.15, "6 m/s at the camera")
	await _frames(120)
	near(her.global_position.distance_to(camera.global_position), Penanggal.CLOSE, 0.05, "and stops 0.6 m away")
	eq(reached[0], 1, "reached, once")
	var face := her.global_basis.z.slide(Vector3.UP).normalized()
	near(face.dot((camera.global_position - her.global_position).slide(Vector3.UP).normalized()), 1.0, 0.02, "her face to it")
	return true


## Seen from the back seat her insides hang past his window, but nothing of hers is inside the car's body.
func test_on_the_roof_nothing_passes_through_the_car() -> bool:
	var car := CarRig.new()
	tree.root.add_child(car)
	car.place(1800.0, RoadLayout.LANE)
	var her := _her()
	her.on_roof(car)
	await _frames(3)
	var body: MeshInstance3D = car.find_child("hatchback", true, false)
	var to_car := body.global_transform.affine_inverse()
	var hers := PackedVector3Array()
	for m: MeshInstance3D in her.find_children("*", "MeshInstance3D", true, false):
		if m != her.pool:
			for s in m.mesh.get_surface_count():
				for v: Vector3 in m.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					hers.append(to_car * (m.global_transform * v))
	var zs := Vector2(INF, -INF)
	for p in hers:
		zs = Vector2(minf(zs.x, p.z), maxf(zs.y, p.z))
	var widths := {}  # the body's half-width in every 5 cm of height, along the stretch of car she is beside
	for s in body.mesh.get_surface_count():
		for v: Vector3 in body.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if v.z > zs.x - 0.05 and v.z < zs.y + 0.05:
				var band := floori(v.y / 0.05)
				widths[band] = maxf(widths.get(band, 0.0), absf(v.x))
	var inside := 0
	var at_window := 0
	for p in hers:
		var band := floori(p.y / 0.05)
		if widths.has(band) and absf(p.x) < widths[band] + 0.03:
			inside += 1
		if p.y > 1.0 and p.y < 1.4 and p.z > -0.95 and p.z < -0.15 and p.x > 0.0 and p.x < 1.3:
			at_window += 1
	eq(inside, 0, "her vertices inside the car's body, or within 3 cm of it")
	check(at_window > 100, "her insides hang past his window (%d vertices)" % at_window)
	check((to_car * her.global_position).y > 1.5, "her head over the roof's height")
	return true


func test_her_warm_up_shows_every_material() -> bool:
	var her := _her()
	var mats := her.materials()
	check(mats.size() == 5, "her four surfaces and the pool (%d)" % mats.size())
	var sway := 0
	for m in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader.code.contains("uniform vec3 motion"):
			sway += 1
	eq(sway, 4, "her four surfaces sway")
	her.warm_up(Vector3(0.0, 50.0, 0.0))
	for m in mats:
		var drawn := false
		for mesh: MeshInstance3D in her.find_children("*", "MeshInstance3D", true, false):
			if mesh.is_visible_in_tree():
				for s in mesh.mesh.get_surface_count():
					drawn = drawn or mesh.get_active_material(s) == m
		check(drawn, "%s is on a visible mesh" % m.resource_name)
	await _frames(3)
	check(not her.visible, "and she is hidden again")
	return true
