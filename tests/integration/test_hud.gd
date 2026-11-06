extends TestCase
## The HUD's text sits where it was laid out, whatever the screen's size and shape.


func test_hud_labels_follow_their_anchors() -> bool:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var hud: Hud = main.hud
	var window := tree.root.size
	for size: Vector2i in [Vector2i(1600, 900), Vector2i(2560, 1080), Vector2i(900, 1200)]:
		tree.root.size = size
		await tree.process_frame
		var screen := hud.get_viewport().get_visible_rect()
		var tag := "%dx%d window, %s screen: " % [size.x, size.y, screen.size]
		var prompt := hud._prompt.get_global_rect()
		near(prompt.get_center().x, screen.size.x / 2, 0.5, tag + "prompt centred")
		near(prompt.position.y, screen.size.y / 2 + 28, 0.5, tag + "prompt just under the crosshair")
		var clock := hud._clock.get_global_rect()
		near(clock.end.x, screen.size.x - 32, 0.5, tag + "clock against the right edge")
		near(clock.position.y, 26, 0.5, tag + "clock at the top")
		var sub := hud._subtitle.get_global_rect()
		near(sub.get_center().x, screen.size.x / 2, 0.5, tag + "subtitle centred")
		near(sub.end.y, screen.size.y - 40, 0.5, tag + "subtitle above the bottom edge")
		for l: Label in [hud._prompt, hud._objective, hud._clock, hud._subtitle]:
			check(screen.encloses(l.get_global_rect()), tag + "%s on screen" % l.get_global_rect())
	tree.root.size = window
	main.queue_free()
	return true


## The road's choices: the core opens and closes them; the HUD only shows them and passes on one key press.
func _road() -> RoadMain:
	var road: RoadMain = load("res://scenes/road.tscn").instantiate()
	tree.root.add_child(road)
	await tree.process_frame
	return road


var _made: Array = []


func _on_made(choice_id: StringName, index: int) -> void:
	_made.append([choice_id, index])


func _press(key: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = true
	tree.root.push_input(ev)


func test_choices_close_only_when_the_core_says() -> bool:
	var road := await _road()
	var hud := road.hud
	check(not hud.is_choosing(), "no choice to begin with")
	EventBus.choices_requested.emit(&"t", PackedStringArray(["\"Don't, bro.\"", "\"Ya lah, go.\""]))
	check(hud.is_choosing(), "the core opens one")
	for i in 30 * 60:
		await tree.process_frame
	check(hud.is_choosing(), "30 s later it is still open: the HUD never closes it by itself")
	EventBus.choices_closed.emit(&"other")
	check(hud.is_choosing(), "another choice's close is not this one's")
	EventBus.choices_closed.emit(&"t")
	check(not hud.is_choosing(), "the core closes it")

	# Paused during a choice (Esc, a lost focus, or the web dropping pointer lock): it stays open, and its timer
	# stands still, so no rule breaks.
	hud.start()
	road.director.ask(&"p", PackedStringArray(["\"Don't.\"", "\"Go.\""]), 5.0, PackedInt32Array([0]), &"r")
	road.pause.open()
	_made.clear()
	EventBus.choice_made.connect(_on_made)
	_press(KEY_2)
	for i in 30 * 60:
		await tree.process_frame
	check(hud.is_choosing(), "paused 30 s: still open")
	eq(road.director.answer(&"p"), RoadDirector.NONE, "no silence counted while paused")
	eq([_made, road.director.score()], [[], 0], "no key answers it while paused, and nothing breaks")
	EventBus.choice_made.disconnect(_on_made)
	road.pause.close()
	road.queue_free()
	return true


func test_stray_choice_keys_do_nothing() -> bool:
	var road := await _road()
	_made.clear()
	EventBus.choice_made.connect(_on_made)
	_press(KEY_1)
	eq(_made, [], "1 with no choice open: nothing")
	EventBus.choices_requested.emit(&"t", PackedStringArray(["a", "b"]))
	_press(KEY_3)
	eq(_made, [], "3 when there are two options: nothing")
	_press(KEY_KP_2)
	_press(KEY_1)
	eq(_made, [[&"t", 1]], "the keypad's 2 answers; a second press in the same choice does nothing")
	EventBus.choices_closed.emit(&"t")
	_press(KEY_2)
	eq(_made, [[&"t", 1]], "after it has closed: nothing")
	EventBus.choices_requested.emit(&"u", PackedStringArray(["a", "b", "c"]))
	_press(KEY_3)
	eq(_made, [[&"t", 1], [&"u", 2]], "the next choice takes a key again")
	EventBus.choice_made.disconnect(_on_made)
	road.queue_free()
	return true


func test_choice_box_fits_the_screen() -> bool:
	var road := await _road()
	var hud := road.hud
	var options := PackedStringArray()
	for i in 3:
		options.append(("%d Bro, please. Stay behind it. Nobody at the wheel. " % i).repeat(2).left(60))
	EventBus.choices_requested.emit(&"t", options)
	hud.show_subtitle("Mei: \"Eh… isn't that the same car?\"", 30.0)
	var window := tree.root.size
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080)]:
		tree.root.size = size
		await tree.process_frame
		await tree.process_frame
		var screen := hud.get_viewport().get_visible_rect()
		var sub := hud._subtitle.get_global_rect()
		var tag := "%dx%d: " % [size.x, size.y]
		eq(hud._choice_labels.filter(func(l: Label) -> bool: return l.visible).size(), 3, tag + "three options")
		for l: Label in hud._choice_labels:
			var r := l.get_global_rect()
			check(screen.encloses(r), tag + "%s on screen (%s)" % [l.text.left(12), r])
			check(not r.intersects(sub), tag + "%s clear of the subtitle (%s, %s)" % [l.text.left(12), r, sub])
			check(l.get_line_count() == 1, tag + "%s on one line" % l.text.left(12))
	tree.root.size = window
	road.queue_free()
	return true


## Captions off: what anyone on the road says or thinks still shows; only the sound captions go.
func test_road_lines_show_with_captions_off() -> bool:
	var road := await _road()
	var hud := road.hud
	Settings.values["subtitles"] = false
	EventBus.subtitle_requested.emit("[A lorry passes]", 3.0)
	eq(hud._subtitle.text, "", "a sound caption follows the setting")
	road.director.say("[You laughed. He didn't.]", 3.0)
	road.director.step(0.1)
	eq(hud._subtitle.text, "[You laughed. He didn't.]", "a road line always shows")
	road.queue_free()
	return true


## Both scenes show the start card before anything is played, so the gore is warned of whichever opens first.
func test_start_card_warns_of_gore() -> bool:
	for path in ["res://scenes/road.tscn", "res://scenes/main.tscn"]:
		var scene: Node3D = load(path).instantiate()
		tree.root.add_child(scene)
		await tree.process_frame
		var texts: Array[String] = []
		for l: Label in scene.hud._start.find_children("*", "Label", true, false):
			texts.append(l.text)
		var card := "\n".join(texts)
		check(card.contains("blood and gore"), "%s: the start card says blood and gore (%s)" % [path, card])
		check(card.contains("Reduced flashing and brightness: press Esc"), "%s: and still points to Esc" % path)
		scene.queue_free()
		await tree.process_frame
	return true
