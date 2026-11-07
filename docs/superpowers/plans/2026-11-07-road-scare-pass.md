# The Road's Scare Pass Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the road scarier in real play: a jump-scare when he looks back on the walk, the missing sound captions on a
caption line of their own, key sounds 10 dB over their beds, and a low wind instead of digital silence. Then record the
real-play trailer again.

**Architecture:**
- The core (RoadDirector, LightMission) gains one cue when a look back counts; the presentation (Penanggal, RoadMain,
  RoadAudio) does everything else.
- The HUD gets a second line for sound captions, and StoryDirector splits its one queue into spoken lines and sound
  captions. So a caption never waits behind a spoken line and never replaces one.
- Levels are judged by one real-play recording made with the play-trailer tools.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer (web + desktop); tools/gen_audio.py (Python stdlib);
ffmpeg for the trailer.

**Spec:** docs/superpowers/specs/2026-11-07-road-scare-pass-design.md (owner-approved 2026-11-07). Read it first; its
"My calls" are binding.

## Global Constraints

- Work in /Users/chrischeng/the-condo/.claude/worktrees/road-scare, branch feat/road-scare. Run
  `$GODOT --headless --path . --import` once before the first test.
- `GODOT=/Users/chrischeng/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot`.
- Tests: `GODOT=$GODOT tools/test.sh --filter=<file>`, and the full suite with `GODOT=$GODOT tools/test.sh`. About 11
  ObjectDB and 5 resource leak lines are known noise. `test_director_runs_in_game_within_budget` is load-sensitive:
  re-run it alone before calling it a failure.
- Smoke: `perl -e 'alarm 300; exec @ARGV' $GODOT --path . -- --smoke` must print `ROAD-SMOKE ok` and `SMOKE ok`.
- Typed GDScript. Comments in the file's own style: `##` doc lines that say what a thing is in the story's terms.
- "No change to the rules, the score, the outcomes or any timing in the core. The three bots (keeper, wobbly, breaker)
  end as now (alive 0, saved 4, caught 16, on seeds 1147, 7 and 2026)."
- "No paid assets or services, and no external LLM APIs." Sounds come from tools/gen_audio.py, or are existing files.
- Road sounds saved with `save_db` keep its ceiling: no road sound's loudest 100 ms above `KNOCK_DB` (−14.6 dBFS).
- "No shader compiles mid-game": `test_every_road_material_is_warmed` passes.
- "Within about 1 m of his head … capped at file level + 3 dB (`max_db`)": play levels do nothing there.
- "In the real-play recording, at the master volume as shipped (0.8), the sting and the louder sounds peak no higher than
  the loudest peak there now (−6.1 dBTP)". Master 0.8 is −1.9 dB on bus 0.
- "Nothing here is a human playtest, and nobody here can listen: loudness is judged by measurement only."
- Never run tools/export.sh. Never leave an override.cfg. Never use bare `git stash`. Never push, merge or upload.
- This Mac is shared: stop only processes you started.
- Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never write a model name anywhere
  else in the repository.
- Implementers dispatch no subagents.

## Review Focus

1. **He looks back with his phone light on** (not only off): her face stays readable, not blown out by the phone's spot
   plus her fill. Task 2 renders the still both ways.
2. **He looks back while a spoken line or Mei's choice is up** (Hafiz's voice, the choice): the line stays, the sting
   caption shows on the caption line. Task 3 tests it.
3. **A second counted look comes while the first scare is still running:** she lunges again cleanly, and her fill
   light fades out afterwards; it is never left on. Task 2 tests it.
4. **Captions for sounds off:** no new caption shows, every spoken line still shows, and the sting still sounds. Tasks 3
   and 4 test it.
5. **Two sound captions in a row in the flat** ("[Nobody there. The corridor is empty.]" then "[Deeper in the flat,
   something heavy settles.]") still show one after the other, not on top of each other. Task 3 tests it.

---

### Task 1: The core says when a look back counts

**Files:**
- Modify: `scripts/road/road_director.gd` (`watch_look`, `_watch`)
- Modify: `scripts/road/missions/light_mission.gd` (`_walk`)
- Test: `tests/unit/test_road_director.gd`, `tests/unit/test_light_mission.gd`

**Interfaces:**
- Produces:
  - `RoadDirector.watch_look(rule: StringName, left: float, right: float, hold: float, weight: int, max_count: int, cue: StringName = &"") -> void`.
    Each time the look rule breaks, it emits `EventBus.road_cue` with `cue`, right after `break_rule`'s `rule_broken`.
    It emits nothing when `cue` is empty.
  - `LightMission`: the walk's look rule passes `cue = &"her_lunges"`. CountMission passes none.

- [ ] **Step 1: Write the failing tests.**
  - In test_road_director.gd, `test_a_look_rule_can_name_its_cue`:
    - with `watch_look(&"r", 1.9, 1.9, 0.25, 3, 2, &"x")`, two held looks with a return between them emit `&"x"` twice,
      each right after a `&"rule_broken"`;
    - a third look emits nothing more;
    - the same rule without a cue emits no extra cue.
    - Drive the yaw as `test_look_rule_needs_a_hold_and_a_return` does.
  - In test_light_mission.gd, `test_looking_back_makes_her_lunge`:
    - looking back as in `test_looking_back_costs_three_twice_at_most` gives `cues.count(&"her_lunges") == 2`;
    - keeping every rule (as in `test_getting_out_and_keeping_every_rule`) gives 0.
- [ ] **Step 2: Run them and see them fail.**
  `GODOT=$GODOT tools/test.sh --filter=test_road_director` and `--filter=test_light_mission`.
- [ ] **Step 3: Implement.**
  - The new parameter in `watch_look`, stored as `_look_cue`.
  - `_watch` emits it after `break_rule`.
  - `LightMission._walk` passes `&"her_lunges"`.
  - Doc comments: say what the cue is for (the presentation's scare; the bots ignore it).
- [ ] **Step 4: Run the two files, then the full suite.**
  - Run `$GODOT --headless --path . --script res://tools/playthroughs.gd`.
  - `git diff --stat docs/playthroughs.md` must show no change in any outcome or score. Commit the file only if it
    changed.
- [ ] **Step 5: Commit** "feat(road): the core says when a look back counts".

### Task 2: She is right behind him

**Files:**
- Modify: `scripts/road/her.gd` (new mode `&"lunge"`, a fill light, her layer)
- Modify: `scripts/road/road_main.gd` (`_on_cue`: `&"her_lunges"`)
- Modify: `scripts/road/road_audio.gd` (`SOUNDS` gains `&"stinger"`, `&"shriek"`; new `play_here`)
- Modify: `tools/gen_audio.py` (new `shriek()` in `road_sounds()`); Create: `assets/audio/shriek.wav` (+ its .import)
- Modify: `tools/road_stills.gd` (shots `lunge` and `lunge_phone`, phone light off and on, for checking only)
- Modify: `docs/architecture.md` (the road's prose on her; "Audio levels" rows for the sting and the shriek)
- Test: `tests/integration/test_her.gd`

**Interfaces:**
- Consumes: the `&"her_lunges"` cue (Task 1).
- Produces:
  - `Penanggal.lunge(camera: Camera3D) -> void`, and its constants:
    - `LUNGE_AT := 0.5`: metres from the camera to her skull's centre. My call: size wins, and a third of the view needs
      0.54 m or less for a 0.26 m head at fov 72.
    - `LUNGE_HOLD := 0.5`: seconds.
    - `LUNGE_CAPTION := "[She is right behind you.]"`.
  - `RoadAudio.play_here(sound_id: StringName, volume_db: float) -> void`: one non-positional `AudioStreamPlayer` for a
    sound in his head, so its level is exact and never meets the +3 dB cap.
- **Behaviour (from the spec, goal 1):**
  - `lunge` does nothing unless she is in `&"behind"` or `&"lunge"`.
  - She is placed in the same frame: `LUNGE_AT` along the camera's view flattened to level, at the camera's height,
    facing it.
  - It plays the stinger and the shriek through `play_here`, and emits `LUNGE_CAPTION` on `subtitle_requested`.
  - After `LUNGE_HOLD` she becomes `&"behind"` again from where she is, so `_process` takes her back to
    `_behind_point()` at `FOLLOW`.
  - A lunge during a lunge restarts it.
  - Her fill: an `OmniLight3D` child, shadows off.
    - It lights only her: its `light_cull_mask` is a visual layer that only her mesh is on. Pick a free layer: the
      mirror uses 11, and RoadMain has `PICTURE_LAYER`. Document the choice.
    - Steady and dim at the lunge. Its energy fades to 0 over the pull-back, never a hard switch, and it is off in
      every other mode.
- **Levels:**
  - STING and SHRIEK play levels are set so their summed peak at master 0.8 is ≤ −6.1 dBFS, worked out from the files'
    peaks. Write the arithmetic in the levels table.
  - `shriek` is saved with `save_db` (≤ −14.6 dBFS loudest 100 ms): her voice, high and rough, about 0.8 s, distinct
    from the stinger's swell.

- [ ] **Step 1: Write the failing test.**
  `test_lunge_puts_her_in_his_face_then_back`, set up as `test_come_for_stops_short_of_the_camera`. A walker and a camera
  1.6 m above it at s 900, the camera turned to look back down the road. `behind(walker)`, 2 frames, then `lunge(camera)`:
  - after 1 frame, `near(distance to camera, Penanggal.LUNGE_AT, 0.02)`;
  - `near(her.y, camera.y, 0.02)`;
  - she is where he looks: `(her - camera).normalized().dot(-camera.global_basis.z) > 0.98`;
  - her face is to it (as in the come_for test);
  - her fill is visible with energy > 0;
  - one `subtitle_requested` carries `LUNGE_CAPTION`;
  - after `LUNGE_HOLD` + 0.5 s she is ≥ 2.2 m from the camera;
  - after 3 s she is within 0.5 m of `_behind_point()`, and her fill's energy is 0;
  - a second `lunge` mid-hold restarts it: she is back at `LUNGE_AT`;
  - after `hide_her()`, `lunge(camera)` leaves her hidden.
- [ ] **Step 2: Run it and see it fail.** `GODOT=$GODOT tools/test.sh --filter=test_her`.
- [ ] **Step 3: Implement it.**
  - Generate the shriek: `python3 tools/gen_audio.py`. Commit only `shriek.wav`; `git checkout --` any other WAV the run
    rewrites unchanged in sound.
  - Import: `$GODOT --headless --path . --import`.
  - `RoadMain._on_cue`: `&"her_lunges": her.lunge(player.camera)`.
- [ ] **Step 4: Run test_her, test_road_warm_up and test_road_builder** (its per-object light limit), then the full suite
  and the smoke.
  - Also run `$GODOT --path . -- --perf` (it needs a window) on c8e9459 and on your commit, and give both results in the
    report. The road's numbers must not be worse by more than noise; docs/performance.md says how to read them.
- [ ] **Step 5: Render and look.**
  - Render both shots: `GODOT=$GODOT tools/road_stills.sh /tmp/road-scare-stills lunge lunge_phone`. It needs a window,
    and its trap removes the override.cfg; check that `ls override.cfg` finds nothing afterwards.
  - Look at both:
    - her face fills about a third of the frame height or more;
    - it is lit and readable, not blown out with the phone on.
  - Tune the fill's energy and say what you saw in the report.
- [ ] **Step 6: Update docs/architecture.md.**
  - Her prose: the look-back scare, the cue, her fill and its layer.
  - Fix her header comment in her.gd ("none of them is a sting").
  - "Audio levels": the stinger and the shriek at the look-back, with their arithmetic.
- [ ] **Step 7: Commit** "feat(road): she is right behind him when he looks back".

### Task 3: Sound captions get a line of their own

**Files:**
- Modify: `scripts/ui/hud.gd` (a `_caption` Label above `_subtitle`; routing; its timer)
- Modify: `scripts/story/story_director.gd` (`say`, `_speak`: two queues)
- Modify: `tools/trailer.gd` (its subtitle font override also on `_caption`)
- Modify: `docs/architecture.md` (the caption rule)
- Test: `tests/integration/test_hud.gd`, `tests/unit/test_story.gd`, `tests/integration/test_trailer.gd`

**Interfaces:**
- Produces:
  - **HUD `_caption: Label`.** It sits just above `_subtitle`, in the same style. It shows every `subtitle_requested`
    text that does not begin with `"`, and only with "Captions for sounds" on. A new caption replaces the one on it.
  - **HUD `_subtitle`.** It shows `line_requested` texts and the `subtitle_requested` texts that begin with `"`, as
    today. A sound caption never touches it.
  - **StoryDirector `say(text, seconds := 3.5, always := false)`.** Its signature is unchanged. A spoken line
    (`always`, or text beginning with `"`) goes to `_lines`; anything else goes to a new `_captions` queue with its own
    timer `_caption_left`. Each queue keeps its FIFO order and its 0.3 s gap.
  - **The last call keeps its test.** `_play_last_call`'s check stays on `_lines` and `_line_left`, because Rosnah's
    lines are spoken.
- Note for reviewers: existing tests that read `hud._subtitle.text` for a sound caption move to `hud._caption.text`.
  That is the design, not a weaker test.

- [ ] **Step 1: Write the failing tests.**
  - test_hud.gd, `test_a_sound_caption_never_cuts_a_spoken_line`:
    - after `line_requested("Hafiz: \"Mei! Wait for me!\"", 5.0)` and then `subtitle_requested("[She is right behind you.]", 2.0)`,
      `_subtitle.text` is still Hafiz's line and `_caption.text` is the caption;
    - with captions off, `_caption.text` stays "" and the line still shows;
    - a quoted `subtitle_requested` shows on `_subtitle`.
  - test_story.gd, `test_the_wall_answer_shows_with_its_knock`: with three spoken lines queued (`say(..., 3.5, true)`),
    calling `_wall_answers()` and ticking 0.5 s gives one `subtitle_requested` with the wall's text.
  - test_story.gd, `test_sound_captions_keep_their_order`: two non-spoken lines said together come out 3.3 s apart
    (3.0 + 0.3), in order.
  - Add `_caption` to `test_hud_labels_follow_their_anchors`. In test_trailer.gd, check the font override on `_caption`
    too.
- [ ] **Step 2: Run and see them fail:** `--filter=test_hud`, `--filter=test_story`, `--filter=test_trailer`.
- [ ] **Step 3: Implement** as in Interfaces. Move the sound-caption assertions in
  `test_road_sounds_are_captioned_with_captions_on` (and any other test reading a sound caption from `_subtitle`) to
  `_caption`.
- [ ] **Step 4: Run the three files, then the full suite and the smoke.**
  - Run tools/playthroughs.gd.
  - Outcomes and scores must be unchanged. Explain any other diff in docs/playthroughs.md in the report.
- [ ] **Step 5: Update docs/architecture.md.** The caption rule (spec goal 3): two lines, two queues, and what counts as
  spoken.
- [ ] **Step 6: Commit** "feat(hud): sound captions get a line of their own".

### Task 4: The road's missing captions

**Files:**
- Modify: `scripts/road/road_main.gd` (`CAPTIONS`, `_on_cue`)
- Modify: `scripts/road/her.gd` (her first wet flap behind him)
- Test: `tests/integration/test_hud.gd` (`test_road_sounds_are_captioned_with_captions_on`), `tests/integration/test_her.gd`

**Interfaces:**
- Consumes: the caption line (Task 3).
- Produces:
  - `RoadMain.CAPTIONS[&"overtake"] = ["[The engine roars.]", 2.5]`, not in `ONE_SET`, so it shows on every overtake.
  - `RoadMain.THUMP_AGAIN := ["[It moves on the roof.]", 2.5]`: shown on each `&"thump"` once `&"thump"` is in
    `_captioned`.
  - `Penanggal.FLAP_CAPTION := "[Behind you, something wet flaps.]"`: on `subtitle_requested`, 2.5 s. It goes with her
    first wet flap in `&"behind"` mode only, once per Penanggal, and never for the door's slap or her other modes.

- [ ] **Step 1: Write the failing tests.**
  - Extend `test_road_sounds_are_captioned_with_captions_on`. The cues `thump`, `thump`, `thump` give "[Something lands
    on the roof]", "[It moves on the roof.]", "[It moves on the roof.]". The cues `overtake`, `overtake` give two "[The
    engine roars.]". With captions off, none of them shows on `_caption`.
  - In test_her.gd, `test_her_first_flap_behind_is_captioned`: `behind(walker)`, then run frames until two `wet_flap`
    sounds have been requested (at most 6 s each). Exactly one `FLAP_CAPTION` arrives, with the first flap's
    `sound_requested`.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.**
- [ ] **Step 4: Run the two files, the full suite and the smoke.**
- [ ] **Step 5: Commit** "feat(road): caption the roar, every roof thump and her flap behind him".

### Task 5: The mix: four sounds 10 dB up, and the wind

**Files:**
- Modify: `tools/gen_audio.py` (new `wind_loop()` in `road_sounds()`); Create: `assets/audio/wind_loop.wav` (+ .import
  with `edit/loop_mode=2`)
- Modify: `scripts/road/road_audio.gd` (`LOOPS[&"wind_loop"]`)
- Modify: `scripts/road/road_main.gd` (`_ride`: the wind; the roar and the sputter levels)
- Modify: `scripts/road/her.gd` (the level of her noises in `&"behind"`)
- Modify: `scripts/story/story_director.gd` (only the `&"complained"` beat's `knock_wall` request: its `volume_db`)
- Modify: `docs/architecture.md` ("Audio levels": the wind and every changed row)
- Test: `tests/integration/test_ride.gd` (next to `test_road_audio_plays_the_road`), `tests/unit/test_story.gd`

**Interfaces:**
- **The wind** plays for the whole night road, the insects over it until they stop, so nothing starts at the "quiet"
  beat.
  - Levels: `set_loop(&"wind_loop", true, WIND_DB_OUT or WIND_DB_IN)`. Heard about −48 dB outside and 6 dB lower seated,
    as the insects drop 6 dB.
  - The file: mono, half rate, ≤ 530 KB, loop seam clean (`save_db(..., loop=True, half=True)`).
- **The four sounds' means**, chosen to fit the cap and `KNOCK_DB`:
  - *The roar:* at the camera, capped. Its file can rise at most to −14.6. The main means is the bed: while it plays,
    the engine loop drops by `ROAR_DUCK` dB.
  - *The sputter:* at ENGINE, about 2.3 m from his seat. Its play level can rise to the cap (heard −16 at most), and its
    file to −14.6.
  - *Her flap behind him:* `Penanggal._play(sound: StringName, volume_db := 0.0)`. NOISES rows gain a fourth field, a
    play level. `&"behind"` uses `BEHIND_DB` for the wet flap; the door's slap and other modes keep 0.
  - *The bedroom thumps at the intercom:* the `&"complained"` request's `volume_db` (now 2.0) rises to `KNOCK_AT_CALL_DB`.
    The `&"again"` request and every other use stay.
- Start values are your call, aiming at ≥ 12 dB in the table's arithmetic. Task 6 measures them, and any fix comes
  back here.

- [ ] **Step 1: Write the failing tests.**
  - `test_the_night_never_goes_dead` in test_ride.gd, built as `test_road_audio_plays_the_road`: `wind_loop` is playing at the start,
    and is still playing after `insects_stop`; the insects' loop has stopped; seated, the wind's level is 6 dB under
    standing.
  - In test_story.gd: the complained beat's knock request carries `KNOCK_AT_CALL_DB`, and the `again` one still
    carries 2.0.
- [ ] **Step 2: Run them and see them fail.**
- [ ] **Step 3: Implement it.** Generate the wind with `python3 tools/gen_audio.py`. Commit only the new or changed WAVs
  you meant to change, then run the import.
- [ ] **Step 4: Run the full suite and the smoke**, and tools/playthroughs.gd (outcomes unchanged).
- [ ] **Step 5: Update docs/architecture.md** "Audio levels": the wind (outside and seated), and each changed level with
  its arithmetic.
- [ ] **Step 6: Commit** "feat(road): the key sounds stand 10 dB out, and the quiet keeps its wind".

### Task 6: Measure in real play and record the trailer again

Runs after the final review of feat/road-scare. It is done by Claude (it needs a window and Movie Maker), not by a
subagent.

**Files (on a new local branch feat/play-trailer-2 from feat/road-scare, with d72e072 cherry-picked):**
- Modify: `tools/play_trailer.gd` (waits for the new beats; the look-back clip holds on the sting)
- Modify: `tools/play_trailer.sh` (every dip in CLIPS 0; the key-sound rows add the sting as `cue:her_lunges#1`; a
  digital-silence check)

**Steps:**
- [ ] **Step 1: Set up the branch.** `git checkout -b feat/play-trailer-2 feat/road-scare`, `git cherry-pick d72e072`,
  then run the import.
- [ ] **Step 2: Fix the edit.**
  - Set every dip to 0.
  - Add the check: no 100 ms window of the road's night clips below −70 dBFS RMS.
  - Fix the checker's edit-level findings: the 9.15 s near-black intercom frame (42.15–51.30 s), and the 3.2 s static
    sink end.
  - Keep the brief's rules (.superpowers/play-trailer-brief.md): input only, captions on, the never-on-screen list.
- [ ] **Step 3: Record and look.**
  - Record, cut and encode with `tools/play_trailer.sh`. It needs a window; any override.cfg must be removed by its
    trap.
  - report.txt must show, in the game-mix column, every key sound ≥ 10 dB, the sting included. It must also show
    limiting ≤ 6 dB and no sample peak over −0.1 dBFS.
  - From the frames:
    - at the sting her face fills ≥ a third of the frame height, lit;
    - within about a second, one frame shows her whole figure;
    - the new captions show with their sounds, and none cuts a spoken line;
    - the wall's caption is up within 0.5 s of its knock.
- [ ] **Step 4: If a margin fails, fix it on feat/road-scare** (Task 5's levels, as a fix commit there), rebase
  feat/play-trailer-2 onto it, and record again.
- [ ] **Step 5: Check, then upload.**
  - Get an independent check of the MP4 against the spec's trailer taste.
  - On a pass, upload privately to Drive "The Condo trailer" (rclone remote klrush-drive:, no share link).
  - Report the path and the numbers to the owner. Merging anything into main waits for the owner.
