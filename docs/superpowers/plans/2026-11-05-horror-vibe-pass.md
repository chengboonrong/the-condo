# The horror vibe pass: implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give THE CONDO a soft half-resolution picture with sharp text, grain at the 3D pixel size, a colour grade that cools act by act, three comfort settings, home sounds that stop one by one, and a rare still figure that the player can watch.

**Architecture:** A new `Look` node (`scripts/world/look.gd`) owns the picture: it sets the root window's 3D scale from the Filter setting and the window height, gives the HUD's film shader its pixel size, and eases the `Environment` adjustments toward a grade picked from `WorldState.act` and `WorldState.player_room`. `AudioDirector` gains three looping beds and a schedule that stops them, and `SilhouetteEvent` and `Silhouette` gain a "still" anchor kind. Field of view and head bob are read by `PlayerController` from `Settings`.

**Tech Stack:** Godot 4.7.2, typed GDScript, Compatibility renderer (WebGL2 on the web), Python 3 stdlib (`tools/gen_audio.py`), the project's headless test runner (`tools/test.sh`).

**Spec:** `docs/superpowers/specs/2026-11-05-horror-vibe-pass-design.md` (approved 2026-11-05). Background: `docs/research/2026-11-05-chillas-art-horror-vibe.md`.

Run everything from `/Users/chrischeng/the-condo` on branch `feat/vibe-pass`. Commands below use:
`GODOT=/Users/chrischeng/tools/godot-4.7.2/Godot.app/Contents/MacOS/Godot`.

## Global Constraints

* Godot 4.7.2, Compatibility renderer (WebGL2 in the browser). It must keep 60 fps in WebKit with no frame over 25 ms. Measure with the filter on and off, the way `docs/performance.md` does.
* What gives way when the look meets an anti-goal: first the frame budget, then whether a moved object can be noticed, then the exact look. If thin things shimmer or a moved object gets hard to see, raise the 3D scale first, up to about 540 lines (`Look.TARGET_LINES`). The rebuilt trailer-objects models are not reopened.
* MSAA 4x is already on (`project.godot`: `anti_aliasing/quality/msaa_3d=2`). It stays on and is measured as part of the build; it is not a step left to add.
* Bilinear 3D scaling (`Viewport.SCALING_3D_MODE_BILINEAR`), never nearest. Resolution scaling does not touch 2D, so the HUD stays sharp.
* Shader warm-up: whatever the grade and the beds first use is compiled or loaded behind the start card. The colour-correction adjustment is on from the first frame.
* New settings follow `Settings.DEFAULTS` and the pause menu's existing rows. Old saved settings files without the new keys must still load.
* Every test passes (`GODOT=$GODOT tools/test.sh`). Figure and story tests change only where the new staging needs them.
* Non-goals stay out: no VHS/CRT look, no chromatic aberration, no date stamp or REC overlay, no camera shake or extra sway.
* Every sound is made by `tools/gen_audio.py` (stdlib only). Existing WAVs stay byte-identical: new sounds go at the end of `main()` and use their own `random.Random`.
* The web `index.pck` stays at most 8912 KiB (`tools/smoke.sh`).
* No external LLM APIs, no paid assets or services, nothing pushed, merged or published. Never `git stash`.
* Typed GDScript; match the surrounding comment density and plain-English comments.
* Same seed, same playthrough: a change in `prepare()` must not change how many times it draws from `ctx.rng`.
* Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. No model names anywhere in the repo.

## Review Focus

1. **A window that is not 900 px tall:** a 1280×720 browser canvas, a 1440p or 4K fullscreen window, or a window resized mid-game. The 3D scale follows at an integer divisor and the HUD stays sharp. Pinned by Task 1's `test_the_filter_follows_a_resized_window`.
2. **A settings file from before this pass,** with none of the new keys. It loads, keeps the player's old values and gives the new keys their defaults. Pinned by Task 3's `test_old_settings_files_still_load`.
3. **A new shift after a cold act** (Play again, Restart). It starts warm at once: no ease from a cold grade, beds playing, fan turning. Pinned by Task 2's `test_a_new_shift_starts_warm` and Task 4's `test_a_new_shift_brings_the_home_sounds_back`.
4. **The player walks up to a still figure,** or first sees it from close by. It fades silently: no stinger, and no figure left standing in the player's face like a dummy. Pinned by Task 5's `test_a_still_figure_walked_up_to_fades_silently`.
5. **A still figure that is never looked at.** It goes after its wait and the run completes without counting as seen. Pinned by Task 5's `test_an_unwatched_still_figure_leaves_unseen`.

---

### Task 1: Soft filter and grain at the 3D pixel size

**Files:**
- Create: `scripts/world/look.gd`
- Modify: `scripts/core/settings.gd` (DEFAULTS)
- Modify: `scripts/ui/hud.gd:7-29` (FILM_SHADER), `:56-64` (film rect)
- Modify: `scripts/main.gd` (create the Look; the `nofilter` flag)
- Modify: `docs/architecture.md` "## Look" (new bullet after "Grain and vignette")
- Test: `tests/integration/test_look.gd` (new)

**Interfaces:**
- Produces:
  - `class_name Look extends Node`, created by `main.gd` as `var look: Look` (node name `"Look"`).
  - `const TARGET_LINES := 450.0`.
  - `var environment: Environment` (used by Task 2) and `var film: ShaderMaterial`. Main sets both before `add_child`.
  - `static func divisor_for(height: int) -> int`.
  - `Hud.film_material: ShaderMaterial`.
  - Settings key `"filter"` (bool, default `true`).
  - The flag `-- --nofilter` / `?nofilter`.
- Consumes: `Settings.changed`, `Settings.get_value`, `Main.has_flag`.

- [ ] **Step 1: Write the failing tests** in `tests/integration/test_look.gd`. Use the `_main()` and `_frames()` helpers from `tests/integration/test_horror_in_game.gd:5-16`: instance `res://scenes/main.tscn`, set `player.input_enabled = true`, wait 2 physics frames.

```gdscript
func test_the_filter_follows_the_window_height() -> bool:
	eq(Look.divisor_for(900), 2, "900 px tall: 450 lines")
	eq(Look.divisor_for(1080), 2, "1080: 540 lines")
	eq(Look.divisor_for(720), 2, "720: 360 lines is nearer 450 than 720")
	eq(Look.divisor_for(1440), 3, "1440: 480 lines")
	eq(Look.divisor_for(2160), 5, "2160: 432 lines")
	eq(Look.divisor_for(500), 1, "a small window stays sharp")
	return true


func test_the_filter_softens_the_3d_and_turns_off() -> bool:
	var main := await _main()
	var film: ShaderMaterial = main.hud.film_material
	eq(tree.root.scaling_3d_mode, Viewport.SCALING_3D_MODE_BILINEAR, "bilinear, not nearest")
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "on by default: half resolution at 1600x900")
	near(float(film.get_shader_parameter("pixel_size")), 2.0, 0.001, "grain at the 3D pixel size")
	Settings.set_value("filter", false)
	near(tree.root.scaling_3d_scale, 1.0, 0.001, "off: full resolution")
	near(float(film.get_shader_parameter("pixel_size")), 1.0, 0.001, "and the grain as before")
	Settings.set_value("filter", true)
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "on again at once")
	main.queue_free()
	return true


func test_the_filter_follows_a_resized_window() -> bool:
	var main := await _main()
	tree.root.size = Vector2i(2560, 1440)
	await tree.process_frame
	near(tree.root.scaling_3d_scale, 1.0 / 3.0, 0.001, "1440 px tall: a third")
	near(float(main.hud.film_material.get_shader_parameter("pixel_size")), 3.0, 0.001, "grain follows")
	tree.root.size = Vector2i(1600, 900)  # the runner's size, for the tests after this one
	await tree.process_frame
	near(tree.root.scaling_3d_scale, 0.5, 0.001, "back to a half")
	main.queue_free()
	return true
```

- [ ] **Step 2: Run them and check that they fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_look`
Expected: FAIL with `test_look.gd — does not load` (no `Look` class yet).

- [ ] **Step 3: Implement**
  - `settings.gd`: add `"filter": true` to `DEFAULTS`.
  - `hud.gd`: add `uniform float pixel_size = 1.0;` to `FILM_SHADER`. Hash `floor(FRAGCOORD.xy / pixel_size)` instead of `FRAGCOORD.xy`, so one grain value covers one 3D pixel. Update the shader's comment to say so. Keep the material as `var film_material: ShaderMaterial`.
  - `look.gd`: `_ready()` connects `Settings.changed` and `get_window().size_changed` to one `_apply_filter()`, then calls it.
    - `_apply_filter()` sets the window's `scaling_3d_mode` to bilinear.
    - It sets `scaling_3d_scale = 1.0 / d` and the film's `pixel_size = d`, where `d = divisor_for(get_window().size.y)` when `Settings.get_value("filter")`, else 1.
    - `divisor_for(height)` is `maxi(1, roundi(height / TARGET_LINES))`.
    - Write the scale only when it changes. `Settings.changed` fires for every setting, a brightness drag included, and resizing the 3D buffers is not free.
    - Doc comment: the soft picture follows the window, so the look is the same at any size.
  - `main.gd` `_ready()`:
    - Right after the builder is added: `if has_flag("nofilter"): Settings.values["filter"] = false`. Its comment: perf runs measure the sharp picture without touching the saved settings.
    - After `hud.bind(player)`: create `look`, set `look.environment = builder.environment` and `look.film = hud.film_material`, and `add_child(look)`.
  - `docs/architecture.md` "## Look": one bullet, **Soft filter**. Cover the 3D at about 450 lines (an integer divisor of the window height), bilinear, the HUD at full resolution, the Filter setting, grain snapped to 3D pixels while it is on, and `TARGET_LINES` as the knob (up to 540 if thin things shimmer).

- [ ] **Step 4: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=test_look`, then `GODOT=$GODOT tools/test.sh`
Expected: the three new tests PASS; then the full suite passes (83 + 3).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/look.gd scripts/core/settings.gd scripts/ui/hud.gd scripts/main.gd docs/architecture.md tests/integration/test_look.gd
git commit -m "look: soft half-resolution filter with grain at the 3D pixel size"
```

---

### Task 2: A colour grade per act

**Files:**
- Modify: `scripts/world/look.gd`
- Modify: `docs/architecture.md` "## Look" (a **Colour grade** bullet)
- Test: `tests/integration/test_look.gd`

**Interfaces:**
- Consumes: `Look.environment` (Task 1), `WorldState.act`, `WorldState.player_room`, `WorldState.set_act(value: int)`.
- Produces:
  - `const GRADES: Dictionary` (keys `1`–`4` and `&"mirror_room"`).
  - `const EASE_SECONDS := 4.0`.
  - `func target_grade() -> Dictionary`.
  - `func settle() -> void`, which jumps to the target now. `_ready()` calls it; Task 6's stills call it per shot.

Values (my call; the stills' two grades are acts 1 and 2):

```gdscript
const GRADES := {
	1: {"saturation": 1.08, "contrast": 1.02, "black": Color(0.0, 0.0, 0.0), "white": Color(1.0, 0.96, 0.88)},
	2: {"saturation": 0.62, "contrast": 1.08, "black": Color(0.0, 0.015, 0.03), "white": Color(0.88, 0.95, 1.0)},
	3: {"saturation": 0.54, "contrast": 1.10, "black": Color(0.0, 0.018, 0.035), "white": Color(0.86, 0.94, 1.0)},
	4: {"saturation": 0.46, "contrast": 1.12, "black": Color(0.0, 0.02, 0.04), "white": Color(0.84, 0.93, 1.0)},
	&"mirror_room": {"saturation": 0.34, "contrast": 1.14, "black": Color(0.0, 0.02, 0.04), "white": Color(0.82, 0.92, 1.0)},
}
```

- [ ] **Step 1: Write the failing tests** (append to `test_look.gd`)

```gdscript
func test_act_one_is_warm_and_full_from_the_first_frame() -> bool:
	var main := await _main()
	var env: Environment = main.builder.environment
	check(env.adjustment_enabled, "the grade is on from the start, so nothing compiles mid-game")
	near(env.adjustment_saturation, 1.08, 0.001, "act 1 saturation")
	near(env.adjustment_contrast, 1.02, 0.001, "act 1 contrast")
	var g: Gradient = (env.adjustment_color_correction as GradientTexture1D).gradient
	eq(g.get_color(1), Color(1.0, 0.96, 0.88), "a warm white")
	main.queue_free()
	return true


func test_each_act_eases_colder() -> bool:
	var main := await _main()
	var env: Environment = main.builder.environment
	WorldState.set_act(2)
	await _frames(30)  # half a second of a 4 s ease
	check(env.adjustment_saturation < 1.08 and env.adjustment_saturation > 0.62, "it eases, it does not cut")
	await _frames(250)
	near(env.adjustment_saturation, 0.62, 0.001, "act 2 saturation")
	near(env.adjustment_contrast, 1.08, 0.001, "act 2 contrast")
	WorldState.set_act(3)
	main.look.settle()
	check(env.adjustment_saturation < 0.62, "act 3 is more drained")
	check((env.adjustment_color_correction as GradientTexture1D).gradient.get_color(1).r < 0.88, "and colder")
	main.queue_free()
	return true


func test_b1107_is_the_most_drained() -> bool:
	for k: Variant in Look.GRADES:
		check(Look.GRADES[&"mirror_room"]["saturation"] <= Look.GRADES[k]["saturation"], "nothing is greyer than B-11-07 (%s)" % k)
	var main := await _main()
	WorldState.set_variant(&"bedroom", &"door")
	main.player.global_position = ApartmentLayout.room_center(&"mirror_room", WorldState.variants)
	await _frames(2)  # main sets player_room on the physics tick
	main.look.settle()
	near(main.builder.environment.adjustment_saturation, 0.34, 0.001, "B-11-07's grade")
	main.queue_free()
	return true


func test_a_new_shift_starts_warm() -> bool:
	WorldState.act = 3  # a cold act left over from the last shift; main resets it
	var main := await _main()
	near(main.builder.environment.adjustment_saturation, 1.08, 0.001, "warm at once, no ease from cold")
	main.queue_free()
	return true
```

- [ ] **Step 2: Run them and check that they fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_look`
Expected: the 4 new tests FAIL (no adjustment yet; `settle` and `GRADES` are not defined, so the file may not load).

- [ ] **Step 3: Implement in `look.gd`**
  - In `_ready()`, before `settle()`: `environment.adjustment_enabled = true`, and `adjustment_color_correction` = a `GradientTexture1D` over a 2-point `Gradient` (black at offset 0, white at 1) kept in a member.
  - `target_grade()` returns `GRADES[&"mirror_room"]` when `WorldState.player_room == &"mirror_room"`, else `GRADES[clampi(WorldState.act, 1, 4)]` (ENDED keeps act 4's).
  - `_process(delta)` polls `target_grade()`. When the target changes, remember the current values and ease from them. The ease is a smoothstep over `EASE_SECONDS`.
  - Write saturation, contrast and the two gradient colours only while easing. A still grade costs nothing per frame, and the gradient texture is not re-uploaded.
  - `settle()` jumps straight to the target and ends any ease.
  - Polling instead of `EventBus.act_changed`: `WorldState.reset()` sets the act without emitting, and the room changes on the physics tick.
  - `docs/architecture.md` "## Look": a **Colour grade** bullet. Cover the per-act table in words (warm and full at home, then a step colder and greyer per act, B-11-07 greyest), the 4 s ease, and that the adjustment is on from the first frame so the warm-up compiles it.

- [ ] **Step 4: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=test_look`, then `GODOT=$GODOT tools/test.sh`
Expected: all of `test_look.gd` PASSES; the full suite passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/look.gd docs/architecture.md tests/integration/test_look.gd
git commit -m "look: colour grade per act, easing colder, B-11-07 the greyest"
```

---

### Task 3: Filter, field of view and head bob settings

**Files:**
- Modify: `scripts/core/settings.gd` (DEFAULTS)
- Modify: `scripts/player/player_controller.gd:37-39` (`_ready`), `:111-123` (`_update_steps`)
- Modify: `scripts/ui/pause_menu.gd:15-45`
- Test: `tests/integration/test_pause_menu.gd`

**Interfaces:**
- Consumes: Settings key `"filter"` and `Look` (Task 1).
- Produces:
  - Settings keys `"fov"` (float, default `72.0`) and `"head_bob"` (float 0–1, default `1.0`).
  - The pause-menu rows are named after their keys (`"filter"`, `"fov"`, `"head_bob"`), and the panel is named `"Frame"`.

- [ ] **Step 1: Write the failing tests** (append to `test_pause_menu.gd`; its `_main()` clicks past the start card)

```gdscript
func test_new_settings_change_the_game_at_once_and_persist() -> bool:
	var main := await _main()
	var player: PlayerController = main.player
	var menu: PauseMenu = main.pause
	menu.open()
	(menu.find_child("fov", true, false) as HSlider).value = 64.0
	near(player.camera.fov, 64.0, 0.001, "field of view changes at once")
	var filter: Button = menu.find_child("filter", true, false)
	filter.button_pressed = false
	near(tree.root.scaling_3d_scale, 1.0, 0.001, "the filter turns off at once")
	eq(filter.text, "Filter: Off", "and the menu says so")
	menu.close()
	player.use_scripted_move = true
	player.scripted_move = Vector2(0, 1)  # north from the spawn: 2 m of clear floor in a second
	var most := 0.0
	for i in 60:
		await tree.physics_frame
		most = maxf(most, absf(player.camera.position.y))
	check(player.horizontal_speed() > 1.5, "(walking, not stopped by a wall)")
	check(most > 0.005, "the head bobs at 100%")
	Settings.set_value("head_bob", 0.0)
	player.global_position = ApartmentLayout.SPAWN  # the same clear walk again
	await _frames(2)
	most = 0.0
	for i in 60:
		await tree.physics_frame
		most = maxf(most, absf(player.camera.position.y))
	check(player.horizontal_speed() > 1.5, "(walking)")
	near(most, 0.0, 0.0001, "and not at all at 0%")
	var cfg := ConfigFile.new()
	eq(cfg.load(Settings.path), OK, "saved")
	eq(cfg.get_value("settings", "fov"), 64.0, "with the field of view")
	eq(cfg.get_value("settings", "filter"), false, "the filter")
	eq(cfg.get_value("settings", "head_bob"), 0.0, "and the head bob")
	main.queue_free()
	return true


func test_old_settings_files_still_load() -> bool:
	var cfg := ConfigFile.new()  # saved before this pass: none of the new keys
	cfg.set_value("settings", "brightness", 1.3)
	cfg.save(Settings.path)
	Settings._ready()
	near(float(Settings.get_value("brightness")), 1.3, 0.001, "the player's old value is kept")
	eq(Settings.get_value("filter"), true, "new keys get their defaults: filter on")
	near(float(Settings.get_value("fov")), 72.0, 0.001, "field of view 72")
	near(float(Settings.get_value("head_bob")), 1.0, 0.001, "head bob 100%")
	return true


func test_the_menu_fits_the_window() -> bool:
	var main := await _main()
	main.pause.open()
	await tree.process_frame  # one layout pass
	var frame: Control = main.pause.find_child("Frame", true, false)
	check(tree.root.get_visible_rect().encloses(frame.get_global_rect()), "every row is on screen at 1600x900")
	main.pause.close()
	main.queue_free()
	return true
```

- [ ] **Step 2: Run them and check that they fail**

Run: `GODOT=$GODOT tools/test.sh --filter=test_pause_menu`
Expected: FAIL on `find_child("fov")` (null) and on `Settings.get_value("fov")` (null).

- [ ] **Step 3: Implement**
  - `settings.gd` `DEFAULTS`: add `"fov": 72.0, "head_bob": 1.0`. Loading already falls back to `DEFAULTS` per key, so old files need nothing more.
  - `player_controller.gd`:
    - `_ready()` connects `Settings.changed` to a new `_apply_settings()` and calls it. `_apply_settings()` sets `camera.fov = float(Settings.get_value("fov"))`.
    - Apply it on change, not every frame: `tools/stills.gd` sets a per-shot fov.
    - In `_update_steps`, multiply the bob by `float(Settings.get_value("head_bob"))`. Footsteps still follow `_stride`.
  - `pause_menu.gd`:
    - Rows in this order: title, Resume, Brightness, **Field of view** (`_slider(box, "Field of view", "fov", 60.0, 80.0, 1.0)`), **Head bob** (`_slider(box, "Head bob", "head_bob", 0.0, 1.0, 0.05)`), Mouse sensitivity, Volume, **Filter** (`_check(box, "Filter", "filter")`), Invert mouse Y, Captions, Reduced flashing, Restart, Quit.
    - Name the PanelContainer `"Frame"`.
    - Centre it on its own size instead of the fixed `Vector2(-300, -330)`: `PRESET_CENTER` with `grow_horizontal` and `grow_vertical` both `GROW_DIRECTION_BOTH`.
    - If the fit test still fails, lower the VBox separation from 12 to 8.

- [ ] **Step 4: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=test_pause_menu`, then `GODOT=$GODOT tools/test.sh`
Expected: PASS, then the full suite passes.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/settings.gd scripts/player/player_controller.gd scripts/ui/pause_menu.gd tests/integration/test_pause_menu.gd
git commit -m "settings: filter, field of view and head bob in the pause menu"
```

---

### Task 4: Home sounds, then silence

**Files:**
- Modify: `tools/gen_audio.py` (end of `main()`; one helper)
- Create: `assets/audio/fan.wav`, `fridge.wav`, `tv_murmur.wav`, and their `.wav.import` files (`edit/loop_mode=2`)
- Modify: `scripts/world/audio_director.gd`
- Modify: `scripts/world/apartment_builder.gd:147`, `:211-213` (fan speed)
- Modify: `scripts/main.gd` (`audio.builder = builder`)
- Modify: `docs/architecture.md` "## Audio levels" (three rows and one sentence)
- Test: `tests/unit/test_beds.gd` (new), `tests/integration/test_home_beds.gd` (new)

**Interfaces:**
- Consumes: `WorldState.act`, `WorldState.time`.
- Produces:
  - `AudioDirector.BEDS: Dictionary`, keyed `&"fan"`, `&"fridge"`, `&"tv"`. Each entry has `stream`, `pos`, `db`, `act`, `after` (s) and `fade` (s).
  - `static func bed_due(bed: Dictionary, act: int, seconds_in_act: float) -> bool`.
  - `var beds: Dictionary` (id → `AudioStreamPlayer3D`).
  - `var builder: ApartmentBuilder`.
  - `ApartmentBuilder.fan_speed: float` (1.0 turns at today's 2.6 rad/s).

The beds and their schedule (my calls; the spec leaves the synthesis, the order and the timing to the builder):

| Bed | Sound | Where | Heard at | Stops | Fade |
|---|---|---|---|---|---|
| `tv` | a neighbour's TV through the wall: two voice-like murmurs (band-limited noise 200–700 Hz, syllable envelopes 3–5 per second, phrases of 1–3 s, pauses 0.3–0.8 s), low-passed near 450 Hz for the wall. No words, no music. 12 s loop. | `Vector3(10.4, 1.0, 1.0)`, behind the east wall (B-12-08) | −40 dB | when act 2 begins (the wall has just knocked back) | 1.5 s |
| `fridge` | compressor hum: 50 Hz with 100 and 150 Hz harmonics, a faint `lowpass(noise, 300)`, a 0.25 Hz wobble. 4 s loop. | `Vector3(0.45, 1.0, 2.95)` | −38 dB | 75 s into act 2, or when act 3 begins | 1.5 s |
| `fan` | air: `lowpass(noise, 900)` with a blade-pass swell at 7/6 Hz (7 per loop) at about 25% depth, plus a faint 100 Hz motor. 6 s loop. | `Vector3(6.5, 2.4, 7.0)` | −36 dB | 15 s into act 3 | 3 s wind-down: volume, pitch to 0.6, blades to a stop |

A bed is due when `act > bed.act`, or when `act == bed.act and seconds_in_act >= bed.after`. Skipping acts (F10) stops several at once; normal play stops them one at a time.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_beds.gd`:

```gdscript
extends TestCase


func test_the_home_sounds_stop_one_at_a_time() -> bool:
	var b := AudioDirector.BEDS
	for id: StringName in b:
		check(not AudioDirector.bed_due(b[id], 1, 999.0), "%s plays all through act 1" % id)
	check(AudioDirector.bed_due(b[&"tv"], 2, 0.0), "the TV next door stops when the wall answers")
	check(not AudioDirector.bed_due(b[&"fridge"], 2, 74.0), "the fridge keeps going a while")
	check(AudioDirector.bed_due(b[&"fridge"], 2, 75.0), "then stops 75 s into act 2")
	check(AudioDirector.bed_due(b[&"fridge"], 3, 0.0), "or when act 3 begins")
	check(not AudioDirector.bed_due(b[&"fan"], 3, 14.0) and AudioDirector.bed_due(b[&"fan"], 3, 15.0), "the fan last, 15 s into act 3")
	return true
```

`tests/integration/test_home_beds.gd` (with the `_main()` and `_frames()` helpers from `test_horror_in_game.gd`):

```gdscript
func test_home_sounds_play_and_loop_in_act_one() -> bool:
	var main := await _main()
	for id: StringName in [&"fan", &"fridge", &"tv"]:
		var p: AudioStreamPlayer3D = main.audio.beds[id]
		check(p.playing, "%s plays from the start" % id)
		eq((p.stream as AudioStreamWAV).loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s loops (its .import)" % id)
	main.queue_free()
	return true


func test_a_bed_fades_out_it_never_cuts() -> bool:
	var main := await _main()
	var tv: AudioStreamPlayer3D = main.audio.beds[&"tv"]
	var start := tv.volume_db
	WorldState.set_act(2)
	await _frames(30)
	check(tv.playing and tv.volume_db < start, "half a second in: fading, still playing")
	await _frames(70)
	check(not tv.playing, "gone after 1.5 s")
	check(main.audio.beds[&"fridge"].playing and main.audio.beds[&"fan"].playing, "the others keep going")
	main.queue_free()
	return true


func test_the_fan_winds_down_with_its_blades() -> bool:
	var main := await _main()
	WorldState.set_act(4)  # past every bed's act (as after F10): all stop
	await _frames(60)
	var fan: AudioStreamPlayer3D = main.audio.beds[&"fan"]
	check(fan.playing and fan.pitch_scale < 1.0, "a second in: winding down")
	check(main.builder.fan_speed > 0.0 and main.builder.fan_speed < 1.0, "the blades slow with it")
	await _frames(150)
	check(not fan.playing, "stopped after 3 s")
	eq(main.builder.fan_speed, 0.0, "and the blades stand still")
	main.queue_free()
	return true


func test_a_new_shift_brings_the_home_sounds_back() -> bool:
	WorldState.act = 4  # left over from the last shift; main resets it
	var main := await _main()
	await _frames(30)
	check(main.audio.beds[&"tv"].playing and main.audio.beds[&"fan"].playing, "home again")
	eq(main.builder.fan_speed, 1.0, "the fan turns")
	main.queue_free()
	return true
```

- [ ] **Step 2: Run them and check that they fail**

Run: `GODOT=$GODOT tools/test.sh --filter=beds`
Expected: FAIL (`BEDS`, `beds`, `fan_speed` not defined).

- [ ] **Step 3: Make the sounds**
  - In `tools/gen_audio.py`, add `loudest_100ms_db(x) -> float`: the highest RMS over 100 ms windows, in dBFS. The `docs/architecture.md` table measures files this way.
  - At the end of `main()`, each bed with its own `random.Random(<seed>)`:
    - Build the bed as in the table.
    - Make it seamless with `loopable(x, 0.5)`, generating 0.5 s more than the loop length.
    - Save it with `save(name, x, 0.5)` and print `name` with `loudest_100ms_db(normalize(x, 0.5))`.
  - Run `python3 tools/gen_audio.py`, then `git status --short assets/audio`. Expected: only the three new WAVs are new, and no existing WAV is modified.
  - Run `"$GODOT" --headless --path . --import` to create the three `.wav.import` files. In each, set `edit/loop_mode=2` (as in `drone.wav.import:21`), then import again.
  - Nobody in this session can listen; the owner hears the beds in the build. So also print each bed's loop seam: the absolute step from its last sample to its first, as a fraction of full scale. Each must be under 0.01. Write down the printed file levels.

- [ ] **Step 4: Play them**
  - `AudioDirector`:
    - `BEDS` const with the table's positions, acts, delays and fades.
    - Each `db` = the target heard level − the printed file level, rounded to 0.5 dB.
    - In `_ready()`, start one `AudioStreamPlayer3D` per bed (`unit_size 6.0`, `max_distance 18.0`) into `beds`.
    - `_process` tracks the act and the `WorldState.time` at which it began. It stops every playing bed that `bed_due(...)` says is due, once each.
  - Stopping a bed is a `create_tween()` on `volume_db` to −60 over its `fade`, then `stop()`. The fan's tween also takes `pitch_scale` to 0.6 and `builder.fan_speed` to 0.0 over the same 3 s, in parallel.
    - Tweens pause with the tree, so the pause menu freezes a fade.
  - Update the doc comment at the top to name the beds and the drop-outs.
  - `ApartmentBuilder`: `var fan_speed := 1.0`; `_process` turns the blades `delta * 2.6 * fan_speed`.
  - `main.gd`: `audio.builder = builder` before `add_child(audio)`.
  - `docs/architecture.md` "## Audio levels":
    - Add the three beds to the table: file level, played at, and a heard level of about −36 / −38 / −40.
    - Add one sentence: they stop one at a time (TV, fridge, fan), fading 1.5 s and winding down 3 s, and no sting marks it.

- [ ] **Step 5: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=beds`, then `GODOT=$GODOT tools/test.sh`
Expected: PASS, then the full suite passes. A headless leak warning for `AudioStreamPlaybackWAV` in filtered runs is known (`docs/test-plan.md:13`) and is not a failure.

- [ ] **Step 6: Commit**

```bash
git add tools/gen_audio.py assets/audio/fan.wav* assets/audio/fridge.wav* assets/audio/tv_murmur.wav* scripts/world/audio_director.gd scripts/world/apartment_builder.gd scripts/main.gd docs/architecture.md tests/unit/test_beds.gd tests/integration/test_home_beds.gd
git commit -m "audio: fan, fridge and a neighbour's TV in act 1, stopping one at a time"
```

---

### Task 5: A figure you can watch

**Files:**
- Modify: `scripts/world/apartment_layout.gd:105-122` (ANCHORS)
- Modify: `scripts/horror/events/silhouette_event.gd`
- Modify: `scripts/world/silhouette.gd`
- Modify: `docs/event-catalog.md:35` (the silhouette row)
- Test: `tests/unit/test_scheduler.gd`, `tests/unit/test_layout.gd`, `tests/integration/test_horror_in_game.gd`

**Interfaces:**
- Consumes: `EventBus.silhouette_requested(anchor_id, duration)`, `EventBus.silhouette_seen(anchor_id)` (signatures unchanged), `WorldState.is_light_on(room) -> bool`.
- Produces:
  - Anchor kind `"still"` with two extra fields: `"light"` (StringName) and `"dark"` (Array of rooms that must be unlit).
  - `SilhouetteEvent.STILL_MIN_DISTANCE := 5.0`, `STILL_WAIT := 8.0`, `STILL_WEIGHT := 1.0`.
  - `run["wait"]` (float).
  - `Silhouette.LOOK_AWAY := 0.2`.

Anchors (my call; add them after `sil_gap`):

```gdscript
	# A still figure stands in the pool of one light, its back to the player: the gap's caged bulkhead (lit in both
	# variants, always on), or the hallway downlight when no other lamp that reaches the hallway is on.
	&"still_gap": {"room": &"gap", "pos": Vector3(7.7, 0, -11.2), "kind": "still", "light": &"gap", "dark": []},
	&"still_hallway": {"room": &"hallway", "pos": Vector3(6.8, 0, 3.25), "kind": "still", "light": &"hallway", "dark": [&"living", &"kitchen", &"bathroom", &"bedroom"]},
```

Behaviour (the spec's goal 5):
- **Choosing it.** `prepare` treats `"still"` anchors like silhouette anchors, with three differences:
  - It also requires the anchor's `light` room lit and every `dark` room unlit, checked now. It never switches a light.
  - The minimum distance is `STILL_MIN_DISTANCE`.
  - The weight is `STILL_WEIGHT`.
  - It sets `run["wait"]`: `STILL_WAIT` for a still anchor, otherwise the resource's `duration`. `start` emits that, and `update` ends on it. 8 s stays inside the scheduler's 9 s timeout for the figure.
  - `options` gains entries, but `pick_weighted` is still called once.
- **Facing.** `Silhouette._on_requested` reads the anchor's kind. A still figure turns its back to where the player is (`look_at(..., not still)`).
- **Watching.** Seen after `SEEN_AFTER` in view, as today, it emits `silhouette_seen` but plays no stinger and does not fade.
  - It stays while any body point is visible.
  - Once none has been for `LOOK_AWAY` (looked away, or a corner between), it hides at once, unseen.
  - Within `VANISH_DISTANCE` it fades, silently.
  - Unseen, it hides when its wait runs out, as today.

- [ ] **Step 1: Write the failing tests**

`tests/unit/test_layout.gd`:

```gdscript
func test_still_figures_stand_under_their_light() -> bool:
	for id: StringName in ApartmentLayout.ANCHORS:
		var a: Dictionary = ApartmentLayout.ANCHORS[id]
		if a["kind"] != "still":
			continue
		var p: Vector3 = a["pos"]
		var near_light: Array = ApartmentLayout.LIGHTS[a["light"]]["pos"].filter(func(l: Vector3) -> bool: return Vector2(l.x - p.x, l.z - p.z).length() < 0.6)
		check(not near_light.is_empty(), "%s stands under a %s light" % [id, a["light"]])
		for variants: Dictionary in [{&"bedroom": &"door"}, {&"bedroom": &"door", &"gap": &"long"}]:
			eq(ApartmentLayout.room_at(p, variants), a["room"], "%s is inside its room (%s)" % [id, variants])
	return true
```

`tests/unit/test_scheduler.gd`:

```gdscript
func test_a_still_figure_needs_its_light_alone() -> bool:
	_setup(&"living", Vector3(6.5, 0, 8.4), PI)  # facing south, the hallway behind
	WorldState.set_light(&"hallway", true)
	eq(sched.check(&"silhouette", {"anchor": &"still_hallway"})["reason"], "no_hidden_anchor", "not while the living room lamp reaches it")
	WorldState.set_light(&"living", false)
	var run := sched.check(&"silhouette", {"anchor": &"still_hallway"})
	eq(run["state"], EventScheduler.State.VALIDATED, "the hallway downlight alone: it can stand there")
	near(run["wait"], SilhouetteEvent.STILL_WAIT, 0.001, "and waits longer than a glimpse")
	WorldState.set_light(&"hallway", false)
	eq(sched.check(&"silhouette", {"anchor": &"still_hallway"})["reason"], "no_hidden_anchor", "never in the dark")
	_teardown()
	return true
```

`tests/integration/test_horror_in_game.gd`. Each test starts like this: `_main()`, living light off, hallway light on, player at the spawn `(6.5, 0, 8.4)` with `set_look(0.0)` (the partition wall hides the hallway), a listener collecting `sound_requested` ids, and `var run: Dictionary = main.runtime.scheduler.start(&"silhouette", {"anchor": &"still_hallway", "ignore_act": true})`.

```gdscript
func test_a_still_figure_is_silent_and_stays_while_watched() -> bool:
	# (setup as above)
	eq(run["state"], EventScheduler.State.RUNNING, "staged")
	var fig: Silhouette = main.silhouette
	var to_player := main.player.global_position - fig.global_position
	check(Vector3(to_player.x, 0, to_player.z).dot(fig.global_basis.z) < 0.0, "its back to the player")
	main.player.global_position = Vector3(3.6, 0, 3.25)
	main.player.set_look(-PI / 2)  # down the hallway, east
	await _frames(60)
	check(run.get("seen", false), "a second in view counts as a sighting")
	check(fig.visible, "it stays while watched")
	near(fig._material.albedo_color.a, 0.95, 0.001, "and does not fade")
	check(not sounds.has(&"stinger"), "silent: no stinger")
	main.player.set_look(PI / 2)  # look away, west
	await _frames(20)
	check(not fig.visible, "gone once the player looks away")
	main.queue_free()
	return true


func test_a_still_figure_walked_up_to_fades_silently() -> bool:
	# (setup as above)
	main.player.global_position = Vector3(5.0, 0, 3.25)  # 1.8 m, inside VANISH_DISTANCE
	main.player.set_look(-PI / 2)
	await _frames(40)
	check(not main.silhouette.visible, "it fades instead of standing in the player's face")
	check(not sounds.has(&"stinger"), "silently")
	main.queue_free()
	return true


func test_an_unwatched_still_figure_leaves_unseen() -> bool:
	# (setup as above; the player never turns)
	await _frames(int(SilhouetteEvent.STILL_WAIT * 60) + 30)
	check(not main.silhouette.visible, "gone after its wait")
	eq(run["state"], EventScheduler.State.COMPLETED, "the run ends")
	check(not run.get("seen", false), "without a sighting")
	main.queue_free()
	return true
```

- [ ] **Step 2: Run them and check that they fail**

Run: `GODOT=$GODOT tools/test.sh --filter=still`
Expected: FAIL (no `still_*` anchors; `STILL_WAIT` undefined).

- [ ] **Step 3: Implement** the anchors, `SilhouetteEvent` and `Silhouette` as described above.
  - `test_silhouette_behind_then_seen`, `test_silhouette_never_appears_in_view_when_looking_down` and `test_silhouette_only_appears_out_of_view` must pass unchanged. At the initial lights, no still anchor qualifies.
  - In `docs/event-catalog.md:35`, add to the silhouette row's rules: a still staging at a `"still"` anchor, only when its light alone is on, its back turned, silent, staying while watched, gone on looking away. Waits 8 s.

- [ ] **Step 4: Run the tests**

Run: `GODOT=$GODOT tools/test.sh --filter=still`, then `GODOT=$GODOT tools/test.sh`
Expected: PASS, then the full suite passes, including `test_same_seed_same_playthrough` and `test_same_seed_same_decisions`.

- [ ] **Step 5: Commit**

```bash
git add scripts/world/apartment_layout.gd scripts/horror/events/silhouette_event.gd scripts/world/silhouette.gd docs/event-catalog.md tests/unit/test_scheduler.gd tests/unit/test_layout.gd tests/integration/test_horror_in_game.gd
git commit -m "figure: a still staging under one light, silent, gone when the player looks away"
```

---

### Task 6: Stills, builds and measurements

**Files:**
- Modify: `tools/stills.gd` (`--act=N`, settle per shot, a `still_gap` shot, a "faces away" column)
- Modify: `scripts/perf_probe.gd:85` (the report names the 3D scale)
- Modify: `tools/web_smoke.mjs:2,36` (`--nofilter` adds `&nofilter`)
- Modify: `docs/performance.md` (results after the vibe pass, filter on and off)

**Interfaces:**
- Consumes: `main.look.settle()` (Task 2), the `nofilter` flag (Task 1), the `still_gap` anchor position (Task 5).

- [ ] **Step 1: Stills**
  - `stills.gd`:
    - Accept `--act=N`. Once `main.loaded`, call `world.set_act(N)`.
    - Call `main.look.settle()` after each shot is set up, before the 10 frames.
    - Add an 11th SHOTS column, "faces away" (`false` for the 12 existing rows); the figure uses `look_at(..., not away)`.
    - Add `["still_gap", 7.7, -2.6, 0.0, 0.0, [], {&"bedroom": &"door"}, Vector3(7.7, 0, -11.2), false, 0.0, true]`.
    - Update the header comment.
  - Run both sheets (a window is needed):
    - `"$GODOT" --path . --script res://tools/stills.gd -- --out=/tmp/condo-vibe/act1 --before=/tmp/condo-stills/after`
    - `"$GODOT" --path . --script res://tools/stills.gd -- --act=2 --out=/tmp/condo-vibe/act2 --before=/tmp/condo-vibe/act1`
  - Expected: `saved /tmp/condo-vibe/act1` and `saved /tmp/condo-vibe/act2`, 13 stills each.
  - Look at both `sheet.png` files. Every trailer object must read clearly: shoes, the turned chair, the tap, the clock hands, the grilles, the figure. The still figure must read as a person in an apron, its back turned, not a dummy.
    - If a moved object reads worse or thin things break up, raise `Look.TARGET_LINES` toward 540 (the Global Constraints order), re-run the tests and both sheets, and note it.
- [ ] **Step 2: Tests** — `GODOT=$GODOT tools/test.sh`. Expected: `Results: N passed, 0 failed`.
- [ ] **Step 3: Builds and smoke**
  - Run `GODOT=$GODOT tools/export.sh`, then `PLAYWRIGHT_FROM=$HOME/work/the-house-web-port/ tools/smoke.sh`.
  - Expected: `SMOKE ok` for macOS, Chromium and WebKit, with the pck at or under 8912 KiB.
  - Look at `builds/smoke-chromium.png` and `builds/smoke-webkit.png`. The soft picture and the warm grade must show in the browsers too (WebGL2).
- [ ] **Step 4: Performance, filter on and off**
  - `perf_probe.gd`: add `3D scale %.2f` (`get_window().scaling_3d_scale`) to the first PERF line.
  - `web_smoke.mjs`: `--nofilter` appends `&nofilter` to the URL; document it in the header.
  - Re-export after these two changes, then run:
    - The macOS app `-- --perf` and `-- --perf --nofilter`, 3 runs each.
    - `node tools/web_smoke.mjs builds/web --perf --headless --webkit`, with and without `--nofilter`, 2 runs each.
    - `node tools/web_smoke.mjs builds/web --perf --chromium` (visible window), with and without `--nofilter`, 1 run each.
  - Expected: WebKit avg 16.67 ms (60 fps), and 0 frames over 25 ms on every build, filter on and off. If not, stop and report the numbers: the budget comes first.
- [ ] **Step 5: Record**
  - `docs/performance.md`: add "after the vibe pass" rows, filter on and filter off, to the Results tables and the memory/load table.
  - Add a dated section saying what was measured and what changed. Copy only numbers the runs printed.
- [ ] **Step 6: Commit**

```bash
git add tools/stills.gd scripts/perf_probe.gd tools/web_smoke.mjs docs/performance.md
git commit -m "tools: act 2 stills and a still-figure shot; perf with the filter on and off"
```
