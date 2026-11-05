# The horror vibe pass: design

2026-11-05. Status: approved by the owner on 2026-11-05, including the four answers marked "My call". Built on
feat/vibe-pass, from the end of feat/trailer-objects.

## Why

The owner loves the Japanese studio Chilla's Art and asked for a study of how its games make a place feel
creepy. The study is in `docs/research/2026-11-05-chillas-art-horror-vibe.md`. These are its main findings:

* **A believable place behind a soft, switchable filter.** The filter is not pixel art.
* **An ordinary place at night.**
* **Slow fear with little explained.**
* **Warmth first, so the wrongness has something to break.** The studio's image for this is "a log cabin in
  heavy snow".
* **Still figures under a single light, not monsters.**

From the study's recommendations the owner chose three groups: look and settings, a figure you can watch,
and home sounds that later stop. The owner did not choose the hands-on act 1 routine or less on-screen text.

After seeing stills rendered from the game, the owner picked **soft half resolution** as the default look
(stills: `/tmp/condo-look/overview.png`, `/tmp/condo-look/detail.png`).

The guiding rule from the study is to borrow the principles, not the surface.

## Goals

1. **A softer image, with the text kept sharp.**
   * The 3D view renders at half resolution and is scaled up with bilinear filtering.
   * The HUD, subtitles, prompts and the inspection panel stay at full resolution.
   * The look should be the same at any window size, so the scale follows the window: about 450 lines of 3D
     image, at an integer divisor. At 900 px tall that is a scale of 0.5.
   * It is on by default, and the **Filter** setting turns it off.
2. **Grain at the 3D pixel size while the filter is on.**
   * Today's grain (`Hud.FILM_SHADER`) snaps to the half-resolution pixel grid, so it reads as part of the
     picture.
   * It stays a shader that does not read the screen.
   * With the filter off, the grain stays as it is today, because it hides banding.
3. **A colour grade per act.**
   * Act 1 (`COMPLAINT`, home after the shift) is a little warm and full.
   * Each later act is a step colder and more drained.
   * B-11-07, the mirrored flat, is the most drained place in the game.
   * The grade eases between steps; it does not cut.
   * The stills' two grades are the starting point. Act 1: saturation 1.08, contrast 1.02, a warm white.
     Act 2 onward: saturation down to about 0.62, contrast 1.08, a cool white.
4. **Three new settings in the pause menu**, saved like the existing ones:
   * **Filter**, on by default.
   * **Field of view**, vertical, about 60 to 80, default 72 as today.
   * **Head bob**, from 0 to 100%, default 100%.
5. **A figure you can watch.**
   * This is a rarer staging of the figure.
   * It stands still under the only light at the far end of a space, such as the gap corridor under a caged
     bulkhead or the hallway with only its downlight on. It faces away or faces the wall.
   * It stays while the player watches. It is gone the next time the player looks away or turns a corner.
   * It counts as a sighting, so everything that follows a sighting still happens.
   * **My call: it is silent.** It counts as seen after 0.3 s in view, as today: the scheduler marks it seen
     and the entity notices. It plays no stinger, though, and it does not fade while watched. A jump-scare
     at first sight would undo a figure meant to be watched quietly. The study also advises against
     stingers as the main tool.
   * **My call: "the only light" means the light on the figure, not the whole flat.** The figure stands in
     the pool of one light, with dark between it and the player. The staging waits for a place where that
     holds and never switches lights itself. Some places hold it by how they are built, such as the gap
     corridor under its caged bulkheads. Others hold it only at that moment, such as the hallway with only
     its downlight on, so the staging checks them when it is prepared.
   * It is built after the figure model (trailer-objects plan, Task 11), because a still figure has to
     survive being looked at. It is the last phase of this pass, and no other goal depends on it.
6. **Home sounds, then silence.**
   * Act 1 has quiet beds that say "home": the ceiling fan turning, the fridge hum, a neighbour's TV
     murmuring through the wall (muffled, no words or music anyone could recognise).
   * From act 2 they drop out one at a time.
   * The silence after one stops is the signal. No sting marks it.
   * **My call on levels**, as heard, using the audio-levels table in `docs/architecture.md`: fan about −36 dB,
     fridge about −38, TV about −40. That is near the corridor hum (−34.7) and above the drone at rest
     (−44), below every event sound. Any quieter and laptop speakers lose them, and then the silence after
     one stops carries no signal.
   * **My call on stopping:** a bed fades out over about 1.5 s. The fan winds down over about 3 s. Never a
     cut, which clicks, and never so slow that nobody notices.
   * Like every sound in the game, they are made by `tools/gen_audio.py`.

## Non-goals

* The full VHS or CRT look: colour bleed, tracking lines, interlacing, rounded screen corners. The study
  advises against it: it is the studio's signature surface, and THE CONDO's premise is already close to
  theirs.
* Chromatic aberration. The rule in `docs/architecture.md` stays.
* A camcorder date stamp or "REC" overlay. The red 11:47 clock already does that job.
* Camera shake, or more sway than today's head bob.
* The hands-on act 1 routine and less on-screen text. The owner did not choose them.
* Changes to the story, the events' rules or the shifts, beyond the new figure staging and the beds dropping
  out.

## Anti-goals (a failure even if it works)

* A moved object becomes hard to notice at half resolution. The game is about noticing the shoes, the
  chair, the tap.
* Thin things shimmer when the camera turns: grilles, chair rungs, clock hands.
* The WebKit build drops below 60 fps, or a hitch appears the first time the grade changes or a bed starts.
* A still figure that reads as a dummy, a monster or a zombie. It is a person in your apron.
* A bed stopping sounds like a bug: a click, or a gap that is plainly a loop seam.
* Motion sickness that the settings cannot fix.

## Constraints

* Godot 4.7.2, Compatibility renderer (WebGL2 in the browser). It must keep 60 fps in WebKit with no frame
  over 25 ms. Measure with the filter on and off, the way `docs/performance.md` does.
* **My call: what gives way when the look meets an anti-goal.** First the frame budget, then whether a moved
  object can be noticed, then the exact look.
  * If thin things shimmer or a moved object gets hard to see, raise the 3D scale first, up to about 540
    lines. That is still soft.
  * Next is MSAA 4x, and only if it measures within the budget.
  * The rebuilt trailer-objects models are not reopened for this.
* Bilinear 3D scaling is documented for every renderer. Nearest was seen working on the desktop build but is
  not used.
* Resolution scaling does not touch 2D, so the HUD stays sharp without extra work.
* **Shader warm-up.** Whatever the grade and the beds first use must be compiled or loaded behind the start
  card. For example, the colour-correction adjustment is on from the first frame, at a neutral setting if
  need be.
* **Settings.** New settings follow `Settings.DEFAULTS` and the pause menu's existing rows.
* Old saved settings files without the new keys must still load.
* Every test passes. The figure and story tests change only where the new staging needs them.
* The trailer is filmed after this pass, with the shipped defaults. Its stills and cameras are
  `tools/stills.gd`.
* Nothing is pushed, merged or published without the owner's say.
* Deadline: submissions close 2026-12-01 13:37 PST.

## Order

This comes after the trailer-objects rebuild, on its own branch from where that work ends. The figure
staging comes after the rebuilt figure. The trailer comes last.

## Done when

1. The `tools/stills.gd` sheet with the shipped defaults (filter on, act 1 grade) and an act 2 sheet
   both show every trailer object still reading clearly. The owner has looked at them.
2. `tools/test.sh` passes in full.
3. `tools/export.sh` then `tools/smoke.sh` give a smoke ok on macOS, Chromium and WebKit.
4. Performance is measured with the filter on and off and recorded in `docs/performance.md`. WebKit keeps 60
   fps, and no frame on any build goes over 25 ms.
5. The three settings change the picture at once and survive a restart.
6. `docs/architecture.md` "## Look" and "## Audio levels" describe the filter, the grade and the beds.

## Left to the builder

* The exact grade values for each act and for B-11-07, and how long each ease takes.
* Which place and light the still figure uses, how rare it is, and how long it waits before it can vanish.
* How the beds are synthesised, and which one stops first and when.
* How the window-size divisor is chosen at sizes between the steps.
* Whether the fan bed follows the fan's own state where the game has one.
