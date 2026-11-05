extends TestCase
## Phase 6: Esc pauses everything and opens the settings; the settings change the game and persist.


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	var click := InputEventMouseButton.new()  # past the start card, as a player would
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(800, 450)
	tree.root.push_input(click, true)
	await tree.physics_frame
	await tree.physics_frame
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func _press_pause() -> void:
	var ev := InputEventAction.new()
	ev.action = &"pause"
	ev.pressed = true
	tree.root.push_input(ev)
	await tree.process_frame


func test_esc_pauses_everything_and_resumes() -> bool:
	var main := await _main()
	var menu: PauseMenu = main.pause
	await _press_pause()
	check(menu.is_open(), "Esc opens the pause menu")
	check(tree.paused, "and pauses the tree")
	var t := WorldState.time
	await _frames(30)
	eq(WorldState.time, t, "no simulation time passes")
	await _press_pause()
	check(not menu.is_open() and not tree.paused, "Esc again resumes")
	await _frames(10)
	check(WorldState.time > t, "and time runs again")
	main.queue_free()
	return true


func test_esc_while_reading_closes_the_note_not_the_game() -> bool:
	var main := await _main()
	main.hud.show_inspect("Note", "Text")
	await _press_pause()
	check(not main.hud.is_inspecting(), "Esc closes the note")
	check(not main.pause.is_open(), "without opening the menu")
	main.queue_free()
	return true


func test_settings_change_the_game_and_persist() -> bool:
	var main := await _main()
	var menu: PauseMenu = main.pause
	menu.open()
	var brightness: HSlider = menu.find_child("brightness", true, false)
	brightness.value = 1.4
	near(main.builder.environment.tonemap_exposure, 1.4, 0.001, "brightness sets the exposure")
	var flashing: Button = menu.find_child("reduced_flashing", true, false)
	flashing.button_pressed = true
	eq(Settings.get_value("reduced_flashing"), true, "reduced flashing is on")
	eq(flashing.text, "Reduced flashing: On", "and the menu says so")
	var cfg := ConfigFile.new()
	eq(cfg.load(Settings.path), OK, "settings are saved")
	eq(cfg.get_value("settings", "brightness"), 1.4, "with the new brightness")
	check(Settings.path != Settings.PATH, "(to the test file, not the player's)")
	menu.close()
	main.queue_free()
	return true


func test_settings_open_from_the_start_card_without_starting() -> bool:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await _frames(3)
	await _press_pause()
	check(main.pause.is_open(), "Esc on the start card opens the settings (reduced flashing before any flicker)")
	await _press_pause()
	check(not main.pause.is_open(), "Esc closes them again")
	check(main.hud.is_on_start_card(), "back on the start card")
	check(not main.player.input_enabled, "the game has not started")
	eq(WorldState.time, 0.0, "and no time has passed")
	main.queue_free()
	return true


func test_losing_focus_while_reading_pauses() -> bool:
	var main := await _main()
	main.hud.show_inspect("Note", "Text")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.pause.is_open(), "time runs behind a note, so alt-tab while reading pauses too")
	main.pause.close()
	main.queue_free()
	return true


func test_new_settings_change_the_game_at_once_and_persist() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var menu: PauseMenu = main.pause
	menu.open()
	(menu.find_child("fov", true, false) as HSlider).value = 64.0
	near(player.camera.fov, 64.0, 0.001, "field of view changes at once")
	var filter: Button = menu.find_child("filter", true, false)
	filter.button_pressed = false
	near(tree.root.scaling_3d_scale, 1.0, 0.001, "the filter turns off at once")
	eq(filter.text, "Filter: Off", "and the menu says so")
	menu.close()
	player.use_scripted_move = true
	player.set_look(-PI / 2)  # east from the spawn: 2 m of clear floor in a second (north is blocked at 0.5 m)
	player.scripted_move = Vector2(0, 1)
	var most := 0.0
	for i in 60:
		await tree.physics_frame
		most = maxf(most, absf(player.camera.position.y))
	check(player.horizontal_speed() > 1.5, "(walking, not stopped by a wall)")
	check(most > 0.005, "the head bobs at 100%")
	Settings.set_value("head_bob", 0.0)
	player.global_position = ApartmentLayout.SPAWN  # the same clear walk again
	await _frames(2)
	most = 0.0
	for i in 60:
		await tree.physics_frame
		most = maxf(most, absf(player.camera.position.y))
	check(player.horizontal_speed() > 1.5, "(walking)")
	near(most, 0.0, 0.0001, "and not at all at 0%")
	var cfg := ConfigFile.new()
	eq(cfg.load(Settings.path), OK, "saved")
	eq(cfg.get_value("settings", "fov"), 64.0, "with the field of view")
	eq(cfg.get_value("settings", "filter"), false, "the filter")
	eq(cfg.get_value("settings", "head_bob"), 0.0, "and the head bob")
	main.queue_free()
	return true


func test_old_settings_files_still_load() -> bool:
	var cfg := ConfigFile.new()  # saved before this pass: none of the new keys
	cfg.set_value("settings", "brightness", 1.3)
	cfg.save(Settings.path)
	Settings._ready()
	near(float(Settings.get_value("brightness")), 1.3, 0.001, "the player's old value is kept")
	eq(Settings.get_value("filter"), true, "new keys get their defaults: filter on")
	near(float(Settings.get_value("fov")), 72.0, 0.001, "field of view 72")
	near(float(Settings.get_value("head_bob")), 1.0, 0.001, "head bob 100%")
	return true


func test_the_menu_fits_the_window() -> bool:
	var main := await _main()
	main.pause.open()
	await tree.process_frame  # one layout pass
	var frame: Control = main.pause.find_child("Frame", true, false)
	check(tree.root.get_visible_rect().encloses(frame.get_global_rect()), "every row is on screen at 1600x900")
	main.pause.close()
	main.queue_free()
	return true
