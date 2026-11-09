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
	near(main.audio.beds[&"tv"].volume_db, AudioDirector.BEDS[&"tv"]["db"], 0.01, "the TV at its level, not fading")
	eq(main.builder.fan_speed, 1.0, "the fan turns")
	main.queue_free()
	return true


## What a positional player is heard at, `d` metres off: its volume plus the inverse-distance gain, clamped to max_db.
func _gain(p: AudioStreamPlayer3D, d: float) -> float:
	return minf(p.volume_db - 20.0 * log(d / p.unit_size) / log(10.0), p.max_db)


## The neighbour's rattle has to stand out of the flat's room tone wherever he is: while he has time to turn, the drone,
## the corridor's hums and the running tap duck by AudioDirector.DUCK, in over 0.15 s, and come back over a second.
func test_the_drone_ducks_under_the_rattle_and_comes_back() -> bool:
	var main := await _main()
	var audio: AudioDirector = main.audio
	var drone: AudioStreamPlayer = audio._drone
	await _frames(5)
	var before := drone.volume_db
	eq(audio.duck, 0.0, "not ducked to begin with")
	EventBus.beds_duck_requested.emit(true)
	await _frames(20)  # 0.33 s: in (it takes 0.15 s)
	near(audio.duck, AudioDirector.DUCK, 0.01, "ducked by its depth")
	near(drone.volume_db, before - AudioDirector.DUCK, 0.5, "the drone is that far down")
	near(audio._tap.volume_db, AudioDirector.TAP_DB - AudioDirector.DUCK, 0.01, "and so is the tap")
	check(audio.beds[&"fan"].playing, "(the rest of the flat's sounds are not touched)")
	EventBus.beds_duck_requested.emit(false)
	await _frames(20)  # 0.33 s: on its way back, over 1 s
	check(audio.duck > 0.0 and audio.duck < AudioDirector.DUCK, "it comes back, it does not snap")
	await _frames(60)
	eq(audio.duck, 0.0, "and is gone after a second")
	near(drone.volume_db, before, 0.5, "the drone is where it was")
	main.queue_free()
	return true


## A positional player adds its volume to its distance gain and only then clamps to max_db, so with only the volume
## ducked a close one is down by less than the duck (the tap by about 18 dB of 30 with his head over the basin, 21 at 1 m).
func test_the_tap_and_the_hums_are_down_the_whole_duck_however_close() -> bool:
	var main := await _main()
	var audio: AudioDirector = main.audio
	var players: Array[AudioStreamPlayer3D] = [audio._tap]
	players.append_array(audio._hums)
	await _frames(5)
	var plain: Array[float] = []
	for d in [0.65, 1.0, 2.0, 5.0, 12.0]:
		for p in players:
			plain.append(_gain(p, d))
	EventBus.beds_duck_requested.emit(true)
	await _frames(20)
	var i := 0
	for d in [0.65, 1.0, 2.0, 5.0, 12.0]:
		for p in players:
			near(plain[i] - _gain(p, d), AudioDirector.DUCK, 0.01, "%s is the full duck down at %.2f m" % [p.name, d])
			i += 1
	main.queue_free()
	return true


## An ending that comes inside the window stops the core, so nothing else would end the duck: the card is not played
## over a silent flat. (After a kill the duck stays on until the card silences the beds, as intended.)
func test_an_ending_in_the_window_lets_the_beds_back() -> bool:
	var main := await _main()
	var audio: AudioDirector = main.audio
	EventBus.beds_duck_requested.emit(true)
	await _frames(20)
	near(audio.duck, AudioDirector.DUCK, 0.01, "ducked")
	WorldState.set_ending(&"vacant")
	await _frames(70)
	eq(audio.duck, 0.0, "the ending lets the beds back, over a second")
	main.queue_free()
	return true
