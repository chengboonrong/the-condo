extends TestCase
## The soft 3D picture: about 450 lines, bilinear, the HUD sharp, the grain at the 3D pixel size.


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	main.player.input_enabled = true  # past the start card: time only runs while playing
	await tree.physics_frame
	await tree.physics_frame
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


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


func test_act_one_is_warm_and_full_from_the_first_frame() -> bool:
	var main := await _main()
	var env: Environment = main.builder.environment
	check(env.adjustment_enabled, "the grade is on from the start, so nothing compiles mid-game")
	near(env.adjustment_saturation, 1.08, 0.001, "act 1 saturation")
	near(env.adjustment_contrast, 1.02, 0.001, "act 1 contrast")
	var g: Gradient = (env.adjustment_color_correction as GradientTexture1D).gradient
	eq(g.get_color(1), Color(1.0, 0.96, 0.88), "a warm white")
	main.queue_free()
	return true


func test_each_act_eases_colder() -> bool:
	var main := await _main()
	var env: Environment = main.builder.environment
	WorldState.set_act(2)
	await _frames(30)  # half a second of a 4 s ease
	check(env.adjustment_saturation < 1.08 and env.adjustment_saturation > 0.62, "it eases, it does not cut")
	await _frames(250)
	near(env.adjustment_saturation, 0.62, 0.001, "act 2 saturation")
	near(env.adjustment_contrast, 1.08, 0.001, "act 2 contrast")
	WorldState.set_act(3)
	main.look.settle()
	check(env.adjustment_saturation < 0.62, "act 3 is more drained")
	check((env.adjustment_color_correction as GradientTexture1D).gradient.get_color(1).r < 0.88, "and colder")
	main.queue_free()
	return true


func test_b1107_is_the_most_drained() -> bool:
	for k: Variant in Look.GRADES:
		check(Look.GRADES[&"mirror_room"]["saturation"] <= Look.GRADES[k]["saturation"], "nothing is greyer than B-11-07 (%s)" % k)
	var main := await _main()
	WorldState.set_variant(&"bedroom", &"door")
	main.player.global_position = ApartmentLayout.room_center(&"mirror_room", WorldState.variants)
	await _frames(2)  # main sets player_room on the physics tick
	main.look.settle()
	near(main.builder.environment.adjustment_saturation, 0.34, 0.001, "B-11-07's grade")
	main.queue_free()
	return true


func test_a_new_shift_starts_warm() -> bool:
	WorldState.act = 3  # a cold act left over from the last shift; main resets it
	var main := await _main()
	near(main.builder.environment.adjustment_saturation, 1.08, 0.001, "warm at once, no ease from cold")
	main.queue_free()
	return true


func test_the_phone_light_shadow_has_depth_to_spare() -> bool:
	# Spot shadows are stored in the positional shadow atlas. At Godot's default 16 bits its depth runs out a few
	# metres from the phone, and the walls it reaches shadow themselves in stripes ("shadow acne"), more the
	# farther away; a bigger shadow bias only pushes them out (0.1 still striped a wall 6.5 m away).
	check(not ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/atlas_16_bits"),
		"the project's shadow atlas has 24-bit depth")
	check(not tree.root.positional_shadow_atlas_16_bits, "and so does the window that draws the game")
	return true


func test_the_phone_light_shadow_is_filled_and_soft() -> bool:
	# The phone is held below and right of the eye, so he sees the shadows it casts (the basin's rim inside its
	# bowl). With no bounce light in the renderer they were black, and the default filter drew them stair-stepped.
	var phone := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	var light := phone.get_node("Head/Camera3D/PhoneLight") as SpotLight3D
	check(light.shadow_enabled, "the phone light still casts shadows")
	check(light.shadow_opacity >= 0.5 and light.shadow_opacity < 1.0, "filled a little, as a lit room bounces it back")
	check(int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality")) >= 4,
		"and filtered soft enough that its edges don't step")
	phone.free()
	return true
