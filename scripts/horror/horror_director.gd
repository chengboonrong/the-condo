class_name HorrorDirector
extends RefCounted
## Picks the next adaptive event at 4 Hz. Pacing comes from a tension model (each event adds its intensity,
## tension decays between events, and the next event waits a recovery gap that grows with tension).
## When it is time, every adaptive event the scheduler would accept is scored:
##   utility = base + behaviour + narrative + tension fit - repetition
## and one of the top three is drawn with the simulation RNG. Every decision is logged with its parts.

const EVAL_INTERVAL := 0.25
const TOP_K := 3
## Tension each act aims for; act 1 has no adaptive events.
const TARGET := {1: 0.0, 2: 0.3, 3: 0.5, 4: 0.7, 5: 0.0}
const TENSION_GAIN := 0.6  # tension added per unit of event intensity
const TENSION_TAU := 40.0  # seconds; decay between events
const GAP_MIN := 10.0  # recovery gap after an event at zero tension...
const GAP_MAX := 30.0  # ...and at full tension
const REPEAT_WINDOW := 5
const LOG_LIMIT := 30

## Every pick, with its scores (the log above keeps only the last LOG_LIMIT).
signal decided(decision: Dictionary)

var scheduler: EventScheduler
var profiler: BehaviorProfiler
var ctx: EventContext
var tension := 0.0
var paused := false
var decisions: Array[Dictionary] = []
var last_eval_usec := 0
var max_eval_usec := 0
var _next_eval := 0.0
var _quiet_until := 0.0


func _init(event_scheduler: EventScheduler, behavior: BehaviorProfiler) -> void:
	scheduler = event_scheduler
	profiler = behavior
	ctx = scheduler.ctx
	scheduler.run_started.connect(_on_run_started)
	scheduler.run_finished.connect(_on_run_finished)


func target() -> float:
	return TARGET.get(WorldState.act, 0.0)


func gap() -> float:
	return lerpf(GAP_MIN, GAP_MAX, tension)


func tick(delta: float) -> void:
	if scheduler.running.is_empty():
		tension *= exp(-delta / TENSION_TAU)
	if ctx.now() < _next_eval:
		return
	_next_eval = ctx.now() + EVAL_INTERVAL
	var t0 := Time.get_ticks_usec()
	_evaluate()
	last_eval_usec = Time.get_ticks_usec() - t0
	max_eval_usec = maxi(max_eval_usec, last_eval_usec)


## Scores every adaptive event now, without starting anything. Each entry: id, total, parts, run.
func score_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in scheduler.sorted_ids():
		var ev: HorrorEvent = scheduler.events[id]
		if not ev.adaptive:
			continue
		var run := scheduler.check(id)
		if run["state"] != EventScheduler.State.VALIDATED:
			out.append({"id": id, "rejected": run["reason"]})
			continue
		var parts := {
			"base": ev.base_weight,
			"behavior": _behavior_score(ev),
			"narrative": _narrative_score(ev),
			"tension": _tension_fit(ev),
			"repetition": -_repetition(id),
		}
		var total := 0.0
		for v: float in parts.values():
			total += v
		out.append({"id": id, "total": total, "parts": parts, "run": run})
	return out


## Short lines for the debug overlay.
func debug_lines() -> Array[String]:
	var lines: Array[String] = []
	lines.append("director tension %.2f → target %.2f   gap %.0fs   next in %.0fs   eval %d µs (max %d)" % [
		tension, target(), gap(), maxf(0.0, _quiet_until - ctx.now()), last_eval_usec, max_eval_usec])
	if not decisions.is_empty():
		var d: Dictionary = decisions[-1]
		lines.append("last pick @%.0fs: %s" % [d["t"], d["chosen"]])
		for s: Dictionary in d["scores"]:
			lines.append("  %-14s %5.2f  %s" % [s["id"], s["total"], _fmt_parts(s["parts"])])
	return lines


func _evaluate() -> void:
	if paused or target() <= 0.0 or ctx.now() < _quiet_until or tension >= target():
		return
	if not scheduler.running.is_empty():
		return  # one beat at a time: never stack on a running adaptive or story event
	var scored := score_all().filter(func(s: Dictionary) -> bool: return s.has("total"))
	if scored.is_empty():
		return
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["total"] > b["total"] or (a["total"] == b["total"] and String(a["id"]) < String(b["id"])))
	var top := scored.slice(0, TOP_K)
	var weights: Array = top.map(func(s: Dictionary) -> Array: return [s, maxf(s["total"], 0.05)])
	var pick: Dictionary = HorrorEvent.pick_weighted(ctx.rng, weights)
	_record(pick, top)
	scheduler.begin(pick["run"])


func _behavior_score(ev: HorrorEvent) -> float:
	var total := 0.0
	for key: Variant in ev.behavior_weights:
		var k := String(key)
		var value := _room_avoid() if k == "room_avoid" else profiler.signal_value(k)
		total += float(ev.behavior_weights[key]) * value
	return total


## How much the player avoids the rooms around them (the director's reason to send events there).
func _room_avoid() -> float:
	var best := 0.0
	for r: StringName in ctx.graph.rooms_within(ctx.player_room(), 2):
		best = maxf(best, profiler.room_avoidance(r))
	return best


func _narrative_score(ev: HorrorEvent) -> float:
	var bonus := float(ev.act_bonus.get(WorldState.act, 0.0))
	for key: Variant in ev.entity_bonus:
		if String(key) == String(WorldState.entity_state):
			bonus += float(ev.entity_bonus[key])
	return bonus


## +1 when the event's intensity fills the gap between tension and target exactly, falling off either side.
func _tension_fit(ev: HorrorEvent) -> float:
	var headroom := clampf(target() - tension, 0.0, 1.0)
	return clampf(1.0 - absf(ev.intensity - headroom) * 2.0, -1.0, 1.0)


func _repetition(id: StringName) -> float:
	var recent: Array[StringName] = []
	for e: Dictionary in WorldState.event_history:
		if int(e.get("priority", 0)) == 0:
			recent.append(e["id"])
	recent = recent.slice(maxi(0, recent.size() - REPEAT_WINDOW))
	var penalty := 0.5 * recent.count(id)
	if not recent.is_empty() and recent[-1] == id:
		penalty += 0.8
	return penalty


func _record(pick: Dictionary, top: Array) -> void:
	decisions.append({
		"t": snappedf(ctx.now(), 0.01),
		"act": WorldState.act,
		"tension": snappedf(tension, 0.001),
		"chosen": pick["id"],
		"scores": top.map(func(s: Dictionary) -> Dictionary: return {"id": s["id"], "total": snappedf(s["total"], 0.001), "parts": s["parts"]}),
	})
	if decisions.size() > LOG_LIMIT:
		decisions.pop_front()
	decided.emit(decisions[-1])
	scheduler._log("director → %s (%.2f; tension %.2f/%.2f)" % [pick["id"], pick["total"], tension, target()])


func _on_run_started(run: Dictionary) -> void:
	var ev: HorrorEvent = scheduler.events[run["id"]]
	tension = minf(1.0, tension + ev.intensity * TENSION_GAIN)


func _on_run_finished(_run: Dictionary) -> void:
	_quiet_until = maxf(_quiet_until, ctx.now() + gap())


func _fmt_parts(parts: Dictionary) -> String:
	var bits: Array[String] = []
	for k: String in parts:
		bits.append("%s %+.2f" % [k.substr(0, 3), parts[k]])
	return " ".join(bits)
