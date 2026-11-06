class_name RoadPerf
extends PerfProbe
## `-- --perf` (desktop) or `?perf` (web) on the road, before the flat's own tour (PerfProbe): about 49 s through the
## road's heaviest moments, each stage reached by a skip (RoadDirector.start_at, debug_skip), then one report in
## PerfProbe's format with every line marked "PERF road", and the road hands over to the flat. As in the flat the view
## turns a full circle every TURN seconds and the phone light is on every other PHONE seconds. The stages:
##   drive   Mission 2, cruising through the tunnel as the fog goes from none to all, her glimpsed every 4 s
##   mirror  Mission 3: the mirror on with her in it, and seen as he turns round to her
##   roof    Mission 4: the car dies with her on its roof, and Hafiz walks off with his phone as a torch
##   walk    Mission 5: the walk to the light, her behind him
##   catch   the caught ending, from where it is decided to her at the camera
## docs/performance.md has the results.

## The report is out: the road hands over to the flat.
signal reported

## [stage, seconds, [[seconds in, a cue the route sends as the core would], ...]]
const STAGES := [
	[&"drive", 11.0, [[0.0, &"her_glimpse"], [4.0, &"her_glimpse"], [8.0, &"her_glimpse"]]],
	[&"mirror", 10.0, []],
	[&"roof", 8.0, [[0.0, &"her_on_roof"], [0.0, &"thump"], [3.0, &"thump"], [4.0, &"hafiz_leaves"], [6.0, &"thump"]]],
	[&"walk", 5.0, []],
	[&"catch", 15.0, []],
]
const TURN := 5.0
const PHONE := 4.0
const TUNNEL_IN := 10.0  # metres short of the tunnel the drive starts: through its 80 m in 10 s at cruising speed

var director: RoadDirector  # RoadMain's, as are the rest
var her: Penanggal
var _stage := 0
var _stage_t := 0.0  # seconds into the stage
var _cue: StringName = &"-"  # the last cue the road sent, for the report's slow frames


func _ready() -> void:
	super()  # starts the road
	EventBus.road_cue.connect(_on_cue)
	_enter(STAGES[0][0])  # before the core's first step, so Mission 1 never begins


func _process(delta: float) -> void:
	# Wall-clock interval between frames, as PerfProbe measures it.
	var now := Time.get_ticks_usec()
	var ms := (now - _last_usec) / 1000.0
	var first := _last_usec == 0  # the frame the route was added in is not part of it
	_last_usec = now
	if first:
		return
	_t += delta
	if _stage_t >= STAGES[_stage][1]:
		_stage += 1
		_stage_t = 0.0
		if _stage >= STAGES.size():
			set_process(false)
			_report()
			reported.emit()
			return
		_enter(STAGES[_stage][0])
	var stage: StringName = STAGES[_stage][0]
	for cue: Array in STAGES[_stage][2]:
		if cue[0] >= _stage_t and cue[0] < _stage_t + delta:
			EventBus.road_cue.emit(cue[1])
	_play(stage)
	_stage_t += delta
	_frame.append(ms)
	if ms > 25.0:
		_slow.append([ms, "%.0f ms at %.1f s in the %s (last cue %s)" % [ms, _t, stage, _cue]])
	_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp) + RenderingServer.get_frame_setup_time_cpu())
	_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp))
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


## The skip into a stage.
func _enter(stage: StringName) -> void:
	var d := director
	match stage:
		&"drive":  # from the start card: seated, cruising
			d.start_at(1)
			d.car_s = RoadLayout.TUNNEL.x - TUNNEL_IN
		&"mirror", &"walk":
			d.debug_skip()
		&"roof":  # where the car dies at once
			d.debug_skip()
			d.car_s = StallMission.STOP_S - d.car_speed * StallMission.DYING / 2.0
		&"catch":  # 30 m short of the light with every rule broken: it is decided at once, and she catches them
			player.use_scripted_move = false
			d.break_rule(&"perf", RoadDirector.SAVED_MAX + 1)
			d.start_at(4)
			player.global_position = RoadLayout.point(d.light_s - LightMission.DECIDE + 0.5, RoadLayout.LANE)
			her.hide_her()  # the walk puts her behind him again, where he is now


## Each frame of a stage: the view turns and the phone light switches; the fog thickens on the drive, and on the walk
## he walks down the road, whichever way he looks.
func _play(stage: StringName) -> void:
	var turn := fmod(_t, TURN) / TURN * TAU
	var s := RoadLayout.closest_s(player.global_position)
	player.set_look((PI if player.is_seated() else RoadBuilder.yaw_along(s)) + turn)  # seated, PI faces ahead
	player.phone_light.visible = int(_t / PHONE) % 2 == 1
	match stage:
		&"drive":
			director.fog = _stage_t / STAGES[_stage][1]
		&"walk":
			var down := player.global_basis.inverse() * RoadLayout.tangent(s)
			player.scripted_move = Vector2(down.x, -down.z)
			player.use_scripted_move = true


func _on_cue(cue: StringName) -> void:
	_cue = cue


func _report() -> void:
	var web := OS.has_feature("web")
	var mb := func(monitor: Performance.Monitor) -> float: return Performance.get_monitor(monitor) / 1048576.0
	var static_mb: String = "static %.1f (peak %.1f)" % [mb.call(Performance.MEMORY_STATIC), mb.call(Performance.MEMORY_STATIC_MAX)] if mb.call(Performance.MEMORY_STATIC_MAX) > 0.0 else "static n/a (release builds don't track it)"
	print("\n".join(PackedStringArray([
		"PERF road %s | %s | window %dx%d | 3D scale %.2f | vsync %s | %.1f s, %d frames, %d rules broken" % [OS.get_name(), RenderingServer.get_video_adapter_name(), get_window().size.x, get_window().size.y, get_window().scaling_3d_scale, "on (browser)" if web else "off", _t, _frame.size(), director.broken.size()],
		"PERF road frame ms: avg %.2f (%.0f fps) p50 %.2f p95 %.2f p99 %.2f max %.2f" % [_avg(_frame), 1000.0 / _avg(_frame), _pct(_frame, 0.5), _pct(_frame, 0.95), _pct(_frame, 0.99), _pct(_frame, 1.0)],
		"PERF road render ms: cpu avg %.2f p95 %.2f | gpu %s" % [_avg(_cpu), _pct(_cpu, 0.95), "avg %.2f p95 %.2f" % [_avg(_gpu), _pct(_gpu, 0.95)] if _pct(_gpu, 1.0) > 0.0 else "not reported by this renderer"],
		"PERF road frames over 25 ms: %d, over 50 ms: %d | worst: %s" % [_slow.size(), _over(50.0), _worst()],
		"PERF road draw calls: avg %.0f max %.0f | memory MB: %s, video %.1f | objects %d" % [_avg(_draws), _pct(_draws, 1.0), static_mb, mb.call(Performance.RENDER_VIDEO_MEM_USED), Performance.get_monitor(Performance.OBJECT_COUNT)],
		"PERF road load ms after engine start: road built %d, shader warm-up done %d" % [scene_ready_msec, _warm_msec],
	])))
