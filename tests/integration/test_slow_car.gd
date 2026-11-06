extends TestCase
## The slow car in the scene: the model follows the core's gap in the couple's lane, shows one dim tail light and pulls
## into a lay-by on its cue; the road plays its old engine, the indicator and the rev.

var _was_changing := true


func _car() -> SlowCar:
	var car := SlowCar.new()
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


## The lens materials by name, as the car draws them.
func _lenses(car: SlowCar) -> Dictionary:
	var out := {}
	for m: Material in car.materials():
		if m.resource_name in [&"taillight_dim", &"taillight_dead"]:
			out[m.resource_name] = m
	return out


func test_it_follows_the_gap_in_the_couples_lane() -> bool:
	var car := _car()
	car.place(100.0, NAN)
	check(not car.visible, "hidden when there is no slow car")
	car.place(100.0, 12.0)
	check(car.visible, "shown when there is")
	near(car.global_position.distance_to(RoadLayout.point(112.0, RoadLayout.LANE)), 0.0, 0.01, "12 m ahead, in the couple's lane")
	near(car.global_basis.z.dot(RoadLayout.tangent(112.0)), 1.0, 0.01, "facing down the road")
	car.place(100.0, -30.0)
	near(car.global_position.distance_to(RoadLayout.point(70.0, RoadLayout.LANE)), 0.0, 0.01, "and behind, once he is past it")
	car.queue_free()
	return true


func test_one_tail_light_is_dim_and_the_other_dead() -> bool:
	var car := _car()
	var lenses := _lenses(car)
	eq(lenses.keys().size(), 2, "both lamps are in its materials, for the warm-up")
	var dim: StandardMaterial3D = lenses[&"taillight_dim"]
	check(dim.emission_enabled and dim.emission_energy_multiplier > 0.0 and dim.emission_energy_multiplier < 1.5, "one is lit, dimmer than the hatchback's")
	check(not (lenses[&"taillight_dead"] as StandardMaterial3D).emission_enabled, "the other gives no light")
	car.queue_free()
	return true


func test_it_pulls_into_the_lay_by_and_goes_dark() -> bool:
	var car := _car()
	car.place(100.0, 12.0)
	var dim: StandardMaterial3D = _lenses(car)[&"taillight_dim"]
	car.pull_in()
	car.place(110.0, NAN)  # the core has let go of it
	check(car.visible, "it stays on the road after the core's gap is gone")
	for i in ceili(SlowCarMission.PULL_SECONDS / 0.05) + 10:
		car._process(0.05)  # past the time it takes
	var parked := car.global_position
	near(car.speed, 0.0, 0.001, "it has stopped")
	near(parked.distance_to(RoadLayout.point(112.0 + SlowCarMission.PULL_DISTANCE, SlowCarMission.LAY_BY)), 0.0, 0.05, "in the lay-by, as far on as the mission says")
	near(dim.emission_energy_multiplier, 0.0, 0.001, "and its light is out")
	car.place(125.0, NAN)
	check(car.visible and car.global_position == parked, "it stays where it stopped")
	car.place(400.0, NAN)
	check(not car.visible, "out of sight once the road has left it far behind")
	car.queue_free()
	return true


## The ground plan of a model's body: its box's four corners in the world, flattened.
func _plan(node: Node3D, mesh_name: String) -> PackedVector2Array:
	var box := (node.find_child(mesh_name, true, false) as MeshInstance3D).get_aabb()
	var out := PackedVector2Array()
	for corner: Vector2 in [Vector2(box.position.x, box.position.z), Vector2(box.end.x, box.position.z), Vector2(box.end.x, box.end.z), Vector2(box.position.x, box.end.z)]:
		var p := node.global_transform * Vector3(corner.x, 0.0, corner.y)
		out.append(Vector2(p.x, p.z))
	return out


## The least distance between two plans that don't overlap, 0 if they do.
func _apart(a: PackedVector2Array, b: PackedVector2Array) -> float:
	if not Geometry2D.intersect_polygons(a, b).is_empty():
		return 0.0
	var least := INF
	for pair: Array in [[a, b], [b, a]]:
		for p: Vector2 in pair[0]:
			for i in 4:
				least = minf(least, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pair[1][i], pair[1][(i + 1) % 4])))
	return least


## The lay-by's numbers (SlowCarMission): the parked car clears the guard rail, and the couple, edged over to
## PASSING_LANE, go by it without touching it, whatever they pass at.
func test_the_couple_go_by_the_parked_car_clear_of_it_and_of_the_rail() -> bool:
	var couple := CarRig.new()
	tree.root.add_child(couple)
	var slow := _car()
	slow.place(640.0, SlowCarMission.FOLLOW_GAP)  # the keeper's lay-by, in switchback 1
	slow.pull_in()
	for i in ceili(SlowCarMission.PULL_SECONDS / 0.05) + 10:
		slow._process(0.05)
	var parked := _plan(slow, "old_sedan")
	var out := 0.0  # the plan's furthest corner from the centreline
	for p: Vector2 in parked:
		var at := Vector3(p.x, 0.0, p.y)
		var s := RoadLayout.closest_s(at)
		out = maxf(out, (at - RoadLayout.point(s)).dot(Vector3(RoadLayout.tangent(s).z, 0.0, -RoadLayout.tangent(s).x)))
	check(RoadBuilder.WALL_VALLEY - out >= 0.3, "the parked car is %.2f m inside the guard rail's face" % (RoadBuilder.WALL_VALLEY - out))
	var closest := INF
	var s := 640.0 + SlowCarMission.FOLLOW_GAP - 15.0
	while s < 640.0 + SlowCarMission.FOLLOW_GAP + SlowCarMission.PAST + 3.0:
		couple.place(s, SlowCarMission.PASSING_LANE)
		closest = minf(closest, _apart(parked, _plan(couple, "hatchback")))
		s += 0.25
	check(closest >= 0.3, "and the couple's car goes by it %.2f m clear" % closest)
	couple.queue_free()
	slow.queue_free()
	return true


func test_the_road_plays_the_slow_cars_sounds() -> bool:
	var road: RoadMain = await _road()
	road.director.slow_gap = 20.0
	await road.get_tree().process_frame
	await road.get_tree().process_frame
	check(road.slow_car.visible, "the slow car is shown for the core's gap")
	check(road.audio.loops[&"old_engine_loop"].playing, "its old engine runs")
	check(not road.audio.loops.has(&"indicator") or not road.audio.loops[&"indicator"].playing, "no indicator yet")
	EventBus.road_cue.emit(&"indicator")
	await road.get_tree().process_frame
	check(road.audio.loops[&"indicator"].playing, "the indicator ticks once Hafiz signals")
	EventBus.road_cue.emit(&"overtake")
	await road.get_tree().process_frame
	check(not road.audio.loops[&"indicator"].playing, "and stops when he pulls out")
	var revs := road.audio.find_children("*", "AudioStreamPlayer3D", true, false).filter(
		func(a: AudioStreamPlayer3D) -> bool: return a.playing and a.stream == RoadAudio.SOUNDS[&"rev"])
	eq(revs.size(), 1, "with a rev")
	road.director.slow_gap = NAN
	await road.get_tree().process_frame
	check(not road.slow_car.visible and not road.audio.loops[&"old_engine_loop"].playing, "no slow car, no old engine")
	_done(road)
	return true


func test_the_road_pulls_the_slow_car_in_and_lets_go_of_the_indicator() -> bool:
	var road: RoadMain = await _road()
	road.director.slow_gap = 20.0
	await road.get_tree().process_frame
	await road.get_tree().process_frame
	EventBus.road_cue.emit(&"indicator")
	await road.get_tree().process_frame
	check(road.audio.loops[&"indicator"].playing, "the indicator ticks")
	road.director.slow_gap = NAN  # no overtake came: the slow car is simply gone
	await road.get_tree().process_frame
	check(not road.audio.loops[&"indicator"].playing, "it stops with the slow car")
	road.director.slow_gap = 20.0
	await road.get_tree().process_frame
	await road.get_tree().process_frame
	check(not road.audio.loops[&"indicator"].playing, "and does not start again with the next one")
	EventBus.road_cue.emit(&"slow_car_gone")  # as the mission sends it, with the gap let go
	road.director.slow_gap = NAN
	await road.get_tree().process_frame
	await road.get_tree().process_frame
	check(road.slow_car.visible, "the slow car stays on the road, pulling in, once the core has let go of it")
	check(road.slow_car.speed < SlowCarMission.SLOW_SPEED, "and slowing (%.2f m/s)" % road.slow_car.speed)
	_done(road)
	return true
