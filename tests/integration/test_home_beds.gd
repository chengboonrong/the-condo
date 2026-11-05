extends TestCase
## The home sound beds in the real scene: they loop in act 1, then fade out (the fan winds down) with no cut.


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


func test_home_sounds_play_and_loop_in_act_one() -> bool:
	var main := await _main()
	for id: StringName in [&"fan", &"fridge", &"tv"]:
		var p: AudioStreamPlayer3D = main.audio.beds[id]
		check(p.playing, "%s plays from the start" % id)
		eq((p.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops (its .import)" % id)
	main.queue_free()
	return true


func test_a_bed_fades_out_it_never_cuts() -> bool:
	var main := await _main()
	var tv: AudioStreamPlayer3D = main.audio.beds[&"tv"]
	var start := tv.volume_db
	WorldState.set_act(2)
	await _frames(30)
	check(tv.playing and tv.volume_db < start, "half a second in: fading, still playing")
	await _frames(70)
	check(not tv.playing, "gone after 1.5 s")
	check(main.audio.beds[&"fridge"].playing and main.audio.beds[&"fan"].playing, "the others keep going")
	main.queue_free()
	return true


func test_the_fan_winds_down_with_its_blades() -> bool:
	var main := await _main()
	WorldState.set_act(4)  # past every bed's act (as after F10): all stop
	await _frames(60)
	var fan: AudioStreamPlayer3D = main.audio.beds[&"fan"]
	check(fan.playing and fan.pitch_scale < 1.0, "a second in: winding down")
	check(main.builder.fan_speed > 0.0 and main.builder.fan_speed < 1.0, "the blades slow with it")
	await _frames(150)
	check(not fan.playing, "stopped after 3 s")
	eq(main.builder.fan_speed, 0.0, "and the blades stand still")
	main.queue_free()
	return true


func test_a_new_shift_brings_the_home_sounds_back() -> bool:
	WorldState.act = 4  # left over from the last shift; main resets it
	var main := await _main()
	await _frames(30)
	check(main.audio.beds[&"tv"].playing and main.audio.beds[&"fan"].playing, "home again")
	eq(main.builder.fan_speed, 1.0, "the fan turns")
	main.queue_free()
	return true
