extends Node3D
## Composition root: builds the condo, places the player, wires presentation to the simulation.

@onready var player: PlayerController = $Player
@onready var hud: Hud = $Hud

var builder: ApartmentBuilder
var audio: AudioDirector
var _demo_ring := -1.0  # Phase 1 stand-in for the story: seconds until the next intercom ring


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
	hud.bind(player)
	hud.started.connect(func() -> void: _demo_ring = 2.0)
	EventBus.object_interacted.connect(_on_interacted)


func _physics_process(delta: float) -> void:
	WorldState.advance_time(delta)
	WorldState.set_player_room(ApartmentLayout.room_at(player.global_position, WorldState.variants))
	if _demo_ring >= 0.0:
		_demo_ring -= delta
		if _demo_ring < 0.0:
			EventBus.sound_requested.emit(&"intercom_ring", Vector3(0.1, 1.45, 8.6), -2.0)
			_demo_ring = 3.6


func _process(_delta: float) -> void:
	# Browsers use Esc to leave pointer lock and Godot never sees the key, so on the web any lost capture
	# pauses the player the way Esc does on desktop.
	if OS.has_feature("web") and player.input_enabled and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not hud.is_inspecting():
		player.input_enabled = false


func _on_interacted(object_id: StringName) -> void:
	if object_id == &"intercom" and _demo_ring >= 0.0:
		_demo_ring = -1.0
		EventBus.subtitle_requested.emit("\"Hello? Sorry ah, so late. Downstairs, 11-07. Can you stop the knocking?\"", 5.0)
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			EventBus.sound_requested.emit(&"knock3", ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"], 2.0)
			EventBus.subtitle_requested.emit("[Three knocks from the bedroom]", 3.0))


func _unhandled_input(event: InputEvent) -> void:
	# Phase 1: Esc frees the mouse, a click takes it back. The pause menu replaces this in Phase 6.
	if event.is_action_pressed("pause") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not hud.is_inspecting():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.input_enabled = false
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.interaction.enabled_input and not hud.is_inspecting() and WorldState.time > 0.1:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.input_enabled = true
