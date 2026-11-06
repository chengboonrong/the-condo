extends TestCase
## Hafiz and Mei in the front of the couple's car: Mei turns to him for her lines, Hafiz glances at the mirror for his,
## and every spoken line on the road says who speaks it.


func _car() -> CarRig:
	var car := CarRig.new()
	tree.root.add_child(car)
	car.add_child(Couple.new(car))
	return car


## Process frames for `seconds` (the suite runs at a fixed 60 fps).
func _wait(seconds: float) -> void:
	for i in roundi(seconds * 60.0):
		await tree.process_frame


func test_heads_turn_to_the_speaker() -> bool:
	var car := _car()
	var couple: Couple = car.get_node("Couple")
	var head: Node3D = couple.mei.get_node("Chest/Head")
	EventBus.road_line.emit(&"mei", 3.0)
	await _wait(0.6)
	check(head.rotation.y > 0.5, "0.6 s into her line Mei has turned her head over her left shoulder, to him (%.2f rad)" % head.rotation.y)
	await _wait(3.4)
	near(head.rotation.y, 0.0, 0.01, "1 s after her line she faces the road again")
	var his: Node3D = couple.hafiz.get_node("Head")
	var off_mirror := func() -> float: return his.global_basis.z.angle_to(car.mirror_mount.global_position - his.global_position)
	var before: float = off_mirror.call()
	EventBus.road_line.emit(&"hafiz", 3.0)
	await _wait(0.6)
	check(off_mirror.call() < before / 2.0, "Hafiz glances at the mirror: %.2f rad off it, from %.2f" % [off_mirror.call(), before])
	car.queue_free()
	return true


func test_lines_name_their_speaker() -> bool:
	var spoken := RegEx.create_from_string("^([A-Z][A-Za-z ]*): \"")
	var lines: Array = []  # [text, the speaker road_line named for it]
	var on_line := func(text: String, _seconds: float) -> void: lines.append([text, &""])
	var on_speaker := func(speaker: StringName, _seconds: float) -> void: lines[-1][1] = speaker
	EventBus.line_requested.connect(on_line)
	EventBus.road_line.connect(on_speaker)
	for profile: String in ["keeper", "wobbly", "breaker"]:
		RoadPlaythrough.run(profile, Main.SEED)
	EventBus.line_requested.disconnect(on_line)
	EventBus.road_line.disconnect(on_speaker)
	var said := 0
	var wrong: Array[String] = []
	for line: Array in lines:
		var name := spoken.search(line[0])
		var speaker := StringName(name.get_string(1).to_lower()) if name else &""
		if speaker != &"":
			said += 1
		if line[1] != speaker or not [&"", &"hafiz", &"mei"].has(speaker):
			wrong.append("%s (named %s)" % [line[0], line[1]])
	check(said >= 3, "the bots heard the couple speak (%d lines)" % said)
	eq(wrong, [] as Array[String], "spoken lines without their speaker, thoughts or sounds with one, or a speaker not in the car")
	return true
