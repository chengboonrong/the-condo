# The road down: design

Owner's ask (2026-11-05 and 06): a horror game about Genting Highlands ghost stories, with missions that have to be
done for the story to continue, not narrative alone. Then: "I want you to rework THE CONDO actually, not a new game".
The owner chose to put the road first and the flat after it. Every line below says whether it is the owner's
decision ("owner") or mine ("my call"). "Owner approved" marks a guess of mine that the owner read and accepted.

Research behind it: `~/genting-ghost-research/2026-11-05-genting-ghost-stories.md` (kept outside this public repo).
It covers the road legends, the real events, the folklore, the legal limits and missions in comparable games.

## Why

The road down from Genting has the strongest ghost stories the research found, and both of them run on a rule:
- a slow car with nobody at the wheel that you must not overtake;
- a stalled car, and a voice that tells you to walk away and not look back.

A rule you must keep is a mission that the story can't go on without. That is what the owner wants missions to be.

THE CONDO already hints that its hero is dead. Its VACANT ending reads "Unit B-12-07 has been vacant since November",
and in DOWNSTAIRS he becomes the knock in someone else's wall. The road gives that death a cause. If he survives
the road, the same flat becomes a place where he is only haunted.

The jam's theme, SHIFT, still fits: he is coming off a night shift, and he leaves the mountain after midnight but
gets home at 11:47.

## The story

1. **The lift down** (owner). He finishes his night shift at a mountain resort above KL after the last bus has
   gone. A couple who had a fun day at the resort stop and give him a lift back down to town at midnight. He is a
   stranger to them. They can see him and talk to him.
   - He still works at a mamak, but the stall is up at the resort now, not on the corner (my call, owner approved).
   - He has heard the staff's stories about the road, so he knows its rules. The couple don't (my call, owner
     approved).
   - The player learns the rules the way he did: a short opening in his thoughts, before mission 1, made of what
     the other staff told him about the road. The rules come back as he needs them. There is no playable scene at
     the stall (my call: one more place to build costs too much in the time left).
2. **The ghost** (owner): a penanggal. In Malay folklore she is a woman by day and at night a head that flies,
   trailing her insides beneath it. She is shown gory, the full folklore version (owner). She is invented: she is
   not any real person who died on any real road (my call).
3. **The road's missions** (my proposal, owner approved), in this order:
   1. **Waiting for a lift.** He walks out to the road in the fog, and the couple stop for him.
   2. **The slow car.** A car with nobody at the wheel crawls ahead. The boyfriend, who is driving (my call),
      wants to overtake it, and the player has to talk him out of it. Each overtake puts the car ahead of them again,
      thickens the fog and brings her closer.
   3. **The extra passenger.** The couple are sure there are four people in the car. The player has to work out
      what they see without turning to look. The rules: don't turn round, and don't count the fourth one out loud
      when the couple ask (my call).
   4. **The car dies.** The boyfriend walks off to find help. The player and the girlfriend wait while something
      thumps on the roof. The rules: don't open the door, and don't answer the knocking or the voice that sounds
      like him (my call).
   5. **Don't look back.** A voice tells them to walk towards a light without looking back. The game is first
      person, so the player can turn around at any moment, and that is the test. He also has to keep her from
      looking.
4. **The road's endings** (owner): all three alive; the boyfriend caught and he gets the girlfriend out; all three
   caught. How well the rules were kept decides which (my call, owner approved). One count of broken rules across
   all five missions decides it, and looking back in mission 5 counts most (my call).
   - **When all three are caught** (owner): the player sees her catch the boyfriend, gore and all, and sees her
     come for the two of them. Then black, at his own moment. He wakes at home at 11:47 exactly as he does after
     the other endings, so the player can't tell he died until the flat shows it.
5. **Home** (owner: road first, then the flat). He wakes up at home in the flat, and the clock says 11:47.
   - **If all three were caught, he is dead and doesn't know it** (owner). The flat is a different world, and he
     only realises it in the end. This is the flat's existing story: the complaint, the things that move, the
     impossible room, B-11-07, and the endings DOWNSTAIRS and VACANT. It gets reframed so that its clues point back
     to the road, and the realisation lands at the end (my call).
   - **If he got off the mountain alive** (the other two endings), he is still haunted, but nothing serious happens
     after that (owner). My call: knocks, things that move and the adaptive events still happen, but the bedroom
     window never becomes a door, and the night ends quietly with him alive. Something small in the flat shows
     whether the boyfriend was lost.

## Goals

1. A playable road section before the flat: the lift down, five missions, a gory penanggal, and three endings.
2. Missions that gate the story: each is a rule to keep or a thing to do, and breaking a rule costs something the
   player can feel (more fog, the car back ahead, her closer), not just a hidden score.
3. Two versions of the flat, chosen by the road: the dead one (the existing story, reframed) and the alive one
   (haunted, then a quiet ending).
4. The whole game in one run, road then flat, in the browser and as a PC download (owner: "Do browser and PC
   download").

## Non-goals

- No phones and no consoles (owner).
- Not a driving game. The boyfriend drives and the player rides in the back seat (my call: the stranger is a
  passenger, and the missions are about what he says and where he looks).
- No voice acting. The couple speak in captions, like the flat's lines (my call: every sound in the game is
  synthesised in code and the AI disclosure says no voice generator was used. Both stay true, and it fits the
  time left).
- No real places, brands or deaths (my call, from the research's section 5):
  - invented names for the resort, the road and the car makes;
  - nothing of the 2013 bus crash or any real death;
  - no real temple;
  - no "true story" framing.
- No new ideas from the research beyond the road. The hotel night audit, the casino cage and the gondola are for
  later, if ever.

## Anti-goals (a failure even if it works)

The owner's four:
- **A ghost that looks fake:** silly, cheap or cartoony instead of frightening.
- **Cheap jump scares:** loud sudden screams every few minutes instead of slow dread.
- **Not Malaysian enough:** a road, car, couple and talk that could be anywhere instead of the hills above KL.
- **Boring missions:** tasks that feel like chores or busywork in the way of the story.

And mine: telling the player he is dead before the end. The flat already keeps its reveal back, and the road must
not give it away.

## Constraints

- **The engine and project stay as they are.**
  - Godot 4.7.2, typed GDScript, the Compatibility renderer (WebGL2 on the web), web and desktop builds.
  - The simulation core stays headless and deterministic, and talks to the presentation through `EventBus`.
  - `tools/test.sh` must pass, and the bots must reach every ending, the new ones included.
- **The jam.** Due 2026-12-01 13:37 PST, which is about 25 days from this design. The work happens in November, and
  the public repo (github.com/chengboonrong/the-condo) gets the final game before the deadline.
- **No paid assets or services, and no external LLM APIs.** New things are made the way the rest of the game is:
  - places in code;
  - models from Blender scripts;
  - sounds synthesised in code.

  A free CC0 asset is allowed only if the credits name it, and the itch page's line "no third-party asset files are
  used" then changes.
- **The web stays smooth.** Measure the road's fog and the penanggal in WebKit against `docs/performance.md`. Never
  claim a frame time that was not measured.
- **No shader compiles mid-game.** The start card's warm-up must also draw the road's materials, the car, the couple
  and the penanggal, gore included.
- **Gore.**
  - The itch page's content warning changes: "No blood or gore" goes, and blood and gore are named.
  - The page gets itch.io's age classification for it.
  - Before publishing, check GitHub's Acceptable Use Policies and itch.io's content rules against what the game
    shows (the public repo carries the models).
- **Tease material stays tease-only.** The trailer, the stills and the itch page show nothing of:
  - his death;
  - the bedroom window becoming a door, or B-11-07;
  - the names of any endings;
  - the penanggal in full.
- **Malaysian.** Use what a night drive down from Genting is really like: the switchbacks, the fog, a tunnel near the
  top, Malay road signs, and how a KL couple talk (Manglish in the captions). The car makes are invented; no real
  brands.
- **Keep what is built.** The flat, its director, its events and its look all stay. The road is added in front of
  them.
  - The trailer and the itch images will need re-shooting afterwards. That is separate work, after this.
  - The unmerged branch `feat/someone-at-the-door` (the visitor and the peephole) suits both versions of the flat.
    Whether to merge it is a separate decision.

## If time runs short

The quiet alive flat goes first (owner). For the jam, every road ending then leads into the flat's existing story,
and the alive version comes in an update after the jam. The road and all five missions stay.

## Order

Build a thin slice that plays from start to finish first: the road, one ending, then the existing flat. Widen it
from there. Main keeps today's game, unchanged, until the road is done and the owner approves moving it (my call).
Which branch the road starts from is decided when the visitor and peephole branch is finished (my call).

1. The road and the ride: the road in fog, the car interior, the scripted drive down, and the couple, visible and
   talking.
2. The five missions, the rule-keeping that decides the road's ending, the three endings, and bots that reach
   each one.
3. The penanggal: her model, the gore, how she moves and sounds, and her warm-up.
4. The two flats: the alive one (new) and the dead one (the existing story with clues that point back to the road,
   and the realisation).
5. Docs, the itch page text and content warning, and stills of the road, the couple and the penanggal.

## Done when

- One run goes from the end of the shift to an ending in the flat, in the browser and on the desktop.
- Every ending can be reached:
  - all three alive, then the quiet flat;
  - the girlfriend saved, then the quiet flat with its small sign of the loss;
  - all three caught, then the dead flat to DOWNSTAIRS;
  - all three caught, then the dead flat to VACANT.
- `tools/test.sh` passes, and the bots reach every ending above.
- Stills of the road, the car, the couple and the penanggal (gore included) exist, and I have looked at them
  against the anti-goals.
- The web smoke passes in WebKit and Chromium, and the frame time on the road is measured and recorded.
- The itch page's description, content warning and credits match the game.

## Left to the builder

- The road's length and layout, and how long the road part takes. My guess is 10 to 15 minutes, against the flat's
  5 to 20.
- How the player talks the driver out of overtaking, and how the other missions are controlled.
- How many broken rules lead to each ending.
- Exactly how the penanggal looks, moves and sounds, within the anti-goals.
- The couple's names, faces, clothes and lines.
- The invented names for the resort, the road and the car. Check that no real place or product uses them.
- How the quiet night ends in the alive flat, and the small sign of the boyfriend's loss.
- Which clues in the dead flat point back to the road, and how the realisation plays.
