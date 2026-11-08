# Architecture

11:47PM is split into a **deterministic simulation core** and a **presentation layer**.
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
| EventBus | `scripts/core/event_bus.gd` | autoload | Typed signals only. No logic. Two are for the visitor: `door_feet_requested(shown: bool)` (the core shows or takes away the feet under the front door) and `peephole_requested(view: Camera3D)` (the peephole asks the HUD to look through it). Seven are for the road (see [The road](#the-road)). |
| WorldState | `scripts/core/world_state.gd` | autoload | Authoritative state: act, objective, flags, clues, player room, doors, lights, variants, entity, event history, ending. Mutated only through explicit methods, each of which emits on EventBus. `reset()` for tests. |
| Settings | `scripts/core/settings.gd` | autoload | Player options in `user://settings.cfg`. |
| Journey | `scripts/core/journey.gd` | autoload | Carries how the road ended into the flat, and sends a restart back to the road. See [The road](#the-road). |
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
| RoadDirector | `scripts/road/road_director.gd` | RefCounted | The road's core: runs five missions in order and keeps one weighted count of the rules he breaks. See [The road](#the-road). |
| RoadMain | `scripts/road/road_main.gd` | Node3D (`scenes/road.tscn`) | The road's composition root, and the game's first scene. |

## Determinism

* One `RandomNumberGenerator`, seeded once, shared by every core system in a fixed call order.
* The core advances only through `HorrorRuntime.step(dt)`, which reads the player through the
  `HorrorStage` (position, facing, speed, phone light). Given the same seed and the same sequence of
  stage states and interactions, the director makes the same decisions; a unit test replays a trace
  twice and compares the decision logs.
* Presentation randomness (flicker patterns, footstep variation) uses its own RNG and never feeds
  back into the core.
* Input from the presentation reaches the core inside the tick: a silhouette sighting is detected on the
  physics tick and applied at the start of the next `step()`, and so is a look through the peephole
  (`object_interacted(&"peephole")` marks the running visit "peeked").
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

After the road (`Journey.road_ending` is `alive`, `saved` or `caught`) the same beats run with a few changes: a quiet
opening with a question, the road's smell and look-back lines (always shown), and roof thumps in place of the bedroom
knocks. Once he has answered Rosnah, the last call plays by itself, once, for `caught` and `saved` (wind and an idling
engine, then Mei's or Hafiz's first line) when her lines are over, wherever he is and unless an ending has started; it
waits for any line or knock still going. Inspecting the intercom after her call only shows the log. `alive` has no
recording. The look-back line comes the first time he notices something a shift has moved. He is still lost: the
objective is to wash the mountain off and try to remember, the sink runs red earth, and lying down he remembers only
the road's end (the lorry's tailgate, or the stall's bulb going out), never getting home. In B-11-07 the call is his own
voice, or Hafiz's after `saved`. `StoryDirector.ending_card(ending, road)` gives the last card its
text: `caught` adds to or edits today's text, `saved` and `alive` have their own. With no road (the flat opened
directly) every line is as before.

In B-11-07 the two endings open only once the call is over and every line said, answered or not (unanswered, 40 s
on; `StoryDirector.choice_open()`): until then the wall is only cold and the lift is out of order. Then knocking back is answering it and the lift
is not answering, with Bang Din's rule as a thought after the road. Waiting out `DECISION_WAIT` still ends it.

The record of the simulated players (bots) is generated into `docs/playthroughs.md` by
`tools/playthroughs.gd`; `tests/integration/test_playthroughs.gd` checks it on three seeds.

## Captions

The HUD has two text lines at the bottom: the sound caption line (`_caption`) just above the subtitle line (`_subtitle`).
What goes on each depends on whether the text is spoken.

* **Spoken** is a `line_requested` text (someone says or thinks it), or a `subtitle_requested` text that begins with `"`.
  It goes on the subtitle line and always shows, whatever "Captions for sounds" says.
* **A sound caption** is any other `subtitle_requested` text. It goes on the caption line, and only with "Captions for
  sounds" on. A new caption replaces the one on the line, and each line has its own timer, so a sound caption never
  cuts a spoken line short.
* **Emitting.** A sound caption that comes with its sound is emitted on `subtitle_requested` at that moment: the
  events, the road's cues, `Her`, the wall's answer. It does not wait for the lines before it.
  `StoryDirector.say()` and `RoadDirector.say()` stay one queue, one text at a time, 0.3 s apart, in the order said:
  what is said there, a caption included, follows the lines before it. Narration needs that ("[The line goes dead.]"
  ends Rosnah's call). What he thinks, sees or recognises ("[It's your voice.]", "[The window is a door.]", the notice
  lines) is said as a story line (`say(text, seconds, true)`); only what describes a sound is a caption. The last call's
  crackle is said, though its sound plays in the same call: `_play_last_call` runs only once the queue is empty and no
  knock is running, so the crackle comes out on the next tick.

## The road

The game starts on the road down a mountain, and the flat follows it. The road has its own simulation core, built like
the flat's: headless, deterministic, and talking to the presentation only through `EventBus`. The design is in
`docs/superpowers/specs/2026-11-06-the-road-down-design.md`. The core is `scripts/road/road_director.gd`,
`road_mission.gd`, `road_stage.gd`, `road_layout.gd` and `missions/*`. All of them are `RefCounted` and touch no node.

### Scene order and Journey

* The project's main scene is `scenes/road.tscn` (`RoadMain`). It builds the road behind the start card, which carries
  the content warning (blood and gore, flickering lights, sudden sounds), the headphones line and the Esc line for
  reduced flashing and brightness. The flat's own scene, `scenes/main.tscn`, has the same card for when it opens first.
* When the core ends the road (`RoadDirector.end` emits `EventBus.road_ended`), `RoadMain.finish(ending)` calls
  `Journey.arrive(ending)`. `Journey` (an autoload) keeps it in `road_ending` (`&"alive"`, `&"saved"` or `&"caught"`;
  `&""` when the flat was opened directly) and changes to `scenes/main.tscn`. The change is deferred, because the call
  comes from inside the scene it replaces.
* The flat sees `road_ending != &""`: it shows a black card, "11:47 PM", while it builds, skips its start card and lets
  the card go over 1.5 s. The clock is 11:47 PM however the road ended. The flat runs the same beats after every road
  ending. `StoryDirector` reads `road_ending` for the quiet opening, the knocks and the last call, `ApartmentBuilder` for the
  footprints (flat red-earth quads from the front door, built only after the road), and the HUD for the ending
  cards (see [Story](#story)); separate flats for each ending (part 2) are not built.
* A restart (the pause menu's Restart, or a click on the flat's ending card) calls `Journey.restart()`, which clears
  `road_ending` and loads the road again. The game never restarts into the flat.
* `-- --flat` / `?flat`: the road hands straight over with `Journey.arrive(&"")`, so the flat shows its own start card
  (the flat's checks use it). `-- --mission=N` / `?mission=N`: the road starts at mission N, as if every earlier one was
  kept (`RoadDirector.start_at`); F10 in a debug build skips the current mission the same way. `-- --smoke` and
  `-- --perf` run the road first and then the flat.
* Tests and tools set `Journey.change_scenes = false` to see the state change without the scene change.

### The core

`RoadDirector` runs five `RoadMission`s in order and keeps one weighted count of the rules he breaks. It holds what the
presentation reads each frame: the ride (`car_s`, `car_speed`, `lane`, `seated`, `slow_gap`, `light_s`), `fog` and
`her_near` (both 0 to 1), `broken` (every broken rule, with its weight, time and mission) and `progress` (every beat
change). One seeded `rng`; no mission draws from it today.

* **Stage.** `RoadStage` says where he is and how far his head has turned from facing the way the car goes (or the walk
  goes): `relative_yaw`, in radians, positive to his left, wrapped to [−π, π], so a full turn of the mouse is facing
  forward again. `RoadGameStage` reads the player, against the car's forward while he rides and against the road while
  he walks, so a hairpin under a player who keeps still is never turning round. Bots set a `RoadStage` directly.
* **Missions** (`RoadMission`) have five hooks: `begin()`, `tick(delta) -> bool` (true when it is done),
  `set_up_skipped()` (the state this mission starts in as if every earlier one was kept, for `start_at`),
  `interacted(id)` (he used something) and `leave()` (clear the card, prompts and objective it put up). Missions never
  connect to `EventBus`: the director passes on `object_interacted` while the mission is current.
* **Tick order.** `step(delta)` does these in order:
  1. time (`WorldState.advance_time`; the clock reads 12:06 AM when the road starts);
  2. captions (`say()` queues lines; one shows at a time, 0.3 s apart);
  3. the open choice's timer, which closes it as silence when it runs out;
  4. the look rule (`watch_look`);
  5. the current mission (`begin()` once, then `tick`; when it is done it is left, the next starts, and after the last
     `end()` is called);
  6. the ride (the car speeds up and slows at 2.5 m/s², brakes in time for `stop_at`, and changes lane at 1.5 m/s).
* **Pausing.** The game steps the director only while he can play (on the road or reading a note), not on the start card
  or in the pause menu, so no timer runs and no rule breaks while paused, or when focus or pointer lock is lost.
* **Breaking a rule** (`break_rule(rule, weight)`) adds it to `broken`, raises `fog` and `her_near` by 0.12 × weight
  each (to at most 1) and sends the cue `rule_broken`. A rule breaks in three ways:
  * a choice (`ask(choice_id, options, seconds, keeps, rule, weight)`): one to three options, one open at a time,
    answered with the keys 1 to 3. The answers in `keeps` (and `-1`, silence, if listed) keep the rule; any other
    breaks it;
  * his look (`watch_look(rule, left, right, hold, weight, max_count)`): his look past `left` or `right` radians for
    `hold` seconds, at most `max_count` times, and it can break again only after it has come back within 0.8 rad of
    forward;
  * something he does (opening the car's door in Mission 4).

### Missions

Weights and what keeps each rule, as the code has them. "Silence" is the choice's timer running out. Every rule's
break also thickens the fog and brings her nearer, as above.

| # | Class | Beats | Rule (weight) | Choices (seconds) and their keeps |
|---|---|---|---|---|
| 1 | `LiftMission` | `opening` (his thoughts on a black card), `walk` (to the bus stop), `wait` (counts only at the stop: the lorry passes at 20 s, the couple's car comes at 45 s), `get_in` (he uses the car's rear door; 9 s of small talk) | none | none |
| 2 | `SlowCarMission` | `cruise`, `seen`; then for each of three attempts `follow`, `urge`, `ask` and either `kept` or `signal`, `pass`, `away`; then `lay_by`, `gone` | `overtook` (1 each, at most 3) | `overtake_1`, `overtake_2`, `overtake_3` (6 s): three options each; the first two keep the rule, the third and silence break it |
| 3 | `CountMission` | `quiet`, `asked`, `asked_again`, `counting`, `empty` | `turned_round` (1, once: his look past 2.2 rad to his left or 1.0 rad to his right for 0.4 s, watched only from Bang Din's reminder at 9 s: before it, turning costs nothing); `counted_her` (1) | `count` (6 s): "Three." and "Why you ask?" keep it, "Four." breaks it, silence keeps it; "Why you ask?" opens `count_again` (5 s): "Three." and silence keep it, "Four." breaks it |
| 4 | `StallMission` | `cruise`, `dying`, `cranking`, `hafiz_leaves`, `waiting`, `thumps`, `voice`, `mei`, `knocks`, `quiet`, `light` | `opened_door` (2, once: he uses his door before the light comes on); `answered` (1); `mei_opened` (1) | `answer_voice` (6 s): "Hafiz? That you?" breaks `answered`, "Stay quiet." and silence keep it; `stop_mei` (4 s): "Mei, don't. That's not him." keeps `mei_opened`, "Okay, open." and silence break it |
| 5 | `LightMission` | `get_out`, `walk`, then `alive`, `saved` or `caught` | `looked_back` (3, at most twice: his look past 1.9 rad either way for 0.25 s); `mei_looked` (1 each) | `mei_look_1` and `mei_look_2` (5 s), 30% and 65% of the way to the light: "Don't look. Hold my hand." keeps `mei_looked`, "Maybe it's him." and silence break it |

The most that can break is 17: 3 (overtakes), 2 (Mission 3), 4 (Mission 4) and 8 (Mission 5, where looking back counts
most).

* Mission 2: the same car is ahead again about 20 s after each overtake, round a bend. After the third attempt, kept or
  not, it pulls into a lay-by and goes dark. Each overtake sends `her_glimpse`.
* Mission 3: whatever he answers, Mei counts three for herself, Hafiz brakes and the seat in the mirror is empty and
  wet. Turning to her shows her to him for 0.3 s (`fourth_glimpse`). Then a thought says nobody speaks and Hafiz drives
  faster: Mission 4's cruise is 14 m/s (`StallMission.CRUISE_SPEED`, Mission 2's `PASS_SPEED`), 71 s to the car dying
  in the keeper bot where 9 m/s took 112 s. The car dies `roll_distance` short of `STOP_S` and rolls to a stop at
  2.25 m/s² (6.2 s from 14 m/s), as the ride lets it slow no faster than 2.5.
* Mission 4: opening his door cracks it a hand's width before something slaps it shut. If Mei is not stopped, her door
  does the same. The voice outside sounds like Hafiz's. Mei reaches for her door whatever he answers the voice.
* Mission 5: the light is 150 m on from where the car died. The walk is over 4 m short of it (`alive`, `saved`) or where
  the bulb dies (`caught`). Every beat is timed by the core, never by the presentation, because the bots play it with
  none. Each look back that counts sends `her_lunges` right after its `rule_broken` (`watch_look`'s cue): the scare.

### How the road ends

`outcome()` reads the weighted count: up to 2 is `alive` (`ALIVE_MAX`), 3 to 6 is `saved` (`SAVED_MAX`), above 6 is
`caught`. Two looks back make 6 on their own. `LightMission` decides it once, 30 m short of the light and once no
choice is open (`DECIDE`), then stops the look rule, so a rule broken after that changes nothing. That ending plays and
the road is over (`end(decided)`, which emits `road_ended` once):

* `alive`: Hafiz walks up to the bulb out of the fog below, torch on. The lorry he flagged down comes down behind them,
  slowly past them, and pulls up past the stall. She is gone. A black card says the lorry takes the three of them down.
* `saved`: nobody is at the stall but his phone, ringing on the table. A lorry pulls up behind the two of them. She is
  gone. A black card says the lorry takes the two of them down.
* `caught`: the bulb dies. Hafiz walks out of the fog ahead with his phone as a torch. She flies over the two of them
  and drops onto him, a dark pool spreads under him, his phone falls lit on the road, and Mei screams (a caption; no
  voice). Then she comes for the camera, and a black card cuts in the moment she reaches it, with no caption. The core
  ends the road 18.5 s after the decision as a backstop if the card is late.

### Signals and cues

The road adds seven signals to `EventBus` (`line_requested` sits among the presentation requests):

| Signal | Sent by | Heard by |
|---|---|---|
| `line_requested(text, seconds)` | `RoadDirector.say`; `Penanggal` (the vinegar smell); `Endings` (Mei's scream) | the HUD: a line someone says or thinks, always shown whatever the captions setting (sound captions use `subtitle_requested`) |
| `road_line(speaker, seconds)` | `RoadDirector.say`, for a named speaker (`&"hafiz"`, `&"mei"`) | `Couple`: they turn their heads |
| `choices_requested(choice_id, options)` | `RoadDirector.ask` | the HUD, through `RoadMain`: it shows the options as "[1] …" and nothing more |
| `choice_made(choice_id, index)` | the HUD on a key press (once per choice), or a bot | the director |
| `choices_closed(choice_id)` | the director, when it closes a choice (answered, silent or skipped) | the HUD, through `RoadMain` |
| `road_cue(cue)` | the director and the missions, for one-off moments | `RoadMain` and `Endings`; tests, bots and stills listen too |
| `road_ended(ending)` | `RoadDirector.end` | `RoadMain.finish`, which hands over to `Journey` |

Every cue, who sends it and what the presentation does (`RoadMain._on_cue` and `Endings._on_cue`). A cue with no
effect in the game is still sent: it marks a moment for the tests, the bots and the stills.

| Cue | Sent by | What the presentation does |
|---|---|---|
| `card_on`, `card_off` | Mission 1 (the opening card); Mission 5 (the endings' card) | the HUD's black card goes up, or fades over 1 s; `Endings` stops the phone and the lorry's diesel |
| `lorry_passes` | Mission 1, 20 s into the wait | the lorry passes in the other lane, with its sound |
| `couple_stops` | Mission 1, once the car that set off at 45 s has stopped at the stop (about 60 to 65 s in) | nothing: the car is the core's ride |
| `seated` | Mission 1, when he gets in | his door swings open and shut |
| `slow_car_seen`, `slow_car_ahead` | Mission 2 | nothing: the slow car follows the core's `slow_gap` |
| `indicator` | Mission 2, before an overtake | the indicator loop ticks |
| `overtake` | Mission 2 | the indicator stops, the rev sounds |
| `her_glimpse` | Mission 2, after an overtake | she shows at the roadside ahead, for 1.2 s at the most |
| `slow_car_gone` | Mission 2, after the third attempt | the slow car pulls into its lay-by and its lights go out |
| `mirror_on`, `mirror_off` | Mission 3 | the rear-view mirror starts and stops drawing |
| `fourth_glimpse` | Mission 3, when he turns to her | his own camera sees her for 0.3 s |
| `brake`, `fourth_gone` | Mission 3, at the end | `brake`: nothing (the core brakes the car); `fourth_gone`: the mirror shows her seat empty, and wet |
| `lights_dying` | Mission 4 | the car's lights die over 4 s, the engine sputters and its loop stops |
| `crank` | Mission 4, twice | the starter cranks |
| `hafiz_leaves` | Mission 4 | Hafiz gets out and walks off with his phone as a torch |
| `insects_stop` | Mission 4 | the insects' loop stops |
| `thump`, `her_on_roof` | Mission 4, three thumps; she lands at the first | the roof thump sounds and his view shakes a little; she hangs over the roof |
| `mei_reaches_door` | Mission 4, after he answers the voice | Mei turns to her door |
| `mei_door_cracked` | Mission 4, if he did not stop Mei | her door opens a little and is slapped shut: heard only |
| `door_cracked` | Mission 4, if he opens his door | his door opens a hand's width and is slapped shut |
| `knock_window` | Mission 4, three times | a knock on Mei's window |
| `light_on` | Mission 4, when it goes quiet | the fruit stall's bulb and the far light come on, Mei leans in to see it, she is gone from the roof |
| `get_out` | Mission 5 | his door swings, Mei's is heard, and Mei gets out and walks beside him |
| `her_behind` | Mission 5 | she follows him along the road, 18 m behind with no rule broken, 4 m at her nearest |
| `her_lunges` | Mission 5, each time a look back counts (at most twice) | she is right behind him: in his face where he looks, with the stinger, her shriek and "[She is right behind you.]"; half a second later she pulls back to where she follows |
| `mei_looks` | Mission 5, if he did not hold her hand | Mei looks back for 2.5 s |
| `hafiz_at_stall` | Mission 5, `alive` decided | `Endings`: Hafiz walks up to the stall |
| `walk_over` | Mission 5, 4 m short of the light (`caught`: where it is decided) | `Endings`: Mei stops where she is |
| `lorry_flagged` | Mission 5, `alive` | `Endings`: the lorry comes down behind them and pulls up past the stall, diesel idling; she is hidden |
| `phone_rings` | Mission 5, `saved` | `Endings`: the phone rings on the table, its screen and a small light on |
| `lorry_stops` | Mission 5, `saved` | `Endings`: a lorry pulls up behind them; she is hidden |
| `light_out` | Mission 5, `caught` | `Endings`: the bulb dies in 0.25 s and Hafiz walks out of the fog |
| `her_catches_hafiz` | Mission 5, `caught` | `Endings`: she flies over them and drops onto him |
| `her_comes` | Mission 5, `caught` | she comes for the camera |
| `rule_broken` | `break_rule` | nothing in the game; the bots and tests count them |

`RoadMain` also captions the cues whose sound carries the moment (`RoadMain.CAPTIONS`): `lorry_passes`, `lights_dying`,
`crank`, `door_cracked`, `mei_door_cracked`, `thump` and `knock_window` (one caption for each set), `lorry_stops` and
`overtake` ("[The engine roars.]", every time). Each `thump` after the first gets `THUMP_AGAIN` ("[It moves on the
roof.]") instead. `Her` captions her first wet flap behind him on the walk (`Penanggal.FLAP_CAPTION`, once, and never for
her flaps in her other places or the door's slap) and the look-back lunge ("[She is right behind you.]"). They go out on
`subtitle_requested`, as the flat's sound captions do, and the HUD shows them on the caption line, only with "Captions
for sounds" on (see [Captions](#captions)).

### What the presentation is

`RoadMain` builds these under itself and wires them to the director. Each frame it reads the director's state: it sets
the fog, places the car, seats him and drives the loops.

| Node | File | What it does |
|---|---|---|
| `Player` | `scripts/player/player_controller.gd` | The flat's controller. `sit(seat)` puts him in the car's rear left seat with no collision and only the look; `stand(at)` puts him back on the road. |
| `Hud` | `scripts/ui/hud.gd` | The flat's HUD, with the black card, the choices and the two caption lines (see [Captions](#captions)). |
| `RoadBuilder` | `scripts/road/road_builder.gd` | The road in code from `RoadLayout` (3,200 m, a constant 6% downhill: a tunnel, six switchbacks, a long straight), in 100 m chunks with a visibility range, with the signs, lamps, tunnel, resort wall, bus stop and the far light. `set_fog(director.fog)` runs from density 0.035 (no rule broken) to 0.11. |
| `Look` | `scripts/world/look.gd` | The flat's grade, held on `&"road"` (`grade_override`). |
| `Car` (`CarRig`) | `scripts/road/car_rig.gd` | The couple's hatchback: its seats, its rear left door (an interactable: `car_door` outside, `car_door_inside` once he is seated), Hafiz's door, headlights that die with the engine. It is solid only when it stands still or with him in it. |
| `Mirror` (on the car) | `scripts/road/mirror.gd` | The rear-view mirror and the fourth passenger. A 320×112 picture, 42° across (keeping the width), drawn only while the mirror is on. It is 42° across rather than the plan's 30° vertical so that his own seat stays out of it. Her own fill light lights layer 11 alone. Its camera uses the player camera's shaders: its environment keeps the colour adjustment switched on but neutral. |
| `Couple` (on the car) | `scripts/road/couple.gd` | Hafiz and Mei in the front seats, turning when they speak; Hafiz walks off and back, and Mei walks beside him. |
| `Lorry` | `scripts/road/lorry.gd` | Passes in Mission 1; in the endings it comes down the walkers' lane and pulls up, yielding to anyone in its way. |
| `SlowCar` | `scripts/road/slow_car.gd` | The slow car ahead, from the core's `slow_gap`, 1 m in from the lane's centre towards the line so that it shows past Mei's head. |
| `Audio` (`RoadAudio`) | `scripts/road/road_audio.gd` | A pool of eight positional players for `sound_requested`, the seven loops (`RoadAudio.LOOPS`), and `play_here`: one non-positional player for each sound played in his head (the look-back's stinger and her shriek). |
| `Her` (`Penanggal`) | `scripts/road/her.gd` | The penanggal. Hidden until called, in one place at a time: glimpsed at the roadside, on the car's roof, behind a walker, right behind him when he looks back (`lunge`), flying, catching someone, or coming for the camera. Her glimpse is 28 m ahead of the car with no rule broken, closing to 10 m by the time `her_near` reaches 0.4. Her sounds are wet, but for the look-back's sting. |
| `Endings` | `scripts/road/endings.gd` | The fruit stall, its bulb, the phones, Hafiz's walk and each ending's moments. |
| `PauseMenu` | `scripts/ui/pause_menu.gd` | The flat's, with its web guard for a lost pointer lock. |

* **Gore.** She is shown gory: the skull with its hair and wet skin, and her windpipe, lungs, heart, stomach and
  intestines hanging beneath it (`art/penanggal/`). In the `caught` ending a man is knocked down and a dark pool spreads
  under him (a shader in `her.gd`). Both stay out of every published image and the README, and the start card, the
  README and the itch page carry the warning (`docs/research/2026-11-06-gore-rules.md`).
* **The look-back.** On the walk she follows him (`behind`), and each look back that counts (`her_lunges`) is the
  game's jump-scare (`Penanggal.lunge`). In the same frame she is 0.45 m from his eyes to her skull's centre
  (`LUNGE_AT`), in the middle of his view whether he looks up or down (the look counts on his yaw alone, so where he
  looks outranks his eye height), upright and facing him: her head, crown to chin, fills 0.38 of his 72° view's height
  there (measured on the `lunge` still; at 0.5 m it was 0.33), so size wins over distance. The stinger and her shriek play in his head (`RoadAudio.play_here`, not positional, so at
  exactly their play levels) and "[She is right behind you.]" goes out on `subtitle_requested`.
  Through the hold she goes where he goes (his eyes' place plus her first offset, which does not turn with his view), so
  walking into her never takes his eyes inside her head. After 0.5 s (`LUNGE_HOLD`) she is `behind` again from where she
  is, and goes back to where she follows at 6 m/s; a second look back during it starts it over. It only ever happens from `behind`, so never after the endings move her.
  For it she carries her own fill: an unshadowed omni light off to her left, above her and a little in front, so her
  eyes stay in deep sockets and her right cheek in shadow; dim (0.5) and steady,
  that fades out as she goes back, by the share of the way left, and is off in every other place. Without it her
  face, with his phone light off (it starts off), is a black shape in the fog. It lights render layer 12 alone, which
  only her mesh is on. The warm-up's omni light draws her under it (an unshadowed omni light is one of its states).
* **Render layer 11** (see the layers table) is the mirror's alone: the fourth passenger and the wet patch she leaves.
  The mirror's camera draws it, the player's camera (cull mask 1047551) leaves it out, except for the 0.3 s glimpse.
  In the warm-up only, a picture of a viewport goes on layer 20 (`PICTURE_LAYER`) so the mirror's camera leaves it
  out: drawn into its own viewport it would read the texture it writes, which WebGL refuses.
* **Render layer 12** is hers (`Penanggal.LAYER`): her mesh is on it as well as layer 1, and her fill lights it alone,
  so it lights nothing else on the road.
* **Sounds.** The road's sounds go through `EventBus.sound_requested` like the flat's, but for the look-back's sting,
  which plays in his head (`RoadAudio.play_here`). The levels are in "Audio levels".
  The stall's sounds are played now: the lorry idling and braking, the phone ringing as a loop, her wet flap and drip.
* **Text.** He never speaks: his options are captions he chooses between. Every line is a caption: `Name: "…"`
  for what is said, `[…]` for a sound or a thought.

### The shader warm-up

No shader may compile mid-game. Behind the start card `RoadMain._compile_shaders` walks the whole road scene for every
`GeometryInstance3D`, hidden or not (her in the mirror, the signs' lines and the fourth passenger included), copies one
of each kind (class, shadow mode and materials) onto a board in front of a camera of its own, far above the road, and
draws it under every mix of the road's lights: an omni light, an unshadowed spot and a copy of his phone light, which
casts a shadow, in 12 states (`LIGHT_STATES`), one frame each. The mirror's camera draws the board each time as well,
because its picture has no shadow maps and a pass of its own. `warmed_materials()` lists what was drawn, and
`test_every_road_material_is_warmed` checks that every material under the road is in it.

A new material is warmed because the walk finds it, if it exists when the walk runs. What is made after the card is
clicked is not.

### Bots, stills and tools

* `tests/sim/road_playthrough.gd` (`RoadPlaythrough`) plays the core headless with a `RoadStage`: three bots, on seeds
  1147, 7 and 2026. `keeper` keeps every rule and ends `alive` with score 0, `wobbly` ends `saved` with 4 and `breaker`
  ends `caught` with 16. They are bots, not people. The keeper reaches `alive` at 538 s of sim time (9.0 minutes; the test accepts 7 to 15
  minutes) on all three seeds. That is a lower bound for a person, because the bot answers in a second and walks
  straight, and it is not a playtest.
* `tools/road_stills.sh <dir>` renders 49 stills of the road, one PNG per shot, and a contact sheet. Each starts its
  mission as `--mission` does and the simulation stands still. Stills made for checking stay out of the repository.
* `-- --perf` runs `RoadPerf`, about 49 s through the road's heaviest moments, before the flat's tour
  ([performance.md](performance.md)).

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
tudung saji on the table, the corridor light under the front door. The flat shows no blood, no red fog and no chromatic
aberration: the fear comes from the place being ordinary. The road before it is the exception: it shows the penanggal
gory, and blood (see [The road](#the-road) and `docs/research/2026-11-06-gore-rules.md`).

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
* **The feet** are what is missing from the light under the front door. `Decor` draws that strip twice, sharing
  one additive material: `door_leak`, whole, and `door_leak_feet`, with two soft-edged gaps centred at x = 1.31 and
  1.65, each dark over 0.16 m and back to full strength 0.04 m either side. `EventBus.door_feet_requested` swaps
  one for the other while the front door is shut, and an open door hides both. They are gaps, not a texture, so
  they are as faint as the strip: in the `door_feet` still (from 2.9 m in the living room, 1920×1080) they show as
  two dark breaks that split the strip into three short lit pieces, a small, faint feature at the foot of the
  dark door rather than an obvious pair of feet.
* **The peephole view**: the `Peephole` on the front door's inside face owns a `Camera3D` (field of view 140)
  just outside the door, facing the corridor. Looking through it makes that camera current and shows the lens, an
  inline `canvas_item` shader (`Hud.LENS_SHADER`) that reads the screen, bends it like a fisheye (it follows
  `view.fov`) and cuts it to a round black mask. The lens is drawn under the film, so the grain stays fine; "[E] step back"
  is drawn over it. The player is held and time keeps running, as for a note; E or Esc steps back, and so
  does the front door opening. It offers nothing while the door is open or still swinging shut (its prompt is empty,
  which is how `InteractionSystem` skips an object). The lens is drawn once behind the start card (`Hud.set_lens`), so it never compiles
  mid-game.
* **The figure** is an ordinary person in dim colours (brown skin, a grey work T-shirt, dark trousers, from a 16 x 4
  palette texture), standing too still with its weight on one leg, and wears a mamak apron like the one drying on the
  rack. A soft shadow under its feet is part of its body mesh, so it fades with it and needs no light of its own.
* **Objects are Blender models**, one folder per model: `art/<id>/build.py` builds it and bakes its textures in
  Blender, and exports `assets/models/<id>.glb`; `tools/models.sh <ids>` rebuilds and imports them. The ids are
  `apron_hung`, `basin`, `bed`, `ceiling_fan`, `dining_chair`, `dining_table`, `figure`, `fridge`, `front_door`,
  `intercom`, `shoe_rack`, `tap_water`, `tv_cabinet`, `wall_clock` and `work_shoes` for the flat, and `fourth`,
  `fruit_stall`, `hafiz_seated`, `hafiz_standing`, `hatchback`, `mei_seated`, `mei_standing`, `old_sedan` and
  `penanggal` for the road. No model borrows a file (there is no `art/*/vendor/`, so no credits list); the one
  outside source is the Inter font, see References consulted.
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

Measured from the files (`assets/audio/`, the loudest 100 ms) plus the volume each is played at. "Heard at" is the
level 3 m from him, the players' unit size, where distance adds and takes away nothing. Scares sit at the top, the
player's own noise near the bottom, beds underneath.

Closer than 3 m a sound gets louder, but not without limit: `AudioStreamPlayer3D` holds its played level plus the gain
from being close to `max_db`, which is +3 dB, and that cap applies after the played level. So a sound played at 0 dB
within about 1 m of his head is heard at its file level + 3 dB, whatever the table's arithmetic says. A sound placed at
his camera, as the lorry passing and the rev are, is at distance 0, so it is capped whatever it is played at, for as
long as it stays there: the rev does not (see the key sounds, below). Rows marked † are those: the roof thump (0.4 m
from his head), the window knock and the car doors (Mei's door and window are 1.2 m away; his own door is beside him),
the lorry passing, the rev and the engine dying (2.35 m from his seat, where +1 reaches the cap). Their "Heard at" is
file + 3 dB, worked out from that rule. The knocks after the intercom's call are † too: at +8 the cap holds to 5.3 m,
so at 3 m they are at it, but they are played at +8 only from the front door, 9.6 m and more away (see the key sounds).
Her breath is the same when she comes to his face (0.6 m), and so is the wet
flap that is heard at Mei's door when it is slapped shut. The flat's rows were not re-checked against this. Measured in
this build (headless, from the master bus), a positional player is also 3 dB under a non-positional one played at the
same level, its power shared between the ears, so one held at the cap is heard at file + 0 dB against the loops and
`play_here`; the table leaves this out.

| Sound | File | Played at | Heard at |
|---|---|---|---|
| Stinger (silhouette seen) | −8.8 dB | 0 dB | −8.8 dB |
| Intercom ring | −8.2 | −2 | −10.2 |
| Lift ding (ending) | −10.7 | 0 | −10.7 |
| Door opening by itself (event) | −6.9 | −4 | −10.9 |
| Knock or thump ×3 after the intercom's call, while he is at the front door (story) † | −14.7 / −14.6 | +8 | −11.7 / −11.6 |
| Door slam | −11.8 | 0 | −11.8 |
| Knock ×3 (story) | −14.7 | +2 / +3 | −12.7 / −11.7 |
| Thump ×3 (the bedroom wall and the knock back at DOWNSTAIRS, after the road) | −14.6 | +2 / 0 (the beacon) | −12.6 / −14.6 |
| Hatchback revving for the overtake (the road) † | −14.6 | +3 (see the key sounds, below) | −11.6, less as the car pulls away |
| Car door shut (the road) † | −17.0 | 0 | −14.0 |
| Lorry passing in the other lane (the road) † | −17.0 | 0 (no effect: see †) | −14.0 |
| Engine dying (the road) † | −17.0 | +1 | −14.0, less as the car rolls on |
| Knock ×1 (the wall answers) | −14.6 | 0 | −14.6 |
| Thump ×1 (the wall answers, after the road) | −14.6 | 0 | −14.6 |
| Roof thump ×3 (the road, something lands on the car) † | −18.5 | 0 | −15.5 |
| Knock on the car window ×3 (the road) † | −19.0 | 0 | −16.0 |
| Spoken lines: Hafiz and Mei (the HUD's `voice`, not positional; `scripts/ui/voices.gd`) | −15.5 to −15.3 | 0 | −15.5 to −15.3 |
| Stinger, as he looks back and she is right behind him (the road, in his head) ‡ | −8.5 | −8 | −16.5 |
| Her shriek, with it (the road, in his head) ‡ | −14.6 | −2 | −16.6 |
| Light buzz (flicker) | −10.8 | −6 | −16.8 |
| His answers; the intercom's voices (Rosnah, his own, the last call); the voice outside the car | −16.7 to −16.3 | 0 | −16.7 to −16.3 |
| The voice behind him on the walk (the road) | −17.4 | 0 | −17.4 |
| Door opening (the player) | −6.9 | −11 | −17.9 |
| Phone ringing on the table (the road, loop: one ring) | −19.0 | 0 | −19.0 |
| Car door opened (the road) † | −23.0 | 0 | −20.0 |
| Door closing | −20.6 | 0 | −20.6 |
| Lorry's air brakes as it pulls up (the road) | −21.0 | 0 | −21.0 |
| Starter cranking ×2 (the road) | −19.0 | −2 | −21.0 |
| Intercom's last call, wind and the idling engine (after the road) | −22.0 | 0 | −22.0 |
| Bang Din, remembered (an echo) | −21.4 | 0 | −21.4 |
| Her wet flap behind him on the walk (the road) | −27.0 | +4 | −23.0 |
| Lorry's diesel idling (the road, loop: 60 firings) | −20.0 | −4 | −24.0 |
| Footsteps that aren't yours | −19.8 to −15.9 | −10 → −2 | −30 to −18, getting closer |
| Your footsteps (walk / sprint / crouch) | −19.8 to −15.9 | −15 / −10 / −22 | about −33 / −28 / −40 |
| Your footsteps on asphalt (the road: walk / sprint / crouch) | −20.7 to −17.8 | −15 / −10 / −22 | about −34 / −29 / −41 |
| Light switch, phone light | −24 (RMS) | −8 / −18 | −32 / −42 |
| Her wet flap elsewhere, her breath (the road) | −27.0 | 0 | −27.0 |
| Her drip (the road) | −28.0 | 0 | −28.0 |
| Tap running (loop) | −19.4 | −8 | −27.4 |
| Indicator (the road, loop: one flash) | −24.0 | −5 | −29.0 |
| Hatchback engine from the back seat (loop, pitch 0.7× to 1.6× with speed) | −16.0 | −13.5 (−19.5 from the signal to the rev's end) | −29.5 (−35.5) |
| Slow car's old engine (loop) | −20.0 | −12 | −32.0 |
| Night insects (loop, stop when the car dies; windows up in the car) | −27.0 | −6 / −12 seated | −33.0 / −39.0 |
| Corridor hum (loop) | −14.7 | −20 | −34.7 |
| Ceiling fan (loop) | −17.3 | −18.5 | −35.8 |
| Fridge (loop) | −11.9 | −26 | −37.9 |
| Neighbour's TV through the wall (loop) | −17.5 | −22.5 | −40 |
| Drone (loop, rises with tension) | −13.8 | −30 → −12 | −44 → −26 |
| Night wind (the road, loop, all night and on when the insects stop; windows up in the car) | −24.0 | −24 / −30 seated | −48.0 / −54.0 |

The rows marked "the road" are the road down's sounds (`tools/gen_audio.py` prints each file's level as it makes it).
Their file levels are measured from the files. "Played at" is what the game plays them at, and all of them are played
now: the engine (seated; outside it falls off as 1/distance), the insects, the wind, the car doors, the lorry passing in
Mission 1 and, in the endings, its diesel idling (falling off past 6 m) and its air brakes as it pulls up, the asphalt
steps, the slow car's old engine (from 10 m away it falls off as 1/distance, and its pitch drops as it stops), the
indicator (while Hafiz signals), the rev (as he pulls out), the stall's sounds (the engine sputtering as the car dies,
the starter cranking twice, the thump on the roof, the knocks on Mei's window and the slap of her door), her wet flap,
drip and breath (from where she is, falling off past 3 m), and, in one ending, the phone ringing on the fruit stall's
table as a loop (falling off past 3 m). Their "Heard at" is that level's result, not a measurement of the game. At 3 m none is louder
than the single knock (−14.6) and none is a sting, but for the look-back's (‡, below). Close to his head the † rows pass it: the rev (−11.6) is 3.0 dB over
it, and his car door, the lorry passing and the engine dying (−14.0) 0.6 dB, while the roof thump (−15.5) and the
window knock (−16.0) stay under it. Seven of them are seamless loops, imported with `edit/loop_mode=2` and only ever started and stopped with `RoadAudio.set_loop`: the four `_loop` files, the
indicator (one flash, 0.667 s, 90 flashes a minute), the phone (one ring, 2.1 s, ending in a pause) and the lorry's idle
(2 s). The rest play once. Eleven of them (both engine loops, the wind, the rev, the lorry passing, idling and braking,
the sputter, the crank, her breath and the phone) are saved at 22.05 kHz, because the pack is charged by the second of
audio: at 44.1 kHz less than 0.05% of the power of all but the lorry is above 8 kHz, and the lorry loses about 1.3% of
its power above 11 kHz (its tyre hiss). The insects are saved at 44.1 kHz because 13% of their power is above 11 kHz.

The rows marked ‡ are the look-back's sting (`Penanggal.lunge`): the flat's stinger and her shriek (`shriek()` in
`tools/gen_audio.py`: a woman's voice torn high and rough, 0.8 s at 44.1 kHz, 0.7% of its power above 8 kHz, saved at
the knock's −14.6). They are played together in his head with `RoadAudio.play_here`, one non-positional player each,
so they are heard at exactly file + play level and the +3 dB cap never applies. Their play levels are set by their
peaks, not their loudness: in the real-play recording at the master volume as shipped (0.8, −1.94 dB on bus 0) nothing
may peak above the loudest peak there now (−6.1 dBTP). The files peak at 0.800 (the stinger, −1.94 dBFS) and 0.325 (the
shriek, −9.78 dBFS). At −8 and −2 dB and then the master they peak at 0.255 (−11.88 dBFS) and 0.206 (−13.71 dBFS), and
the two peaks summed, as if they fell on the same sample, are 0.461: −6.73 dBFS, 0.63 dB under the limit. As mixed,
started together, the pair peaks at −7.13 dBFS. Their loudest 100 ms together is −13.8 dB before the master, so the
sting is the loudest sound of the walk by loudness (his steps on asphalt are about −34, her wet flap −27), not by peak.
The stinger's file level here is measured as `tools/gen_audio.py` measures the road's (its loudest 100 ms, −8.49); the
flat's row above has −8.8.

**The key sounds.** The real-play recording of 2026-11-07 had four key sounds under 10 dB over their beds (level: the
loudest 50 ms RMS from the cue to 2 s on; bed: the RMS of the second before it, so a duck counts only if it is already
in place then). Their levels now are set by mixing each moment in Godot itself, headless, from the master bus: the same
files and players, the beds as loops at their play levels, the camera moving as the car does. That mix put today's
three road moments within 0.2 to 0.8 dB of the recording, a little over it (5.6, 9.1 and 9.6 dB against 4.8, 8.7 and
9.4), so "Expected" takes that off. A peak is at the master (−1.94 dB): the sound's loudest sample as mixed, summed
with the loudest of each sound under it as if they all fell on one sample, against the limit of −6.1 dBFS. It holds
where each moment is heard; it is not a bound for every place, and for the thumps after the call it is gated (below).

| Key sound | Its levels | Bed, the second before | Recorded | Mixed now | Expected | Peak, summed |
|---|---|---|---|---|---|---|
| The rev at the overtake | file −14.6, played +3 | the engine (ducked 6 dB from the signal), the indicator (−5), the slow car | 4.8 | 13.9 to 14.6 | about 13 | −7.1 (−6.8 with the slow car close) |
| The engine dying | file −17.0, played +1 | the engine (now −13.5) | 8.7 | about 13.6 (12.1 at −18.5) | about 12.3 (10.8 in real play at −18.5) | about −6.5 in play (−8.0 dBTP at −18.5); about −5.0 as mixed, −4.8 if it were all to one side |
| Her wet flap behind him | played +4 (`Penanggal.BEHIND_DB`), 4.1 m from his eyes | his steps, and now the wind | 9.4 | 13.5 | about 13.3 | −9.7 |
| The bedroom's thumps after the call | played +8 (`StoryDirector.KNOCK_AT_CALL_DB`) while he is at the front door; heard by the intercom, 11.6 m away | the flat's room tone, unchanged | 7.0 | | 12.3 | −10.3 (−8.8 at the entrance's nearest point) |

* **The rev and the sputter** both play from a pool player that stays where it started, and the car leaves it. At the
  overtake the car pulls out at 4 m/s and speeds up at 2.5 m/s², so the rev is 5 m behind him by the file's loudest,
  1 s in: the cap no longer holds there and the play level counts (at +3 it is at the cap to 3 m). As it dies the car
  rolls on from 9 m/s (14 now, since Hafiz drives faster after the fourth passenger; not measured again), so the
  sputter passes his right shoulder 0.6 m off and falls behind. As heard, its loudest 50 ms
  and its loudest sample both come in its first half-second, at the cap, so past +1 the play level adds nothing and only
  the file can raise it. The file's own loudest 50 ms and sample are at 2.25 s (1.0 and 1.8 dB over the first
  half-second's), heard far behind the car; its loudest 100 ms, the table's measure, is at the start, so it is heard at
  −14.0. The rest of the margin is the bed: the engine loop, 1.5 dB lower all ride. At −18.5 the headless mix put its
  peak at −6.4 dBFS summed; the real-play recording (take 2, seed 1147) measured 10.8 dB over its bed and −8.0 dBTP,
  where the sputter passes ahead of and behind him, centred, not to one side. So the file is −17.0, 1.5 dB up: about
  12.3 dB and −6.5 dBTP in play. As mixed headless (about −5.0) and by the bound with it all to one side (−4.8) it is now
  over the −6.1 limit, by 1.1 and 1.3 dB; only the real play, with the sputter passing ahead of and behind him, keeps it
  under.
* **The rev's bed.** In the second before, the engine (−28.7 dB RMS at −12) and the indicator's ticks (−30.1 at 0)
  were about level, so ducking the engine alone stops at about 12 dB. The indicator at −5 does the rest. Its ticks
  peaked at −4.6 dBFS, −2.1 summed with what is under them; at −5, −9.6 and −6.3. `RoadMain.ROAR_DUCK` eases in over
  0.3 s from the signal (`indicator`, 2.5 s before the overtake), so it is in place 2.2 s before, and eases out over
  0.5 s from the rev's end, 1.9 s after it.
* **The thumps after the call.** The 7.0 dB recorded is the thumps with the bed under them, so alone they were
  10·log10(10^0.7 − 1) = 6.0 dB over it. 6 dB more makes 12.0, and 12.3 with the bed under them again. They are played
  at +8 only while he is at the front door (the entrance or the corridor, 9.6 m and more from that wall); anywhere else
  at +2, as the next try is and as both were before. The gate is read when the knock is requested, not when it plays: a
  story request is queued only behind a priority-10 `audio_major` event, which this beat never requests, so it plays at
  once in practice, and were it ever delayed the worst case is the pre-branch cap peak. Their peak here is a bound: the
  file's loudest sample (thump3 0.615, knock3 0.900 when the flat is opened directly) at the player's gain (+8 less
  20·log10(d/3), at most +3, then the fade to 30 m), all to one side (1 dB under a non-positional player), the master,
  and the flat's beds with the drone at full tension, as mixed at the intercom (0.130), summed. At the entrance's
  nearest point, 9.6 m, that is −8.8 dBFS (knock3 −6.5); at the intercom −10.3. At +8 every other room would pass the
  limit somewhere: the kitchen's nearest point (5.7 m) −4.4, the living room's (5.9 m) −4.7, the hallway's far end (6.9
  m) −6.07, and the bedroom, the bathroom and the hallway's bedroom side are within 5.3 m, at the cap. So −6.1 holds
  wherever +8 is played. At +2 near the wall it does not, as it never did: within 2.7 m of it a knock at +2 is at the
  cap, −2.6 dBFS summed for thump3, and knock3 reaches 0 dBFS.
* **The wind** (`wind_loop()`, 12 s at 22.05 kHz, its own `Random`) blows from the start of the road to its end, at −24
  outside and −30 seated, as the insects drop 6 dB, so nothing starts at the quiet. Its strongest second outside is
  −49.8 dB RMS (−52.6 on average): 8 dB under his steps (−41.9 RMS as mixed) and 10 dB under the insects (−39.6). It
  raises the flap's bed by 0.6 dB.

The rows marked "after the road" are the flat's own sounds that the road changes (`bridge_sounds()` in `tools/gen_audio.py`).
The thumps are `thump_roof`'s body at knock3's timing and the knock's level, so the story's bedroom knocks are the roof's
thumps; the front door's knocks stay knocks. The intercom's call is 3 s of wind and the road's engine through a 300 to
3400 Hz door speaker, saved at 22.05 kHz.

The three home beds stop one at a time, the TV when act 2 begins, the fridge 75 s into act 2 (or at act 3) and
the fan 15 s into act 3, fading over 1.5 s (the fan winds down over 3 s), and no sting marks it.

The "Heard at" levels compare like for like between the event sounds and the home beds: both use unit size 3,
so any distance moves them by the same amount. The corridor hum uses 2, the tap keeps Godot's default, and the
drone is not positional.

Every file peaks below 0 dBFS and nothing is played above +3 dB. Before this pass, opening a door
(−6.9 dB) was the loudest sound in the game, louder than the stinger and the slam.

## Collision and render layers

| Layer | Name | Used by |
|---|---|---|
| 1 | world | walls, floors, furniture, doors, interactables |
| 2 | player | the player capsule |

| Render layer | Used by |
|---|---|
| 1 | everything the player's camera draws (Godot's default) |
| 11 | mirror only: the road's fourth passenger and the wet patch she leaves (`Mirror`). The rear-view mirror's camera draws it; the player's camera (`scenes/player/player.tscn`, cull mask 1047551) leaves it out, except for her 0.3 s glimpse when he turns round to her. Her fill light lights layer 11 alone. |
| 12 | the penanggal (`Penanggal.LAYER`), on it as well as layer 1: her own fill at the look-back lights layer 12 alone, so it lights her and nothing else. Every camera draws it. |

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

## The road: invented names

The resort, the road and the roadside signs were checked before use (web and OpenStreetMap searches, and JKR's
sign manual, 2026-11-06). OpenStreetMap's place search (Nominatim) is fuzzy, so "0 hits"
means nothing close is in OSM, not proof that nobody uses the name. Google Maps and the SSM company register were
not searched.

| Name | What it is | What the search found |
|---|---|---|
| **Bukit Selubung** (used) | The resort at the top of the road ("selubung": a shroud, the hill under mist) | OSM: "Bukit Selubung", "Selubung", "Jalan Bukit Selubung", "Selubung Resort": 0 hits. Web: no page; only other hills (Bukit Selambau, Bukit Senaling). |
| **Jalan Lama Bukit Selubung** (used) | The old road down from it | Follows the real pattern of [Jalan Lama Bukit Putus](https://en.wikipedia.org/wiki/Jalan_Lama_Bukit_Putus) and Jalan Lama Gombak-Bentong. The exact name: OSM 0 hits, web 0 hits. |
| Bukit Sunyi (rejected) | Was the resort | OSM 0 hits and no resort or company, but it is literally "Silent Hill" in Malay, and the title of a 1988 album and song ([Malay Wikipedia, "Mus Barbarik"](https://ms.wikipedia.org/wiki/Mus_Barbarik)). Rejected for the Silent Hill echo. |
| Jalan Puncak Lama (rejected) | Was the road | No road of that name, but it is one word off *Jalan Puncak Alam*, a 2015 Malaysian horror film about a lonely road at night ([list of Malaysian films of 2015](https://en.wikipedia.org/wiki/List_of_Malaysian_films_of_2015)), and [Puncak Alam](https://en.wikipedia.org/wiki/Puncak_Alam) is a real Selangor township with roads such as Jalan Puncak Alam Jaya 1. Rejected. |

The signs say only what real Malaysian signs say (`RoadBuilder.SIGN_TEXTS`). The AWAS boards are red with white
text, every line on the same board; warning diamonds and the chevron boards on the switchbacks are black on yellow;
posts are banded black and white, as in the photographs (JKR's manual says orange and black).

| Text | Where on the road | What the search found |
|---|---|---|
| AWAS | The top line of every red board | JKR Arahan Teknik (Jalan) 2B/85, clause 2B.2.1 ("black symbols and borders on yellow background except for the signs AWAS...") and 3.8.2 ([copy on pdfcoffee](https://pdfcoffee.com/arahan-teknik-jalan-2b-85-traffic-signs-application-pdf-free.html)); [WD17](https://commons.wikimedia.org/wiki/File:Malaysia_road_sign_WD17.svg); red boards with white text in Selangor B23 photographs of 2025-01-25 ([photo C](https://commons.wikimedia.org/wiki/File:B23_%28Jalan_Hulu_Yam_Bharu%E2%80%93Batu_Caves%29,_Hulu_Selangor_20250125_122206.jpg), [photo D](https://commons.wikimedia.org/wiki/File:B23_%28Jalan_Sungai_Tua%29,_Gombak_20250125_120603.jpg)). |
| SELEKOH MERBAHAYA DI HADAPAN / 200 m / KURANGKAN LAJU | 200 m before switchback 1 | Photo C reads "AWAS / SELEKOH MERBAHAYA DI HADAPAN / 200 m / KURANGKAN LAJU". "MERBAHAYA" is how the boards print it (the standard spelling is "berbahaya"). |
| SELEKOH MERBAHAYA DI HADAPAN / KURANGKAN LAJU / 40 km/j | 200 m before switchback 4 | Photo D reads "AWAS / SELEKOH MERBAHAYA DI HADAPAN / KURANGKAN LAJU / 40 km/j". |
| KURANGKAN LAJU | Under AWAS | JKR 2B/85 clause 3.8.2 names it a supplementary sign; photos C and D. |
| KAWASAN TANAH RUNTUH / PANDU BERHATI-HATI | Under AWAS, by the cut slopes | ["Awas! Kawasan Tanah Runtuh / Pandu berhati-hati", Semporna-Kunak Road, Sabah, 2014-05-22](https://commons.wikimedia.org/wiki/File:Malaysia_Traffic-signs_Warning-sign-04b.jpg). |
| KAWASAN KEMALANGAN | Under AWAS, at the top of the long straight | Selangor B23 photo B, 2025-01-25; ["Kawasan Kemalangan" with "Kurangkan Laju", near Semporna, Sabah, 2014-05-21](https://commons.wikimedia.org/wiki/File:Malaysia_Traffic-signs_Danger-sign-01.jpg). |
| (chevron boards, no text) | Every 7 m round the outside of each switchback | JKR 2B/85 clause 3.3.4: "Chevron Delineator" WD.39a/b, black on yellow, on the outside of the curve about 6 m apart; [WD39a](https://commons.wikimedia.org/wiki/File:Malaysia_road_sign_WD39a.svg); [Genting Sempah, Federal Route 68, 2022-07-29](https://commons.wikimedia.org/wiki/File:Genting_Sempah_3.jpg). |
| (winding-road diamond, no text) | Before each stack of switchbacks | JKR 2B/85, Fig. 10 note 6: "use winding road sign if the road has many curve and turns such as those roads in hill areas". |
| ~~SELEKOH TAJAM~~ (dropped) | | Not in JKR's text, on Commons or in any photograph found; real boards say SELEKOH MERBAHAYA DI HADAPAN. |
| ~~GUNAKAN GEAR RENDAH~~ (dropped) | | Community-drawn diagrams on Commons only; no photograph or JKR text. |
| ~~DILARANG MEMOTONG~~ (dropped) | | The real sign is a red-ringed roundel with no text ([Ranau, 2014](https://commons.wikimedia.org/wiki/File:Malaysia_Traffic-signs_Regulatory-sign-09.jpg)); the text plate is only in drawings. |

## References consulted

No third-party code or asset files are used; the wall clock's numerals are rendered from Inter (SIL OFL 1.1), the
font bundled with Blender. Reviewed for approach only:

* Godot 4 docs: CharacterBody3D, AnimatableBody3D, RayCast3D, AudioStreamPlayer3D, `--headless`.
* MIT first-person controllers ([epergo/character-controller](https://github.com/epergo/character-controller),
  ColormaticStudios/quality-godot-first-person). Both are larger than needed (state machines, swim/fly);
  the controller here is a ~120-line CharacterBody3D written from the engine docs.
