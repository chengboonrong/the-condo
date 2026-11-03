extends TestCase
## Phase 1 exit criteria against the real scene and real physics.

const ARRIVE := 0.25
const STEP_TIMEOUT := 600  # physics frames per waypoint (10 s)

# [x, z, room expected on arrival or &"" for "don't check", variant change applied before this leg]
const ROUTE := [
	[5.0, 8.5, &"living"], [3.6, 8.5, &""], [2.0, 8.5, &"entrance"],
	[1.5, 7.6, &""], [1.5, 6.2, &""], [1.5, 5.0, &"kitchen"], [1.5, 6.2, &""], [1.5, 7.6, &""],
	[2.0, 8.5, &""], [3.6, 8.5, &""], [5.6, 8.0, &""], [5.6, 5.0, &""], [4.0, 4.8, &""], [4.0, 3.25, &"hallway"],
	[4.33, 3.25, &""], [4.33, 1.8, &""], [4.3, 0.0, &"bathroom"], [4.33, 1.8, &""], [4.33, 3.25, &""],
	[6.75, 3.25, &""], [6.75, 1.6, &"bedroom"], [7.5, -1.2, &""], [9.4, 1.6, &""],
	[6.75, 1.6, &""], [6.75, 3.25, &""], [4.0, 3.25, &""], [4.0, 4.8, &""], [5.6, 5.0, &""],
	[5.6, 8.0, &""], [3.6, 8.5, &""], [1.53, 9.0, &""], [1.53, 10.8, &"corridor"], [10.0, 11.3, &""],
	[18.0, 11.3, &""], [-3.0, 11.3, &""], [1.53, 10.8, &""], [1.53, 9.0, &"entrance"], [3.6, 8.5, &""],
	[5.6, 8.0, &""], [5.6, 5.0, &""], [4.0, 4.8, &""], [4.0, 3.25, &""], [6.75, 3.25, &""], [6.75, 1.6, &"bedroom"],
	[7.72, 1.0, &""],
	# the reveal: the window is now a door
	[7.72, -1.4, &"", {&"bedroom": &"door"}], [7.72, -3.0, &"gap"], [7.72, -13.4, &""], [7.72, -15.0, &"mirror_room"],
	# the corridor grows while the player is inside B-11-07
	[7.72, -13.4, &"gap", {&"gap": &"long"}], [7.72, -8.7, &""], [-1.3, -8.7, &""], [-1.3, -2.7, &""], [7.72, -2.7, &""],
	[7.72, -1.4, &"bedroom"],
]


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame
	return main


func _walk_to(player: PlayerController, target: Vector2) -> bool:
	for i in STEP_TIMEOUT:
		var d := target - Vector2(player.global_position.x, player.global_position.z)
		if d.length() < ARRIVE:
			player.scripted_move = Vector2.ZERO
			return true
		player.set_look(atan2(-d.x, -d.y))
		player.scripted_move = Vector2(0, 1)
		await tree.physics_frame
	player.scripted_move = Vector2.ZERO
	return false


func test_walk_reaches_every_room_without_getting_stuck() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	player.use_scripted_move = true
	for id: StringName in ApartmentLayout.DOORS:
		WorldState.set_door(id, true, &"test")
	var visited := {}
	for leg: Array in ROUTE:
		if leg.size() > 3:
			for area: StringName in leg[3]:
				WorldState.set_variant(area, leg[3][area])
			await tree.physics_frame
		var ok: bool = await _walk_to(player, Vector2(leg[0], leg[1]))
		if not ok:
			failures.append("stuck before (%.2f, %.2f) at %s" % [leg[0], leg[1], player.global_position])
			break
		if leg[2] != &"":
			eq(WorldState.player_room, leg[2], "room at (%.2f, %.2f)" % [leg[0], leg[1]])
		visited[WorldState.player_room] = true
	for room: StringName in ApartmentLayout.ROOMS:
		check(visited.has(room), "never reached %s" % room)
	main.queue_free()
	return true


func test_doors_follow_world_state_and_interaction() -> bool:
	var main := await _main()
	var door: Door = main.builder.doors[&"bathroom_door"]
	eq(WorldState.is_door_open(&"bathroom_door"), false, "bathroom starts closed")
	WorldState.set_door(&"bathroom_door", true, &"test")
	for i in 90:
		await tree.physics_frame
	near(absf(door.rotation.y), Door.OPEN_ANGLE, 0.01, "door swung open")
	door.interact(main.player)
	eq(WorldState.is_door_open(&"bathroom_door"), false, "interact closes it")
	for i in 90:
		await tree.physics_frame
	near(door.rotation.y, 0.0, 0.01, "door swung shut")
	main.queue_free()
	return true


func test_interaction_reach() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var tv := Vector3(6.5, 0.95, 4.57)
	for spot: Array in [[6.2, true], [7.6, false]]:
		player.global_position = Vector3(6.5, 0, spot[0])
		var eye := player.global_position + Vector3.UP * 1.62
		player.set_look(0.0, atan2(tv.y - eye.y, eye.z - tv.z))
		for i in 3:
			await tree.physics_frame
		var hit: Object = player.interaction.target
		eq(hit != null and hit.object_id == &"tv", spot[1], "TV interactable from z=%.1f" % spot[0])
	main.queue_free()
	return true


func test_knock_plays_at_its_anchor() -> bool:
	var main := await _main()
	var pos: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	EventBus.sound_requested.emit(&"knock3", pos, 0.0)
	var found := false
	for p in main.audio.get_children():
		if p is AudioStreamPlayer3D and p.playing and p.global_position.is_equal_approx(pos):
			found = true
	check(found, "a positional player is playing at the knock anchor")
	main.queue_free()
	return true


func test_variant_swap_toggles_visibility_and_collision() -> bool:
	var main := await _main()
	var gap_door: Door = main.builder.doors[&"gap_door"]
	var shape: CollisionShape3D = gap_door.get_child(0)
	eq(gap_door.visible, false, "gap door hidden before the reveal")
	eq(shape.disabled, true, "gap door has no collision before the reveal")
	WorldState.set_variant(&"bedroom", &"door")
	await tree.physics_frame
	eq(gap_door.visible, true, "gap door shown after the reveal")
	eq(shape.disabled, false, "gap door collides after the reveal")
	main.queue_free()
	return true
