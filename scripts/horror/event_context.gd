class_name EventContext
extends RefCounted
## What an event may read while it runs. State changes still go through WorldState; sounds through EventBus.

var graph: RoomGraph
var stage: HorrorStage
var rng: RandomNumberGenerator  # the one simulation RNG; never use randf() in the core
var profiler: Object = null  # BehaviorProfiler, once the director is running
var entity: Object = null  # EntityController
var transformer: Object = null  # RoomTransformer


func now() -> float:
	return WorldState.time


func player_room() -> StringName:
	return WorldState.player_room


func room_name(room_id: StringName) -> String:
	return String(ApartmentLayout.ROOMS.get(room_id, {}).get("name", "")).to_lower()


## Avoidance score 0–1 for a room; 0 until the profiler exists.
func room_avoidance(room_id: StringName) -> float:
	return profiler.room_avoidance(room_id) if profiler else 0.0
