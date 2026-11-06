extends TestCase
## The car dying, in the scene: its lights fail (smoothly with reduced flashing), its engine stops, Hafiz gets out and
## walks off with his phone as a torch, something thumps on the roof and hangs there, and a light shows far down the
## road.

var _was_changing := true


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
		car.queue_free()
	Settings.set_value("reduced_flashing", was)
	return true


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
	await _frames(2)
	var p := road.player
	check(p.is_seated() and road.audio.loops[&"engine_loop"].playing, "(seated, with the engine running)")
	EventBus.road_cue.emit(&"lights_dying")
	await _frames(2)
	check(not road.audio.loops[&"engine_loop"].playing, "the engine stops when the car dies")
	check(_playing(road, &"engine_sputter"), "with a sputter")
	EventBus.road_cue.emit(&"hafiz_leaves")
	await _frames(60)
	var hafiz := road.couple.hafiz_out
	check(not road.couple.hafiz.visible and hafiz.visible, "Hafiz is out of his seat and on his feet")
	check(road.car.door_driver.rotation.y > 0.5, "his door is open")
	near(hafiz.global_position.distance_to(road.car.global_transform * Vector3(-1.2, 0.0, 0.1)), 0.0, 0.3, "and he stands beside it")
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
	EventBus.road_cue.emit(&"door_cracked")
	var opened := 0.0
	for i in 60:
		await tree.process_frame
		opened = minf(opened, road.car.door_rear_left.rotation.y)
	check(opened < -0.1 and opened > -0.2, "his door opens a hand's width (%.2f rad)" % opened)
	near(road.car.door_rear_left.rotation.y, 0.0, 0.001, "and is slapped shut")
	EventBus.road_cue.emit(&"light_on")
	await _frames(2)
	check(road.builder.far_light.visible, "a light shows far down the road")
	check(not road.her.visible, "and she has gone")
	road.queue_free()
	Journey.change_scenes = _was_changing
	return true


func _playing(road: RoadMain, sound: StringName) -> bool:
	return road.audio.find_children("*", "AudioStreamPlayer3D", true, false).any(
		func(a: AudioStreamPlayer3D) -> bool: return a.playing and a.stream == RoadAudio.SOUNDS[sound])
