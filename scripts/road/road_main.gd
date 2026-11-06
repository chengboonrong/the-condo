class_name RoadMain
extends Node3D
## The road down the mountain, the first scene of the game: it ends by handing over to the flat (see Journey).
## The road's core (RoadDirector) runs the missions; this wires it to the HUD and steps it while he plays. The road
## itself is RoadBuilder's, in the core's fog. He starts at the staff exit; the couple's car (CarRig), with Hafiz and Mei
## in the front (Couple), follows the core's ride each frame, and he rides in its back seat once the core seats him.

## The road is over. `ending` is how it went; Journey carries it into the flat.
signal finished(ending: StringName)

## Where the car's sounds come from, in its own space (+X its left, +Z its front): the engine, the roof over his head,
## and Mei's door and its window, which are part of the body and never open.
const ENGINE := Vector3(0.0, 0.7, 1.5)
const ROOF := Vector3(0.4, 1.45, -0.6)
const MEI_DOOR := Vector3(0.86, 0.9, 0.3)
const MEI_WINDOW := Vector3(0.82, 1.15, 0.3)
const SHAKE := 0.012  # metres each way a thump on the roof shakes his view, at the most
const SHAKE_SECONDS := 0.35

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
var pause: PauseMenu
var loaded := false  # the start card is ready to be clicked (tools wait for this)
var _automated := false
var _signalling := false  # the dashboard indicator ticks: from the signal to the pull out
var _dead := false  # the car's engine has died (lights_dying), and it never starts again
var _quiet := false  # the insects have stopped (insects_stop)
var _shake := 0.0  # seconds left of a thump's shake


func _ready() -> void:
	if Main.has_flag("flat") or Main.has_flag("perf"):  # checks of the flat alone: straight to its own start card
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
	add_child(her)
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
	_finish_loading.call_deferred()


func _finish_loading() -> void:
	loaded = true
	hud.allow_start()
	if Main.has_flag("smoke"):
		_smoke()


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
			EventBus.sound_requested.emit(&"rev", player.camera.global_position, -2.0)
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
			_sound(&"engine_sputter", ENGINE, -2.0)
		&"crank":
			_sound(&"starter_crank", ENGINE, -2.0)
		&"hafiz_leaves":
			couple.hafiz_leaves()
		&"door_cracked":
			car.crack_door()
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
			_sound(&"thump_roof", ROOF, 0.0)  # no louder than the flat's knock, and louder than the knock on the glass
			_shake = SHAKE_SECONDS
		&"her_on_roof":
			her.on_roof(car)
		&"knock_window":
			_sound(&"knock_glass", MEI_WINDOW, 0.0)
		&"light_on":
			builder.show_light(director.light_s)
			her.hide_her()


## One of the car's sounds, from `at` in the car's own space.
func _sound(id: StringName, at: Vector3, volume_db: float) -> void:
	EventBus.sound_requested.emit(id, car.global_transform * at, volume_db)


func _physics_process(delta: float) -> void:
	# As in the flat: time and the choices' timers stand still on the start card and while paused (the pause menu
	# pauses the whole tree), so no rule can break then. They keep running while he reads something.
	if player.input_enabled or hud.is_inspecting():
		director.step(delta)


func _process(delta: float) -> void:
	builder.set_fog(director.fog)
	_ride()
	_shake_view(delta)
	pause.guard(delta, _playing(), OS.has_feature("web"))


## A thump on the roof jolts his view while he sits, a little and briefly (less with less head bob), and it settles.
func _shake_view(delta: float) -> void:
	if _shake <= 0.0 or not player.is_seated():
		return
	_shake = maxf(_shake - delta, 0.0)
	var k := SHAKE * _shake / SHAKE_SECONDS * float(Settings.get_value("head_bob"))
	player.camera.position = Vector3(sin(_shake * 90.0), sin(_shake * 70.0 + 1.3), 0.0) * k


## The car, the slow car, his seat and the ride's loops follow the core. The car stands out of sight up the road,
## hidden and not solid, until it comes for him; it is solid only standing still or with him in it (CarRig.set_solid).
## The engine's pitch follows the car's speed; outside, it fades with distance, as does the slow car's old engine from
## 10 m.
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
			player.stand(car.global_transform.translated_local(Vector3(1.5, 0.0, -0.5)).rotated_local(Vector3.UP, PI))
		car.door_rear_left.object_id = &"car_door_inside" if director.seated else &"car_door"
	var inside := player.is_seated()
	var away := 0.0 if inside else linear_to_db(1.0 / maxf(player.camera.global_position.distance_to(car.global_position), 1.0))
	audio.set_loop(&"engine_loop", shown and not _dead, -12.0 + away, lerpf(0.7, 1.6, clampf(director.car_speed / 15.0, 0.0, 1.0)))
	audio.set_loop(&"insects_loop", not _quiet, -12.0 if inside else -6.0)  # the windows are up
	var slow_away := player.camera.global_position.distance_to(slow_car.global_position)
	audio.set_loop(&"old_engine_loop", slow_car.visible and slow_car.speed > 0.0, -12.0 + linear_to_db(1.0 / maxf(slow_away / 10.0, 1.0)),
		lerpf(0.6, 1.0, slow_car.speed / SlowCarMission.SLOW_SPEED))
	if is_nan(director.slow_gap):
		_signalling = false  # the slow car is gone, by the lay-by or a skip: so is the indicator
	audio.set_loop(&"indicator", _signalling, 0.0)


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
