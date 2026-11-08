class_name RoadMain
extends Node3D
## The road down the mountain, the first scene of the game: it ends by handing over to the flat (see Journey).
## The road's core (RoadDirector) runs the missions; this wires it to the HUD and steps it while he plays. The road
## itself is RoadBuilder's, in the core's fog. He starts at the staff exit; the couple's car (CarRig), with Hafiz and Mei
## in the front (Couple), follows the core's ride each frame, and he rides in its back seat once the core seats him.
## The road's end, the fruit stall at the light and its endings, is Endings'.

## The road is over. `ending` is how it went; Journey carries it into the flat.
signal finished(ending: StringName)

## Where the car's sounds come from, in its own space (+X its left, +Z its front): the engine, the roof over his head,
## and Mei's door and its window, which are part of the body and never open.
const ENGINE := Vector3(0.0, 0.7, 1.5)
const ROOF := Vector3(0.4, 1.45, -0.6)
const MEI_DOOR := Vector3(0.86, 0.9, 0.3)
const MEI_WINDOW := Vector3(0.82, 1.15, 0.3)
## The road's sounds that carry a moment, captioned as the flat's are: [text, seconds] by cue, on subtitle_requested,
## which the HUD shows only with "Captions for sounds" on. The knocks come as one set: one caption. So do the thumps,
## but for THUMP_AGAIN. Every overtake has the engine roar: the rev, each time.
const CAPTIONS := {
	&"lorry_passes": ["[A lorry passes]", 3.0],
	&"lights_dying": ["[The engine sputters out]", 3.0],
	&"crank": ["[The engine cranks and dies]", 2.5],
	&"door_cracked": ["[Your door opens. A wet slap, and it slams shut]", 3.0],
	&"doors_locked": ["[The doors lock]", 2.0],
	&"mei_door_cracked": ["[Mei's door opens. A wet slap, and it slams shut]", 3.0],
	&"thump": ["[Something lands on the roof]", 3.0],
	&"knock_window": ["[Knocking on Mei's window]", 3.0],
	&"lorry_stops": ["[A lorry pulls up]", 4.0],
	&"overtake": ["[The engine roars.]", 2.5],
}
## What each thump after the first is captioned as: the first landed, and now it moves about up there.
const THUMP_AGAIN := ["[It moves on the roof.]", 2.5]
const ONE_SET: Array[StringName] = [&"thump", &"knock_window"]
const SHAKE := 0.012  # metres each way a thump on the roof shakes his view, at the most
const SHAKE_SECONDS := 0.35
## The engine loop drops by this many dB from the indicator to the end of the rev: Hafiz eases off, signals, then floors
## it. It eases down over 0.3 s and back up over 0.5 s; the second before the rev is what it is heard over, so the drop
## is in place by then (the indicator starts 2.5 s before it).
const ROAR_DUCK := 6.0
## The wind's play levels (its file is -24 dB): heard at -48 dB outside and 6 dB lower in the car, where the windows
## are up, as the insects are. It blows all night, under the insects and on when they stop.
const WIND_DB_OUT := -24.0
const WIND_DB_IN := -30.0
## The warm-up's board (_compile_shaders), far above the road where none of its lights reach: BOARD_AWAY in front of a
## camera of its own, a grid COLUMNS wide of CELL squares, each holding a copy turned by TILT so that a flat one (a
## plane faces up) still shows. The mirror's camera looks at it from MIRROR_BACK further back, where its narrow picture
## takes in the whole board.
const WARM_AT := Vector3(0.0, 300.0, 0.0)
const BOARD_AWAY := 2.5
const CELL := 0.15
const COLUMNS := 16
const TILT := Vector3(0.5, 0.6, 0.0)
const MIRROR_BACK := 6.0
const PICTURE_LAYER := 1 << 19  # in the warm-up only: a picture of a viewport, which the mirror's camera leaves out
## The warm-up's light states, one frame each: bit 1 the omni light, 2 the spot, 4 the phone light. The phone light's
## first, then without it, then with it again: the renderer binds the phone light's shadow map only for its own pass
## and leaves it bound after, and the driver seems to compile a shader again when what is bound with it differs. Measured
## on the perf route (M1 Max, desktop): with the phone light's states last only, the slow car's first sight cost about
## 70 ms and the mirror's first frame about 60 ms; with them first only, the phone light in the walk cost 128 ms; first
## and last, no frame over 25 ms.
const LIGHT_STATES: Array[int] = [4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 6, 7]

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

var director: RoadDirector
var builder: RoadBuilder
var look: Look
var car: CarRig
var couple: Couple
var lorry: Lorry
var slow_car: SlowCar
var audio: RoadAudio
var her: Penanggal
var endings: Endings
var pause: PauseMenu
var loaded := false  # the shader warm-up is done and the start card can be clicked (tools wait for this)
var ready_msec := 0  # engine start to the road built, for the perf report
var _automated := false
var _warmed := {}  # the renderer's RID of each material the warm-up drew -> true
var _signalling := false  # the dashboard indicator ticks: from the signal to the pull out
var _dead := false  # the car's engine has died (lights_dying), and it never starts again
var _quiet := false  # the insects have stopped (insects_stop)
var _shake := 0.0  # seconds left of a thump's shake
var _roar := 0.0  # seconds left of the overtake's rev, which the engine loop ducks under (ROAR_DUCK)
var _duck := 0.0  # dB the engine loop is ducked by now, on its way to ROAR_DUCK or back to 0
var _at_light := false  # the walk to the light (LightMission) is the core's mission
var _captioned: Array[StringName] = []  # the sets (ONE_SET) captioned already


func _ready() -> void:
	if Main.has_flag("flat"):  # checks of the flat alone: straight to its own start card
		process_mode = Node.PROCESS_MODE_DISABLED  # nothing is built, so nothing runs until the flat replaces it
		Journey.arrive(&"")
		return
	WorldState.reset()
	builder = RoadBuilder.new()
	builder.name = "RoadBuilder"
	add_child(builder)
	player.global_position = RoadLayout.EXIT
	player.set_look(RoadBuilder.yaw_along(RoadLayout.closest_s(RoadLayout.EXIT)))
	car = CarRig.new()
	car.name = "Car"
	add_child(car)
	car.mirror.use_environment(builder.environment)
	couple = Couple.new(car)
	car.add_child(couple)
	lorry = Lorry.new()
	lorry.name = "Lorry"
	lorry.yields_to.assign([player, couple.mei_out, couple.hafiz_out])
	add_child(lorry)
	slow_car = SlowCar.new()
	slow_car.name = "SlowCar"
	add_child(slow_car)
	audio = RoadAudio.new()
	audio.name = "Audio"
	add_child(audio)
	director = RoadDirector.new(RoadGameStage.new(player, car), Main.SEED)
	her = Penanggal.new()
	her.name = "Her"
	her.director = director
	her.builder = builder
	her.audio = audio
	add_child(her)
	endings = Endings.new()
	endings.name = "Endings"
	endings.director = director
	endings.builder = builder
	endings.couple = couple
	endings.her = her
	endings.lorry = lorry
	endings.audio = audio
	endings.hud = hud
	endings.player = player
	add_child(endings)
	EventBus.choices_requested.connect(hud.show_choices)
	EventBus.choices_closed.connect(hud.close_choices)
	EventBus.road_cue.connect(_on_cue)
	EventBus.road_ended.connect(finish)
	# `-- --mission=N` / `?mission=N`: start at mission N (1 is the lift, and past the last is the last), as if every
	# earlier one was kept. Without it, mission 1: the car and his seat are then where the road starts them, even on
	# the start card, before the first mission begins.
	var mission := Main.flag_value("mission")
	director.start_at(clampi(int(mission) - 1, 0, director.missions.size() - 1) if mission.is_valid_int() else 0)
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	hud.bind(player)
	look = Look.new()
	look.name = "Look"
	look.environment = builder.environment
	look.film = hud.film_material
	look.grade_override = &"road"
	add_child(look)
	ready_msec = Time.get_ticks_msec()
	_finish_loading.call_deferred()


## Headless too, unlike the flat's: nothing is drawn there, but what would be is known, and the tests check it.
func _finish_loading() -> void:
	await _compile_shaders()
	loaded = true
	hud.allow_start()
	if Main.has_flag("smoke"):
		_smoke()
	elif Main.has_flag("perf"):
		_automated = true
		var route := RoadPerf.new()
		route.director = director
		route.her = her
		route.hud = hud
		route.player = player
		route.scene_ready_msec = ready_msec
		route.reported.connect(finish.bind(&"caught"))  # the ending it plays
		add_child(route)


## Behind the start card, as the flat does (Main._compile_shaders): a copy of each kind of thing the road draws, every
## mesh, multimesh and sign's line with its own materials, shown in play or hidden till later, her in the mirror
## included, is drawn on a board in front of a camera of its own under every mix of the road's lights, so that nothing
## compiles a shader mid-game. In this renderer a light changes the shaders by its kind and by whether it casts a
## shadow, not by which light it is, so three stand in for them all: an omni light for the sodium lamps, the tunnel's,
## her fill in the mirror, her own at the look-back and the endings' bulb, ring light and fallen phone; an unshadowed
## spot for the headlights, the dash, Mei's screen, Hafiz's torch and the lorry's lamps; and a copy of his phone light,
## the one with a shadow.
## The mirror's camera draws the board each time too: its picture is drawn without shadow maps and with a pass after
## the scene of its own (Mirror.use_environment). The order of the light states (LIGHT_STATES) matters as much as the
## states.
func _compile_shaders() -> void:
	var cam := Camera3D.new()
	cam.far = BOARD_AWAY * 4.0
	add_child(cam)
	cam.global_position = WARM_AT
	cam.make_current()
	var omni := OmniLight3D.new()
	var spot := SpotLight3D.new()
	var phone := player.phone_light.duplicate() as SpotLight3D
	omni.omni_range = BOARD_AWAY * 3.0
	for light: SpotLight3D in [spot, phone]:
		light.spot_angle = 45.0  # the whole board
		light.spot_range = BOARD_AWAY * 3.0
	for light: Light3D in [omni, spot, phone]:
		cam.add_child(light)
	var copies: Array[GeometryInstance3D] = []
	var boxes: Array[AABB] = []
	var kinds := {}
	for g: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		var materials := _materials_of(g)
		var kind := "%s %d %s" % [g.get_class(), g.cast_shadow, materials]
		if kinds.has(kind):
			continue
		kinds[kind] = true
		copies.append(_copy(g))
		boxes.append(g.get_aabb())
		for m: RID in materials:
			_warmed[m] = true
	var board := Node3D.new()
	add_child(board)
	board.global_position = WARM_AT + Vector3.FORWARD * BOARD_AWAY
	var rows := ceili(copies.size() / float(COLUMNS))
	for n in copies.size():
		var basis := Basis.from_euler(TILT) * (CELL * 0.9 / maxf(boxes[n].get_longest_axis_size(), 0.001))
		var at := Vector3((n % COLUMNS - (COLUMNS - 1) * 0.5) * CELL, ((rows - 1) * 0.5 - n / COLUMNS) * CELL, 0.0)
		copies[n].transform = Transform3D(basis, at - basis * boxes[n].get_center())
		board.add_child(copies[n])
	var mirror := car.mirror
	var mask := mirror.camera.cull_mask
	mirror.camera.cull_mask = mask & ~PICTURE_LAYER
	mirror.camera.global_transform = cam.global_transform.translated(Vector3.BACK * MIRROR_BACK)
	mirror.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for state in LIGHT_STATES:
		omni.visible = state & 1 != 0
		spot.visible = state & 2 != 0
		phone.visible = state & 4 != 0
		await get_tree().process_frame
	mirror.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED  # the mirror is off until Mission 3
	mirror.camera.cull_mask = mask
	board.queue_free()
	player.camera.make_current()
	cam.queue_free()


## The renderer's RID of each material the warm-up drew (_compile_shaders): of every surface of everything under the
## road, hidden or not.
func warmed_materials() -> Dictionary:
	return _warmed


## The renderer's RID of each material `g` draws with: a mesh's surfaces' (whatever overrides them), a multimesh's, the
## one a sign's line (Label3D) makes for itself, and an overlay.
static func _materials_of(g: GeometryInstance3D) -> Array[RID]:
	var out: Array[RID] = []
	if g is MeshInstance3D:
		var m := g as MeshInstance3D
		for i in m.get_surface_override_material_count():
			if m.get_active_material(i) != null:
				out.append(m.get_active_material(i).get_rid())
	elif g is MultiMeshInstance3D:
		var mesh := (g as MultiMeshInstance3D).multimesh.mesh
		for i in mesh.get_surface_count():
			var mat := g.material_override if g.material_override != null else mesh.surface_get_material(i)
			if mat != null:
				out.append(mat.get_rid())
	elif g is Label3D:
		for i in RenderingServer.mesh_get_surface_count(g.get_base()):
			out.append(RenderingServer.mesh_surface_get_material(g.get_base(), i))
	else:
		push_error("the warm-up does not know a %s (%s)" % [g.get_class(), g.name])
	if g.material_overlay != null:
		out.append(g.material_overlay.get_rid())
	return out


## A copy of `g`, shown, that draws as it does: the same mesh (or multimesh, which draws with a shader of its own) and
## materials, shadow and layers, without what hangs under it. A sign's line is duplicated, and makes its own material
## as the original did. A picture of a viewport (the mirror's glass) goes on PICTURE_LAYER, out of the mirror's sight:
## drawn into its own viewport it would read the texture it writes, which WebGL refuses.
static func _copy(g: GeometryInstance3D) -> GeometryInstance3D:
	var copy: GeometryInstance3D
	if g is MeshInstance3D:
		var m := MeshInstance3D.new()
		m.mesh = (g as MeshInstance3D).mesh
		for i in m.get_surface_override_material_count():
			m.set_surface_override_material(i, (g as MeshInstance3D).get_surface_override_material(i))
		copy = m
	elif g is MultiMeshInstance3D:
		copy = MultiMeshInstance3D.new()
		(copy as MultiMeshInstance3D).multimesh = (g as MultiMeshInstance3D).multimesh
	else:
		copy = g.duplicate(0)
	copy.visible = true
	copy.material_override = g.material_override
	copy.material_overlay = g.material_overlay
	copy.cast_shadow = g.cast_shadow
	copy.transparency = g.transparency
	copy.layers = g.layers
	var picture := g.material_override as BaseMaterial3D
	if picture != null and picture.albedo_texture is ViewportTexture:
		copy.layers = PICTURE_LAYER
	return copy


## `-- --smoke` / `?smoke`: the road starts at once and runs 3 s, then hands over to the flat. The flag carries
## over, so the flat's own SMOKE line follows. A failed road stops here.
func _smoke() -> void:
	_automated = true
	hud.start()
	await get_tree().create_timer(3.0).timeout
	var ok := loaded and player.input_enabled and get_viewport().get_camera_3d() == player.camera and WorldState.time > 2.0
	print("ROAD-SMOKE %s time=%.1f gpu=%s" % ["ok" if ok else "FAIL", WorldState.time, RenderingServer.get_video_adapter_name()])
	if ok:
		finish(&"alive")
	elif not OS.has_feature("web"):
		get_tree().quit(1)


func finish(ending: StringName) -> void:
	finished.emit(ending)
	Journey.arrive(ending)


func _on_cue(cue: StringName) -> void:
	if CAPTIONS.has(cue) and not _captioned.has(cue):
		EventBus.subtitle_requested.emit(CAPTIONS[cue][0], CAPTIONS[cue][1])
		if ONE_SET.has(cue):
			_captioned.append(cue)
	elif cue == &"thump":  # one already captioned
		EventBus.subtitle_requested.emit(THUMP_AGAIN[0], THUMP_AGAIN[1])
	match cue:
		&"card_on":
			hud.show_card("")
		&"card_off":
			hud.hide_card(1.0)
		&"seated":
			car.swing_door()
		&"lorry_passes":
			lorry.pass_by()
			EventBus.sound_requested.emit(&"lorry_pass", player.camera.global_position, 0.0)  # its pass is in the file
		&"indicator":
			_signalling = true
		&"overtake":
			_signalling = false
			_roar = (RoadAudio.SOUNDS[&"rev"] as AudioStream).get_length()
			audio.play_here(&"rev", 0.0)  # in his head: a pool player would stay put as the car pulls out
		&"slow_car_gone":
			slow_car.pull_in()
		&"mirror_on":
			car.mirror.set_on(true)
		&"mirror_off":
			car.mirror.set_on(false)
		&"fourth_glimpse":
			car.mirror.glimpse()  # no sting: he only sees her
		&"fourth_gone":
			car.mirror.empty()
		&"her_glimpse":
			her.show_glimpse()
		&"lights_dying":
			_dead = true
			car.lights_dying()
			audio.play_here(&"engine_sputter", 0.0)  # in his head: a pool player would stay put as the car rolls on
		&"crank":
			_sound(&"starter_crank", ENGINE, -2.0)
		&"hafiz_leaves":
			couple.hafiz_leaves()
		&"door_cracked":
			car.crack_door()
		&"doors_locked":  # a short clunk at the lock, under the door's: it is within a metre of his head
			_sound(&"car_door_close", car.lock.position, -14.0)
		&"mei_reaches_door":
			couple.mei_faces(&"door")
		&"mei_door_cracked":  # her door opens a little and is slapped shut: heard, as it never moves
			_sound(&"car_door_open", MEI_DOOR, 0.0)
			var slap := create_tween()
			slap.tween_interval(0.65)
			slap.tween_callback(func() -> void:
				_sound(&"wet_flap", MEI_DOOR, 0.0)
				_sound(&"car_door_close", MEI_DOOR, 0.0))
		&"insects_stop":
			_quiet = true
		&"thump":
			# Within about 1 m of his head the +3 dB max_db cap applies after the play level, so as heard it is the
			# file (-18.5) + 3 = -15.5 dB, under the door knock's -14.6 (the window knock is heard at -16.0).
			_sound(&"thump_roof", ROOF, 0.0)
			_shake = SHAKE_SECONDS
		&"her_on_roof":
			her.on_roof(car)
		&"knock_window":
			_sound(&"knock_glass", MEI_WINDOW, 0.0)
		&"light_on":
			couple.mei_faces(&"ahead")  # she leans in to see it, and he sees it past her (Endings lights it)
			her.hide_her()
		&"get_out":  # his door, and Mei's on her side, heard: it is part of the body and never opens
			car.swing_door()
			couple.walk_beside(player)
			var out := create_tween()
			out.tween_interval(0.3)
			out.tween_callback(_sound.bind(&"car_door_open", MEI_DOOR, 0.0))
			out.tween_interval(1.2)
			out.tween_callback(_sound.bind(&"car_door_close", MEI_DOOR, 0.0))
		&"her_behind":
			her.behind(player)
		&"her_lunges":  # he looked back on the walk, and it counted
			her.lunge(player.camera)
		&"mei_looks":
			couple.mei_looks_back()


## One of the car's sounds, from `at` in the car's own space.
func _sound(id: StringName, at: Vector3, volume_db: float) -> void:
	EventBus.sound_requested.emit(id, car.global_transform * at, volume_db)


func _physics_process(delta: float) -> void:
	to_the_light()
	# As in the flat: time and the choices' timers stand still on the start card and while paused (the pause menu
	# pauses the whole tree), so no rule can break then. They keep running while he reads something.
	if player.input_enabled or hud.is_inspecting():
		director.step(delta)


func _process(delta: float) -> void:
	builder.set_fog(director.fog)
	_roar = maxf(_roar - delta, 0.0)
	var duck := ROAR_DUCK if _signalling or _roar > 0.0 else 0.0
	_duck = move_toward(_duck, duck, delta * ROAR_DUCK / (0.3 if duck > _duck else 0.5))  # down in 0.3 s, up in 0.5 s
	_ride()
	_shake_view(delta)
	pause.guard(delta, _playing(), OS.has_feature("web"))


## The walk to the light has become the core's mission, by Mission 4 ending or by a skip (`--mission=5`, F10): what
## Mission 4 left is set, before the walk begins. The car is dead and dark, the insects quiet, Hafiz gone and the light
## on; she is off the roof (the walk puts her behind them); Mei's next line has no pose left over from her door. If the
## skip has him on his feet, he stands beside his door with Mei beside him.
func to_the_light() -> void:
	var at_light := director.mission_index < director.missions.size() and director.missions[director.mission_index] is LightMission
	if at_light and not _at_light:
		_dead = true
		_quiet = true
		car.lights_dead()
		couple.hafiz_gone()
		couple.mei_faces(&"him")
		her.hide_her()
		if not builder.far_light.visible:
			endings.light(true)
		if not director.seated:
			if not player.is_seated():
				car.place(director.car_s, director.lane)
				player.stand(beside_door())
			couple.walk_beside(player)
	_at_light = at_light


## Beside his door, facing the way the car faces: where he stands when he gets out.
func beside_door() -> Transform3D:
	return car.global_transform.translated_local(Vector3(1.5, 0.0, -0.5)).rotated_local(Vector3.UP, PI)


## A thump on the roof jolts his view while he sits, a little and briefly (less with less head bob), and it settles.
func _shake_view(delta: float) -> void:
	if _shake <= 0.0 or not player.is_seated():
		return
	_shake = maxf(_shake - delta, 0.0)
	var k := SHAKE * _shake / SHAKE_SECONDS * float(Settings.get_value("head_bob"))
	player.camera.position = Vector3(sin(_shake * 90.0), sin(_shake * 70.0 + 1.3), 0.0) * k


## The car, the slow car, his seat and the ride's loops follow the core. The car stands out of sight up the road,
## hidden and not solid, until it comes for him; it is solid only standing still or with him in it (CarRig.set_solid).
## The engine's pitch follows the car's speed (a recording, at its own speed at the 9 m/s cruise); outside, it fades
## with distance, as does the slow car's old engine from 10 m. The engine ducks under the overtake's rev (ROAR_DUCK), and
## the wind blows all the while.
func _ride() -> void:
	var shown := director.seated or director.car_speed > 0.0 or director.car_s > LiftMission.CAR_FROM
	car.visible = shown
	car.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	car.place(director.car_s, director.lane)
	car.set_solid(director.car_speed == 0.0, player.is_seated(), player.global_position)
	slow_car.place(director.car_s, director.slow_gap)
	if director.seated != player.is_seated():
		if director.seated:
			player.sit(car.seat_rear_left)
		else:  # beside his door, facing the way the car faces
			player.stand(beside_door())
		car.door_rear_left.object_id = &"car_door_inside" if director.seated else &"car_door"
	var inside := player.is_seated()
	var away := 0.0 if inside else linear_to_db(1.0 / maxf(player.camera.global_position.distance_to(car.global_position), 1.0))
	audio.set_loop(&"engine_loop", shown and not _dead, -13.5 + away - _duck, lerpf(0.78, 1.12, clampf(director.car_speed / 14.0, 0.0, 1.0)))
	audio.set_loop(&"insects_loop", not _quiet, -12.0 if inside else -6.0)  # the windows are up
	audio.set_loop(&"wind_loop", true, WIND_DB_IN if inside else WIND_DB_OUT)
	var slow_away := player.camera.global_position.distance_to(slow_car.global_position)
	audio.set_loop(&"old_engine_loop", slow_car.visible and slow_car.speed > 0.0, -12.0 + linear_to_db(1.0 / maxf(slow_away / 10.0, 1.0)),
		lerpf(0.85, 1.0, slow_car.speed / SlowCarMission.SLOW_SPEED))
	if is_nan(director.slow_gap):
		_signalling = false  # the slow car is gone, by the lay-by or a skip: so is the indicator
	audio.set_loop(&"indicator", _signalling, -5.0)  # under the rev's roar: with the engine ducked it was most of its bed


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and pause != null:
		pause.focus_lost(_playing())


## In the world: moving, or holding still to read a note or look through the peephole (time keeps running behind them).
func _playing() -> bool:
	return (player.input_enabled or hud.is_inspecting()) and not _automated


func _unhandled_input(event: InputEvent) -> void:
	# The HUD sees input first: Esc while reading closes the note instead.
	if event.is_action_pressed("pause") and (player.input_enabled or hud.is_on_start_card()):
		pause.open(player.input_enabled)  # from the start card: settings (reduced flashing) before playing
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event.is_action_pressed("debug_skip_beat"):
		director.debug_skip()  # F10, as in the flat: the current mission is over, as if kept
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # in case the browser refused the first request
