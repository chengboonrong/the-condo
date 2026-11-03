class_name PhoneRingEvent
extends HorrorEvent
## Story only: an intercom rings until params.stop_flag is set in WorldState, or the duration runs out.

const RING_EVERY := 3.6


func prepare(_ctx: EventContext, run: Dictionary) -> String:
	var anchor: StringName = run["params"].get("anchor", &"")
	if not ApartmentLayout.ANCHORS.has(anchor):
		return "unknown_phone"
	run["room"] = ApartmentLayout.ANCHORS[anchor]["room"]
	run["position"] = ApartmentLayout.ANCHORS[anchor]["pos"]
	run["next_ring"] = 0.0
	return ""


func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	if WorldState.has_flag(run["params"].get("stop_flag", &"")):
		return true
	if run["elapsed"] >= run["next_ring"]:
		EventBus.sound_requested.emit(&"intercom_ring", run["position"], -2.0)
		EventBus.subtitle_requested.emit("[The intercom is ringing]", 2.5)
		run["next_ring"] = run["elapsed"] + RING_EVERY
	return run["elapsed"] >= duration
