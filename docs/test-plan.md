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
never the player's own.

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

## Manual checks (need a window)

* Mouse capture and release in a real window and in browsers (pointer lock), the pause menu by mouse.
* Lighting readability at default brightness; reduced-flashing option.
* Performance capture on real hardware (see the README's Performance section).
