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
│ ApartmentBuilder (rooms, doors,      │  queries    │  ├ EventScheduler    (lifecycle, locks)       │
│   lights, variants) + Decor          │             │  ├ HorrorDirector    (utility scoring, 4 Hz)  │
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
* Input from the presentation reaches the core inside the tick: a silhouette sighting is detected on the
  physics tick and applied at the start of the next `step()`.
* The game steps the core only while the player is playing (or reading): not on the start card, while
  paused or after the ending, so pauses don't count as idle time or time spent in a room.

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

## Look

The aim is a real Malaysian condo at night, not generic horror: grilles on the windows and gates,
wall tiles to 1.8 m in the bathroom, laundry drying by the window, a gas cylinder at the end of the counter, a
tudung saji on the table, the corridor light under the front door. No blood, no red fog, no chromatic
aberration. The fear comes from the place being ordinary.

* `ApartmentBuilder` builds the structure (walls, floors, doors, lights) from `ApartmentLayout`;
  `Decor` (`scripts/world/decor.gd`) adds furniture, trim, door frames, window grilles and fixtures.
  `Decor` draws into one mesh per room and material, keeping the number of lights that reach a mesh
  small. The Compatibility renderer shades up to `rendering/limits/opengl/max_lights_per_object`
  unshadowed lights per mesh in the same pass and silently drops the rest, in pairing order, not the
  farthest. It pairs by bounding box (a cube for an omni light). With every lamp on and the gap at its
  longest, the long wall at x = 3 (bathroom, hallway, living room and kitchen) is reached by 10, so the limit is 10
  instead of the default 8 (`test_no_mesh_loses_a_light_with_every_lamp_on` checks before the reveal,
  after it and with the long gap). Only the phone light casts shadows; it draws what
  it reaches once more. The window's shadow atlas has 24-bit depth (`positional_shadow/atlas_16_bits` off;
  a SubViewport drawing the 3D would need the same): at Godot's default 16 bits the walls the phone light reaches
  shadow themselves in stripes a few metres away.
* **Contact shadows** without SSAO: soft quads under furniture and along the wall-floor and
  wall-ceiling edges, with a squared falloff texture. Unshaded, so lights don't touch them.
* **Light fittings** match the room: fluorescent tubes in the kitchen, bathroom and corridor, a light
  under the living room fan, a ceiling dome in the bedroom, downlights in the entrance and hallway, caged
  bulkheads in the gap, a bare bulb in B-11-07. Light colours follow them: cool tubes and fan light, warm
  downlights, dome and bulb.
* **Grain and vignette** are one full-screen `canvas_item` shader under the HUD text (`Hud.FILM_SHADER`).
  The vignette darkens grain and picture alike, so the corners don't fizz. The grain changes 24 times a
  second; its frame number wraps at 256, or float rounding turns it into a fixed tile after half an hour.
* **Soft filter** (`Look`, `scripts/world/look.gd`): the 3D view is drawn at a fraction of the window and
  scaled up with bilinear filtering, which softens it; the HUD is 2D, so it stays at full resolution. The
  scale is `1 / d`, where `d` is the window height divided by `Look.TARGET_LINES` (450), rounded, at least 1,
  and it follows the window (900 px: 2, 1440 px: 3, 2160 px: 5). So `d` is a whole number and the 3D view
  has `height / d` lines: 450 at 900 px, 360 at 720 px (the browser), 540 at 1080 px, and under 675 px `d`
  is 1 and the filter does nothing. `TARGET_LINES` only moves where those bands start and end (at 540,
  nothing changes at 900 or 1080 px, and the filter turns off between 675 and 809 px, which includes
  1280×720); it is not a sharpness knob. If legibility ever fails, the real options are full resolution
  below some minimum line count, or a fractional scale (0.6 at 900 px is 540 lines, with slightly uneven
  grain cells). The choice is the owner's. The Filter setting turns it off (`d = 1`). `-- --nofilter` /
  `?nofilter` does the same for one run; it is a developer flag, and if any setting is saved during that run,
  `filter = false` is saved with it. While the filter is on, the grain is snapped to 3D pixels (`pixel_size`
  in `Hud.FILM_SHADER`); off, it is per window pixel, as before.
* **Colour grade** (`Look`, `Look.GRADES`): the Environment's own adjustment (saturation, contrast and a
  two-point colour-correction ramp), no pass of the game's own. Act 1, at home after the shift, is a little warm and full
  (saturation 1.08, a creamy white); each later act is a step colder and greyer (0.62, 0.54, 0.46, with the
  white going bluer and the black lifted a touch); B-11-07 (`mirror_room`) is the greyest place in the game
  (0.34). The ending keeps act 4's grade. The grade follows `WorldState.act` and `WorldState.player_room`,
  polled each frame (`reset()` sets the act without a signal, and the room is set on the physics tick), and
  it eases over `Look.EASE_SECONDS` (4 s, smoothstep) from wherever it is, so it never cuts. A still grade
  writes nothing, so the ramp texture is not re-uploaded. `Look.settle()` jumps to the target at once (a new
  shift starts warm, and the stills call it per shot). The adjustment is switched on in `_ready()`, so the
  start card's warm-up compiles it and nothing compiles mid-game.
* **The figure** is shaded near-black and wears a mamak apron like the one drying on the rack.
* **Objects are Blender models**, one folder per model: `art/<id>/build.py` builds it and bakes its textures in
  Blender, and exports `assets/models/<id>.glb`; `tools/models.sh <ids>` rebuilds and imports them. The ids are
  `apron_hung`, `basin`, `bed`, `ceiling_fan`, `dining_chair`, `dining_table`, `figure`, `fridge`, `front_door`,
  `intercom`, `shoe_rack`, `tap_water`, `tv_cabinet`, `wall_clock` and `work_shoes`. No model borrows a file (there
  is no `art/*/vendor/`, so no credits list); the one outside source is the Inter font, see References consulted.
* **The trailer** is filmed in the game: `tools/trailer.gd` plays the shot list through the game's own state,
  signals and nodes and draws the cuts, black and cards itself, and `tools/trailer.sh` records it with Movie
  Maker at 1920×1080 (through a temporary `override.cfg`, removed afterwards), encodes it with ffmpeg at about
  −18 LUFS with light limiting, and checks it. The output is in `builds/trailer/`, which git ignores:
  `the-condo-trailer.mp4`, `report.txt` (ffprobe and loudness numbers), `sheet.png` (one frame per beat) and
  `render.log`. `tools/trailer.sh --encode-only` re-encodes from the kept `raw/` frames after a failed check.

Two rules keep the decor from breaking the game:

* `Decor.solid()` colliders are at most 0.3 m tall: the player's capsule meets them at its widest, so
  they still stop it, but they never hide a probe from `GameStage.can_see`, which uses physics rays (a
  tall table collider let the chair turn while the player watched it over the table).
  `test_furniture_never_hides_a_shift_probe` checks every probe from standing and crouching eye height.
* Nothing may show a material for the first time mid-game: the shader warm-up only compiles what it
  sees, under the lights it sees it under. No light, the ceiling lights, the phone light (shadowed) and both are
  four variants of every material, so a material that only a few objects use must be drawn under each
  (`Main._compile_shaders`). The blinking aircon LED therefore shares the material of the other indicator lights.

## Audio levels

Measured from the files (`assets/audio/`, the loudest 100 ms) plus the volume each is played at, before
distance attenuation. Scares sit at the top, the player's own noise near the bottom, beds underneath.

| Sound | File | Played at | Heard at |
|---|---|---|---|
| Stinger (silhouette seen) | −8.8 dB | 0 dB | −8.8 dB |
| Intercom ring | −8.2 | −2 | −10.2 |
| Lift ding (ending) | −10.7 | 0 | −10.7 |
| Door opening by itself (event) | −6.9 | −4 | −10.9 |
| Door slam | −11.8 | 0 | −11.8 |
| Knock ×3 (story) | −14.7 | +2 / +3 | −12.7 / −11.7 |
| Knock ×1 (the wall answers) | −14.6 | 0 | −14.6 |
| Light buzz (flicker) | −10.8 | −6 | −16.8 |
| Door opening (the player) | −6.9 | −11 | −17.9 |
| Door closing | −20.6 | 0 | −20.6 |
| Footsteps that aren't yours | −19.8 to −15.9 | −10 → −2 | −30 to −18, getting closer |
| Your footsteps (walk / sprint / crouch) | −19.8 to −15.9 | −15 / −10 / −22 | about −33 / −28 / −40 |
| Light switch, phone light | −24 (RMS) | −8 / −18 | −32 / −42 |
| Tap running (loop) | −19.4 | −8 | −27.4 |
| Corridor hum (loop) | −14.7 | −20 | −34.7 |
| Ceiling fan (loop) | −17.3 | −18.5 | −35.8 |
| Fridge (loop) | −11.9 | −26 | −37.9 |
| Neighbour's TV through the wall (loop) | −17.5 | −22.5 | −40 |
| Drone (loop, rises with tension) | −13.8 | −30 → −12 | −44 → −26 |

The three home beds stop one at a time, the TV when act 2 begins, the fridge 75 s into act 2 (or at act 3) and
the fan 15 s into act 3, fading over 1.5 s (the fan winds down over 3 s), and no sting marks it.

The "Heard at" levels compare like for like between the event sounds and the home beds: both use unit size 3,
so any distance moves them by the same amount. The corridor hum uses 2, the tap keeps Godot's default, and the
drone is not positional.

Every file peaks below 0 dBFS and nothing is played above +3 dB. Before this pass, opening a door
(−6.9 dB) was the loudest sound in the game, louder than the stinger and the slam.

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
* The condo is built in code from `ApartmentLayout` by `ApartmentBuilder` and `Decor` rather than
  hand-placed in `.tscn` files, so geometry, the room graph and the tests cannot drift apart. Replacing
  it with modelled rooms means swapping the mesh calls, not the data.
* `scenes/corridor/` and `scenes/entities/` are folded into the builder and `scenes/main.tscn`.
* Story code lives in `scripts/story/` (not listed in the brief).

## References consulted

No third-party code or asset files are used; the wall clock's numerals are rendered from Inter (SIL OFL 1.1), the
font bundled with Blender. Reviewed for approach only:

* Godot 4 docs: CharacterBody3D, AnimatableBody3D, RayCast3D, AudioStreamPlayer3D, `--headless`.
* MIT first-person controllers ([epergo/character-controller](https://github.com/epergo/character-controller),
  ColormaticStudios/quality-godot-first-person). Both are larger than needed (state machines, swim/fly);
  the controller here is a ~120-line CharacterBody3D written from the engine docs.
