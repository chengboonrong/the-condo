# Event catalogue

Definitions: `resources/horror_events/*.tres` (tuning) + `scripts/horror/events/*.gd` (behaviour).
All events run through `EventScheduler`:

```
IDLE ──check()──▶ VALIDATED ──begin()──▶ RUNNING ──▶ COMPLETED
  │ (reason)                               ├──────▶ CANCELLED  (pre-empted, cancel_id)
  ▼                                        └──────▶ FAILED     (run.failed, or timeout)
rejected / queued (story)
```

* **Preconditions.** Act range and cooldown (skipped for story requests), then the event's own
  `prepare()` (location, distance, visibility), then channel locks.
* **Mutual exclusion.** Runs sharing a channel never overlap. A higher priority pre-empts a lower one;
  equal or lower priority is rejected (adaptive) or queued (story). The pre-empted run's `finish()` restores
  the world first, then the new run is prepared again against what is actually there.
* **Priorities.** 0 adaptive (director) · 5 story hint · 10 story · 20 story-critical.
* **Timeouts.** `max(duration × 2, duration + 5)` seconds unless the request sets `timeout`. A timed-out run
  is FAILED and its `finish()` restores what it changed.
* **Story requests never drop.** `request()` retries queued runs every tick until they start; a story run
  that is pre-empted goes back to the front of the queue. The one exception: a request whose target
  already holds ("door_already_shut", "already_door") is done and leaves the queue. An unknown event id
  is an error, not a queued request.
* **Events load with `ResourceLoader.list_directory`**, which also works in exported packs (where the
  files are renamed `*.tres.remap`).
* **Debug keys** F5–F9 skip only the act gate; preconditions and cooldowns still apply.

| ID | Intensity | Cooldown | Duration | Channels | Location rule | State change | Adapts to |
|---|---|---|---|---|---|---|---|
| `knock_wall` | 0.35 | 25 s | 1.6 s | audio_major | Knock anchor ≤ 2 rooms away (floor knock if in the same room); weighted towards avoided rooms, and a curious player rarely hears it from the last knock's room again. `params.anchor` forces it. | none | curiosity, idle, room avoidance |
| `light_flicker` | 0.30 | 35 s | 2.2 s | lights, lights:<room> | The player's room, only if its light is on. | 35 %: the light goes out, only in rooms with a switch; a cut-short flicker shows the real light again | light dependence, hesitation |
| `door_slam` | 0.50 | 45 s | 1.2 s | door, door:<id> | A door of the player's room at least 1.8 m away; never the front, gap or mirror door (story only). Heard from the far side. | door shut/opened; restored (quietly) on cancel/fail unless the player is now within 1.8 m | hesitation, room avoidance |
| `footsteps` | 0.55 | 50 s | ≤ 7 s | audio_major | From the entity's room if ≤ 2 away, else a room ≤ 2 away; walks the room graph and stops at the player's doorway. | none | avoidance, idle |
| `silhouette` | 0.75 | 70 s | ≤ 4 s (still: 8 s) | visual | Silhouette anchor in or next to the player's room, ≥ 3.5 m away, out of view (prefers behind): no point of its body (feet, waist, head, sides) may be on screen. Vanishes 0.3 s after any of them is. Rarer, a still staging at a `"still"` anchor (≥ 5 m away), only when its light alone is on: its back turned, silent, it stays while watched and is gone once the player looks away; waits 8 s. | none | look-behind |
| `shift` | 0.20 | 40 s | 0.5 s | shift, shift:<area> | Adaptive: flips the shoes, the chair or the tap, never one the player can see or is next to (weighted towards avoided rooms). Story: `params.area` + `params.variant`, retried until safe. | the area's variant; resets the clock to 11:47 PM | curiosity, room avoidance |
| `visitor` | 0.30 | 900 s | ≤ 27 s | audio_major | Act 2 only. The front door shut, and the player in the entrance, living room or kitchen at least 2.5 m from it. The lift chimes down the corridor, 2.5 s later 16 footsteps come up it (quiet to louder, all below the knock's level) and stop outside the door, and two gaps break the strip of light under it for 15 s. Then the feet go without a sound. It ends early, the same way, if the front door opens or the player looks through the peephole: nobody is there, so peeking ends it. A story knock pre-empts it. | the feet under the door (`door_feet_requested`), always taken away when the run ends | idle, light dependence, curiosity |
| `phone_ring` | 0.10 | — | ≤ 90 s | phone | Story only. Rings every 3.6 s until `params.stop_flag` is set. | none | — |

The director's pacing and scoring, and the room-shift safety checks, are in
[architecture.md](architecture.md#director).

## Captions

Every event that makes a story-relevant sound also emits a caption ("[Three knocks from the bedroom]",
"[A door slams]", "[Footsteps, coming closer]", "[The lights buzz and flicker]", "[The intercom is ringing]").
The visitor's are "[A lift chimes down the corridor]", "[Footsteps in the corridor, coming closer]" and
"[The footsteps stop outside your door]". Nothing is captioned when the feet go: nothing is heard. Captions
can be turned off in settings; dialogue always shows.

## The road

The road's moments are not `HorrorEvent`s. They have no scheduler, scoring or cooldowns: `RoadDirector` runs five
missions in a fixed order and sends `EventBus.road_cue` for each one-off moment, in the order a player meets it. The
cue's effect on screen and in the speakers is in [architecture.md](architecture.md#signals-and-cues). The core is
deterministic, and a bot sees the same cues a player does.

| Cue | Mission | Sent when |
|---|---|---|
| `card_on`, `card_off` | 1 | the opening's black card goes up at once and is taken away 13 s in. Mission 5 sends `card_on` again for each ending's card |
| `lorry_passes` | 1 | 20 s of waiting at the stop (the wait counts only while he is at the stop) |
| `couple_stops` | 1 | the car that set off at 45 s of waiting has stopped at the stop (about 60 to 65 s in) |
| `seated` | 1 | he gets in |
| `slow_car_seen` | 2 | the car has slowed to the slow car's speed behind it |
| `indicator`, `overtake` | 2 | Hafiz is going to overtake: the indicator, then 2.5 s later the pull out |
| `her_glimpse` | 2 | he is back in his own lane after an overtake |
| `slow_car_ahead` | 2 | the same car is ahead again, 40 m on |
| `slow_car_gone` | 2 | after the third attempt it pulls into a lay-by |
| `mirror_on`, `mirror_off` | 3 | the mirror starts and stops showing the back seat |
| `fourth_glimpse` | 3 | he turned round to her |
| `brake`, `fourth_gone` | 3 | 2.5 s into the empty seat, as Mei breaks off |
| `lights_dying`, `crank` | 4 | the car dies on the long straight, then Hafiz tries the key twice |
| `hafiz_leaves` | 4 | 8 s into his going, once his two lines are over |
| `insects_stop` | 4 | 20 s after Hafiz has gone |
| `thump`, `her_on_roof` | 4 | three thumps on the roof, she lands at the first |
| `mei_reaches_door` | 4 | the voice outside has been answered, or not |
| `mei_door_cracked` | 4 | Mei was not stopped |
| `door_cracked` | 4 | he opened his door |
| `knock_window` | 4 | three knocks on Mei's window |
| `light_on` | 4 | 10 s after the knocks, when it has gone quiet |
| `get_out`, `her_behind` | 5 | he gets out and the walk begins |
| `mei_looks` | 5 | Mei was not held and looks back |
| `hafiz_at_stall` | 5 | `alive` is decided |
| `walk_over` | 5 | 4 m short of the light; in `caught`, where it is decided |
| `lorry_flagged` | 5 | `alive`: they are at the stall |
| `phone_rings`, `lorry_stops` | 5 | `saved`: they are at the stall, then 6.5 s later |
| `light_out` | 5 | `caught` is decided: 30 m short of the light |
| `her_catches_hafiz`, `her_comes` | 5 | `caught`: 6 s and 12.5 s after it |
| `rule_broken` | any | `break_rule` |

### When a rule breaks

A break always does three things, whatever the mission: it adds the rule's weight to the count that decides the ending,
it thickens the fog (the road's fog runs from density 0.035 to 0.11), and it brings her nearer (her glimpses come closer
and she follows closer on the walk). It sends `rule_broken`. What each mission adds:

| Mission | Rule (weight) | What else happens |
|---|---|---|
| 2 | `overtook` (1) | He says "Okay, hold tight! Potong!", the indicator ticks and the rev sounds, and the car goes round the slow car at 14 m/s in the other lane. She shows at the roadside (`her_glimpse`). About 20 s later the same car is ahead again, round a bend, and Mei says "Eh… isn't that the same car?". Hafiz asks again at once, not after a long follow. A kept rule costs a grumble and a long crawl on. |
| 3 | `turned_round` (1) | His own camera sees her for 0.3 s, in the seat beside him. |
| 3 | `counted_her` (1) | "Four." has Mei count heads aloud for 3 s ("Four meh? Wait, I count. One, two...") before she says "Three? Then who's sitting—". Any answer ends the same way: the car brakes and the seat in the mirror is empty and wet. |
| 4 | `opened_door` (2) | His door opens a hand's width and something slaps it shut. He cannot try again. |
| 4 | `answered` (1) | Nothing shows but the fog and her. Mei reaches for her door whatever he said. |
| 4 | `mei_opened` (1) | Mei's door opens a little and is slapped shut. |
| 5 | `looked_back` (3, at most twice) | Nothing shows but the fog and her, who is nearer behind them. |
| 5 | `mei_looked` (1) | Mei looks back for 2.5 s: "[Mei looks back.]". |

The count then decides the ending at the light: up to 2 `alive`, 3 to 6 `saved`, more `caught`.

No sound on the road is captioned. What anyone says or thinks (`line_requested`) always shows, whatever the captions
setting, and so does "[A sour smell, like vinegar.]" after her first glimpse.
