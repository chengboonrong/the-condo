extends TestCase


func test_anchors_lie_in_their_rooms() -> bool:
	var revealed := {&"bedroom": &"door"}
	for id: StringName in ApartmentLayout.ANCHORS:
		var a: Dictionary = ApartmentLayout.ANCHORS[id]
		var p: Vector3 = a["pos"]
		# knock anchors sit on walls: nudge 0.2 m towards the room centre before testing
		var c := ApartmentLayout.room_center(a["room"], revealed)
		var probe := p + (Vector3(c.x, p.y, c.z) - p).normalized() * 0.2
		eq(ApartmentLayout.room_at(probe, revealed), a["room"], "anchor %s" % id)
	return true


func test_initial_state() -> bool:
	ApartmentLayout.apply_initial_state()
	eq(WorldState.is_light_on(&"living"), true, "living room lit")
	eq(WorldState.is_light_on(&"bedroom"), false, "bedroom dark")
	eq(WorldState.is_door_open(&"main_door"), false, "front door shut")
	eq(WorldState.is_door_open(&"bedroom_door"), true, "bedroom door open")
	return true


func test_clock_resets_on_shift() -> bool:
	eq(WorldState.clock_minutes(), 23 * 60 + 47, "starts 11:47 PM")
	WorldState.advance_time(5 * 60.0)
	eq(WorldState.clock_minutes(), 23 * 60 + 52, "five minutes later")
	WorldState.set_variant(&"gap", &"default")
	eq(WorldState.clock_minutes(), 23 * 60 + 52, "re-setting the variant an area already has is not a shift")
	WorldState.set_variant(&"living_chair", &"turned")
	eq(WorldState.clock_minutes(), 23 * 60 + 47, "a shift puts it back to 11:47 PM")
	eq(WorldState.time, 300.0, "simulation time never rewinds")
	WorldState.advance_time(14 * 60.0)
	eq(WorldState.clock_minutes(), 1, "rolls past midnight to 12:01 AM")
	return true
