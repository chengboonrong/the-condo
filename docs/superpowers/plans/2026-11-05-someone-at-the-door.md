# Someone at your door Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An act 2 fright where someone comes up the corridor and stands outside the front door (their feet break the light under it), and a peephole the player can look through to find the corridor empty.

**Architecture:** `VisitorEvent` is a new `HorrorEvent` in the headless simulation core; it asks for the feet through a new `EventBus.door_feet_requested` signal that `Decor` answers by swapping the light strip under the door. The peephole is an `Interactable` subclass on the front door with its own `Camera3D` outside the door; the HUD shows that camera through a fisheye lens shader, like a note it freezes the player and lets time run. Peeking reaches the event the way a silhouette sighting does: the runtime marks the run.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer (WebGL2 on the web), the project's own test runner (`tools/test.sh`).

**Spec:** `docs/superpowers/specs/2026-11-05-someone-at-the-door-design.md`

## Global Constraints

- Godot binary: `GODOT=/Users/chrischeng/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot` (never the /Applications copy). Tests: `GODOT=$GODOT tools/test.sh [--filter=<substring>]`.
- Typed GDScript, matching the surrounding code's comment density and naming. No asset files: shaders are inline strings (see `FILM_SHADER` in `scripts/ui/hud.gd`), geometry is built in code.
- The simulation core (`scripts/horror/**`) stays headless and deterministic: randomness only from `ctx.rng`, the world only through `ctx.stage`/`WorldState`, presentation only through `EventBus` signals.
- Captions, exactly: `"[A lift chimes down the corridor]"`, `"[Footsteps in the corridor, coming closer]"`, `"[The footsteps stop outside your door]"`. Nothing when the feet go.
- Prompt, exactly: `"Look through the peephole"`. Step-back hint, exactly: `"[E] step back"`.
- No figure or person is ever shown; no stinger; the loudest visitor sound stays below 0 dB (the knock3's level).
- Act 2 only (`min_act = 2`, `max_act = 2`), channel `audio_major`.
- Commits: stage files by name (never `git add -A`), message ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push, never `git stash`, never a model ID in any file.
- Shared Mac: stop only processes you started.

## Review Focus

1. The front door opens (a door event, or the story) while the player looks through the peephole: the view is on the door and would swing into the flat, so the peek must end. Test in Task 3.
2. Esc while looking through the peephole steps back instead of opening the pause menu, as it does for a note. Test in Task 3.
3. The E that steps back must not look through the peephole again on the same press. Test in Task 3.
4. A visit cancelled by anything (story knock, story ending) while the feet are shown must not leave them under the door. Test in Task 1 (pre-emption) and Task 2 (the signal's off state).
5. The first look through the peephole on the web must not stall on a shader compile: the lens is drawn during the warm-up. A compile cannot be observed from GDScript, so this is checked by reading `Main._compile_shaders` in review, not by a test.

---

### Task 1: The visitor in the simulation core

**Files:**
- Create: `scripts/horror/events/visitor_event.gd`
- Create: `resources/horror_events/visitor.tres`
- Modify: `scripts/core/event_bus.gd` (presentation signals block, next to `silhouette_requested`)
- Modify: `tests/unit/test_scheduler.gd:44` (seven → eight events)
- Test: `tests/unit/test_visitor.gd` (new)

**Interfaces:**
- Produces: `EventBus.door_feet_requested(shown: bool)` (Task 2 listens).
- Produces: event id `&"visitor"`; a running visit ends on its next tick when its run has `"peeked"` set (`scheduler.mark(&"visitor", "peeked")`, Task 3 calls it).
- Produces: `VisitorEvent.DOOR := Vector3(1.5, 0, 10.0)` (the front door on the floor; the doorway in `ApartmentLayout.CONNECTIONS`).

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_visitor.gd`, with the same `_setup(room, pos, yaw := 0.0, act := 2)`, `_teardown()` and `_run_for(seconds)` as `tests/unit/test_scheduler.gd`, plus listeners that append to one ordered `trail: Array`: `["sound", id, pos, db]`, `["feet", shown]`, `["caption", text]`.

```gdscript
func test_the_visitor_comes_to_the_door_and_waits() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	eq(run["state"], EventScheduler.State.RUNNING, "a visit starts in the living room with the door shut")
	eq(run["room"], &"corridor", "it happens in the corridor")
	_run_for(14.0)
	var sounds := trail.filter(func(e: Array) -> bool: return e[0] == "sound")
	eq(sounds[0][1], &"lift_ding", "the lift chimes first")
	var steps := sounds.filter(func(e: Array) -> bool: return e[1] == &"footstep")
	check(steps.size() >= 8, "footsteps come along the corridor")
	for i in range(1, steps.size()):
		check((steps[i][2] as Vector3).distance_to(VisitorEvent.DOOR) < (steps[i - 1][2] as Vector3).distance_to(VisitorEvent.DOOR), "step %d is closer to the door" % i)
		check(steps[i][3] >= steps[i - 1][3], "step %d is no quieter" % i)
	check((steps[-1][2] as Vector3).distance_to(VisitorEvent.DOOR) < 0.6, "the last step is at the front door")
	check(sounds.all(func(e: Array) -> bool: return e[3] < 0.0), "every sound under the knock's 0 dB")
	var shown := trail.find(["feet", true])
	check(shown > trail.rfind(steps[-1]), "the feet show after the last step")
	_run_for(30.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "the visit ends by itself")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet"), [["feet", true], ["feet", false]], "the feet go")
	check(trail.slice(shown).all(func(e: Array) -> bool: return e[0] != "sound"), "without a sound")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "caption").map(func(e: Array) -> String: return e[1]),
		["[A lift chimes down the corridor]", "[Footsteps in the corridor, coming closer]", "[The footsteps stop outside your door]"],
		"captions for the sounds only")
	_teardown()
	return true


func test_the_visitor_needs_the_door_shut_and_the_player_inside() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	WorldState.set_door(&"main_door", true, &"player")
	eq(sched.start(&"visitor")["reason"], "door_open", "not with the front door open")
	_teardown()
	for c: Array in [[&"corridor", Vector3(8, 0, 11.2), "player_not_inside"], [&"bedroom", Vector3(7.7, 0, 1.0), "player_not_inside"],
			[&"entrance", Vector3(1.5, 0, 9.0), "player_at_door"]]:
		_setup(c[0], c[1])
		eq(sched.start(&"visitor")["reason"], c[2], "%s: %s" % [c[0], c[2]])
		_teardown()
	for act in [1, 3]:
		_setup(&"living", Vector3(6.5, 0, 8.4), 0.0, act)
		eq(sched.start(&"visitor")["reason"], "act", "act %d: act 2 only" % act)
		_teardown()
	return true


func test_opening_the_door_or_peeking_ends_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	_run_for(14.0)
	WorldState.set_door(&"main_door", true, &"player")
	_run_for(0.2)
	eq(run["state"], EventScheduler.State.COMPLETED, "opening the door ends it: nobody there")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "and the feet are gone")
	_teardown()
	_setup(&"living", Vector3(6.5, 0, 8.4))
	run = sched.start(&"visitor")
	_run_for(4.0)  # still walking
	var at := trail.size()
	sched.mark(&"visitor", "peeked")
	_run_for(5.0)
	eq(run["state"], EventScheduler.State.COMPLETED, "looking through the peephole ends it, even on the way")
	check(trail.slice(at).all(func(e: Array) -> bool: return e[0] != "sound"), "the steps stop when you look")
	check(not trail.has(["feet", true]) or trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1] == ["feet", false], "no feet left under the door")
	_teardown()
	return true


func test_a_story_knock_preempts_the_visit() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4))
	var run := sched.start(&"visitor")
	_run_for(14.0)
	sched.request(&"knock_wall", {"anchor": &"knock_entrance_door"})
	eq(run["state"], EventScheduler.State.CANCELLED, "the act 3 knock pre-empts the visit (same channel)")
	eq(trail.filter(func(e: Array) -> bool: return e[0] == "feet")[-1], ["feet", false], "and takes the feet away")
	_teardown()
	return true
```

In `tests/unit/test_scheduler.gd` `test_definitions_are_sane`: `eq(sched.events.size(), 8, "eight events loaded")`.

- [ ] **Step 2: Run the tests to see them fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_visitor` and `--filter=test_scheduler`
Expected: FAIL (unknown event `visitor`; seven events loaded; `door_feet_requested` not a signal of EventBus).

- [ ] **Step 3: Add `signal door_feet_requested(shown: bool)` to `scripts/core/event_bus.gd`** next to `silhouette_requested`.

- [ ] **Step 4: Implement `class_name VisitorEvent extends HorrorEvent` in `scripts/horror/events/visitor_event.gd`**

  - `prepare(ctx, run) -> String`: `"door_open"` if `WorldState.is_door_open(&"main_door")`; `"player_not_inside"` unless `ctx.player_room()` is `&"entrance"`, `&"living"` or `&"kitchen"`; `"player_at_door"` if `ctx.stage.distance_to(DOOR) < MIN_DISTANCE` (2.5). Sets `run["room"] = &"corridor"`, `run["position"] = DOOR`, and builds `run["steps"]`: `steps` points (export, 16) 0.7 m apart along the corridor at z = 10.6 from the lift's side (x decreasing) towards x = 1.5, the last one at (1.5, 0, 10.35).
  - `start`: `lift_ding` at `ApartmentLayout.LIFT_POS + Vector3.UP * 1.5`, −8 dB, and its caption.
  - `update`: the first step 1.5 s after the chime, then one `footstep` every 0.55 s, volume `lerpf(-16.0, -5.0, i / (n - 1.0))`; the steps caption with the first step; after the last step `door_feet_requested.emit(true)` and the stop caption; done when `run.get("peeked")`, when the main door is open, or `hold` (export, 15.0) seconds after the feet showed. Peeked or an open door stop the steps at once.
  - `finish(ctx, run, result)`: `door_feet_requested.emit(false)` whenever the feet were shown, whatever the result.

- [ ] **Step 5: Create `resources/horror_events/visitor.tres`** in the format of `footsteps.tres`: `id = &"visitor"`, `intensity = 0.6`, `base_weight = 0.6`, `cooldown = 900.0`, `duration = 26.0`, `min_act = 2`, `max_act = 2`, `channels = PackedStringArray("audio_major")`, `behavior_weights = {"idle": 0.6, "light_dependence": 0.5, "curiosity": 0.3}`.

- [ ] **Step 6: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=test_visitor`, then `--filter=test_scheduler`, `--filter=test_director`
Expected: PASS.

- [ ] **Step 7: Commit** `scripts/horror/events/visitor_event.gd`, `resources/horror_events/visitor.tres` (and the `.uid` Godot writes for the script), `scripts/core/event_bus.gd`, `tests/unit/test_visitor.gd` (+ `.uid`), `tests/unit/test_scheduler.gd`: `feat: someone comes up the corridor and waits outside the front door`.

---

### Task 2: The feet under the door

**Files:**
- Modify: `scripts/world/decor.gd:27-36` (`_leak`, `_ready`) and `:470-484` (`_entrance`)
- Test: `tests/integration/test_horror_in_game.gd` (append)

**Interfaces:**
- Consumes: `EventBus.door_feet_requested(shown: bool)` (Task 1).
- Produces: two nodes under `Decor`, named `door_leak` (the whole strip, as now) and `door_leak_feet` (the strip with two gaps).

- [ ] **Step 1: Write the failing test**

```gdscript
func test_feet_break_the_light_under_the_front_door() -> bool:
	var main := await _main()
	var decor: Decor = main.builder.decor
	var whole: Node3D = decor.get_node("door_leak")
	var feet: Node3D = decor.get_node("door_leak_feet")
	check(whole.visible and not feet.visible, "door shut: the whole strip of light")
	EventBus.door_feet_requested.emit(true)
	check(feet.visible and not whole.visible, "someone outside: two gaps in it")
	WorldState.set_door(&"main_door", true, &"player")
	check(not feet.visible and not whole.visible, "door open: no strip at all")
	WorldState.set_door(&"main_door", false, &"player")
	check(feet.visible and not whole.visible, "shut again while they are there: the gaps")
	EventBus.door_feet_requested.emit(false)
	check(whole.visible and not feet.visible, "gone: the whole strip again")
	main.queue_free()
	return true
```

- [ ] **Step 2: Run it to see it fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_horror_in_game`
Expected: FAIL (no node `door_leak`).

- [ ] **Step 3: Implement in `Decor`**: name the existing leak `door_leak`; build `door_leak_feet` beside it with the same material (`lm`, so no new shader variant) from `shade()` segments of the same strip, leaving two soft-edged gaps about 0.1 m wide centred at x = 1.37 and x = 1.63; keep a `_feet := false` flag; one `_show_leak()` sets `door_leak.visible = shut and not _feet`, `door_leak_feet.visible = shut and _feet`, called from the `door_changed` listener and a new `door_feet_requested` listener.

- [ ] **Step 4: Run the test**

Run: `GODOT=$GODOT tools/test.sh --filter=test_horror_in_game`
Expected: PASS.

- [ ] **Step 5: Commit** `scripts/world/decor.gd`, `tests/integration/test_horror_in_game.gd`: `feat: the visitor's feet break the light under the front door`.

---

### Task 3: The peephole

**Files:**
- Create: `scripts/world/peephole.gd`
- Modify: `scripts/world/apartment_builder.gd` (`_build_door`, the `main_door` branch)
- Modify: `scripts/core/event_bus.gd` (UI requests, next to `inspect_requested`)
- Modify: `scripts/ui/hud.gd` (lens overlay, peephole mode, input, ending)
- Modify: `scripts/main.gd` (`_compile_shaders`: draw the lens once)
- Modify: `scripts/horror/horror_runtime.gd` (peeks mark the visit)
- Test: `tests/integration/test_horror_in_game.gd` (append)

**Interfaces:**
- Consumes: `&"visitor"` and its `"peeked"` mark (Task 1).
- Produces: `class_name Peephole extends Interactable` with `var view: Camera3D`; the node is the main door's child named `peephole`.
- Produces: `EventBus.peephole_requested(view: Camera3D)`; HUD methods `show_peephole(view: Camera3D) -> void`, `close_peephole() -> void`, `is_peeping() -> bool`, `set_lens(on: bool) -> void`; `is_inspecting()` becomes true while peeping too.

- [ ] **Step 1: Write the failing tests.** `_look_at(player, stand: Vector3, point: Vector3)` puts the player at `stand` and sets its look with `set_look(yaw, pitch)` towards `point` (as `test_interaction_reach` does). Press keys with `InputEventAction` (`action`, `pressed = true`) through `main.get_viewport().push_input(ev)`.

```gdscript
func test_the_peephole_shows_the_corridor() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var hole: Peephole = main.builder.doors[&"main_door"].get_node("peephole")
	check(absf(hole.global_position.x - 1.5) < 0.03 and absf(hole.global_position.y - 1.565) < 0.03 and hole.global_position.z < 9.93,
		"on the door's inside face, at 1.55 m")
	_look_at(player, Vector3(1.5, 0, 9.0), hole.global_position)
	await _frames(3)
	eq(player.interaction.target, hole, "the peephole is what the player looks at")
	eq(hole.get_prompt(), "Look through the peephole", "its prompt")
	player.interaction.try_interact()
	await _frames(2)
	var view := main.get_viewport().get_camera_3d()
	check(view == hole.view and view.global_position.z > 9.96, "the view is from the outside of the door")
	check((-view.global_basis.z).dot(Vector3.BACK) > 0.95, "looking into the corridor")
	check(main.hud.is_peeping() and not player.input_enabled, "the player is held at the door")
	var t := WorldState.time
	await _frames(30)
	check(WorldState.time > t, "time keeps running")
	_press(main, &"interact")
	await _frames(3)
	eq(main.get_viewport().get_camera_3d(), player.camera, "E steps back")
	check(player.input_enabled and not main.hud.is_peeping(), "and does not look again on the same press")
	player.interaction.try_interact()
	await _frames(2)
	_press(main, &"pause")
	await _frames(2)
	check(not main.hud.is_peeping() and not main.pause.is_open(), "Esc steps back too, without the menu")
	player.interaction.try_interact()
	await _frames(2)
	WorldState.set_door(&"main_door", true, &"event")
	await _frames(2)
	check(not main.hud.is_peeping(), "the door opening ends the look")
	eq(hole.get_prompt(), "", "nothing to look through while the door is open")
	main.queue_free()
	return true


func test_peeking_during_a_visit_ends_it() -> bool:
	var main := await _main()
	main.player.global_position = Vector3(6.5, 0, 8.4)
	await _frames(2)
	var run: Dictionary = main.runtime.scheduler.start(&"visitor", {"ignore_act": true})
	eq(run["state"], EventScheduler.State.RUNNING, "a visit is on")
	var hole: Peephole = main.builder.doors[&"main_door"].get_node("peephole")
	hole.interact(main.player)
	await _frames(3)
	eq(run["state"], EventScheduler.State.COMPLETED, "looking through the peephole ends it")
	main.hud.close_peephole()
	main.queue_free()
	return true
```

(`main.pause` is the pause menu as `scripts/main.gd` names it; if the name differs, use the one there.)

- [ ] **Step 2: Run them to see them fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_horror_in_game`
Expected: FAIL (no node `peephole`).

- [ ] **Step 3: Implement `Peephole` in `scripts/world/peephole.gd`**: `get_prompt()` returns `""` while `WorldState.is_door_open(&"main_door")`, else `super()`; `interact(player)` emits `EventBus.peephole_requested.emit(view)`, then `super.interact(player)` (which emits `object_interacted(&"peephole")`). Add `signal peephole_requested(view: Camera3D)` to `EventBus`.

- [ ] **Step 4: Place it in `ApartmentBuilder._build_door`** (main door only): a `Peephole` child of the door named `peephole`, `object_id = &"peephole"`, `prompt = "Look through the peephole"`, with a 0.12 × 0.12 × 0.02 m collision box flush with the panel's inside face, centred on the model's peephole (door-local x = panel x + 0.477, y = panel y + 1.55; `art/front_door/build.py` `PEEPHOLE`). Its `view` is a child `Camera3D`, not current, just outside the panel's outside face, turned to face +z (the corridor), field of view and near plane tuned in Task 4's still (start at fov 120, near 0.02).

- [ ] **Step 5: Peephole mode in `HUD`**: a full-screen lens `ColorRect` with an inline `LENS_SHADER` (canvas_item, `hint_screen_texture`: barrel bend that squeezes the edges, black outside a circle about 0.45 of the screen height, darkening towards the rim), drawn above the film and below the labels; a `BackBufferCopy` before it if that is what keeps the soft filter visible under it. `show_peephole` makes `view` current, shows the lens and the `"[E] step back"` hint, hides crosshair and prompt, holds the player as `show_inspect` does; `close_peephole` puts `player.camera` back and undoes the rest as `close_inspect` does (the deferred `enabled_input`); `_unhandled_input` steps back on interact or pause while peeping; a `door_changed` for `main_door` opening steps back; the ending card steps back too. Connect `EventBus.peephole_requested`.

- [ ] **Step 6: Warm-up and runtime.** In `Main._compile_shaders`, `hud.set_lens(true)` for one frame and then `false`. In `HorrorRuntime`, connect `EventBus.object_interacted` (disconnect in `_exit_tree`); a `&"peephole"` is queued like `_sightings` and applied at the top of `step()` as `scheduler.mark(&"visitor", "peeked")`.

- [ ] **Step 7: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=test_horror_in_game`, then `--filter=test_hud`, `--filter=test_apartment`
Expected: PASS.

- [ ] **Step 8: Commit** the files above (+ `.uid` of the new script): `feat: look through the front door's peephole`.

---

### Task 4: Stills, docs and the whole suite

**Files:**
- Modify: `tools/stills.gd` (two shots)
- Modify: `docs/event-catalog.md`, `docs/architecture.md`, `docs/roadmap.md`, `docs/playthroughs.md` (generated)
- Possibly modify: `scripts/world/peephole.gd`, `scripts/ui/hud.gd`, `scripts/world/decor.gd` (numbers tuned from the stills)

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Two stills in `tools/stills.gd`**, in its pattern: `door_feet` from the living room looking at the bottom of the front door, the entrance light off, the feet shown (`EventBus.door_feet_requested.emit(true)` before the shot, `false` after); `peephole`, the HUD's peephole view (`hud.show_peephole(...)`) of the corridor. Neither may show anything of the reveal.

- [ ] **Step 2: Render and look.** With the 1920×1080 `override.cfg` pattern from `tools/itch.sh` (refuse if it exists, remove it by trap): `$GODOT --path . --script res://tools/stills.gd -- --out=/tmp/condo-stills/door`. Expected: both PNGs exist; the gaps read as two feet standing at the door; the lens reads as a peephole (bent edges, round black mask) and shows an empty corridor. Tune the numbers until they do; report the paths.

- [ ] **Step 3: Docs.** `docs/event-catalog.md`: a `visitor` row (act 2, `audio_major`, preconditions, three endings), its captions, and that peeking ends it. `docs/architecture.md`: the two new signals in the EventBus list, the feet (Decor's two strips) and the peephole view (camera on the door, the lens, time runs) in the Look section. `docs/roadmap.md`: replace the line "Repository: local only until the owner approves creating the public GitHub repo" with the public repo https://github.com/chengboonrong/the-condo. Regenerate `docs/playthroughs.md` with `$GODOT --headless --path . --script res://tools/playthroughs.gd` (the command in that file's header if it differs).

- [ ] **Step 4: The whole suite**

Run: `GODOT=$GODOT tools/test.sh`
Expected: every test passes (109 before this plan, plus the new ones), the three bots reach both endings.

- [ ] **Step 5: Commit** the stills tool and the docs (and any tuned files): `docs: the visitor and the peephole; stills of both`.
