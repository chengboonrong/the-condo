extends TestCase
## Hafiz and Mei in the front of the couple's car: Mei turns to him for her lines, Hafiz glances at the mirror for his,
## and every spoken line on the road says who speaks it.

const MISSIONS := "res://scripts/road/missions"


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


func test_two_lines_of_hers_are_one_turn() -> bool:
	var car := _car()
	var head: Node3D = (car.get_node("Couple") as Couple).mei.get_node("Chest/Head")
	var none: Array[RoadMission] = []
	var core := RoadDirector.new(RoadStage.new(), 1147, none)
	core.say("Mei: \"One.\"", 2.0, &"mei")
	core.say("Mei: \"Two.\"", 2.0, &"mei")
	var turned := 0.0  # her head as her first line ends
	var lowest := INF  # and its least after that, through the gap, until her second line ends
	for i in roundi(4.0 * 60.0):
		core.step(1.0 / 60.0)
		await tree.process_frame
		if i == 119:
			turned = head.rotation.y
		elif i > 119:
			lowest = minf(lowest, head.rotation.y)
	check(lowest > 0.5 and lowest > turned - 0.01, "through the gap between two of her lines she stays turned to him (%.2f rad, down to %.2f)" % [turned, lowest])
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
	# And the lines on paths no bot takes: every say( in the missions' source.
	var unchecked: Array[String] = []
	for file in DirAccess.get_files_at(MISSIONS):
		if file.ends_with(".gd"):
			unchecked.append_array(_source_problems("%s/%s" % [MISSIONS, file]))
	eq(unchecked, [] as Array[String], "every say( in the missions names the speaker of a spoken line, and only of one")
	return true


## What is wrong with the say( calls in a mission's source. A line written `Name: "…"` must name its speaker as
## &"name", Hafiz or Mei; any other line names none. A spoken line anywhere but straight in a say( (a const, a
## variable, a sum), or a speaker passed in a variable, is a problem too: the scan can't check it.
func _source_problems(path: String) -> Array[String]:
	var file := path.get_file()
	var source := FileAccess.get_file_as_string(path)
	var spoken := RegEx.create_from_string("^([A-Z][A-Za-z ]*): \"")
	var token := RegEx.create_from_string(r"""#[^\n]*|([&^]?)("{3}[\s\S]*?"{3}|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*')""")
	var marker := RegEx.create_from_string("^«(\\d+)»$")
	# The source with comments dropped and each string literal swapped for «n», its index in `literals`.
	var literals: Array = []  # [prefix, text, line]
	var masked := ""
	var at := 0
	var swaps: Array = []  # [offset in masked, offset in source] after each swap, to find a say('s line in the source
	for m in token.search_all(source):
		masked += source.substr(at, m.get_start() - at)
		at = m.get_end()
		if not m.get_string().begins_with("#"):
			var quoted := m.get_string(2)
			var q := 3 if quoted.begins_with("\"\"\"") else 1
			masked += "«%d»" % literals.size()
			var text := quoted.substr(q, quoted.length() - 2 * q).c_unescape()
			literals.append([m.get_string(1), text, source.substr(0, m.get_start()).count("\n") + 1])
		swaps.append([masked.length(), at])
	masked += source.substr(at)
	var problems: Array[String] = []
	var in_say := {}
	for call in RegEx.create_from_string("\\bsay\\(").search_all(masked):
		var args := _args(masked, call.get_end())
		var from := call.get_start()  # in the source: past the last swap before it, the two texts run alike
		for swap: Array in swaps:
			if swap[0] <= call.get_start():
				from = swap[1] + call.get_start() - swap[0]
		var where := "%s:%d" % [file, source.substr(0, from).count("\n") + 1]
		var line := marker.search(args[0])
		var i := int(line.get_string(1)) if line else -1
		if i >= 0 and literals[i][0] == "":
			in_say[i] = true
		else:
			i = -1
		var speaker := ""
		if args.size() > 2:
			var named := marker.search(args[2])
			if named == null or literals[int(named.get_string(1))][0] != "&":
				problems.append("%s: a speaker not written &\"name\"" % where)
				continue
			speaker = literals[int(named.get_string(1))][1]
		if i < 0:
			if speaker != "":
				problems.append("%s: a line in a variable names a speaker, so the two can't be checked" % where)
			continue
		var text: String = literals[i][1]
		var who := spoken.search(text)
		var want := who.get_string(1).to_lower() if who else ""
		if speaker != want or want not in ["", "hafiz", "mei"]:
			problems.append("%s: %s (names &\"%s\")" % [where, text, speaker])
	for i in literals.size():
		if not in_say.has(i) and literals[i][0] == "" and spoken.search(literals[i][1]):
			problems.append("%s:%d: %s is not written straight in a say(, so its speaker can't be checked" % [file, literals[i][2], literals[i][1]])
	return problems


## A call's arguments in `text`, from just after its "(" to its ")".
func _args(text: String, from: int) -> Array[String]:
	var args: Array[String] = [""]
	var depth := 0
	for c in text.substr(from):
		if c == "," and depth == 0:
			args.append("")
			continue
		if c in "([{":
			depth += 1
		elif c in ")]}":
			if depth == 0:
				break
			depth -= 1
		args[-1] += c
	for i in args.size():
		args[i] = args[i].strip_edges()
	return args
