# itch.io page

Everything for the game's itch.io page, ready to paste. Nothing here has been posted: creating the page, uploading
and publishing are the owner's steps. The page teases only, like the trailer: nothing from the moment the bedroom
window becomes a door, no B-11-07, no ending names, nothing of his death and nothing of the penanggal in full. The
gore is named in the content warning and nowhere else.

## Images

`GODOT=<Godot 4.7.2> tools/itch.sh` renders them into `builds/itch/` (git-ignored), in a window.
Run it again whenever the game's look changes.

| Field on *Edit game* | File |
|---|---|
| Cover image (630×500) | `builds/itch/cover.png`: the figure in the kitchen, in the phone light |
| Screenshots | `builds/itch/screenshots/1-hallway.png` … `5-clock.png` (1920×1080), in that order: the figure in the hallway, the bedroom, the tap in the phone light, the front door, the clock at 11:47 |
| Gameplay video or trailer | The YouTube link, once the trailer is uploaded there (the file is in Drive, "The Condo trailer") |

These are the flat's images, made before the road was added. The page now opens on the road, so the cover, the
screenshots and the trailer need re-shooting, which is separate work after this plan. The cover and the
thumbnail show no gore (itch.io's guidelines ask for no explicit cover image, and shock images can get a page delisted
from browse and search; see `docs/research/2026-11-06-gore-rules.md`).

`tools/road_stills.sh <dir>` renders the road's 46 stills, two of them for checking only (`lunge`, `lunge_phone`).
Only the ones that show the road, the car and the couple,
the mirror, the light and the stall belong on this page: `road_exit`, `road_stop`, `road_bend`, `road_tunnel`,
`road_tunnel_in`, `road_awas40`, `road_city`, `car_arrives`, `back_seat`, `slow_car`, `overtake`,
`lay_by`, `couple`, `mei_turns`, `mirror_fourth`, `light_seen`, `walk_mei`, `walk_mei_looks`, `walk_light`, `walk_near`
and `stall`, and the ten far, fogged glimpses (every `her_glimpse_*`), where she is a few pixels of dark shape. Never
on the page: `her_full`, `her_close`, `her_roof`, `her_comes`, `lunge`, `lunge_phone`,
every ending (`ending_saved`, `ending_alive`,
`ending_caught`) and the shots of how `alive` is decided (`alive_before`, `alive_decided`, `alive_2s`, `alive_torch`,
`alive_pass`).

## Title and tagline

* **Title:** 11:47PM
* **Short description or tagline:** The last bus has gone. The road down has rules.

## Description

> **Content warning:** blood and gore, a figure that appears suddenly, sudden loud sounds and flickering lights.
>
> **12:06 AM.** The last staff bus went down the mountain at eleven. Bang Din at the stall says the road down has
> rules. He only tells them after midnight. You laughed. He didn't.
>
> A couple you have never met stop and give you a lift. Hafiz drives and Mei talks. You sit in the back, in the fog, and
> try to remember the rules. Follow the slow car, however long it takes. If the car dies, stay inside. Whatever follows
> you, don't look back.
>
> Then it is 11:47 PM and you are home. The intercom rings: the neighbour downstairs wants you to stop knocking. You live
> alone. You haven't made a sound.
>
> Then three knocks come from your bedroom.
>
> 11:47PM is a short first-person horror game: a night drive down a mountain in Malaysia, then an ordinary
> condo at night, with grilles on the windows, laundry drying by the window and the corridor light under the front door.
> On the road you choose what to say and where to look. In the flat, small things move while you aren't looking. Notice
> what moved. And the clock keeps going back to 11:47.
>
> A Horror Director watches how you play in the flat (the rooms you avoid, how often you look behind you, whether you
> chase sounds or keep to the light) and picks which frights happen, and when. The road ends in more than one way, and
> so does the flat.
>
> Made for **GitHub Game Off 2026**. The theme is SHIFT: you come off a shift, and the flat shifts while you aren't
> looking.
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
> * Answer a choice on the road: 1, 2 or 3
> * Pause and settings: Esc
>
> **Settings:** brightness, field of view, head bob, mouse sensitivity, invert mouse Y, volume, Filter (a soft look),
> captions for sounds (spoken lines always show), and reduced flashing (flickering lights dim slowly instead).
>
> **Credits:** made by Chris Cheng in Godot 4.7. The rooms and the road are built in code, the objects, the car and
> the people in Blender from scripts, and every sound is synthesised in code; no third-party asset files are used.
> The clock's numerals use the Inter font (SIL Open Font License 1.1). Source code (MIT licence): https://github.com/chengboonrong/the-condo

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
| Tags | horror, gore, psychological-horror, first-person, atmospheric, exploration, 3d, godot, malaysia, singleplayer | itch.io allows 10, so `short` made way for `gore`, which is accurate now. The owner can swap. Never `porn`, `adult`, `hentai`, `erotic` or `sex` (itch.io's UK restriction reads them together with the sensitive-content setting) |
| Average session | Set after a real playthrough | Only bots have played it: the keeper bot takes 538 s (9.0 minutes) to finish the road, and the flat 5 to 20 minutes (sim time, `docs/playthroughs.md`). Nobody has timed a person yet |
| Age rating | None to set | itch.io has no age-rating setting and no blood-and-gore setting. Its quality guidelines and Creator FAQ (read 2026-11-06) mention neither; its admin said in 2018 that the only option is a NSFW toggle, and his 2025 post on the UK law still names one "Has sensitive content" setting. The content warning in the description is how the page says it |
| Has sensitive content (*Metadata » Classification*) | The owner's call; open | The rule is that a page with "strong adult themes" "must be marked", and the Creator FAQ defines adult content as sexualised material. The game has none, so leaving the box off follows the written text. Ticking it is the cautious choice, and hides the page from visitors who have not turned adult content on. The wording of the checkbox itself was not read: the logged-in edit page was not opened. See `docs/research/2026-11-06-gore-rules.md` |
| Languages | English | |
| Inputs | Keyboard, Mouse | No gamepad support |
| Accessibility | Subtitles | What anyone says or thinks always shows. The sounds that carry a moment are captioned, in the flat and on the road, and those captions can be turned off. Controls can't be remapped |
| Comments | On | |
| Visibility | Draft until the page is finished | Publish once, when it's ready |

## AI disclosure

The jam asks about AI use at submission, and itch.io's *Edit game* page has its own AI section. Both answers are the
owner's to word. The facts:

* The code was written with an AI coding assistant. That includes the scripts that build every 3D model in Blender
  and the code that synthesises every sound.
* The in-game text (the dialogue and the captions) and this page's text were drafted with it. Every commit in the
  repository carries its co-author line.
* The spoken lines were generated with a voice model, mesolitica/Malaysian-Podcast-Dia-1.6B, in its own voices
  (no real person's), each take checked with a speech recogniser (README, Licence).
* No image, video, 3D or music generator was used, as far as the repository shows (every model has its Blender
  script, every sound its line in `tools/gen_audio.py`). Yours to confirm.

## Before publishing

* Decide the *Has sensitive content* box, and the tags (see the table above). The README already carries the content
  warning that GitHub's policy asks for, and has no gore image; keep gore out of the repository's social preview and
  avatar too.
* Re-shoot the cover, the screenshots and the trailer for the road (see Images above).
* The public repository is https://github.com/chengboonrong/the-condo. Push the final game to it before
  2026-12-01 13:37 PST (the jam's rule).
* Upload the trailer to YouTube and paste the link.
* Re-export the web build from the branch that ships, and retake the images if the look has changed since.
