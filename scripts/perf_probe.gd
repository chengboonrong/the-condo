class_name PerfProbe
extends Node
## `-- --perf` (desktop) or `?perf` (web): a scripted tour of every room with a scare every 3 s and the
## phone light on in every other room, then one report of frame time, render time, simulation cost, memory
## and load time. Desktop turns vsync off so frame times show the real cost; browsers always cap at the
## display's refresh rate. docs/performance.md has the results and how to run it.

const ROOM_SECONDS := 5.0
const SCARE_EVERY := 3.0
const TOUR: Array[StringName] = [&"living", &"kitchen", &"entrance", &"hallway", &"bathroom", &"bedroom", &"gap", &"mirror_room"]

var hud: Hud
var player: PlayerController
var runtime: HorrorRuntime
var _vp: RID
var scene_ready_msec := 0
var _warm_msec := 0
var _last_usec := 0
var _t := 0.0
var _room := -1
var _scares := 0
var _frame := PackedFloat32Array()
var _cpu := PackedFloat32Array()
var _gpu := PackedFloat32Array()
var _draws := PackedFloat32Array()
var _steps := PackedFloat32Array()
var _slow: Array[Array] = []  # frames over 25 ms (a missed frame even at 60 Hz): ms, when, where


func _ready() -> void:
	_warm_msec = Time.get_ticks_msec()  # main adds the probe once the shader warm-up is done
	_vp = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp, true)
	if not OS.has_feature("web"):
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	hud.start()


func _physics_process(_delta: float) -> void:
	if _room >= 0:
		_steps.append(runtime.last_step_usec)  # main (the parent) stepped the simulation just before this


func _process(delta: float) -> void:
	# Wall-clock interval between frames: `delta` is smoothed to line up with physics ticks.
	var now := Time.get_ticks_usec()
	var ms := (now - _last_usec) / 1000.0
	var first := _last_usec == 0  # the frame the probe was added in is not part of the tour
	_last_usec = now
	if first:
		return
	_t += delta
	var room := int(_t / ROOM_SECONDS)
	if room >= TOUR.size():
		set_process(false)
		set_physics_process(false)
		_report()
		return
	if room != _room:
		_room = room
		while TOUR[room] == &"gap" and WorldState.get_variant(&"bedroom") != &"door" and WorldState.act < WorldState.Act.DECISION:
			runtime.story.debug_skip()  # acts 2 and 3, then the bedroom window becomes a door
		player.global_position = ApartmentLayout.room_center(TOUR[room], WorldState.variants)
		player.phone_light.visible = room % 2 == 1
	player.set_look(fmod(_t, ROOM_SECONDS) / ROOM_SECONDS * TAU)
	if _t >= (_scares + 1) * SCARE_EVERY:
		runtime.debug_trigger(_scares % HorrorRuntime.DEBUG_EVENTS.size())  # refused if its preconditions fail
		_scares += 1
	_frame.append(ms)
	if ms > 25.0:
		var last: String = String(WorldState.event_history.back()["id"]) if not WorldState.event_history.is_empty() else "-"
		_slow.append([ms, "%.0f ms at %.1f s in the %s (last event %s)" % [ms, _t, TOUR[room], last]])
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _report() -> void:
	var web := OS.has_feature("web")
	var d := runtime.director
	var mb := func(monitor: Performance.Monitor) -> float: return Performance.get_monitor(monitor) / 1048576.0
	var static_mb: String = "static %.1f (peak %.1f)" % [mb.call(Performance.MEMORY_STATIC), mb.call(Performance.MEMORY_STATIC_MAX)] if mb.call(Performance.MEMORY_STATIC_MAX) > 0.0 else "static n/a (release builds don't track it)"
	var started := WorldState.event_history.size()
	print("\n".join(PackedStringArray([
		"PERF %s | %s | window %dx%d | 3D scale %.2f | vsync %s | %.1f s, %d frames, %d events started" % [OS.get_name(), RenderingServer.get_video_adapter_name(), get_window().size.x, get_window().size.y, get_window().scaling_3d_scale, "on (browser)" if web else "off", _t, _frame.size(), started],
		"PERF frame ms: avg %.2f (%.0f fps) p50 %.2f p95 %.2f p99 %.2f max %.2f" % [_avg(_frame), 1000.0 / _avg(_frame), _pct(_frame, 0.5), _pct(_frame, 0.95), _pct(_frame, 0.99), _pct(_frame, 1.0)],
		"PERF render ms: cpu avg %.2f p95 %.2f | gpu %s" % [_avg(_cpu), _pct(_cpu, 0.95), "avg %.2f p95 %.2f" % [_avg(_gpu), _pct(_gpu, 0.95)] if _pct(_gpu, 1.0) > 0.0 else "not reported by this renderer"],
		"PERF frames over 25 ms: %d, over 50 ms: %d | worst: %s" % [_slow.size(), _over(50.0), _worst()],
		"PERF simulation step µs: avg %.0f p95 %.0f max %.0f (%d steps) | director eval µs: avg %.0f max %d (%d evals)" % [_avg(_steps), _pct(_steps, 0.95), _pct(_steps, 1.0), _steps.size(), float(d.total_eval_usec) / maxi(d.eval_count, 1), d.max_eval_usec, d.eval_count],
		"PERF draw calls: avg %.0f max %.0f | memory MB: %s, video %.1f | objects %d" % [_avg(_draws), _pct(_draws, 1.0), static_mb, mb.call(Performance.RENDER_VIDEO_MEM_USED), Performance.get_monitor(Performance.OBJECT_COUNT)],
		"PERF load ms after engine start: condo built %d, shader warm-up done %d" % [scene_ready_msec, _warm_msec],
	])))
	if not web:
		get_tree().quit()


func _worst() -> String:
	_slow.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	return ", ".join(_slow.slice(0, 6).map(func(s: Array) -> String: return s[1])) if not _slow.is_empty() else "-"


func _over(ms: float) -> int:
	var n := 0
	for v in _frame:
		if v > ms:
			n += 1
	return n


static func _avg(a: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in a:
		sum += v
	return sum / maxi(a.size(), 1)


static func _pct(a: PackedFloat32Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var s := a.duplicate()
	s.sort()
	return s[mini(int(p * s.size()), s.size() - 1)]
