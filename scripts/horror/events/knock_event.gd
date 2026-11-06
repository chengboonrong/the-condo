class_name KnockEvent
extends HorrorEvent
## Three knocks from a wall near the player. Prefers rooms the player avoids; a curious player
## hears the next knock somewhere new. params.anchor forces the location and params.sound the sound (story).

@export var max_steps := 2
@export var volume_db := 0.0


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var anchor: StringName = run["params"].get("anchor", &"")
	if anchor == &"":
		var options: Array = []
		var here := ctx.player_room()
		var last_room := _last_knock_room()
		var curiosity: float = ctx.profiler.signal_value("curiosity") if ctx.profiler != null else 0.0
		for a_id: StringName in ApartmentLayout.ANCHORS:
			var a: Dictionary = ApartmentLayout.ANCHORS[a_id]
			if a["kind"] != "knock" or not ctx.graph.rooms().has(a["room"]):
				continue
			var steps := ctx.graph.distance(here, a["room"])
			if steps > max_steps:
				continue
			# Same-room knocks only from the floor ("from downstairs"); otherwise prefer avoided rooms.
			if steps == 0 and not String(a_id).ends_with("floor"):
				continue
			var w := 1.0 + 3.0 * ctx.room_avoidance(a["room"])
			options.append([a_id, w * (1.0 - 0.8 * curiosity) if a["room"] == last_room else w])
		anchor = HorrorEvent.pick_weighted(ctx.rng, options) if not options.is_empty() else &""
		if anchor == &"":
			return "no_anchor_near_player"
	var a: Dictionary = ApartmentLayout.ANCHORS.get(anchor, {})
	if a.is_empty() or a["kind"] != "knock" or not ctx.graph.rooms().has(a["room"]):
		return "anchor_unavailable"
	run["anchor"] = anchor
	run["room"] = a["room"]
	run["position"] = a["pos"]
	return ""


func start(ctx: EventContext, run: Dictionary) -> void:
	EventBus.sound_requested.emit(run["params"].get("sound", &"knock3"), run["position"], float(run["params"].get("volume_db", volume_db)))
	var where := ctx.room_name(run["room"])
	EventBus.subtitle_requested.emit("[Three knocks%s]" % ("" if where == "???" else " from the %s" % where), 3.0)


static func _last_knock_room() -> StringName:
	for i in range(WorldState.event_history.size() - 1, -1, -1):
		if WorldState.event_history[i]["id"] == &"knock_wall":
			return WorldState.event_history[i]["room"]
	return &""
