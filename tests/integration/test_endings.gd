extends TestCase
## The walk to the light and the road's three endings, in the scene: the cues come from here, with the core standing
## still (the road is left on its start card), so each is seen to on its own.

var _was_changing := true
var _sounds: Array[StringName] = []
var _lines: Array[String] = []


func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


## The road, skipped to the walk to the light (as `--mission=5` does), on its start card.
func _road() -> RoadMain:
	_was_changing = Journey.change_scenes
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	_sounds.clear()
	_lines.clear()
	EventBus.sound_requested.connect(_on_sound)
	EventBus.line_requested.connect(_on_line)
	return road


func _done(road: RoadMain) -> void:
	EventBus.sound_requested.disconnect(_on_sound)
	EventBus.line_requested.disconnect(_on_line)
	var unknown := _sounds.filter(func(id: StringName) -> bool: return not RoadAudio.SOUNDS.has(id))
	eq(unknown, [], "every sound played is one the road has")
	road.queue_free()
	Journey.change_scenes = _was_changing


func _on_sound(id: StringName, _at: Vector3, _volume_db: float) -> void:
	_sounds.append(id)


func _on_line(text: String, _seconds: float) -> void:
	_lines.append(text)


func _light_index(road: RoadMain) -> int:
	return road.director.missions.find_custom(func(m: RoadMission) -> bool: return m is LightMission)


func _looping(road: RoadMain, id: StringName) -> bool:
	var p: AudioStreamPlayer = road.audio.loops.get(id)
	return p != null and p.playing


## He stands at `s` on the verge, facing down the road.
func _put(road: RoadMain, s: float) -> void:
	road.player.stand(Transform3D(Basis.looking_at(RoadLayout.tangent(s).slide(Vector3.UP).normalized()), RoadLayout.point(s, 3.3)))


func test_a_skip_to_the_walk_sets_the_scene() -> bool:
	var road := await _road()
	road.couple.mei_faces(&"door")  # left over from Mission 4: she was saying her line to her door
	road.director.start_at(_light_index(road))
	await _frames(3)
	var d := road.director
	var p := road.player
	check(not p.is_seated(), "he is out of the car")
	near(p.global_position.distance_to(road._beside_door().origin), 0.0, 0.05, "standing beside his door")
	var mei := road.couple.mei_out
	var s := RoadLayout.closest_s(p.global_position)
	check(mei.visible and not road.couple.mei.visible, "Mei is out too")
	near(RoadLayout.closest_s(mei.global_position), s, 0.05, "level with him")
	near(Couple.across(mei.global_position, s) - Couple.across(p.global_position, s), 1.0, 0.05, "a metre to his left")
	check(road.car.headlights.all(func(spot: SpotLight3D) -> bool: return not spot.visible or spot.light_energy == 0.0), "the car is dark")
	check(not _looping(road, &"engine_loop") and not _looping(road, &"insects_loop"), "and dead, and the insects quiet")
	check(not road.couple.hafiz.visible and not road.couple.hafiz_out.visible, "Hafiz is gone")
	check(not road.her.visible, "she is off the roof")
	var e := road.endings
	check(road.builder.far_light.visible and road.builder.far_core.visible, "the light is on down the road")
	check(e.stall.visible, "at the stall")
	near(e.stall.global_position.distance_to(Endings.stall_at(d.light_s).origin), 0.0, 0.01, "150 m on")
	check(e.bulb.visible and e.bulb.light_energy > 0.0, "its bulb lit")
	EventBus.road_line.emit(&"mei", 3.0)  # her first line of the walk
	await _frames(40)
	var face: Vector3 = road.car.global_basis.inverse() * (road.couple.mei.get_node("Chest/Head") as Node3D).global_basis.z
	check(face.z < -0.3, "her first line has no pose left over from her door (%s)" % face)
	_done(road)
	return true


func test_getting_out_and_walking_beside_him() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	road.director.seated = true  # as Mission 4 leaves him
	await _frames(3)
	check(road.player.is_seated() and road.couple.mei.visible and not road.couple.mei_out.visible, "(both in the car)")
	road.director.seated = false
	EventBus.road_cue.emit(&"get_out")
	var opened := 0.0
	for i in 120:
		await tree.process_frame
		opened = minf(opened, road.car.door_rear_left.rotation.y)
	check(opened < -0.5, "his door swings open (%.2f rad)" % opened)
	check(not road.player.is_seated(), "and he gets out")
	check(_sounds.count(&"car_door_open") >= 2 and _sounds.count(&"car_door_close") >= 1, "both doors are heard (%s)" % [_sounds])
	var p := road.player
	var mei := road.couple.mei_out
	var legs: Node3D = mei.get_node("LegL")
	var swing := 0.0
	var s0 := RoadLayout.closest_s(p.global_position)
	for i in 90:  # he walks 3 m down the road
		p.global_position = RoadLayout.point(s0 + 3.0 * (i + 1) / 90.0, 3.3)
		await tree.process_frame
		swing = maxf(swing, absf(legs.rotation.x))
	var s := RoadLayout.closest_s(p.global_position)
	near(Couple.across(mei.global_position, s) - Couple.across(p.global_position, s), 1.0, 0.05, "Mei walks a metre to his left")
	near(RoadLayout.closest_s(mei.global_position), s, 0.1, "level with him")
	check(swing > 0.1, "in her stride (%.2f rad)" % swing)
	var ahead := mei.global_basis.z.slide(Vector3.UP).normalized()
	check(ahead.dot(RoadLayout.tangent(s).slide(Vector3.UP).normalized()) > 0.95, "facing down the road")
	EventBus.road_cue.emit(&"her_behind")
	await _frames(2)
	var her := road.her
	check(her.visible and RoadLayout.closest_s(her.global_position) < s - 3.0, "she follows behind them")
	EventBus.road_cue.emit(&"mei_looks")
	await _frames(40)
	var head: Node3D = mei.get_node("Head")
	check(head.rotation.y < -1.0, "Mei looks back, over her right shoulder (her head %.0f deg)" % rad_to_deg(head.rotation.y))
	await _frames(roundi((Couple.LOOK_BACK + Couple.TURN) * 60.0))
	near(head.rotation.y, 0.0, 0.01, "and turns ahead again")
	_done(road)
	return true


func test_alive_hafiz_and_a_lorry_at_the_stall() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	await _frames(3)
	var light_s := road.director.light_s
	_put(road, light_s - 30.0)
	EventBus.road_cue.emit(&"hafiz_at_stall")
	await _frames(2)
	var lorry := road.lorry
	near(lorry.global_position.distance_to(CarRig.on_road(light_s + Endings.LORRY_AHEAD, RoadLayout.LANE).origin), 0.0, 0.01, "a lorry stands past the stall")
	check(_looping(road, &"lorry_idle"), "idling")
	check(not road.endings.phone.visible, "his phone is not on the table")
	var hafiz := road.couple.hafiz_out
	check(hafiz.visible, "Hafiz walks up from beside it")
	var closest := INF  # metres between him and the lorry's side, at the least
	for i in 60 * 11:
		if i == 300:
			_put(road, light_s - 4.0)  # they are there
		await tree.process_frame
		var side := lorry.global_transform.affine_inverse() * hafiz.global_position
		if absf(side.z) < 4.3:
			closest = minf(closest, absf(side.x) - 1.2)
	check(closest > 0.3, "clear of the lorry's side (%.2f m)" % closest)
	var hs := RoadLayout.closest_s(hafiz.global_position)
	check(hs > light_s + 1.0 and hs < light_s + 2.5, "to the stall's far side (%.1f m past the light)" % (hs - light_s))
	var faces := hafiz.global_basis.z.slide(Vector3.UP).normalized().dot(-RoadLayout.tangent(hs).slide(Vector3.UP).normalized())
	check(faces > 0.95, "facing up the road to them")
	near((hafiz.get_node("LegL") as Node3D).rotation.x, 0.0, 0.01, "standing still")
	var e := road.endings
	var lit := e.bulb.global_position.distance_to(hafiz.global_position + Vector3.UP * 1.6)
	check(lit < e.bulb.omni_range * 0.5, "under the bulb (%.1f m from his face)" % lit)
	EventBus.road_cue.emit(&"card_on")
	await _frames(2)
	check(road.hud.is_card_shown() and not _looping(road, &"lorry_idle"), "the card, and the diesel is left behind")
	_done(road)
	return true


func test_saved_his_phone_and_a_lorry_behind_them() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	await _frames(3)
	var light_s := road.director.light_s
	_put(road, light_s - 4.0)
	EventBus.road_cue.emit(&"her_behind")
	var e := road.endings
	check(e.phone.visible and e._screen.emission_energy_multiplier == 0.0, "a phone lies on the table, dark")
	EventBus.road_cue.emit(&"phone_rings")
	await _frames(2)
	check(_looping(road, &"phone_ring_mobile") and e._screen.emission_energy_multiplier > 0.5, "it rings, and lights up")
	EventBus.road_cue.emit(&"lorry_stops")
	await _frames(2)
	var lorry := road.lorry
	var first := RoadLayout.closest_s(lorry.global_position)
	check(not road.her.visible, "out of the fog behind them a lorry comes, and she is gone")
	await _frames(60)
	check(lorry.speed > 0.0 and RoadLayout.closest_s(lorry.global_position) > first, "down the road")
	await _frames(roundi(Lorry.PULLING * 60.0))
	var at := RoadLayout.closest_s(road.player.global_position) - Endings.LORRY_BEHIND
	near(lorry.global_position.distance_to(CarRig.on_road(at, RoadLayout.LANE).origin), 0.0, 0.05, "and pulls up behind them")
	check(_sounds.has(&"lorry_brake") and _looping(road, &"lorry_idle"), "its brakes hiss, and it idles")
	EventBus.road_cue.emit(&"card_on")
	await _frames(2)
	check(not _looping(road, &"phone_ring_mobile") and not _looping(road, &"lorry_idle"), "the card leaves both behind")
	_done(road)
	return true


func test_caught_the_light_dies_and_she_takes_hafiz() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	await _frames(3)
	var light_s := road.director.light_s
	var p := road.player
	_put(road, light_s - 30.0)
	p.toggle_phone_light()
	road.couple.walk_beside(p)
	road.director.her_near = 0.84  # as near as she is at the least, for the road to end caught (7 rules' weight)
	EventBus.road_cue.emit(&"her_behind")
	await _frames(120)
	var e := road.endings
	EventBus.road_cue.emit(&"light_out")
	await _frames(roundi(Endings.DIE * 60.0) + 2)
	check(not e.bulb.visible and not road.builder.far_light.visible and not road.builder.far_core.visible, "the light dies, haze and all")
	var hafiz := road.couple.hafiz_out
	var hs := RoadLayout.closest_s(hafiz.global_position)
	check(hafiz.visible and hs > light_s - 30.0 + 12.0, "Hafiz is out of the fog ahead (%.1f m)" % (hs - light_s + 30.0))
	await _frames(roundi(LightMission.CAUGHT_CATCH * 60.0))
	var walked := hs - RoadLayout.closest_s(hafiz.global_position)
	check(walked > 3.0, "coming up the road to them (%.1f m)" % walked)
	EventBus.road_cue.emit(&"her_catches_hafiz")
	var her := road.her
	var heads: Array[Node3D] = [p.camera, road.couple.mei_out.get_node("Head")]
	var clear := INF  # metres her insides' ends pass over a walker's head, at the least, while within a metre of it
	var lit := 0  # frames she is in his phone light, flying to Hafiz
	var there := [false]
	her.arrived.connect(func() -> void: there[0] = true)
	var down := -1
	for i in 600:
		await tree.process_frame
		if not there[0]:
			for head: Node3D in heads:
				var to := her.global_position - head.global_position
				if to.slide(Vector3.UP).length() < 1.0:
					clear = minf(clear, to.y - 2.05)
			var light := p.phone_light
			var to_her := her.global_position - light.global_position
			if to_her.length() < light.spot_range and rad_to_deg(to_her.angle_to(-light.global_basis.z)) < light.spot_angle:
				lit += 1
		if _lines.has(Endings.SCREAM):
			down = i
			break
	check(clear > 0.3, "she flies up and over them (%.2f m clear)" % clear)
	eq(lit, 0, "out of his phone light")
	check(down > 0, "she takes Hafiz, and once he is down Mei screams (%.1f s)" % (down / 60.0))
	EventBus.road_cue.emit(&"her_comes")
	var reached := -1
	for i in 600:
		await tree.process_frame
		if road.hud.is_card_shown():
			reached = i
			break
	check(reached > 0, "she comes for them, and the card cuts in as she reaches him (%.1f s)" % (reached / 60.0))
	check(down / 60.0 + reached / 60.0 < LightMission.CAUGHT_END - LightMission.CAUGHT_CATCH, "before the core's backstop")
	near(her.global_position.distance_to(p.camera.global_position), Penanggal.CLOSE, 0.05, "face to face")
	eq(road.hud.card_text(), "", "with no caption")
	_done(road)
	return true
