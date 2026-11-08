extends TestCase
## The car dying, in the scene: its lights fail (smoothly with reduced flashing), its engine stops, Hafiz gets out and
## walks off with his phone as a torch, something thumps on the roof and hangs there, and a light shows far down the
## road.

var _was_changing := true
var _sounds: Array[StringName] = []  # every sound asked for while the road plays the car dying
var _last: Array = []  # the last sound asked for: [id, where, volume_db]


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## Every frame's energy of the car's first headlight while its lights die, and a little after.
func _dying(car: CarRig) -> PackedFloat32Array:
	var out := PackedFloat32Array([car.headlights[0].light_energy])
	car.lights_dying()
	for i in roundi((CarRig.DYING + 0.5) * 60.0):
		await tree.process_frame
		out.append(car.headlights[0].light_energy)
	return out


func test_dying_lights_respect_reduced_flashing() -> bool:
	var was: bool = Settings.get_value("reduced_flashing")
	for reduced: bool in [true, false]:
		Settings.set_value("reduced_flashing", reduced)
		var car := CarRig.new()
		tree.root.add_child(car)
		await tree.process_frame
		var energy: PackedFloat32Array = await _dying(car)
		var full := energy[0]
		var worst := 0.0  # the largest change in one frame, as a share of the lamp's full energy
		var rises := 0
		for i in range(1, energy.size()):
			worst = maxf(worst, absf(energy[i] - energy[i - 1]) / full)
			if energy[i] > energy[i - 1] + 0.0001:
				rises += 1
		var what := "reduced flashing %s" % ("on" if reduced else "off")
		check(full > 1.0, "%s: lit to begin with (%.2f)" % [what, full])
		near(energy[-1], 0.0, 0.0001, "%s: dead in the end" % what)
		check(car.headlights.all(func(spot: SpotLight3D) -> bool: return not spot.visible), "%s: both lamps out" % what)
		if reduced:
			check(worst <= 0.05, "%s: it changes by at most 5%% a frame (%.1f%%)" % [what, worst * 100.0])
			eq(rises, 0, "%s: and only falls" % what)
		else:
			check(rises > 0, "%s: it may flicker, and does (%d rises)" % [what, rises])
			var jumps: Array[int] = []  # frames where it browns out or comes back
			for i in range(1, energy.size()):
				if absf(energy[i] - energy[i - 1]) / full > 0.05:
					jumps.append(i)
			var closest := INF
			for j in range(1, jumps.size()):
				closest = minf(closest, (jumps[j] - jumps[j - 1]) / 60.0)
			check(jumps.size() >= 2 and closest >= CarRig.BROWN_OUT - 0.02,
				"%s: under 3 flashes a second (%d changes, %.2f s apart at the least)" % [what, jumps.size(), closest])
		car.queue_free()
	Settings.set_value("reduced_flashing", was)
	return true


func test_the_car_has_a_lock_within_reach() -> bool:
	var car := CarRig.new()
	tree.root.add_child(car)
	await tree.process_frame
	check(car.lock != null, "the car has a lock")
	eq(car.lock.object_id, &"car_lock", "its id")
	eq(car.lock.prompt, "", "usable only while a mission prompts it")
	var lock := _box(car, car.lock)
	var door := _box(car, car.door_rear_left)
	var at := lock.get_center()
	check(at.distance_to(Penanggal.SEAT) <= 1.0, "within a metre of his eyes (%.2f m)" % at.distance_to(Penanggal.SEAT))
	check(not lock.intersects(door), "its collider is clear of his door's")
	check(door.intersects_segment(Penanggal.SEAT, at) == null, "and a look from his eyes to it never crosses the door")  # null: no hit
	for seat in _front_seats(car):
		check(seat.intersects_segment(Penanggal.SEAT, at) == null, "nor a front seat (%s): he sees it over them" % seat)
	var angle := rad_to_deg(Vector3.BACK.angle_to(at - Penanggal.SEAT))  # BACK is +Z, the way the car faces
	check(angle <= 45.0, "within 45 degrees of straight ahead, so he finds it looking forward (%.0f)" % angle)
	near(lock.size.x, 0.12, 0.001, "its collider is about 12 cm, a target he can hit")
	var meshes := car.lock.find_children("*", "MeshInstance3D", false, false)
	check(not meshes.is_empty() and meshes.all(func(m: MeshInstance3D) -> bool: return m.visible), "and it has a mesh he can see")
	car.queue_free()
	return true


## Each front seat's box in the car's space: its cloth in the model, forward of the rear bench.
func _front_seats(car: CarRig) -> Array[AABB]:
	var body: MeshInstance3D = car.find_children("hatchback", "MeshInstance3D", true, false)[0]
	var seats: Array[AABB] = []
	for side in [1.0, -1.0]:
		var box := AABB()
		var found := false
		for s in body.mesh.get_surface_count():
			if body.mesh.surface_get_material(s).resource_name != "cloth":
				continue
			for p: Vector3 in body.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if p.z > -0.6 and p.x * side > 0.0:
					box = box.expand(p) if found else AABB(p, Vector3.ZERO)
					found = true
		seats.append(box)
	return seats


## The box collider of a body, in the car's space.
func _box(car: CarRig, body: Node3D) -> AABB:
	var collider: CollisionShape3D = body.find_children("*", "CollisionShape3D", false, false)[0]
	var size := (collider.shape as BoxShape3D).size
	return AABB(car.to_local(collider.global_position) - size / 2.0, size)


func test_the_road_plays_the_car_dying() -> bool:
	_was_changing = Journey.change_scenes
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	road.hud.start()
	road.set_physics_process(false)  # the core stands still: the cues come from here
	road.director.start_at(road.director.missions.find_custom(func(m: RoadMission) -> bool: return m is StallMission))
	road.director.car_speed = 0.0
	_sounds.clear()
	EventBus.sound_requested.connect(_on_sound)
	await _frames(2)
	var p := road.player
	check(p.is_seated() and road.audio.loops[&"engine_loop"].playing, "(seated, with the engine running)")
	EventBus.road_cue.emit(&"lights_dying")
	await _frames(2)
	check(not road.audio.loops[&"engine_loop"].playing, "the engine stops when the car dies")
	check(road.audio.here[&"engine_sputter"].playing, "with a sputter, in his head so it rides with the car")
	EventBus.road_cue.emit(&"crank")
	EventBus.road_cue.emit(&"hafiz_leaves")
	await _frames(60)
	var hafiz := road.couple.hafiz_out
	check(not road.couple.hafiz.visible and hafiz.visible, "Hafiz is out of his seat and on his feet")
	check(road.car.door_driver.rotation.y > 0.5, "his door is open")
	near(hafiz.global_position.distance_to(road.car.global_transform * Couple.OUT), 0.0, 0.3, "and he stands beside it")
	await _frames(240)
	near(road.car.door_driver.rotation.y, 0.0, 0.001, "he shuts it behind him")
	var ahead := (hafiz.global_position - road.car.global_position).dot(road.car.global_basis.z)
	check(ahead > 2.0, "and walks off ahead of the car (%.1f m)" % ahead)
	var torch: SpotLight3D = hafiz.find_children("*", "SpotLight3D", true, false)[0]
	check(torch.visible and not torch.shadow_enabled, "with his phone as a torch, unshadowed")
	EventBus.road_cue.emit(&"insects_stop")
	await _frames(2)
	check(not road.audio.loops[&"insects_loop"].playing, "the insects stop")
	EventBus.road_cue.emit(&"thump")
	EventBus.road_cue.emit(&"her_on_roof")
	var shake := 0.0
	for i in 40:
		await tree.process_frame
		shake = maxf(shake, p.camera.position.length())
	check(shake > 0.002 and shake < 0.02, "a thump shakes his view, by less than 2 cm (%.4f m)" % shake)
	eq(p.camera.position, Vector3.ZERO, "and it settles")
	check(_playing(road, &"thump_roof"), "the roof thumps")
	var on := road.car.global_transform.affine_inverse() * road.her.global_position
	check(road.her.visible and on.y > 1.4 and on.x > 0.8, "she is up by the roof on his side (%s)" % on)
	EventBus.road_cue.emit(&"doors_locked")
	eq([_last[0], _last[2]], [&"car_door_close", -14.0], "locking the doors clunks, quietly")
	near((_last[1] as Vector3).distance_to(road.car.lock.global_position), 0.0, 0.001, "at the lock")
	EventBus.road_cue.emit(&"door_cracked")
	var opened := 0.0
	for i in 60:
		await tree.process_frame
		opened = minf(opened, road.car.door_rear_left.rotation.y)
	check(opened < -0.1 and opened > -0.2, "his door opens a hand's width (%.2f rad)" % opened)
	near(road.car.door_rear_left.rotation.y, 0.0, 0.001, "and is slapped shut")
	var mei := road.couple.mei
	EventBus.road_cue.emit(&"mei_reaches_door")
	EventBus.road_line.emit(&"mei", 3.0)
	await _frames(40)
	var face := _facing(road, mei)
	check(face.x > 0.7 and face.z > -0.2, "Mei says she is opening it to her own door, not round to him (%s)" % face)
	EventBus.road_cue.emit(&"mei_door_cracked")
	EventBus.road_cue.emit(&"knock_window")
	await _frames(240)  # her line ends, and she faces the road again
	EventBus.road_cue.emit(&"light_on")
	EventBus.road_line.emit(&"mei", 3.5)
	await _frames(40)
	check(road.builder.far_light.visible, "a light shows far down the road")
	check(not road.her.visible, "and she has gone")
	face = _facing(road, mei)
	var lean := (mei.get_node("Chest") as Node3D).rotation.x
	check(face.z > 0.9 and lean > 0.15, "Mei leans in to the windscreen to see it, not round to him (%s, %.2f rad)" % [face, lean])
	EventBus.sound_requested.disconnect(_on_sound)
	for id: StringName in [&"starter_crank", &"car_door_open", &"car_door_close", &"wet_flap",
			&"thump_roof", &"knock_glass"]:
		check(_sounds.has(id), "the car dying plays %s" % id)
	var unknown := _sounds.filter(func(id: StringName) -> bool: return not RoadAudio.SOUNDS.has(id))
	eq(unknown, [], "and every sound it plays is one the road has")
	road.queue_free()
	Journey.change_scenes = _was_changing
	return true


func _on_sound(id: StringName, at: Vector3, volume_db: float) -> void:
	_sounds.append(id)
	_last = [id, at, volume_db]


## Which way Mei's face points, in the car's space (+X its left, +Z its front).
func _facing(road: RoadMain, mei: Node3D) -> Vector3:
	var head: Node3D = mei.get_node("Chest/Head")
	return road.car.global_basis.inverse() * head.global_basis.z


func _playing(road: RoadMain, sound: StringName) -> bool:
	return road.audio.find_children("*", "AudioStreamPlayer3D", true, false).any(
		func(a: AudioStreamPlayer3D) -> bool: return a.playing and a.stream == RoadAudio.SOUNDS[sound])
