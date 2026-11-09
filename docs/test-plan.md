# Test plan

Run everything: `GODOT=/path/to/Godot tools/test.sh` (imports, then runs `tests/run_tests.gd`).
Filter: `tools/test.sh --filter=room_graph`. Exit code 0 means every test passed.

Test files extend `TestCase` (`tests/test_case.gd`). Methods named `test_*` must end with `return true`;
a method that hits a runtime error returns null and is reported as "did not finish". `WorldState` is reset
before every test.

The runner waits one frame after every test, so a scene the test `queue_free()`d is gone before the next
test starts (a leftover scene's StoryDirector would otherwise answer the next test's signals). The full
suite ends without "leaked" or "still in use" warnings. A filtered run whose last test is an in-game one
can report `AudioStreamPlaybackWAV` leaks: the headless dummy audio driver never releases the looping
ambience of a scene freed in the last frame. Tests use `user://test_settings.cfg` and default settings,
never the player's own. The runner sets the viewport to the game's 16:9 window (1600×900); headless
Godot otherwise uses a square one, which sees less at the sides than a player does.

## Levels

| Level | Where | Covers |
|---|---|---|
| The road, unit | `tests/unit/test_road_director.gd`, `test_road_layout.gd`, `test_lift_mission.gd`, `test_slow_car_mission.gd`, `test_count_mission.gd`, `test_stall_mission.gd`, `test_light_mission.gd` | the road's core with no nodes: the weighted count of the others' rules and the outcome thresholds, the choices (3 s, one open at a time, silence) and the look rule, the road's data, each mission's beats and cues, what kills him (his own rules and the clocks: the lift's 10 s, the lock's 5 s, standing still for 5 s) and what Try again keeps |
| The road, in the scene | `tests/integration/test_journey.gd`, `test_ride.gd`, `test_couple.gd`, `test_her.gd`, `test_mirror.gd`, `test_slow_car.gd`, `test_stall.gd`, `test_endings.gd`, `test_road_builder.gd`, `test_road_warm_up.gd` | the road hands over to the flat at 11:47 and both restarts go back to the road; he rides in the car; the penanggal's places and that she never passes through the car; the mirror shows the fourth passenger only while Mission 3 has it on; the lights, the roof and the three endings; the road built in code; every material drawn once behind the start card |
| The road, simulated players | `tests/integration/test_road_playthroughs.gd` | three bots (`keeper`, `wobbly`, `breaker`, `tests/sim/road_playthrough.gd`) drive the road's core to `alive`, `saved` and `caught` on three seeds, and none dies (`test_no_bot_dies`); same seed, same run |
| Deaths and Try again | `tests/unit/test_road_director.gd`, `test_lift_mission.gd`, `test_count_mission.gd`, `test_stall_mission.gd`, `test_light_mission.gd`, `test_visitor.gd`, `test_entity.gd`, `test_story.gd`, `tests/integration/test_journey.gd`, `test_ride.gd`, `test_hud.gd` | each death happens, and in the core (the road's `die` and clocks, the visitor's front door and lights, the entity's rattle, act 3's front door), only after the warning where there is one; he sees her come, in view with nothing in the way for 0.5 s or more before she reaches him, standing still or out of the car on the road and facing a wall or at the peephole in the flat (`test_*_he_sees_her_come`, `test_her.gd`'s `test_come_for_starts_where_he_sees_her_come`); the GAME OVER card with the cause's line and Try again; Try again starts the mission or act he died in, with the road's kept count or the flat's snapshot; the flat's beds duck the full 30 dB, however close he stands, while the neighbour's rattle has him in its window, and come back when he turns, gets away or an ending comes (`test_home_beds.gd`) |
| The road's HUD | `tests/integration/test_hud.gd` | the start card says "blood and gore" on the road and on the flat (`test_start_card_warns_of_gore`); a choice stays open until the core closes it, even paused; stray keys do nothing; the choices fit the screen; what people say shows with captions off; a sound caption has its own line above and never cuts a spoken line short (`test_a_sound_caption_never_cuts_a_spoken_line`) |
| Unit (the flat) | `tests/unit/` | room graph, event eligibility, cooldowns, utility scoring, behaviour aggregation, tension decay, lifecycle transitions, seeded selection |
| Integration (the flat) | `tests/integration/` | doors, scheduling, world-state updates, room transformations, story progression, endings, a physics walk through every room |
| Story | `tests/unit/test_story.gd` | act 1–3 fail-safes with an idle player, the reveal never in front of the player, noticing moved things, both endings and the decision fail-safe |
| Simulated playthroughs | `tests/integration/test_playthroughs.gd` | Explorer, Avoider and Passive bots (`tests/sim/playthrough.gd`) driving the simulation core to an ending on three seeds, and none dies (`test_no_flat_bot_dies`: they put the lights out for the visitor, keep the front door shut in a visit and in act 3, and turn to the rattle); the explorer meets an armed visitor on seeds 3 and 5 and lives through it; same seed, same run |

Simulated playthroughs are bots, not people. They are never reported as human playtests.
`godot --headless --path . --script res://tools/playthroughs.gd` rewrites `docs/playthroughs.md` with each
bot's event sequence, director scores, progression, completion, errors and warnings, and the road's bots. The road's
bots are checked by `test_road_playthroughs.gd`: the keeper ends `alive` with score 0, the wobbly one `saved` with 3 and
the breaker `caught` with 9, and none of them dies. The keeper reaches `alive` at 538 s of sim time (9.0 minutes; the test
accepts 7 to 15 minutes), a lower bound for a person, because the bot answers in a second and walks straight.

`docs/playthroughs.md` also has `## Meeting the visitor` (the explorer on seeds 3 and 5, where an armed visitor comes) and
`## After the road`: the same three bots in the flat after each road ending
(`Playthrough.run(profile, seed, road_ending)`, which sets `Journey.road_ending` for the run and puts it back). Every
row ends the flat (explorer `downstairs`, avoider `vacant`, passive `downstairs`) with no errors or warnings. The
record is generated by the tool, not checked by the suite.

## The bridge from the road to the flat

What the flat does with `Journey.road_ending` (`alive`, `saved`, `caught`; `&""` = opened directly, which keeps
today's flat). Each test sets the ending itself and puts it back.

| Test | Where | Pins |
|---|---|---|
| `test_footprints_only_come_down_from_the_road` | `tests/integration/test_apartment.gd` | red earth from just inside the front door to where he stands, only after a road ending: a trail of even strides, one lit mesh of tread prints blended over the floor and fading from the door, and a low box to look at ("Look at the footprints") clear of the furniture |
| `test_the_footprints_are_walked_over` | `tests/integration/test_apartment.gd` | the player walks across the trail (x 5.9 to 3.4) and stays on the floor, not on the box |
| `test_from_the_road_the_flat_opens_quiet_and_asking` | `tests/unit/test_story.gd` | the first objective is "How did you get home?", two found lines (phone 12:41, damp uniform), nothing happens for 20 s |
| `test_lying_down_early_holds_the_ring_until_the_quiet_ends` | `tests/unit/test_story.gd` | the intercom does not ring before 20 s, and rings once the quiet is over |
| `test_washing_during_the_question_leaves_get_some_sleep` | `tests/unit/test_story.gd` | washing does not answer the question; "Get some sleep." follows at the end of the quiet |
| `test_inspecting_the_footprints_ends_the_question` | `tests/unit/test_story.gd` | looking at the footprints gives way to the usual objective, and the quiet still holds the ring |
| `test_opened_directly_the_flat_opens_as_today` | `tests/unit/test_story.gd` | no road: today's objective, the ring 4 s after lying down, no new lines |
| `test_from_the_road_the_bedroom_knocks_sound_like_the_roof` | `tests/unit/test_story.gd` | the wall's knocks and its answer are the roof's thumps; her smell comes once, as a story line, by the wall |
| `test_the_wall_answer_shows_with_its_knock` | `tests/unit/test_story.gd` | the wall's answer caption comes within 0.5 s of its knock, with spoken lines still queued |
| `test_sound_captions_keep_their_order` | `tests/unit/test_story.gd` | two captions said together come out in order, 3.3 s apart |
| `test_touching_the_wall_early_brings_the_smell_after_the_answer` | `tests/unit/test_story.gd` | touching the wall early: the smell follows the answer's caption, once |
| `test_the_fail_safe_answer_brings_no_smell_to_someone_elsewhere` | `tests/unit/test_story.gd` | the wall answers by itself at 120 s, but there is no smell unless he is by the bedroom wall |
| `test_opened_directly_the_knocks_are_knocks` | `tests/unit/test_story.gd` | no road: knuckle knocks, no thump, no smell line |
| `test_the_look_back_line_plays_once_when_he_notices_something_moved` | `tests/unit/test_story.gd` | a shift moves an object and says nothing; the first time he notices a moved object, "On the road you weren't allowed to look back. Here, you can't look away." follows the notice line, never twice |
| `test_the_look_back_line_comes_with_the_first_notice_even_after_enough_signs` | `tests/unit/test_story.gd` | the first notice brings the line even when he already has enough signs (no "Keep looking" objective) |
| `test_opened_directly_nothing_is_said_when_he_notices` | `tests/unit/test_story.gd` | no road: noticing a moved object says no look-back line and no new line at all |
| `test_the_downstairs_knock_back_follows_the_road` | `tests/unit/test_story.gd` | the knock back at the mirror wall (the B-11-07 side) is a thump after a road and a knuckle knock without one, never both |
| `test_ending_cards_follow_the_road` | `tests/unit/test_story.gd` | every road has its card text per flat ending (titles kept); no road keeps today's cards; caught adds "You never got home." or its notice |
| `test_the_last_call_points_back_once` | `tests/unit/test_story.gd` | once he has answered Rosnah, the last call plays the road's wind and engine by itself, once, with its crackle as a sound caption and Mei's line (caught) or Hafiz's (saved) as a story line; `alive` and no road have none |
| `test_the_last_call_waits_for_rosnah_to_finish` | `tests/unit/test_story.gd` | no wind or engine over Rosnah's voice or her last line; a press meanwhile only shows the log, and the call plays by itself when her call is done |
| `test_the_last_call_plays_by_itself_wherever_he_is` | `tests/unit/test_story.gd` | he walks out of the entrance during her call: it plays once when she is done; a later press shows the log and plays nothing again |
| `test_the_last_call_waits_for_a_knock` | `tests/unit/test_story.gd` | a knock that starts as her call ends holds the last call until it is done |
| `test_a_pending_last_call_never_plays_after_an_ending` | `tests/unit/test_story.gd` | a pending last call does not play once the story has ended |
| `test_a_road_without_a_last_call_never_leaves_one_pending` | `tests/unit/test_story.gd` | roads `alive` and none: pressing the intercom during and after her call never plays a last call or its crackle |
| `test_his_recognition_of_his_own_voice_is_a_story_line` | `tests/unit/test_story.gd` | "[It's your voice.]" goes out as a story line, shown with "Captions for sounds" off, not as a sound caption |
| `test_after_the_road_he_washes_the_mountain_off_and_cannot_remember_getting_home` | `tests/unit/test_story.gd` | After each road: the road's objective, red earth at the sink, and lying down the road's last memory (the stall's bulb or the lorry) before the lift |
| `test_the_choice_opens_only_after_the_call_and_the_call_follows_the_road` | `tests/unit/test_story.gd` | In B-11-07 the wall and the lift do nothing until the call is answered or 40 s pass; then the answer-or-don't prompts, Bang Din's rule after a road, and Hafiz's voice after `saved`, his own otherwise |
| `test_the_quiet_starts_on_the_first_tick_whatever_came_first` | `tests/unit/test_story.gd` | road `caught`, F10 before the first tick: the quiet still ends 20 s after that tick |

## Builds

`tools/smoke.sh` (after `tools/export.sh`) first checks `index.pck` against the 9936 KiB cap (exit 1 above it),
then starts the exported macOS app with `-- --smoke` and the web build with `?smoke` in Chromium and WebKit. The game starts on the road,
which plays 3 s and prints `ROAD-SMOKE ok` (it started, the player's camera is current and the road's clock ran past 2 s), then hands over to the flat. The flat plays 3 s and prints `SMOKE ok` only if all
8 event definitions loaded from the exported pack, time is running, the story is at its first beat, and
the shader warm-up gave back the player's camera and the real light states. It also saves a screenshot. Both lines must be ok, the road's first, except with `--flat` (`tools/smoke.sh --flat`,
`web_smoke.mjs --flat`), which skips the road and checks the flat alone.
Windows and Linux builds are not checked (no machine). `-- --perf` / `?perf` is the performance tour,
see [performance.md](performance.md).

## Manual checks (need a window)

* The road's stills: `GODOT=<Godot 4.7.2> tools/road_stills.sh <dir>` renders 46 of them at 1920×1080 and a contact sheet.
  Look at each at full size against the four anti-goals (a ghost that looks fake, cheap jump scares, not Malaysian
  enough, boring missions).
* The flat after the road: `"<Godot 4.7.2>" --path . --script res://tools/stills.gd -- --out=<dir> --road=caught`
  (needs a window; `alive` and `saved` too) shoots the stills with the red earth built. Look at `footprints.png`
  (from where he stands, towards the front door, phone light on) and `living.png`.
* The start card's text and its wrap at the window sizes players use.
* Mouse capture and release in a real window and in browsers (pointer lock), the pause menu by mouse.
  On the web, Esc leaves pointer lock and the menu opens within half a second; only the Resume click
  closes it, and a refused lock (Resume clicked within a second of leaving) reopens it.
* Lighting readability at default brightness; reduced-flashing option.
* A few minutes in real Safari (Playwright's WebKit can't measure a visible window for long here).
