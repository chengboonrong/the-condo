# Roadmap

Target: **GitHub Game Off 2026** (theme **SHIFT**). Submissions close **1 Dec 2026, 13:37 PST**.
The entry needs a public GitHub repository and an itch.io submission. Plan to submit on 30 Nov.

## Jam decisions (2026-11-04)

* **Platforms:** web (itch.io, in the browser) plus macOS and Windows downloads. The project uses the
  **Compatibility** renderer because Forward+ cannot export to the web. Keep every feature WebGL2-safe.
* **Theme:** the condo *shifting* is the core mechanic. Rooms and objects change only while unobserved,
  chosen by the Horror Director. The player has just come home from a shift at the mamak on the corner.
  Every shift also resets the clock to 11:47 PM (time shifts too).
* **Repository:** public at <https://github.com/chengboonrong/the-condo>.

## Phases

| Phase | Branch | Week | Status |
|---|---|---|---|
| 0 — Technical foundation | `feat/project-foundation` | 1 (4–10 Nov) | done |
| 1 — Playable apartment | `feat/player-apartment` | 1 | done |
| 2 — Horror event framework | `feat/horror-event-system` | 1–2 | done |
| 3 — Adaptive Horror Director | `feat/adaptive-director` | 2 (11–17 Nov) | done |
| 4 — Environmental manipulation (shifts) | `feat/environmental-manipulation` | 2 | done |
| 5 — Narrative and endings | `feat/narrative` | 3 (18–24 Nov) | done |
| 6 — Polish and release candidate | `feat/polish-release` | 4 (25 Nov–1 Dec) | done; Windows and Linux builds not run |
| 7 — The road down, part 1 | `feat/the-road-down` | 1 | built: the road, five missions, the penanggal, three endings, then the flat. Part 2 (the alive and the dead flat) is not started; web measurements of the road are not run |

Branches are stacked: each starts from the previous one. Nothing is merged into `main` without approval.

## Story outline

0. **The Road Down.** The game now starts here, before the flat. 12:06 AM at a mountain resort above KL. The last staff
   bus has gone, and Bang Din at the stall, the older colleague, has told him the road down has rules. A couple, Hafiz
   and Mei, stop and give him a lift. He rides in the back seat and never drives. Five missions, each with rules to keep
   (one weighted count of the broken ones decides the ending): **the lift** (wait for the car), **the slow car**
   (follow it, never overtake, however long), **the extra passenger** (a fourth in the mirror: don't turn round, don't
   count her), **the car dies** (stay in, don't open the door, don't answer the voice) and **don't look back** (walk to
   the light and keep Mei from looking). A penanggal, a flying head with its insides hanging beneath it, follows the
   car. Breaking a rule costs something he can feel: thicker fog, her nearer, the same car ahead again. Three road
   endings: all three get down alive, he gets Mei out, or she catches Hafiz and comes for the two of them. Every one
   wakes him at home at 11:47 PM. Part 1 runs the flat unchanged after every road ending; part 2 will make it differ
   (see [architecture.md](architecture.md#the-road)).
1. **The Complaint.** 11:47 PM, just home from a shift at the mamak on the corner. Wash up, lie down (this walks the player
   past the shoes, the tap and the chair that will later move). The intercom rings: Puan Rosnah from
   B-11-07, downstairs, complains about knocking. You have made no noise. Knocks from the bedroom wall;
   touch it and something knocks back.
2. **The Disturbance.** Search the unit. Knocks, footsteps, doors and lights react to how you play.
   Small things shift while you aren't looking (shoes, a chair, the tap); noticing what moved is how
   the story advances, backed by clues (B-11-07 is vacant; the call came from your own unit). Four signs
   and four minutes move the story on (seven minutes at most).
   Every shift resets the clock to 11:47 PM.
3. **The Impossible Room.** A knock at the front door draws you away. When you come back, the bedroom
   window is a door. Behind it, a corridor that cannot exist leads to B-11-07.
4. **The Decision.** Inside B-11-07 the intercom rings again. Once the call is over, answer it by knocking back three
   times (ending: *Downstairs*), or don't: run, along a corridor that is now longer than before, to the lift (ending:
   *Vacant*).

## Known risks

* **Graphics and Audio are judged.** Phase 6 added night lighting, plaster walls and balanced sound
  levels; the detail pass added furniture, trim, fixtures, contact shadows and grain (see
  [architecture.md](architecture.md#look)). Everything is still built from boxes and cylinders in code,
  and every sound is synthesised.
* **The road's look.** The penanggal, the people and the road are judged against four things: a ghost that looks fake,
  cheap jump scares, not Malaysian enough, and boring missions. Its stills were looked at on 2026-11-06
  (`tools/road_stills.sh`); only bots have played the road, as far as the repository records. Its web performance is not
  measured (the desktop numbers are in [performance.md](performance.md#the-road)).
* **Gore on a public repository and itch.io.** Nothing either platform's text bans outright, but the wording is broad:
  see `docs/research/2026-11-06-gore-rules.md`. Two choices are the owner's at publish time.
* **Web performance on slower machines.** Measured only on an M1 Max (see
  [performance.md](performance.md)): 120 fps in Chromium, 60 fps in headless WebKit, no frame over 25 ms.
  The detail pass raised draw calls by about a third. Real Safari, integrated graphics and older GPUs are
  unmeasured.
