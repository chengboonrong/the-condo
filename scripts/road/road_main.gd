class_name RoadMain
extends Node3D
## The road down the mountain, the first scene of the game: it ends by handing over to the flat (see Journey).
## For now it is empty: the start card, and a click ends the road at once.

## The road is over. `ending` is how it went; Journey carries it into the flat.
signal finished(ending: StringName)

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

var pause: PauseMenu
var loaded := false  # the start card is ready to be clicked (tools wait for this)
var _automated := false


func _ready() -> void:
	WorldState.reset()
	pause = PauseMenu.new()
	pause.name = "PauseMenu"
	add_child(pause)
	hud.bind(player)
	hud.started.connect(_on_started)
	if Main.has_flag("flat") or Main.has_flag("perf"):  # checks of the flat alone: straight to its own start card
		Journey.arrive.call_deferred(&"")  # deferred: the tree is still adding this scene, the first one
		return
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
	var ok := loaded and player.input_enabled and get_viewport().get_camera_3d() == player.camera
	print("ROAD-SMOKE %s time=%.1f gpu=%s" % ["ok" if ok else "FAIL", WorldState.time, RenderingServer.get_video_adapter_name()])
	if ok:
		finish(&"alive")
	elif not OS.has_feature("web"):
		get_tree().quit(1)


func finish(ending: StringName) -> void:
	finished.emit(ending)
	Journey.arrive(ending)


func _on_started() -> void:
	if not _automated:  # the smoke run plays its 3 s first and ends the road itself
		finish(&"alive")


func _process(delta: float) -> void:
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
	elif event is InputEventMouseButton and event.pressed and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # in case the browser refused the first request
