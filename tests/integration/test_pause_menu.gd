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
