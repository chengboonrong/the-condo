extends TestCase
## Phase 2 in the real scene: debug keys, the silhouette against the real camera, the intercom beat.

var sounds: Array[StringName] = []


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


func _on_sound(id: StringName, _pos: Vector3, _db: float) -> void:
	sounds.append(id)


## The still figure in the hallway, under its downlight alone: the player at the spawn faces north, where the
## partition wall hides it. Collects sound ids in `sounds` until _end_still.
func _stage_still(main: Node3D) -> Dictionary:
	WorldState.set_light(&"living", false)
	WorldState.set_light(&"hallway", true)
	main.player.global_position = ApartmentLayout.SPAWN
	main.player.set_look(0.0)
	await _frames(2)
	EventBus.sound_requested.connect(_on_sound)
	return main.runtime.scheduler.start(&"silhouette", {"anchor": &"still_hallway", "ignore_act": true})


func _end_still(main: Node3D) -> void:
	EventBus.sound_requested.disconnect(_on_sound)
	main.queue_free()


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


func test_cut_short_flicker_shows_the_real_light() -> bool:
	var main := await _main()
	var rt: HorrorRuntime = main.runtime
	var run := rt.debug_trigger(1)  # living room
	await _frames(20)
	rt.scheduler.cancel(run)
	await _frames(2)
	var lights := main.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is RoomLight and n.room_id == &"living")
	var light: RoomLight = lights[0]
	check(light.visible and is_equal_approx(light.light_energy, light.base_energy), "the light is back as WorldState says (visible %s, energy %.2f of %.2f)" % [light.visible, light.light_energy, light.base_energy])
	main.queue_free()
	return true


func test_visibility_follows_the_window_shape() -> bool:
	var main := await _main()
	var stage: GameStage = main.runtime.ctx.stage
	main.player.global_position = ApartmentLayout.SPAWN
	main.player.set_look(0.0)  # facing north
	await tree.physics_frame
	var side := Vector3(-sin(PI / 4), 0, -cos(PI / 4))  # 45° to the left
	var point: Vector3 = main.player.camera.global_position + side * 3.0
	eq(tree.root.size, Vector2i(1600, 900), "tests run in the game's 16:9 window")
	check(stage.can_see(point), "45° off centre is on screen in a 16:9 window (about 107° across)")
	tree.root.size = Vector2i(900, 900)
	check(not stage.can_see(point), "but not in a square one (75° across)")
	tree.root.size = Vector2i(1600, 900)
	main.queue_free()
	return true


func test_silhouette_never_appears_in_view_when_looking_down() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	player.global_position = Vector3(4, 0, 8)
	player.set_look(5.76, -0.6)  # the head is above the frame, the body is on screen
	await _frames(3)
	var rt: HorrorRuntime = main.runtime
	var run := rt.scheduler.start(&"silhouette", {"anchor": &"sil_living_balcony", "ignore_act": true})
	eq(run["reason"], "no_hidden_anchor", "it does not appear where its body can be seen")
	main.queue_free()
	return true


func test_a_still_figure_is_silent_and_stays_while_watched() -> bool:
	var main := await _main()
	var run: Dictionary = await _stage_still(main)
	eq(run["state"], EventScheduler.State.RUNNING, "staged")
	var fig: Silhouette = main.silhouette
	var to_player: Vector3 = main.player.global_position - fig.global_position
	check(Vector3(to_player.x, 0, to_player.z).dot(fig.global_basis.z) < 0.0, "its back to the player")
	main.player.global_position = Vector3(3.6, 0, 3.25)
	main.player.set_look(-PI / 2)  # down the hallway, east
	await _frames(60)
	check(run.get("seen", false), "a second in view counts as a sighting")
	check(fig.visible, "it stays while watched")
	near(fig._material.albedo_color.a, 0.95, 0.001, "and does not fade")
	check(not sounds.has(&"stinger"), "silent: no stinger")
	main.player.set_look(PI / 2)  # look away, west
	await _frames(20)
	check(not fig.visible, "gone once the player looks away")
	_end_still(main)
	return true


func test_a_still_figure_walked_up_to_fades_silently() -> bool:
	var main := await _main()
	await _stage_still(main)
	main.player.global_position = Vector3(5.0, 0, 3.25)  # 1.8 m, inside VANISH_DISTANCE
	main.player.set_look(-PI / 2)
	await _frames(40)
	check(not main.silhouette.visible, "it fades instead of standing in the player's face")
	check(not sounds.has(&"stinger"), "silently")
	_end_still(main)
	return true


func test_an_unwatched_still_figure_leaves_unseen() -> bool:
	var main := await _main()
	var run: Dictionary = await _stage_still(main)  # the player never turns
	await _frames(int(SilhouetteEvent.STILL_WAIT * 60) + 30)
	check(not main.silhouette.visible, "gone after its wait")
	eq(run["state"], EventScheduler.State.COMPLETED, "the run ends")
	check(not run.get("seen", false), "without a sighting")
	_end_still(main)
	return true


func test_time_stands_still_while_paused() -> bool:
	var main := await _main()
	main.player.input_enabled = false  # Esc, the start card or a lost pointer lock
	var t := WorldState.time
	await _frames(30)
	eq(WorldState.time, t, "no simulation time passes while paused")
	main.hud.show_inspect("Note", "Text")
	await _frames(30)
	check(WorldState.time > t, "but it does while the player reads")
	main.queue_free()
	return true


func test_intercom_beat() -> bool:
	var main := await _main()
	var rt: HorrorRuntime = main.runtime
	main.hud.started.emit()
	await _frames(2)
	check(not rt.scheduler.is_running(&"phone_ring"), "first the player gets ready for bed")
	EventBus.object_interacted.emit(&"sink")
	EventBus.object_interacted.emit(&"bed")
	await _frames(300)
	check(rt.scheduler.is_running(&"phone_ring"), "the intercom rings once they lie down")
	EventBus.object_interacted.emit(&"intercom")
	await _frames(2)
	check(not rt.scheduler.is_running(&"phone_ring"), "answering stops it")
	await _frames(660)  # 8 s pause, then a 1.6 s knock (history records it when it ends)
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
