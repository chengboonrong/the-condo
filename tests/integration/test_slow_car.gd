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
	for i in 90:
		car._process(0.05)  # 4.5 s: past the 3 s it takes
	var parked := car.global_position
	near(car.speed, 0.0, 0.001, "it has stopped")
	near(parked.distance_to(RoadLayout.point(112.0 + 6.0, RoadLayout.LANE + 1.5)), 0.0, 0.5, "6 m further on, in the lay-by")
	near(dim.emission_energy_multiplier, 0.0, 0.001, "and its light is out")
	car.place(125.0, NAN)
	check(car.visible and car.global_position == parked, "it stays where it stopped")
	car.place(400.0, NAN)
	check(not car.visible, "out of sight once the road has left it far behind")
	car.queue_free()
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
