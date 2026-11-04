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
var silhouette: Silhouette
var ready_msec := 0  # engine start to the condo built, for the perf report
var _had_capture := false
var _automated := false


func _ready() -> void:
	WorldState.reset()
	ApartmentLayout.apply_initial_state()
	builder = ApartmentBuilder.new()
	builder.name = "Apartment"
	add_child(builder)
	audio = AudioDirector.new()
	audio.name = "Audio"
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
	var overlay := DebugOverlay.new()
	overlay.runtime = runtime
	add_child(overlay)
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	hud.bind(player)
	hud.started.connect(_on_started)
	EventBus.ending_reached.connect(_on_ending)
	ready_msec = Time.get_ticks_msec()
	_finish_loading.call_deferred()


func _finish_loading() -> void:
	if DisplayServer.get_name() != "headless":  # nothing is drawn headless (tests), so nothing to compile
		await _compile_shaders()
	hud.allow_start()
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
	for room: StringName in ApartmentLayout.APARTMENT_ROOMS + [&"corridor"]:
		for i in 4:
			cam.global_position = ApartmentLayout.room_center(room) + Vector3(0, 1.6, 0)
			cam.rotation.y = i * PI / 2
			for state: Array in [[true, false], [false, true], [true, true]]:  # ceiling lights, phone light
				for l: Light3D in lights:
					l.visible = state[0]
				phone.visible = state[1]
				await get_tree().process_frame
	for k in lights.size():
		(lights[k] as Light3D).visible = was_on[k]
	silhouette.warm_up(cam.global_position + cam.global_basis.z * -2.0 + Vector3.DOWN * 1.6)
	await get_tree().process_frame
	await get_tree().process_frame
	player.camera.make_current()
	cam.queue_free()


## Release checks: `-- --smoke` / `-- --perf` on desktop, `?smoke` / `?perf` on the web.
static func has_flag(flag: String) -> bool:
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("location.search", true)
		return query is String and (query as String).contains(flag)
	return OS.get_cmdline_user_args().has("--" + flag)


## Plays the first 3 seconds of a built game and reports whether the simulation runs.
func _smoke() -> void:
	_automated = true
	hud.start()
	await get_tree().create_timer(3.0).timeout
	var events := runtime.scheduler.events.size()
	var lights := builder.find_children("*", "OmniLight3D", true, false).filter(func(l: Node) -> bool: return l is RoomLight)
	var restored := get_viewport().get_camera_3d() == player.camera and lights.all(func(l: RoomLight) -> bool: return l.visible == WorldState.is_light_on(l.room_id))
	var ok := events == 7 and WorldState.time > 2.0 and runtime.story.beat == &"home" and restored  # 7 event definitions
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


func _process(_delta: float) -> void:
	# Browsers use Esc to leave pointer lock and Godot never sees the key, so on the web a lost capture
	# opens the pause menu. Only once capture was actually held: browsers grant it a moment after the click.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_had_capture = true
	elif _had_capture and player.input_enabled and not pause.is_open():
		_had_capture = false
		pause.open()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and player.input_enabled and not pause.is_open() and not _automated:
		pause.open()


func _on_started() -> void:
	runtime.start_story()


func _on_ending(_ending_id: StringName) -> void:
	player.input_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	# The HUD sees input first: Esc while reading closes the note instead.
	if event.is_action_pressed("pause") and player.input_enabled:
		pause.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # in case the browser refused the first request
