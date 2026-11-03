extends TestCase
## Phase 2 in the real scene: debug keys, the silhouette against the real camera, the intercom beat.


func _main() -> Node3D:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.physics_frame
	await tree.physics_frame
	return main


func _frames(n: int) -> void:
	for i in n:
		await tree.physics_frame


func test_debug_keys_fire_events() -> bool:
	var main := await _main()
	var rt: HorrorRuntime = main.runtime
	eq(rt.debug_trigger(0)["state"], EventScheduler.State.RUNNING, "F5 knocks")
	eq(rt.debug_trigger(1)["state"], EventScheduler.State.RUNNING, "F6 flickers the living room light")
	eq(rt.debug_trigger(2)["reason"], "no_door_out_of_reach", "F7: the living room has no door to slam")
	eq(rt.debug_trigger(3)["reason"], "busy:knock_wall", "F8 waits for the knock (same audio channel)")
	await _frames(150)
	eq(rt.scheduler.running.size(), 0, "both finished")
	eq(WorldState.event_history.size(), 2, "and were recorded")
	main.queue_free()
	return true


func test_silhouette_behind_then_seen() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var rt: HorrorRuntime = main.runtime
	player.global_position = Vector3(4.0, 0, 3.25)
	player.set_look(PI / 2)  # facing west, the hallway behind
	await _frames(2)
	var run := rt.debug_trigger(4)
	eq(run["state"], EventScheduler.State.RUNNING, "F9 places the silhouette behind the player")
	var fig: Silhouette = main.find_children("*", "Silhouette", false, false)[0]
	await _frames(30)
	check(fig.visible, "it stays while the player looks away")
	var to: Vector3 = run["position"] - player.global_position
	player.set_look(atan2(-to.x, -to.z))
	await _frames(40)
	eq(run["state"], EventScheduler.State.COMPLETED, "turning round to it ends the event")
	await _frames(40)
	check(not fig.visible, "and it has faded")
	main.queue_free()
	return true


func test_intercom_beat() -> bool:
	var main := await _main()
	var rt: HorrorRuntime = main.runtime
	main.hud.started.emit()
	await _frames(150)
	check(rt.scheduler.is_running(&"phone_ring"), "the intercom rings after the start card")
	EventBus.object_interacted.emit(&"intercom")
	await _frames(2)
	check(not rt.scheduler.is_running(&"phone_ring"), "answering stops it")
	await _frames(480)  # 6 s pause, then a 1.6 s knock (history records it when it ends)
	var knocks := WorldState.event_history.filter(func(e: Dictionary) -> bool: return e["id"] == &"knock_wall")
	eq(knocks.size(), 1, "then the knocks start")
	eq(knocks[0]["room"] if not knocks.is_empty() else &"", &"bedroom", "from the bedroom wall")
	main.queue_free()
	return true


func test_director_runs_in_game_within_budget() -> bool:
	var main := await _main()
	var rt: HorrorRuntime = main.runtime
	WorldState.set_act(WorldState.Act.IMPOSSIBLE)
	await _frames(60 * 90)  # 90 s of play standing at the spawn point
	check(not rt.director.decisions.is_empty(), "the director picks events in game")
	check(WorldState.entity_state != &"dormant", "the entity is awake in act 3")
	check(rt.director.max_eval_usec < 2000, "a decision takes under 2 ms (max %d µs)" % rt.director.max_eval_usec)
	var overlay: DebugOverlay = main.find_children("*", "DebugOverlay", false, false)[0]
	overlay.visible = true  # F3
	await tree.process_frame
	await tree.process_frame  # process_frame fires before _process
	var text: String = overlay._label.text
	check(text.contains("director tension") and text.contains("last pick"), "F3 shows the director's last pick and its scores")
	print("    director in game: %d picks in 90 s, eval last %d µs, max %d µs (headless)" % [
		rt.director.decisions.size(), rt.director.last_eval_usec, rt.director.max_eval_usec])
	main.queue_free()
	return true
