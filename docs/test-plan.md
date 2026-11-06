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
| The road, unit | `tests/unit/test_road_director.gd`, `test_road_layout.gd`, `test_lift_mission.gd`, `test_slow_car_mission.gd`, `test_count_mission.gd`, `test_stall_mission.gd`, `test_light_mission.gd` | the road's core with no nodes: the weighted rule count and the outcome thresholds, the choices (one open at a time, silence) and the look rule, the road's data, and each mission's beats, cues and what breaks its rules |
| The road, in the scene | `tests/integration/test_journey.gd`, `test_ride.gd`, `test_couple.gd`, `test_her.gd`, `test_mirror.gd`, `test_slow_car.gd`, `test_stall.gd`, `test_endings.gd`, `test_road_builder.gd`, `test_road_warm_up.gd` | the road hands over to the flat at 11:47 and both restarts go back to the road; he rides in the car; the penanggal's places and that she never passes through the car; the mirror shows the fourth passenger only while Mission 3 has it on; the lights, the roof and the three endings; the road built in code; every material drawn once behind the start card |
| The road, simulated players | `tests/integration/test_road_playthroughs.gd` | three bots (`keeper`, `wobbly`, `breaker`, `tests/sim/road_playthrough.gd`) drive the road's core to `alive`, `saved` and `caught` on three seeds; same seed, same run |
| The road's HUD | `tests/integration/test_hud.gd` | the start card says "blood and gore" on the road and on the flat (`test_start_card_warns_of_gore`); a choice stays open until the core closes it, even paused; stray keys do nothing; the choices fit the screen; what people say shows with captions off |
| Unit (the flat) | `tests/unit/` | room graph, event eligibility, cooldowns, utility scoring, behaviour aggregation, tension decay, lifecycle transitions, seeded selection |
| Integration (the flat) | `tests/integration/` | doors, scheduling, world-state updates, room transformations, story progression, endings, a physics walk through every room |
| Story | `tests/unit/test_story.gd` | act 1–3 fail-safes with an idle player, the reveal never in front of the player, noticing moved things, both endings and the decision fail-safe |
| Simulated playthroughs | `tests/integration/test_playthroughs.gd` | Explorer, Avoider and Passive bots (`tests/sim/playthrough.gd`) driving the simulation core to an ending on three seeds; same seed, same run |

Simulated playthroughs are bots, not people. They are never reported as human playtests.
`godot --headless --path . --script res://tools/playthroughs.gd` rewrites `docs/playthroughs.md` with each
bot's event sequence, director scores, progression, completion, errors and warnings. The road's bots are checked by
`test_road_playthroughs.gd` and write no record: the keeper ends `alive` with score 0, the wobbly one `saved` with 4 and
the breaker `caught` with 16. The keeper's sim time (7 to 15 minutes) is a lower bound for a person, because the bot
answers in a second and walks straight.

## Builds

`tools/smoke.sh` (after `tools/export.sh`) first checks `index.pck` against the 8912 KiB cap (exit 1 above it),
then starts the exported macOS app with `-- --smoke` and the web build with `?smoke` in Chromium and WebKit. The game starts on the road,
which plays 3 s and prints `ROAD-SMOKE ok` (it started, the player's camera is current and the road's clock ran past 2 s), then hands over to the flat. The flat plays 3 s and prints `SMOKE ok` only if all
8 event definitions loaded from the exported pack, time is running, the story is at its first beat, and
the shader warm-up gave back the player's camera and the real light states. It also saves a screenshot. Both lines must be ok, the road's first, except with `--flat` (`tools/smoke.sh --flat`,
`web_smoke.mjs --flat`), which skips the road and checks the flat alone.
Windows and Linux builds are not checked (no machine). `-- --perf` / `?perf` is the performance tour,
see [performance.md](performance.md).

## Manual checks (need a window)

* The road's stills: `GODOT=<Godot 4.7.2> tools/road_stills.sh <dir>` renders 44 of them at 1920×1080 and a contact sheet.
  Look at each at full size against the four anti-goals (a ghost that looks fake, cheap jump scares, not Malaysian
  enough, boring missions).
* The start card's text and its wrap at the window sizes players use.

* Mouse capture and release in a real window and in browsers (pointer lock), the pause menu by mouse.
  On the web, Esc leaves pointer lock and the menu opens within half a second; only the Resume click
  closes it, and a refused lock (Resume clicked within a second of leaving) reopens it.
* Lighting readability at default brightness; reduced-flashing option.
* A few minutes in real Safari (Playwright's WebKit can't measure a visible window for long here).
