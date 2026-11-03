class_name DoorEvent
extends HorrorEvent
## A door near the player slams shut or creaks open. Never within reach of the player, never locks.
## params.door + params.open force a specific door (story).

const MIN_DISTANCE := 1.8

@export var excluded_doors: Array[StringName] = [&"main_door", &"gap_door", &"mirror_door"]


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var door: StringName = run["params"].get("door", &"")
	var here := ctx.player_room()
	if door == &"":
		var options: Array = []
		for c: Dictionary in ctx.graph.connections():
			var d: StringName = c["door"]
			if d == &"" or excluded_doors.has(d) or (c["a"] != here and c["b"] != here):
				continue
			if ctx.stage.distance_to(_center(d)) < MIN_DISTANCE:
				continue
			var other: StringName = c["b"] if c["a"] == here else c["a"]
			options.append([d, 1.0 + 2.0 * ctx.room_avoidance(other)])
		door = HorrorEvent.pick_weighted(ctx.rng, options) if not options.is_empty() else &""
		if door == &"":
			return "no_door_out_of_reach"
	if not ApartmentLayout.requires_met(ApartmentLayout.DOORS[door].get("requires", {}), WorldState.variants):
		return "door_unavailable"
	if ctx.stage.distance_to(_center(door)) < MIN_DISTANCE:
		return "player_too_close"
	var was_open := WorldState.is_door_open(door)
	var target: bool = run["params"].get("open", not was_open)
	if target == was_open:
		return "door_already_%s" % ("open" if was_open else "shut")
	run["door"] = door
	run["was_open"] = was_open
	run["target_open"] = target
	run["position"] = _center(door)
	run["room"] = here
	run["channels"].append("door:%s" % door)
	return ""


func start(_ctx: EventContext, run: Dictionary) -> void:
	WorldState.set_door(run["door"], run["target_open"], id)
	EventBus.subtitle_requested.emit("[A door slams]" if not run["target_open"] else "[A door creaks open]", 2.0)


func finish(_ctx: EventContext, run: Dictionary, result: StringName) -> void:
	if result != &"completed":
		WorldState.set_door(run["door"], run["was_open"], &"restore")


static func _center(door: StringName) -> Vector3:
	var d: Dictionary = ApartmentLayout.DOORS[door]
	return d["hinge"] + Vector3(d["width"] * 0.5, 0, 0)
