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
