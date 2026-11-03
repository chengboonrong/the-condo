class_name SilhouetteEvent
extends HorrorEvent
## A figure appears briefly where the player is not looking, in or next to their room.
## It vanishes once seen (the presentation reports silhouette_seen) or when its time is up.

const MIN_DISTANCE := 3.5


## Points on the figure standing at pos, facing the viewer: feet, waist, head and both sides.
## Any of them on screen means it is in view (a head-only test misses it when the player looks down).
static func body_points(pos: Vector3, viewer: Vector3) -> Array[Vector3]:
	var to := Vector3(viewer.x - pos.x, 0, viewer.z - pos.z)
	var side := to.normalized().cross(Vector3.UP) * 0.25 if to.length() > 0.01 else Vector3.RIGHT * 0.25
	var waist := pos + Vector3.UP * 1.0
	return [pos + Vector3.UP * 0.1, waist, pos + Vector3.UP * 1.6, waist + side, waist - side]


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var here := ctx.player_room()
	var options: Array = []
	for a_id: StringName in ApartmentLayout.ANCHORS:
		var a: Dictionary = ApartmentLayout.ANCHORS[a_id]
		if a["kind"] != "silhouette" or not ctx.graph.rooms().has(a["room"]):
			continue
		if a_id != run["params"].get("anchor", a_id):
			continue
		if ctx.graph.distance(here, a["room"]) > 1 or ctx.stage.distance_to(a["pos"]) < MIN_DISTANCE:
			continue
		var head: Vector3 = a["pos"] + Vector3.UP * 1.6
		if ctx.stage.any_visible(body_points(a["pos"], ctx.stage.player_position())) and not ctx.stage.is_behind(head):
			continue  # it must appear out of view
		options.append([a_id, 2.0 if ctx.stage.is_behind(head) else 1.0])
	var anchor: Variant = HorrorEvent.pick_weighted(ctx.rng, options) if not options.is_empty() else null
	if anchor == null:
		return "no_hidden_anchor"
	run["anchor"] = anchor
	run["room"] = ApartmentLayout.ANCHORS[anchor]["room"]
	run["position"] = ApartmentLayout.ANCHORS[anchor]["pos"]
	return ""


func start(_ctx: EventContext, run: Dictionary) -> void:
	EventBus.silhouette_requested.emit(run["anchor"], duration)


func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	return run.get("seen", false) or run["elapsed"] >= duration


func finish(_ctx: EventContext, run: Dictionary, result: StringName) -> void:
	if result != &"completed":
		EventBus.silhouette_requested.emit(run["anchor"], 0.0)  # hide it now
