# How Chilla's Art makes its games feel scary, and what fits THE CONDO

2026-11-05. A study for the owner. It lists options and trade-offs and marks what I would choose. Nothing
here is decided or built.

**How this was researched.** Studio claims come from the studio's site, ten official Steam store pages and
two interviews in which the studio speaks for itself (Famitsu 2020, Gendai 2025). Their wording was checked
against the page text. Secondary sources (one review, three Game*Spark articles) are labelled as such.
Observations marked **[SS]** are mine, made from looking at the store screenshots of six games. Store
screenshots are marketing images and may not match default in-game settings. Engine facts cite the Godot 4.7
docs. No game was downloaded or run. Source IDs in brackets (for example [P4]) refer to the source list at
the end. English quotes from the Japanese interviews are my translations; the originals are in
[section 7](#7-what-the-studio-says-about-its-own-approach) or inline.

## Summary: the five most useful findings

1. **The look is a believable place, softened by a switchable VHS filter. It is not pixel art.** From 2019
   to 2020 the store pages promise "photo-realistic graphics". From 2022 to 2023 they say "believable
   environment". Every page from 2019 to 2023 mentions a VHS filter, and all but one describe it the same way
   ("phosphor screen trail and bleeding, VHS tape noise, interlacing, and jitter"). Most say it can be
   turned off in the options menu [P2–P9]. In the screenshots the filter is soft smear, colour bleed and
   noise, not chunky pixels [SS]. The studio's own reason for the retro look was cost: their previous,
   graphics-heavy game took too much time, so they followed the retro-horror trend [I1]. The 2024 and 2025
   store pages no longer mention a VHS filter [P10, P11].
2. **They start from a real, specific, ordinary place.** "We find things in Japanese scenery that we think
   are scary, and turn them into games" [I1]. Their aim is "Japanese-ness, fear unique to Japan", so they
   often build a game around a place: a convenience store, a bathhouse, a tunnel [I2]. Many give you a job,
   usually at night: convenience store, café closing shift, deliveries, security, bathhouse [P4, P7, P9,
   P10, R5].
3. **The fear is slow and the story is not explained.** The convenience store game is one where "you
   gradually come to feel fear" (じわじわと) [I1]. The studio does not explain too much, because "without
   mystery, fear thins out". It keeps on-screen text to a minimum [I2]. A reviewer noted that the game holds
   back for most of its length [R1].
4. **Horror needs a safe, warm baseline to break.** The studio says what scares people is anxiety
   (不安). It compares horror to "a log cabin in heavy snow": danger outside a safe place. It adds warm,
   human details to its games "to emphasise the gap between fear and safety" [I2].
5. **"Someone is behind you" is the promise, not the monster.** Store pages sell the feeling that someone
   is watching or behind you [P2, P3, P5, P6]. In the screenshots, figures stand still under the only light
   at the end of a corridor or face a wall in a lit window [SS]. Most games are short (about 20 minutes to 2
   hours) and cheap, and most have two endings [P2–P5, P9].

For THE CONDO, my top three are: options for filter, FOV and head bob (R1); an optional lower 3D render
resolution with a colour grade per act (R2, R3); and a figure that stands still where you can see it
(R4). See [Recommendations](#recommendations-for-the-condo).

## The studio

* **Who.** It started as a sibling team: an elder brother who is a 3D artist and a younger brother who
  programs [I1]. The 3D artist worked in the United States until 2018. He built Japan-set horror because he
  knew of few indie horror games set in Japan [I2]. The middle brother started programming with no
  experience. The youngest brother and two friends now help [I2]. Famitsu says the studio moved to "retro,
  Japanese-taste horror" from September 2019 and releases games in quick succession [I1].
* **Engine.** Unity, learned while making the games [I1]. *Cursed Digicam* (2025) moved to Unreal Engine
  because a game about spirit photos "first had to draw the world realistically" [I2, P11].
* **The site** lists 24 games and links to Steam, X, Patreon and YouTube. It has no statements about style
  [P1].
* **Their influences**, in their words, are more often indie games (*Detention*, *DreadOut*, *Home Sweet
  Home*, *Granny* and others) than *Silent Hill* or *P.T.* [I1]. Later: Asian horror films and dramas, and
  other games [I2].

## 1. Visual style

### What the studio says

| Year, game | Store wording [source] |
|---|---|
| 2019 *Okaeri* | "An atmospheric photo-realistic graphics intensifies the horror experience. The minimalistic design makes the player fully immersed in the ambiance." [P2] |
| 2019 *Stigmatized Property*, 2020 *The Convenience Store* | "An atmospheric, photo-realistic graphics intensifies the horror experience." [P3, P4] |
| 2021 *The Night Way Home* | "Atmospheric graphics add to the terror." [P6] |
| 2022 *The Closing Shift*, 2023 *Parasocial*, *Night Security* | "An atmospheric, believable environment intensifies the horror experience." [P7, P8, P9] |
| Every page from 2019 to 2023 except *Night Security* | "VHS aesthetic emulates look and feel of CRT screens including phosphor screen trail and bleeding, VHS tape noise, interlacing, and jitter in the analog video signal" (wording varies slightly) [P2–P8] |
| 2023 *Night Security* | "VHS effect can be toggled on/off in the options menu." No description. [P9] |
| 2024 *The Bathhouse* remake | "Enhanced graphics and environmental detail", "Improved character models". No VHS line. [P10] |

**Why they chose it.** Famitsu asked about the move, from September 2019, to a "VHS-like, early-PlayStation,
low-poly" retro style. The answer, in full meaning: perhaps by chance. Their previous game, *Blame Him*, was
graphics-focused, and 「開発に必要な時間と労力がハンパなくて、もう同じことは絶対にしたくないと思いました」
("the time and effort it needed were enormous; we never wanted to do that again"). Retro horror was trending
around them, and they wanted 「もっとインディーズらしいもの」 ("something more indie") [I1]. In 2025, asked
why their graphics vary, they said, laughing, that they partly "got bored of the same graphics"
(同じグラフィックだから飽きてしまった). Rough polygons are quick to make. Detailed CG "looks premium but takes
time" [I2]. So the studio frames the filter as a
production choice and an atmosphere layer, not as the source of the fear.

A secondary feature describes the style from *Aka Manto* (2019) as "low-poly with deliberately lowered image
quality and a VHS-style noise filter", and 2022–2023 as "short, cheap, PS1-style" [R4]. That is the writer's
reading.

### What the screenshots show [SS]

* **Softness, not blocks.** At 1:1, *Stigmatized Property* and *Night Delivery* show horizontal smear,
  colour bleed, heavy luminance and colour noise, and in *Night Delivery* VHS tracking lines and a magenta
  fringe. Edges are soft. I saw no nearest-neighbour pixel blocks.
* **Real-world assets.** Japanese packaging, signage, vending machines, lift panels, open-air flat
  corridors. The café in *The Closing Shift* carries the studio's own name ("CHILLA'S COFFEE"), so no real
  brand is needed.
* **Colour grade.** Each game has its own cast: cold blue-white (*The Convenience Store*), green night sky
  (*Stigmatized Property*), desaturated sepia-green (*The Closing Shift*), magenta (*Night Delivery*),
  teal-grey (*Night Security*). Blacks are crushed. Strong vignettes, some with rounded, CRT-like corners.
* **Lighting.** A few hard sources in large darkness: fluorescent tubes, a vending machine, a street lamp,
  the bright shop seen from a dark car park. Bright sources bloom and streak.
* **The later look.** *The Bathhouse* remake (2024) screenshots are clean and high-fidelity: steam, wet
  tiles, warm tungsten against cold tubes, no visible VHS artefacts.

### UI and subtitles [SS]

*Night Security* shows a dialogue line in plain white text with a soft shadow at the bottom left, with a
small ▼ to advance, and an "ESC" back icon on an inspect view. *The Bathhouse* shows a small speaker label
(大家, "landlord") above a short white line. One *Night Delivery* screenshot carries the title in red serif
type. *Okaeri* has "native Japanese voice acting" [P2]. I could not confirm a font or a subtitle style
guide from any text source.

## 2. Camera and post-processing

* **Filter switch.** *Okaeri*, *Stigmatized Property* and *Parasocial* do not mention a switch [P2, P3, P8].
  *The Convenience Store*, *Night Delivery*, *The Night Way Home*, *The Closing Shift* and *Night Security*
  say the VHS effect can be turned off in the options [P4–P7, P9]. A reviewer of *The Convenience Store*
  grants that "a filter that obscures your visuals adds an extra layer of uncertainty". He objects to a
  "camera glitch" effect that "makes no sense when I'm supposed to have just regular human eyeballs", and
  ends: "If you're going to insist on hiding your design limitations behind a filter, at least work the
  filter into the game's story." He notes the game already has an option to turn it off [R1].
* **Quality options.** The store notes tell players to "Disable or Lower Shadow/Texture/Screen
  Resolution/SSR Quality for better performance" [P7] or to "Lower quality setting" [P9]. Requirements were
  low early ("Integrated graphics" for *Okaeri* and *Stigmatized Property* [P2, P3]) and rose to a GTX 1060
  for the 2024 remake [P10].
* **Head bob and sway.** Game*Spark (secondary) wrote that *Night Security*'s 「カメラ操作の独特な挙動や移動時の揺れ」
  (odd camera behaviour and sway while moving) might cause motion sickness [R2]. I found no studio statement on
  head bob or field of view, and no options list. **FOV: could not be confirmed.**
* **Date and timestamp overlays.** One *Night Security* screenshot is a security-camera view with "CAM 3F",
  "10/23" and "LIVE" overlaid [SS]. I could not confirm a camcorder date stamp over normal play in any
  title.
* **Trailers.** I did not review trailer descriptions beyond the store pages' movie entries, which carry no
  text.

## 3. Settings: ordinary places and night jobs

| Game | Place and job [source] |
|---|---|
| *Okaeri* (2019) | "It's 6:00 pm, coming back home expecting a welcome from your mom" to a newly moved-to house [P2] |
| *Stigmatized Property* (2019) | haunted apartment rooms with "cheap rents"; "You are alone in your apartment...or are you really?" [P3] |
| *The Convenience Store* (2020) | "a college girl on a night shift" [P4] |
| *Night Delivery* (2021) | delivering boxes as a courier and meeting the residents of a block of flats [R5]; open corridors and a lift panel in the screenshots [SS] |
| *The Night Way Home* (2021) | a schoolgirl walking home who "enters an eerie world" [P6] |
| *The Closing Shift* (2022) | "a girl on a closing shift" at a café [P7, R3] |
| *Night Security* (2023) | night security in an old building [P9, R2] |
| *The Bathhouse* (2024) | "working at a bathhouse" [P10] |

**Why ordinary places work, in the studio's words.** They look for scary things in ordinary Japanese
scenery [I1], build around places where Japanese fear shows easily [I2], and see horror as anxiety set
against safety [I2]. My reading, not theirs: a familiar place gives the player a baseline, so a small
change reads as wrong without explanation. THE CONDO's "noticing what moved" mechanic depends on exactly that
baseline.

Note how close THE CONDO's premise already is: *Okaeri* is coming home at night, *Stigmatized Property* is
being alone in a cheap flat, and *Night Delivery*'s screenshots show open-corridor flats like a Malaysian
low-cost condo.

## 4. Pacing

* **Length and endings.** About 20–40 minutes (*Okaeri*), 30 (*Stigmatized Property*), 40 (*The
  Convenience Store*), 1–2 hours (*Night Delivery*), 2–4 hours (*The Night Way Home*), 60–90 minutes
  (*Cursed Digicam*) [P2–P6, P11]. Two endings is the usual pattern [P3, P4, P5, P9], described as "good
  and bad" on two pages [P3, P4]. *The Bathhouse* remake has "multiple endings" [P10]; *Cursed Digicam* has
  one [P11]. Early prices followed playtime: 300 yen for psychological horror, 500 for survival horror,
  which has replay value [I1].
* **Routine, then wrongness.** A reviewer of *The Convenience Store* describes four nights, each starting
  with a walk to work and a menial task left by the manager. He writes that "the menial tasks of taking out
  the garbage and stocking the shelves made the game far scarier", because the chores never let the
  supernatural feel normal, and that the game "restrains itself for about 90% of the game" [R1].
  Game*Spark on *Night Security*: 「作業に集中している途中で不意に怖くなる」 ("while you concentrate on the
  work, it suddenly turns scary") [R2]. The studio describes *The Convenience
  Store* as suspicious people coming in and paranormal events during a midnight shift, so that "you gradually
  come to feel fear" [I1].
* **Leave gaps.** 「謎がないと恐怖は薄まるので説明しすぎないようにはしています」 ("without mystery, fear thins out,
  so we try not to explain too much"). Imagining what you don't know is like a roller coaster climbing,
  "where it feels most frightening" [I2].

## 5. Sound

Evidence is thin.

* Many store pages ask for headphones in the requirements notes: "Wear headphone" [P2, P3, P4], "Wear
  headphones and play in the dark" [P5], "Turn off room lights and Put your headset on" [P8, P10].
* *Okaeri* has native Japanese voice acting [P2]; *Night Security* and *The Bathhouse* show Japanese
  dialogue subtitles [SS].
* A reviewer says the game makes you wary of "the innocuous beeping of an automatic door or the whir of an
  automatic toilet lid", and calls the audio "nothing groundbreaking" but effective at turning the mundane
  spooky [R1].
* **Could not confirm:** how they use music, silence or ambience beds. No source I could load discusses it.

## 6. Scare design

* **Someone behind you.** "You are alone, but feels like someone is watching you" [P2]. "Makes you feel like
  someone is behind you during gameplay" [P5], "...there is someone behind you" [P6]. Game*Spark reports the
  same feeling for *The Closing Shift* and *Night Security* [R2, R3].
* **Figures at a distance, held still.** In *Night Security* a figure with a mop stands under the only
  light at the end of a corridor, a dark pool on the floor. In *Stigmatized Property* a person stands in a
  lit window facing the wall, back turned [SS].
* **Intruders.** Suspicious people come into the shop [I1].
* **Faces.** The reviewer: "This also might be unintentional, but the characters' faces are insanely
  unsettling", from "slapping a photo onto a texture" [R1]. NPC faces in the *Night Security* and
  *Bathhouse* screenshots are realistic but stiff [SS].
* **Jump scares versus dread.** The studio talks about slow build and anxiety [I1, I2]. A reviewer says that
  even when it goes "full spooky, it doesn't devolve into a series of jumpscares" (his view) [R1]. I found
  no studio statement on jump scares.
* **Things that change when you look back.** I could not confirm this as a Chilla's Art mechanic. In THE
  CONDO it is already the core mechanic [C2].

## 7. What the studio says about its own approach

All verified against the article text. Translations are mine.

| Quote | Meaning | Source |
|---|---|---|
| 「精神的ホラー系はただ単に日本の風景を見て怖いと思ったものを見つけたら、それらをゲーム化しているだけです」 | For psychological horror, we just find things in Japanese scenery we think are scary and make games of them. | [I1] |
| 「シンプルな3D背景やチープな演出でそのスリルの心理を追求するおもしろさ」 | (Small indie horror is appealing because of) the fun of pursuing the psychology of thrill with simple 3D backgrounds and cheap staging. | [I1] |
| 「日本らしさや日本独特の怖さを表現したいというのが軸」 | Our core is expressing Japanese-ness and fear unique to Japan. | [I2] |
| 「文字情報は最低限にしています」 | We keep text to a minimum (so players experience events rather than read them). | [I2] |
| 「“不安が怖い”のだと思います」 | I think it is anxiety that is frightening. | [I2] |
| 「大雪の中のログハウス」 | (Horror's appeal is) a log cabin in heavy snow. | [I2] |
| 「自作に人の感情や温かみを感じられる描写をよく入れるのも、恐怖と安心感のギャップを強調したいからかもしれません」 | I often put human feeling and warmth in my games, perhaps to stress the gap between fear and safety. | [I2] |

A Tokyo Weekender interview with the studio could not be loaded (HTTP 403), so nothing from it is used.

## 8. THE CONDO today (from the repo)

* **Look.** Filmic tonemap, glow, light fog, ambient light, exposure tied to the Brightness slider
  [C5: `apartment_builder.gd` `_build_environment`]. Grain (0.035, 24 changes a second) and a vignette in one
  `canvas_item` overlay that does not read the screen [C2, C5: `hud.gd` `FILM_SHADER`]. The written rules: "No
  blood, no red fog, no chromatic aberration. The fear comes from the place being ordinary" [C2]. MSAA 3D 2×,
  `canvas_items` stretch, 1600×900 base [C5: `project.godot`].
* **Camera.** Vertical FOV 72 [C5: `player.tscn`]. That is about 104° horizontal at 16:9 (my arithmetic,
  using the Camera3D docs' convention that `fov` is vertical [G9]). Head bob about 0.025 m at walking speed, no setting
  [C5: `player_controller.gd`]. The phone light is a 40° spot, the only shadow caster [C2, C5].
* **Options.** Brightness, mouse sensitivity, volume, invert Y, captions for sounds, reduced flashing
  [C5: `pause_menu.gd`, `settings.gd`]. No FOV, head bob or filter setting.
* **HUD.** Objective at top left, a red 11:47 clock at top right, prompt, subtitles, inspection panel
  [C5: `hud.gd`]. The start card already says "Headphones recommended".
* **Scares.** The figure appears out of view and vanishes 0.3 s after any part of it is on screen
  [event-catalog.md]. Shifts happen only unobserved [C2].
* **Rebuild in progress.** Five of about twelve objects have Blender models (chair, table, shoe rack,
  clock, shoes), with 512 px textures (256 for the shoes) [C6]. The spec caps textures at 1024 px, defaults
  to 512, and grows the web download by at most 8 MB [C4].
* **Performance.** 60 fps in headless WebKit and 120 in Chromium on an M1 Max, no frame over 25 ms; GPU time
  is not reported by Compatibility; integrated graphics and real Safari are unmeasured [C3].

## Recommendations for THE CONDO

Ranked by impact for the effort. "Impact" is my judgement of how much it adds to the scare or the look for
a jam voter. Each item says what changes, roughly how in Godot 4.7.2 Compatibility, and what it risks. The
owner decides.

| # | Option | Impact | Effort | My call |
|---|---|---|---|---|
| R1 | Options: filter on/off, FOV slider, head-bob slider | Medium (comfort, trust) | Small | Do |
| R2 | Lower 3D render resolution as the "filter" (½, nearest), HUD stays sharp | High (look, cohesion) | Small to medium | Do, if WebKit and readability tests pass |
| R3 | Colour grade per act: warm and safe in act 1, colder after | Medium to high | Small | Do |
| R4 | A figure that stands still in a lit spot, seen and held | High | Small to medium | Do |
| R5 | Routine first: the player puts the things that will move in their places | High | Medium | Strongly consider; touches story and tests |
| R6 | Less on-screen text | Medium | Small | Do, gently |
| R7 | Everyday sound beds, and silence when they stop | Medium | Medium | Consider |
| R8 | Grain at the low-res pixel size, faint luminance smear | Low to medium | Small | With R2 only |

### R1. Options: filter, FOV, head bob

* **Evidence.** Most of the studio's store pages promise the filter can be turned off [P4–P7, P9], and a
  reviewer pointed to that option [R1]. Game*Spark said the sway might cause motion sickness [R2]. Xbox
  Accessibility Guideline 117 says to "avoid the use of camera shake, camera bobbing effects ... or provide
  an option to turn off these behaviors" and to "provide adjustable field of view settings" [X1].
* **Change.** Three new rows in the pause menu, using its existing `_slider` and `_check` helpers
  [C5: `pause_menu.gd`], and three keys in `Settings.DEFAULTS` (for example `fov` 72, `head_bob` 1.0, `filter`
  on).
* **How.** FOV: `camera.fov = float(Settings.get_value("fov"))` on `Settings.changed`. Offer about 60–80; it is
  vertical [G9]. A narrower FOV makes rooms feel tighter and distant figures larger; a wider one reduces the
  "fishbowl" effect for some players [X1]. Head bob: multiply `_bob` by the setting in `_update_steps`
  [C5: `player_controller.gd`]. Filter: switches R2 and R8 together.
* **Risk.** Almost none. The pause menu grows by three rows.

### R2. Lower 3D render resolution, HUD kept sharp

* **Evidence.** The studio's filter softens a believable scene [P2–P9, SS] and was chosen partly to save
  production time [I1]. That matters here: the rebuild has five of about twelve objects done [C6] and the
  jam closes on 1 December [C1]. A softer image narrows the gap between new models and box-built decor, which the spec
  wants to "sit in the room" [C4].
* **Change.** The 3D image renders at half resolution and is scaled up; text, prompts, subtitles and the
  inspection panel stay at full resolution.
* **How, option A (smallest change).** The root viewport's 3D scaling:
  ```gdscript
  var vp := get_viewport()
  vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST  # or SCALING_3D_MODE_BILINEAR for softer
  vp.scaling_3d_scale = 0.5
  ```
  The docs say Nearest "has no additional rendering cost", values below 1.0 "speed up 3D rendering", and
  scales of 1/integer (0.5, 0.3333, 0.25) avoid uneven pixels [G2, G3]. Resolution scaling does not apply to
  2D, so the HUD stays crisp [G1]. **Unconfirmed:** the docs say bilinear scaling is "available in all
  renderers" [G1] but do not say whether Nearest works in Compatibility. Test it in the web build in WebKit and
  Chromium first. Bilinear is the softer, more VHS-like choice and is documented for all renderers.
* **How, option B (fallback).** Put the 3D world and camera inside a `SubViewport` under a
  `SubViewportContainer` with `stretch = true` and `stretch_shrink = 2`, and set the container's texture
  filter to nearest. `stretch_shrink` "divides the sub-viewport's effective resolution by this value"
  [G4]. This is documented and certain, but it moves the player, `GameStage` visibility checks and input
  under a new node. More work and more test risk.
* **Not recommended: the `viewport` stretch mode.** It renders everything, the HUD included, at the base
  size [G5], so subtitles and notices would turn pixelated.
* **Keep the look the same on every screen.** The browser canvas size varies (itch.io embed, fullscreen).
  Pick the divisor from the window height, for example `n = max(1, round(height / 450.0))` and
  `scale = 1.0 / n`. The 3D image is then always about 450 lines tall at an integer scale.
* **Risks.**
  * *Readability.* The mechanic is noticing moved shoes, a chair and a tap [C1]. At 450 lines they should
    still read (untested); at a third of 900 (300 lines) the shoes may be a handful of pixels. Test with the
    spec's storyboard stills [C4] at scales 1.0, 0.5 and 0.33 side by side.
  * *Shimmer.* With Nearest, thin parts (window grilles, chair legs, clock hands) shimmer when the camera
    moves. MSAA 2× smooths polygon edges [G3] but not texture detail. Bilinear shimmers less.
  * *WebGL2 cost.* Fewer 3D pixels should lower GPU work [G2, G3], which helps the unmeasured integrated-graphics
    case [C3]. The same knob doubles as a performance setting, as the studio's own store notes suggest [P7].
    Still, re-run the `--perf` tour in WebKit and Chromium with the setting on and off [C3].
  * *Realism.* The owner asked for "more realistic" [C4]. In my view a half-resolution image is less sharp
    but can look more real, which is what the studio's "photo-realistic" plus VHS pairing bets on [P3, P4].
    Judge from the stills.

### R3. Colour grade per act

* **Evidence.** Each Chilla's Art game has its own colour cast [SS]. The studio adds warmth to make the gap
  between fear and safety larger [I2]. THE CONDO already pairs warm and cool fittings [C2].
* **Change.** Act 1 (home after the shift) is a little warmer and fuller. From act 2 the grade cools and
  desaturates a step at a time. B-11-07 is the most drained.
* **How.** `Environment.adjustment_enabled`, `adjustment_contrast`, `adjustment_saturation`, and
  `adjustment_color_correction`, which takes a `GradientTexture1D` or a 3D LUT [G8]. Adjustments are
  supported in Compatibility [G6]. Tween between grades on the act change. No new materials.
* **Risks.** Changing the colour-correction texture mid-game might compile a shader variant. Watch for a
  first-time hitch in the `--perf` tour, as with the hitches already found [C3]. Keep contrast modest: Compatibility
  has no debanding (`use_debanding` "has no effect" there [G2]), so dark gradients band. The grain is what hides
  that today [C2].

### R4. A figure you are allowed to see

* **Evidence.** Store pages sell "someone behind you" [P2, P5, P6]. Screenshots hold a still figure in a lit
  spot at a distance, or facing a wall [SS].
* **Change.** Today the figure vanishes 0.3 s after any part of it is on screen [event-catalog.md], so it is
  only ever a glimpse. Add a rarer staging: it stands still under one light at the far end of a space (the
  gap corridor under a caged bulkhead, the hallway at night), facing away or facing the wall. It stays while
  watched and is gone the next time the player looks away or turns a corner.
* **How.** A variant of the existing silhouette event with the vanish rule inverted, still reported as a
  sighting so the entity retreats [C2]. It reuses the figure's material, which the shader warm-up already
  covers [C3].
* **Risks.** Held in view, the figure must survive being looked at. That depends on the Blender figure in the
  rebuild [C4]; with today's capsule mannequin it may read as a dummy. R2 helps here: softness hides the
  limits of a still pose. Keep it a person, not a monster [C4].

### R5. Routine first, so the wrongness has a baseline

* **Evidence.** The chores in *The Convenience Store* are where the unease comes from [R1]. The scare comes
  while you are busy with the work [R2]. Fear builds gradually [I1].
* **Change.** Act 1 already walks the player past the shoes, the tap and the chair [C1]. Make it hands-on:
  put the work shoes on the rack, hang the apron on the laundry rack, turn the tap off after washing, set the
  teh tarik bag on the table. Each is one interaction. Each later becomes a shift target, and the player
  remembers placing it.
* **How.** Story beats in `StoryDirector` with fail-safes, like the existing `home` beat [C2]. The shoes and the
  chair already have variants [C4]. The apron on the rack also ties to the figure's apron [C4].
* **Risks.** Act 1 gets longer, and the jam run is short (10–15 minutes [C2]). The simulated playthroughs and
  story tests must be updated [C2]. This is the largest change here, so it is the first to cut if time runs out.

### R6. Less on-screen text

* **Evidence.** The studio keeps text to a minimum and does not explain too much [I2].
* **Change.** Fade the objective out a few seconds after it changes, and show it again on a key or after a long
  idle. Keep prompts, captions and the clock.
* **Risks.** Jam voters get less guidance. The story's fail-safes [C2] limit how lost a player can get.

### R7. Everyday sound, then silence

* **Evidence.** Thin. The studio asks for headphones [P2–P5, P8, P10]. A reviewer singled out ordinary
  noises turned uneasy [R1]. How they use music or silence could not be confirmed.
* **Change (my suggestion, not studio evidence).** Quiet act-1 beds that say "home": the ceiling fan, a
  fridge hum, distant traffic or a neighbour's TV through the wall. In later acts one of them stops, and the
  silence is the signal.
* **How.** Looping `AudioStreamPlayer3D`s at bed level in the existing level table [C2]. Every sound is
  synthesised today [C1], so these must be made too.
* **Risks.** Mix time. A bed that stops must be quiet enough not to read as a bug.

### R8. Grain at the internal pixel size

* **Change.** With R2 on, make the existing grain snap to the 3D pixel grid so it looks like part of the
  image: in `FILM_SHADER`, hash `floor(FRAGCOORD.xy / px)` where `px = 1.0 / scaling_3d_scale` [C5]. Optionally
  add a faint horizontal luminance smear.
* **How and cost.** The grain overlay does not read the screen, so it stays cheap. A smear needs
  `hint_screen_texture`; the first node that uses it makes Godot do "a full-screen copy to a back-buffer"
  [G10], and blurs are "resource intensive" [G7]. Keep any screen read to one pass with two or three taps,
  and measure it.
* **Risks.** Small. The grain must stay in some form even with the filter off, because it hides banding [C2].

### What not to borrow

* **The full VHS/CRT emulation** (colour bleed, tracking lines, interlacing jitter, rounded CRT frame). It
  breaks the repo's own rule against chromatic aberration [C2]. It implies a camera that no one in the story
  holds; the reviewer asked that a filter at least be worked "into the game's story" [R1]. It is the
  studio's most recognisable surface, repeated almost word for word across its store pages [P2–P8], and
  THE CONDO's premise already sits close to *Okaeri* and *Stigmatized Property*. Copying the look too would
  read as imitation. A per-frame noise layer is also
  likely to break up after video compression in the trailer (my expectation, not tested).
* **A camcorder date or "REC" overlay during play.** The only overlay I could confirm is a CCTV view in
  *Night Security* [SS]. THE CONDO has no camera in the fiction. Its red 11:47 clock already does the timestamp
  job.
* **Photo-textured, realistic faces.** The uncanniness may be accidental [R1], and THE CONDO has no NPC faces:
  Rosnah is a voice and the figure is near-black [C2]. Keep it that way.
* **Darkness the player cannot see through.** On one outdoor night the reviewer "couldn't even tell what I
  was touching" and writes: "I almost quit when I couldn't see in front of me" [R1]. Jam
  voters play on laptops in lit rooms, and the moved-object mechanic needs things to be visible. Keep the
  Brightness slider and the phone light.
* **Strong camera sway** [R2, X1]. Keep the bob small, and make it switchable (R1).
* **Japanese folklore figures and jump-scare stingers as the main tool.** The studio's strength is a
  specific real place [I1, I2]. THE CONDO's equivalent is the Malaysian low-cost condo, which the Look section
  already describes [C2].

### Risks across all options

* **WebGL2 cost.** R2 should reduce GPU load; R8's screen read and R3's LUT add a little. All must pass the
  existing `--perf` tour (WebKit 60 fps, no frame over 25 ms) and keep the shader warm-up complete [C3].
  Integrated graphics remain unmeasured [C3].
* **Readability.** The game is judged on a voter's laptop, often in an itch.io embed. Test R2 at the
  smallest likely canvas.
* **Motion sickness.** R1 covers it. Do not add sway or shake elsewhere.
* **Accessibility.** One "Filter" switch should turn off R2 and the smear in R8. Brightness, captions and
  reduced flashing exist [C5].
* **Too close to the source.** Borrow the principles (ordinary place, routine, warmth then wrongness, still
  figures, few words), not the surface (the VHS frame, the red title cards, Japanese settings).

### How this meets the Blender rebuild and the trailer

* **Texture size.** At half resolution in a 1600×900 window, the 3D image is 800×450. At 2 m with a vertical
  FOV of 72, one metre covers about 150 of those pixels, so a chair seat is about 70 pixels across (my
  arithmetic). A 512 px texture already holds more texels than the screen shows. Keep 512 as the cap. 256 is
  enough for small or distant objects, which shrinks the download within the spec's 8 MB budget [C4]. Keep
  512 for things seen up close or in trailer close-ups (the clock face, the intercom, the apron) [C4].
* **Normal and roughness maps.** Fine normal detail mostly disappears at half resolution. Value contrast in
  the colour map (dirt, wear, baked ambient occlusion) carries further. The spec leaves baking AO to the
  builder [C4]; with R2, baking it into the colour map is the better use of time.
* **Triangles.** No need for more. Silhouette matters more than bevels under 1 cm. Thin parts must cover at
  least two internal pixels at play distance or they shimmer: give the clock hands enough width to read
  11:47 [C4].
* **Cohesion.** R2 narrows the gap between rebuilt objects and the box-built rooms. That lowers the risk if
  not all twelve objects are done by the deadline, but it is not a reason to skip the figure, which R4
  depends on.
* **Trailer.** The trailer must show what is in the game [C4], so film it with the shipped default. If R2 is on,
  capture at 1920×1080 with scale 0.5 for an exact 2× image. Subtitles are 2D and stay sharp, which serves
  the "readable with the sound off" goal [C4]. Consider lighter grain for capture if test encodes break up.
* **Before deciding.** Render the spec's nine storyboard stills [C4] at scale 1.0 and 0.5, with and without
  the act-2 grade, and compare them side by side. That is one afternoon and answers most of the open
  questions above.

## Open questions for the owner

1. Should the default be the sharp image or the half-resolution one (R2)? And Nearest (crisper) or Bilinear
   (softer, closer to tape)?
2. Is the "no chromatic aberration" rule [C2] still wanted? This study recommends keeping it.
3. Is a longer, hands-on act 1 (R5) worth the test changes this close to the deadline?

## Sources

All web pages were read on 2026-11-05.

**Studio (primary)**

* [P1] Chilla's Art, official site (games list): https://www.chillasart.co.jp
* [P2] *Okaeri* (2019), Steam: https://store.steampowered.com/app/1147960/
* [P3] *Stigmatized Property* (2019), Steam: https://store.steampowered.com/app/1162680/
* [P4] *The Convenience Store* (2020), Steam: https://store.steampowered.com/app/1228520/
* [P5] *Night Delivery* (2021), Steam: https://store.steampowered.com/app/1611490/
* [P6] *The Night Way Home* (2021), Steam: https://store.steampowered.com/app/1671550/
* [P7] *The Closing Shift* (2022), Steam: https://store.steampowered.com/app/1843090/
* [P8] *Parasocial* (2023), Steam: https://store.steampowered.com/app/2314720/
* [P9] *Night Security* (2023), Steam: https://store.steampowered.com/app/2367230/
* [P10] *The Bathhouse Restored Edition* (2024), Steam: https://store.steampowered.com/app/2989950/
* [P11] *Cursed Digicam* (2025), Steam: https://store.steampowered.com/app/3334550/

**Interviews (the studio's own words, published by the press)**

* [I1] Famitsu, ヘイ昇平, 2020-02-20, "『事故物件』『赤マント』『雪女』。Steamで話題の兄弟ホラーゲームクリエイター"Chilla's Art（チラズアート）"インタビュー": https://www.famitsu.com/news/202002/20191858.html
* [I2] 現代ビジネス (Gendai), むくろ幽介, 2025-03-02, "伝説のホラーゲームをつくる驚異の発想…チラズアート（Chilla's Art）が語る「恐怖の本質」", pages 1–3: https://gendai.media/articles/-/147820

**Secondary (observations by others, not the studio's intent)**

* [R1] Ted Hentschke, "Ultra-Indie Spotlight Sundays – The Convenience Store | 夜勤事件", Dread Central, 2020-02-24: https://www.dreadcentral.com/editorials/475159/ultra-indie-spotlight-sundays-the-convenience-store-%e5%a4%9c%e5%8b%a4%e4%ba%8b%e4%bb%b6-2/
* [R2] いわし, "チラズアート新作『夜間警備』Steamでリリース", Game*Spark, 2023-06-17: https://www.gamespark.jp/article/2023/06/17/131210.html
* [R3] いわし, "バイト先カフェの閉店間際に体験する恐怖…チラズアート最新作『The Closing Shift | 閉店事件』発売", Game*Spark, 2022-03-19: https://www.gamespark.jp/article/2022/03/19/117023.html
* [R4] DOOMKID, "映画「夜勤事件」公開記念！インディーホラー界のトップランナー"チラズアート"の魅力を改めて振り返ってみよう", Game*Spark, 2026-02-22: https://www.gamespark.jp/article/2026/02/22/163106.html
* [R5] "実は恐ろしい配達のお仕事......配達員として恐怖を体験するチラズアート新作ホラー『例外配達』がSteamにてリリース", Game*Spark, 2021-06-05 (byline not read): https://www.gamespark.jp/article/2021/06/05/109255.html
* [SS] My own observations of the store screenshots of P3, P4, P5, P7, P9 and P10 (six per game, five for P10), taken from the store pages' screenshot sets.

**Godot 4.7 documentation**

* [G1] Resolution scaling: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html
* [G2] Viewport (`scaling_3d_mode`, `Scaling3DMode`, `scaling_3d_scale`, `use_debanding`): https://docs.godotengine.org/en/stable/classes/class_viewport.html
* [G3] ProjectSettings (`rendering/scaling_3d/mode`, `rendering/scaling_3d/scale`): https://docs.godotengine.org/en/stable/classes/class_projectsettings.html
* [G4] SubViewportContainer (`stretch`, `stretch_shrink`): https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html
* [G5] Multiple resolutions (stretch modes): https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
* [G6] Overview of renderers (feature comparison): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
* [G7] Custom post-processing: https://docs.godotengine.org/en/stable/tutorials/shaders/custom_postprocessing.html
* [G8] Environment (`adjustment_*`, glow notes for Compatibility): https://docs.godotengine.org/en/stable/classes/class_environment.html
* [G9] Camera3D (`fov`): https://docs.godotengine.org/en/stable/classes/class_camera3d.html
* [G10] Screen-reading shaders (back-buffer copy): https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html

**Other**

* [X1] Microsoft, Xbox Accessibility Guideline 117: https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117

**This repository**

* [C1] `docs/roadmap.md`
* [C2] `docs/architecture.md` (Director, Story, Look, Audio levels); `docs/event-catalog.md` is cited by name
* [C3] `docs/performance.md`
* [C4] `docs/superpowers/specs/2026-11-05-trailer-objects-rebuild-design.md`
* [C5] `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`, `scripts/core/settings.gd`, `scripts/player/player_controller.gd`, `scenes/player/player.tscn`, `scripts/world/apartment_builder.gd`, `project.godot`
* [C6] `art/*/` textures (sizes read from the PNG files)

**Could not load or confirm**

* Tokyo Weekender interview with the studio (HTTP 403): https://www.tokyoweekender.com/entertainment/tech-trends/chillas-art-horror-games/
* PC Gamer on *Night Delivery* and Automaton English news on *The Closing Shift* (bodies did not load).
* TV Tropes, PCGamingWiki and a mezha.ua article on VHS horror (HTTP 403).
* Not confirmed anywhere: field of view, head bob settings, the full options menus, music and ambience
  practice, and any date stamp over normal play.
