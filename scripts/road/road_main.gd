class_name RoadMain
extends Node3D
## The road down the mountain, the first scene of the game: it ends by handing over to the flat (see Journey).
## The road's core (RoadDirector) runs the missions; this wires it to the HUD and steps it while he plays. The road
## itself is RoadBuilder's, in the core's fog; the walk and the car come later: for now he starts at the staff exit.

## The road is over. `ending` is how it went; Journey carries it into the flat.
signal finished(ending: StringName)

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

var director: RoadDirector
var builder: RoadBuilder
var look: Look
var pause: PauseMenu
var loaded := false  # the start card is ready to be clicked (tools wait for this)
var _automated := false


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
	var stage := RoadStage.new()
	stage.position = RoadLayout.EXIT
	director = RoadDirector.new(stage, Main.SEED)
	EventBus.choices_requested.connect(hud.show_choices)
	EventBus.choices_closed.connect(hud.close_choices)
	EventBus.road_cue.connect(_on_cue)
	EventBus.road_ended.connect(finish)
	# `-- --mission=N` / `?mission=N`: start at mission N (1 is the lift, and past the last is the last), as if every
	# earlier one was kept.
	var mission := Main.flag_value("mission")
	if mission.is_valid_int():
		director.start_at(clampi(int(mission) - 1, 0, director.missions.size() - 1))
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


func _physics_process(delta: float) -> void:
	# As in the flat: time and the choices' timers stand still on the start card and while paused (the pause menu
	# pauses the whole tree), so no rule can break then. They keep running while he reads something.
	if player.input_enabled or hud.is_inspecting():
		director.step(delta)


func _process(delta: float) -> void:
	builder.set_fog(director.fog)
	pause.guard(delta, _playing(), OS.has_feature("web"))


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
