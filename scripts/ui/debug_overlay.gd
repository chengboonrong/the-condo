class_name DebugOverlay
extends CanvasLayer
## F3 toggles a live view of the simulation; F5–F9 fire events through the scheduler (debug builds only).

var runtime: HorrorRuntime
var _label: Label
var _flash := ""
var _flash_left := 0.0


func _ready() -> void:
	layer = 50
	visible = false
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.72)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(16, 90)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	_label.add_theme_font_override("font", SystemFont.new())
	(_label.get_theme_font("font") as SystemFont).font_names = PackedStringArray(["Menlo", "Consolas", "monospace"])
	panel.add_child(_label)
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
	if event.is_action_pressed("debug_skip_beat") and WorldState.ending == &"":
		runtime.start_story()
		runtime.story.debug_skip()
		_flash = "F10 → act %d (%s)" % [WorldState.act, runtime.story.beat]
		_flash_left = 3.0
	for i in HorrorRuntime.DEBUG_EVENTS.size():
		if event.is_action_pressed("debug_event_%d" % (i + 1)):
			var run := runtime.debug_trigger(i)
			_flash = "F%d %s → %s" % [i + 5, run["id"], "started" if run["state"] == EventScheduler.State.RUNNING else run["reason"]]
			_flash_left = 3.0


func _process(delta: float) -> void:
	_flash_left -= delta
	if not visible or runtime == null:
		return
	var s := runtime.scheduler
	var lines: Array[String] = []
	lines.append("act %d   room %s   t %.1fs   clock %02d:%02d" % [WorldState.act, WorldState.player_room, WorldState.time, WorldState.clock_minutes() / 60, WorldState.clock_minutes() % 60])
	lines.append("entity %s @ %s   variants %s" % [WorldState.entity_state, WorldState.entity_room, WorldState.variants])
	lines.append("running: %s" % ", ".join(s.running.map(func(r: Dictionary) -> String: return "%s(%s %.1fs)" % [r["id"], r["room"], r["elapsed"]])))
	lines.append("queued:  %s" % ", ".join(s.queue.map(func(q: Dictionary) -> String: return String(q["id"]))))
	var cds: Array[String] = []
	for id: StringName in s.sorted_ids():
		var left: float = s.cooldown_until.get(id, 0.0) - WorldState.time
		if left > 0.0:
			cds.append("%s %.0fs" % [id, left])
	lines.append("cooldown: %s" % ", ".join(cds))
	if runtime.has_method("debug_lines"):
		lines.append_array(runtime.debug_lines())
	lines.append("── log ──")
	lines.append_array(s.log_lines.slice(maxi(0, s.log_lines.size() - 10)))
	if _flash_left > 0.0:
		lines.append("── %s" % _flash)
	lines.append("F5 knock  F6 lights  F7 door  F8 footsteps  F9 silhouette  F10 skip to next act")
	_label.text = "\n".join(lines)
