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
	Journey.retry_mission = -1
	Journey.retry_broken = []
	Journey.flat_retry = {}


func _end() -> void:
	Journey.change_scenes = _was_changing
	Journey.road_ending = _was_ending
	Journey.retry_mission = -1
	Journey.retry_broken = []
	Journey.flat_retry = {}


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


## The debug skip, mission after mission, until the road ends (at most one call per mission, plus one).
func _skip_to_the_end(road: RoadMain) -> void:
	for i in road.director.missions.size() + 1:
		if road.director.ending != &"":
			return
		road.director.debug_skip()


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
	eq(ended, [], "the click starts the road, it doesn't end it")
	_skip_to_the_end(road)
	eq(ended, [&"alive"], "skipped through, nothing broken: all alive")
	eq(Journey.road_ending, &"alive", "Journey carries it")
	road.hud.start()
	eq(ended, [&"alive"], "a second start does nothing")
	road.queue_free()
	_end()
	return true


## Debug builds: F10 ends the current road mission, as if kept, as it skips a beat in the flat.
func test_f10_skips_a_road_mission() -> bool:
	_begin()
	check(OS.is_debug_build(), "(the tests run a debug build)")
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	await _loaded(road)
	road.hud.start()
	var ended := []
	road.finished.connect(func(ending: StringName) -> void: ended.append(ending))
	var f10 := InputEventKey.new()
	f10.physical_keycode = KEY_F10
	f10.pressed = true
	tree.root.push_input(f10)
	eq([road.director.mission_index, ended], [1, []], "the lift is skipped, and the next mission starts")
	for i in road.director.missions.size() - 1:
		tree.root.push_input(f10)
	eq([road.director.mission_index, ended], [road.director.missions.size(), [&"alive"]], "skipping the last one ends the road")
	road.queue_free()
	_end()
	return true


## A real scene change, with the road as the current scene as it is in the game (the runner has none, and a change
## only removes the one it has). A real click starts the road, and the road's end hands over: the scene must not be
## taken out from under whoever ends it, or their next line runs on a viewport that is gone.
func test_the_start_click_hands_over_without_an_error() -> bool:
	_begin()
	Journey.change_scenes = true
	var road := _scene(Journey.ROAD_SCENE) as RoadMain
	tree.current_scene = road
	await _loaded(road)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(800, 450)
	tree.root.push_input(click, true)
	check(road.is_inside_tree(), "the road is still there when the click returns")
	check(not road.hud.is_on_start_card(), "and it has started")
	_skip_to_the_end(road)
	eq(Journey.road_ending, &"alive", "Journey carries the ending at once")
	check(road.is_inside_tree(), "the road is still there when it ends")
	for i in 3:
		await tree.process_frame
	check(not is_instance_valid(road), "the road is gone a frame later")
	check(tree.current_scene != null and tree.current_scene.scene_file_path == Journey.FLAT_SCENE, "and the flat is the scene")
	_end()  # the flat is not ours to free: the runner frees what a test added
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
	check(hud._card.get_index() < hud._caption.get_index(), "and under the sound captions")
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


## Try again on the road: the mission he died in (0-based) and the count it began with, kept apart from the director that
## is about to be freed.
func test_retry_road_carries_the_mission_and_the_count() -> bool:
	_begin()
	eq(Journey.retry_mission, -1, "no retry to begin with")
	var kept: Array[Dictionary] = [{"rule": &"overtook", "weight": 1, "t": 12.0, "mission": 1}]
	Journey.retry_road(3, kept)
	eq(Journey.retry_mission, 3, "the mission")
	eq(Journey.retry_broken, kept, "and the count")
	kept.clear()
	eq(Journey.retry_broken.size(), 1, "a copy: the old director's own count does not change it")
	_end()
	return true


## Try again in the flat keeps how the road ended: the flat wakes as it did.
func test_retry_flat_keeps_the_road_ending() -> bool:
	_begin()
	Journey.road_ending = &"saved"
	Journey.retry_flat({"clock": 1234})
	eq(Journey.flat_retry, {"clock": 1234}, "the snapshot")
	eq(Journey.road_ending, &"saved", "and the road's ending")
	_end()
	return true


## Frames until cond() holds or `seconds` pass, with the physics step they run on. Returns whether it held.
func _until(cond: Callable, seconds: float) -> bool:
	for i in int(seconds * 60.0):
		if cond.call():
			return true
		await tree.physics_frame
	return cond.call()


## The flat's looping players that are sounding: everything under `audio` but its pool of one-shots.
func _playing(audio: AudioDirector) -> Array[Node]:
	var out: Array[Node] = []
	for p: Node in audio.find_children("*", "AudioStreamPlayer3D", false, false) + audio.find_children("*", "AudioStreamPlayer", false, false):
		if p.get("playing") and not (p is AudioStreamPlayer3D and audio._pool.has(p)):
			out.append(p)
	return out


## He dies in the flat's act 3: she comes, and the card follows once she is there, with the cause's line and nothing of the
## flat left over it, to see or to hear. Try again, a real click, keeps the act and how the road ended.
func test_a_death_in_the_flat_shows_game_over_and_try_again_keeps_the_act() -> bool:
	_begin()
	Journey.road_ending = &"saved"
	var main := _scene(Journey.FLAT_SCENE) as Main
	await _loaded(main)
	WorldState.set_flag(&"answered_intercom")
	main.runtime.story.debug_skip()  # act 2
	main.runtime.story.debug_skip()  # act 3
	EventBus.subtitle_requested.emit("[Knocking at the front door]", 30.0)
	EventBus.line_requested.emit("[Nobody there. The corridor is empty.]", 30.0)
	check(main.hud._caption.text != "" and main.hud._subtitle.text != "", "a caption and a line are up")
	var playing := _playing(main.audio)
	check(playing.size() >= 3, "(the flat's drone, hums and beds are playing: %d)" % playing.size())
	var reached: Array[bool] = []  # whether the card was up when she reached him: Main's own handler runs first
	main.her.reached.connect(func() -> void: reached.append(main.hud.is_game_over_shown()))
	main.runtime.die(&"front_door")
	await _until(func() -> bool: return false, 0.2)
	check(not main.player.input_enabled, "he is held")
	check(main.her.visible and not main.hud.is_game_over_shown(), "she comes, and there is no card yet")
	var early := false
	var came := await _until(func() -> bool:
		early = early or (main.hud.is_game_over_shown() and reached.is_empty())
		return not reached.is_empty(), 10.0)
	check(came, "she reaches him within 10 s")
	check(not early, "and the card was not up before")
	eq(reached, [true], "the card is up as she reaches him, once")
	eq(main.hud._game_over_line.text, Journey.DEATHS[&"front_door"], "with the cause's line")
	check(main.hud.is_card_shown(), "the black card is under it")
	check(main.hud._caption.text == "" and main.hud._subtitle.text == "", "no caption and no line left")
	check(not main.her.visible, "she is gone")
	playing = _playing(main.audio)
	check(playing.is_empty(), "the drone, the hums, the tap and the beds are off (%s)" % [playing.map(func(p: Node) -> String: return p.name)])
	var heard: Array[StringName] = []
	var on_sound := func(id: StringName, _at: Vector3, _db: float) -> void: heard.append(id)
	EventBus.sound_requested.connect(on_sound)
	await _until(func() -> bool: return false, 2.0)
	EventBus.sound_requested.disconnect(on_sound)
	eq(heard, [] as Array[StringName], "nothing new plays under the card (2 s)")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = main.hud._retry.get_global_rect().get_center()
	click.pressed = true
	tree.root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	tree.root.push_input(click, true)
	eq(Journey.flat_retry, main.runtime.story.act_snapshot, "Try again keeps the act's start")
	eq(Journey.flat_retry["act"], WorldState.Act.IMPOSSIBLE, "act 3")
	eq(Journey.road_ending, &"saved", "and how the road ended")
	main.queue_free()
	_end()
	return true


## The flat Try again loads: a plain black card (not the road's 11:47 PM one, and no start card), then he is playing at the
## act's start, with the road's ending and what he had done, and the card fades.
func test_try_again_starts_the_flat_at_the_act() -> bool:
	_begin()
	Journey.road_ending = &"caught"
	var first := _scene(Journey.FLAT_SCENE) as Main
	await _loaded(first)
	WorldState.set_flag(&"washed")
	WorldState.set_flag(&"answered_intercom")
	first.runtime.story.debug_skip()
	first.runtime.story.debug_skip()
	var snapshot: Dictionary = first.runtime.story.act_snapshot
	Journey.retry_flat(snapshot)
	first.queue_free()
	await tree.process_frame
	var main := _scene(Journey.FLAT_SCENE) as Main
	check(main.hud.is_card_shown() and main.hud.card_text() == "", "a plain black card from the first frame")
	await _loaded(main)
	check(not main.hud.is_on_start_card(), "no start card")
	check(main.runtime.story_running and main.player.input_enabled, "he is playing")
	eq(WorldState.act, WorldState.Act.IMPOSSIBLE, "at act 3")
	eq(main.runtime.story.beat, &"front_door", "with the knocking")
	check(WorldState.has_flag(&"washed") and WorldState.has_flag(&"answered_intercom"), "and what he had done")
	eq(main.runtime.story.road, &"caught", "the road's ending")
	check(not main.runtime.story.quiet(), "the flat is not holding its breath")
	eq(Journey.flat_retry, {}, "the retry is used up")
	eq(main.runtime.story.act_snapshot, snapshot, "and dying again retries the same start")
	var gone := await _until(func() -> bool: return not main.hud.is_card_shown(), 3.0)
	check(gone, "and the black card fades away")
	main.queue_free()
	_end()
	return true


func test_restart_clears_every_retry() -> bool:
	_begin()
	var kept: Array[Dictionary] = [{"rule": &"overtook", "weight": 1, "t": 12.0, "mission": 1}]
	Journey.road_ending = &"caught"
	Journey.retry_road(3, kept)
	Journey.retry_flat({"clock": 1234})
	Journey.restart()
	eq(Journey.retry_mission, -1, "no mission")
	eq(Journey.retry_broken.size(), 0, "no count")
	eq(Journey.flat_retry, {}, "no flat snapshot")
	eq(Journey.road_ending, &"", "and the road's ending")
	_end()
	return true


## The card has a line for every way he can die: the road's own rules and the core's other causes.
func test_every_cause_of_death_has_a_line() -> bool:
	var causes: Array[StringName] = RoadDirector.DEADLY.duplicate()
	causes.append_array([&"missed_lift", &"not_locked", &"stood_still"] as Array[StringName])
	for cause in causes:
		check(Journey.DEATHS.has(cause) and Journey.DEATHS[cause] != "", "%s has a line" % cause)
	return true
