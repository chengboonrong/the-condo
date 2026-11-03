class_name ShiftEvent
extends HorrorEvent
## Something in the condo changes while nobody is looking. Adaptive runs flip one of `areas` (small
## object shifts) to its other variant; story runs pass params.area and params.variant (the impossible
## room), and the scheduler retries them every tick until RoomTransformer's checks pass. No sound, no
## caption: noticing what moved is the player's job.

## Areas the director may shift on its own.
@export var areas: PackedStringArray = []


func prepare(ctx: EventContext, run: Dictionary) -> String:
	var transformer: RoomTransformer = ctx.transformer
	if transformer == null:
		return "no_transformer"
	var area: StringName = run["params"].get("area", &"")
	var variant: StringName = run["params"].get("variant", &"")
	if area == &"":
		var options: Array = []
		for a: String in areas:
			var v := _other_variant(StringName(a))
			if transformer.check(StringName(a), v) == "":
				var room: StringName = ApartmentLayout.VARIANT_AREAS[StringName(a)]["rooms"][0]
				options.append([StringName(a), 1.0 + 2.0 * ctx.room_avoidance(room)])
		if options.is_empty():
			return "nothing_unseen_to_shift"
		area = HorrorEvent.pick_weighted(ctx.rng, options)
		variant = _other_variant(area)
	var reason := transformer.check(area, variant)
	if reason != "":
		return reason
	run["area"] = area
	run["variant"] = variant
	run["room"] = ApartmentLayout.VARIANT_AREAS[area]["rooms"][0]
	run["position"] = ApartmentLayout.VARIANT_AREAS[area]["probes"][0]
	run["channels"].append("shift:%s" % area)
	return ""


func start(ctx: EventContext, run: Dictionary) -> void:
	# check() ran this same tick, so this only fails if something changed the world in between.
	if (ctx.transformer as RoomTransformer).apply(run["area"], run["variant"]) != "":
		run["failed"] = true


static func _other_variant(area: StringName) -> StringName:
	for v: StringName in ApartmentLayout.VARIANT_AREAS[area]["variants"]:
		if v != WorldState.get_variant(area):
			return v
	return WorldState.get_variant(area)
