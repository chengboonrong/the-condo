# Rebuilding the trailer's objects in Blender: design

2026-11-05. Status: draft for the owner's approval. Nothing is built yet.

## Why

The owner asked for a gameplay trailer for the itch.io page (tease only, 16:9 1080p, about 60 s, readable
with the sound off). Storyboard stills from the real game showed that the things the trailer lingers on are
boxes: the furniture is cuboids, the figure is a mannequin of capsules. The owner's answer: rebuild them
properly in Blender, using sources from the internet where that helps. A trailer must show what is in the
game, so the new models go into the game, not only the video. The trailer is filmed after this work, and it
has a design of its own.

This continues the owner's earlier ask for the condo to look "more realistic and scary, anti AI slop".

## Goals

1. **About 12 objects get real models** (owner: "Trailer objects first"), plus the rack apron that shares the figure's:

   | Object | Built today in | Must keep |
   |---|---|---|
   | The figure | `scripts/world/silhouette.gd` (`PARTS`) | It is your double ("Someone in your apron", "[It's your voice.]"), and the script never says who you are, so who it is stays open (owner): medium build, a loose work T-shirt and trousers under the apron, rubber slippers, plain hair, no headwear. About 1.7 m tall: `SilhouetteEvent.body_points` checks sight at 0.1, 1.0 and 1.6 m. Near-black, a mamak apron like the one on the laundry rack, arms hanging a little too low, head tipped; fades in and out (alpha, `render_priority = 1`); no collision |
   | Work shoes, both states | `apartment_builder.gd` `PROPS` (`entrance_shoes` default / moved) | Black, oily work shoes; on the rack, or side by side in the middle of the floor facing the hallway |
   | Shoe rack | `decor.gd`, entrance (around line 520) | Its `Interactable` and its `solid()` |
   | Dining table and chairs (with the turned chair) | `decor.gd` dining block (around line 416), `PROPS` seats and backs | Three chairs, one of them the `living_chair` variant (default / turned to face the bedroom); the teh tarik bag and the food cover on the table. Today the turned chair's back is on its east edge, so it faces the wall; the model faces the bedroom door as the text says, and its back's box and collider move with it (my call; the probe and walk tests must still pass) |
   | Bathroom basin and tap, running or not | `decor.gd` basin (around line 564), `PROPS` water (`bathroom_tap`) | Pedestal basin, glass shelf, toothbrush; the running water |
   | Wall clock | `decor.gd` `_clock()` | Hands that follow the game clock (it always reads 11:47 and moves with it) |
   | Intercom handset | `decor.gd`, entrance (line 529) | The beige wall handset of a Malaysian condo; the `intercom` `Interactable` |
   | Front door | `apartment_builder.gd` `_build_door()`, `door.gd` (`main_door`) | Hinge, swing, size and gaps from `ApartmentLayout.DOORS`; handle, peephole |
   | Bed | `PROPS` base, `decor.gd` `_bedroom()` | Mattress, pillows, bolster, the blanket kicked down, headboard. The same bed, mirrored and dusty, in B-11-07 |
   | Fridge | `PROPS` box, `decor.gd` `_kitchen()` (handle, freezer line) | The management notice on its door (`notice_fridge`) |
   | Ceiling fan | `apartment_builder.gd` `_build_fan()` | It turns (`_fan.rotate_y`); the light under it |
   | TV and cabinet | `PROPS`, `decor.gd` TV corner (around line 398) | A glossy black screen with a soft sheen, no real reflection: no probe, no second camera (my call: a live view would cost WebKit its 60 fps). The Astro box and router with their lights |
| The apron on the laundry rack | `decor.gd` `_garment()` by the window (around line 440) | The same apron model and texture as the figure's, tea stains and all, so the trailer's "laundry by the window" and "someone in your apron" visibly match (my call) |

2. **The look** (owner approved): worn and lived-in, a real low-cost Malaysian condo. Scuffs, chipped
   laminate, yellowed plastic, oil on the shoes. No real brand names or logos anywhere.
3. **They sit in the room.** Everything else keeps today's look for now, so the new models are toned to
   belong next to it, not to stand out (owner approved).

## Non-goals

* Rebuilding anything else: walls, floors, the other furniture, the corridor. That may follow later.
* Any change to play: positions, colliders, `Interactable` boxes, variants, story, events, audio. The one
  exception is the turned chair, whose back moves to match its text (above).
* Animating the figure. One still pose is enough: it only appears and fades.
* The trailer itself: its own design comes next.

## Anti-goals (a failure even if it works)

* Asset-store pieces dropped in: too clean, too new, or from the wrong place (an American double-door
  fridge, a Scandinavian dining set).
* A figure that reads as a horror monster or a zombie. It is a person, wearing your apron.
* Browser players waiting noticeably longer, or the WebKit build dropping from 60 fps.
* Any hitch the first time a new object comes into view.

## Constraints

* Godot 4.7.2, Compatibility renderer (WebGL2 for the web build). Blender 5.2.3 is installed.
* **Lights per mesh:** the renderer shades at most `max_lights_per_object` (10) lights per mesh and drops the
  rest silently. `test_no_mesh_loses_a_light_with_every_lamp_on` counts it for every visible mesh; it must
  still pass.
* **Shader warm-up:** `Main._compile_shaders` only compiles what its camera sees behind the start card. Every
  new material must be seen there (or share an existing one), or it hitches on first sight.
* **Colliders stay as they are.** `Decor.solid()` colliders are at most 0.3 m tall so they never hide a
  shift probe from `GameStage.can_see` (`test_furniture_never_hides_a_shift_probe`). Models replace the
  visible meshes only.
* **Variants:** anything tied to a variant is gated with `ApartmentBuilder.gate()` so it shows, and
  collides, only while its variant is active.
* **Doors are AnimatableBody3D** synced to physics; the door model is a child of the existing body.
* **Licences:** owner allows sources from the internet; nothing paid (the brief). The repository will be
  public for the jam.
* **Deadline:** submissions close 2026-12-01 13:37 PST; the trailer still has to be made after this.
* Nothing is pushed, merged or published without the owner's say.

## How it is made

* **Sources (my call):** CC0 models and textures (e.g. Poly Haven, ambientCG) where one fits, adapted in
  Blender; built in Blender where nothing fits (expected: the figure, the intercom, the Malaysian fittings).
  CC-BY 4.0 is acceptable with credit. Not acceptable: paid, non-commercial, no-derivatives, editorial-only,
  or unknown-origin files, and AI-generated meshes or textures. Photos from the internet are used as
  reference only, never copied into textures.
* **Credits (my call):** each third-party file is listed with its source URL, author and licence in a
  credits section of the README. `README.md` ("Every asset in this repository is original to the project")
  and `docs/architecture.md` ("No third-party code or assets are used") change to say what is borrowed.
  The Game Off 2024 and 2025 FAQs allow free third-party assets in the repository with credit; check the
  2026 rules before the jam submission.
* **Sources kept (my call):** the `.blend` files stay in the repository next to the exported models (the
  repository is source-available for the jam), excluded from every export preset.
* **Size budget (my call):** the game data the browser downloads (`index.pck`, 720 KB today) grows by at most
  8 MB for all twelve objects. Textures at most 1024 px (512 px is the default), compressed.
* **Check stills:** the storyboard camera positions below, rendered before and after, side by side.
  The stills script is at `/tmp/condo-trailer/storyboard.gd` (throwaway) and should move into `tools/` (or
  into `tools/screenshots.gd`) so the trailer can use the same cameras.

  | Still | Camera x, z | Yaw, pitch | Set up |
  |---|---|---|---|
  | Living room | 6.5, 8.4 | 0, 0.15 | fan, TV, clock, table |
  | Intercom and front door | 2.75, 7.25 | 2.24, -0.1 | entrance light on |
  | Bedroom wall | 7.2, 2.1 | 0.149, -0.12 | phone light |
  | Shoes, on the rack / moved | 2.7, 9.6 | 0.7, -0.5 | entrance light on; `entrance_shoes` default / moved |
  | Chair turned | 5.5, 7.0 | 0.723, -0.3 | `living_chair` turned |
  | Tap running | 4.4, 0.3 | 2.137, -0.35 | phone light; `bathroom_tap` running |
  | Figure in the hallway | 4.6, 3.25 | -π/2, 0 | hallway light; figure at (9.6, 0, 3.25) |
  | Figure in the kitchen | 1.5, 6.5 | 0.114, -0.05 | phone light; figure at (1.1, 0, 3.0) |
  | Clock | 5.3, 5.6 | 0, 0.28 | camera fov 28 |

  Yaw follows `PlayerController.set_look` (`yaw = atan2(-d.x, -d.z)` for a direction d); eyes at 1.62 m.

## Done when

1. The before/after sheet shows every object reading as the real thing at trailer framing, and the owner
   has looked at it.
2. `tools/test.sh` passes in full (64 tests today), including the light and probe tests above.
3. `tools/export.sh` then `tools/smoke.sh`: smoke ok on macOS, Chromium and WebKit.
4. Performance measured the way `docs/performance.md` does (macOS `--perf` 3 runs, Chromium and WebKit
   `--perf` 2 runs each) and recorded there with the draw calls and the new `index.pck` size. WebKit keeps
   60 fps; no frame over 25 ms on any build.
5. Credits and the two licence sentences updated; `docs/architecture.md` "## Look" describes the models.

## Left to the builder

Which source suits each object; polygon counts; texture sizes and formats within the budget; file layout
under `assets/`; how to split each visible mesh from its collider in `PROPS` and `Decor`; whether to bake
ambient occlusion into textures; how the figure's base body is made (built by hand, or from a CC0 base
such as MakeHuman output); whether the interior doors reuse the front door model.
