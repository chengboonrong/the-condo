# Roadmap

Target: **GitHub Game Off 2026** (theme **SHIFT**). Submissions close **1 Dec 2026, 13:37 PST**.
The entry needs a public GitHub repository and an itch.io submission. Plan to submit on 30 Nov.

## Jam decisions (2026-11-04)

* **Platforms:** web (itch.io, in the browser) plus macOS and Windows downloads. The project uses the
  **Compatibility** renderer because Forward+ cannot export to the web. Keep every feature WebGL2-safe.
* **Theme:** the condo *shifting* is the core mechanic. Rooms and objects change only while unobserved,
  chosen by the Horror Director. The player has just come home from a night shift.
  Every shift also resets the clock to 11:47 PM (time shifts too).
* **Repository:** local only until the owner approves creating the public GitHub repo.

## Phases

| Phase | Branch | Week | Status |
|---|---|---|---|
| 0 — Technical foundation | `feat/project-foundation` | 1 (4–10 Nov) | done |
| 1 — Playable apartment | `feat/player-apartment` | 1 | done |
| 2 — Horror event framework | `feat/horror-event-system` | 1–2 | done |
| 3 — Adaptive Horror Director | `feat/adaptive-director` | 2 (11–17 Nov) | done |
| 4 — Environmental manipulation (shifts) | `feat/environmental-manipulation` | 2 | done |
| 5 — Narrative and endings | `feat/narrative` | 3 (18–24 Nov) | planned |
| 6 — Polish and release candidate | `feat/polish-release` | 4 (25 Nov–1 Dec) | planned |

Branches are stacked: each starts from the previous one. Nothing is merged into `main` without approval.

## Story outline

1. **The Complaint.** 11:47 PM, just home from a night shift. The intercom rings: Puan Rosnah from
   B-11-07, downstairs, complains about knocking. You have made no noise. Three knocks from the bedroom wall.
2. **The Disturbance.** Search the unit. Knocks, footsteps, doors and lights react to how you play.
   Small things shift while you aren't looking (shoes, a chair, the tap); noticing what moved is how
   the story advances, backed by clues (B-11-07 is vacant; the call came from your own unit).
   Every shift resets the clock to 11:47 PM.
3. **The Impossible Room.** A knock at the front door draws you away. When you come back, the bedroom
   window is a door. Behind it, a corridor that cannot exist leads to B-11-07.
4. **The Decision.** Inside B-11-07 the intercom rings again. Knock back three times (ending: *Downstairs*)
   or run, along a corridor that is now longer than before, to the lift (ending: *Vacant*).

## Known risks

* **Graphics and Audio are judged.** The graybox and the synthesised sounds are placeholders; week 4 has
  an art and audio pass using CC0 or self-made assets.
* **Web performance.** Shadows from several omni lights in WebGL2; measure the web build early (week 3).
