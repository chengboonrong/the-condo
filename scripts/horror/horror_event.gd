class_name HorrorEvent
extends Resource
## A horror event definition. Tuning lives in resources/horror_events/*.tres; behaviour lives in subclasses.
## Definitions are shared and stateless: everything about one firing is kept in its `run` Dictionary.
##
## Hooks, called by EventScheduler:
##   prepare(ctx, run) -> String   preconditions + choose location; "" = OK, else the rejection reason
##   start(ctx, run)               begin (sounds, presentation requests, state changes)
##   update(ctx, run, delta) -> bool   true when finished
##   finish(ctx, run, result)      always called once; on cancelled/failed it must leave the world valid

@export var id: StringName
@export_range(0.0, 1.0) var intensity := 0.3
@export var base_weight := 1.0
@export var cooldown := 30.0
@export var duration := 3.0
@export_range(1, 4) var min_act := 2
@export_range(1, 4) var max_act := 4
## Mutual exclusion: two runs sharing a channel never overlap. prepare() may add run-specific channels.
@export var channels: PackedStringArray = []
## false = never chosen by the director; only the story or debug keys request it.
@export var adaptive := true
## BehaviorProfiler signal -> weight, summed into the director's behaviour relevance.
@export var behavior_weights: Dictionary = {}
## Act (int) -> bonus, and entity state (StringName) -> bonus, for the director's narrative relevance.
@export var act_bonus: Dictionary = {}
@export var entity_bonus: Dictionary = {}


func prepare(_ctx: EventContext, _run: Dictionary) -> String:
	return ""


func start(_ctx: EventContext, _run: Dictionary) -> void:
	pass


func update(_ctx: EventContext, run: Dictionary, _delta: float) -> bool:
	return run["elapsed"] >= duration


func finish(_ctx: EventContext, _run: Dictionary, _result: StringName) -> void:
	pass


## Weighted pick with the simulation RNG. weights: Array of [value, weight].
static func pick_weighted(rng: RandomNumberGenerator, weights: Array) -> Variant:
	var total := 0.0
	for w: Array in weights:
		total += maxf(w[1], 0.0)
	if total <= 0.0:
		return null
	var roll := rng.randf() * total
	for w: Array in weights:
		roll -= maxf(w[1], 0.0)
		if roll <= 0.0:
			return w[0]
	return weights[-1][0]
