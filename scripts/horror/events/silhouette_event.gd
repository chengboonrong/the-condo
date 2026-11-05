class_name SilhouetteEvent
extends HorrorEvent
## A figure appears briefly where the player is not looking, in or next to their room.
## It vanishes once seen (the presentation reports silhouette_seen) or when its time is up.
## Rarer, at a "still" anchor: it stands under the only light on there and waits longer to be found.

const MIN_DISTANCE := 3.5
const STILL_MIN_DISTANCE := 5.0
const STILL_WAIT := 8.0  # inside the scheduler's timeout for the figure (9 s)
const STILL_WEIGHT := 1.0


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
		var still: bool = a["kind"] == "still"
		if not (still or a["kind"] == "silhouette") or not ctx.graph.rooms().has(a["room"]):
			continue
		if a_id != run["params"].get("anchor", a_id):
			continue
		if still and not _lit_alone(a):
			continue
		if ctx.graph.distance(here, a["room"]) > 1 or ctx.stage.distance_to(a["pos"]) < (STILL_MIN_DISTANCE if still else MIN_DISTANCE):
			continue
		var head: Vector3 = a["pos"] + Vector3.UP * 1.6
		if ctx.stage.any_visible(body_points(a["pos"], ctx.stage.player_position())) and not ctx.stage.is_behind(head):
			continue  # it must appear out of view
		options.append([a_id, STILL_WEIGHT if still else (2.0 if ctx.stage.is_behind(head) else 1.0)])
	var anchor: Variant = HorrorEvent.pick_weighted(ctx.rng, options) if not options.is_empty() else null
	if anchor == null:
		return "no_hidden_anchor"
	run["anchor"] = anchor
	run["room"] = ApartmentLayout.ANCHORS[anchor]["room"]
	run["position"] = ApartmentLayout.ANCHORS[anchor]["pos"]
	run["wait"] = STILL_WAIT if ApartmentLayout.ANCHORS[anchor]["kind"] == "still" else duration
	return ""


## A still anchor's own light is on and every other lamp that would reach it is off, as things are now:
## the figure never switches a light to stand there.
static func _lit_alone(a: Dictionary) -> bool:
	if not WorldState.is_light_on(a["light"]):
		return false
	for room: StringName in a["dark"]:
		if WorldState.is_light_on(room):
			return false
	return true


func start(_ctx: EventContext, run: Dictionary) -> void:
	EventBus.silhouette_requested.emit(run["anchor"], run["wait"])


func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	return run.get("seen", false) or run["elapsed"] >= run["wait"]


func finish(_ctx: EventContext, run: Dictionary, result: StringName) -> void:
	if result != &"completed":
		EventBus.silhouette_requested.emit(run["anchor"], 0.0)  # hide it now
