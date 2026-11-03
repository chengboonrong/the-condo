extends TestCase
## Phase 4 deliverable, walked with real physics and the real camera: the bedroom window becomes a
## door while the player looks away; a corridor that cannot fit in the building leads to B-11-07,
## the flat downstairs; while the player is inside, the corridor grows, so the way back is longer.

const ARRIVE := 0.25


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


## Walks to each point; returns the distance walked, or -1 if stuck or off the floor.
func _walk(player: PlayerController, points: Array) -> float:
	var walked := 0.0
	for p: Vector2 in points:
		var arrived := false
		for i in 600:
			var here := Vector2(player.global_position.x, player.global_position.z)
			var d := p - here
			if d.length() < ARRIVE:
				arrived = true
				break
			player.set_look(atan2(-d.x, -d.y))
			player.scripted_move = Vector2(0, 1)
			await tree.physics_frame
			walked += here.distance_to(Vector2(player.global_position.x, player.global_position.z))
		player.scripted_move = Vector2.ZERO
		if not arrived or absf(player.global_position.y) > 0.05:
			failures.append("stuck or fell before %s at %s" % [p, player.global_position])
			return -1.0
	return walked


func test_impossible_space_sequence() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var sched: EventScheduler = main.runtime.scheduler
	player.use_scripted_move = true
	player.global_position = Vector3(6.75, 0, 3.4)  # hallway, at the open bedroom door
	player.set_look(0.0)  # looking into the bedroom, at the window wall
	await _frames(3)

	sched.request(&"shift", {"area": &"bedroom", "variant": &"door"}, 20)  # as the story asks in act 3
	await _frames(5)
	check(sched.is_queued(&"shift"), "the reveal waits while the window is in view")
	eq(WorldState.get_variant(&"bedroom"), &"default", "the window is still a window")
	WorldState.advance_time(300.0)
	player.set_look(PI / 2)  # look down the hallway
	await _frames(3)
	eq(WorldState.get_variant(&"bedroom"), &"door", "the window became a door while the player looked away")
	eq(WorldState.clock_minutes(), 23 * 60 + 47, "and the clock is back at 11:47 PM")

	if await _walk(player, [Vector2(6.75, 1.6), Vector2(7.72, 1.0)]) < 0.0:
		return true
	WorldState.set_door(&"gap_door", true, &"player")
	await _frames(90)
	if await _walk(player, [Vector2(7.72, -1.4), Vector2(7.72, -3.0)]) < 0.0:
		return true
	var corridor_in := await _walk(player, [Vector2(7.72, -13.0)])
	if corridor_in < 0.0:
		return true

	# Back into B-11-07 while watching the corridor: it must not grow while it can be seen.
	player.set_look(PI)
	player.scripted_move = Vector2(0, -1)
	for i in 300:
		if player.global_position.z < -15.3:
			break
		await tree.physics_frame
	player.scripted_move = Vector2.ZERO
	await _frames(2)
	eq(WorldState.player_room, &"mirror_room", "the corridor leads to B-11-07")
	sched.request(&"shift", {"area": &"gap", "variant": &"long"}, 20)  # as the story asks in act 4
	await _frames(5)
	check(sched.is_queued(&"shift"), "the corridor does not grow while the player watches it")
	eq(WorldState.get_variant(&"gap"), &"default", "still short")
	player.set_look(0.0)  # face into B-11-07
	await _frames(3)
	eq(WorldState.get_variant(&"gap"), &"long", "it grew behind the player's back")

	if await _walk(player, [Vector2(7.72, -13.0)]) < 0.0:
		return true
	var corridor_back := await _walk(player, [Vector2(7.72, -8.7), Vector2(-1.3, -8.7), Vector2(-1.3, -2.7), Vector2(7.72, -2.7)])
	if corridor_back < 0.0 or await _walk(player, [Vector2(7.72, -1.4)]) < 0.0:
		return true
	eq(WorldState.player_room, &"bedroom", "the long way still comes home")
	check(corridor_back > corridor_in * 2.0, "the corridor back is much longer than the way in (%.1f m vs %.1f m)" % [corridor_back, corridor_in])
	print("    impossible space: corridor in %.1f m, back %.1f m" % [corridor_in, corridor_back])
	main.queue_free()
	return true
