extends TestCase
## The penanggal: where she shows, how long, how she catches someone and comes for the camera, that she never passes
## through the car, and that her warm-up draws everything she is drawn with.


func _her() -> Penanggal:
	var her := Penanggal.new()
	her.director = RoadDirector.new(RoadStage.new(), 1147)
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
		var distance := 18.0 if her_near == 0.0 else 4.0
		her.director.her_near = her_near
		walker.global_position = RoadLayout.point(700.0, 1.0)
		her.hide_her()
		her.behind(walker)
		await _frames(2)
		near(RoadLayout.closest_s(her.global_position), 700.0 - distance, 0.5, "her_near %.0f: %.0f m behind him along the road" % [her_near, distance])
		check(her.global_position.y - RoadLayout.point(700.0 - distance).y > 2.3, "her_near %.0f: high enough that nothing of hers reaches the road" % her_near)
		for i in 120:  # he walks on 6 m
			walker.global_position = RoadLayout.point(700.0 + 6.0 * (i + 1) / 120.0, 1.0)
			await tree.process_frame
		await _frames(30)
		near(RoadLayout.closest_s(her.global_position), 706.0 - distance, 0.5, "her_near %.0f: and she keeps it as he walks" % her_near)
		near(_across(her.global_position), 1.0, 0.3, "her_near %.0f: on his line" % her_near)
		eq(her.materials()[0].get_shader_parameter(&"fog_share"), 1.0, "her_near %.0f: in all of the road's fog" % her_near)
	her.director.her_near = 0.0
	her.hide_her()
	her.behind(walker)  # 18 m back
	await _frames(2)
	her.director.her_near = 0.5  # he breaks a rule on the way
	await _frames(90)  # 7 m at 6 m/s, and some
	near(RoadLayout.closest_s(her.global_position), 706.0 - 11.0, 0.5, "it brings her gliding in, to 11 m")
	her.hide_her()
	check(not her.visible, "hide_her hides her")
	return true


## Mission 2 shows her as the car, back in its lane after the overtake at 14 m/s, slows to its cruise: at s 523 the
## valley is on the left, at s 740 the hill. One overtake brings her to 22.6 m, a second to 17.2, a third to 11.8.
func test_glimpse_is_brief_and_off_the_road() -> bool:
	near(Penanggal.glimpse_distance(0.0), 28.0, 0.001, "28 m ahead with no rule broken")
	near(Penanggal.glimpse_distance(0.12), 22.6, 0.001, "22.6 m after one overtake")
	near(Penanggal.glimpse_distance(0.4), 10.0, 0.001, "10 m at her nearest")
	near(Penanggal.glimpse_distance(1.0), 10.0, 0.001, "and no nearer")
	var builder := RoadBuilder.new()
	tree.root.add_child(builder)
	var car := CarRig.new()
	tree.root.add_child(car)
	var her := _her()
	her.builder = builder
	her.director.car_speed = 14.0
	var lines := []
	var on_line := func(text: String, _seconds: float) -> void: lines.append(text)
	EventBus.line_requested.connect(on_line)
	var linear := RoadBuilder.FOG_COLOR.srgb_to_linear()
	var fog_color := Vector3(linear.r, linear.g, linear.b)
	for car_s: float in [523.0, 740.0]:
		for her_near: float in [0.12, 0.24, 0.36]:
			var what := "at %.0f, her_near %.2f" % [car_s, her_near]
			her.director.her_near = her_near
			her.director.car_s = car_s
			her.director.car_speed = 14.0
			car.place(car_s, her.director.lane)
			her.show_glimpse()
			var ahead := RoadLayout.closest_s(her.global_position) - car_s
			var valley := builder.ground_at(car_s + ahead, 7.0) < 0.0
			check(ahead > Penanggal.glimpse_distance(her_near) - 0.5 and ahead < Penanggal.glimpse_distance(her_near) + 3.0,
				"%s: glimpse_distance ahead, or as near past it as he can see her from (%.1f m)" % [what, ahead])
			var shown := 0
			var in_view := 0
			var off := INF  # her nearest to the road's middle, while seen
			var left := true
			var lit := 0
			var last := NAN  # her bearing from his seat as she goes (+ left)
			var ground := INF
			var fog := true  # her four surfaces take GLIMPSE_FOG of the road's own fog
			for i in 120:
				if her.visible:
					shown += 1
					var pos := her.global_position
					var across := _across(pos)
					off = minf(off, absf(across))
					left = left and across > 0.0
					for spot: SpotLight3D in car.headlights:
						var to := pos - spot.global_position
						if to.length() < spot.spot_range and rad_to_deg(to.angle_to(-spot.global_basis.z)) < spot.spot_angle:
							lit += 1
							break
					var seat := car.global_transform.affine_inverse() * pos - Penanggal.SEAT
					last = rad_to_deg(atan2(seat.x, seat.z))
					if Penanggal.CLEAR.any(func(band: Vector2) -> bool: return last >= band.x and last <= band.y):
						in_view += 1
					if i == 20:  # set by her own frame before this one
						var here := RoadLayout.closest_s(pos)
						var floor_y: float = her.materials()[0].get_shader_parameter(&"floor_y")
						ground = pos.y + floor_y - 0.02 - (RoadLayout.point(here).y + builder.ground_at(here, across))
						for m: ShaderMaterial in her.materials().slice(0, 4):  # her four surfaces: less of the road's fog
							fog = fog and m.get_shader_parameter(&"fog_share") == Penanggal.GLIMPSE_FOG \
								and m.get_shader_parameter(&"fog_density") == builder.environment.fog_density \
								and m.get_shader_parameter(&"fog_color") == fog_color
				await tree.process_frame
				her.director.car_s += her.director.car_speed / 60.0  # the car comes on, slowing as Mission 2's does
				her.director.car_speed -= RoadDirector.ACCEL / 60.0
				car.place(her.director.car_s, her.director.lane)
			check(shown > 0 and shown <= 78, "%s: seen, for at most 1.3 s (%.2f s)" % [what, shown / 60.0])
			check(left, "%s: on the left verge, his side" % what)
			check(off >= (Penanggal.VALLEY_OUT.x if valley else Penanggal.HILL_OUT.x) - 0.1,
				"%s: never on the road, past the rail where the valley is (%.2f m out at the nearest)" % [what, off])
			check(lit > 0, "%s: her head in a headlight's beam for part of it (%d frames)" % [what, lit])
			check(Penanggal.CLEAR.any(func(band: Vector2) -> bool: return last >= band.x and last <= band.y),
				"%s: gone where he sees her, not behind a pillar or a head (%.1f degrees)" % [what, last])
			if her_near >= 0.24:
				check(in_view >= 36, "%s: in view for 0.6 s or more (%.2f s)" % [what, in_view / 60.0])
			near(ground, 0.0, 0.01, "%s: what hangs from her lies on the real ground there, not the road's plane" % what)
			check(fog, "%s: she shows through the road's fog, taking GLIMPSE_FOG of it" % what)
	EventBus.line_requested.disconnect(on_line)
	eq(lines, [Penanggal.SMELL], "the smell, after her first glimpse only")
	return true


func test_catch_ends_on_the_ground() -> bool:
	var her := _her()
	var victim := Node3D.new()
	tree.root.add_child(victim)
	victim.global_transform = CarRig.on_road(800.0, 1.0)  # standing on the road, facing down it
	her.behind(victim)  # 18 m behind him
	await _frames(2)
	var feet := victim.global_position
	var sounds: Array[StringName] = []
	var on_sound := func(id: StringName, _pos: Vector3, _db: float) -> void: sounds.append(id)
	EventBus.sound_requested.connect(on_sound)
	her.catch(victim)
	var fastest := 0.0
	var was := her.global_position
	for i in 240:
		await tree.process_frame
		fastest = maxf(fastest, her.global_position.distance_to(was) * 60.0)
		was = her.global_position
	EventBus.sound_requested.disconnect(on_sound)
	check(fastest <= 2.0 * Penanggal.SWOOP + 0.5, "from 18 m off she comes at him no faster than a swoop (%.1f m/s)" % fastest)
	var up := victim.global_basis.y.normalized()
	check(absf(up.dot(Vector3.UP)) < sin(deg_to_rad(15.0)), "4 s on, he lies on the ground (up %s)" % up)
	near(victim.global_position.distance_to(feet), 0.0, 0.01, "fallen where he stood")
	check(her.pool.is_visible_in_tree(), "a pool")
	check(her.pool.global_position.distance_to(feet + up * Penanggal.SHOULDERS) < 0.4, "under his shoulders")
	check(her.global_position.y - her.pool.global_position.y > 0.9, "she stays over him, off the ground")
	check(not sounds.is_empty(), "she is heard")
	for id: StringName in sounds:
		check(RoadAudio.SOUNDS.has(id) and id != &"stinger", "%s: one of the road's sounds, and no sting" % id)
	var camera := Camera3D.new()
	tree.root.add_child(camera)
	camera.global_position = RoadLayout.point(780.0) + Vector3.UP * 1.6
	her.come_for(camera)
	await _frames(30)
	check(her.pool.is_visible_in_tree(), "the pool stays where it spread as she comes on")
	return true


## Task 10 waits on `caught` to go on: from 18 m behind him the drop takes over 2 s, so no timer would do.
func test_catch_says_when_he_is_down() -> bool:
	var her := _her()
	var victim := Node3D.new()
	tree.root.add_child(victim)
	victim.global_transform = CarRig.on_road(800.0, 1.0)
	her.behind(victim)  # 18 m behind him
	await _frames(2)
	var heard := []  # per caught: who, his up axis then, and whether the pool showed
	her.caught.connect(func(who: Node3D) -> void: heard.append([who, victim.global_basis.y.normalized(), her.pool.is_visible_in_tree()]))
	her.catch(victim)
	await _frames(300)
	eq(heard.size(), 1, "caught, once")
	if heard.size() == 1:
		check(heard[0][0] == victim, "with him")
		check(absf((heard[0][1] as Vector3).dot(Vector3.UP)) < sin(deg_to_rad(15.0)), "as he lies on the ground (up %s)" % heard[0][1])
		check(heard[0][2], "and the pool begins")
	her.catch(victim)  # again, from over him
	await _frames(120)
	eq(heard.size(), 2, "and once more for a second catch")
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
	await _frames(15)
	var low := INF  # her lowest above the road while still LOW_IN and more from stopping
	for i in 45:
		low = minf(low, her.global_position.y - RoadLayout.point(RoadLayout.closest_s(her.global_position)).y)
		await tree.process_frame
	check(low > Penanggal.ABOVE_ROAD - 0.1, "she comes in high enough that nothing of hers lies on the road (%.2f m)" % low)
	near(her.global_position.distance_to(camera.global_position), 4.1, 0.15, "6 m/s at the camera")
	await _frames(120)
	near(her.global_position.distance_to(camera.global_position), Penanggal.CLOSE, 0.05, "and stops 0.6 m away")
	eq(reached[0], 1, "reached, once")
	var face := her.global_basis.z.slide(Vector3.UP).normalized()
	near(face.dot((camera.global_position - her.global_position).slide(Vector3.UP).normalized()), 1.0, 0.02, "her face to it")
	her.hide_her()
	camera.rotation.x = deg_to_rad(-60.0)  # looking down at the road
	her.come_for(camera)
	var out := her.global_position - camera.global_position
	near(out.y, 0.0, 0.01, "from hiding she comes out of the fog level with it, not from under the road")
	near(out.slide(Vector3.UP).length(), 15.0, 0.01, "15 m off")
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
