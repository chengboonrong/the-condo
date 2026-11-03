extends TestCase


func test_every_apartment_room_reachable_from_corridor() -> bool:
	var g := RoomGraph.new({})
	for room: StringName in g.rooms():
		check(g.is_reachable(&"corridor", room), "unreachable: %s" % room)
	eq(g.rooms().has(&"gap"), false, "gap hidden before the reveal")
	return true


func test_reveal_adds_gap_and_mirror_room() -> bool:
	var g := RoomGraph.new({&"bedroom": &"door"})
	eq(g.path(&"living", &"mirror_room"), [&"living", &"hallway", &"bedroom", &"gap", &"mirror_room"] as Array[StringName], "path to mirror room")
	for v: StringName in [&"default", &"long"]:
		var vs := {&"bedroom": &"door", &"gap": v}
		for room: StringName in g.rooms(vs):
			check(g.is_reachable(&"mirror_room", room, vs), "gap %s: %s unreachable from mirror room" % [v, room])
	return true


func test_room_at_matches_rects_per_variant() -> bool:
	eq(ApartmentLayout.room_at(Vector3(6.5, 0, 8.4), {}), &"living", "spawn is in the living room")
	eq(ApartmentLayout.room_at(Vector3(7.7, 0, -5), {}), &"", "no gap before the reveal")
	eq(ApartmentLayout.room_at(Vector3(7.7, 0, -5), {&"bedroom": &"door"}), &"gap", "straight gap")
	eq(ApartmentLayout.room_at(Vector3(7.7, 0, -5), {&"bedroom": &"door", &"gap": &"long"}), &"", "long gap skips the middle")
	eq(ApartmentLayout.room_at(Vector3(-1.3, 0, -5), {&"bedroom": &"door", &"gap": &"long"}), &"gap", "long gap detour")
	eq(ApartmentLayout.room_at(ApartmentLayout.LIFT_POS, {}), &"corridor", "lift is in the corridor")
	return true
