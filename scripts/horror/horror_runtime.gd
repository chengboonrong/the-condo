class_name HorrorRuntime
extends Node
## Composition root of the simulation core. One seeded RNG; one fixed tick order.
## The game calls step() from _physics_process; tests and simulated playthroughs call it directly.

const EVENTS_DIR := "res://resources/horror_events"
## Debug keys F5–F9 in the brief's order: knocks, lights, door, footsteps, silhouette.
const DEBUG_EVENTS: Array[StringName] = [&"knock_wall", &"light_flicker", &"door_slam", &"footsteps", &"silhouette"]

var rng := RandomNumberGenerator.new()
var graph: RoomGraph
var ctx: EventContext
var scheduler: EventScheduler


func setup(stage: HorrorStage, seed_value: int) -> void:
	rng.seed = seed_value
	graph = stage.graph
	ctx = EventContext.new()
	ctx.graph = graph
	ctx.stage = stage
	ctx.rng = rng
	scheduler = EventScheduler.new(ctx)
	scheduler.load_dir(EVENTS_DIR)
	EventBus.silhouette_seen.connect(_on_silhouette_seen)


func _exit_tree() -> void:
	if EventBus.silhouette_seen.is_connected(_on_silhouette_seen):
		EventBus.silhouette_seen.disconnect(_on_silhouette_seen)


## Advances the whole simulation by delta seconds.
func step(delta: float) -> void:
	WorldState.advance_time(delta)
	scheduler.tick(delta)


## Debug: start event n (0-based) now. Preconditions and cooldowns still apply; only the act gate is skipped.
func debug_trigger(index: int) -> Dictionary:
	return scheduler.start(DEBUG_EVENTS[index], {"ignore_act": true, "debug": true})


func _on_silhouette_seen(_anchor: StringName) -> void:
	scheduler.mark(&"silhouette", "seen")
