class_name HorrorRuntime
extends Node
## Composition root of the simulation core. One seeded RNG; one fixed tick order:
## time → profiler → entity → story → scheduler → director.
## The game calls step() from _physics_process; tests and simulated playthroughs call it directly.

const EVENTS_DIR := "res://resources/horror_events"
## Debug keys F5–F9 in the brief's order: knocks, lights, door, footsteps, silhouette.
const DEBUG_EVENTS: Array[StringName] = [&"knock_wall", &"light_flicker", &"door_slam", &"footsteps", &"silhouette"]

var rng := RandomNumberGenerator.new()
var graph: RoomGraph
var ctx: EventContext
var scheduler: EventScheduler
var profiler: BehaviorProfiler
var entity: EntityController
var director: HorrorDirector
var transformer: RoomTransformer
var story: StoryDirector
var story_running := false
var dead: StringName = &""  # what killed him (EventBus.player_died), once
var _sightings: Array[StringName] = []  # silhouettes seen since the last step
var last_step_usec := 0


func setup(stage: HorrorStage, seed_value: int) -> void:
	rng.seed = seed_value
	graph = stage.graph
	ctx = EventContext.new()
	ctx.graph = graph
	ctx.stage = stage
	ctx.rng = rng
	profiler = BehaviorProfiler.new(graph)
	entity = EntityController.new(graph, rng)
	entity.stage = stage
	entity.killed.connect(die)
	transformer = RoomTransformer.new(graph, stage)
	ctx.profiler = profiler
	ctx.entity = entity
	ctx.transformer = transformer
	scheduler = EventScheduler.new(ctx)
	scheduler.load_dir(EVENTS_DIR)
	scheduler.run_started.connect(_on_run_started)
	scheduler.run_finished.connect(_on_run_finished)
	director = HorrorDirector.new(scheduler, profiler)
	story = StoryDirector.new(scheduler, transformer)
	story.killed.connect(die)
	entity.story = story
	EventBus.silhouette_seen.connect(_on_silhouette_seen)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and entity != null:
		entity.story = null  # entity -> story -> scheduler -> ctx -> entity would keep all of them alive


func _exit_tree() -> void:
	if EventBus.silhouette_seen.is_connected(_on_silhouette_seen):
		EventBus.silhouette_seen.disconnect(_on_silhouette_seen)


## Advances the whole simulation by delta seconds.
func step(delta: float) -> void:
	if dead != &"":  # nothing goes on for the dead but the clock: not even what he saw before
		WorldState.advance_time(delta)
		return
	var t0 := Time.get_ticks_usec()
	for _anchor in _sightings:  # applied inside the tick, so the core's order never depends on frame rate
		scheduler.mark(&"silhouette", "seen")
		entity.notice()
	_sightings.clear()
	WorldState.advance_time(delta)
	profiler.observe(delta, ctx.stage.sample())
	entity.tick(delta)
	if dead != &"":  # it got him: the story and the scheduler do not run on after that
		return
	if story_running:
		story.tick(delta)
	scheduler.tick(delta)
	director.tick(delta)
	WorldState.behavior["tension"] = director.tension
	last_step_usec = Time.get_ticks_usec() - t0


## The story begins when the player dismisses the start card (tests and bots call it directly).
func start_story() -> void:
	story_running = true


## He dies of `cause`, once, and never after an ending: the story stops and nothing it started or asked for goes on.
## Whoever shows his death (Main) answers EventBus.player_died.
func die(cause: StringName) -> void:
	if dead != &"" or WorldState.ending != &"":
		return
	dead = cause
	story_running = false
	for run in scheduler.running.duplicate():
		scheduler.cancel(run, "died")
	scheduler.queue.clear()
	EventBus.player_died.emit(cause)


## Debug: start event n (0-based) now. Preconditions and cooldowns still apply; only the act gate is skipped.
func debug_trigger(index: int) -> Dictionary:
	return scheduler.start(DEBUG_EVENTS[index], {"ignore_act": true, "debug": true})


func debug_lines() -> Array[String]:
	var s := profiler.signals
	var lines: Array[String] = ["behaviour  cur %.2f  avo %.2f  look %.2f  hes %.2f  light %.2f  idle %.2f" % [
		s["curiosity"], s["avoidance"], s["look_behind"], s["hesitation"], s["light_dependence"], s["idle"]]]
	lines.append_array(director.debug_lines())
	lines.append("story %s (%.0fs)   signs %d/%d   clues %s" % [story.beat, story.beat_time(), story.signs(), StoryDirector.SIGNS_NEEDED, WorldState.clues.keys()])
	return lines


## Sounds from another room are stimuli: the profiler watches whether the player goes towards them.
func _on_run_started(run: Dictionary) -> void:
	var channels: Array = run["channels"]
	if channels.has("audio_major") or channels.has("door"):
		profiler.note_stimulus(run["room"])


## A run that ended with a rule he broke (VisitorEvent's "kill") is his death.
func _on_run_finished(run: Dictionary) -> void:
	if run.has("kill"):
		die(run["kill"])


func _on_silhouette_seen(anchor: StringName) -> void:
	_sightings.append(anchor)
