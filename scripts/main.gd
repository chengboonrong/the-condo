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
var _had_capture := false


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
	var silhouette := Silhouette.new()
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
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and player != null and player.input_enabled and not pause.is_open():
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
