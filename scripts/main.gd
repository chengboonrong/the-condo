extends Node3D
## Composition root: builds the condo, places the player, wires presentation to the simulation.

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

## Fixed for now so runs are reproducible; the story/settings choose it later.
const SEED := 1147

var builder: ApartmentBuilder
var audio: AudioDirector
var runtime: HorrorRuntime


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
	hud.bind(player)
	hud.started.connect(_on_started)
	EventBus.object_interacted.connect(_on_interacted)


func _physics_process(delta: float) -> void:
	WorldState.set_player_room(ApartmentLayout.room_at(player.global_position, WorldState.variants))
	runtime.step(delta)


func _process(_delta: float) -> void:
	# Browsers use Esc to leave pointer lock and Godot never sees the key, so on the web any lost capture
	# pauses the player the way Esc does on desktop.
	if OS.has_feature("web") and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not hud.is_inspecting():
		player.input_enabled = false


# Phase 2 stand-in for the story (StoryDirector replaces it in Phase 5): the intercom rings, the
# neighbour complains, and the knocks start, all as story requests through the scheduler.
func _on_started() -> void:
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		runtime.scheduler.request(&"phone_ring", {"anchor": &"phone_intercom", "stop_flag": &"answered_intercom"}))


func _on_interacted(object_id: StringName) -> void:
	if object_id == &"intercom" and runtime.scheduler.is_running(&"phone_ring") and not WorldState.has_flag(&"answered_intercom"):
		WorldState.set_flag(&"answered_intercom")
		EventBus.subtitle_requested.emit("\"Hello? Sorry ah, so late. Downstairs, 11-07. Can you stop the knocking?\"", 5.0)
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			runtime.scheduler.request(&"knock_wall", {"anchor": &"knock_bedroom_north", "volume_db": 2.0}))


func _unhandled_input(event: InputEvent) -> void:
	# Phase 1: Esc frees the mouse, a click takes it back. The pause menu replaces this in Phase 6.
	if event.is_action_pressed("pause") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hud.is_inspecting():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.input_enabled = false
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.interaction.enabled_input and not hud.is_inspecting() and WorldState.time > 0.1:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.input_enabled = true
