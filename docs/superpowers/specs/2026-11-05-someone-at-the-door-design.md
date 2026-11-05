# Someone at your door: design

Owner's ask (2026-11-05): "More frights and content", using ideas from the Chilla's Art study
(`docs/research/2026-11-05-chillas-art-horror-vibe.md`) that the vibe pass did not use. The owner chose "Skip
questions", so every call below is mine and is marked as such for the owner to check.

## Why

The study's strongest unused finding is the intruder: in Chilla's Art games strangers come to the shop or the
door, and the fear is that an ordinary visit is not ordinary. A Malaysian condo has the perfect stage for it, and
the game already built half of it: the corridor light that leaks under the front door, a front door with a
peephole, a lift down the corridor that is "under maintenance", and the corridor's own footsteps sound.

## Goals

1. **A new adaptive fright, `visitor`** (my call). In act 2 only, about once a shift:
   1. The lift chimes far down the corridor.
   2. Slow footsteps come along the corridor, getting louder, and stop outside the front door.
   3. Two shadows of feet break the strip of light under the door, and stay.
   4. Then they are gone, without a sound: no footsteps walk away. It ends that way when the wait runs out, when
      the player opens the front door (the corridor is empty), or when the player looks through the peephole.
2. **The peephole** (my call). The front door's peephole, on its inside face, becomes something to use: "Look
   through the peephole". It shows the corridor through a fisheye lens, inside a round black mask; E or Esc steps
   back. During the visit the corridor is empty although the feet were under the door: the contradiction is the
   scare, and it is never explained. Peeking ends the visit, so after stepping back the light under the door is
   whole again.
3. Captions for the sounds only, in the existing style: "[A lift chimes down the corridor]", "[Footsteps in the
   corridor, coming closer]", "[The footsteps stop outside your door]". Nothing is captioned when the feet go.

## Non-goals

* No figure, face or person is ever shown in the corridor or through the peephole.
* No new story beat, ending, clue or objective; the story director does not know about the visit.
* No change to the act 3 knock at the front door, except that it pre-empts a visit (same channel).
* Not the other ideas from the study (the mirror's reflection, phone messages, R5 routine, R6 less text). The
  mirror needs a second render of the 3D (a SubViewport, with its own shadow-atlas setting) on the web; it is a
  later idea, not this one.

## Anti-goals (a failure even if it works)

* A jump scare: no stinger, no sudden loud sound, no shake. The loudest step stays under the knock3.
* Telling the player what happened: no caption for the feet leaving, no "someone was there" text.
* Feet that look like a texture glued to the floor: they are gaps in the light strip, soft-edged like the strip.
* A peephole view that looks like a plain camera: it needs the fisheye bend and the round mask to read at once.

## Constraints

* Godot 4.7.2, typed GDScript, Compatibility renderer (WebGL2 on the web). No asset files: the lens is a shader
  in code, the feet are geometry in `Decor`, the sounds already exist (`lift_ding`, `footstep`).
* The simulation core stays headless and deterministic: `VisitorEvent` uses `ctx.rng` and `ctx.stage` only, and
  reaches the presentation through `EventBus` signals, as the silhouette does.
* The event framework as it is: a `HorrorEvent` subclass in `scripts/horror/events/`, a `.tres` in
  `resources/horror_events/`, the scheduler's lifecycle, channels and timeouts.
* The visit needs the front door shut, and the player inside the flat, within one room of the entrance (the
  entrance, living room or kitchen, not the corridor), and at least 2.5 m from the door.
* Channel `audio_major`: it never overlaps footsteps or knocks, and the story's act 3 knock (priority 10)
  pre-empts it. Whatever ends it, the feet are taken away (`finish()`).
* Tease-only material stays tease-only: if the stills or the itch page ever use the peephole, nothing from the
  reveal is in it.
* Time keeps running while the player looks through the peephole, as it does while reading a note.
* No mid-game shader compile on the web: the lens is drawn once during the warm-up behind the start card.

## Order

1. `VisitorEvent` in the simulation core, with its tests.
2. The feet under the door (Decor), with a test.
3. The peephole: the interactable on the door, its camera, the HUD's lens view, with tests.
4. Docs (event catalogue, architecture, the stale roadmap line), stills of the feet and the peephole view.

## Done when

* Unit tests show the visit's order (chime, steps getting closer to the door, feet shown, no step after that),
  its preconditions, its three ways of ending, and that a story knock pre-empts it and takes the feet away.
* In the real scene, the feet signal swaps the light strip for one with two gaps while the door is shut, and the
  open door hides both; looking through the peephole switches to a camera outside the door facing the corridor,
  freezes the player, keeps time running, and E puts everything back; peeking during a visit ends it.
* The full suite passes (`tools/test.sh`), the three bots still reach both endings.
* Stills show the feet under the door from the living room, and the peephole view of the empty corridor, and I
  have looked at both.
* `docs/event-catalog.md` and `docs/architecture.md` describe the visit and the peephole.

## Left to the builder

* The lens shader's numbers (field of view, bend, mask radius, vignette), tuned by looking at the still.
* The exact shapes of the gaps in the light strip.
* How long the feet stay (about 15 s is my guess), the step count and the volume ramp, within the anti-goals.
* The director weights: rare (a long cooldown, so about once per act 2), favouring a player who stands still or
  keeps to the light.
