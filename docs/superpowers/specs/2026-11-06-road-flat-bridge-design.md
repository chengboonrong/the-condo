# 11:47PM — the bridge from the road to the flat

Status: owner-approved in conversation, 2026-11-06 (each part played back and answered "All good"). Branch
`feat/road-flat-bridge`, from local main at f1e1177. Everything not marked "owner" is my call, and the owner
approved the parts as described below.

## Intent

The owner: "I feel like the condo script seems not connected with the road script". They are right. The road ends
with a crash, the penanggal and maybe two people dead, and the flat then opens with "You're home from your shift at
the mamak. Wash up, then get some sleep." as if nothing happened. The road's ending is recorded
(`Journey.road_ending`) but the flat only uses it to skip its start card. Nothing in the flat points back to the
road: no Mei, no Hafiz, no car, no mountain, no penanggal.

This is the **light bridge** (owner's choice over the full "part 2" of two flats): the flat keeps every room, event
and puzzle, and only its opening, a few sounds and some words change, so that the road follows him home.

## What the player should feel (owner)

* **At the start of the flat: lost and empty.** "Feel lost and empty, what's going on. He doesn't know why he
  suddenly back to home and how."
* **At the end: he never got home** (owner's choice of three). If all three were caught on the road, he died there,
  and the flat is where he keeps coming back to at 11:47, the time he should have got home. If he got off the
  mountain alive, the last card says who didn't.

## Goals

### 1. The opening: suddenly home

* No cutscene, no narrator, no message explaining anything. The road's black card (`"11:47 PM"`, main.gd) hands
  over as now; he is standing in his own dark living room (the flat's existing spawn).
* **Quiet first.** About 20 s with no horror event: the fridge hum and the building settling only.
* **Things that don't add up, found, not told:**
  * a caption a few seconds in: *[Your phone says 12:41 AM. The clock on the wall says 11:47.]*
  * a caption soon after: *[Your uniform is still damp from the fog.]*
  * red earth by the front door: footprints of the mountain road's red earth from the door to where he stood,
    drawn in code (flat decals, no model files). Inspecting them: *Red earth, from the mountain road. You don't
    remember walking in.*
* **The first objective is a question:** *How did you get home?* It becomes the flat's usual *Wash up, then get
  some sleep.* after the quiet stretch (or when he inspects the footprints, if sooner). The rest of the flat's flow
  is unchanged.

### 2. The road follows him in

* **The knocks sound like the roof.** The flat's three knocks from the bedroom use the body of the road's roof
  thump (`thump_roof.wav`), so a player who heard it on the road recognises it. Same timing and loudness rules as
  the knocks today.
* **Her smell, once.** The road's line *[A sour smell, like vinegar.]* (her.gd `SMELL`) plays once in the flat,
  near the bedroom wall, after the first knocks. Never explained.
* **The rules mirror each other.** The first time the flat's *Things move when you aren't looking. Keep looking.*
  appears, one caption makes the reversal deliberate: *[On the road you weren't allowed to look back. Here, you
  can't look away.]*

### 3. The clues point back

* **The intercom's last call.** Inspecting the intercom after Rosnah's call shows *LAST CALL 23:47 FROM B-12-07*
  as now. Then, by road ending:
  * caught: the line crackles with wind and an idling engine, and Mei's first line plays as a caption:
    *"Eh, you going down ah? Jom, we got space."* The night started with that invitation.
  * saved: the same, with Hafiz's first line (*"Wah, so late still working ah? Kesian, bro."*): he is the one lost.
  * alive: as today.

### 4. The endings say what happened on the road

The flat's two endings keep their names and choices. Only their last card's text depends on the road. Drafts
(my calls; the builder may tighten wording, not meaning):

| Road | DOWNSTAIRS | VACANT |
|---|---|---|
| caught | Today's text, then: *You never got home.* | Today's text, with the notice reading: *Unit B-12-07 has been vacant since November. Its tenant was one of three people found on the old road down the mountain.* |
| saved | *You knock three times. Something knocks back, three times, from inside the wall, the way something landed on the roof of Hafiz's car. Hafiz never got home. He's been knocking all night.* | *The lift is warm, as if someone has just stepped out of it. You don't go back up. Hafiz never got home. Some nights you still hear him knocking.* |
| alive | *You knock three times. Something knocks back. All three of you got home. Something else came down the mountain too.* | *The lift is warm, as if someone has just stepped out of it. You don't go back up. All three of you got home. Something else came down the mountain too.* |

## Non-goals

* The full part 2: no separate quiet flat for the alive endings, no new rooms, models or events. In the alive
  endings the flat's middle (B-11-07, *It's your voice*) still reads like a ghost story; only the last card
  reframes it. Accepted for now.
* No change to the road.
* The trailer's flat half (it shows him walking home along the corridor) is re-cut afterwards, separately.

## Anti-goals

* Explaining it outright: no narrator, no *you died*, no flashback footage.
* Naming a real place, road or crash, or real victims. The road is "the old road down the mountain".
* Breaking the flat's existing beats, endings or bots.
* Captions that cut a spoken line short (the one subtitle line is last-in-wins).

## Constraints

* Godot 4.7.2, typed GDScript, Compatibility renderer, web and desktop. No new paid or external assets; anything
  new is drawn in code or reuses the game's sounds.
* With `Journey.road_ending == &""` (the flat opened directly: tests, `--flat`, smoke) the flat behaves exactly as
  today.
* Captions follow the flat's style: bracketed, in the flat's durations; spoken lines in quotes.
* The flat's endings and the bots (`tools/playthroughs.gd`) still reach every ending, for each road ending.
* Jam deadline: 2026-12-01 13:37 PST.

## Left to the builder

* Where in `story_director.gd` each change hooks in, and how the 20 s of quiet holds the event scheduler.
* How the footprints are drawn and placed, and the knock sound's mix (a new file made from the existing two is fine).
* Exact caption timings, within the rule above.
* Which docs to update (architecture, event catalog, test plan).
* Tests: per road ending, the opening objective and captions, the intercom line, and each ending's text; and that
  `&""` leaves the flat as today.

## How we know it's done

* The full suite passes; the smoke runs; the bots reach every flat ending after each road ending.
* Stills of the opening (the footprints by the door) and the captions, looked at.
* A separate reviewer reads the diff against this document.
* The owner plays it through.
