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
| Unit | `tests/unit/` | room graph, event eligibility, cooldowns, utility scoring, behaviour aggregation, tension decay, lifecycle transitions, seeded selection |
| Integration | `tests/integration/` | doors, scheduling, world-state updates, room transformations, story progression, endings, a physics walk through every room |
| Story | `tests/unit/test_story.gd` | act 1–3 fail-safes with an idle player, the reveal never in front of the player, noticing moved things, both endings and the decision fail-safe |
| Simulated playthroughs | `tests/integration/test_playthroughs.gd` | Explorer, Avoider and Passive bots (`tests/sim/playthrough.gd`) driving the simulation core to an ending on three seeds; same seed, same run |

Simulated playthroughs are bots, not people. They are never reported as human playtests.
`godot --headless --path . --script res://tools/playthroughs.gd` rewrites `docs/playthroughs.md` with each
bot's event sequence, director scores, progression, completion, errors and warnings.

## Builds

`tools/smoke.sh` (after `tools/export.sh`) starts the exported macOS app with `-- --smoke` and the web build
with `?smoke` in Chromium and WebKit. The game starts itself, plays 3 s and prints `SMOKE ok` only if all
7 event definitions loaded from the exported pack, time is running, the story is at its first beat, and
the shader warm-up gave back the player's camera and the real light states. It also saves a screenshot.
Windows and Linux builds are not checked (no machine). `-- --perf` / `?perf` is the performance tour,
see [performance.md](performance.md).

## Manual checks (need a window)

* Mouse capture and release in a real window and in browsers (pointer lock), the pause menu by mouse.
  On the web, Esc leaves pointer lock and the menu opens within half a second; only the Resume click
  closes it, and a refused lock (Resume clicked within a second of leaving) reopens it.
* Lighting readability at default brightness; reduced-flashing option.
* A few minutes in real Safari (Playwright's WebKit can't measure a visible window for long here).
