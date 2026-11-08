class_name EventScheduler
extends RefCounted
## Runs horror events through IDLE → VALIDATED → RUNNING → COMPLETED / CANCELLED / FAILED.
## Owns cooldowns, channel locks, priority pre-emption, timeouts and queued story requests.
##
## Priorities: 0 = adaptive (director), 5 = story hint, 10 = story, 20 = story-critical.
## A request may pre-empt running events of strictly lower priority that share a channel.
## Queued requests (story) are retried every tick until they start. The only ones dropped are those
## whose target already holds ("door_already_shut", "already_door"): there is nothing left to do.

signal run_started(run: Dictionary)
signal run_finished(run: Dictionary)

enum State { IDLE, VALIDATED, RUNNING, COMPLETED, CANCELLED, FAILED }
const RESULT := {State.COMPLETED: &"completed", State.CANCELLED: &"cancelled", State.FAILED: &"failed"}
const LOG_LIMIT := 120

var ctx: EventContext
var events: Dictionary = {}  # id -> HorrorEvent
var running: Array[Dictionary] = []
var queue: Array[Dictionary] = []
var cooldown_until: Dictionary = {}  # id -> sim time
var log_lines: Array[String] = []
var _next_uid := 1


func _init(context: EventContext) -> void:
	ctx = context


func register(event: HorrorEvent) -> void:
	assert(event.id != &"" and not events.has(event.id), "duplicate or empty event id")
	events[event.id] = event


## ResourceLoader, not DirAccess: in an exported pack the files are renamed *.tres.remap.
func load_dir(path: String) -> void:
	var files := Array(ResourceLoader.list_directory(path))
	files.sort()  # deterministic registration order
	for f: String in files:
		if f.ends_with(".tres"):
			register(load(path.path_join(f)))


func sorted_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(events.keys())
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## Validates without starting. Returns a run in VALIDATED state, or IDLE with run["reason"].
## params: story=true skips act and cooldown checks; ignore_act=true skips only the act check (debug keys).
func check(id: StringName, params: Dictionary = {}, priority := 0) -> Dictionary:
	var run := {
		"uid": _next_uid, "id": id, "state": State.IDLE, "params": params, "priority": priority,
		"elapsed": 0.0, "room": &"", "position": Vector3.ZERO, "reason": "",
	}
	_next_uid += 1
	var ev: HorrorEvent = events.get(id)
	if ev == null:
		run["reason"] = "unknown_event"
		return run
	run["channels"] = Array(ev.channels)
	var story: bool = params.get("story", false)
	if not story and not params.get("ignore_act", false) and (WorldState.act < ev.min_act or WorldState.act > ev.max_act):
		run["reason"] = "act"
		return run
	if not story and ctx.now() < cooldown_until.get(id, -INF):
		run["reason"] = "cooldown"
		return run
	var reason := ev.prepare(ctx, run)
	if reason != "":
		run["reason"] = reason
		return run
	for other in running:
		if _shares_channel(run, other) and priority <= int(other["priority"]):
			run["reason"] = "busy:%s" % other["id"]
			return run
	run["state"] = State.VALIDATED
	return run


## Validates and starts now. Returns the run (state RUNNING, or IDLE with a reason).
func start(id: StringName, params: Dictionary = {}, priority := 0) -> Dictionary:
	var run := check(id, params, priority)
	if run["state"] == State.VALIDATED:
		begin(run)
	else:
		_log("%s rejected: %s" % [id, run["reason"]])
	return run


## Story request: start now, or queue and retry every tick until it can start.
func request(id: StringName, params: Dictionary = {}, priority := 10) -> Dictionary:
	var p := params.duplicate()
	p["story"] = true
	var run := start(id, p, priority)
	if run["reason"] == "unknown_event":
		push_error("story request for unknown event %s" % id)
		return run
	if run["state"] != State.RUNNING:
		if _satisfied(run):
			_log("%s not needed (%s)" % [id, run["reason"]])
			return run
		queue.append({"id": id, "params": p, "priority": priority, "since": ctx.now(), "reason": run["reason"]})
		_log("%s queued (%s)" % [id, run["reason"]])
	return run


## Starts a run that check() validated in this same tick. If it pre-empts other runs, their finish()
## restores the world first and the run is prepared again against that; it may then not start
## (state back to IDLE with a reason). Pre-empted story requests go back to the front of the queue.
func begin(run: Dictionary) -> void:
	assert(run["state"] == State.VALIDATED)
	var preempted := false
	for other in running.duplicate():
		if _shares_channel(run, other):
			cancel(other, "preempted by %s" % run["id"])
			preempted = true
			if other["params"].get("story", false):
				queue.push_front({"id": other["id"], "params": other["params"], "priority": other["priority"], "since": ctx.now(), "reason": "preempted"})
	if preempted:
		var again := check(run["id"], run["params"], run["priority"])
		run.merge(again, true)
		if run["state"] != State.VALIDATED:
			_log("%s rejected after pre-empting: %s" % [run["id"], run["reason"]])
			return
	var ev: HorrorEvent = events[run["id"]]
	run["state"] = State.RUNNING
	run["started_at"] = ctx.now()
	run["timeout"] = float(run["params"].get("timeout", maxf(ev.duration * 2.0, ev.duration + 5.0)))
	cooldown_until[run["id"]] = ctx.now() + ev.cooldown
	running.append(run)
	ev.start(ctx, run)
	_log("%s RUNNING room=%s prio=%d" % [run["id"], run["room"], run["priority"]])
	EventBus.horror_event_started.emit(run["id"], run["room"])
	run_started.emit(run)


func cancel(run: Dictionary, reason := "cancelled") -> void:
	if run["state"] == State.RUNNING:
		run["reason"] = reason
		_end(run, State.CANCELLED)


func cancel_id(id: StringName, reason := "cancelled") -> void:
	for run in running.duplicate():
		if run["id"] == id:
			cancel(run, reason)
	queue = queue.filter(func(q: Dictionary) -> bool: return q["id"] != id)


## Marks running runs of an event, e.g. mark(&"silhouette", "seen") when the player spots it.
func mark(id: StringName, key: String) -> void:
	for run in running:
		if run["id"] == id:
			run[key] = true


func tick(delta: float) -> void:
	for run in running.duplicate():
		if run["state"] != State.RUNNING:  # a run before it in this tick ended and cancelled it (a death)
			continue
		run["elapsed"] += delta
		var ev: HorrorEvent = events[run["id"]]
		var done := ev.update(ctx, run, delta)
		if run.get("failed", false):
			_end(run, State.FAILED)
		elif done:
			_end(run, State.COMPLETED)
		elif run["elapsed"] > run["timeout"]:
			run["reason"] = "timeout"
			_end(run, State.FAILED)
	if queue.is_empty():
		return
	var pending := queue
	queue = []
	for q: Dictionary in pending:
		var run := check(q["id"], q["params"], q["priority"])
		if run["state"] == State.VALIDATED:
			begin(run)
		if run["state"] == State.RUNNING or _satisfied(run):
			continue
		if run["reason"] != q["reason"]:
			q["reason"] = run["reason"]
			_log("%s still queued (%s)" % [q["id"], run["reason"]])
		queue.append(q)


func is_running(id: StringName) -> bool:
	return running.any(func(r: Dictionary) -> bool: return r["id"] == id)


func is_queued(id: StringName) -> bool:
	return queue.any(func(q: Dictionary) -> bool: return q["id"] == id)


func adaptive_running() -> bool:
	return running.any(func(r: Dictionary) -> bool: return r["priority"] == 0)


func _end(run: Dictionary, state: State) -> void:
	run["state"] = state
	running.erase(run)
	var result: StringName = RESULT[state]
	events[run["id"]].finish(ctx, run, result)
	_log("%s %s%s" % [run["id"], result, "" if run["reason"] == "" else " (%s)" % run["reason"]])
	WorldState.record_event({"id": run["id"], "room": run["room"], "t": snappedf(ctx.now(), 0.01), "result": result, "priority": run["priority"]})
	EventBus.horror_event_finished.emit(run["id"], result)
	run_finished.emit(run)


## The world is already the way the request wants it.
static func _satisfied(run: Dictionary) -> bool:
	return String(run["reason"]).contains("already")


func _shares_channel(a: Dictionary, b: Dictionary) -> bool:
	for c: String in a["channels"]:
		if (b["channels"] as Array).has(c):
			return true
	return false


func _log(line: String) -> void:
	log_lines.append("[%6.2f] %s" % [ctx.now(), line])
	if log_lines.size() > LOG_LIMIT:
		log_lines.pop_front()
