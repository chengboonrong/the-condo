# THE CONDO: 11:47 PM — trailer

Status: written 2026-11-05 from the brainstorm; awaiting the owner's approval. Branch: `feat/trailer`, from the
end of `feat/vibe-pass`.

## Intent

A one-minute trailer for the game's itch.io page. It is embedded from YouTube and is the first thing a GitHub
Game Off 2026 voter sees. Its job is to make them press Play. It shows what the game feels like: a tired
mamak worker gets home at 11:47 PM, small things in the flat move, and someone in your apron is there. Then it
stops, before the game's big moment. The jam theme is SHIFT, and the trailer shows it as the flat itself
shifting: the home sounds stop one at a time, the colour drains, and things move.

## Goals

* About 60 s (55–65 s), 16:9, 1920×1080, made from the real game. Everything on screen is the game as players
  get it, with the shipped defaults (filter on, field of view 72, head bob 100%).
* It reads with the sound off for its first seconds, because embeds often start muted. The first beats are text
  cards and pictures, and every spoken line and key sound has the game's own caption on screen.
* With the sound on, it sounds like the game. Its sound is the game's own: the home sounds, the knocks, the
  intercom, the stinger and the door slam.
* The finished MP4 goes to a private folder, "The Condo trailer", on the owner's Google Drive.

## Non-goals

* No music score, no voice-over, and no vertical (9:16) cut.
* No upload to YouTube or itch.io. Publishing is the owner's step.
* No rough cut. Only the finished trailer is uploaded (owner, 2026-11-05: "Wait for the real trailer").
* No new game features. The trailer may only add tooling that films the game.

## Anti-goals

* **Spoilers.** Nothing from the moment the bedroom window becomes a door: no gap, no B-11-07, no corridor
  that grows, no endings (owner: "Tease only").
* **A trailer that looks better than the game.** No post effects, grading or footage that the game doesn't
  render itself.
* **Generic horror-trailer tropes:** whooshes, booms, glitch transitions, a "from the makers of" card, a jump
  scare in every beat. The game's scare is the figure, and the trailer uses it once at full strength.

## Decided by the owner

* Tease only.
* Made for the itch.io page: 16:9, 1080p, about 60 s, readable with the sound off at first.
* The storyboard below, approved 2026-11-05 ("All good"). Its stills are in `/tmp/condo-trailer2/` (throwaway,
  shot from `feat/vibe-pass`).
* Filmed after the vibe pass, with the rebuilt objects.
* The finished trailer goes to Drive, privately, with no rough cut.

## The storyboard

Times are approximate. "Act 1" and "act 2" are the game's colour grades: act 1 a little warm, act 2 colder and
greyer.

| Time | Picture | Sound |
|---|---|---|
| 0:00 | Black. Card: **11:47 PM** in the HUD clock's red. | The fridge hums. |
| 0:04 | The open-air corridor at night, walking towards your door. Card: **Home from the night shift at the mamak.** | Footsteps; the lift dings behind you. |
| 0:10 | Home, act 1. The living room, ceiling fan turning. | The fan; a neighbour's TV murmurs through the wall. |
| 0:15 | The entrance, the intercom. Rosnah's line as the game's subtitle: *"Every night also the same. Knock, knock, knock. From your bedroom."* | The intercom; the home sounds under it. |
| 0:20 | The living room, held. It drains from the act 1 grade to act 2's, the game's own 4 s ease. Card: **You haven't made a sound.** | The TV stops, then the fan winds down. Then only the corridor hum. |
| 0:26 | The bedroom wall in the phone light. Caption: *[Three knocks from the bedroom wall]* | Three knocks. |
| 0:30 | Your work shoes on the rack. The camera looks away… | Quiet. |
| 0:33 | …and back. The shoes are in the middle of the floor, with the game's caption. Quick cuts from here. | |
| 0:36 | The chair, turned to face the bedroom, with the game's caption. | |
| 0:39 | The bathroom tap running in the dark, phone light. | Running water. |
| 0:42 | Only the hallway light on. Someone in your apron stands with their back to you, not moving. | Nothing. The figure is silent. |
| 0:46 | The camera glances away and back. The hallway is empty. | |
| 0:49 | The dark kitchen in the phone light. It stands by the fridge, facing you. | The stinger. Cut to black on a door slam. |
| 0:53 | The wall clock. Card: **And it's always 11:47.** | |
| 0:57 | Title: **THE CONDO: 11:47 PM**, then **Play free in your browser. GitHub Game Off 2026.** | Ends around 1:02. |

## How it gets made (my calls)

* **Filmed by the game itself.** A trailer script in `tools/` (like `tools/stills.gd`) loads the game, sets each
  shot up through the game's own state and signals, and films it with Godot's Movie Maker mode at 1920×1080,
  60 fps. That mode renders every frame and records the game's mixed audio, so frame rate on this Mac doesn't
  matter and every take is the same. Any shot can be re-shot by changing the script.
  * The state is the act, lights, variants and doors. The signals are sound, subtitle and figure requests.
* **One run, already cut.** The script makes the cuts and the black, and draws the text cards in the game's own
  UI font on black. The recording is then the whole trailer. Cards are not added afterwards. (This Mac's
  ffmpeg has no text filter, and keeping the cards in Godot keeps one font.)
* **ffmpeg only encodes.** It turns the recording into H.264 (yuv420p) with AAC 48 kHz in an MP4. It sets the
  loudness to about −14 LUFS integrated with a true peak at or under −1 dBTP, where YouTube normalises. A
  `tools/` shell script runs both steps.
* **Camera.** Walking shots use the player's own movement, so the head bob and footsteps are the game's.
  * "Looks away… and back" shots turn the player's view.
  * Held shots stay still or creep forward slowly.
  * The HUD shows only subtitles. The crosshair, prompt, objective and corner clock are hidden; the clock
    appears only in the clock shot, as in the storyboard.
* **The colour drain** at 0:20 is the game's own act change, eased by the grade over its 4 s.
* **Time is squeezed.** In the game the TV stops when act 2 begins and the fan winds down 15 s into act 3. The
  trailer stops them seconds apart in one held shot, using the game's own fades, the fan's slowing pitch and
  blades included. The captions are the game's own text: Rosnah's line, the knocks, and the noticed shoes and
  chair.
* **The still figure** at 0:42 uses the game's still staging at the `still_hallway` anchor.
* **Fonts.** The game's own (Godot's default UI font, the one the HUD uses).
* **Where things live.** The scripts are committed in `tools/`. The video goes to `builds/trailer/`, which git
  ignores. The upload uses rclone's `klrush-drive:` remote into the folder "The Condo trailer". It stays
  private: no share link is made unless the owner asks.

## Left to the builder

* Exact timings within each beat (keep the total at 55–65 s), and slow-push distances and speeds.
* Whether a beat holds still or creeps forward.
* How the script drives the game, provided it goes through the game's own state, signals and nodes and
  changes no gameplay code. A small hook in game code is allowed only if filming is impossible without it, and
  it is noted in the plan.
* Recording format before encoding (Movie Maker's AVI or PNG frames plus WAV), whichever keeps the most
  quality within the disk space.
* The bitrate, as long as the grain and the soft picture survive (no blocky dark scenes).

## How we know it's done

* The MP4 is 1920×1080, 55–65 s long, H.264 with AAC. ffprobe prints these.
* Loudness is measured with ffmpeg's EBU R128 scanner and written down: integrated about −14 LUFS, true peak at
  or under −1 dBTP.
* A contact sheet of one frame per beat is checked against the storyboard by eye, by the controller and by a
  separate reviewer.
  * The spoiler check is on the frames: no window-door, gap, B-11-07 or ending in any frame.
  * The first 4 s read with the sound off.
* The full test suite still passes, and no gameplay code changed except a noted hook.
* The finished file is in "The Condo trailer" on Drive, and `rclone check` reports no differences.
* The owner watches it there. Nobody in this session can listen, so nobody here claims the mix sounds right;
  the loudness numbers are all that is measured.

## Constraints

* Free tools only: Godot, ffmpeg and rclone, already on this Mac. No paid services, no stock media, and no
  AI-generated footage, voices or music.
* Nothing is pushed, merged or published without the owner. The Drive upload is private to the owner's own
  Drive, as asked.
* The Mac is shared, so stop only processes this work starts.
* Deadline: the jam closes 2026-12-01 13:37 PST, and the trailer should be ready well before.
