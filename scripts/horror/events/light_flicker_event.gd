class_name LightFlickerEvent
extends HorrorEvent
## The lights in the player's room flicker; sometimes they go out (they can be switched back on).

@export_range(0.0, 1.0) var chance_off := 0.35


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var room: StringName = run["params"].get("room", ctx.player_room())
	if not ApartmentLayout.LIGHTS.has(room):
		return "no_light_here"
	if not WorldState.is_light_on(room):
		return "light_already_off"
	run["room"] = room
	run["position"] = ApartmentLayout.LIGHTS[room]["pos"][0]
	run["channels"].append("lights:%s" % room)
	run["goes_dark"] = ctx.rng.randf() < float(run["params"].get("chance_off", chance_off))
	return ""


func start(_ctx: EventContext, run: Dictionary) -> void:
	EventBus.light_flicker_requested.emit(run["room"], duration)
	EventBus.sound_requested.emit(&"buzz", run["position"], -6.0)
	EventBus.subtitle_requested.emit("[The lights buzz and flicker]", 2.0)


func finish(_ctx: EventContext, run: Dictionary, result: StringName) -> void:
	if result == &"completed":
		if run["goes_dark"]:
			WorldState.set_light(run["room"], false)
	else:
		EventBus.light_flicker_requested.emit(run["room"], 0.0)  # stop the effect; the state never changed
