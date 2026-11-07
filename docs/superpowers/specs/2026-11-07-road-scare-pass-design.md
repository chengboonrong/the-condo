# The road's scare pass (design, 2026-11-07)

## Why

The owner asked for a trailer of real play. It was recorded on local branch feat/play-trailer (d72e072, tools/play_trailer.gd
and .sh, nothing changed in the game) and failed an independent check on taste, because of the game itself:

- The look-back on the walk to the light is no scare. She follows at least 4 m back and 2.45 m up, small and dim in the fog,
  and nothing plays when he turns.
- Some key sounds have no caption: her wet flap while she follows, every roof thump after the first, the engine's roar
  on the overtake (potong). The wall's answer knock in the bedroom has one, but it can show 3–4 s after the knock,
  queued behind other lines.
- In the game's own mix, four key sounds sit under 10 dB over what is around them: the potong roar 4.8 dB, the car dying
  8.7, her wet flap on the walk 9.4, and the bedroom thumps heard at the intercom ("knocks again") 7.0.
- Once the insects stop ("when it goes quiet"), the road at night drops to digital silence between sounds.

The owner chose "make the game scarier first", then the look-back option "shriek, then she drops back", then "right,
write it up". After this is built, the real-play trailer is recorded again.

## Goals

1. **The look-back scare.** On the walk to the light (LightMission's beat `walk`), each time a look back counts (the
   `looked_back` rule breaks: at most twice), she is right behind him.
   - **Where she is:** at his eye height, facing him, where his view is. She is close enough that her face fills at least
     a third of his view's height: about 0.6 m (`CLOSE`) at the default field of view of 72°.
   - **What plays:** a loud sting and her shriek, with the sound caption "[She is right behind you.]".
   - **What follows:** about half a second later she pulls back into the fog, to where she follows now
     (`Her._behind_point`). On the way, within about a second of the sting, his view shows her whole figure: skull,
     hair and the insides hanging from her. The walk goes on, and the look counts as a broken rule exactly as it does now.
   - **Light:** her face is lit and readable with his phone light off (it starts off, and it is the player's choice). For
     the scare she carries a dim, steady fill light of her own, as the mirror's fourth passenger does. It is not a flash,
     so the Reduced flashing setting does not apply. The fill is drawn by the shader warm-up's light states.
2. **The missing captions,** each a sound caption (on `subtitle_requested`, so "Captions for sounds" governs them; it is
   on by default):
   - her first wet flap on the walk: "[Behind you, something wet flaps.]";
   - each roof thump after the first: "[It moves on the roof.]";
   - the potong roar, on every overtake: "[The engine roars.]".
3. **Captions keep time and keep the lines.** On the road and in the flat, a sound caption shows within 0.5 s of its
   sound and never cuts a spoken line short. A spoken line is a quoted line, or one shown whatever the captions setting.
   The road trailer's design (feat/road-trailer, Revision 2) already asks this. The case known to fail today is the
   flat's wall answer: StoryDirector's "[The wall is cold. Something on the other side knocks back. Once.]" waits in the
   queue for 3–4 s.
4. **Louder key sounds in the game's own mix.** Each is at least 10 dB over its bed, measured as in Acceptance:
   - the potong roar;
   - the car dying (`lights_dying`);
   - her wet flap on the walk;
   - the bedroom thumps heard at the intercom. These are louder only at that moment; the `thump3` file and its other
     uses (the wall, DOWNSTAIRS) stay as they are.
5. **No dead silence.** After the insects stop, a low wind stays: quieter inside the car with the windows up, as the
   insects are now. It still reads as quiet: it sits under his footsteps on asphalt.

## Non-goals

- The in-car scares, the flat's other scares, the endings and the bridge stay as they are.
- No change to the rules, the score, the outcomes or any timing in the core. The three bots (keeper, wobbly, breaker)
  end as now (alive 0, saved 4, caught 16, on seeds 1147, 7 and 2026), and docs/playthroughs.md's outcomes are unchanged.
- The trailer tools are not part of this branch (they stay on feat/play-trailer).
- The owner-items list from the bridge (the HUD clock and the rest) is not in scope, apart from goal 3.

## Anti-goals (a failure even if it works)

- **A scare that cheats:** she appears where he isn't looking, or the scare is triggered by anything other than his own
  look back.
- **Mush:** the scare reads as a blur or a dark smudge.
- **Loudness that clips:** in the real-play recording, at the master volume as shipped (0.8), the sting and the louder
  sounds peak no higher than the loudest peak there now (−6.1 dBTP, report.txt of d72e072). The trailer's limiter
  then stays within its 6 dB. The sting is the loudest sound of the walk by RMS, not by peak.
- **Fake quiet:** a wind so loud the "when it goes quiet" beat no longer reads as quiet.
- **Timing by presentation:** a scare that changes when the core's beats happen. The core never waits on her.

## Constraints

- Godot 4.7.2, typed GDScript, Compatibility renderer, web and desktop.
- No paid assets or services, and no external LLM APIs.
- Sounds are made by tools/gen_audio.py (stdlib, deterministic), or are existing files.
- No shader compiles mid-game: any new material or light state is drawn by `RoadMain._compile_shaders`
  (`test_every_road_material_is_warmed` passes).
- Levels are documented in docs/architecture.md "Audio levels". Its rule for sounds within about 1 m of his head holds:
  they are capped at file level + 3 dB (`max_db`), so turning such a sound's play level up does nothing.
- Full test suite green; ROAD-SMOKE ok and SMOKE ok; road perf (`-- --perf`) not worse than now by more than noise.
- Tests and bots are simulation. Nothing here is a human playtest, and nobody here can listen: loudness is judged by
  measurement only.

## Decided (by the owner)

- The scare is "shriek, then she drops back" (goal 1). The look still counts as a broken rule.
- The scope is goals 1–5, then the real-play trailer is recorded again.
- **The trailer taste (2026-11-06):**
  - show the penanggal in full, up close (gore is fine);
  - one real jump-scare;
  - the game's sound captions on screen;
  - every effect clearly audible, measured at ≥ 10 dB over its bed;
  - never shown: his death, Hafiz being caught, any ending, B-11-07, the window-door.
  The full list is in .superpowers/play-trailer-brief.md, "What the trailer is".

## My calls (the owner can overrule them when reading)

1. **Both counted looks get the scare,** not only the first. Each look that counts is a broken rule, so each one is
   punished.
2. **The sting is two sounds:** the flat's stinger (assets/audio/stinger.wav) and a new shriek of hers made in
   gen_audio.py. Her breath (`rattle`) is a breath, not a shriek.
3. **Size wins over distance:** her face fills a third of his view, so she stops at about 0.6 m, not 1 m.
4. **Her own fill light** for the scare, steady and dim (goal 1).
5. **Only her first wet flap on the walk gets a caption.** She flaps every 3–6 s, and a caption each time would crowd
   Hafiz's voice and Mei's choices. The look-back has its own caption.
6. **Each roof thump gets a caption; the potong roar gets one on every overtake.** The window knocks stay one caption for
   the set (no gap was found there).
7. **Goal 3 covers the road too,** because the new road captions can otherwise cut a line short: the HUD has one text
   slot today, and a new caption replaces whatever is on it.
8. **The bedroom thumps get louder only at the intercom moment** (goal 4).
9. **The wind loop** is made in gen_audio.py. Heard about 14 dB under his walking steps on asphalt: those are about
   −34 dB, so the wind is about −48 dB, and lower inside the car. It is a mono loop at half rate, as the other loops
   are, about the insects loop's size (≈530 KB) or less.
10. **The caption texts** are as in goals 1–2. They follow the road's style: a bracket, a short plain sentence, no names.

## Left to the builder

- How her look-back pose is made in her.gd: a new mode next to `come_for` (which already brings her to the camera's height
  `LOW_IN` and stops her `CLOSE` to it), how she gets there in the same frame as the look counts, and how she pulls back.
- **How the core tells the presentation a look counted:** a new road cue, emitted from the core where the `looked_back` rule
  breaks. It is the presentation's only trigger, and the bots ignore it.
- **How goal 3 is met:** e.g. a second HUD line for sound captions, or a caption queue that never delays a sound's caption.
  Either way it follows goal 3's rule.
- **How each sound reaches its 10 dB:**
  - louder files;
  - play levels, where the cap allows;
  - or lowering what is under it for a moment (e.g. the engine loop under the roar).
  Not every sound needs the same means.
- How the shriek is synthesised.
- Any still or tool they need to check the scare by eye. Stills made for checking stay out of the repository.
- Tests, at the project's usual size:
  - the cue fires on a counted look during the walk, and at no other time;
  - the captions fire once where stated;
  - a sound caption doesn't cut a spoken line short;
  - the bots' outcomes are unchanged.

## Acceptance

1. Unit tests for the cue and the captions pass, and the full suite is green. ROAD-SMOKE ok and SMOKE ok.
   docs/playthroughs.md regenerated with the same outcomes and scores as now.
2. docs/architecture.md: the "Audio levels" table gains the sting and the shriek at the look-back, the wind and every
   changed level. The road's prose gains the look-back scare, the new cue and the caption rule.
3. **The real-play trailer.** Recorded again with tools/play_trailer.gd/.sh from feat/play-trailer, on a local branch
   that has this branch under it (main is not touched). The pilot may need new waits for the new beats. With every dip
   in its CLIPS set to 0, report.txt shows:
   - each key sound ≥ 10 dB over its bed in the game's own mix (the "game mix" column), including the look-back's sting;
   - no stretch of the road's night clips below −70 dBFS RMS for 100 ms or more;
   - limiting ≤ 6 dB and no recorded sample peak over −0.1 dBFS.
4. **By eye, from the real-play recording's frames:**
   - at the sting, her face fills at least a third of the frame height, lit and readable;
   - within about a second, one frame shows her whole figure;
   - in the recording (not only in the cut), the new captions show with their sounds, and no spoken line is cut short
     by one;
   - the wall's answer caption is up within 0.5 s of its knock.
5. An independent check of the new trailer against the trailer taste above passes before it is uploaded privately to
   Drive ("The Condo trailer", no share link).
