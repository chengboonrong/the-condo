# Architecture

The Condo is split into a **deterministic simulation core** and a **presentation layer**.
The core decides *what happens*; the presentation layer decides *how it looks and sounds*.
The core never touches cameras, meshes or audio players, so it runs headless at any speed,
which is what makes seeded replays and simulated playthroughs possible.

```
             input / camera / physics                         simulation core (RefCounted, ticked)
┌──────────────────────────────────────┐  sample()   ┌───────────────────────────────────────────────┐
│ PlayerController ─ InteractionSystem │ ──────────▶ │ HorrorRuntime.step(dt)                        │
│ GameStage (visibility queries)       │ ◀────────── │  ├ BehaviorProfiler  (bounded scores)         │
│ ApartmentBuilder (graybox, doors,    │  queries    │  ├ EventScheduler    (lifecycle, locks)       │
│   lights, variants)                  │             │  ├ HorrorDirector    (utility scoring, 4 Hz)  │
│ AudioDirector, Silhouette, HUD, UI   │             │  ├ EntityController  (abstract FSM)           │
└──────────────────────────────────────┘             │  ├ RoomTransformer   (validated variant swaps)│
          ▲  listens                                 │  └ StoryDirector     (acts, objectives)       │
          │                                          └──────────────────────┬────────────────────────┘
          │            EventBus (typed signals)          mutates via methods│
          └───────────────────────────────────────────── WorldState ◀───────┘
```

## Modules

| Module | File | Kind | Responsibility |
|---|---|---|---|
| EventBus | `scripts/core/event_bus.gd` | autoload | Typed signals only. No logic. |
| WorldState | `scripts/core/world_state.gd` | autoload | Authoritative state: act, objective, flags, clues, player room, doors, lights, variants, entity, event history, ending. Mutated only through explicit methods, each of which emits on EventBus. `reset()` for tests. |
| Settings | `scripts/core/settings.gd` | autoload | Player options in `user://settings.cfg`. |
| ApartmentLayout | `scripts/world/apartment_layout.gd` | static data | Rooms, walls, doors, lights, anchors, variant areas. The builder, RoomGraph and the tests all read this one file. |
| RoomGraph | `scripts/world/room_graph.gd` | RefCounted | Room connectivity for any variant set: neighbours, BFS paths, reachability. |
| PlayerController | `scripts/player/player_controller.gd` | CharacterBody3D | Walk, sprint, crouch (with headroom check), mouse look, phone light, footsteps. `scripted_move` lets tests drive it. |
| InteractionSystem | `scripts/player/interaction_system.gd` | RayCast3D | 2.2 m reach. Anything with `get_prompt()` + `interact()` is interactable; an empty prompt means "not now". |
| HorrorEvent | `scripts/horror/horror_event.gd` | Resource | Event definition (id, intensity, cooldown, duration, act range, channels, behaviour weights) plus the `prepare / start / update / finish` hooks. Tuned values live in `resources/horror_events/*.tres`. |
| EventScheduler | `scripts/horror/event_scheduler.gd` | RefCounted | Lifecycle `IDLE → VALIDATED → RUNNING → COMPLETED / CANCELLED / FAILED`, cooldowns, channel locks, priority pre-emption, timeouts, queued story requests. |
| BehaviorProfiler | `scripts/horror/behavior_profiler.gd` | RefCounted | Turns 10 Hz player samples into bounded 0–1 signals (EMAs, decayed room time, last-8 outcome window). |
| HorrorDirector | `scripts/horror/horror_director.gd` | RefCounted | 4 Hz utility scoring of eligible events, tension model, recovery gaps, seeded pick, explainable decision log. |
| EntityController | `scripts/horror/entity_controller.gd` | RefCounted | Unseen presence: `dormant → observing → approaching → retreating`, located in a room of the RoomGraph. |
| RoomTransformer | `scripts/horror/room_transformer.gd` | RefCounted | Applies predefined variants only after the five safety checks pass. |
| StoryDirector | `scripts/story/story_director.gd` | RefCounted | Acts, objectives, dialogue, clues, fail-safes, endings. |
| HorrorRuntime | `scripts/horror/horror_runtime.gd` | Node | Composition root for the core; one seeded RNG; fixed tick order. |

## Determinism

* One `RandomNumberGenerator`, seeded once, shared by every core system in a fixed call order.
* The core advances only through `HorrorRuntime.step(dt)`, which reads the player through the
  `HorrorStage` (position, facing, speed, phone light). Given the same seed and the same sequence of
  stage states and interactions, the director makes the same decisions; a unit test replays a trace
  twice and compares the decision logs.
* Presentation randomness (flicker patterns, footstep variation) uses its own RNG and never feeds
  back into the core.

## Director

Every tick: time → `BehaviorProfiler` → `EntityController` → `EventScheduler` → `HorrorDirector`.

* **Behaviour signals** (0–1, sampled at 10 Hz): curiosity and avoidance (share of the last 8 sounds from
  another room that the player walked towards or away from), look-behind (sharp turns, decaying),
  hesitation (standing at a doorway), light dependence (time lit), idle (time still), and per-room
  avoidance from a decayed time-in-room (90 s half-life). They are behaviour proxies, not a fear measure.
* **Pacing.** Each event adds `intensity × 0.6` to tension, which decays (τ 40 s) while nothing runs.
  Each act has a target (act 2: 0.3, act 3: 0.5, act 4: 0.7). The director fires only below target, never
  while any event runs, and waits a recovery gap of 10–30 s that grows with tension.
* **Scoring** (4 Hz, only when it may fire): every adaptive event the scheduler would accept gets
  `base + behaviour + narrative + tension fit − repetition`. Behaviour is the event's weights × signals.
  Narrative is the act and entity-state bonuses. Tension fit is +1 when the event's intensity fills the
  gap to target. Repetition is 0.5 per use in the last five, plus 0.8 if it was the last one. One of the top
  three is drawn with the simulation RNG, weighted by score. Each pick is logged with its parts (F3).
* **Entity.** A room and a state, no body: dormant (act 1) → observing (two rooms away) →
  approaching (act 3+, one room closer every 12 s, never into the player's room) → retreating (when seen
  or walked in on, to the farthest room) → observing. Footsteps start from its room.

## Room shifts

`RoomTransformer` swaps an area (`ApartmentLayout.VARIANT_AREAS`) to a predefined variant only when all
five checks pass, in this order:

1. the player is outside every affected room (the area's rooms plus rooms that depend on the variant,
   e.g. the reveal also creates the gap and B-11-07);
2. none of the area's probe points is visible (`HorrorStage.can_see`: the camera and a ray in game);
3. every affected room that still exists afterwards is reachable from the player;
4. the player's spot is still inside a room afterwards, and that room still leads to the corridor;
5. every room in `required_rooms` (set by the story) stays reachable.

All shifts go through the `shift` event: the director flips small objects, and the story requests the
structural ones, which wait in the scheduler queue until the checks pass. Every shift resets the
clock to 11:47 PM.

Impossible-space sequence (tested with physics, `tests/integration/test_impossible_space.gd`):
in act 3 the bedroom window becomes a door once the player looks away. Behind it, a corridor that cannot
fit in the building leads to B-11-07, the flat downstairs. While the player is inside, the corridor grows
from 10 m to a 28 m loop, so the way back is longer.

## Story

`StoryDirector` runs inside the core tick, on simulation time. It is a list of beats; each beat has an
exit the player triggers and a fail-safe that fires if they don't, so a player who never acts still
reaches act 4, and both endings are only a choice away. Story events go through the scheduler as
`request()`s (priority 5 for hints, 10 for story, 20 for story-critical shifts), never around it.

| Act | Beat | Player exit | Fail-safe |
|---|---|---|---|
| 1 | `home` | wash at the sink, lie down → `in_bed` | the intercom rings after 150 s |
| 1 | `ringing` | answer the intercom (Rosnah's call) | unanswered after 90 s, the story goes on |
| 1 | `knocked` | touch the bedroom wall, or stay 15 s in the bedroom | the wall answers after 120 s; knocks repeat at 45 s |
| 2 | `disturbance` | 4 signs (clues + moved things noticed) and 240 s | act 3 at 420 s; a shift every 75 s at most |
| 3 | `front_door` | go to the front door | the reveal is requested after 60 s |
| 3 | `reveal_pending` | leave the bedroom, look away | every 30 s: knock at the front door if the player is in the bedroom, else shut the bedroom door |
| 3 | `revealed` / `in_gap` | through the new door, along the corridor to B-11-07 | knocks behind the door every 30 s |
| 4 | `decision` | knock back on the wall (*Downstairs*) or take the lift (*Vacant*) | after 210 s, waiting is a choice: *Downstairs* |

A shift that is already safe applies inside `scheduler.request()`, so a beat that waits for a shift
switches to its waiting beat *before* asking for it. Noticing a moved object puts it back
(`set_variant(..., is_shift = false)`), which counts as a sign and does not reset the clock.

The record of the simulated players (bots) is generated into `docs/playthroughs.md` by
`tools/playthroughs.gd`; `tests/integration/test_playthroughs.gd` checks it on three seeds.

## Visibility

Room swaps and silhouettes need "can the player see this point?". The core asks a `HorrorStage`:

* `HorrorStage` (base) answers from the room graph: a point is visible when its room is the
  player's room or adjacent through an opening or an open door. Simulated playthroughs use this.
* `GameStage` (in-game) checks the camera frustum and a physics ray from the camera to each probe point.

## Renderer

The project uses the **Compatibility** (OpenGL 3 / WebGL2) renderer so one project exports to the web
(itch.io) and to desktop. Avoid Forward+-only features: SDFGI, SSAO/SSIL, volumetric fog, decals.

## Collision layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | walls, floors, furniture, doors, interactables |
| 2 | player | the player capsule |

Room membership comes from `ApartmentLayout.room_at(position)` (a point-in-rect test against the
active variant's rects), not from Area3D triggers, so it is exact and identical in simulation.

## Deviations from the brief's repository layout

* `scripts/core/save_manager.gd` is not present. A 10–15 minute run does not need save slots;
  `Settings` persists options. Add a save manager if checkpoints become necessary.
* Room detection uses layout rects instead of Area3D triggers (see above).
* The graybox is built in code from `ApartmentLayout` by `ApartmentBuilder` rather than hand-placed
  in `.tscn` files, so geometry, the room graph and the tests cannot drift apart. Replacing the
  graybox with modelled rooms means swapping the builder's mesh calls, not the data.
* `scenes/corridor/` and `scenes/entities/` are folded into the builder and `scenes/main.tscn`.
* Story code lives in `scripts/story/` (not listed in the brief).

## References consulted

No third-party code or assets are used. Reviewed for approach only:

* Godot 4 docs: CharacterBody3D, AnimatableBody3D, RayCast3D, AudioStreamPlayer3D, `--headless`.
* MIT first-person controllers ([epergo/character-controller](https://github.com/epergo/character-controller),
  ColormaticStudios/quality-godot-first-person). Both are larger than needed (state machines, swim/fly);
  the controller here is a ~120-line CharacterBody3D written from the engine docs.
