# itch.io page

Everything for the game's itch.io page, ready to paste. Nothing here has been posted: creating the page, uploading
and publishing are the owner's steps. The page teases only, like the trailer: nothing from the moment the bedroom
window becomes a door, no B-11-07, and no ending names.

## Images

`GODOT=<Godot 4.7.2> tools/itch.sh` renders them into `builds/itch/` (git-ignored), in a window.
Run it again whenever the game's look changes.

| Field on *Edit game* | File |
|---|---|
| Cover image (630×500) | `builds/itch/cover.png`: the figure in the kitchen, in the phone light |
| Screenshots | `builds/itch/screenshots/1-hallway.png` … `5-clock.png` (1920×1080), in that order: the figure in the hallway, the bedroom and the tap in the phone light, the front door, the clock at 11:47 |
| Gameplay video or trailer | The YouTube link, once the trailer is uploaded there (the file is in Drive, "The Condo trailer") |

## Title and tagline

* **Title:** THE CONDO: 11:47 PM
* **Short description or tagline:** The neighbour downstairs wants you to stop knocking. You haven't made a sound.

## Description

> **11:47 PM.** You've just come home from your shift at the mamak on the corner. The intercom rings: the neighbour
> downstairs wants you to stop knocking.
>
> You live alone. You haven't made a sound.
>
> Then three knocks come from your bedroom.
>
> THE CONDO: 11:47 PM is a short first-person horror game set in an ordinary Malaysian condo at night: grilles on
> the windows, laundry drying by the window, the corridor light under the front door. Small things in the flat
> move while you aren't looking. Notice what moved. And the clock keeps going back to 11:47.
>
> A Horror Director watches how you play (the rooms you avoid, how often you look behind you, whether you chase
> sounds or keep to the light) and picks which frights happen, and when. There are two endings.
>
> Made for **GitHub Game Off 2026**. The theme is SHIFT: you're home from a shift, and the flat shifts while you
> aren't looking.
>
> **Play**
>
> * In your browser, on a computer with a keyboard and mouse. Phones and tablets aren't supported.
> * Fullscreen and headphones recommended.
> * The macOS app isn't notarised, so macOS blocks it the first time: open System Settings › Privacy & Security and
>   click Open Anyway (on macOS 14 and earlier, right-click the app and choose Open).
>
> **Controls**
>
> * Move: W A S D or the arrow keys
> * Sprint: Shift
> * Crouch: hold C
> * Interact: E or left click
> * Phone light: F or right click
> * Pause and settings: Esc
>
> **Settings:** brightness, field of view, head bob, mouse sensitivity, invert mouse Y, volume, Filter (a soft look),
> captions for sounds (spoken lines always show), and reduced flashing (flickering lights dim slowly instead).
>
> **Content warning:** darkness, a figure that appears suddenly, sudden loud sounds and flickering lights. No blood
> or gore.
>
> **Credits:** made by Chris Cheng in Godot 4.7. The rooms are built in code, the objects in Blender from scripts,
> and every sound is synthesised in code; no third-party asset files are used. The clock's numerals use the Inter
> font (SIL Open Font License 1.1). Source code (MIT licence): https://github.com/chengboonrong/the-condo

The macOS line goes only if the macOS app is uploaded. The Windows and Linux builds have never been run, so they
stay off the page until someone has run them.

## Settings on *Edit game*

| Setting | Value | Why |
|---|---|---|
| Kind of project | HTML | Played in the browser |
| Uploads | A zip of `builds/web/` (`index.html` at its root), marked *This file will be played in the browser* | 9 files, about 46 MB: inside itch.io's limits (1,000 files, 500 MB). Export it again from the branch that ships first (`tools/export.sh`) |
| Viewport dimensions | 1280 × 720 | The size the soft filter was set for (360 lines at 720 px, `docs/architecture.md`, Look); below 675 px tall it switches itself off |
| Fullscreen button | On | |
| Mobile friendly | Off | Keyboard and mouse only |
| Automatically start on page load | Off | Click to start, so the sound isn't a surprise |
| SharedArrayBuffer support | Off | The web build has no threads |
| Release status | Released | The jam build |
| Pricing | No payments | The trailer says "Play free in your browser" |
| Genre | Horror | |
| Tags | horror, psychological-horror, first-person, short, atmospheric, exploration, 3d, godot, malaysia, singleplayer | itch.io allows 10 |
| Average session | Set after a real playthrough | Only bots have played it (5 to 20 minutes); nobody has timed a person yet |
| Languages | English | |
| Inputs | Keyboard, Mouse | No gamepad support |
| Accessibility | Subtitles | Controls can't be remapped |
| Comments | On | |
| Visibility | Draft until the page is finished | Publish once, when it's ready |

## AI disclosure

The jam asks about AI use at submission, and itch.io's *Edit game* page has its own AI section. Both answers are the
owner's to word. The facts:

* The code was written with an AI coding assistant. That includes the scripts that build every 3D model in Blender
  and the code that synthesises every sound.
* The in-game text (the dialogue and the captions) and this page's text were drafted with it. Every commit in the
  repository carries its co-author line.
* No image, video, 3D, voice or music generator was used, as far as the repository shows (every model has its
  Blender script, every sound its line in `tools/gen_audio.py`). Yours to confirm.

## Before publishing

* The public repository is https://github.com/chengboonrong/the-condo. Push the final game to it before
  2026-12-01 13:37 PST (the jam's rule).
* Upload the trailer to YouTube and paste the link.
* Re-export the web build from the branch that ships, and retake the images if the look has changed since.
