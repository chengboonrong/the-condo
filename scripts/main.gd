class_name Main
extends Node3D
## Composition root: builds the condo, places the player, wires presentation to the simulation.

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

## Fixed for now so runs are reproducible; the story/settings choose it later.
const SEED := 1147

var builder: ApartmentBuilder
var audio: AudioDirector
var runtime: HorrorRuntime
var pause: PauseMenu
var look: Look
var silhouette: Silhouette
var her: Penanggal  # comes for him when he dies; hidden, and without a road
var ready_msec := 0  # engine start to the condo built, for the perf report
var loaded := false  # the shader warm-up is done and the player's camera is back (tools wait for this)
var _automated := false


func _ready() -> void:
	if not Journey.flat_retry.is_empty():  # Try again: a plain black card until the flat is built
		hud.show_card("")
	elif Journey.road_ending != &"":  # he has come down from the road: a black card until the flat is built
		hud.show_card("11:47 PM")
	WorldState.reset()
	ApartmentLayout.apply_initial_state()
	builder = ApartmentBuilder.new()
	builder.name = "Apartment"
	add_child(builder)
	# Developer flag for perf runs. It writes Settings.values, so if any setting is saved during the run,
	# filter=false is saved with it.
	if has_flag("nofilter"):
		Settings.values["filter"] = false
	audio = AudioDirector.new()
	audio.name = "Audio"
	audio.builder = builder
	add_child(audio)
	player.global_position = ApartmentLayout.SPAWN
	player.set_look(ApartmentLayout.SPAWN_YAW)
	var stage := GameStage.new(RoomGraph.new(WorldState.variants), player)
	runtime = HorrorRuntime.new()
	runtime.name = "Horror"
	add_child(runtime)
	runtime.setup(stage, SEED)
	silhouette = Silhouette.new()
	silhouette.stage = stage
	add_child(silhouette)
	her = Penanggal.new()
	her.name = "Her"
	add_child(her)
	var overlay := DebugOverlay.new()
	overlay.runtime = runtime
	add_child(overlay)
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	hud.bind(player)
	look = Look.new()
	look.name = "Look"
	look.environment = builder.environment
	look.film = hud.film_material
	add_child(look)
	hud.started.connect(_on_started)
	EventBus.ending_reached.connect(_on_ending)
	EventBus.player_died.connect(_on_died)
	her.reached.connect(_on_her_reached)
	hud.retry_pressed.connect(_on_retry, CONNECT_ONE_SHOT)  # a second press would reload again
	ready_msec = Time.get_ticks_msec()
	_finish_loading.call_deferred()


func _finish_loading() -> void:
	if DisplayServer.get_name() != "headless":  # nothing is drawn headless (tests), so nothing to compile
		await _compile_shaders()
	loaded = true
	hud.allow_start()
	if not Journey.flat_retry.is_empty():  # Try again: no start card, and the act begins again where its lines say he is
		var start: Dictionary = ApartmentLayout.ACT_STARTS[Journey.flat_retry["act"]]
		player.global_position = start["pos"]
		player.set_look(start["yaw"])
		WorldState.set_player_room(ApartmentLayout.room_at(start["pos"], Journey.flat_retry["variants"]))
		hud.start()  # the story starts with it
		runtime.story.start_at_act(Journey.flat_retry)
		Journey.flat_retry = {}
		hud.hide_card(1.0)
	elif Journey.road_ending != &"":  # no start card: he was already playing, and wakes at 11:47
		hud.start()
		hud.hide_card(1.5)
	if has_flag("smoke"):
		_smoke()
	elif has_flag("perf"):
		_automated = true
		var probe := PerfProbe.new()
		probe.hud = hud
		probe.player = player
		probe.runtime = runtime
		probe.scene_ready_msec = ready_msec
		add_child(probe)


## Behind the start card, looks around every room with the ceiling lights on, off and with the phone light,
## so the renderer compiles every shader variant now instead of mid-game: the first silhouette, the first
## flicker and the first phone light each cost a 30–110 ms hitch on an M1 Max otherwise.
func _compile_shaders() -> void:
	var cam := Camera3D.new()
	var phone := player.phone_light.duplicate() as SpotLight3D  # same light, but where this camera looks
	cam.add_child(phone)
	add_child(cam)
	cam.make_current()
	var lights := builder.find_children("*", "OmniLight3D", true, false)
	var was_on := lights.map(func(l: Light3D) -> bool: return l.visible)
	builder.warm_up_models()  # every model, whatever its variant
	for room: StringName in ApartmentLayout.APARTMENT_ROOMS + [&"corridor"]:
		for i in 4:
			cam.global_position = ApartmentLayout.room_center(room) + Vector3(0, 1.6, 0)
			cam.rotation.y = i * PI / 2
			for state: Array in [[true, false], [false, true], [true, true]]:  # ceiling lights, phone light
				for l: Light3D in lights:
					l.visible = state[0]
				phone.visible = state[1]
				await get_tree().process_frame
	# The figure's materials are its own, and a shadowed light on it is a variant of its own: show it under each
	# light it can be met with. Drawn only with the phone light on it, its first sight by a ceiling light alone cost
	# 44–107 ms on an M1 Max. Her skin is her own too, and she comes for him in whatever light he dies in.
	for state: Array in [[true, false], [false, true], [true, true], [false, false]]:
		for l: Light3D in lights:
			l.visible = state[0]
		phone.visible = state[1]
		silhouette.warm_up(cam.global_position + cam.global_basis.z * -2.0 + Vector3.DOWN * 1.6)
		her.global_position = cam.global_position + cam.global_basis.z * -2.0  # her origin is her skull's centre
		her.visible = true
		await get_tree().process_frame
	her.hide_her()
	hud.set_lens(true)  # the peephole's lens, behind the start card, so its first look does not compile it
	await get_tree().process_frame
	hud.set_lens(false)
	for k in lights.size():
		(lights[k] as Light3D).visible = was_on[k]
	builder.refresh_variants()
	await get_tree().process_frame
	await get_tree().process_frame
	player.camera.make_current()
	cam.queue_free()


## Release checks: `-- --smoke` / `-- --perf` / `-- --nofilter` on desktop, `?smoke` / `?perf` / `?nofilter` on the web.
static func has_flag(flag: String) -> bool:
	if OS.has_feature("web"):
		# A string, not a JS boolean: in Godot 4.7.2 web builds a boolean result never compared equal to true.
		return str(JavaScriptBridge.eval("String(new URLSearchParams(location.search).has('%s'))" % flag, true)) == "true"
	return OS.get_cmdline_user_args().has("--" + flag)


## A flag's value: `-- --mission=3` on desktop, `?mission=3` on the web. "" when it is not given.
static func flag_value(flag: String) -> String:
	if OS.has_feature("web"):
		return str(JavaScriptBridge.eval("String(new URLSearchParams(location.search).get('%s') ?? '')" % flag, true))
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % flag):
			return arg.trim_prefix("--%s=" % flag)
	return ""


## Plays the first 3 seconds of a built game and reports whether the simulation runs.
func _smoke() -> void:
	_automated = true
	hud.start()
	await get_tree().create_timer(3.0).timeout
	var events := runtime.scheduler.events.size()
	var lights := builder.find_children("*", "OmniLight3D", true, false).filter(func(l: Node) -> bool: return l is RoomLight)
	var restored := get_viewport().get_camera_3d() == player.camera and lights.all(func(l: RoomLight) -> bool: return l.visible == WorldState.is_light_on(l.room_id))
	var ok := events == 8 and WorldState.time > 2.0 and runtime.story.beat == &"home" and restored  # 8 event definitions
	var shot := ""
	if not OS.has_feature("web"):
		shot = ProjectSettings.globalize_path("user://smoke.png")
		get_viewport().get_texture().get_image().save_png(shot)
	print("SMOKE %s events=%d time=%.1f beat=%s warm-up-restored=%s gpu=%s %s" % ["ok" if ok else "FAIL", events, WorldState.time, runtime.story.beat, restored, RenderingServer.get_video_adapter_name(), shot])
	if not OS.has_feature("web"):
		get_tree().quit(0 if ok else 1)


func _physics_process(delta: float) -> void:
	WorldState.set_player_room(ApartmentLayout.room_at(player.global_position, WorldState.variants))
	# Time stands still on the start card and after the ending (and the pause menu pauses the whole
	# tree); it keeps running while the player reads something.
	if player.input_enabled or hud.is_inspecting():
		runtime.step(delta)


func _process(delta: float) -> void:
	pause.guard(delta, _playing(), OS.has_feature("web"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and pause != null:
		pause.focus_lost(_playing())


## In the world: moving, or holding still to read a note or look through the peephole (time keeps running behind them).
func _playing() -> bool:
	return (player.input_enabled or hud.is_inspecting()) and not _automated


func _on_started() -> void:
	runtime.start_story()


func _on_ending(_ending_id: StringName) -> void:
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## He died: out of the peephole or the note he was at, and held (nothing is left open for E or Esc to close, and the
## interaction stays off after what closing it turned on), and she comes for his face along a clear line, seen on the
## way: straight ahead of him if it is clear for Penanggal.MIN_START, else whichever of the four level ways round him is
## clearest, which his held view turns to. His view comes level either way. The card follows once she is there.
func _on_died(_cause: StringName) -> void:
	if hud.is_inspecting():
		hud.close_peephole()
	player.input_enabled = false
	player.interaction.set_deferred(&"enabled_input", false)
	var yaw := player.yaw
	var run := _clear_run(yaw)
	if run - Penanggal.SHORT < Penanggal.MIN_START:
		for k in range(1, 4):
			if _clear_run(player.yaw + k * PI / 2.0) > run:
				run = _clear_run(player.yaw + k * PI / 2.0)
				yaw = player.yaw + k * PI / 2.0
	player.turn_to(yaw, 0.0, Penanggal.TURN)
	var start := clampf(run - Penanggal.SHORT, Penanggal.CLOSE, Penanggal.AHEAD)
	her.come_for(player.camera, player.camera.global_position + _level(yaw) * start)


## Metres from his eyes along the level way `yaw` faces to the first solid thing in it; INF if nothing is within
## Penanggal.AHEAD.
func _clear_run(yaw: float) -> float:
	var eye := player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + _level(yaw) * Penanggal.AHEAD)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
	return eye.distance_to(hit["position"]) if not hit.is_empty() else INF


## The level way he faces at `yaw` (PlayerController.set_look's).
static func _level(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func _on_her_reached() -> void:
	if runtime.dead != &"":
		hud.show_card("")
		hud.show_game_over(Journey.DEATHS[runtime.dead])
		her.hide_her()  # in her come_for she wet-flaps every second, point blank, under the card
		audio.silence()


## The scene is freed by the change. The pointer lock is asked for here, inside the click: Safari grants it to a gesture
## only, and the new scene's own request comes after its warm-up.
func _on_retry() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Journey.retry_flat(runtime.story.act_snapshot)


func _unhandled_input(event: InputEvent) -> void:
	# The HUD sees input first: Esc while reading closes the note instead.
	if event.is_action_pressed("pause") and (player.input_enabled or hud.is_on_start_card()):
		pause.open(player.input_enabled)  # from the start card: settings (reduced flashing) before playing
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # in case the browser refused the first request
