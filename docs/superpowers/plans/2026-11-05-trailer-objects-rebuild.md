# Trailer Objects Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the box-built versions of the trailer's 13 objects with worn, realistic Blender models, without changing how the game plays.

**Architecture:** Each model is a Blender Python build script in `art/<id>/build.py` (ignored by Godot via `art/.gdignore`) that saves `art/<id>/<id>.blend` and exports `assets/models/<id>.glb`. In Godot, `ApartmentBuilder.MODELS` places models (draw only) and `ApartmentBuilder.COLLIDERS` keeps the old box colliders (collide only). The few objects with moving parts or special code (clock hands, fan blades, front door, figure) load their model where they are built today and find their parts by node name.

**Tech Stack:** Godot 4.7.2 (GDScript, Compatibility renderer, WebGL2 export), Blender 5.2.3 (bpy, Cycles bake, glTF exporter), CC0/CC-BY 4.0 textures and models.

**Spec:** `docs/superpowers/specs/2026-11-05-trailer-objects-rebuild-design.md` (approved by the owner 2026-11-05). Read it first.

## Global Constraints

- Godot binary: `~/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot`; Blender: `/Applications/Blender.app/Contents/MacOS/Blender` (5.2.3). Tests: `GODOT=<godot> tools/test.sh [--filter=x]` (64 pass before this plan).
- No change to play: object positions, colliders, `Interactable` boxes, variants, story, events and audio stay as they are. Only exception: the turned chair's back collider moves (Task 4).
- Sources: CC0, or CC-BY 4.0 with credit. Not: paid, non-commercial, no-derivatives, editorial-only, unknown origin, AI-generated meshes or textures. Internet photos are reference only. Download 1K texture sets; nothing larger is committed.
- Every third-party file sits in `art/<id>/vendor/` with a `SOURCE.md` block per file: `File: …`, `URL: …`, `Author: …`, `Licence: …`.
- No real brand names or logos on any model.
- Look: worn and lived-in low-cost Malaysian condo (scuffs, chipped laminate, yellowed plastic, oil); toned to sit next to the remaining box furniture, not to stand out.
- Budget: `builds/web/index.pck` at most 8912 KiB (720 KiB today + 8 MiB). Textures at most 1024 px on any side, 512 px by default. Triangle budgets per model are in Task 2's `TRIS` table.
- Each model: one mesh and one baked material unless a part must move or needs its own shading (hands, blades, emissive LEDs, glossy TV screen, water, the figure's apron). Fewer draw calls is the point.
- Model convention: metres, origin at the centre of its floor footprint (wall items: centre of the face touching the wall; hanging items: the hanging point), front facing Blender −Y (Front view), which is Godot +Z after glTF export. Materials are image-textured Principled BSDF only (that is all glTF carries); procedural wear is baked to images.
- Every new material must be seen by `Main._compile_shaders` (Task 2 makes it show every model) so nothing hitches on first sight; `test_no_mesh_loses_a_light_with_every_lamp_on` must keep passing.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Never push, merge or create a remote.

## Review Focus

1. **The phone light (the only shadowed light) on the new models:** self-shadow acne, light leaking through thin parts. Checked in the phone-light stills (bedroom wall, tap, kitchen figure) in Tasks 5, 7 and 11.
2. **The web build's look:** GLB materials (normal and ORM maps) can render differently in WebGL2. Task 12 looks at `builds/smoke-webkit.png` and `builds/smoke-chromium.png` next to the macOS screenshot.
3. **Thin parts shimmering at a distance** (chair legs, fan blades, rack slats, shoe laces): seen in the living-room still and the after sheet; fixed with mipmapped textures and no sub-centimetre geometry.
4. **The figure fading out:** both its materials must fade together, or a floating apron is left behind. `test_figure_is_a_person_in_an_apron` checks the materials; Task 11 renders a frame mid-fade.
5. **A shift swapping a model in plain view:** the gated models must not be larger than the old boxes they replace, or a swap shows outside the probes' sight lines. `test_models_stand_where_they_collide` pins `shoes_moved` and `chair_turned` to the old boxes' size (Tasks 3 and 4).

---

### Task 1: Stills tool and the "before" pictures

**Files:**
- Create: `tools/stills.gd` (from `/tmp/condo-trailer/storyboard.gd`)

**Interfaces:**
- Produces: `godot --path . --script res://tools/stills.gd -- --out=<dir> [--before=<dir>]` writes `<dir>/<still>.png` (1600×900) for every still, and `<dir>/sheet.png`. With `--before`, the sheet pairs each still with the same file from the before directory (before left, after right). Later tasks and the trailer use it.

- [ ] **Step 1: Write `tools/stills.gd`** (a `SceneTree` script; needs a window, not `--headless`). Shot list, one row per still: `[name, x, z, yaw, pitch, lights on, variants, figure position or null, phone light, fov or 0 for the default]`:

  | name | x, z | yaw, pitch | set up |
  |---|---|---|---|
  | living | 6.5, 8.4 | 0, 0.15 | none |
  | entrance | 2.75, 7.25 | 2.24, -0.1 | `[&"entrance"]` |
  | bedroom_wall | 7.2, 2.1 | 0.149, -0.12 | phone light |
  | shoes | 2.7, 9.6 | 0.7, -0.5 | `[&"entrance"]` |
  | shoes_moved | 2.7, 9.6 | 0.7, -0.5 | `[&"entrance"]`, `{&"entrance_shoes": &"moved"}` |
  | chair_turned | 5.5, 7.0 | 0.723, -0.3 | `{&"living_chair": &"turned"}` |
  | tap | 4.4, 0.3 | 2.137, -0.35 | phone light, `{&"bathroom_tap": &"running"}` |
  | hallway_figure | 4.6, 3.25 | -PI / 2, 0 | `[&"hallway"]`, figure at (9.6, 0, 3.25) |
  | kitchen_figure | 1.5, 6.5 | 0.114, -0.05 | phone light, figure at (1.1, 0, 3.0) |
  | clock | 5.3, 5.6 | 0, 0.28 | fov 28 |
  | bedroom_lit | 7.2, 1.9 | 0.1, 0 | `[&"bedroom"]` |
  | b1107 | 7.75, -14.6 | 0, -0.1 | `{&"bedroom": &"door"}` |

  Keep the storyboard script's set-up (wait for `main.loaded`, `player.set_physics_process(false)`, hide the start card, the objective, the crosshair and the prompt, figure via `main.silhouette` with `_left = 10.0` and `_set_alpha(0.95)`, 10 frames per still). Hide the HUD clock. Build the sheet with `Image.blit_rect`, 3 columns, each still scaled to 640×360 (pairs: 1280×360 per row).

- [ ] **Step 2: Render the before pictures**

  Run: `~/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot --path . --script res://tools/stills.gd -- --out=/tmp/condo-stills/before`
  Expected: 12 PNGs and `sheet.png` in `/tmp/condo-stills/before`. Open `sheet.png` and check each still shows what its name says. Write the base commit's hash in the task report (to re-render "before" from a worktree if `/tmp` is cleared).

- [ ] **Step 3: Commit**

  `git add tools/stills.gd tools/stills.gd.uid` (the `.uid` appears after the first run) and commit: `tools: stills from the trailer's cameras, before/after sheets`.

### Task 2: The model pipeline, proven on the wall clock

**Files:**
- Create: `art/.gdignore` (empty), `art/common.py`, `art/wall_clock/build.py`, `tools/models.sh`, `assets/models/wall_clock.glb`, `tests/integration/test_models.gd`
- Modify: `scripts/world/apartment_builder.gd` (new `MODELS`, `COLLIDERS`, `models`, `model()`, `_build_models()`, `_collider()`, `warm_up_models()`), `scripts/world/decor.gd` (`_clock()`), `scripts/main.gd` (`_compile_shaders`)

**Interfaces:**
- Produces (Blender, `art/common.py`, imported by every `build.py` via `sys.path.insert(0, <art dir>)`):
  - `reset() -> None`: empty scene, metric units.
  - `pbr(name: str, folder: str, tint: tuple[float, float, float] | None = None) -> bpy.types.Material`: Principled material from a texture set in `folder` (albedo, roughness, normal; files matched by `*Color*`, `*Roughness*`, `*NormalGL*`).
  - `bake(obj: bpy.types.Object, size: int = 512) -> None`: Cycles-bakes every material on `obj` (diffuse colour, roughness, metallic, normal) into one image set on a fresh UV unwrap, and replaces them with one material named `<obj.name>_baked`.
  - `export(model_id: str, objects: list[bpy.types.Object]) -> None`: saves `art/<id>/<id>.blend` (textures not packed) and writes `assets/models/<id>.glb` (selected objects only, modifiers applied, +Y up, textures embedded).
- Produces (shell): `tools/models.sh [id ...]` runs `"$BLENDER" -b --factory-startup --python art/<id>/build.py` for each id (every `art/*/build.py` when none given; `BLENDER` defaults to `/Applications/Blender.app/Contents/MacOS/Blender`), then `"$GODOT" --headless --path . --import`.
- Produces (Godot, `ApartmentBuilder`):
  - `const MODELS := [[node_name: StringName, model_id: StringName, xf: Transform3D, requires: Dictionary, dusty: bool (optional, default false)], ...]`
  - `const COLLIDERS := [[center: Vector3, size: Vector3, requires: Dictionary], ...]`: built like a colliding `PROPS` entry but with no mesh, including its `decor.foot()` shade when it stands on the floor.
  - `var models: Dictionary`: node name → the placed `Node3D`.
  - `static func model(id: StringName) -> Node3D`: instantiates `res://assets/models/<id>.glb`.
  - `func warm_up_models() -> void`: makes every node in `models` visible whatever its variant; `refresh_variants()` puts them back.
- Produces (model `wall_clock`): child nodes `HourHand` and `MinuteHand`, each with its origin at the dial centre, pointing +Y at rotation 0, so `Decor._process` keeps turning them with `rotation.z`.

- [ ] **Step 1: Write the failing tests** in `tests/integration/test_models.gd` (`extends TestCase`, with a `_main()` helper like `test_apartment.gd`'s, and `static func _aabb(node: Node3D) -> AABB` merging `m.global_transform * m.get_aabb()` over every `MeshInstance3D` under `node`):

  ```gdscript
  # Triangles each model may have. Each object task adds its ids.
  const TRIS := {&"wall_clock": 1500}
  # Floor footprints: node name -> [centre x, centre z, size x, size z] of the collider it replaces.
  const FOOTPRINTS := {}

  func test_every_model_is_within_budget() -> bool:
  	# every .glb in res://assets/models has a TRIS entry (eq on the sorted id lists);
  	# for each id: ApartmentBuilder.model(id), sum triangles over all MeshInstance3D surfaces
  	# (index count / 3, or vertex count / 3 when unindexed): check(tris <= TRIS[id], ...);
  	# every texture of every surface material (BaseMaterial3D.get_texture(t) for t < TEXTURE_MAX):
  	# check(maxi(w, h) <= 1024, ...)

  func test_models_stand_where_they_collide() -> bool:
  	# for name in FOOTPRINTS: a := _aabb(main.builder.models[name]); f := FOOTPRINTS[name]
  	# near(a.get_center().x, f[0], 0.05, ...); near(a.get_center().z, f[1], 0.05, ...)
  	# near(a.size.x, f[2], 0.08, ...); near(a.size.z, f[3], 0.08, ...); near(a.position.y, 0.0, 0.02, ...)

  func test_models_follow_their_variants() -> bool:
  	# for each MODELS entry with requires: for each area in it, for each variant in
  	# ApartmentLayout.VARIANT_AREAS[area]["variants"]: WorldState.set_variant(area, v); await tree.process_frame
  	# eq(node.visible, ApartmentLayout.requires_met(requires, WorldState.variants), "<name> with <area>=<v>")
  	# then set every area back to &"default"

  func test_warm_up_shows_every_model() -> bool:
  	# main.builder.warm_up_models(): every node in main.builder.models is visible
  	# main.builder.refresh_variants(): each gated one is visible exactly when requires_met

  func test_every_borrowed_file_is_credited() -> bool:
  	# README text contains every "URL: " value from every res://art/*/vendor/SOURCE.md

  func test_clock_hands_read_the_game_clock() -> bool:
  	# with WorldState at its start (11:47 PM) after one process frame:
  	# hands := main.builder.models[&"wall_clock"] -> get_node("HourHand"), get_node("MinuteHand")
  	# near(hour.rotation.z, -TAU * (11.0 + 47.0 / 60.0) / 12.0, 0.01, ...)
  	# near(minute.rotation.z, -TAU * 47.0 / 60.0, 0.01, ...)
  ```

  The comments are the assertions to write; values as given.

- [ ] **Step 2: Run them to see them fail**

  Run: `GODOT=… tools/test.sh --filter=test_models`
  Expected: FAIL (no `ApartmentBuilder.model`, no `models`).

- [ ] **Step 3: Write `art/.gdignore`, `art/common.py` and `tools/models.sh`** with the signatures above.

- [ ] **Step 4: Write `art/wall_clock/build.py`:** a cheap round plastic wall clock, 30 cm across, 4 cm deep: off-white face with printed hour numerals in a plain sans serif, a slightly yellowed rim, a scuffed clear cover (glossy, not transparent), black `HourHand` and `MinuteHand` as separate objects (origin at the dial centre, pointing up), a thin red second hand fixed at 12. Body and hands share one baked material. Run `tools/models.sh wall_clock`; expected: `assets/models/wall_clock.glb` exists and Godot imports it without errors.

- [ ] **Step 5: Wire it in.**
  - `ApartmentBuilder`: add `MODELS`, `COLLIDERS`, `models`, `model()`, `_build_models()` (instance, set `transform`, `add_child`, store in `models`, `gate()`; `dusty` entries get every surface material duplicated with `albedo_color *= Color(0.75, 0.73, 0.7)` and `roughness = 1.0`), `_collider()` and the `COLLIDERS` loop next to the `PROPS` loop in `build()`, and `warm_up_models()`.
  - `Decor._clock(at)`: replace the disc, ticks and hand boxes with `ApartmentBuilder.model(&"wall_clock")` at `at` (the wall face; front +Z), add it, register it as `builder.models[&"wall_clock"]`, and fill `_hands` with its `HourHand` and `MinuteHand`.
  - `Main._compile_shaders`: call `builder.warm_up_models()` before the room loop, and `builder.refresh_variants()` after the lights are restored.

- [ ] **Step 6: Run the tests**

  Run: `GODOT=… tools/test.sh`
  Expected: all pass (64 + 6 new).

- [ ] **Step 7: Look at it**

  Run: `… --script res://tools/stills.gd -- --out=/tmp/condo-stills/after --before=/tmp/condo-stills/before`
  Expected: in the `clock` and `living` pairs the clock reads as a real cheap wall clock at 11:47, no worse lit than before.

- [ ] **Step 8: Commit** `art/`, `assets/models/`, `tools/models.sh`, the three scripts and the test: `feat: Blender model pipeline; the wall clock`.

### Task 3: Work shoes and the shoe rack

**Files:**
- Create: `art/work_shoes/build.py`, `art/shoe_rack/build.py`, their `.glb` files
- Modify: `apartment_builder.gd` (`PROPS`: remove the four shoe boxes; `MODELS`), `decor.gd` (`_entrance()`: remove the rack's boxes, keep its `solid()` and `foot()`), `tests/integration/test_models.gd` (`TRIS`, `FOOTPRINTS`)

**Interfaces:**
- Consumes: Task 2's `MODELS`, `model()`, `tools/models.sh`, `art/common.py`.

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"work_shoes": 2000, &"shoe_rack": 2000`; `FOOTPRINTS` gains `&"shoe_rack": [0.25, 8.0, 0.4, 1.0]` and `&"shoes_moved": [2.3, 8.5, 0.28, 0.32]` (the two old boxes: a moved pair no bigger than before). `test_models_follow_their_variants` covers the shoes once they are in `MODELS`.
- [ ] **Step 2: Run:** `tools/test.sh --filter=test_models`. Expected: FAIL (no model files).
- [ ] **Step 3: Build the models.** `work_shoes`: one pair of black slip-on kitchen work shoes with thick non-slip rubber soles, creased uppers, a grease sheen, worn-down heels; origin at the centre of the pair's soles, toes +Z. `shoe_rack`: a cheap three-tier slatted rack (1.0 m long along its X, 0.38 m deep, 0.6 m tall; shelves at 0.03, 0.3 and 0.59 m), worn varnish, a pair of blue rubber selipar on the bottom shelf.
- [ ] **Step 4: Place them** in `MODELS`:
  - `[&"shoe_rack", &"shoe_rack", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.25, 0, 8.0)), {}]`
  - `[&"shoes_on_rack", &"work_shoes", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(0.29, 0.6, 7.8)), {&"entrance_shoes": &"default"}]` (toes towards the wall)
  - `[&"shoes_moved", &"work_shoes", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(2.3, 0, 8.5)), {&"entrance_shoes": &"moved"}]` (toes towards the living room)
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass.
- [ ] **Step 6: Look:** stills `shoes`, `shoes_moved`, `entrance`. The shoes read as work shoes, on the rack and then in the middle of the floor.
- [ ] **Step 7: Commit:** `feat: work shoes and shoe rack models`.

### Task 4: Dining table and chairs, with the turned chair facing the hallway

**Files:**
- Create: `art/dining_table/build.py`, `art/dining_chair/build.py`, their `.glb` files
- Modify: `apartment_builder.gd` (`PROPS`: remove the six chair entries; `COLLIDERS`: the three backs; `MODELS`), `decor.gd` (`_living()`: remove the table top, legs, food cover, tea bag and chair legs; keep the table's `solid()` and every `foot()`), `tests/integration/test_models.gd`

**Interfaces:**
- Consumes: Task 2's `MODELS`, `COLLIDERS`, `model()`.

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"dining_table": 6000, &"dining_chair": 2500`; `FOOTPRINTS` gains `&"dining_table": [4.5, 6.2, 1.1, 0.75]` and `&"chair_turned": [3.45, 5.2, 0.42, 0.42]`; and

  ```gdscript
  func test_turned_chair_faces_the_hallway() -> bool:
  	# chair := main.builder.models[&"chair_turned"]
  	# check(chair.global_basis.z.dot(Vector3.FORWARD) > 0.95, "its front points north, through the hallway opening")
  	# the COLLIDERS entry gated {&"living_chair": &"turned"}: check(entry[0].z > 5.3, "its back is on the south side")
  ```

- [ ] **Step 2: Run:** `tools/test.sh --filter=test_models`. Expected: FAIL.
- [ ] **Step 3: Build the models.** `dining_table`: a 1.1 × 0.75 m rubberwood table, top at 0.76 m, varnish worn pale along the edges, a ring stain; on it, as part of the same model, a pink plastic tudung saji (dome food cover, 0.54 m across, at the table's −X end like today) and a tied plastic bag of teh tarik with a pink raffia loop (at today's +X end). `dining_chair`: matching rubberwood chair, seat 0.42 m square at 0.45 m, back to 0.9 m; origin at the floor centre of the seat, front +Z.
- [ ] **Step 4: Place them.** `MODELS`: table `Transform3D(Basis(), Vector3(4.5, 0, 6.2))`; `chair_north` at (4.5, 0, 6.85) yaw `PI`; `chair_south` at (4.5, 0, 5.55) yaw 0, `{&"living_chair": &"default"}`; `chair_turned` at (3.45, 0, 5.2) yaw `PI`, `{&"living_chair": &"turned"}`. `COLLIDERS`: the backs `[Vector3(4.5, 0.75, 7.05), Vector3(0.42, 0.55, 0.05), {}]`, `[Vector3(4.5, 0.75, 5.35), Vector3(0.42, 0.55, 0.05), {&"living_chair": &"default"}]`, and the moved one `[Vector3(3.45, 0.75, 5.4), Vector3(0.42, 0.55, 0.05), {&"living_chair": &"turned"}]`. The seats had no collider (too thin) and get none.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass, including `test_furniture_never_hides_a_shift_probe` and the walk test.
- [ ] **Step 6: Look:** stills `living`, `chair_turned`. The turned chair faces the hallway opening, away from the table.
- [ ] **Step 7: Commit:** `feat: dining table and chairs; the turned chair faces the hallway`.

### Task 5: Bathroom basin, tap and running water

**Files:**
- Create: `art/basin/build.py`, `art/tap_water/build.py`, their `.glb` files
- Modify: `apartment_builder.gd` (`PROPS`: remove the water entry; `MODELS`), `decor.gd` (`_bathroom()`: remove the pedestal, basin, tap, shelf, cup and toothbrush; keep the `solid()`), `tests/integration/test_models.gd`

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"basin": 4000, &"tap_water": 300`; `FOOTPRINTS` gains `&"basin": [3.3, 1.0, 0.38, 0.48]` (its `solid()`).
- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build.** `basin`: a white pedestal basin (top at 0.93 m, about 0.48 × 0.4 m), a chrome pillar tap with a cross handle, a glass shelf above it at 1.17 m with a plastic cup and one toothbrush, a limescale ring and grime in the corners; origin at the floor centre of the pedestal, front +Z (away from the wall). `tap_water`: a thin falling stream from the spout to the bowl, transparent with the same shading features as the shower screen's material (`albedo` with alpha, no texture), origin at the spout.
- [ ] **Step 4: Place:** `[&"basin", &"basin", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(3.3, 0, 1.0)), {}]` and `[&"tap_water", &"tap_water", Transform3D(Basis(), <the new model's spout, measured in Blender>), {&"bathroom_tap": &"running"}]`. The `tap` `Interactable` box at (3.22, 1.0, 1.0) must still enclose the spout; if the spout moves outside it, move the model, not the box.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass.
- [ ] **Step 6: Look:** still `tap` (phone light). Watch for shadow acne on the porcelain and the stream's visibility.
- [ ] **Step 7: Commit:** `feat: basin, tap and running water models`.

### Task 6: Intercom and front door

**Files:**
- Create: `art/intercom/build.py`, `art/front_door/build.py`, their `.glb` files
- Modify: `apartment_builder.gd` (`_build_door()`: for `&"main_door"` only, the model replaces the panel, handle and peephole boxes; `MODELS`: the intercom), `decor.gd` (`_entrance()`: remove the handset box), `tests/integration/test_models.gd`

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"intercom": 1000, &"front_door": 3000`; and

  ```gdscript
  func test_front_door_model_fills_its_panel() -> bool:
  	# door: Door = main.builder.doors[&"main_door"]; shape := door.get_child(0) as CollisionShape3D
  	# model := door.get_node("front_door"); a := door local AABB of the model's meshes
  	# near(a.get_center() vs shape.position, each axis, 0.005); near(a.size vs (shape.shape as BoxShape3D).size, each axis, 0.005)
  ```

- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build.** `intercom`: a beige wall-mounted intercom handset unit (about 9 × 22 cm) on its base, with a coiled cord and a door-release button; yellowed plastic, finger grime around the handset; origin at the centre of the face touching the wall, front +Z. `front_door`: a solid timber door panel 0.954 × 2.07 × 0.05 m, dark varnish worn pale around the handle, kick marks at the bottom, lever handles on both faces, a deadbolt on the inside face, a peephole at 1.55 m; origin at the hinge-side bottom edge, middle of its thickness, panel along +X.
- [ ] **Step 4: Place.** Intercom: `[&"intercom", &"intercom", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.14, 1.48, 8.56)), {}]`. Front door: in `_build_door`, when `door_id == &"main_door"`, add `ApartmentBuilder.model(&"front_door")` named `front_door` at `Vector3(0.003, 0.015, back)` instead of the boxes (`back` as computed there; check which face is the corridor side and turn the model so its deadbolt faces the entrance).
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass, including the door tests in `test_apartment.gd`.
- [ ] **Step 6: Look:** still `entrance` (front door and intercom) and the `corridor → lift` sheet of `tools/screenshots.gd` for the door's outside.
- [ ] **Step 7: Commit:** `feat: intercom and front door models`.

### Task 7: The bed, and its dusty twin in B-11-07

**Files:**
- Create: `art/bed/build.py`, `assets/models/bed.glb`
- Modify: `apartment_builder.gd` (`PROPS`: both bed bases move to `COLLIDERS`; `MODELS`), `decor.gd` (`_bedroom()`: remove the mattress, headboard, pillows, bolster and blanket), `tests/integration/test_models.gd`

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"bed": 8000`; `FOOTPRINTS` gains `&"bed": [8.95, 0.2, 1.8, 2.0]` and `&"bed_b1107": [6.55, -16.3, 1.8, 2.0]` (today's headboard stands 0.07 m past the base, inside the tolerance).
- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build `bed`:** a queen bed on a dark wooden frame, headboard 1.86 m wide and 0.96 m tall at the −Z end, a mattress with a white fitted sheet, two pillows, a bolster (bantal peluk) and a blue blanket kicked down to the foot; creased fabric, a sag where someone sleeps; origin at the floor centre of the base, foot end +Z.
- [ ] **Step 4: Place:** `[&"bed", &"bed", Transform3D(Basis(), Vector3(8.95, 0, 0.2)), {}]` and `[&"bed_b1107", &"bed", Transform3D(Basis(Vector3.UP, PI), Vector3(6.55, 0, -16.3)), {&"bedroom": &"door"}, true]`. `COLLIDERS`: `[Vector3(8.95, 0.25, 0.2), Vector3(1.8, 0.5, 2.0), {}]` and `[Vector3(6.55, 0.25, -16.3), Vector3(1.8, 0.5, 2.0), {&"bedroom": &"door"}]`.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass, including the walk test's "round the bed" legs.
- [ ] **Step 6: Look:** stills `bedroom_wall` (phone light), `bedroom_lit`, `b1107`.
- [ ] **Step 7: Commit:** `feat: bed model, dusty in B-11-07`.

### Task 8: The fridge

**Files:**
- Create: `art/fridge/build.py`, `assets/models/fridge.glb`
- Modify: `apartment_builder.gd` (`PROPS`: the fridge box moves to `COLLIDERS`; `MODELS`), `decor.gd` (`_kitchen()`: remove the fridge handle and freezer line), `tests/integration/test_models.gd`

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"fridge": 4000`; `FOOTPRINTS` gains `&"fridge": [0.4, 2.95, 0.7, 0.7]`.
- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build `fridge`:** a 1.8 m two-door top-freezer fridge, off-white gone faintly yellow, grey door seals, a recessed handle on each door, a few fridge magnets (a kedai runcit's, a takeaway menu, a calendar: made-up shop names only), fingerprints around the handles; the door face kept flat where the management notice hangs (the `notice_fridge` box at (0.77, 1.35, 2.95)); origin at the floor centre, front +Z.
- [ ] **Step 4: Place:** `[&"fridge", &"fridge", Transform3D(Basis(Vector3.UP, PI / 2), Vector3(0.4, 0, 2.95)), {}]`; `COLLIDERS`: `[Vector3(0.4, 0.9, 2.95), Vector3(0.7, 1.8, 0.7), {}]`.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass.
- [ ] **Step 6: Look:** still `kitchen_figure`; the notice still sits on the door, not inside it.
- [ ] **Step 7: Commit:** `feat: fridge model`.

### Task 9: The ceiling fan

**Files:**
- Create: `art/ceiling_fan/build.py`, `assets/models/ceiling_fan.glb`
- Modify: `apartment_builder.gd` (`_build_fan()`), `tests/integration/test_models.gd`

**Interfaces:**
- Produces (model `ceiling_fan`): root at the ceiling mount; child `Blades` (motor housing and blades) whose origin lies on the downrod's axis 0.2 m below the root. `_fan` becomes that `Blades` node, so `_process` keeps turning it.

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"ceiling_fan": 3000`; and

  ```gdscript
  func test_fan_turns_under_the_ceiling() -> bool:
  	# fan := main.builder.models[&"ceiling_fan"]; blades := fan.get_node("Blades")
  	# near(_aabb(fan).end.y, ApartmentLayout.CEILING, 0.02, "hangs from the ceiling")
  	# var r := blades.rotation.y; await 10 process frames; check(not is_equal_approx(blades.rotation.y, r), "turns")
  ```

- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build `ceiling_fan`:** a plain three-blade ceiling fan about 1.4 m across, white motor housing, cream painted metal blades with a grey dust line along their leading edges, a short downrod and ceiling canopy.
- [ ] **Step 4: Wire:** `_build_fan()` adds the model at `Vector3(6.5, ApartmentLayout.CEILING, 7.0)`, registers it in `models`, and sets `_fan` to its `Blades`; the old boxes go.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass, `test_no_mesh_loses_a_light_with_every_lamp_on` included (the fan sits on the light under it).
- [ ] **Step 6: Look:** still `living`; blades must not shimmer.
- [ ] **Step 7: Commit:** `feat: ceiling fan model`.

### Task 10: TV and cabinet

**Files:**
- Create: `art/tv_cabinet/build.py`, `assets/models/tv_cabinet.glb`
- Modify: `apartment_builder.gd` (`PROPS`: the cabinet box moves to `COLLIDERS`; `MODELS`), `decor.gd` (`_living()`: remove the TV corner's boxes: cabinet lines, screen, stand, decoder, its LED, router, antennas, its LEDs), `tests/integration/test_models.gd`

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"tv_cabinet": 6000`; `FOOTPRINTS` gains `&"tv_cabinet": [6.5, 4.3, 2.0, 0.45]`.
- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build `tv_cabinet`:** a low chipboard TV cabinet (2.0 × 0.45 × 0.5 m) with wood-grain laminate peeling at one corner and two doors; on it a 43-inch flat TV (screen 1.43 × 0.83 m, centre at 0.95 m, its stand), a satellite decoder box with a red standby LED, and a white Wi-Fi router with two antennas and three green LEDs. The screen is its own glossy black material (roughness about 0.1, no texture, no reflection probe); the LEDs share one emissive material; the rest is one baked material. Origin at the floor centre, front +Z.
- [ ] **Step 4: Place:** `[&"tv_cabinet", &"tv_cabinet", Transform3D(Basis(), Vector3(6.5, 0, 4.3)), {}]`; `COLLIDERS`: `[Vector3(6.5, 0.25, 4.3), Vector3(2.0, 0.5, 0.45), {}]`. The `tv` `Interactable` (6.5, 0.95, 4.57) must still sit on the screen.
- [ ] **Step 5: Run** `tools/test.sh`. Expected: all pass.
- [ ] **Step 6: Look:** still `living`.
- [ ] **Step 7: Commit:** `feat: TV and cabinet model`.

### Task 11: The figure, and the apron on the laundry rack

**Files:**
- Create: `art/figure/build.py`, `art/apron_hung/build.py`, `art/shared/apron/` (the apron's textures, used by both), their `.glb` files
- Modify: `scripts/world/silhouette.gd` (`BODY` and the box apron give way to the model), `decor.gd` (`_living()`: remove the apron `_garment` and its two tea stains), `apartment_builder.gd` (`MODELS`), `tests/integration/test_models.gd`

**Interfaces:**
- Produces (model `figure`): two materials, one named `body`, one named `apron` (surface material names as exported). `Silhouette` overrides `body` surfaces with `_material`, and `apron` surfaces with `_apron`, which takes the model's apron `albedo_texture` and keeps its alpha fade and `render_priority = 1`.

- [ ] **Step 1: Write the failing tests:** `TRIS` gains `&"figure": 12000, &"apron_hung": 1500`; and

  ```gdscript
  func test_figure_is_a_person_in_an_apron() -> bool:
  	# sil: Silhouette = main.silhouette; a := _aabb(sil) with sil at the origin
  	# check(a.size.y >= 1.65 and a.size.y <= 1.75, "about 1.7 m tall (body_points check 0.1, 1.0, 1.6 m)")
  	# every MeshInstance3D surface's override is sil._material or sil._apron; at least one is sil._apron
  	# sil._apron.albedo_texture != null
  ```

  `test_silhouette_behind_then_seen` and `test_silhouette_never_appears_in_view_when_looking_down` must keep passing.
- [ ] **Step 2: Run:** expected FAIL.
- [ ] **Step 3: Build the apron textures** in `art/shared/apron/`: off-white canvas, tea and oil stains, frayed edges (512 px).
- [ ] **Step 4: Build `figure`** with the Skin modifier on a vertex skeleton, then Subdivision: about 1.70 m, medium build, plain hair, no headwear, a loose work T-shirt and trousers, rubber slippers, standing still with the arms hanging a little too low (hands near mid-thigh) and the head tipped about 0.2 rad, wearing the apron (tied at the back). Who it is stays open: no detail that says man or woman. Origin between the feet, front +Z. If the Skin modifier cannot give a believable outline, stop and report; a MakeHuman (MPFB) base needs a Blender add-on installed, which needs the owner's OK.
- [ ] **Step 5: Build `apron_hung`:** the same apron hanging folded over a rail, origin at the rail contact, front +Z.
- [ ] **Step 6: Wire.** `Silhouette._ready`: add `ApartmentBuilder.model(&"figure")` and apply the materials as above, `cast_shadow` off as today. `MODELS`: `[&"apron_hung", &"apron_hung", Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(9.3, 1.69, 6.82)), {}]`.
- [ ] **Step 7: Run** `tools/test.sh`. Expected: all pass.
- [ ] **Step 8: Look:** stills `hallway_figure`, `kitchen_figure` (phone light), `living` (the rack apron). The figure reads as a person, not a monster; the two aprons are visibly the same. Render one more frame of the hallway still with `sil._set_alpha(0.4)`: body and apron fade together.
- [ ] **Step 9: Commit:** `feat: the figure and the rack apron, one apron`.

### Task 12: Credits, size cap, builds, measurements and the after sheet

**Files:**
- Modify: `README.md` (`## Licence` sentence; new `## Credits`), `docs/architecture.md` ("## Look": a models bullet; "## References consulted": the "No third-party code or assets" sentence), `tools/smoke.sh` (size cap), `docs/performance.md`

- [ ] **Step 1: Credits.** README `## Credits`: one line per `SOURCE.md` block (file, author, licence, URL), grouped by model. Replace "Every asset in this repository is original to the project." with what is borrowed and under which licences; same in `docs/architecture.md`. Run `tools/test.sh --filter=test_every_borrowed_file_is_credited`; expected PASS.
- [ ] **Step 2: Size cap in `tools/smoke.sh`:** before the macOS run, print `web: index.pck <n> KiB (cap 8912)` from `stat -f%z builds/web/index.pck` and set the exit status to 1 above 8912.
- [ ] **Step 3: Build and smoke.**
  Run: `GODOT=… tools/export.sh && GODOT=… PLAYWRIGHT_FROM=$HOME/work/the-house-web-port/ tools/smoke.sh`
  Expected: `SMOKE ok` for macOS, Chromium and WebKit, the pck line under the cap, exit 0. Look at `builds/smoke-webkit.png` and `builds/smoke-chromium.png` next to the macOS screenshot: the models look the same in WebGL2.
- [ ] **Step 4: Measure** exactly as `docs/performance.md` describes (macOS `--perf` 3 runs; Chromium and WebKit `--perf --headless` 2 runs each, first run after the shader change reported separately) and record frame time, p95, p99, worst, draw calls, warm-up time and the pck size there, next to the previous numbers. Expected: WebKit 60 fps and no frame over 25 ms on any build. If not met, stop and report with the numbers; don't tune silently.
- [ ] **Step 5: After sheet.** Run the stills tool with `--before=/tmp/condo-stills/before` into `/tmp/condo-stills/after` and give the owner the path to `sheet.png`.
- [ ] **Step 6: Full suite** `tools/test.sh`: all pass.
- [ ] **Step 7: Commit:** `docs: credits, size cap, measurements for the rebuilt objects`.
