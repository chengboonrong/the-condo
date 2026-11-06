extends TestCase
## The rear-view mirror: only it shows the fourth passenger, and it renders only while Mission 3 has it on.

const MIRROR_ONLY := 1 << 10  # render layer 11

var _was_changing := true
var _was_ending: StringName = &""


## The road scene, loaded and on its start card. Its ending must not reach the next test's flat (_done).
func _road() -> RoadMain:
	_was_changing = Journey.change_scenes
	_was_ending = Journey.road_ending
	Journey.change_scenes = false
	var road: RoadMain = load(Journey.ROAD_SCENE).instantiate()
	tree.root.add_child(road)
	for i in 600:
		if road.loaded:
			break
		await tree.process_frame
	return road


func _done(road: RoadMain) -> void:
	road.queue_free()
	Journey.change_scenes = _was_changing
	Journey.road_ending = _was_ending


func test_only_the_mirror_sees_her() -> bool:
	var car := CarRig.new()
	tree.root.add_child(car)
	var mirror := car.mirror
	eq(mirror.get_parent(), car.mirror_mount, "the mirror is on its mount")
	eq(mirror.fourth.get_parent(), car.seat_rear_right, "she sits in the rear right seat")
	var hers := mirror.fourth.find_children("*", "VisualInstance3D", true, false)
	check(not hers.is_empty(), "she is there")
	check(hers.all(func(v: VisualInstance3D) -> bool: return v.layers == MIRROR_ONLY), "on layer 11 only")
	check(hers.all(func(v: VisualInstance3D) -> bool: return v is not GeometryInstance3D or v.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),
		"casting no shadow the player could see")
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	tree.root.add_child(player)
	eq(player.camera.cull_mask & MIRROR_ONLY, 0, "the player's camera leaves layer 11 out")
	check(mirror.camera.cull_mask & MIRROR_ONLY != 0, "the mirror's camera draws it")
	eq([mirror.viewport.size, mirror.camera.fov], [Vector2i(320, 112), 30.0], "a 320x112 picture at fov 30")
	eq(mirror.fill.light_cull_mask, MIRROR_ONLY, "her own fill light lights nothing the player's camera sees")
	var listed := mirror.materials()
	for m: MeshInstance3D in mirror.fourth.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			check(listed.has(m.get_active_material(i)), "her %s is listed for the warm-up" % m.get_active_material(i).resource_name)
	mirror.set_on(true)
	await tree.process_frame
	var face := mirror.fourth.global_position + car.global_basis.y * 0.55
	check(mirror.camera.is_position_in_frustum(face), "the mirror looks back at her")
	mirror.glimpse()
	check(hers.all(func(v: VisualInstance3D) -> bool: return v.layers & 1 != 0), "turning to her, the player's camera sees her too")
	for i in 12:  # 0.2 s
		await tree.process_frame
	check(hers.all(func(v: VisualInstance3D) -> bool: return v.layers & 1 != 0), "for a moment")
	for i in 12:  # 0.4 s in all
		await tree.process_frame
	check(hers.all(func(v: VisualInstance3D) -> bool: return v.layers == MIRROR_ONLY), "then only the mirror again")
	player.queue_free()
	car.queue_free()
	return true


func test_the_mirror_renders_only_in_mission_3() -> bool:
	var road: RoadMain = await _road()
	var d := road.director
	var mirror := road.car.mirror
	var at := d.missions.find_custom(func(m: RoadMission) -> bool: return m is CountMission)
	eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "at the road's start it doesn't render")
	d.start_at(at)
	await tree.process_frame
	eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "set up for mission 3, not yet begun: still not")
	d.step(0.1)
	eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "mission 3 begins: it renders")
	check(mirror.fourth.visible, "with her in it")
	for i in 1200:
		if d.mission_index != at:
			break
		d.step(0.1)
		if d.pending == &"count":
			EventBus.choice_made.emit(&"count", 0)
	check(d.mission_index != at, "(mission 3 is over)")
	eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "and after mirror_off it doesn't")
	check(not mirror.fourth.visible, "and she is gone")
	d.start_at(at)
	d.step(0.1)
	d.debug_skip()
	eq(mirror.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "skipped part way: off too")
	_done(road)
	return true
