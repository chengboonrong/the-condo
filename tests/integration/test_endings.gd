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


## He stands at `s`, on his line down the road unless `across` says otherwise, facing down the road.
func _put(road: RoadMain, s: float, across := 3.3) -> void:
	road.player.stand(Transform3D(Basis.looking_at(RoadLayout.tangent(s).slide(Vector3.UP).normalized()), RoadLayout.point(s, across)))


## The walk is over 4 m short of the light: he walks on to `s`, `across`, over 2 s, and Mei stays where she stopped,
## clear of the stall's box by her own width. Returns the least clearance, in metres.
func _walk_on(road: RoadMain, s: float, across: float) -> float:
	var light_s := road.director.light_s
	var p := road.player
	var mei := road.couple.mei_out
	EventBus.road_cue.emit(&"walk_over")
	var from := RoadLayout.closest_s(p.global_position)
	var from_across := RoadLayout.across(p.global_position, from)
	var clear := INF
	for i in 120:
		var k := (i + 1) / 120.0
		var at := lerpf(from, s, k)
		p.global_position = RoadLayout.point(at, lerpf(from_across, across, k))
		await tree.process_frame
		var local := road.endings.stall.global_transform.affine_inverse() * mei.global_position - Endings.BOX_AT
		clear = minf(clear, maxf(absf(local.x) - Endings.BOX.x / 2.0, absf(local.z) - Endings.BOX.z / 2.0) - 0.25)
	near(RoadLayout.closest_s(mei.global_position), light_s - 4.0, 0.1, "Mei stays where the walk ended")
	return clear


func test_a_skip_to_the_walk_sets_the_scene() -> bool:
	var road := await _road()
	road.couple.mei_faces(&"door")  # left over from Mission 4: she was saying her line to her door
	road.director.start_at(_light_index(road))
	await _frames(3)
	var d := road.director
	var p := road.player
	check(not p.is_seated(), "he is out of the car")
	near(p.global_position.distance_to(road.beside_door().origin), 0.0, 0.05, "standing beside his door")
	var mei := road.couple.mei_out
	var s := RoadLayout.closest_s(p.global_position)
	check(mei.visible and not road.couple.mei.visible, "Mei is out too")
	near(RoadLayout.closest_s(mei.global_position), s, 0.05, "level with him")
	near(RoadLayout.across(mei.global_position, s) - RoadLayout.across(p.global_position, s), 1.0, 0.05, "a metre to his left")
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
	near(RoadLayout.across(mei.global_position, s) - RoadLayout.across(p.global_position, s), 1.0, 0.05, "Mei walks a metre to his left")
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


## The lorry's body, in its own space: every box it is built of.
func _lorry_box(lorry: Lorry) -> AABB:
	var box := AABB()
	for m: MeshInstance3D in lorry.find_children("*", "MeshInstance3D", true, false):
		var part := m.transform * m.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	return box


func test_alive_hafiz_flags_a_lorry_down() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	await _frames(3)
	var light_s := road.director.light_s
	var p := road.player
	_put(road, light_s - 30.0)
	EventBus.road_cue.emit(&"her_behind")
	EventBus.road_cue.emit(&"hafiz_at_stall")
	await _frames(1)
	var lorry := road.lorry
	check(not lorry.visible, "no lorry yet")
	check(road.endings.phone.visible, "the phone on the table stays: it would be seen to go")
	var hafiz := road.couple.hafiz_out
	var torch := road.couple.torch
	var from := RoadLayout.closest_s(hafiz.global_position)
	check(hafiz.visible and from > light_s + 55.0, "Hafiz walks up out of the fog below, from beyond what it shows (%.0f m past the light)" % (from - light_s))
	eq(torch.light_energy, 0.0, "his torch not on yet")
	var lit := [-1, -1, INF]  # frames in: his torch comes on, it is fully on; metres from him as it comes on
	var torch_on := func(frame: int) -> void:
		if lit[0] < 0 and torch.light_energy > 0.0:
			lit[0] = frame
			lit[2] = RoadLayout.closest_s(hafiz.global_position) - RoadLayout.closest_s(p.global_position)
		if lit[1] < 0 and torch.light_energy == Couple.TORCH_ENERGY:
			lit[1] = frame
	var walk := roundi((30.0 - LightMission.THERE) / PlayerController.SPRINT_SPEED * 60.0)  # the soonest he is there
	for i in walk:
		p.global_position = RoadLayout.point(light_s - 30.0 + (30.0 - LightMission.THERE) * (i + 1) / walk, 3.3)
		await tree.process_frame
		torch_on.call(i)
	EventBus.road_cue.emit(&"walk_over")  # they are there, as the core says
	EventBus.road_cue.emit(&"lorry_flagged")
	await _frames(1)
	var box := _lorry_box(lorry)
	var behind := RoadLayout.closest_s(p.global_position) - RoadLayout.closest_s(lorry.global_position) - box.end.z
	check(lorry.visible and behind > p.camera.far, "a lorry comes down the mountain behind them, from past what he can see (%.0f m)" % behind)
	check(not road.her.visible, "and she is gone")
	check(_looping(road, &"lorry_idle"), "its diesel heard")
	var mei := road.couple.mei_out
	var clear := {p: INF, mei: INF, hafiz: INF}  # metres from the lorry's side to each one's line, while beside it, at the least
	var passing := 0.0  # m/s, its fastest beside any of them
	var line := 0.0  # metres off the line it comes down, at the most
	var inside := INF  # metres its far side is inside the centreline, at the least
	for i in roundi(LightMission.ALIVE_HAFIZ * 60.0) - 1:
		await tree.process_frame
		torch_on.call(walk + 2 + i)
		var ls := RoadLayout.closest_s(lorry.global_position)
		var la := RoadLayout.across(lorry.global_position, ls)
		line = maxf(line, absf(la - Lorry.LINE))
		inside = minf(inside, la - box.end.x)
		for who: Node3D in clear:
			var local := lorry.global_transform.affine_inverse() * who.global_position
			if local.z > box.position.z - 0.25 and local.z < box.end.z + 0.25:  # a person is about 0.5 m across
				clear[who] = minf(clear[who], absf(local.x) - box.end.x)
				passing = maxf(passing, lorry.speed)
	check(lit[2] < Couple.TORCH_NEAR and lit[2] > Couple.TORCH_NEAR - 1.0, "he puts his torch on once he is near them (%.1f m)" % lit[2])
	near((lit[1] - lit[0]) / 60.0, Couple.TORCH_FADE, 0.05, "and it comes on over about 2 s")
	check(clear[p] < INF and clear[mei] < INF, "it passes them")
	check(passing <= Lorry.PASS + 0.001, "slowly (%.1f m/s at the most)" % passing)
	check(clear[p] >= 0.5 and clear[mei] >= 0.5 and clear[hafiz] >= 0.5, "its side half a metre clear of his line, Mei's and Hafiz's at the least (%.2f, %.2f, %.2f m)" % [clear[p], clear[mei], clear[hafiz]])
	check(line < 0.01 and inside >= 0.0, "wholly in their lane (%.2f m off its line, its far side %.2f m inside the centreline)" % [line, inside])
	near(lorry.global_position.distance_to(CarRig.on_road(light_s + Endings.LORRY_AHEAD, Lorry.LINE).origin), 0.0, 0.01, "it has pulled up just past the stall, facing down the road, where Hafiz flagged it")
	check(lorry.speed == 0.0 and _sounds.has(&"lorry_brake") and _looping(road, &"lorry_idle"), "its brakes hiss, and it idles")
	var hs := RoadLayout.closest_s(hafiz.global_position)
	check(hs > light_s + 1.0 and hs < light_s + 2.5, "Hafiz is at the stall's far side (%.1f m past the light)" % (hs - light_s))
	var faces := hafiz.global_basis.z.slide(Vector3.UP).normalized().dot(-RoadLayout.tangent(hs).slide(Vector3.UP).normalized())
	check(faces > 0.95, "facing up the road to them")
	near((hafiz.get_node("LegL") as Node3D).rotation.x, 0.0, 0.01, "standing still")
	var e := road.endings
	var off := absf(RoadLayout.across(hafiz.global_position, hs) - RoadLayout.across(e.bulb.global_position, hs))
	check(off < 1.5, "under the bulb (%.1f m across the road from it)" % off)
	var on := await _walk_on(road, hs - 1.0, 3.0)
	check(on > 0.0, "he walks on to Hafiz, and Mei is never in the stall (%.2f m clear)" % on)
	EventBus.road_cue.emit(&"card_on")
	await _frames(2)
	check(road.hud.is_card_shown() and not _looping(road, &"lorry_idle"), "the card, and the diesel is left behind")
	_done(road)
	return true


## He is free to walk: once they are there he steps out into the middle of its lane at the stall, and the lorry he
## flagged down holds short of him, idling, and goes on to its stop once he steps to the edge.
func test_alive_the_lorry_holds_for_him_in_its_lane() -> bool:
	var road := await _road()
	road.director.start_at(_light_index(road))
	await _frames(3)
	var light_s := road.director.light_s
	var p := road.player
	_put(road, light_s - LightMission.THERE)
	await _frames(2)
	EventBus.road_cue.emit(&"walk_over")  # they are there, as the core says: Mei stops beside him
	EventBus.road_cue.emit(&"lorry_flagged")
	_put(road, light_s, RoadLayout.LANE)
	await _frames(1)
	var lorry := road.lorry
	var box := _lorry_box(lorry)
	var r := (p.shape.shape as CapsuleShape3D).radius
	var nearest := INF  # metres from its nose to his line ahead, while he is across its width, at the least
	var touched := false
	for i in roundi(LightMission.ALIVE_HAFIZ * 60.0):
		await tree.process_frame
		var local := lorry.global_transform.affine_inverse() * p.global_position
		if absf(local.x) < box.end.x + r:
			nearest = minf(nearest, local.z - box.end.z)
			touched = touched or (local.z > box.position.z - r and local.z < box.end.z + r)
	check(not touched and nearest > r, "it comes up behind him and never touches him (its nose %.2f m short of him)" % nearest)
	var held := lorry.global_position
	await _frames(60)
	check(lorry.speed == 0.0 and lorry.global_position.distance_to(held) < 0.001, "it holds there while he stands in its way")
	check(not _sounds.has(&"lorry_brake") and _looping(road, &"lorry_idle"), "idling, short of its stop")
	_put(road, light_s, RoadBuilder.EDGE - 0.4)  # he steps to the edge
	var clear := INF  # metres from its side to his line, while beside him, at the least
	for i in 10 * 60:
		await tree.process_frame
		var local := lorry.global_transform.affine_inverse() * p.global_position
		if local.z > box.position.z - r and local.z < box.end.z + r:
			clear = minf(clear, absf(local.x) - box.end.x)
	check(clear >= 0.5 and clear < INF, "once the way is clear it drives on past him (%.2f m from his line)" % clear)
	near(lorry.global_position.distance_to(CarRig.on_road(light_s + Endings.LORRY_AHEAD, Lorry.LINE).origin), 0.0, 0.01, "to its stop past the stall")
	check(lorry.speed == 0.0 and _sounds.has(&"lorry_brake"), "and pulls up there, its brakes hissing")
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
	check(e.phone.visible and e.screen.emission_energy_multiplier == 0.0 and e.ring_light.light_energy == 0.0, "a phone lies on the table, dark")
	EventBus.road_cue.emit(&"phone_rings")
	await _frames(2)
	check(_looping(road, &"phone_ring_mobile") and e.screen.emission_energy_multiplier > 0.5, "it rings, and lights up")
	check(e.ring_light.visible and e.ring_light.light_energy > 0.0 and not e.ring_light.shadow_enabled, "and the table round it")
	var clear := await _walk_on(road, light_s + Endings.PHONE.x, RoadBuilder.EDGE - 0.4)
	check(clear > 0.0, "he walks on to the phone, and Mei is never in the stall (%.2f m clear)" % clear)
	EventBus.road_cue.emit(&"lorry_stops")
	await _frames(2)
	var lorry := road.lorry
	var first := RoadLayout.closest_s(lorry.global_position)
	check(not road.her.visible, "out of the fog behind them a lorry comes, and she is gone")
	await _frames(60)
	check(lorry.speed > 0.0 and RoadLayout.closest_s(lorry.global_position) > first, "down the road")
	await _frames(roundi(Lorry.PULLING * 60.0))
	var at := RoadLayout.closest_s(road.player.global_position) - Endings.LORRY_BEHIND
	near(lorry.global_position.distance_to(CarRig.on_road(at, Lorry.LINE).origin), 0.0, 0.05, "and pulls up behind them")
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
	check(e.dropped_light.is_visible_in_tree() and e.dropped_light.light_energy == 0.0 and not e.dropped.visible, "the light his phone will throw is there, dark: switched by its energy alone")
	EventBus.road_cue.emit(&"light_out")
	await _frames(roundi(Endings.DIE * 60.0) + 2)
	check(e.bulb.light_energy == 0.0 and not road.builder.far_light.visible and not road.builder.far_core.visible, "the light dies, haze and all")
	var hafiz := road.couple.hafiz_out
	var hs := RoadLayout.closest_s(hafiz.global_position)
	check(hafiz.visible and hs > light_s - 30.0 + Endings.HAFIZ_AHEAD - 1.0, "Hafiz is out of the fog ahead (%.1f m)" % (hs - light_s + 30.0))
	var torch := road.couple.torch
	var at_them := (p.camera.global_position - torch.global_position).normalized()
	check(torch.light_energy > 0.0 and rad_to_deg(at_them.angle_to(-torch.global_basis.z)) < torch.spot_angle, "his torch coming on, and on them")
	await _frames(roundi(LightMission.CAUGHT_CATCH * 60.0))
	eq(torch.light_energy, Couple.TORCH_ENERGY, "on, by the time she comes")
	var walked := hs - RoadLayout.closest_s(hafiz.global_position)
	check(walked > 3.0, "coming up the road to them (%.1f m)" % walked)
	var meet := hafiz.global_position.distance_to(p.global_position)
	check(meet > 3.5 and meet < 4.5, "to about 4 m from him, in his phone light's reach (%.1f m)" % meet)
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
	var lamp := e.dropped_light
	var chest := hafiz.global_transform * Vector3(0.0, 1.2, 0.0)
	check(e.dropped.visible and lamp.light_energy > 0.0 and torch.light_energy == 0.0, "his phone falls from his hand, its torch on")
	check(absf(lamp.global_position.y - RoadLayout.point(RoadLayout.closest_s(lamp.global_position)).y) < 0.6, "on the road")
	var reach := maxf(lamp.global_position.distance_to(chest), lamp.global_position.distance_to(road.her.pool.global_position))
	check(reach < lamp.omni_range * 0.5, "lighting him and the pool (%.1f m)" % reach)
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
