extends TestCase
## The road comes first: it hands over to the flat, the flat wakes at 11:47, both restart paths go back to the
## road, and the road keeps the flat's pointer-lock rule. Each test puts Journey back as it found it.

var _was_changing := true
var _was_ending: StringName = &""


func _begin() -> void:
	_was_changing = Journey.change_scenes
	_was_ending = Journey.road_ending
	Journey.change_scenes = false
	Journey.road_ending = &""


func _end() -> void:
	Journey.change_scenes = _was_changing
	Journey.road_ending = _was_ending


## Both scenes set `loaded` once their warm-up is done.
func _loaded(node: Node) -> void:
	for i in 600:
		if node.get("loaded"):
			return
		await tree.process_frame


func _scene(path: String) -> Node3D:
	var node: Node3D = load(path).instantiate()
	tree.root.add_child(node)
	return node


func test_flat_opened_directly_keeps_its_start_card() -> bool:
	_begin()
	var main := _scene(Journey.FLAT_SCENE)
	await _loaded(main)
	check(main.hud.is_on_start_card(), "start card shown")
	check(not main.hud.is_card_shown(), "and no wake card")
	check(not main.runtime.story_running, "story waits for the click")
	main.queue_free()
	_end()
	return true


func test_arriving_from_the_road_wakes_at_1147() -> bool:
	_begin()
	for ending: StringName in [&"alive", &"saved", &"caught"]:
		Journey.road_ending = ending
		var main := _scene(Journey.FLAT_SCENE)
		check(main.hud.is_card_shown(), "%s: wake card from the first frame" % ending)  # before the warm-up ends
		eq(main.hud.card_text(), "11:47 PM", "%s: same card for every road ending" % ending)
		await _loaded(main)
		check(not main.hud.is_on_start_card(), "%s: no start card" % ending)
		check(main.runtime.story_running, "%s: the story starts without a click" % ending)
		check(main.player.input_enabled, "%s: and he can move" % ending)
		eq(WorldState.clock_minutes(), 23 * 60 + 47, "%s: the clock reads 11:47" % ending)
		main.queue_free()
		await tree.process_frame
	_end()
	return true


func test_the_road_hands_over_on_the_click() -> bool:
	_begin()
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	await _loaded(road)
	check(road.hud.is_on_start_card(), "the road shows the start card")
	var ended := []
	road.finished.connect(func(ending: StringName) -> void: ended.append(ending))
	road.hud.start()
	eq(ended, [&"alive"], "for now, the road ends at once, all alive")  # from Task 2 on: road.director.debug_skip() until it ends
	eq(Journey.road_ending, &"alive", "Journey carries it")
	road.hud.start()
	eq(ended, [&"alive"], "a second start does nothing")
	road.queue_free()
	_end()
	return true


func test_restart_goes_back_to_the_road() -> bool:
	_begin()
	var main := _scene(Journey.FLAT_SCENE)
	await _loaded(main)
	Journey.road_ending = &"caught"
	var restart: Array = main.pause.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "Restart")
	eq(restart.size(), 1, "the pause menu has one Restart button")
	(restart[0] as Button).pressed.emit()
	eq(Journey.road_ending, &"", "Restart clears the road's ending")
	check(not tree.paused, "and unpauses")
	Journey.road_ending = &"caught"
	WorldState.set_ending(&"vacant")
	for i in 400:
		if main.hud.is_ending_shown():
			break
		await tree.process_frame
	check(main.hud.is_ending_shown(), "the ending card comes up")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(800, 450)
	tree.root.push_input(click, true)
	eq(Journey.road_ending, &"", "the ending card's click clears it too")  # both call sites go through Journey.restart()
	main.queue_free()
	_end()
	return true


func test_road_guards_pointer_lock_like_the_flat() -> bool:
	_begin()
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	await _loaded(road)
	var pause := road.pause
	var mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause.guard(0.3, true, true)
	check(not pause.is_open(), "0.3 s in play without pointer lock: not yet")
	pause.guard(0.3, true, true)
	check(pause.is_open(), "0.6 s: the menu opens")
	pause.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pause.guard(1.0, false, true)
	check(not pause.is_open(), "never while not playing")
	pause.guard(1.0, true, false)
	check(not pause.is_open(), "never off the web")
	pause.guard(0.3, true, true)  # the half second counts from the last time the lock was held
	check(not pause.is_open(), "(the clock was reset by the ticks that did not count)")
	Input.mouse_mode = mode
	road.queue_free()
	_end()
	return true


func test_road_pauses_when_the_window_loses_focus() -> bool:
	_begin()
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	await _loaded(road)
	road.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not road.pause.is_open(), "not before the start")
	road.player.input_enabled = true
	road.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(road.pause.is_open(), "in play, losing focus pauses")
	road.pause.close()
	road.queue_free()
	_end()
	return true


func test_the_card_fades_out_over_the_labels_and_under_the_subtitles() -> bool:
	_begin()
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	await _loaded(road)
	var hud := road.hud
	check(not hud.is_card_shown(), "no card to begin with")
	hud.show_card("")
	check(hud.is_card_shown(), "shown")
	var root := hud._clock.get_parent()
	check(hud._card.get_parent() == root, "(in the labels' root)")
	check(hud._card.get_index() > hud._clock.get_index(), "over the HUD labels")
	check(hud._card.get_index() < hud._subtitle.get_index(), "and under the subtitles")
	hud.hide_card(0.1)
	check(hud.is_card_shown(), "still there while it fades")
	for i in 20:
		await tree.process_frame
	check(not hud.is_card_shown(), "gone after the fade")
	hud.show_card("again")
	near(hud._card.modulate.a, 1.0, 0.001, "a new card starts opaque")
	eq(hud.card_text(), "again", "with its own text")
	hud.hide_card(0.0)
	check(not hud.is_card_shown(), "no seconds, no fade")
	road.queue_free()
	_end()
	return true
