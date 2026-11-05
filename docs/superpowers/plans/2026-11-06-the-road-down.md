# The Road Down, Part 1: The Road. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a playable road down the mountain in front of THE CONDO's flat: the lift down, five rule missions, a gory
penanggal and three road endings. Every road ending then wakes him in today's flat at 11:47.

**Architecture:** The road is its own scene (`scenes/road.tscn`), which becomes the project's main scene. A small
autoload, `Journey`, carries the road's ending into `scenes/main.tscn`, which is today's flat with its start card
skipped. The road's simulation core is headless and deterministic, like the flat's. It is a `RoadDirector` that runs
five `RoadMission`s in order. It keeps one weighted count of broken rules, and from that count it decides the
outcome. Presentation nodes read the director's ride state each frame. One-off moments come through `EventBus`
signals (`road_cue`, the choices, `road_ended`). Rule-based bots play the core and reach all three outcomes.

**Tech Stack:** Godot 4.7.2, typed GDScript, the Compatibility renderer (WebGL2 on the web). Models come from Blender
5.2 scripts (`art/<id>/build.py`, `tools/models.sh`). Sounds are synthesised in `tools/gen_audio.py`. Web checks use
Playwright 1.63 in WebKit and Chromium.

**Spec:** `docs/superpowers/specs/2026-11-06-the-road-down-design.md` (owner-approved 2026-11-06).

**Scope.** This is part 1 of 2. It ends with every road ending leading into the existing flat, which is the jam
version the spec's "If time runs short" keeps. Part 2, the two flats, gets its own plan once this one is built:
- the alive flat: haunted, a quiet ending, and a small sign if Hafiz was lost;
- the dead flat: clues that point back to the road, and the realisation.

The owner cuts the alive flat first. Part 2 reads `Journey.road_ending`, which Task 1 creates.

**Base:** branch `feat/the-road-down`, made from the tip of `feat/someone-at-the-door` once its final review is done.

## Global Constraints

- Godot 4.7.2 (`GODOT=/Users/chrischeng/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot`, never the /Applications
  copy). Typed GDScript, the Compatibility renderer, web and desktop builds.
- "The simulation core stays headless and deterministic, and talks to the presentation through `EventBus`." The road's
  core files (`road_director.gd`, `road_mission.gd`, `road_stage.gd`, `road_layout.gd`, `missions/*`) are
  `RefCounted`. They touch no nodes and no rendering, and they draw randomness only from the director's seeded RNG.
- "`tools/test.sh` must pass, and the bots must reach every ending, the new ones included."
  `GODOT=$GODOT tools/test.sh` ends `Results: N passed, 0 failed`. The "ObjectDB instances were leaked" and
  "resources still in use" lines at exit are pre-existing.
- "No paid assets or services, and no external LLM APIs." Places are built in code, models come from Blender
  scripts, and sounds are synthesised in code. A CC0 asset is allowed only if the credits name it.
- "Never claim a frame time that was not measured." Bots are bots: never call a simulated run a playtest.
- "No shader compiles mid-game": the road's warm-up draws every road material, including the penanggal and her gore.
- No real places, brands or deaths, no real temple, and no "true story" framing.
  - Cars carry no badge and no make name, and nobody in the game names a car.
  - The invented resort and road names are checked against real places and products (Task 3).
- "Not a driving game": Hafiz drives and the player rides in the back seat. "No voice acting": every line is a caption.
- Caption style is the flat's:
  - sounds, thoughts and remembered words go in brackets: `[The wall is cold.]`;
  - spoken lines go as `Name: "…"`, for example `Mei: "Eh, you going down ah?"`.

  The couple talk Manglish. He is never named, and his thoughts are in the second person, as in the flat.
- Names (my call, from the spec's "Left to the builder"): Hafiz (driving), Mei (his girlfriend), and Bang Din (the
  older colleague at the stall whose rules he remembers).
- Malaysia drives on the left. The car is right-hand drive: Hafiz front right, Mei front left, him rear left (behind
  Mei), and the fourth rear right (behind Hafiz).
- `view_yaw` is in radians. 0 means facing the way the car (or the walk) goes, positive is to his left, and it is
  always read wrapped to [-π, π].
- Tease-only: the trailer, the stills you publish and the itch page never show his death, the bedroom window as a
  door, B-11-07, any ending's name, or the penanggal in full. Stills made for checking stay in `/tmp`.
- The web `index.pck` stays under the 8912 KiB cap that `tools/smoke.sh` checks. If the road can't fit, stop and
  report.
- Never run `tools/export.sh`: it starts with `rm -rf builds`, which wipes the trailer and the itch images. Web
  checks export to `/tmp` (Task 11).
- Never leave an `override.cfg` in the repo, and never use a bare `git stash`. Don't push or merge without the
  owner's approval; main keeps today's game.
- The shared Mac runs other people's processes: stop only processes you started.
- Each commit ends with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No model names
  anywhere else.

## Review Focus

1. **Esc, a lost window focus, or the web dropping pointer lock** during a choice or a look rule.
   - The choice stays open, and no rule breaks while the game is paused.
   - The road keeps the flat's web rule: half a second in play without pointer lock opens the pause menu.
   - Tests: Task 1 (`test_road_guards_pointer_lock_like_the_flat`) and Task 2 (`test_choices_close_only_when_the_core_says`).
2. **Turning the mouse through a full circle, or the car taking a hairpin** under a player who keeps still.
   - Facing forward after a full turn never counts as looking back.
   - A hairpin never counts as turning round.
   - Tests: Task 2 (`test_view_yaw_wraps`) and Task 4 (`test_relative_yaw_follows_the_car`).
3. **Pressing 1, 2 or 3 with no choice open**, twice in one choice, or after a choice has closed: only the first
   press during an open choice counts. Test: Task 2 (`test_stray_choice_keys_do_nothing`).
4. **Restart**, from the pause menu or by clicking after the flat's ending: it goes back to the start of the road,
   with `Journey` cleared, not into the flat again. Test: Task 1 (`test_restart_goes_back_to_the_road`).
5. **Reduced flashing**: with that setting on, the dying headlights, the tunnel lights and the passing lights dim
   smoothly and never strobe. Test: Task 9 (`test_dying_lights_respect_reduced_flashing`).

---

### Task 1: The road comes first

The thin handoff. `road.tscn` becomes the main scene. For now it shows the start card, and a click hands straight
over to the flat. The flat then skips its start card and wakes him at 11:47.

**Files:**
- Create: `scripts/core/journey.gd`, `scenes/road.tscn`, `scripts/road/road_main.gd`, `tests/integration/test_journey.gd`
- Modify: `project.godot` (the `Journey` autoload after `Settings`; `run/main_scene="res://scenes/road.tscn"`)
- Modify: `scripts/main.gd`, `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`, `tools/smoke.sh`, `tools/web_smoke.mjs`

**Interfaces:**
- Produces, in `Journey` (autoload, `extends Node`):
  - `const ROAD_SCENE := "res://scenes/road.tscn"` and `const FLAT_SCENE := "res://scenes/main.tscn"`;
  - `var road_ending: StringName = &""`: the road's outcome; `&""` means the flat was opened directly;
  - `var change_scenes := true`: tests and tools set it false;
  - `func arrive(ending: StringName) -> void`: sets `road_ending`, then changes to the flat if `change_scenes`;
  - `func restart() -> void`: clears `road_ending`, then changes to the road if `change_scenes`.
- Produces, in `Hud`:
  - `func show_card(text: String) -> void`: a black full-screen card with centred text. It draws over the 3D view and
    the HUD labels, but under the subtitles and the pause menu;
  - `func hide_card(seconds: float) -> void`;
  - `func is_card_shown() -> bool`.
- Produces, in `PauseMenu` (the pointer-lock and focus rules move here from `Main._process` and
  `Main._notification`, unchanged):
  - `func guard(delta: float, playing: bool, web: bool) -> void`;
  - `func focus_lost(playing: bool) -> void`.
- Produces, in `RoadMain` (`extends Node3D`, `class_name RoadMain`): `player`, `hud`, `pause`, `var loaded := false`,
  `signal finished(ending: StringName)`, and `func finish(ending: StringName) -> void`, which emits `finished` and
  then calls `Journey.arrive(ending)`.

- [ ] **Step 1: Write the failing tests** in `tests/integration/test_journey.gd`. Each test sets
  `Journey.change_scenes = false` and puts `Journey` back as it was when it ends.

```gdscript
func test_flat_opened_directly_keeps_its_start_card() -> bool:  # road_ending == &"": exactly today's flat
	# instance main.tscn, await main.loaded
	check(main.hud.is_on_start_card(), "start card shown")
	check(not main.runtime.story_running, "story waits for the click")

func test_arriving_from_the_road_wakes_at_1147() -> bool:
	# for each of &"alive", &"saved", &"caught": Journey.road_ending = it; instance main.tscn
	check(main.hud.is_card_shown(), "wake card from the first frame")  # before the warm-up ends
	eq(main.hud.card_text(), "11:47 PM", "same card for every road ending")
	# await main.loaded
	check(not main.hud.is_on_start_card(), "no start card")
	check(main.runtime.story_running, "the story starts without a click")
	eq(WorldState.clock_minutes(), 23 * 60 + 47, "the clock reads 11:47")

func test_the_road_hands_over_on_the_click() -> bool:
	# instance road.tscn, await road.loaded, road.hud.start()
	eq(ending_from(road.finished), &"alive", "for now, the road ends at once, all alive")  # from Task 2 on: call road.director.debug_skip() until it ends
	eq(Journey.road_ending, &"alive", "Journey carries it")

func test_restart_goes_back_to_the_road() -> bool:
	# Journey.road_ending = &"caught"; PauseMenu's Restart button pressed; the ending card's click on main
	eq(Journey.road_ending, &"", "Restart clears the road's ending")  # both call sites go through Journey.restart()

func test_road_guards_pointer_lock_like_the_flat() -> bool:
	# pause.guard(0.3, true, true) → not open; guard(0.3, true, true) again → open; guard(1.0, false, true) → never
	# guard(1.0, true, false) → never (not the web)
```

  `card_text()` is a getter on `Hud`, for tests. Add it with the card.
- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=journey`. Expected: FAIL, because `Journey` doesn't exist yet.
- [ ] **Step 3: Implement** the interfaces above.
  - **`RoadMain._ready`:**
    - `WorldState.reset()`;
    - the player at the origin, with input off until the start;
    - `PauseMenu`, `hud.bind(player)` and `hud.started.connect(...)`;
    - `loaded = true` and `hud.allow_start()`, deferred.

    For now, the start makes it call `finish(&"alive")`.
  - **`RoadMain` copies `Main`'s pause wiring:**
    - `_unhandled_input`: Esc opens the menu, and a click captures the mouse;
    - `_process` calls `pause.guard(delta, (player.input_enabled or hud.is_inspecting()) and not _automated, OS.has_feature("web"))`;
    - `_notification` calls `pause.focus_lost(...)`.

    `Main` makes the same calls. The one change from today: `playing` now counts reading a note or peeping, so on
    the web the menu opens when Esc drops pointer lock there. Until now the player got a cursor and had to press E.
    That was the visitor branch's final review, Minor 2.
  - **Flags:** `--flat` / `?flat` and `--perf` / `?perf` change straight to the flat with `road_ending` left `&""`, so
    the flat's start card and `PerfProbe` work as today. Task 11 gives the road its own perf route.
  - **`--smoke` / `?smoke`:** the road starts at once and runs 3 s. It prints
    `ROAD-SMOKE ok|FAIL time=<WorldState.time> gpu=<adapter>`, then `finish(&"alive")`. The flag carries over, so the
    flat's `SMOKE` line follows. The desktop quits 1 on a road FAIL.
  - **`Main` arriving from the road** (`Journey.road_ending != &""`): `hud.show_card("11:47 PM")` in `_ready`. After
    the warm-up, `_finish_loading` calls `hud.start()`, then `hud.hide_card(1.5)`. `hud.start()` must do nothing the
    second time, because the smoke calls it as well.
  - **Both restart paths** go through `Journey.restart()`: `Hud`'s click after the ending and `PauseMenu`'s Restart.
  - **The smoke scripts:** `tools/smoke.sh` and `tools/web_smoke.mjs` require a `ROAD-SMOKE ok` line before
    `SMOKE ok`, except with `--flat`. A line starting `ROAD-SMOKE` must not satisfy the existing `SMOKE` prefix match.
- [ ] **Step 4: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`, and every existing test passes unchanged.
- [ ] **Step 5: Smoke the desktop from the project.** Run `$GODOT --path . -- --smoke`. Expected: `ROAD-SMOKE ok`,
  then `SMOKE ok ... beat=home`, and exit 0.
- [ ] **Step 6: Commit** with the message `feat: the road comes first, and hands over to the flat at 11:47`.

### Task 2: The road's core

The headless director, its rule count and the choices. Mission 1 is built as core only (the opening, the walk to the
stop, the wait, getting in), along with the bots that play it.

**Files:**
- Create: `scripts/road/road_stage.gd`, `scripts/road/road_layout.gd`, `scripts/road/road_director.gd`,
  `scripts/road/road_mission.gd`, `scripts/road/missions/lift_mission.gd`, `tests/sim/road_playthrough.gd`
- Create tests: `tests/unit/test_road_director.gd`, `tests/unit/test_road_layout.gd`,
  `tests/unit/test_lift_mission.gd`, `tests/integration/test_road_playthroughs.gd`
- Modify: `scripts/core/event_bus.gd`, `scripts/ui/hud.gd`, `project.godot` (inputs `choice_1`/`choice_2`/`choice_3`
  on keys 1/2/3 and keypad 1/2/3), `scripts/road/road_main.gd`, `tests/integration/test_hud.gd`

**Interfaces:**
- Consumes: `RoadMain` and `Hud` from Task 1; `WorldState` (`advance_time`, `set_objective`, `set_prompt`,
  `clock_anchor`); `EventBus.subtitle_requested`, `EventBus.object_interacted`.
- Produces, in `EventBus`:
  - `signal choices_requested(choice_id: StringName, options: PackedStringArray)`;
  - `signal choices_closed(choice_id: StringName)`;
  - `signal choice_made(choice_id: StringName, index: int)`;
  - `signal road_cue(cue: StringName)`;
  - `signal road_line(speaker: StringName, seconds: float)`: who speaks, so the presentation can turn heads;
  - `signal road_ended(ending: StringName)`.
- Produces, in `RoadStage` (`RefCounted`):
  - `var view_yaw := 0.0` and `var position := Vector3.ZERO`, which bots set;
  - `func relative_yaw() -> float`, which returns `wrapf(view_yaw, -PI, PI)`;
  - `func player_position() -> Vector3`.
- Produces, in `RoadLayout` (static data and math, no nodes):
  - `const LANE := 1.8`, `const WIDTH := 7.2` and `const LENGTH: float` (at least 3000);
  - `static func point(s: float, across := 0.0) -> Vector3`: across is metres to the left of the centreline, in the
    direction of travel;
  - `static func tangent(s: float) -> Vector3`;
  - `static func closest_s(pos: Vector3) -> float`;
  - `static func min_radius() -> float`;
  - `const BUS_STOP_S := 0.0`, `const BUS_STOP := Vector3(...)` (on the left verge at s 0), `const EXIT := Vector3(...)`
    (the staff exit, 40–60 m back up the road from the stop), and `const TUNNEL := Vector2(start_s, end_s)`.
- Produces, in `RoadDirector` (`RefCounted`):
  - `const ALIVE_MAX := 2`, `const SAVED_MAX := 6`, `const CLOCK_START := 6` (minutes past midnight) and
    `const NONE := -2`;
  - `func _init(road_stage: RoadStage, seed_value: int, mission_list: Array[RoadMission] = default_missions())`;
  - `static func default_missions() -> Array[RoadMission]`, which is `[LiftMission]` for now; Tasks 6, 7, 9 and 10
    append to it;
  - `func step(delta: float) -> void`, in this order: `WorldState.advance_time`, captions, choice timeout, look
    rule, mission, ride;
  - `func start_at(mission_index: int) -> void`: the state as if every earlier mission was kept (seated, the car
    at that mission's start). It serves the tools, stills and the owner's `--mission=N` / `?mission=N`;
  - `func say(text: String, seconds := 3.5, speaker: StringName = &"") -> void`;
  - `func ask(choice_id: StringName, options: PackedStringArray, seconds: float, keeps: PackedInt32Array, rule: StringName = &"", weight := 1) -> void`.
    `keeps` lists the answers that keep the rule; -1 in it means silence keeps. A non-keeping answer calls
    `break_rule(rule, weight)` by itself;
  - `func answer(choice_id: StringName) -> int`: `NONE` while the choice is open, -1 for silence, otherwise the index;
  - `func watch_look(rule: StringName, left: float, right: float, hold: float, weight: int, max_count: int) -> void`.
    It breaks when `relative_yaw() > left` or `relative_yaw() < -right` has held for `hold` seconds. Another break
    can only follow once the yaw has been back within ±0.8 rad;
  - `func stop_look() -> void`;
  - `func break_rule(rule: StringName, weight := 1) -> void`: records `{"rule", "weight", "t", "mission"}`, raises
    `fog` and `her_near` by `0.12 * weight` each (both capped at 1), and emits `road_cue(&"rule_broken")`;
  - `func score() -> int`, and `func outcome() -> StringName`: `&"alive"` if the score is at most `ALIVE_MAX`, else
    `&"saved"` if it is at most `SAVED_MAX`, else `&"caught"`;
  - `func end() -> void`: `ending = outcome()`, then emits `road_ended`;
  - `func debug_skip() -> void`;
  - ride control: `func drive(speed: float) -> void`, `func stop_at(s: float) -> void` (eases to a stop exactly at s)
    and `func lane_to(across: float) -> void`;
  - state the presentation reads each frame: `car_s`, `car_speed`, `lane`, `seated`, `fog`, `her_near`, `slow_gap`
    (NAN when there is no slow car), `light_s` (-1 until set), `mission_index`, `pending`, `look_rule`, `broken`,
    `progress` (`{"t", "mission", "beat"}`) and `ending`.
- Produces, in `RoadMission` (`RefCounted`):
  - `var d: RoadDirector`, `var beat: StringName` and `var beat_t := 0.0`;
  - `func begin() -> void`, `func tick(delta: float) -> bool` (true when done) and `func go(next: StringName) -> void`
    (resets `beat_t` and appends to `d.progress`);
  - `func set_up_skipped() -> void`: puts the director in the state this mission starts in, as if every earlier
    mission was kept (seated or not, `car_s`, `light_s` and so on). `start_at(n)` calls it on mission n. Every mission
    task implements its own.
- Produces, in `Hud`:
  - `func show_choices(choice_id: StringName, options: PackedStringArray) -> void`, which numbers the options 1–3 at
    the bottom centre, above the subtitle;
  - `func close_choices(choice_id: StringName) -> void` and `func is_choosing() -> bool`;
  - the keys `choice_1..3` emit `EventBus.choice_made` once, then the HUD ignores keys until the next choice.

  The HUD never closes a choice by itself; only `choices_closed` does.
- Produces, in `RoadPlaythrough` (`class_name`, mirroring `tests/sim/playthrough.gd`): `static func run(profile: String, seed_value: int) -> Dictionary`.
  - It returns `{"profile", "seed", "ending", "time", "score", "broken", "progress", "errors", "warnings"}`.
  - The profiles are `keeper`, `wobbly` and `breaker`. Each follows the policy table in Task 10, one row per mission
    as the missions are added.
  - The bot walks at 2.2 m/s along `RoadLayout`, answers 1.0 s after a choice opens, and uses a prompted object 0.5 s
    after its prompt appears.
- Cues from this task: `&"card_on"`, `&"card_off"`, `&"lorry_passes"`, `&"couple_stops"`, `&"seated"` and
  `&"rule_broken"`.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_road_director.gd: a RoadDirector over a stub mission list, stepped at 0.1 s
func test_score_decides_the_outcome() -> bool:  # weights summing to 2 → &"alive", 3 → &"saved", 6 → &"saved", 7 → &"caught"
func test_a_broken_rule_costs_fog_and_brings_her_closer() -> bool:  # weight 2: fog and her_near each +0.24, one &"rule_broken" cue
func test_choices_silence_and_keeps() -> bool:
	# ask(&"a", 3 options, 5.0, [0, -1], &"r", 2): no answer for 5 s → answer(&"a") == -1, score 0, choices_closed(&"a")
	# ask(&"b", ..., [0], &"r", 2) then choice_made(&"b", 1) → answer == 1, score 2
	# choice_made(&"b", 0) after it closed → answer stays 1
	# choice_made(&"zzz", 0) → ignored
func test_look_rule_needs_a_hold_and_a_return() -> bool:
	# watch_look(&"turned", 2.2, 1.0, 0.4, 1, 1): yaw -1.2 for 0.3 s → no break; for 0.5 s → one break; held 10 s → still one
	# yaw +1.5 (out of his own window) for 5 s → no break
	# watch_look(&"back", 1.9, 1.9, 0.25, 3, 2): back 0.3 s → 3; stays back → 3; centre, then back again → 6; a third look → 6
func test_view_yaw_wraps() -> bool:  # view_yaw TAU + 0.1 → relative_yaw ≈ 0.1, no break of a 1.9 rule
func test_road_clock_starts_after_midnight() -> bool:  # after _init, WorldState.clock_minutes() == 6, so the HUD reads 12:06 AM
func test_road_core_leaves_no_connections() -> bool:  # director freed → EventBus.choice_made and object_interacted have no road connections

# test_road_layout.gd
func test_the_road_is_long_enough() -> bool:  # LENGTH >= 3000
func test_the_road_is_continuous() -> bool:  # point(s) and point(s + 1) never more than 1.05 m apart, s from -200 to LENGTH
func test_bends_are_drivable() -> bool:  # min_radius() >= 20; every 10 m, the drop is between 0 and 1 m (downhill, at most 10 %)
func test_closest_s_round_trips() -> bool:  # |closest_s(point(s, x)) - s| < 0.5 for s every 50 m, x in [-3.6, 3.6]
func test_places_are_in_order() -> bool:  # EXIT is uphill of BUS_STOP; 200 <= TUNNEL.x < TUNNEL.y <= 1200

# test_lift_mission.gd
func test_opening_then_walk_then_wait() -> bool:  # cues in order card_on, card_off, lorry_passes, couple_stops; objective set at walk
func test_the_car_door_works_only_once_the_car_has_stopped() -> bool:  # car_door before couple_stops → nothing; after → seated, cue &"seated"
func test_waiting_away_from_the_stop_does_not_bring_the_car() -> bool:  # no couple_stops while the player is more than 3 m from BUS_STOP

# test_road_playthroughs.gd
func test_road_bots_reach_an_ending() -> bool:  # for seeds [1147, 7, 2026] × the three profiles: ending != &"", errors == [], warnings == []
func test_same_seed_same_road() -> bool:  # keeper 1147 twice → same time, same progress, same broken

# test_hud.gd (add)
func test_choices_close_only_when_the_core_says() -> bool:  # show_choices, then 30 s of frames → is_choosing(); choices_closed → not
func test_stray_choice_keys_do_nothing() -> bool:  # choice_1 pressed with no open choice → no choice_made; two presses in one choice → one emit
func test_choice_box_fits_the_screen() -> bool:  # at 1280×720 and 2560×1080, three 60-character options lie inside the viewport and do not overlap the subtitle
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=road`. Expected: FAIL, because the classes don't exist.
- [ ] **Step 3: Implement** the interfaces.
  - **`RoadLayout`:** a const list of segments (`["straight", length]` or `["bend", radius, degrees]`), at a constant
    6 % downhill. The curve is built once into a cached `Curve3D` (bake interval 1 m), from s = -200 (the resort side)
    to `LENGTH`. Include at least six switchbacks of radius 22–35 m.
  - **`LiftMission`** has four beats, `&"opening"`, `&"walk"`, `&"wait"` and `&"get_in"`:
    - **opening:** `card_on`, then the pinned opening lines below, then `card_off`, about 14 s in all;
    - **walk:** sets the objective; it is done within 3 m of `BUS_STOP`;
    - **wait:** `lorry_passes` at 20 s. At 45 s, `drive(9)` from s = -150 then `stop_at(BUS_STOP_S)`, with
      `couple_stops` when stopped. Then `Mei: "Eh, you going down ah? Jom, we got space."` and
      `set_prompt(&"car_door", "Get in")`;
    - **get_in:** `object_interacted(&"car_door")` sets `seated = true`, emits `seated`, clears the prompt, and
      plays two lines of small talk.

    It is done then. With only this mission, the director ends after it, all alive.
  - **`RoadMain`:**
    - owns a `RoadDirector` over a `RoadStage`, with seed `Main.SEED`, and steps it in `_physics_process` while
      playing;
    - wires `choices_requested`/`choices_closed` to the HUD, `card_on`/`card_off` to `hud.show_card("")` and
      `hud.hide_card(1.0)`, and `road_ended` to `finish`;
    - reads `--mission=N` for `start_at`.

    The presentation of the walk and the car comes in Tasks 3 and 4. Until then the player stands at `EXIT`.
- [ ] **Step 4: Copy these opening lines verbatim** (they are the rules intro the spec asks for):

```
[12:06 AM. The last staff bus went down the mountain at eleven.]
[Bang Din at the stall says the road down has rules. He only tells them after midnight.]
[You laughed. He didn't.]
```

  The objective at the walk beat is `Walk down to the bus stop and wait for a lift.`
- [ ] **Step 5: Update Task 1's `test_the_road_hands_over_on_the_click`.** After the start, it calls
  `road.director.debug_skip()` until the road ends. Then run `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: the road's core, its rule count, choices and the wait for a lift`.

### Task 3: The road

The mountain road, built in code from `RoadLayout`.

**Files:**
- Create: `scripts/road/road_builder.gd`, `tools/road_stills.gd`, `tools/road_stills.sh`,
  `tests/integration/test_road_builder.gd`
- Modify: `scripts/road/road_main.gd`, `scripts/world/look.gd` (`var grade_override: StringName = &""` and a
  `&"road"` grade), `docs/architecture.md` (only the invented-name check table)

**Interfaces:**
- Consumes: `RoadLayout` (Task 2), `Look`, and `ApartmentBuilder.tile_material`/`_plaster` patterns, for reference only.
- Produces, in `RoadBuilder` (`Node3D`):
  - `var environment: Environment`;
  - `func set_fog(amount: float) -> void`: 0 gives density 0.035 and 1 gives 0.11. These are starting values, so
    tune them on the stills;
  - `func materials() -> Array[Material]`, every material it made, for Task 11's warm-up.
- Produces, in `Look`: when `grade_override != &""`, `target_grade()` returns `GRADES[grade_override]`.
- Produces: `tools/road_stills.sh <out> [shot ...]` writes a temporary `override.cfg` (1920×1080), refuses if one
  exists, and removes it by trap. It runs `tools/road_stills.gd -- --out=<dir> [--before=<dir>]`, which instances
  `road.tscn` with `Journey.change_scenes = false`, uses `start_at` per shot, and writes one PNG per shot plus
  `sheet.png`.

What the road holds, in code:
- **The surface:** an asphalt ribbon with a white dashed centre line, solid white edge lines, and an open concrete
  monsoon drain on the hill side.
- **Rails and signs:** a W-beam guard rail on posts on the valley side, chevron boards on the switchbacks, and Malay
  text signs.
- **The jungle:** layered tree cards (alpha scissor, canopy textures generated in code) and a dark slope mesh on both
  sides.
- **Lights:** sodium lamps every ~60 m near the resort only, then none further down. The resort's glow sits in the
  fog uphill.
- **The tunnel** over `TUNNEL`, about 80 m, lit by emissive strips plus at most 2 omni lights.
- **The staff exit** at `EXIT`: a back-of-house door, a bin and a sodium lamp.
- **The bus stop:** a concrete bench under a metal roof, and a timetable plate.
- **Walking:** colliders that let the player walk anywhere on the road and verge but never leave it.
- **Culling:** the trees, rails and signs come in chunks of about 100 m, with `visibility_range_end` set.

- [ ] **Step 1: Write the failing tests** in `test_road_builder.gd`.

```gdscript
func test_the_road_builds_with_its_fog() -> bool:  # environment.fog_enabled; set_fog(0) → 0.035, set_fog(1) → 0.11
func test_far_scenery_is_culled() -> bool:  # every MultiMeshInstance3D and every sign has visibility_range_end > 0 and <= 160
func test_signs_say_only_checked_text() -> bool:  # every Label3D text on a sign is in RoadBuilder.SIGN_TEXTS
func test_the_player_cannot_leave_the_road() -> bool:  # player.tscn, scripted_move sideways for 6 s at 10 points (s from 0 to 2900) → stays within WIDTH / 2 + 2.5 m of the centreline
func test_the_road_has_its_own_grade() -> bool:  # road.tscn: look.grade_override == &"road" and the environment shows GRADES[&"road"]
func test_road_lights_fit_the_per_object_limit() -> bool:  # no road mesh is reached by more than rendering/limits/opengl/max_lights_per_object lights
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=road_builder`. Expected: FAIL.
- [ ] **Step 3: Implement `RoadBuilder`** and add it to `RoadMain`.
  - `RoadMain` calls `builder.set_fog(director.fog)` each frame and sets `look.grade_override = &"road"`.
  - The road grade's starting values are saturation 0.5, contrast 1.06, black `Color(0.0, 0.012, 0.02)` and white
    `Color(0.86, 0.9, 0.92)`.
  - The player now spawns at `EXIT`, facing down the road.
- [ ] **Step 4: Check the names and the sign text before you use them.** Search the web for each invented name and
  each sign text, and put the results in `docs/architecture.md` under "The road: invented names" as a table: name,
  what it is, what the search found.
  - Use resort and road names only if no real resort, road or product uses them. Candidates: "Bukit Sunyi" for the
    resort, "Jalan Puncak Lama" for the road.
  - Sign texts must match what Malaysian hill-road signs really say. Check them against photographs, or JKR's sign
    standards if you can reach them, and cite the source. Candidates: "AWAS", "SELEKOH TAJAM", "KURANGKAN LAJU",
    "GUNAKAN GEAR RENDAH", "DILARANG MEMOTONG".
  - `SIGN_TEXTS` holds only checked texts. Drop any candidate you can't confirm.
- [ ] **Step 5: Render and look.**
  - Run `bash tools/road_stills.sh /tmp/road-stills/t3 road_exit road_stop road_bend road_tunnel`.
  - Look at each still at full size. Do they look like a foggy hill road above KL at night, not anywhere-road? Tune
    fog, lamps and cards.
  - At most 4 rounds. Write in the report what each still shows.
- [ ] **Step 6: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 7: Commit** with the message `feat: the road down the mountain, in fog`.

### Task 4: The ride

The couple's car, the seated player and the car arriving at the stop. After this task the thin slice plays from end
to end: start, the walk, the car, getting in, then the flat.

**Files:**
- Create: `art/hatchback/build.py`, `scripts/road/car_rig.gd`, `scripts/road/road_game_stage.gd`,
  `scripts/road/road_audio.gd`, `tests/integration/test_ride.gd`
- Modify: `scripts/player/player_controller.gd`, `scripts/road/road_main.gd`, `tools/gen_audio.py`,
  `tests/integration/test_models.gd` (`TRIS[&"hatchback"] = 14000`), `tools/road_stills.gd`

**Interfaces:**
- Consumes: `RoadDirector` ride state and `drive`/`stop_at`/`lane_to` (Task 2), `RoadLayout.point`/`tangent`,
  `Interactable`, and `EventBus.sound_requested`.
- Produces, in `PlayerController`:
  - `func sit(seat: Node3D) -> void`: reparents the player under the seat, turns collision and movement off, and
    keeps the mouse look, with yaw relative to the seat and pitch clamped as now;
  - `func stand(at: Transform3D) -> void`: the reverse;
  - `func is_seated() -> bool`.
- Produces, in `CarRig` (`Node3D`):
  - seat markers `seat_driver`, `seat_front`, `seat_rear_left` (his) and `seat_rear_right` (the fourth's);
  - `mirror_mount: Node3D`, `door_rear_left: Interactable` (`object_id` `&"car_door"`, and `&"car_door_inside"` once
    he sits) and `headlights: Array[SpotLight3D]`;
  - `func place(s: float, across: float) -> void`;
  - `func materials() -> Array[Material]`.
- Produces, in `RoadGameStage extends RoadStage`: `func _init(p: PlayerController, car: CarRig)`. It takes the car,
  not the director, because the director is built with its stage. `relative_yaw()` measures the camera's horizontal
  forward against the car's forward when `p.is_seated()`, and against `RoadLayout.tangent(closest_s(player))` when he
  walks. `player_position()` is the player's.
- Produces, in `RoadAudio` (`Node`):
  - the road's sound pool for `EventBus.sound_requested`, built like `AudioDirector.play_at`, with asphalt footsteps
    for `&"player_step"`;
  - `func set_loop(id: StringName, on: bool, volume_db: float, pitch := 1.0) -> void`, for the engine, the insects
    and later loops.
- Produces, in `tools/gen_audio.py`: `engine_loop`, `insects_loop` (a night jungle: cicada drone and crickets),
  `car_door_open`, `car_door_close`, `lorry_pass` and asphalt `road_step_1..4`. Each sound's level goes in
  `docs/architecture.md`'s audio table, measured with `loudest_100ms_db`.

The car (`art/hatchback`): an ordinary small 5-door hatchback, about ten years old and kept clean, with no badge.
- Inside: cloth seats, a dashboard with gauges that glow, a rear-view mirror on the mount, door cards, a parking
  sticker and a small plush toy from the resort's theme park on the dash (invented, no logo).
- Its origin is the ground at the centre of the wheelbase. It faces -Y, the game's +Z, like `art/figure`.

The car's lights and moves:
- Headlights: two unshadowed spots, with additive cone meshes that show in the fog.
- Taillights and a small dash glow.
- The engine loop's pitch follows `car_speed`.
- It is placed at `car_s` and `lane` each frame. In M1 the lorry is code-built: a dark box, reflective strips and two
  lights, passing in the other lane in 3 s.

- [ ] **Step 1: Write the failing tests** in `test_ride.gd`.

```gdscript
func test_player_sits_and_stands() -> bool:  # sit(seat): the player follows the seat while the car moves 20 m; move input ignored; look still turns; stand(at): collision back, walking works
func test_relative_yaw_follows_the_car() -> bool:  # car yawed 180° on a hairpin, player looking along the car → relative_yaw ≈ 0; turned to face the rear window → ≈ ±PI
func test_the_car_stops_at_the_stop() -> bool:  # LiftMission's wait: CarRig's position within 0.3 m of RoadLayout.point(BUS_STOP_S, LANE) when couple_stops fires
func test_the_slice_plays_through() -> bool:  # road.tscn with change_scenes false: walk to the stop (scripted_move), wait, interact car_door → seated, then debug_skip() until finished(&"alive")
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=ride`. Expected: FAIL.
- [ ] **Step 3: Build the model.** Run `tools/models.sh hatchback` with `GODOT=$GODOT`. The budget test must pass at
  14000 triangles or under.
- [ ] **Step 4: Implement** `sit`/`stand`, `CarRig`, `RoadGameStage`, `RoadAudio` and the new sounds, and wire them
  in `RoadMain`. `RoadMain` replaces the plain `RoadStage` with a `RoadGameStage`.
- [ ] **Step 5: Render and look.** Run `bash tools/road_stills.sh /tmp/road-stills/t4 car_arrives back_seat`.
  - Check the car reads as a real car in headlights and fog.
  - Check the back seat reads as the back of a small Malaysian family car at night.
- [ ] **Step 6: Run** `GODOT=$GODOT tools/test.sh`, then `$GODOT --path . -- --smoke`. Expected: `0 failed`, then
  `ROAD-SMOKE ok`, then `SMOKE ok`.
- [ ] **Step 7: Commit** with the message `feat: the couple's car stops for him, and he rides in the back`.

### Task 5: The couple

Hafiz and Mei, seen from the back seat, turning when they talk.

**Files:**
- Create: `art/hafiz/build.py`, `art/mei/build.py`, `scripts/road/couple.gd`, `tests/integration/test_couple.gd`
- Modify: `scripts/road/road_main.gd`, `scripts/road/road_director.gd` (`say` emits `road_line`),
  `tests/integration/test_models.gd`, `tools/road_stills.gd`

**Interfaces:**
- Consumes: `CarRig` seats (Task 4) and `EventBus.road_line` (Task 2).
- Produces:
  - models `hafiz_seated`, `hafiz_standing`, `mei_seated` and `mei_standing`, each with a separate head node `Head`
    so it can turn (budget 9000 each);
  - `Couple` (`Node3D`): `func turn_to(speaker: StringName, seconds: float) -> void`. Mei's head and shoulders turn
    towards the back seat for her lines. Hafiz glances at the mirror for his;
  - `func materials() -> Array[Material]`.

Who they are (my calls; the quality bar is that their clothes and props show who they are):
- **Hafiz:** early twenties, driving with one hand. A plain hoodie and a cap worn backwards.
- **Mei:** early twenties. A cardigan over a dress, a lanyard from the theme park round her neck (no logo), and her
  phone in her hand, its screen lighting her face from below.

Faces are seen dimly and from the side, and must not look like mannequins: skin with colour variation, hair in
clumps rather than one shell, and eyes that catch the dash light.

- [ ] **Step 1: Write the failing tests.** In `test_couple.gd`:
  - `test_heads_turn_to_the_speaker`: a `road_line(&"mei", 3.0)` turns Mei's `Head` past 0.5 rad towards the rear
    within 0.6 s, and back within 1 s of the line ending;
  - `test_lines_name_their_speaker`: every `say` of a spoken line in the missions passes a speaker, which is
    `&"hafiz"` or `&"mei"`.
- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=couple`. Expected: FAIL.
- [ ] **Step 3: Build** with `tools/models.sh hafiz mei`, then implement `Couple`. They are seated in `CarRig` from
  `&"couple_stops"` on. The standing models are used in Tasks 9 and 10.
- [ ] **Step 4: Render and look.** Run `bash tools/road_stills.sh /tmp/road-stills/t5 couple mei_turns`. Judge them
  against the anti-goals. At most 4 rounds; report what each round changed.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: Hafiz and Mei, who talk to him on the way down`.

### Task 6: Mission 2, the slow car

**Files:**
- Create: `scripts/road/missions/slow_car_mission.gd`, `art/old_sedan/build.py`, `scripts/road/slow_car.gd`,
  `tests/unit/test_slow_car_mission.gd`
- Modify: `scripts/road/road_director.gd` (`default_missions()` appends `SlowCarMission`),
  `tests/sim/road_playthrough.gd` (the policy's M2 rows), `scripts/road/road_main.gd`, `scripts/road/car_rig.gd`
  (the overtake swings `lane` to `-LANE` and back), `tools/gen_audio.py`, `tests/integration/test_models.gd`
  (`TRIS[&"old_sedan"] = 8000`), `tools/road_stills.gd`

**Interfaces:**
- Consumes: `drive`, `lane_to`, `ask`, `say`, `break_rule` and `slow_gap` (Task 2), and `RoadAudio.set_loop` (Task 4).
- Produces: cues `&"slow_car_seen"`, `&"indicator"`, `&"overtake"`, `&"slow_car_ahead"`, `&"slow_car_gone"` and
  `&"her_glimpse"`. Task 8 shows `&"her_glimpse"`; until then nothing listens to it.
- Produces: `SlowCar` (`Node3D`) placed at `car_s + slow_gap` in the left lane, hidden when `slow_gap` is NAN, and its
  `materials()`. The model is an old, rounded small sedan, faded yellow, with no badge and one dim tail light. When
  the headlights reach the rear window, its driver's seat shows empty.

The mission runs in these beats:
1. **cruise:** 8 s at 9 m/s.
2. **seen:** `slow_gap` starts at 60 m and closes to 12 m while the car slows to 4 m/s, then `slow_car_seen` and the
   rule recall. The objective is `Keep him behind the slow car.`
3. **Three attempts,** about 40 s apart. Each opens `ask(&"overtake_<n>", options, 6.0, [0, 1], &"overtook")`, with
   options in Hafiz's escalating mood:
   - **kept:** Hafiz grumbles and follows;
   - **broken** (index 2, or silence: he overtakes): `indicator`, then `lane_to(-LANE)` and 14 m/s for 6 s, with
     `slow_gap` falling below -10, then `lane_to(LANE)`. `her_glimpse` follows. About 20 s later comes
     `slow_car_ahead`: `slow_gap` is 40 m again, round a bend, and Mei says
     `Mei: "Eh… isn't that the same car?"`.
4. **After the third attempt:** the slow car pulls into a lay-by and its lights go out (`slow_car_gone`,
   `slow_gap = NAN`). Done.

Copy these verbatim:

```
[Bang Din: "A slow car with nobody driving, you follow it. However long. Never potong."]
overtake_1: "Don't, bro. Just follow it." / "Eh… got nobody driving that car." / "Ya lah, go."
overtake_2: "Follow it lah. No rush." / "Bang Din says never potong a car like that." / "Faster, go."
overtake_3: "Bro, please. Stay behind it." / "Look properly. Nobody at the wheel." / "Okay, last time. Go."
```

Hafiz's lines before each attempt are yours to write: short, Manglish, more impatient each time. Sounds:
`indicator.wav` (the dashboard tick), `old_engine_loop` and `rev`.

`set_up_skipped()`: seated, `car_s` 0, cruising. The bots: keeper answers 0, 0, 0; wobbly answers 0, 0, 2; breaker
stays silent all three times.

- [ ] **Step 1: Write the failing tests** in `test_slow_car_mission.gd`.

```gdscript
func test_keeping_all_three_breaks_nothing() -> bool:  # answers 0, 1, 0 → score 0; cues seen … slow_car_gone; slow_gap NAN at the end
func test_silence_lets_him_overtake() -> bool:  # no answers → three &"overtook", score 3; fog >= 0.36
func test_after_an_overtake_it_is_ahead_again() -> bool:  # after a break: slow_gap < 0 during the overtake, then > 0 after slow_car_ahead
func test_her_glimpse_follows_each_overtake() -> bool:  # one &"her_glimpse" per overtake, none when kept
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=slow_car`. Expected: FAIL.
- [ ] **Step 3: Implement** the mission, the model (`tools/models.sh old_sedan`), `SlowCar`, the overtake in
  `CarRig`, the sounds and the bot rows (Task 10's table).
- [ ] **Step 4: Render** `slow_car` and `overtake` stills and look at them.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: the slow car with nobody at the wheel`.

### Task 7: Mission 3, the extra passenger

**Files:**
- Create: `scripts/road/missions/count_mission.gd`, `scripts/road/mirror.gd`, `art/fourth/build.py`,
  `tests/unit/test_count_mission.gd`, `tests/integration/test_mirror.gd`
- Modify: `road_director.gd` (append `CountMission`), `road_playthrough.gd`, `road_main.gd`, `car_rig.gd`,
  `test_models.gd` (`TRIS[&"fourth"] = 8000`), `tools/road_stills.gd`, `docs/architecture.md` (collision and render
  layers: layer 11 is mirror only)

**Interfaces:**
- Consumes: `watch_look`/`stop_look`/`ask` (Task 2), `CarRig.mirror_mount` and `seat_rear_right` (Task 4).
- Produces: cues `&"mirror_on"`, `&"mirror_off"`, `&"fourth_glimpse"` (when `turned_round` breaks), `&"brake"` and
  `&"fourth_gone"`.
- Produces, in `Mirror` (`Node3D` on `mirror_mount`):
  - a `SubViewport` of 320×112 with its own `Camera3D` (fov 30), looking back at the rear seats, shown on the mirror
    glass;
  - its camera's cull mask includes layer 11, and the player's camera mask excludes it;
  - `render_target_update_mode` is `UPDATE_ALWAYS` only between `mirror_on` and `mirror_off`, and
    `UPDATE_DISABLED` otherwise;
  - `func materials() -> Array[Material]`.
- Produces: the model `fourth`, a woman seated in the rear right seat, head down, long wet hair over her face, in a
  plain soaked baju kurung. It is on layer 11 only, except for 0.3 s on `fourth_glimpse`, when the main camera sees
  her too, with no sound sting. She is the penanggal by day, so keep her face and hair consistent with Task 8.

The mission runs in these beats:
1. **quiet:** `mirror_on` and `watch_look(&"turned_round", 2.2, 1.0, 0.4, 1, 1)`. Mei and Hafiz talk about "your
   friend", which is how the player works out who is there without looking. Then the rule recall. The objective is
   `Don't turn round. Don't count her.`
2. **asked:** `ask(&"count", ["\"Three.\"", "\"Four.\"", "\"Why you ask?\""], 6.0, [0, 2, -1], &"counted_her")`.
3. **asked_again** (only after "Why you ask?"): `ask(&"count_again", ["\"Three.\"", "\"Four.\""], 5.0, [0, -1], &"counted_her")`.
4. **empty:** `Mei: "Three? Then who's sitting—"`, then `brake` and `fourth_gone`. The mirror shows the seat empty,
   with a wet patch. Then `mirror_off` and `stop_look`. Done.

Copy these verbatim:

```
[Bang Din: "If they say there's one more in the car, don't turn to look. And don't count her."]
Mei: "Eh, how many of us ah? I want to buy drinks at the R&R."
Hafiz: "Four people in this small car, also nobody talk."
```

`set_up_skipped()`: seated, `car_s` 900, cruising, no slow car. The bots: keeper never turns and answers 0; wobbly
never turns and answers 2, then 0; breaker turns towards her once and answers 1.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_count_mission.gd
func test_keeping_breaks_nothing() -> bool:  # yaw 0 throughout, answer 0 → score 0, cues mirror_on … fourth_gone, mirror_off
func test_turning_to_her_breaks_once() -> bool:  # yaw -1.3 held 10 s → one &"turned_round", one &"fourth_glimpse"
func test_looking_out_of_his_own_window_is_allowed() -> bool:  # yaw +1.6 held 10 s → no break
func test_why_asks_again_and_silence_keeps() -> bool:  # answer 2, then silence → asked_again happened, score 0
func test_four_counts_her() -> bool:  # answer 1 → one &"counted_her"

# test_mirror.gd
func test_only_the_mirror_sees_her() -> bool:  # fourth on layer 11 only; player camera mask excludes 11; mirror camera includes it
func test_the_mirror_renders_only_in_mission_3() -> bool:  # UPDATE_DISABLED before mirror_on and after mirror_off
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=count`. Expected: FAIL.
- [ ] **Step 3: Implement** the mission, `Mirror`, the model (`tools/models.sh fourth`) and the bot rows.
- [ ] **Step 4: Render** the `mirror_fourth` still from his seat looking at the mirror, and look at it. She should be
  readable in the mirror at 1:1, and not obvious.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: the passenger only the mirror shows`.

### Task 8: The penanggal

Her model, the gore, how she moves and sounds, and every place she appears. Mission 2's glimpses go live here.

**Files:**
- Create: `art/penanggal/build.py`, `scripts/road/her.gd` (`class_name Penanggal`), `tests/integration/test_her.gd`
- Modify: `road_main.gd`, `tools/gen_audio.py`, `test_models.gd` (`TRIS[&"penanggal"] = 14000`),
  `tools/road_stills.gd`

**Interfaces:**
- Consumes: `road_cue` (`her_glimpse` from Task 6), `RoadDirector.her_near`, `CarRig`, and `RoadLayout.point`.
- Produces, in `Penanggal` (`Node3D`):
  - `func show_glimpse() -> void`;
  - `func on_roof(car: CarRig) -> void` (Task 9);
  - `func behind(walker: Node3D, distance: float) -> void` (Task 10);
  - `func catch(victim: Node3D) -> void` and `func come_for(camera: Camera3D) -> void` (Task 10);
  - `func hide_her() -> void`;
  - `func materials() -> Array[Material]`;
  - `func warm_up(at: Vector3) -> void`, which shows every material and the sway shader for one frame.
- Produces: the sounds `wet_flap`, `drip` and `rattle`.

The model (`art/penanggal`): a woman's head, gaunt, with grey-pale skin and wide dark eyes, the mouth a little open,
and long black wet hair in clumps. Beneath it hang the windpipe and gullet, two dark spongy lungs, the heart, the
stomach, and ropes of intestine 1.2–1.6 m long, with strands of blood that drip.
- Colours are muted: dark crimson, bruise purple and grey-pink, never bright red. Low roughness gives a wet sheen in
  the headlights.
- The origin is the centre of the skull.
- A spatial vertex shader sways the entrails and hair. The displacement grows with the square of the distance below
  the head, and a `motion` uniform makes them trail behind when she moves.
- Her first glimpse adds the caption `[A sour smell, like vinegar.]`, from the folklore of her soaking her entrails in
  vinegar. Nothing else about her is explained.

Where she appears:
- **`show_glimpse`:** 25–35 m ahead and off the road edge, crossing the edge of the headlights for 1.2 s, half in fog.
- **`behind`:** on the road behind the walker, at a distance of `lerp(18, 4, her_near)`.
- **`catch`:** she drops onto the victim's shoulders. The victim falls over 0.6 s, and a dark pool mesh spreads.
- **`come_for`:** she moves at the camera at 6 m/s until 0.6 m away.

Anti-goals, on every still:
- she must not look fake, silly or cartoony;
- she is lit only by the scene: the headlights, a phone light, the fog;
- no loud sting when she appears. Her sounds are wet and quiet, and dread comes from distance and timing.

- [ ] **Step 1: Write the failing tests** in `test_her.gd`.

```gdscript
func test_behind_keeps_her_distance() -> bool:  # her_near 0 → 18 m behind the walker along the road; 1 → 4 m
func test_glimpse_is_brief_and_off_the_road() -> bool:  # visible ≤ 1.3 s; |across| > WIDTH / 2 at that s
func test_catch_ends_on_the_ground() -> bool:  # after catch(victim) and 2 s: victim's up axis within 15° of horizontal; pool visible
func test_her_warm_up_shows_every_material() -> bool:  # warm_up(): every material in materials() on a visible mesh that frame
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=her`. Expected: FAIL.
- [ ] **Step 3: Build** with `tools/models.sh penanggal`, then implement `Penanggal`, the sounds, and the wiring of
  `her_glimpse` in `RoadMain`.
- [ ] **Step 4: Render and judge.** Run `bash tools/road_stills.sh /tmp/road-stills/t8 her_glimpse her_full her_close`
  and look at each at full size against the anti-goals. At most 4 rounds; the report says what changed each round
  and what still looks wrong. `her_full` is for checking only and is never published.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: the penanggal`.

### Task 9: Mission 4, the car dies

**Files:**
- Create: `scripts/road/missions/stall_mission.gd`, `tests/unit/test_stall_mission.gd`, `tests/integration/test_stall.gd`
- Modify: `road_director.gd` (append `StallMission`), `road_playthrough.gd`, `road_main.gd`, `car_rig.gd`, `couple.gd`
  (Hafiz gets out and walks off), `tools/gen_audio.py`, `tools/road_stills.gd`

**Interfaces:**
- Consumes: `stop_at`, `ask`, `break_rule` and `light_s` (Task 2); `CarRig.door_rear_left` (Task 4);
  `Penanggal.on_roof` (Task 8); `hafiz_standing` (Task 5); and `Settings.get_value("reduced_flashing")`.
- Produces: cues `&"lights_dying"`, `&"crank"`, `&"hafiz_leaves"`, `&"door_cracked"`, `&"insects_stop"`, `&"thump"`,
  `&"her_on_roof"`, `&"knock_window"` and `&"light_on"`.
- Produces: `RoadDirector.light_s = car_s + 150` when the car stops. The light, and the stall Task 10 builds there,
  sit 150 m on.
- Produces: the sounds `engine_sputter`, `starter_crank`, `thump_roof` and `knock_glass`.

The mission runs in these beats:
1. **dying:** `lights_dying`, and the speed eases to 0 over 4 s.
2. **cranking:** two `crank`s.
3. **hafiz_leaves:** his lines, then the rule recall. The objective is `Stay in the car. Don't open the door. Don't answer.`
   Hafiz gets out, and his door opens and closes. He walks ahead into the fog with his phone torch, which is an
   unshadowed spot. From here, `set_prompt(&"car_door_inside", "Open the door")`. Using it breaks `&"opened_door"`
   (weight 2) once: the door opens a hand's width and something wet slaps it shut (`door_cracked`), and the prompt
   goes.
4. **waiting:** 20 s, then `insects_stop`.
5. **thumps:** three `thump`s on the roof over 15 s (camera shake under 0.02 m), with `her_on_roof` at the first.
   Strands hang past the side windows.
6. **voice:** `[Outside, in Hafiz's voice: "Bro! Open the door, I found help!"]`, then
   `ask(&"answer_voice", ["\"Hafiz? That you?\"", "Stay quiet."], 6.0, [1, -1], &"answered")`.
7. **mei:** `Mei: "That's him! I'm opening—"`, then
   `ask(&"stop_mei", ["\"Mei, don't. That's not him.\"", "\"Okay, open.\""], 4.0, [0], &"mei_opened")`. Silence
   means she opens it: the cost is the broken rule, and the door slaps shut as above.
8. **knocks:** three knocks on Mei's window (`knock_window`).
9. **quiet:** 10 s, then `light_on` far down the road. Done.

Copy this rule recall verbatim:

```
[Bang Din: "If the car dies, stay inside. Don't open the door. Don't answer, even if it sounds like your own mother."]
```

`set_up_skipped()`: seated, `car_s` 1800, cruising. The bots: keeper and wobbly never open the door and answer 1,
then 0; breaker opens the door once and stays silent for both choices.

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_stall_mission.gd
func test_keeping_breaks_nothing() -> bool:  # never use the door, answers 1 then 0 → score 0; cues in the order above
func test_the_door_prompt_comes_only_after_hafiz_leaves() -> bool:  # no car_door_inside prompt before hafiz_leaves
func test_opening_the_door_costs_two_once() -> bool:  # use it twice → one &"opened_door" (weight 2); the prompt is gone after the first
func test_silence_lets_mei_open() -> bool:  # stop_mei unanswered → &"mei_opened"
func test_the_light_is_150_m_on() -> bool:  # light_s == car_s at the stop + 150

# test_stall.gd
func test_dying_lights_respect_reduced_flashing() -> bool:  # reduced_flashing on: during lights_dying, headlight energy changes by at most 5 % per frame and only falls; off: it may flicker
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=stall`. Expected: FAIL.
- [ ] **Step 3: Implement** the mission, the `CarRig` light failure (dimming when reduced flashing is on), Hafiz's
  exit, the roof, the sounds and the bot rows. The same reduced-flashing rule applies to the tunnel lights and the
  lorry.
- [ ] **Step 4: Render** the `her_roof` still from his seat (strands at the window) and look at it.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `feat: the car dies, and something is on the roof`.

### Task 10: Mission 5 and the road's endings

**Files:**
- Create: `scripts/road/missions/light_mission.gd`, `art/fruit_stall/build.py`, `scripts/road/endings.gd`,
  `tests/unit/test_light_mission.gd`
- Modify: `road_director.gd` (append `LightMission`), `road_playthrough.gd`, `tests/integration/test_road_playthroughs.gd`,
  `tools/playthroughs.gd` (a "The road" section), `docs/playthroughs.md` (regenerated), `road_main.gd`, `couple.gd`
  (Mei walks beside him), `test_models.gd` (`TRIS[&"fruit_stall"] = 4000`), `tools/gen_audio.py`,
  `tools/road_stills.gd`

**Interfaces:**
- Consumes: `watch_look`, `ask`, `light_s`, `outcome()` and `end()` (Task 2); `PlayerController.stand` (Task 4);
  `Penanggal.behind`/`catch`/`come_for` (Task 8); `mei_standing` and `hafiz_standing` (Task 5); the lorry (Task 4).
- Produces: cues `&"get_out"`, `&"her_behind"`, `&"mei_looks"`, `&"light_out"`, `&"her_catches_hafiz"`, `&"her_comes"`,
  `&"lorry_stops"`, `&"phone_rings"` and `&"hafiz_at_stall"`.
- Produces: `Endings` (`Node`), which plays the presentation of each road ending from the cues, and
  `func materials() -> Array[Material]` (the stall and the lorry) for Task 11.
- `set_up_skipped()`: standing beside the car, `car_s` 2000, `light_s` 2150.
- Produces: the model `fruit_stall`, a closed roadside fruit stall at `light_s`: a timber frame, a blue tarp, a table
  with a few durians and one bare bulb. Plus the sound `phone_ring_mobile`.

The mission runs in these beats:
1. **get_out:** `set_prompt(&"car_door_inside", "Get out")`. Using it emits `get_out` and stands him beside the car.
   This is not a break.
2. **walk:**
   - the rule recall, and the objective `Walk to the light. Don't look back.`;
   - `watch_look(&"looked_back", 1.9, 1.9, 0.25, 3, 2)` and `her_behind`;
   - Mei walks 1 m to his left, matching his s;
   - at 30 % and 65 % of the way, `ask(&"mei_look_<n>", ["\"Don't look. Hold my hand.\"", "\"Maybe it's him.\""], 5.0, [0], &"mei_looked")`.
     A break plays `mei_looks`: her head turns back;
   - behind them, with no speaker turn: `[Behind you, Hafiz's voice: "Mei! Wait for me!"]`, wet flaps and drips.

   At `light_s - 30` the ending is decided once: `outcome()` is read and kept, and `stop_look()` ends the look rule.
   If it is `&"caught"`, the walk is done there. Otherwise it is done within 4 m of `light_s`.
3. **ending:** one of the three below, then `end()`.
   - **alive:** `hafiz_at_stall`: Hafiz waits under the bulb, and a lorry idles. Hafiz:
     `"Eh! Found this uncle, he's going down. Jom."` Then the card and
     `[The lorry takes the three of you down the mountain.]`.
   - **saved:** nobody is at the stall. `phone_rings`: Hafiz's phone rings on the table, and Mei says
     `"That's his phone…"`. Then `lorry_stops`, the card, and `[The lorry takes the two of you down the mountain.]`.
   - **caught:**
     1. `light_out`: the bulb dies;
     2. Hafiz walks out of the fog ahead, `"Mei? Bro?"`;
     3. `her_catches_hafiz`, gore and all;
     4. `[Mei screams.]`;
     5. `her_comes` towards the two of them;
     6. the card the moment she reaches the camera, with no caption.

Copy this rule recall verbatim:

```
[Bang Din: "When it goes quiet, walk to the light. Whatever is behind you, don't look back."]
```

The bots' policy, pinned. The resulting scores are keeper 0 (alive), wobbly 4 (saved) and breaker 16 (caught).

| Choice or rule | keeper | wobbly | breaker |
|---|---|---|---|
| overtake_1, overtake_2, overtake_3 | 0, 0, 0 | 0, 0, 2 | silence ×3 |
| turned_round | never | never | once |
| count / count_again | 0 | 2, then 0 | 1 |
| car_door_inside "Open the door" | never | never | once |
| answer_voice | 1 | 1 | silence |
| stop_mei | 0 | 0 | silence |
| looked_back | never | once | twice |
| mei_look_1, mei_look_2 | 0, 0 | 0, 0 | silence ×2 |

- [ ] **Step 1: Write the failing tests.**

```gdscript
# test_light_mission.gd
func test_looking_back_costs_three_twice_at_most() -> bool:  # three looks with a return to centre between → 6
func test_silence_lets_mei_look() -> bool:  # both unanswered → two &"mei_looked"
func test_reaching_the_light_ends_the_road() -> bool:  # score 0: done at light_s - 4, ending &"alive", road_ended emitted once
func test_caught_ends_before_the_light() -> bool:  # score 7 before the walk: light_out at light_s - 30, her_catches_hafiz then her_comes, ending &"caught"

# test_road_playthroughs.gd (add)
func test_each_bot_meets_its_ending() -> bool:  # for every seed: keeper → &"alive" (score 0), wobbly → &"saved" (4), breaker → &"caught" (16)
func test_the_keeper_takes_seven_to_fifteen_minutes() -> bool:  # 420 <= keeper time <= 900 sim s. The spec guessed 10–15 min for people; the bot answers in 1 s and walks straight, so it is a lower bound (about 8 min by the beats above). Reported as a bot.
```

- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=light`. Expected: FAIL.
- [ ] **Step 3: Implement** the mission, `Endings`, the stall model (`tools/models.sh fruit_stall`), the sounds and the
  bot rows.
- [ ] **Step 4: Regenerate the bots' record.** Run `$GODOT --headless --path . --script res://tools/playthroughs.gd`.
  The new section says plainly that these are bots, as the existing header does.
- [ ] **Step 5: Render** `walk_light`, `stall`, `ending_caught` and `ending_alive`, and look at them.
- [ ] **Step 6: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 7: Commit** with the message `feat: don't look back, and the road's three endings`.

### Task 11: Warm-up, performance and the web

**Files:**
- Create: `scripts/road/road_perf.gd`, `tests/integration/test_road_warm_up.gd`
- Modify: `road_main.gd` (`_compile_shaders`, and the perf route replacing Task 1's skip), `tools/web_smoke.mjs`
  (perf waits for both the road's and the flat's report), `docs/performance.md`

**Interfaces:**
- Consumes: every `materials()` (Tasks 3–10), `Penanggal.warm_up`, `Mirror`, and `PerfProbe`'s report format.
- Produces, in `RoadMain`: `func warmed_materials() -> Dictionary`, the set of materials drawn during the warm-up.

**The warm-up** runs behind the start card. Every material from every `materials()` is drawn under each light state:
- none;
- headlights;
- the phone light;
- headlights and phone.

The mirror viewport renders once with the fourth in it. The tunnel lights are on for one pass. It follows the
flat's rule: a material first drawn mid-game hitches.

**The perf route** runs with `--perf` / `?perf`, about 45 s, then prints `PERF road …` lines in `PerfProbe`'s format.
It then hands over to the flat, whose own tour and report run as today. Each stage uses `start_at` and `debug_skip`:
1. the drive at cruise with the fog going from 0 to 1, a glimpse every 4 s, and the tunnel;
2. the mirror on for 10 s;
3. her on the roof for 8 s;
4. the walk with her behind;
5. the catch.

- [ ] **Step 1: Write the failing test.**
  - `test_every_road_material_is_warmed`: after `loaded`, every material reachable under the road scene, including
    hidden nodes and the mirror's world, is in `warmed_materials()`.
- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=road_warm_up`. Expected: FAIL.
- [ ] **Step 3: Implement** the warm-up and the route.
- [ ] **Step 4: Measure** on the desktop and on the web, and record only what was measured.
  - **Desktop:** `$GODOT --path . -- --perf`.
  - **Web:** export the `Web` preset to `/tmp/condo-road-web/index.html` with
    `$GODOT --headless --path . --export-release Web /tmp/condo-road-web/index.html`. That is never `tools/export.sh`
    and never `builds/`. Then:
    - `PLAYWRIGHT_FROM=/Users/chrischeng/work/the-house-web-port/ node tools/web_smoke.mjs /tmp/condo-road-web --perf --headless --webkit`;
    - the same run with `--chromium`;
    - the plain smoke in both browsers.
  - **Record** in `docs/performance.md` under "The road":
    - the road's frame times (avg, p95, max, frames over 25 ms), each with its date, machine and browser;
    - the pck size against the 8912 KiB cap.

  The bar is the flat's: no frame over 25 ms in WebKit after the start card.
  - If the road misses it, the report gives the numbers and what costs the most (fog cards, cone overdraw, the
    mirror), and the fix goes in this task.
  - If it can't be fixed without cutting something the spec asks for, stop and report.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh`. Expected: `0 failed`.
- [ ] **Step 6: Commit** with the message `perf: warm the road's shaders and measure it on the web`.

### Task 12: Docs, the start card, the itch text and the stills

**Files:**
- Create: `docs/research/2026-11-xx-gore-rules.md` (the date is the day it is written)
- Modify: `scripts/ui/hud.gd` (the start card's body text), `docs/architecture.md`, `docs/event-catalog.md`,
  `docs/test-plan.md`, `docs/roadmap.md`, `docs/itch-page.md`, `tests/integration/test_hud.gd`

**Interfaces:**
- Consumes: everything above.

What changes:
- **The start card's body,** verbatim:

```
Headphones recommended. Contains blood and gore, flickering lights, sudden sounds and themes of isolation.
Reduced flashing and brightness: press Esc now or at any time.
```

- **`docs/architecture.md`:** a section "The road" covering:
  - the scene order and `Journey`;
  - the core and its tick order;
  - a missions table (beats, rules, weights, choices and their keeps);
  - the outcome thresholds;
  - the new `EventBus` signals and every cue;
  - the presentation nodes, layer 11, and the road sounds in the audio levels table.
- **`docs/event-catalog.md`:** the road's cues, and what each mission does when a rule breaks.
- **`docs/test-plan.md`** and **`docs/roadmap.md`:** the road comes first in the story outline.
- **`docs/itch-page.md`:**
  - **The content warning** becomes: "Content warning: blood and gore, a figure that appears suddenly, sudden loud
    sounds and flickering lights." The line "No blood or gore" goes.
  - **The description** teases the road: the last bus gone, a lift down with strangers, the rules. Never his death,
    any ending's name, or the penanggal in full.
  - **The age and content classification** rows come from itch.io's current settings for blood and gore.
  - **Credits and AI-use answers** are updated only if something changed. If any CC0 asset was used, it is named and
    the line "no third-party asset files are used" changes.
- **The gore rules note** (`docs/research/2026-11-xx-gore-rules.md`): what GitHub's Acceptable Use Policies and
  itch.io's content rules say about realistic gore in a public repository and on a game page, against what this game
  shows (the models are in the public repo). Cite and date each source. If either rule forbids something the game
  does, stop and report it; it is the owner's call.

- [ ] **Step 1: Write the failing test** in `test_hud.gd`. `test_start_card_warns_of_gore` checks that the start card
  body contains "blood and gore", on both `road.tscn` and `main.tscn`.
- [ ] **Step 2: Run** `GODOT=$GODOT tools/test.sh --filter=hud`. Expected: FAIL.
- [ ] **Step 3: Write** the changes above.
- [ ] **Step 4: Render the full set.** Run `bash tools/road_stills.sh /tmp/road-stills/final` (every shot). Look at
  each at full size against the four anti-goals: a fake-looking ghost, cheap jump scares, not Malaysian enough, and
  boring missions. Then add to the report:
  - one line per still;
  - the stills that could go on the itch page later, which excludes `her_full`, `her_close` and `ending_caught`.

  Re-shooting the trailer and the itch images is separate work, after this plan.
- [ ] **Step 5: Run** `GODOT=$GODOT tools/test.sh` and `$GODOT --path . -- --smoke`. Expected: `0 failed`, then
  `ROAD-SMOKE ok`, then `SMOKE ok`.
- [ ] **Step 6: Commit** with the message `docs: the road, its content warning and its stills`.

---

## Self-review

**Spec coverage:**

| Spec item | Where |
|---|---|
| The lift down; Bang Din's rules learned in his thoughts, with no stall scene | Tasks 2 and 4 |
| The penanggal, gory | Task 8 |
| The five missions in order | Tasks 2, 6, 7, 9 and 10 |
| The road's three endings, with one weighted count and looking back counting most | Tasks 2 and 10 (weight 3) |
| All caught: she catches Hafiz, comes for them, black at his moment | Task 10 |
| He wakes at 11:47 the same after every ending | Task 1 |
| Breaking a rule costs something the player can feel | Task 2 `break_rule` (fog, her_near), Tasks 6–10 (the car ahead again, glimpses, her distance) |
| The browser and the PC download | Tasks 1 and 11 |
| No voice acting, no real names, the Malaysian details | Global Constraints; Tasks 3–7 |
| The warm-up | Task 11 |
| Gore: content warning, classification, AUP | Task 12 |
| Tease-only | Global Constraints; Task 12 |
| Keep what is built; main unchanged | Task 1 (every existing test unchanged); Global Constraints |

- The "Done when" stills and the web measurements are Tasks 8, 10, 11 and 12.
- The flats are part 2, as the plan's Scope says.

**Types:** names cross-checked across the tasks:
- `RoadDirector`, `RoadMission.go`, `ask(..., keeps, rule, weight)` and `watch_look(rule, left, right, hold, weight, max_count)`;
- `Journey.arrive`/`restart`/`change_scenes`;
- `CarRig` seats and `door_rear_left` (`&"car_door"`, then `&"car_door_inside"`);
- the `Penanggal` methods;
- every `materials()`;
- the cue names, each produced in exactly one task's Interfaces.

**Review Focus:** each of the five lines has a named test in its owning task.
