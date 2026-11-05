extends TestCase
## The soft 3D picture: about 450 lines, bilinear, the HUD sharp, the grain at the 3D pixel size.


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	main.player.input_enabled = true  # past the start card: time only runs while playing
	await tree.physics_frame
	await tree.physics_frame
	return main


func test_the_filter_follows_the_window_height() -> bool:
	eq(Look.divisor_for(900), 2, "900 px tall: 450 lines")
	eq(Look.divisor_for(1080), 2, "1080: 540 lines")
	eq(Look.divisor_for(720), 2, "720: 360 lines is nearer 450 than 720")
	eq(Look.divisor_for(1440), 3, "1440: 480 lines")
	eq(Look.divisor_for(2160), 5, "2160: 432 lines")
	eq(Look.divisor_for(500), 1, "a small window stays sharp")
	return true


func test_the_filter_softens_the_3d_and_turns_off() -> bool:
	var main := await _main()
	var film: ShaderMaterial = main.hud.film_material
	eq(tree.root.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "bilinear, not nearest")
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "on by default: half resolution at 1600x900")
	near(float(film.get_shader_parameter("pixel_size")), 2.0, 0.001, "grain at the 3D pixel size")
	Settings.set_value("filter", false)
	near(tree.root.scaling_3d_scale, 1.0, 0.001, "off: full resolution")
	near(float(film.get_shader_parameter("pixel_size")), 1.0, 0.001, "and the grain as before")
	Settings.set_value("filter", true)
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "on again at once")
	main.queue_free()
	return true


func test_the_filter_follows_a_resized_window() -> bool:
	var main := await _main()
	tree.root.size = Vector2i(2560, 1440)
	await tree.process_frame
	near(tree.root.scaling_3d_scale, 1.0 / 3.0, 0.001, "1440 px tall: a third")
	near(float(main.hud.film_material.get_shader_parameter("pixel_size")), 3.0, 0.001, "grain follows")
	tree.root.size = Vector2i(1600, 900)  # the runner's size, for the tests after this one
	await tree.process_frame
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "back to a half")
	main.queue_free()
	return true
