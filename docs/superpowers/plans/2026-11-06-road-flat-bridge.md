# The bridge from the road to the flat — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After the road, the flat opens lost and quiet, the road echoes through its knocks and lines, the intercom and
the ending cards point back to what happened on the mountain; opened directly, the flat is as today.

**Architecture:** `StoryDirector` reads `Journey.road_ending` once (`road`) and does everything that depends on it: the
quiet opening, the always-shown lines, the knock sounds it asks for, the last call, and a static `ending_card()` the
HUD reads. `ApartmentBuilder` draws the red-earth footprints and their inspectable only after the road. Three new
sounds come from `tools/gen_audio.py`, like every other sound.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer, the project's own test runner
(`tests/run_tests.gd`), Python 3 for `tools/gen_audio.py`.

**Spec:** `docs/superpowers/specs/2026-11-06-road-flat-bridge-design.md` (owner-approved 2026-11-06). Read it first.

## Global Constraints

* Godot: `GODOT=/Users/chrischeng/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot` (never /Applications/Godot.app).
  Tests: `GODOT=$GODOT tools/test.sh --filter=<part of the file path>`. Import: `$GODOT --headless --path . --import`.
* `Journey.road_ending == &""` (tests, `--flat`, smoke) gives today's flat exactly: same beats, objectives, events,
  sounds, lines and ending texts. The one exception is the bedroom window's text, which changes everywhere (spec).
* The new lines are story, not sound captions: they always show (`EventBus.line_requested`), whatever "Captions for
  sounds" says. They go through `StoryDirector.say()`'s queue, so none cuts another short.
* Spoken lines are bare quoted lines with no speaker name. Exact copy, verbatim from the spec:
  * `[Your phone says 12:41 AM. The clock on the wall says 11:47.]`
  * `[Your uniform is still damp from the fog.]`
  * `How did you get home?` (objective), then `Wash up, then get some sleep.` (or `Get some sleep.` once washed)
  * Footprints: title `Footprints`, text `Red earth, from the mountain road. You don't remember walking in.`
  * `[A sour smell, like vinegar.]` (the road's `Penanggal.SMELL`)
  * `[On the road you weren't allowed to look back. Here, you can't look away.]`
  * Last call: `"Eh, you going down ah? Jom, we got space."` (caught), `"Wah, so late still working ah? Kesian, bro."` (saved)
  * Window: `Twelve floors down, the mamak where you used to work is still open. Someone in your apron is pulling teh tarik. They stop, and look up.`
  * The six ending texts are in Task 4.
* Nothing new is drawn with Decal (it doesn't draw in Compatibility). No model files, no paid or external assets; new
  sounds only from `tools/gen_audio.py`.
* Never run `tools/export.sh`; never leave `override.cfg`; never use bare `git stash`; never push. Commits end with
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
* Known test noise: the runner's exit prints about 11 ObjectDB and 5 resource leak lines;
  `test_director_runs_in_game_within_budget` can fail under heavy machine load. Neither is a failure of this work.
* Implementers run their filtered tests; the full suite and the smoke run once, in Task 5.

## Review Focus

1. He lies down in the first seconds: the intercom must not ring until the quiet is over (Task 1 test).
2. He washes while the objective is still the question: at the end of the quiet it reads `Get some sleep.`, not
   `Wash up…` (Task 1 test).
3. The footprints' inspect box covers the notes under the door or the shoes: the clue can't be picked up (Task 2 test).
4. "Captions for sounds" off: the opening lines, the smell and the look-back line still show (Tasks 1 and 3 assert
   they arrive on `line_requested`, never on `subtitle_requested`).
5. He inspects the intercom again and again: the last call's lines and sound play once, not every time (Task 4 test).

---

### Task 1: The story knows the road, and the flat opens quiet

**Files:**
- Modify: `scripts/story/story_director.gd`
- Test: `tests/unit/test_story.gd`

**Interfaces:**
- Produces: `var road: StringName` (set in `_init` from `Journey.road_ending`; tests overwrite it right after setup,
  before the first step); `const QUIET := 20.0`; `func quiet() -> bool` (true while `road != &""` and less than
  `QUIET` s have passed since the story's first tick); `func say(text: String, seconds := 3.5, always := false) -> void`
  (`always` lines are emitted on `EventBus.line_requested`, the rest on `subtitle_requested` as today);
  `func _end_question() -> void` (replaces the question with the home objective, only while the beat is `home` and the
  question is still showing); a one-shot store that survives beat changes (unlike `_fired`), used by Tasks 3 and 4.

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_story.gd`. Capture lines with lambdas on
  `EventBus.line_requested` / `subtitle_requested` that append to local arrays; disconnect before `_done()`.

```gdscript
func test_from_the_road_the_flat_opens_quiet_and_asking() -> bool:
	var story := _setup(ApartmentLayout.SPAWN)
	story.road = &"caught"
	# step 1 s:
	eq(WorldState.objective, "How did you get home?", "the first objective is a question")
	# step to 12 s, collecting lines:
	eq(lines, ["[Your phone says 12:41 AM. The clock on the wall says 11:47.]", "[Your uniform is still damp from the fog.]"], "found, not told, in order")
	check(not subtitles.has(lines[0]) and not subtitles.has(lines[1]), "story lines, not sound captions: always shown")
	# step to 19.9 s:
	check(WorldState.event_history.is_empty(), "nothing happens in the quiet")
	# step to 20.1 s:
	eq(WorldState.objective, "Wash up, then get some sleep.", "then the usual objective, without the mamak")

func test_lying_down_early_holds_the_ring_until_the_quiet_ends() -> bool:
	# road &"saved"; at 5 s: EventBus.object_interacted.emit(&"bed")
	check(not _until(func() -> bool: return story.beat == &"ringing", 14.8), "no ring before 20 s")
	check(_until(func() -> bool: return story.beat == &"ringing", 5.0), "it rings once the quiet is over")

func test_washing_during_the_question_leaves_get_some_sleep() -> bool:
	# road &"alive"; at 5 s: EventBus.object_interacted.emit(&"sink")
	eq(WorldState.objective, "How did you get home?", "washing doesn't answer the question")  # at 6 s
	eq(WorldState.objective, "Get some sleep.", "at the end of the quiet")  # at 20.1 s

func test_opened_directly_the_flat_opens_as_today() -> bool:
	# road &""
	eq(WorldState.objective, "You're home from your shift at the mamak. Wash up, then get some sleep.", "today's objective")
	# lie down at 1 s:
	check(_until(func() -> bool: return story.beat == &"ringing", 4.2), "the intercom rings 4 s after lying down, as today")
	eq(lines, [], "no new lines")
```


- [ ] **Step 2: Run them to see them fail.** `GODOT=$GODOT tools/test.sh --filter=test_story` → the four new tests
  FAIL (no `road` member).

- [ ] **Step 3: Implement in `scripts/story/story_director.gd`.** The two opening lines as one const table of
  `[seconds after the first tick, text, duration]`: `[3.0, phone line, 4.5]`, `[10.0, damp line, 3.5]`, said with
  `always`, each once, whatever the beat. The first tick sets the question when `road != &""`, today's objective
  otherwise. At `QUIET` s, or on `_end_question()`, the objective becomes `Get some sleep.` if washed, else
  `Wash up, then get some sleep.`. The sink keeps its line and flag but leaves the objective alone while the
  question shows. `in_bed` rings at `t >= 4.0 and not quiet()`. Lying down clears the objective as today, which also
  ends the question.

- [ ] **Step 4: Run them to see them pass.** Same command → all `test_story` tests pass, the old ones included.

- [ ] **Step 5: Commit** `git add scripts/story/story_director.gd tests/unit/test_story.gd` and
  `git commit -m "feat(story): after the road the flat opens quiet, with a question"`.

### Task 2: The red earth by the door, and the window's text

**Files:**
- Modify: `scripts/world/apartment_builder.gd` (a new `_build_footprints()`; the `bedroom_window` text in `OBJECTS`)
- Modify: `scripts/story/story_director.gd` (`&"footprints"` in `_on_interacted`)
- Test: `tests/integration/test_apartment.gd`, `tests/unit/test_story.gd`

**Interfaces:**
- Consumes: `StoryDirector._end_question()` (Task 1).
- Produces: `static func footprint_trail() -> Array[Vector3]` in `ApartmentBuilder` (each print's centre, the door's
  first; `_build_footprints()` and the test both use it); a `MeshInstance3D` named `Footprints` and an `Interactable`
  with `object_id = &"footprints"`, both children of the `ApartmentBuilder`, built only when
  `Journey.road_ending != &""`.

- [ ] **Step 1: Write the failing tests.** In `tests/integration/test_apartment.gd` (build the apartment the way the
  file's other tests do; save and restore `Journey.road_ending`):

```gdscript
func test_footprints_only_come_down_from_the_road() -> bool:
	# Journey.road_ending = &"": no node "Footprints", no Interactable with object_id &"footprints"
	# Journey.road_ending = &"caught":
	check(prints != null, "red earth after the road")
	eq(it.prompt, "Look at the footprints", "prompt")
	eq(it.title, "Footprints", "title")
	eq(it.text, "Red earth, from the mountain road. You don't remember walking in.", "text")
	var trail := ApartmentBuilder.footprint_trail()
	check(trail.size() >= 10, "a trail, not a smudge")
	check(trail[0].distance_to(Vector3(1.5, trail[0].y, 10.0)) <= 0.6 and trail[0].z < 10.0, "from just inside the front door")
	check(trail[-1].distance_to(Vector3(ApartmentLayout.SPAWN.x, trail[-1].y, ApartmentLayout.SPAWN.z)) <= 0.8, "to where he stands")
	check(trail.all(func(p: Vector3) -> bool: return p.y >= 0.004 and p.y <= 0.012), "on the floor")
	# the inspect box, grown by 0.05 m, overlaps no box in ApartmentBuilder.OBJECTS, and is at most 0.02 m tall
```

  In `tests/unit/test_story.gd`:

```gdscript
func test_inspecting_the_footprints_ends_the_question() -> bool:
	# road &"caught"; at 5 s: EventBus.object_interacted.emit(&"footprints")
	eq(WorldState.objective, "Wash up, then get some sleep.", "the question gives way")
	# lie down at 6 s:
	check(not _until(func() -> bool: return story.beat == &"ringing", 13.8), "the quiet still holds the ring")
```

- [ ] **Step 2: Run them to see them fail.** `--filter=test_apartment` and `--filter=test_story` → the new tests FAIL.

- [ ] **Step 3: Implement.** Footprints: one mesh (one draw), at least 10 shoe prints, left and right in turn, a
  0.55–0.75 m stride, from just inside the front door through the entrance's opening into the living room (3, 8.5)
  to his heels at `SPAWN`. Flat polygons a few mm above the floor (the `Decor._poly` pattern works), an opaque
  red-earth material that the phone light and ceiling lights light (start near `Color(0.42, 0.17, 0.09)`, rough, not
  shiny). The inspect box covers the living-room stretch of the trail, clear of every other object (the notes
  under the door are at (1.5, 9.55)). Story: `&"footprints"` calls `_end_question()`. Window: replace
  `where you work` with `where you used to work` in the `bedroom_window` entry.

- [ ] **Step 4: Run them to see them pass.** Both filters pass.

- [ ] **Step 5: Commit** the three files plus tests, `feat(flat): red earth from the door after the road`.

### Task 3: The road follows him in (roof knocks, her smell, the look-back line)

**Files:**
- Modify: `tools/gen_audio.py`; Create (generated): `assets/audio/thump3.wav`, `thump1.wav`, `intercom_road.wav` and
  their `.import` files
- Modify: `scripts/world/audio_director.gd` (`SOUNDS`), `scripts/horror/events/knock_event.gd`,
  `scripts/story/story_director.gd`
- Modify: `docs/architecture.md` (audio table), `docs/event-catalog.md` (knock_wall's new param)
- Test: `tests/unit/test_story.gd`

**Interfaces:**
- Consumes: `road`, `say(..., always)`, the one-shot store (Task 1).
- Produces: sound ids `&"thump3"`, `&"thump1"`, `&"intercom_road"` in `AudioDirector.SOUNDS` (Task 4 plays
  `&"intercom_road"`); `knock_wall` accepts `params.sound: StringName` (default `&"knock3"`);
  `const SMELL := "[A sour smell, like vinegar.]"` and `const REVERSAL := "[On the road you weren't allowed to look
  back. Here, you can't look away.]"` in `StoryDirector` (a copy of `Penanggal.SMELL`, so the flat doesn't load the
  road's script; a test keeps them equal).

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_story.gd`. Collect `EventBus.sound_requested` as
  `[id, pos]` and lines as in Task 1. Reach the `knocked` beat the do-nothing way (`_until(beat == &"knocked", 170.0)`).

```gdscript
func test_from_the_road_the_bedroom_knocks_sound_like_the_roof() -> bool:
	# road &"caught", do nothing until beat == &"knocked"
	var wall: Vector3 = ApartmentLayout.ANCHORS[&"knock_bedroom_north"]["pos"]
	check(sounds.has([&"thump3", wall]) and not sounds.has([&"knock3", wall]), "the story's knocks are the roof's")
	_place(Vector3(8.5, 0, 0.5))  # in the bedroom (the point this file's other tests use)
	_until(func() -> bool: return false, 5.0)
	eq(lines.count(StoryDirector.SMELL), 1, "her smell, once, as a story line")
	check(not subtitles.has(StoryDirector.SMELL), "not a sound caption: shown with captions off")
	EventBus.object_interacted.emit(&"bedroom_wall")
	check(sounds.has([&"thump1", wall]), "the wall answers like the roof")
	eq(StoryDirector.SMELL, Penanggal.SMELL, "the road's own line")

func test_opened_directly_the_knocks_are_knocks() -> bool:
	# road &"", same path: knock3 then knock1 at that anchor, no thump at all, no SMELL line

func test_the_look_back_line_plays_once() -> bool:
	# road &"alive"; story.debug_skip() -> act 2; then set entrance_shoes to &"moved" and emit &"shoes_moved"
	eq(lines.count(StoryDirector.REVERSAL), 1, "with the first 'Keep looking'")
	# step until a shift completes (scheduler.request(&"shift", {}, 5), limit 120 s)
	eq(lines.count(StoryDirector.REVERSAL), 1, "never twice")

func test_the_look_back_line_comes_with_the_first_shift_too() -> bool:
	# road &"saved"; debug_skip() -> act 2; step until a shift completes: REVERSAL said once; road &"": never
```

  The downstairs ending's knock-back is asserted in Task 4's ending test.

- [ ] **Step 2: Run them to see them fail.** `--filter=test_story` → the new tests FAIL.

- [ ] **Step 3: Make the sounds.** In `tools/gen_audio.py`'s road section, with their own `random.Random` seeds (the
  module's rng untouched): `thump3()`, three `thump_roof()` bodies at 0.0, 0.38 and 0.74 s in 1.3 s, the second at
  0.9 strength (knock3's timing); `thump1()`, one body; `intercom_road()`, 3.0 s of wind (low-passed noise that
  swells) and the first 3.0 s of `engine_loop()` at half gain, band-limited 300–3400 Hz like a door speaker, with a
  0.05 s fade in and 0.4 s fade out. Save with `save_db("thump3", …, KNOCK_DB)`, `save_db("thump1", …, KNOCK_DB)`
  and `save_db("intercom_road", …, -22.0, half=True)`. Run `python3 tools/gen_audio.py`, then the import.
  Expected: `git status --porcelain assets/audio` lists only the three new `.wav` files and their `.import` files.
  If any existing file changed, restore it with `git checkout -- <file>` and say so in the report.

- [ ] **Step 4: Implement.** Add the three ids to `AudioDirector.SOUNDS`. `KnockEvent.start` plays
  `run["params"].get("sound", &"knock3")`. In the story, under `road != &""`: the three `knock_bedroom_north`
  requests (`complained`, the `again` knock in `knocked`, the `revealed` beacon) carry `"sound": &"thump3"`;
  `_wall_answers` plays `&"thump1"`; the downstairs ending's knock-back plays `&"thump3"`. Front-door and adaptive
  knocks are untouched. The smell: once, with `always`, after 4 s in the bedroom during `knocked`, or just before the
  wall's answer if he touches the wall sooner. The look-back line: once, with `always`, at whichever comes first of
  the `Keep looking` objective and a `shift` that completes during `disturbance`.

- [ ] **Step 5: Run them to see them pass.** `--filter=test_story`, `--filter=test_apartment` (its knock test) and
  `--filter=test_beds` pass.

- [ ] **Step 6: Docs.** `docs/architecture.md`'s audio table: one row each for `thump3`, `thump1` (−14.6 dB, the
  knock's level) and `intercom_road` (−22.0 dB), in the table's format. `docs/event-catalog.md`: knock_wall's
  `sound` param, and that the story uses it after the road.

- [ ] **Step 7: Commit** the code, the generated files, the tests and the docs: `feat(flat): the road follows him in`.

### Task 4: The last call and the ending cards

**Files:**
- Modify: `scripts/story/story_director.gd`, `scripts/ui/hud.gd:463` (the ending card)
- Modify: `docs/architecture.md` (the story section: one short paragraph on what changes after the road)
- Test: `tests/unit/test_story.gd`

**Interfaces:**
- Consumes: `road`, `say(..., always)`, the one-shot store (Task 1); `&"intercom_road"` (Task 3).
- Produces: `static func ending_card(ending_id: StringName, road: StringName) -> Array` (`[title, text]`; any road
  not in the table gives `ENDINGS[ending_id]`); the HUD shows
  `StoryDirector.ending_card(WorldState.ending, Journey.road_ending)`.

The table (titles stay `DOWNSTAIRS` and `VACANT`; `\n\n` between paragraphs as in `ENDINGS`):

| Road | DOWNSTAIRS | VACANT |
|---|---|---|
| caught | `ENDINGS` text + `\n\nYou never got home.` | `ENDINGS` text with its notice line reading `Unit B-12-07 has been vacant since November. Its tenant was one of three people found on the old road down the mountain.` |
| saved | `You knock three times.` / `Something knocks back, three times, from inside the wall, the way something landed on the roof of Hafiz's car.` / `Hafiz never got home. He's been knocking all night.` | `The lift is warm, as if someone has just stepped out of it.` / `You don't go back up.` / `Hafiz never got home. Some nights you still hear him knocking.` |
| alive | `You knock three times.` / `Something knocks back.` / `All three of you got home. Something else came down the mountain too.` | `The lift is warm, as if someone has just stepped out of it.` / `You don't go back up.` / `All three of you got home. Something else came down the mountain too.` |

The last call, on inspecting the intercom after Rosnah's call (the inspect text as today), once per flat: caught and
saved play `&"intercom_road"` at the `phone_intercom` anchor, then say `[The speaker crackles. Wind, and an engine
idling.]` (3.0 s) and the road's line (3.5 s), both with `always`. Alive and `&""`: as today.

- [ ] **Step 1: Write the failing tests** in `tests/unit/test_story.gd`:

```gdscript
func test_ending_cards_follow_the_road() -> bool:
	for id: StringName in [&"downstairs", &"vacant"]:
		eq(StoryDirector.ending_card(id, &""), StoryDirector.ENDINGS[id], "%s opened directly: as today" % id)
		for road: StringName in [&"caught", &"saved", &"alive"]:
			eq(StoryDirector.ending_card(id, road)[0], StoryDirector.ENDINGS[id][0], "%s/%s keeps its title" % [id, road])
	check(StoryDirector.ending_card(&"downstairs", &"caught")[1].ends_with("You never got home."), "caught: he never got home")
	check(StoryDirector.ending_card(&"vacant", &"caught")[1].contains("Its tenant was one of three people found on the old road down the mountain."), "caught: the notice")
	check(StoryDirector.ending_card(&"downstairs", &"saved")[1].ends_with("He's been knocking all night."), "saved: Hafiz")
	check(StoryDirector.ending_card(&"vacant", &"saved")[1].ends_with("Some nights you still hear him knocking."), "saved: Hafiz")
	for id: StringName in [&"downstairs", &"vacant"]:
		check(StoryDirector.ending_card(id, &"alive")[1].ends_with("Something else came down the mountain too."), "alive: %s" % id)

func test_the_downstairs_knock_back_follows_the_road() -> bool:
	# road &"caught": act 4 via debug_skip x3, emit &"mirror_wall": sounds has [&"thump3", knock_mirror pos]; road &"": [&"knock3", …]

func test_the_last_call_points_back_once() -> bool:
	for road: StringName in [&"caught", &"saved", &"alive", &""]:
		# setup, story.road = road, WorldState.set_flag(&"answered_intercom"), emit &"intercom" twice, step 10 s
		# caught: lines.count("\"Eh, you going down ah? Jom, we got space.\"") == 1 and sounds intercom_road once
		# saved:  lines.count("\"Wah, so late still working ah? Kesian, bro.\"") == 1 and sounds intercom_road once
		# alive and &"": neither line, no intercom_road
```

- [ ] **Step 2: Run them to see them fail.** `--filter=test_story` → the new tests FAIL.

- [ ] **Step 3: Implement** the table as a const beside `ENDINGS`, `ending_card()`, the last call, and the HUD line.

- [ ] **Step 4: Run them to see them pass.** `--filter=test_story` and `--filter=test_hud` pass.

- [ ] **Step 5: Docs, then commit** `feat(flat): the last call and the endings point back to the road`.

### Task 5: Bots after each road ending, the opening still, the full checks

**Files:**
- Modify: `tests/sim/playthrough.gd` (`run`), `tools/playthroughs.gd`, `tools/stills.gd`
- Regenerate: `docs/playthroughs.md`
- Modify: `docs/test-plan.md` (the new tests, one line each)

**Interfaces:**
- Consumes: everything above.
- Produces: `static func run(profile_name: String, seed_value: int, road_ending: StringName = &"") -> Dictionary`
  (sets `Journey.road_ending` for the run, restores the old value after; the result carries `"road"`);
  `tools/stills.gd --road=<ending>`.

- [ ] **Step 1: Bots.** `tools/playthroughs.gd` keeps today's table and sections (road `&""`) and adds a section
  `## After the road`: one row per bot (explorer, avoider, passive) per road ending (alive, saved, caught) with the
  road ending, the flat ending, sim time, errors and warnings; same seed. Keep the file's existing wording that these
  are bots, not human playtests.

- [ ] **Step 2: Run them.** `$GODOT --headless --path . --script res://tools/playthroughs.gd`. Expected: every row of
  the new section has a flat ending (explorer `downstairs`, avoider `vacant`, passive `downstairs` by the fail-safe)
  and 0 errors. `git diff docs/playthroughs.md` shows only the new section: today's runs (road `&""`) come out
  identical. If a row says **none**, shows errors, or an old row changed, stop and report it with the row.

- [ ] **Step 3: The still.** `tools/stills.gd`: `--road=<ending>` sets `Journey.road_ending` before the scene loads,
  and a shot `["footprints", 6.5, 8.4, 1.88, -0.35, [], {}, null, true, 0.0, false]` (from where he stands, turned
  towards the front door, phone light on), taken after the wake card has gone. The controller runs
  `$GODOT --path . --script res://tools/stills.gd -- --out=/tmp/bridge-stills --road=caught` (it needs a window) and
  looks at `footprints.png` and `living.png`.

- [ ] **Step 4: Full checks.** `GODOT=$GODOT tools/test.sh` → `Results: N passed, 0 failed`;
  `perl -e 'alarm 300; exec @ARGV' $GODOT --path . -- --smoke` → prints `ROAD-SMOKE ok` and `SMOKE ok`;
  `ls override.cfg` → no such file.

- [ ] **Step 5: Commit** `test(sim): the bots play the flat after each road ending`, with the regenerated
  `docs/playthroughs.md` and `docs/test-plan.md`.

## Notes for the controller

* The HUD's red clock (top right) is the flat's clock and reads 11:47 PM, like the wall clock; only the caption says
  the phone reads 12:41 AM. Not changed by this plan; worth a look in the owner's play-through.
* Task 3's sound generator rewrites every file it owns; the check in its Step 3 is what proves nothing else moved.
