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
		var caption := hud._caption.get_global_rect()
		near(caption.get_center().x, screen.size.x / 2, 0.5, tag + "caption centred")
		near(caption.end.y, sub.position.y, 0.5, tag + "caption just above the subtitle")
		for l: Label in [hud._prompt, hud._objective, hud._clock, hud._caption, hud._subtitle]:
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


## Spoken lines and the answer he picks are heard (Voices). A sound caption leaves a voice talking, and a voiced line
## that comes while another is being said waits for it: the reply that follows his answer at once doesn't cut him off.
func test_lines_and_his_answers_are_heard() -> bool:
	var road := await _road()
	var hud := road.hud
	var hafiz := "Hafiz: \"Mei? Bro?\""
	EventBus.line_requested.emit(hafiz, 2.5)
	check(hud.voice.playing, "a line is heard")
	eq(hud.voice.stream, Voices.stream(hafiz), "in its own voice")
	EventBus.subtitle_requested.emit("[A car door shuts.]", 2.0)
	eq([hud.voice.stream, hud.next_voice], [Voices.stream(hafiz), null], "a sound caption leaves him talking")
	hud.voice.stop()
	EventBus.choices_requested.emit(&"t", PackedStringArray(["\"Three.\"", "\"Four.\""]))
	_press(KEY_2)
	eq(hud.voice.stream, Voices.stream("\"Four.\""), "his answer is heard")
	var reply := "Mei: \"Four meh? Wait, I count. One, two...\""
	EventBus.line_requested.emit(reply, 3.0)
	eq([hud.voice.stream, hud.next_voice], [Voices.stream("\"Four.\""), Voices.stream(reply)], "Mei's reply waits for him")
	hud.voice.finished.emit()
	eq([hud.voice.stream, hud.next_voice], [Voices.stream(reply), null], "and is heard once he has finished")
	road.queue_free()
	return true


func test_choice_box_fits_the_screen() -> bool:
	var road := await _road()
	var hud := road.hud
	var options := PackedStringArray()
	for i in 3:
		options.append(("%d Bro, please. Stay behind it. Nobody at the wheel. " % i).repeat(2).left(60))
	EventBus.choices_requested.emit(&"t", options)
	hud.show_subtitle("Mei: \"Eh… isn't that the same car?\"", 30.0, true)  # said by someone: the worst case sits on the subtitle
	var window := tree.root.size
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(2560, 1080)]:
		tree.root.size = size
		await tree.process_frame
		await tree.process_frame
		var screen := hud.get_viewport().get_visible_rect()
		var sub := hud._subtitle.get_global_rect()
		var caption := hud._caption.get_global_rect()
		var prompt := hud._prompt.get_global_rect()  # the door's prompt can be up while the stall's choices are
		var tag := "%dx%d: " % [size.x, size.y]
		eq(hud._choice_labels.filter(func(l: Label) -> bool: return l.visible).size(), 3, tag + "three options")
		for l: Label in hud._choice_labels:
			var r := l.get_global_rect()
			check(screen.encloses(r), tag + "%s on screen (%s)" % [l.text.left(12), r])
			check(not r.intersects(sub), tag + "%s clear of the subtitle (%s, %s)" % [l.text.left(12), r, sub])
			check(not r.intersects(caption), tag + "%s clear of the caption (%s, %s)" % [l.text.left(12), r, caption])
			check(not r.intersects(prompt), tag + "%s clear of the prompt (%s, %s)" % [l.text.left(12), r, prompt])
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
	eq(hud._caption.text, "", "a sound caption follows the setting")
	road.director.say("[You laughed. He didn't.]", 3.0)
	road.director.step(0.1)
	eq(hud._subtitle.text, "[You laughed. He didn't.]", "a road line always shows")
	road.queue_free()
	return true


## A sound caption has a line of its own, above the subtitle: it never cuts a spoken line short, and it follows the
## captions setting. A quoted line is dialogue and goes on the subtitle whatever the setting.
func test_a_sound_caption_never_cuts_a_spoken_line() -> bool:
	var road := await _road()
	var hud := road.hud
	var hafiz := "Hafiz: \"Mei! Wait for me!\""
	EventBus.line_requested.emit(hafiz, 5.0)
	EventBus.subtitle_requested.emit("[She is right behind you.]", 2.0)
	eq(hud._subtitle.text, hafiz, "the spoken line is still up")
	eq(hud._caption.text, "[She is right behind you.]", "and the caption has its own line")
	EventBus.subtitle_requested.emit("[Something lands on the roof]", 2.0)
	eq(hud._caption.text, "[Something lands on the roof]", "a new caption replaces the one on the caption line")
	eq(hud._subtitle.text, hafiz, "and still leaves the spoken line")
	hud._process(2.5)
	eq(hud._caption.text, "", "each line has its own timer: the caption has gone")
	eq(hud._subtitle.text, hafiz, "the spoken line has 2.5 s left")
	hud._process(2.6)
	eq(hud._subtitle.text, "", "and then it goes")
	Settings.values["subtitles"] = false
	EventBus.line_requested.emit(hafiz, 5.0)
	EventBus.subtitle_requested.emit("[She is right behind you.]", 2.0)
	eq(hud._caption.text, "", "captions off: no caption")
	eq(hud._subtitle.text, hafiz, "and the spoken line still shows")
	EventBus.subtitle_requested.emit("\"Hello? Sorry ah, so late.\"", 2.0)
	eq(hud._subtitle.text, "\"Hello? Sorry ah, so late.\"", "a quoted line goes on the subtitle, whatever the setting")
	eq(hud._caption.text, "", "and leaves the caption line alone")
	road.queue_free()
	return true


## A caption that wraps to two lines grows up, away from the subtitle's line, not down into it.
func test_a_long_caption_grows_up_not_into_the_subtitle() -> bool:
	var road := await _road()
	var hud := road.hud
	hud._caption.add_theme_font_size_override("font_size", 34)  # the trailer's size
	EventBus.subtitle_requested.emit("[Your work shoes, in the middle of the floor. You always leave them on the rack.]", 3.0)
	for i in 3:
		await tree.process_frame
	eq(hud._caption.get_line_count(), 2, "the caption wraps to two lines")
	var caption := hud._caption.get_global_rect()
	var sub := hud._subtitle.get_global_rect()
	check(caption.end.y <= sub.position.y + 0.5, "and its bottom stays above the subtitle's top (%s, %s)" % [caption, sub])
	check(hud.get_viewport().get_visible_rect().encloses(caption), "on screen (%s)" % caption)
	road.queue_free()
	return true


## The road's sounds are captioned the way the flat's are: on subtitle_requested, shown only with "Captions for sounds"
## on. The first thump on the roof gets its caption and each one after an "again"; every overtake gets the roar.
func test_road_sounds_are_captioned_with_captions_on() -> bool:
	var road := await _road()
	var hud := road.hud
	var captions: Array[String] = []
	var seconds: Array[float] = []
	var heard := func(text: String, secs: float) -> void:
		captions.append(text)
		seconds.append(secs)
	EventBus.subtitle_requested.connect(heard)
	EventBus.road_cue.emit(&"thump")
	eq(captions, ["[Something lands on the roof]"] as Array[String], "a thump is captioned")
	eq(hud._caption.text, "[Something lands on the roof]", "and it shows, captions on")
	EventBus.road_cue.emit(&"thump")
	EventBus.road_cue.emit(&"thump")
	eq(captions, ["[Something lands on the roof]", "[It moves on the roof.]", "[It moves on the roof.]"] as Array[String],
			"the first is the landing, each one after it moves")
	eq(seconds.slice(1), [2.5, 2.5] as Array[float], "for 2.5 s")
	eq(hud._caption.text, "[It moves on the roof.]", "and it shows")
	captions.clear()
	seconds.clear()
	EventBus.road_cue.emit(&"overtake")
	EventBus.road_cue.emit(&"overtake")
	eq(captions, ["[The engine roars.]", "[The engine roars.]"] as Array[String], "every overtake roars")
	eq(seconds, [2.5, 2.5] as Array[float], "for 2.5 s")
	eq(hud._caption.text, "[The engine roars.]", "and it shows")
	captions.clear()
	EventBus.road_cue.emit(&"knock_window")
	EventBus.road_cue.emit(&"knock_window")
	eq(captions, ["[Knocking on Mei's window]"] as Array[String], "the knocks stay one caption for the set")
	road.queue_free()
	await tree.process_frame
	road = await _road()
	Settings.values["subtitles"] = false
	captions.clear()
	for cue: StringName in [&"thump", &"thump", &"overtake"]:
		EventBus.road_cue.emit(cue)
	eq(captions.size(), 3, "with captions off they go out on the same signal, as the flat's do")
	eq(road.hud._caption.text, "", "but do not show")
	EventBus.subtitle_requested.disconnect(heard)
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


var _retried := 0


func _on_retry() -> void:
	_retried += 1


## GAME OVER: an opaque black card over every other element of the HUD, the cause's line under the title, and a
## Try again button the mouse can press (the mouse is shown again: on the web that also lets go of the pointer lock).
func test_game_over_shows_its_title_line_and_try_again() -> bool:
	var hud := Hud.new()
	tree.root.add_child(hud)
	await tree.process_frame
	check(not hud.is_game_over_shown(), "not before a death")
	var mode := Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	hud.show_game_over("[You looked back.]")
	check(hud.is_game_over_shown(), "shown")
	eq(hud._game_over_title.text, "GAME OVER", "with its title")
	eq(hud._game_over_line.text, "[You looked back.]", "and the line it was given")
	eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "the mouse is back")
	near(hud._game_over.color.a, 1.0, 0.001, "the card is opaque")
	eq(hud._game_over.get_index(), hud._game_over.get_parent().get_child_count() - 1, "and the last child: over the prompt, the captions, the choices, every card")
	await tree.process_frame  # laid out
	hud.retry_pressed.connect(_on_retry)
	_retried = 0
	var at := hud._retry.get_global_rect().get_center()
	check(hud.get_viewport().get_visible_rect().has_point(at), "the button is on screen (%s)" % at)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = true
	tree.root.push_input(click, true)
	click = click.duplicate()
	click.pressed = false
	tree.root.push_input(click, true)
	eq(_retried, 1, "a click on Try again emits retry_pressed, once")
	Input.mouse_mode = mode
	hud.queue_free()
	return true


## A choice or a caption that is up when he dies is closed, not left to show over the card.
func test_game_over_closes_choices_and_captions() -> bool:
	var hud := Hud.new()
	tree.root.add_child(hud)
	await tree.process_frame
	hud.show_choices(&"t", PackedStringArray(["\"Don't.\"", "\"Go.\""]))
	hud.show_subtitle("Mei: \"That's him! I'm opening\u2014\"", 30.0, true)
	hud.show_subtitle("[Knocking on Mei's window]", 30.0)
	check(hud.is_choosing() and hud._subtitle.text != "" and hud._caption.text != "", "a choice, a line and a caption are up")
	hud.show_game_over("[You opened the door.]")
	check(not hud.is_choosing(), "the choice is closed")
	eq(hud._subtitle.text, "", "the line is cleared")
	eq(hud._caption.text, "", "and the caption")
	for over: Control in [hud._choices, hud._subtitle, hud._caption]:
		check(hud._game_over.get_index() > over.get_index(), "%s is under the card" % over.name)
	hud.queue_free()
	return true
