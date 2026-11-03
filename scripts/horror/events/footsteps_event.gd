class_name FootstepsEvent
extends HorrorEvent
## Footsteps walk from an empty room toward the player and stop at the doorway. They start where the
## entity is when it is near; otherwise from a room two steps away.

const STEP_LENGTH := 0.7
const STEP_TIME := 0.55

@export var max_steps := 12


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var here := ctx.player_room()
	var source: StringName = run["params"].get("from", &"")
	var lurking := WorldState.entity_room
	if source == &"" and lurking != &"" and lurking != here and ctx.graph.distance(lurking, here) <= 2:
		source = lurking
	if source == &"":
		var options: Array = []
		for r: StringName in ctx.graph.rooms_within(here, 2):
			options.append([r, 1.0 + 2.0 * ctx.room_avoidance(r)])
		source = HorrorEvent.pick_weighted(ctx.rng, options) if not options.is_empty() else &""
	if source == &"" or source == here:
		return "no_source_room"
	var path := ctx.graph.path(source, here)
	if path.size() < 2:
		return "no_path"
	var points: Array[Vector3] = [ApartmentLayout.room_center(source, WorldState.variants)]
	for i in path.size() - 1:
		points.append(ctx.graph.connection(path[i], path[i + 1])["pos"])
	var steps: Array[Vector3] = []
	for i in points.size() - 1:
		var seg := points[i + 1] - points[i]
		var n := maxi(1, int(seg.length() / STEP_LENGTH))
		for k in n:
			steps.append(points[i] + seg * (float(k + 1) / n) + Vector3.UP * 0.05)
	run["steps"] = steps.slice(maxi(0, steps.size() - max_steps))  # keep the end nearest the player
	run["room"] = source
	run["position"] = run["steps"][0]
	run["next_step"] = 0.0
	return ""


func start(_ctx: EventContext, _run: Dictionary) -> void:
	EventBus.subtitle_requested.emit("[Footsteps, coming closer]", 3.0)


func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	var steps: Array = run["steps"]
	var i := int(run.get("step_index", 0))
	if i >= steps.size():
		return true
	if run["elapsed"] >= run["next_step"]:
		EventBus.sound_requested.emit(&"footstep", steps[i], lerpf(-10.0, -2.0, float(i) / steps.size()))
		run["step_index"] = i + 1
		run["next_step"] = run["elapsed"] + STEP_TIME
	return false
