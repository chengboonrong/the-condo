# Game over: design

Owner's ask (2026-11-09): "I doesn't feel any stress when I playing the game because I will never failed the game or
game over because of doing things slow or wrong, rectify it". The owner answered every question below. Each decision
says whether it is the owner's ("owner") or mine ("my call"). "Owner approved" marks a guess of mine that the owner
read and accepted.

## Why

Nothing in the game can stop you today:
- On the road, each broken rule adds to one weighted count (`RoadDirector.broken`, `score()`), and at the light that
  count picks one of three endings (`outcome()`: alive up to `ALIVE_MAX` 2, saved up to `SAVED_MAX` 6, caught above).
  Breaking a rule thickens the fog and brings her nearer (`fog`, `her_near`), but the ride always goes on.
- In the flat, every beat of `StoryDirector` has a fail-safe, so the story moves on whatever the player does.
- Choices that time out pick a default, and doing nothing is often the safe answer.

Because mistakes and being slow cost nothing, the player feels no pressure. The fix: his own mistakes and being too
slow kill him, and death sends him back to try that part again.

## Goals

### 1. His own mistakes kill him at once (owner)

Breaking one of his own rules kills him on the spot (owner: "Caught at once"). His rules are these (owner approved
list):

| Rule id | Mission | What he does |
|---|---|---|
| `turned_round` | 3, the extra passenger | turns round to look at her, once Bang Din's reminder is said |
| `counted_her` | 3 | answers "Four." when Mei counts (also after "Why you ask?") |
| `answered` | 4, the car dies | answers the voice outside ("Hafiz? That you?") |
| `opened_door` | 4 | opens his own door |
| `looked_back` | 5, the walk to the light | looks back in a way that counts (today: weight 3, at most twice) |

The death plays (goal 4), then GAME OVER, then he retries that mission (goal 5).

### 2. The others' mistakes still pick the ending (owner)

When he fails to stop Hafiz or Mei, they pay instead of him (owner: "Others pay"). These rules stay in the weighted
count, and the count still picks alive, saved or caught at the light:
- `overtook`: he lets Hafiz overtake the slow car (the third option or silence, up to 3 times);
- `mei_opened`: he doesn't stop Mei opening her door in the dead car;
- `mei_looked`: he doesn't stop Mei looking back on the walk (up to 2 times).

All three endings must stay reachable from these rules alone. Today they add up to at most 6 (3 + 1 + 2, all weight
1), which is `SAVED_MAX`, so "caught" could never happen. Re-weight them, or move the thresholds, so that:
- no mistake gives alive;
- some mistakes give saved;
- most of them give caught.

The exact weights are left to the builder (my call).

### 3. Being too slow kills him (owner)

These deaths are new. The owner picked all four on the road and three in the flat.

**On the road:**
- **Getting in the car** (mission 1). When the couple's car stops at the bus stop, he has about 10 s to get in.
  Longer, and they drive off and she takes him on the empty road.
- **The walk to the light** (mission 5). She follows behind him and Mei. The slower he walks, the closer she comes,
  and if he stands still for a few seconds she catches him. How her closing in is shown and heard is left to the
  builder, but it must be readable before it kills: he should feel her getting near.
- **Shorter clocks.** Every choice (`RoadDirector.ask`) gets about 3 s instead of today's 4–6 s. Where saying nothing
  *is* the rule ("Stay quiet." when the voice calls, or "Three." or nothing when Mei counts), silence stays safe on
  the shorter clock (owner approved). Where silence breaks an others' rule (Hafiz overtakes, Mei opens or looks),
  being slow now loses them more easily.
- **The dead car** (mission 4). When something lands on the roof (the `thumps` beat), he has a few seconds to lock
  the doors, or it gets in and kills him. This is a new interaction in the car: one prompt, "Lock the doors", locks
  every door (my call). Locking protects him only. Mei's wish to open her door stays a separate choice, which can
  still lose her (owner approved). Locking does not stop him opening his own door: that is still `opened_door` and
  still kills him (my call).

**In the flat:**
- **Face the sound** (owner, after the builder check). The thing in the flat (`EntityController`, the neighbour)
  has no body: it is only ever in a room next to his. Today it creeps towards him from act 3 and backs off when he
  walks into its room or sees its silhouette, or when it has been next to him for `HOLD_TIME`. Now:
  - when it reaches a room next to his, it gives itself away with a sound from that doorway (a creak or breathing,
    my call; made like the other sounds and within the audio limits);
  - if he turns and looks at that doorway within a few seconds, it backs off as it does today;
  - if he doesn't, it gets him.

  This runs from act 3 (when it creeps today) to the end. The first time it comes, a line tells him what to do, in
  the style of the flat's other story lines, for example "[Something is breathing in the doorway behind you. Face
  it.]" (my call). The timing and what counts as looking at the doorway are left to the builder. A player who turns
  to the sound when he hears it must survive.
- **Don't open the front door.** Opening it kills him in two cases:
  - while the visitor's feet are under it (act 2's `visitor`, `docs/superpowers/specs/2026-11-05-someone-at-the-door-design.md`);
  - during act 3's knocking at the front door.

  Today, opening it during the visit shows an empty corridor, and that changes. In act 3 the danger runs from the
  first knock at the front door until the reveal (the `front_door` and `reveal_pending` beats), my call. The fail-safe
  knocks that call him out of the bedroom stay: walking to the door is safe, only opening it kills. Act 3's
  "[Nobody there. The corridor is empty.]" is said when he looks through the peephole instead of when he reaches the
  entrance (my call).
- **The peephole** never kills, and it no longer ends the visit (my call; this changes the visitor design's
  "Peeking ends the visit"). He still sees the empty corridor through it, and the visit runs on to the lights check,
  so peeking can't be used to skip the rule.
- **Hide from the footsteps.** When the visitor's footsteps come along the corridor, every light in the flat must be
  off by the time they stop outside the door, or it knows he is home and gets him (my call: every light, his phone
  light included, and the check comes when the footsteps stop). The time from the lift chime to the feet stopping must be long enough to
  reach a switch from anywhere in the flat with a light on. If it is too short, lengthen the walk; don't loosen the
  rule.

### 4. What dying looks like (owner)

- **On the road:** a short death scene. She comes for the camera, and the screen cuts to black as she reaches it, as
  in the caught ending today (`Penanggal.come_for`, `Endings` `her_comes`; my call to reuse them). At the bus stop
  the couple's car drives off first, then she comes.
- **In the flat:** "She followed you" (owner). The flying head from the road comes at him in the flat, with the same
  cut to black. The visitor design keeps its rule that nobody is ever seen in the corridor or through the peephole;
  only this death breaks it (owner).
- **GAME OVER** (owner's word). After the cut, a black card shows:
  - the title "GAME OVER";
  - one bracketed line in the game's voice naming what killed him, for example "[You looked back.]" or "[The car
    left without you.]";
  - a "Try again" button.

  The card's style, layout and wording are my call, matching the game's existing cards (`Hud.show_card`). No lives
  counter (my call).

### 5. Trying again (owner)

- **On the road:** from the start of the mission he died in (owner), as `RoadDirector.start_at()` does for
  `--mission=N`. The others' mistakes from earlier missions are kept. Those from the failed try are dropped, so a
  retry starts with the count it had when that mission began (my call). Dying adds nothing to the count (my call).
- **In the flat:** from the start of the stage (act) he died in (owner). The stages are complaint (the intercom and
  the knocks), disturbance (the things that move), impossible (the front-door knocking and the new door) and
  decision. The flat's state when that act began is restored: the world's flags, doors, lights, shifted rooms, clues
  and the director's beat. The road's ending is kept (owner: "Getting home" was the other option, not picked). How
  the state is saved and restored is left to the builder.
- Retrying is quick: within a few seconds of "Try again" he is playing again, with no title or loading card longer
  than the game needs (my call).

### 6. He is told every rule that can kill him (owner)

The owner chose "Bang Din warns you". A death must never come from a rule he was never told:
- **Bang Din (road):** new lines, said as his other rules are (a bracketed memory line, as in `RECALL`, before the
  rule applies), for:
  - getting in fast when a car stops (said during the wait in mission 1);
  - locking the doors if something lands on the roof (mission 4's rule, before the thumps);
  - not stopping on the walk (mission 5's rule).
- **Rosnah (flat):** a new line on her intercom call in act 1, before the visitor can come in act 2: switch off all
  your lights, even your phone, if you hear footsteps outside at night, and don't open the door (my call: Rosnah, not
  a note). The lights and front-door deaths are armed only once he has heard this line (the `answered_intercom`
  flag), my call. If he never answers her, those two can't kill him: the story's fail-safe for the unanswered
  intercom stays.
- The face-the-sound rule is told by its own line the first time (goal 3). Act 3's front-door knocking is covered by
  Rosnah's line.
- The exact wording is my call, in the characters' own English (Rosnah's "Sorry ah" register, Bang Din's short
  orders). Where an existing line changes, its voice is made again.

All new and changed lines are voiced in the same Dia voices (owner), with `~/condo-voice/gen.py`:
- Bang Din's lines use the `memory` effect;
- Rosnah's line uses the `intercom` effect;
- every take passes the Qwen3-ASR check before it ships.

## Non-goals

- No lives, difficulty setting, or checkpoints inside a mission or a stage (my call).
- No new creature or model: she is the one who comes (owner).
- The three road endings, the flat's two endings and the bridge between them play as now. Only which ending a
  mistake leads to changes.
- No trailer or gameplay-video changes; they are re-recorded later.
- Mission 1's walk to the stop and the flat's opening quiet stay without deaths, apart from the car's 10 s.

## Anti-goals (a failure even if it works)

- **An unfair death:** dying to a rule he was never told, or a clock that can't be met from where he stands.
- **A death that kills the bots:** a death that depends on the presentation. As now, the core (`RoadDirector`,
  `StoryDirector`) decides every death and its timing, and the headless bots can play it.
- **A cheap death:** a cut to black with no moment of her, or a GAME OVER that takes so long that retrying feels
  like a chore.
- **Lost endings:** an ending that the others' mistakes can no longer reach.
- **Dying to the old default:** a timed-out choice that kills him even though silence is the rule there.

## Constraints

- Godot 4.7.2 (`~/tools/godot-4.7.2`), typed GDScript, Compatibility renderer, web and desktop.
- No shader compiles mid-game. Today she is drawn in the road's warm-up only (`RoadMain._compile_shaders`). In the
  flat she needs warming too, before she can come.
- The web build stays under the pck cap in `tools/smoke.sh` (9936 KiB; 9447 KiB today). New voice lines are 40 kbps
  MP3, a few KB each.
- Audio limits in `docs/architecture.md` hold: the summed peak at the master stays ≤ −6.1 dBFS.
- The headless tests (`tools/test.sh`, 287 today) and the three road bots (keeper, wobbly, breaker in
  `tests/sim/road_playthrough.gd`) are updated:
  - the keeper keeps every rule and survives;
  - each death has a test that it happens and that the retry starts where goal 5 says;
  - the others' rules alone reach all three endings;
  - `docs/playthroughs.md` is updated to match.
- Changing a voiced line's text drops its voice until it is made again (`tests/unit/test_voices.gd`).
- The game is due 2026-12-01 (Game Off).
- Build, merge and push only with the owner's OK. Never run `tools/export.sh` in `~/the-condo`; use a worktree.

## Left to the builder

- The exact clocks: the car (about 10 s), standing still on the walk (a few seconds), the roof (a few seconds), the
  footsteps, how long he has to face the sound.
- How her closing in on the walk shows and sounds.
- The new weights or thresholds for goal 2.
- How the flat's act state is saved and restored, and how the road's retry reuses `start_at()`.
- The GAME OVER card's layout and each death's bracketed line.
- The test design.
