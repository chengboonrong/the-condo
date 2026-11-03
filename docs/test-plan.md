# Test plan

Run everything: `GODOT=/path/to/Godot tools/test.sh` (imports, then runs `tests/run_tests.gd`).
Filter: `tools/test.sh --filter=room_graph`. Exit code 0 means every test passed.

Test files extend `TestCase` (`tests/test_case.gd`). Methods named `test_*` must end with `return true`;
a method that hits a runtime error returns null and is reported as "did not finish". `WorldState` is reset
before every test.

## Levels

| Level | Where | Covers |
|---|---|---|
| Unit | `tests/unit/` | room graph, event eligibility, cooldowns, utility scoring, behaviour aggregation, tension decay, lifecycle transitions, seeded selection |
| Integration | `tests/integration/` | doors, scheduling, world-state updates, room transformations, story progression, endings, a physics walk through every room |
| Simulated playthroughs | `tests/integration/test_playthroughs.gd` | Explorer, Avoider and Passive bots driving the simulation core to an ending |

Simulated playthroughs are bots, not people. They are never reported as human playtests.

## Manual checks (need a window)

* Mouse capture and release, pause menu, settings.
* Lighting readability at default brightness; reduced-flashing option.
* Performance capture on real hardware (see the README's Performance section).
