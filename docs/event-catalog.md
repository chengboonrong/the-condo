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
| `phone_ring` | 0.10 | — | ≤ 90 s | phone | Story only. Rings every 3.6 s until `params.stop_flag` is set. | none | — |

The director's pacing and scoring, and the room-shift safety checks, are in
[architecture.md](architecture.md#director).

## Captions

Every event that makes a story-relevant sound also emits a caption ("[Three knocks from the bedroom]",
"[A door slams]", "[Footsteps, coming closer]", "[The lights buzz and flicker]", "[The intercom is ringing]").
Captions can be turned off in settings; dialogue always shows.
