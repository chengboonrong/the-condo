extends TestCase
## The ride: he sits in the couple's car and rides with it, his look is measured against the car, the car stops at
## the bus stop, the road's sounds play, and the thin slice plays from the start to the flat.

var _was_changing := true


func _player() -> PlayerController:
	var p: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	tree.root.add_child(p)
	return p


func _car() -> CarRig:
	var car := CarRig.new()
	tree.root.add_child(car)
	return car


func _road() -> RoadMain:
	_was_changing = Journey.change_scenes
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	road.hud.start()
	return road


func _done(road: RoadMain) -> void:
	road.queue_free()
	Journey.change_scenes = _was_changing


## Physics frames until `cond` holds, at most `seconds` of them; whether it held.
func _until(cond: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


## Turns him to look at `point`. His look is in his parent's frame: the seat's, while he sits.
func _face(p: PlayerController, point: Vector3) -> void:
	var to: Vector3 = (p.get_parent() as Node3D).global_basis.inverse() * (point - p.camera.global_position)
	p.set_look(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


func test_player_sits_and_stands() -> bool:
	var road := RoadBuilder.new()  # something to stand on afterwards
	tree.root.add_child(road)
	var car := _car()
	car.place(100.0, RoadLayout.LANE)
	var beam := (car.headlights[0].get_child(0) as MeshInstance3D).material_override
	check(car.materials().has(beam), "its materials, for the warm-up, include the headlight beams")
	var p := _player()
	p.global_position = RoadLayout.point(100.0, 4.0) + Vector3.UP * 0.05
	await tree.physics_frame
	p.sit(car.seat_rear_left)
	check(p.is_seated(), "he sits")
	check(p.shape.disabled, "his collision is off")
	p.use_scripted_move = true
	p.scripted_move = Vector2(0.0, 1.0)  # walking forward, all the way
	for i in 60:
		car.place(100.0 + 20.0 * (i + 1) / 60.0, RoadLayout.LANE)
		await tree.physics_frame
	near(p.global_position.distance_to(car.seat_rear_left.global_position), 0.0, 0.01, "20 m on he is still in the seat, whatever the move input")
	var stage := RoadGameStage.new(p, car)
	p.set_look(PI + 0.6, 2.0)  # what the mouse look calls (headless runs can't capture the mouse)
	near(stage.relative_yaw(), 0.6, 0.01, "his look turns against the car")
	near(p.pitch, 1.45, 0.001, "pitch clamped as when he stands")
	near(p.camera.global_position.y - car.seat_rear_left.global_position.y, PlayerController.SEAT_EYE, 0.01, "his eyes at a seated height")
	var at := Transform3D(Basis(Vector3.UP, RoadBuilder.yaw_along(130.0)), RoadLayout.point(130.0, 3.0) + Vector3.UP * 0.05)
	p.stand(at)
	check(not p.is_seated(), "he stands")
	check(not p.shape.disabled, "his collision is back")
	check(p.get_parent() == tree.root, "where he was before he sat")
	near(p.global_position.distance_to(at.origin), 0.0, 0.01, "at the place given")
	near(stage.relative_yaw(), 0.0, 0.05, "facing the way it faces, down the road")
	near(p.camera.global_position.y - p.global_position.y, PlayerController.STAND_HEIGHT - PlayerController.EYE_DROP, 0.01, "at his standing height")
	var from := p.global_position
	for i in 60:
		await tree.physics_frame
	check(p.global_position.distance_to(from) > 1.0, "and he walks again (%.2f m)" % p.global_position.distance_to(from))
	check(p.is_on_floor(), "on the road")
	p.queue_free()
	car.queue_free()
	road.queue_free()
	return true


## Switchback 1 (s 631 to 726) turns the car round: his look is measured against the car, so the hairpin itself
## never reads as turning round.
func test_relative_yaw_follows_the_car() -> bool:
	var car := _car()
	var p := _player()
	p.sit(car.seat_rear_left)
	var stage := RoadGameStage.new(p, car)
	car.place(620.0, RoadLayout.LANE)
	var before := car.global_basis.z
	for s: float in [620.0, 740.0]:
		car.place(s, RoadLayout.LANE)
		p.set_look(PI)
		near(stage.relative_yaw(), 0.0, 0.02, "s %.0f: looking along the car" % s)
		p.set_look(0.0)
		near(absf(stage.relative_yaw()), PI, 0.02, "s %.0f: facing the rear window" % s)
		p.set_look(PI + 1.0)
		near(stage.relative_yaw(), 1.0, 0.02, "s %.0f: to his left is positive" % s)
	check(before.dot(car.global_basis.z) < -0.95, "the car did turn round (%.2f)" % before.dot(car.global_basis.z))
	car.rotate_y(0.4)
	p.set_look(PI)
	near(stage.relative_yaw(), 0.0, 0.02, "against the car itself, not the road under it")
	p.stand(Transform3D(Basis(Vector3.UP, RoadBuilder.yaw_along(740.0) + 0.5), RoadLayout.point(740.0, 3.0)))
	near(stage.relative_yaw(), 0.5, 0.02, "walking, it is measured against the road")
	p.queue_free()
	car.queue_free()
	return true


func test_the_car_stops_at_the_stop() -> bool:
	var road: RoadMain = await _road()
	road.player.global_position = RoadLayout.BUS_STOP + Vector3.UP * 0.05
	var seen := []  # [cue, the car shown, where it is]
	var on_cue := func(cue: StringName) -> void: seen.append([cue, road.car.visible, road.car.global_position])
	EventBus.road_cue.connect(on_cue)
	check(not road.car.visible, "the car is not on the road while it stands up the hill")
	var stopped := await _until(func() -> bool: return seen.any(func(c: Array) -> bool: return c[0] == &"couple_stops"), 120.0)
	EventBus.road_cue.disconnect(on_cue)
	check(stopped, "the couple stop for him")
	check(seen.any(func(c: Array) -> bool: return c[0] == &"lorry_passes"), "the lorry passed first")
	for c: Array in seen:
		if c[0] == &"lorry_passes":
			check(not c[1], "20 s into the wait the car is still not shown")
		elif c[0] == &"couple_stops":
			check(c[1], "it is shown once it has come")
			near(c[2].distance_to(RoadLayout.point(RoadLayout.BUS_STOP_S, RoadLayout.LANE)), 0.0, 0.3, "the car stands at the stop")
	check(road.audio.loops[&"engine_loop"].playing, "its engine runs")
	_done(road)
	return true


## He waits in the lane, where the car stops: it must not shove him or shut him in, and once he steps clear of it,
## it is solid again.
func test_the_car_does_not_stop_on_him() -> bool:
	var road: RoadMain = await _road()
	var p := road.player
	var lane := RoadLayout.point(RoadLayout.BUS_STOP_S, RoadLayout.LANE)
	var off := func() -> float: return Vector2(p.global_position.x - lane.x, p.global_position.z - lane.z).length()
	p.global_position = lane + Vector3.UP * 0.05
	var stopped := await _until(func() -> bool: return WorldState.prompts.get(&"car_door", "") == "Get in", 120.0)
	check(stopped, "the couple stop, with him in the lane")
	for i in 30:
		await tree.physics_frame
	near(off.call(), 0.0, 0.05, "the car coming and standing where he stands does not shove him")
	p.use_scripted_move = true
	p.scripted_move = Vector2(0.0, 1.0)
	var out := await _until(func() -> bool:
		_face(p, RoadLayout.BUS_STOP + Vector3.UP * 1.62)
		return off.call() > 2.0, 3.0)
	p.scripted_move = Vector2.ZERO
	check(out, "he walks out of it (%.2f m)" % off.call())
	await tree.physics_frame
	await tree.physics_frame
	var shapes := road.car.find_children("*", "CollisionShape3D", true, false)
	check(not shapes.is_empty() and shapes.all(func(c: CollisionShape3D) -> bool: return not c.disabled), "once he is clear, it is solid")
	_done(road)
	return true


## The car standing at the stop is solid to him: he walks up to its door but not into it, and "Get in" holds while he
## stands against it.
func test_the_stopped_car_is_solid_to_him() -> bool:
	var road: RoadMain = await _road()
	var p := road.player
	p.global_position = RoadLayout.point(RoadLayout.BUS_STOP_S, 4.0) + Vector3.UP * 0.05
	var came := await _until(func() -> bool: return WorldState.prompts.get(&"car_door", "") == "Get in", 120.0)
	check(came, "the couple stop for him")
	var door := road.car.door_rear_left
	p.use_scripted_move = true
	p.scripted_move = Vector2(0.0, 1.0)
	var closest := INF
	var held := 0
	for i in 120:  # 2 s of walking at its door
		_face(p, door.global_transform * (door.get_child(-1) as CollisionShape3D).position)
		await tree.physics_frame
		closest = minf(closest, absf(road.car.to_local(p.global_position).x))
		if i >= 90 and p.interaction.target == door:
			held += 1
	p.scripted_move = Vector2.ZERO
	check(closest >= 0.78 + 0.3 - 0.01, "he stays outside its body (%.2f m from its centre line)" % closest)
	eq(held, 30, "and its door stays the thing he looks at, while he stands against it")
	eq(WorldState.prompts.get(&"car_door", ""), "Get in", "with its Get in")
	_done(road)
	return true


func test_the_slice_plays_through() -> bool:
	var road: RoadMain = await _road()
	var p := road.player
	var ended := []
	road.finished.connect(func(ending: StringName) -> void: ended.append(ending))
	var stop := RoadLayout.point(RoadLayout.BUS_STOP_S, 4.0)
	p.use_scripted_move = true
	p.scripted_move = Vector2(0.0, 1.0)
	var walked := await _until(func() -> bool:
		_face(p, stop + Vector3.UP * 1.62)
		return p.global_position.distance_to(stop) < 0.6, 60.0)
	p.scripted_move = Vector2.ZERO
	check(walked, "he walks down to the stop (%.1f m off)" % p.global_position.distance_to(stop))
	var came := await _until(func() -> bool: return WorldState.prompts.get(&"car_door", "") == "Get in", 120.0)
	check(came, "the couple stop for him")
	var door := road.car.door_rear_left
	_face(p, door.global_transform * (door.get_child(-1) as CollisionShape3D).position)
	await tree.physics_frame
	await tree.physics_frame
	eq(p.interaction.target, door, "he looks at the rear door")
	check(p.interaction.try_interact(), "and gets in")
	await tree.process_frame  # the scene follows the core in its own _process, after this signal
	await tree.process_frame
	eq([road.director.seated, p.is_seated()], [true, true], "seated in the back")
	eq(door.object_id, &"car_door_inside", "the door is now the one beside him")
	WorldState.set_prompt(&"car_door_inside", "Open the door")  # as a later mission prompts it
	_face(p, door.global_transform * (door.get_child(-1) as CollisionShape3D).position)
	await tree.physics_frame
	await tree.physics_frame
	eq(p.interaction.target, door, "seated, he can look at that door and use it")
	WorldState.prompts.erase(&"car_door_inside")
	for i in road.director.missions.size() + 1:
		if road.director.ending != &"":
			break
		road.director.debug_skip()
	eq(ended, [&"alive"], "the road plays through to the flat, all alive")
	_done(road)
	return true


func test_road_audio_plays_the_road() -> bool:
	var audio := RoadAudio.new()
	tree.root.add_child(audio)
	for id: StringName in [&"engine_loop", &"old_engine_loop", &"insects_loop", &"indicator", &"phone_ring_mobile"]:
		eq((RoadAudio.LOOPS[id] as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops (its .import)" % id)
	audio.set_loop(&"engine_loop", true, -12.0, 1.3)
	var engine: AudioStreamPlayer = audio.loops[&"engine_loop"]
	check(engine.playing, "the engine starts")
	audio.set_loop(&"engine_loop", true, -14.0, 0.8)
	check(engine == audio.loops[&"engine_loop"] and engine.playing, "and keeps going on the same player")
	near(engine.volume_db, -14.0, 0.001, "at its new level")
	near(engine.pitch_scale, 0.8, 0.001, "and pitch")
	audio.set_loop(&"engine_loop", false, -14.0)
	check(not engine.playing, "and stops")
	var players := audio.get_child_count()
	audio.set_loop(&"no_such_loop", true, 0.0)  # warns
	check(audio.get_child_count() == players and not audio.loops.has(&"no_such_loop"), "an unknown loop is refused, leaving no player")
	EventBus.sound_requested.emit(&"player_step", Vector3.ZERO, -15.0)
	var steps := audio.find_children("*", "AudioStreamPlayer3D", true, false).filter(func(a: AudioStreamPlayer3D) -> bool: return a.playing)
	eq(steps.size(), 1, "a footstep plays")
	check(not steps.is_empty() and RoadAudio.STEPS.has(steps[0].stream), "on asphalt")
	audio.queue_free()
	return true
