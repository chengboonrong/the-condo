extends TestCase
## Face the sound: when the neighbour reaches a room next to his, it breathes in that doorway. If he keeps his back to
## it for FACE_SECONDS it gets him; if he turns to look it backs off. From act 3 only, and never an unfair death.

const HALLWAY_DOOR := Vector3(4, 0, 4)  # the hallway's opening onto the living room
const FACING := PI  # in the hallway, the way the living room's doorway lies
const BACK_TURNED := 0.0
const FACE_SECONDS := EntityController.FACE_SECONDS

var graph: RoomGraph
var stage: HorrorStage
var entity: EntityController
var sounds: Array = []  # [id, position, db] of every sound the entity asked for
var lines: Array[String] = []
var captions: Array[String] = []
var kills: Array[StringName] = []


## He stands in `room` at its centre looking `yaw`; the neighbour is in `entity_room`, coming for him.
func _setup(room: StringName, yaw: float, entity_room: StringName, state := &"approaching", act := 3) -> void:
	ApartmentLayout.apply_initial_state()
	WorldState.act = act
	graph = RoomGraph.new(WorldState.variants)
	stage = HorrorStage.new(graph)
	_place(room, yaw)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	entity = EntityController.new(graph, rng)
	entity.stage = stage
	entity.killed.connect(_on_killed)
	WorldState.set_entity(entity_room, state)
	sounds.clear()
	lines.clear()
	captions.clear()
	kills.clear()
	_listen()


func _teardown() -> void:
	entity.killed.disconnect(_on_killed)
	_unlisten()


func _listen() -> void:
	EventBus.sound_requested.connect(_on_sound)
	EventBus.line_requested.connect(_on_line)
	EventBus.subtitle_requested.connect(_on_caption)


func _unlisten() -> void:
	EventBus.sound_requested.disconnect(_on_sound)
	EventBus.line_requested.disconnect(_on_line)
	EventBus.subtitle_requested.disconnect(_on_caption)


## The whole core, its story running, with him in the hallway looking `yaw` and the neighbour in the living room
## coming for him. Free it with _core_done.
func _core(yaw: float) -> HorrorRuntime:
	ApartmentLayout.apply_initial_state()
	WorldState.act = WorldState.Act.IMPOSSIBLE
	graph = RoomGraph.new(WorldState.variants)
	stage = HorrorStage.new(graph)
	_place(&"hallway", yaw)
	var rt := HorrorRuntime.new()
	rt.setup(stage, 3)
	rt.start_story()
	WorldState.set_entity(&"living", &"approaching")
	sounds.clear()
	lines.clear()
	captions.clear()
	_listen()
	return rt


func _core_done(rt: HorrorRuntime) -> bool:
	_unlisten()
	rt.free()
	return true


func _step(rt: HorrorRuntime, seconds: float) -> void:
	for i in roundi(seconds * 10.0):
		rt.step(0.1)


func _place(room: StringName, yaw: float) -> void:
	stage.position = ApartmentLayout.room_center(room, WorldState.variants)
	stage.yaw = yaw
	WorldState.set_player_room(room)


func _on_killed(cause: StringName) -> void:
	kills.append(cause)


func _on_sound(id: StringName, pos: Vector3, db: float) -> void:
	sounds.append([id, pos, db])


func _on_line(text: String, _duration: float) -> void:
	lines.append(text)


func _on_caption(text: String, _duration: float) -> void:
	captions.append(text)


func _run(seconds: float, dt := 0.5) -> void:
	var t := 0.0
	while t < seconds - 0.0001:
		entity.tick(dt)
		t += dt


## It watches from two rooms away (the entrance), then creeps up until it breathes at the living room's doorway.
## Returns the seconds that took.
func _until_it_breathes() -> float:
	var t := 0.0
	while sounds.is_empty() and t < 120.0:
		entity.tick(0.5)
		t += 0.5
	return t


func test_it_breathes_at_the_doorway_when_next_to_him() -> bool:
	_setup(&"hallway", BACK_TURNED, &"entrance", &"observing")
	check(stage.is_behind(HALLWAY_DOOR), "(his back is to the living room's doorway)")
	var t := _until_it_breathes()
	check(t > EntityController.OBSERVE_TIME, "it makes no sound while it watches or creeps (first at %.1f s)" % t)
	eq(WorldState.entity_room, &"living", "it breathes the moment it is next to his room")
	eq(sounds.size(), 1, "once")
	eq(sounds[0][0], &"rattle", "it is the rattle")
	check((sounds[0][1] as Vector3).is_equal_approx(HALLWAY_DOOR + Vector3.UP * 1.5), "from the connecting doorway, 1.5 m up (%s)" % sounds[0][1])
	eq(sounds[0][2], EntityController.RATTLE_DB, "at its level")
	_run(1.5)
	eq(sounds.size(), 1, "and it does not go on breathing while he has the time to turn")
	_teardown()
	return true


func test_facing_the_doorway_sends_it_back() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living")
	entity.tick(0.1)  # it breathes
	_run(3.0)
	eq(WorldState.entity_state, &"approaching", "it waits while his back is turned")
	stage.yaw = FACING
	check(not stage.is_behind(HALLWAY_DOOR), "(he faces the doorway)")
	_run(0.5)
	eq(WorldState.entity_state, &"retreating", "he looks: it backs off")
	eq(kills, [], "and nothing is killed")
	_run(10.0)
	eq(kills, [], "not later either")
	_teardown()
	return true


func test_a_turn_at_the_last_moment_still_saves_him() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living")
	entity.tick(0.1)
	_run(3.5)
	stage.yaw = FACING
	entity.tick(0.5)  # the tick that would have been the fourth second
	eq(kills, [], "turning inside the four seconds is enough")
	eq(WorldState.entity_state, &"retreating", "it backs off")
	_teardown()
	return true


func test_keeping_his_back_to_it_kills() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living")
	entity.tick(0.1)  # it breathes: the clock starts
	entity.tick(3.9)
	eq(kills, [], "not at 3.9 s")
	entity.tick(0.1)
	eq(kills, [&"faced_away"], "at 4.0 s: killed, once, for keeping his back to it")
	eq(EntityController.FACE_SECONDS, 4.0, "four seconds")
	_teardown()
	return true


func test_the_warning_comes_the_first_time_only() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living")
	entity.tick(0.1)
	eq(lines, [EntityController.WARN], "the first time it comes, the line tells him what to do")
	eq(captions, [], "(no caption yet)")
	stage.yaw = FACING
	_run(0.5)
	eq(WorldState.entity_state, &"retreating", "he faces it")
	stage.yaw = BACK_TURNED
	var t := 0.0
	while sounds.size() < 2 and t < 200.0:  # it backs off, watches, and comes again
		entity.tick(0.5)
		t += 0.5
	eq(sounds.size(), 2, "it came a second time and breathed again")
	eq(lines, [EntityController.WARN], "the warning is said once over the two approaches")
	eq(captions, [EntityController.CAPTION], "the second time it is the sound's caption")
	eq(EntityController.CAPTION, "[Breathing in the doorway]", "which says what the sound is")
	_teardown()
	return true


func test_it_never_kills_before_act_three() -> bool:
	for act in [1, 2]:
		_setup(&"hallway", BACK_TURNED, &"living", &"observing", act)
		_run(200.0)
		eq(sounds, [], "act %d: it makes no sound" % act)
		eq(kills, [], "act %d: it kills nothing" % act)
		check(WorldState.entity_state != &"approaching", "act %d: it never comes for him" % act)
		_teardown()
	return true


func test_it_stops_when_the_story_ends() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living", &"approaching", WorldState.Act.ENDED)
	_run(20.0)
	eq(kills, [], "after the ending it does not kill")
	eq(sounds, [], "or breathe")
	_teardown()
	return true


## Act 2's watching does not count towards act 3's approach: it is OBSERVE_TIME from the act that lets it come, as after a retry.
func test_it_waits_a_full_observe_time_when_act_three_begins() -> bool:
	_setup(&"hallway", BACK_TURNED, &"entrance", &"observing", 2)
	_run(60.0)  # a minute of act 2
	eq(WorldState.entity_state, &"observing", "(it only watched)")
	WorldState.act = WorldState.Act.IMPOSSIBLE
	_run(EntityController.OBSERVE_TIME - 1.0)
	eq(WorldState.entity_state, &"observing", "act 3 has just begun: it has not come yet")
	_run(3.0)
	eq(WorldState.entity_state, &"approaching", "it comes once OBSERVE_TIME has passed")
	_teardown()
	return true


## The first time it comes while the story is speaking, it holds, next to him and silent, with no clock running: the
## warning must not cut a line short, nor be cut. When the story is quiet it breathes and warns in that same step.
func test_the_first_approach_waits_while_the_story_speaks() -> bool:
	var rt := _core(BACK_TURNED)
	rt.story.say("[Rosnah goes on.]", 3.0, true)
	_step(rt, 3.0)
	eq(lines, ["[Rosnah goes on.]"], "only the story's line is on screen")
	eq(sounds, [], "it does not breathe over it")
	eq(WorldState.entity_room, &"living", "it waits next to him")
	eq(rt.dead, &"", "and no clock is running, though his back has been turned for three seconds")
	var t := 0.0
	while sounds.is_empty() and t < 2.0:
		rt.step(0.1)
		t += 0.1
	eq(sounds.size(), 1, "the moment the story is quiet it breathes")
	eq(lines, ["[Rosnah goes on.]", EntityController.WARN], "and says what to do, in the same step")
	_step(rt, 3.0)
	eq(rt.dead, &"", "(his four seconds run from the breath, not from before)")
	_step(rt, 1.5)
	eq(rt.dead, &"faced_away", "and run out")
	_core_done(rt)
	return true


## The warning is the story's own line (in its queue, then on its timer): a line the story says next waits for it.
func test_the_warning_goes_through_the_story() -> bool:
	var rt := _core(BACK_TURNED)
	rt.step(0.1)  # it breathes and warns
	eq(lines, [EntityController.WARN], "said at once, the story having nothing to say")
	check(rt.story.speaking(), "the story is speaking it")
	stage.yaw = FACING  # (he looks, so the clock does not matter here)
	rt.story.say("[Something else.]", 3.0, true)
	_step(rt, 4.0)
	eq(lines, [EntityController.WARN], "a line said right after waits for it to run its time")
	_step(rt, 1.0)
	eq(lines, [EntityController.WARN, "[Something else.]"], "and then comes")
	_core_done(rt)
	return true


## Later approaches say the sound's caption, on the line that never cuts a spoken one, even while the story speaks.
func test_later_approaches_do_not_wait_for_the_story() -> bool:
	var rt := _core(BACK_TURNED)
	rt.step(0.1)
	stage.yaw = FACING
	rt.step(0.1)  # it backs off
	eq(WorldState.entity_state, &"retreating", "(he looked)")
	stage.yaw = BACK_TURNED
	WorldState.set_entity(&"living", &"approaching")
	rt.story.say("[Rosnah goes on.]", 3.0, true)
	rt.step(0.1)
	eq(sounds.size(), 2, "the second time it breathes at once")
	eq(captions, [EntityController.CAPTION], "as a caption")
	_core_done(rt)
	return true


## He walks out of reach before he has turned: the clock stops, it goes on coming, and when it is next to him again
## it breathes again, with the full FACE_SECONDS.
func test_walking_out_of_reach_stops_the_clock() -> bool:
	_setup(&"hallway", BACK_TURNED, &"entrance", &"observing")
	_until_it_breathes()
	_run(3.0)
	_place(&"bedroom", BACK_TURNED)  # two rooms from the living room: not next to it any more
	var t := 0.0
	while WorldState.entity_room == &"living" and t < 30.0:
		entity.tick(0.5)
		t += 0.5
	eq(WorldState.entity_room, &"hallway", "it keeps approaching, a room closer after its time")
	check(t > FACE_SECONDS, "the seconds he spent out of reach (%.1f) were not held against him" % t)
	eq(kills, [], "he lives")
	entity.tick(0.1)  # next to him again, at the bedroom door
	eq(sounds.size(), 2, "it breathes again")
	check((sounds[1][1] as Vector3).is_equal_approx(Vector3(6.75, 1.5, 2.5)), "at the doorway that joins it to him now (%s)" % sounds[1][1])
	entity.tick(3.9)
	eq(kills, [], "his four seconds start again")
	entity.tick(0.1)
	eq(kills, [&"faced_away"], "and run out")
	_teardown()
	return true


## The same doorway again after stepping out and back: a fresh breath, a fresh clock.
func test_stepping_out_and_back_starts_the_clock_again() -> bool:
	_setup(&"hallway", BACK_TURNED, &"entrance", &"observing")
	_until_it_breathes()
	_run(3.0)
	_place(&"bedroom", BACK_TURNED)  # out of reach, but it has not had the time to follow
	entity.tick(0.5)
	eq(WorldState.entity_room, &"living", "(it is still in the living room)")
	_place(&"hallway", BACK_TURNED)
	entity.tick(0.1)
	eq(sounds.size(), 2, "back next to it, it breathes at the doorway again")
	check((sounds[1][1] as Vector3).is_equal_approx(sounds[0][1]), "the same one")
	entity.tick(3.9)
	eq(kills, [], "with the clock back at zero")
	entity.tick(0.1)
	eq(kills, [&"faced_away"], "and four seconds from the second breath it gets him")
	_teardown()
	return true


func test_walking_into_its_room_makes_it_leave() -> bool:
	_setup(&"hallway", BACK_TURNED, &"living")
	entity.tick(0.1)
	_run(3.5)
	_place(&"living", BACK_TURNED)
	entity.tick(1.0)
	eq(WorldState.entity_state, &"retreating", "he walks into its room: it backs off, as it always did")
	check(WorldState.entity_room != &"living", "and it is gone")
	eq(kills, [], "he was never killed, though his back was turned for more than four seconds")
	_teardown()
	return true


## The gap and the mirror room exist only with the bedroom's door variant: the doorway is the one that is there.
func test_the_doorway_is_the_one_the_variants_give() -> bool:
	_setup(&"bedroom", BACK_TURNED, &"hallway")
	WorldState.set_variant(&"bedroom", &"door")  # the graph shares WorldState.variants
	WorldState.set_entity(&"gap", &"approaching")
	entity.tick(0.1)
	eq(sounds.size(), 1, "with the door in the bedroom, the gap's side is next to it")
	check((sounds[0][1] as Vector3).is_equal_approx(Vector3(7.7, 1.5, -2)), "at the gap door (%s)" % sounds[0][1])
	_teardown()
	return true


## The rule the whole thing rests on: a player who turns to the sound when he hears it survives. Every approach needs a
## real turn: after it backs off he is put with his back to every doorway of the living room again (facing east).
func test_a_player_who_turns_to_the_sound_survives() -> bool:
	const AWAY := -PI / 2
	ApartmentLayout.apply_initial_state()
	WorldState.act = WorldState.Act.IMPOSSIBLE
	var rt_stage := HorrorStage.new(RoomGraph.new(WorldState.variants))
	rt_stage.position = ApartmentLayout.room_center(&"living")
	rt_stage.yaw = AWAY
	WorldState.set_player_room(&"living")
	var rt := HorrorRuntime.new()
	rt.setup(rt_stage, 11)
	var heard: Array = []  # [when, where, whether his back was to it]
	var on_sound := func(id: StringName, pos: Vector3, _db: float) -> void:
		if id == &"rattle":
			heard.append([WorldState.time, pos, rt_stage.is_behind(pos)])
	EventBus.sound_requested.connect(on_sound)
	var turned := 0
	var t := 0.0
	while t < 900.0 and rt.dead == &"":
		if turned < heard.size() and WorldState.time - heard[turned][0] >= 1.0:  # a second to hear it and turn
			var at: Vector3 = heard[turned][1]
			rt_stage.yaw = atan2(-(at.x - rt_stage.position.x), -(at.z - rt_stage.position.z))
			turned += 1
		elif WorldState.entity_state == &"retreating":
			rt_stage.yaw = AWAY
		rt.step(0.1)
		t += 0.1
	EventBus.sound_requested.disconnect(on_sound)
	eq(rt.dead, &"", "he turned every time and lived for fifteen minutes")
	check(heard.size() >= 3, "it came for him again and again (%d times)" % heard.size())
	check(heard.all(func(h: Array) -> bool: return h[2]), "and each time his back was to it, so it took a real turn")
	rt.free()
	return true


## And the core, not the controller, is what kills: his death is the runtime's, once, and stops everything.
func test_the_core_decides_the_death() -> bool:
	ApartmentLayout.apply_initial_state()
	WorldState.act = WorldState.Act.IMPOSSIBLE
	var rt_stage := HorrorStage.new(RoomGraph.new(WorldState.variants))
	rt_stage.position = ApartmentLayout.room_center(&"hallway")
	rt_stage.yaw = BACK_TURNED
	WorldState.set_player_room(&"hallway")
	var rt := HorrorRuntime.new()
	rt.setup(rt_stage, 3)
	WorldState.set_entity(&"living", &"approaching")
	var deaths: Array[StringName] = []
	var on_died := func(cause: StringName) -> void: deaths.append(cause)
	EventBus.player_died.connect(on_died)
	var t := 0.0
	var evaluated_when_killed := -1
	while rt.dead == &"" and t < 10.0:
		rt.director._next_eval = 0.0  # the director would evaluate on every step it is allowed to run
		var evals := rt.director.eval_count
		rt.step(0.1)
		t += 0.1
		if rt.dead != &"":
			evaluated_when_killed = rt.director.eval_count - evals
	EventBus.player_died.disconnect(on_died)
	check(rt.director.eval_count > 0, "(the director did run in the steps before)")
	eq(evaluated_when_killed, 0, "but not in the step that killed him")
	eq(rt.dead, &"faced_away", "the runtime has him dead of it")
	eq(deaths, [&"faced_away"], "and says so once")
	check(t > EntityController.FACE_SECONDS - 0.5 and t < EntityController.FACE_SECONDS + 1.0, "after about four seconds (%.1f)" % t)
	check(rt.scheduler.running.is_empty() and rt.scheduler.queue.is_empty(), "nothing it started goes on")
	rt.free()
	return true
