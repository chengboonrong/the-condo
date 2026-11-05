# Performance

Measured 2026-11-04 on one machine: Apple M1 Max, 64 GB, macOS 27.0, Godot 4.7.2, Compatibility
renderer. This is a fast machine. Nothing has been measured on integrated graphics, Windows, Linux,
phones or real Safari, so no claim is made for them.

## How it was measured

`-- --perf` (desktop) or `?perf` (web) runs a scripted tour after the start card: 5 s in each of the
living room, kitchen, entrance, hallway, bathroom and bedroom, then the story skips to act 4 and the
tour visits the gap and B-11-07. The camera turns a full circle in every room. A scare is requested
every 3 s (knock, flicker, door, footsteps, silhouette in turn; cooldowns refuse some), and the phone
light (the only light that casts shadows) is on in every other room. 40 s of play, then one report.

```sh
tools/export.sh                                    # builds/ (needs GODOT=/path/to/Godot)
"builds/…/The Condo- 11-47 PM.app/Contents/MacOS/The Condo- 11-47 PM" -- --perf   # after unzipping
node tools/web_smoke.mjs builds/web --perf         # Chromium and WebKit, visible windows
node tools/web_smoke.mjs builds/web --perf --headless --webkit
node tools/web_smoke.mjs builds/web --perf --headless --webkit --nofilter   # filter off; -- --perf --nofilter on the desktop
godot --path . -- --perf                           # debug build from the project
```

* **Frame time** is the wall-clock time between frames (Godot's `delta` is smoothed, so it isn't
  used). The desktop turns vsync off, so its frame time is the real cost of a frame. Browsers always
  wait for the display: 120 Hz here for Chromium, 60 Hz for WebKit.
* **Render CPU** is `RenderingServer.viewport_get_measured_render_time_cpu` plus frame setup.
  **GPU time is not reported** by the Compatibility renderer (it returns 0). On the desktop the uncapped
  frame time is an upper bound for CPU and GPU work together.
* **Simulation step** times `HorrorRuntime.step` (time, profiler, entity, story, scheduler, director)
  on every physics tick; **director eval** times each scoring pass (every 0.25 s).
* **Memory**: peak resident memory of the macOS app process (sampled once a second with `ps`), video
  memory from Godot, and static memory from the debug build (release builds don't track it).
* **Load**: milliseconds after engine start until the condo is built, and until the shader warm-up
  behind the start card is done (see below). Web numbers start when the engine starts, after the
  download.

## Results

Measured after the detail pass (furniture, trim, fixtures, soft contact shadows, grain and vignette; see
[architecture.md](architecture.md#look)) and its review fixes, with up to 10 lights per mesh. The "before the detail pass" rows are the Phase 6 build (plaster
walls, nine box props); the "before the art pass" rows came before that. Same tour every time. The "after the vibe
pass" rows are the build with the soft filter and the colour grade, filter on (the 3D view drawn at half the window's
lines, 3D scale 0.50) and filter off (`--nofilter`, 3D scale 1.00); see [below](#after-the-vibe-pass-2026-11-05).

| Build | Runs | Avg frame | fps | p50 | p95 | p99 | Worst | Frames > 25 ms | Render CPU avg / p95 |
|---|---|---|---|---|---|---|---|---|---|
| macOS app (release), 1600×900, vsync off | 3 | 2.93–3.01 ms | 333–342 | 2.96–3.00 ms | 3.72–3.77 ms | 3.96–4.04 ms | 14.2–18.0 ms | 0 | 1.16–1.19 / 1.64–1.65 ms |
| macOS app (release), after the object rebuild, 1600×900, vsync off | 3 | 2.56–2.82 ms | 355–391 | 2.48–2.83 ms | 3.71–3.93 ms | 4.83–5.38 ms | 11.6–14.0 ms | 0 | 1.11–1.19 / 1.71–1.81 ms |
| macOS app (release), after the vibe pass, filter on, 1600×900, vsync off | 3 | 1.98–1.99 ms | 501–504 | 1.91–1.92 ms | 2.54–2.61 ms | 2.81–2.87 ms | 10.26–11.12 ms | 0 | 0.95–0.97 / 1.43–1.48 ms |
| macOS app (release), after the vibe pass, filter off, 1600×900, vsync off | 3 | 2.99–3.01 ms | 332–335 | 2.98–3.01 ms | 3.75–3.81 ms | 3.99–4.06 ms | 14.33–16.71 ms | 0 | 1.17–1.18 / 1.65–1.70 ms |
| macOS app (release), before the detail pass | 3 | 2.95–2.98 ms | 335–339 | 2.95–2.98 ms | 3.73 ms | 4.10–4.11 ms | 18.2–20.8 ms | 0 | 1.19–1.20 / 1.58–1.60 ms |
| macOS app (release), before the art pass | 3 | 2.52–2.73 ms | 367–396 | 2.64–2.71 ms | 3.40–3.53 ms | 3.81–3.90 ms | 12.4–13.6 ms | 0 | 0.98–1.05 / 1.43–1.46 ms |
| Project in the editor binary (debug), before the art pass, 1600×900, vsync off | 1 | 2.41 ms | 414 | 2.41 ms | 3.50 ms | 4.07 ms | 11.5 ms | 0 | 0.99 / 1.49 ms |
| Web, Chromium (Playwright 1.63), 1280×720, visible window | 2 | 8.33 ms | 120 | 8.30 ms | 10.9–11.1 ms | 11.8–11.9 ms | 13.4–14.3 ms | 0 | 0.55–0.57 / 0.80–0.90 ms |
| Web, Chromium, after the object rebuild, visible window | 2 | 8.33 ms | 120 | 8.30 ms | 9.9–10.4 ms | 11.0–11.2 ms | 12.1–13.8 ms | 0 | 0.46–0.48 / 0.80 ms |
| Web, Chromium, after the vibe pass, filter on, visible window | 1 | 8.33 ms | 120 | 8.30 ms | 11.0 ms | 11.9 ms | 13.2 ms | 0 | 0.50 / 0.80 ms |
| Web, Chromium, after the vibe pass, filter off, visible window | 1 | 8.33 ms | 120 | 8.40 ms | 11.1 ms | 12.0 ms | 15.6 ms | 0 | 0.54 / 0.80 ms |
| Web, WebKit (Playwright 1.63), 1280×720, headless | 2 | 16.67 ms | 60 | 17 ms | 18 ms | 18–19 ms | 23 ms | 0 | 2.34–2.37 / 4.00 ms |
| Web, WebKit, after the object rebuild, headless | 2 | 16.67 ms | 60 | 17 ms | 18 ms | 19 ms | 22, 25 ms | 0 | 1.93–2.49 / 3.00–4.00 ms |
| Web, WebKit, after the vibe pass, filter on, headless | 2 | 16.67 ms | 60 | 17 ms | 18 ms | 18 ms | 23, 22 ms | 0 | 2.26–2.31 / 4.00 ms |
| Web, WebKit, after the vibe pass, filter off, headless | 2 | 16.67 ms | 60 | 17 ms | 18 ms | 19 ms | 20, 21 ms | 0 | 2.20–2.29 / 3.00–4.00 ms |
| Web, Chromium, before the detail pass | 1 | 8.33 ms | 120 | 8.30 ms | 11.1 ms | 12.2 ms | 14.5 ms | 0 | 0.51 / 0.80 ms |
| Web, WebKit, before the detail pass | 1 | 16.67 ms | 60 | 17 ms | 18 ms | 19 ms | 23 ms | 0 | 2.12 / 3.00 ms |

| Build | Simulation step avg / p95 / max | Director eval avg / max (153 evals) | Draw calls avg / max |
|---|---|---|---|
| macOS app (release) | 52–55 / 95–99 / 239–356 µs | 3 / 6–8 µs | 87–89 / 284 |
| macOS app (release), after the object rebuild | 50–52 / 80–83 / 212–224 µs | 2 / 4–7 µs | 84 / 279–280 |
| macOS app (release), after the vibe pass, filter on | 41–43 / 70–72 / 212–217 µs | 2 / 4–5 µs | 85–86 / 280 |
| macOS app (release), after the vibe pass, filter off | 51–55 / 86–102 / 224–251 µs | 2–3 / 6–7 µs | 87–88 / 279–280 |
| macOS app (release), before the detail pass | 59–62 / 105–110 / 325–347 µs | 3–4 / 7–10 µs | 65–66 / 208 |
| Debug build (before the art pass) | 61 / 127 / 427 µs | 3 / 8 µs | 58 / 191 |
| Chromium | 148–154 / 300 / 3500–3600 µs | 5–8 / 100 µs | 93 / 283 |
| Chromium, after the object rebuild, visible window | 86–95 / 200 / 2300–3900 µs | 4–5 / 100 µs | 91 / 276–277 |
| Chromium, after the vibe pass, filter on, visible window | 110 / 200 / 2800 µs | 5 / 100 µs | 91 / 276 |
| Chromium, after the vibe pass, filter off, visible window | 131 / 300 / 3700 µs | 4 / 100 µs | 91 / 276 |
| WebKit | 146–159 / 1000 / 5000 µs | at most 1 ms (the browser's timer only has 1 ms steps) | 93 / 283 |
| WebKit, after the object rebuild, headless | 90–99 / 1000 / 3000–5000 µs | at most 1 ms | 91 / 275–276 |
| WebKit, after the vibe pass, filter on, headless | 107–123 / 1000 / 4000 µs | under 1 ms (printed as 0) | 91 / 275 |
| WebKit, after the vibe pass, filter off, headless | 90–132 / 1000 / 2000–3000 µs | under 1 ms (printed as 0) | 91 / 276–277 |
| Chromium / WebKit, before the detail pass | 166 / 300 / 3800 µs; 118 / 1000 / 4000 µs | 7 / 100 µs; under 1 ms | 68 / 207 |

The detail pass raised draw calls from about 66 to 88 a frame on average (max 208 to 284): each room's
furniture is one mesh per material. Ceiling lights add no draw calls in this renderer (each mesh is shaded
by its lights in one pass); only the phone light, which casts shadows, draws what it reaches once more.
On this machine the frame time did not change; on integrated graphics it is unmeasured.

Browser timers are coarse (0.1 ms steps in Chromium, 1 ms in WebKit), so the web simulation and director
numbers are rounded, not exact. The simulation costs well under a millisecond per physics tick on every
build measured; the director's scoring pass is a few microseconds.

The simulated playthroughs (`docs/playthroughs.md`, bots driving the simulation headless) report the
director's slowest single evaluation over a whole story: 0.9–1.6 ms in earlier runs on this machine. That
is a maximum, often the first evaluation, not a typical cost.

### Memory and load

| Build | Memory | Condo built | Shader warm-up done |
|---|---|---|---|
| macOS app (release) | 280 MB peak resident; video 82.5 MB | 522–544 ms | 2.39–2.43 s; 3.11 s on the first run after the export |
| macOS app (release), after the object rebuild | video 114.4 MB (peak resident not re-measured) | 651–722 ms | 3.48–3.56 s; 3.82 s on the first run after the export (no smoke run before it) |
| macOS app (release), after the vibe pass, filter on | 349–351 MB peak resident; video 71.8 MB | 646–665 ms | 3370–3383 ms (a smoke run before them) |
| macOS app (release), after the vibe pass, filter off | 349 MB peak resident; video 114.4 MB | 641–642 ms | 3398–3471 ms |
| macOS app (release), before the detail pass | 251–253 MB peak resident; video 81.2 MB | 490–519 ms | 1.91–1.95 s |
| Debug build (before the art pass) | static 48.6 MB; video 81.2 MB | 586 ms | 2.08 s |
| Chromium | video 66.9 MB | 836–1071 ms | 2.64 s; 6.61 s on the first run after the shaders changed (before the detail pass: 2.27 s; first ever run on this Mac: 11.8 s) |
| Chromium, after the object rebuild, visible window | video 98.8 MB | 1055–1071 ms | 3.55 s; 4.02 s on the first run of this build (no smoke run before it) |
| Chromium, after the vibe pass, filter on, visible window | video 71.6 MB | 1140 ms | 4062 ms, the first visible-window run of this build (the smoke run before it is headless) |
| Chromium, after the vibe pass, filter off, visible window | video 98.8 MB | 1026 ms | 3390 ms |
| WebKit | video 62.8 MB | 508–772 ms | 2.73 s; 6.78 s on the first run after the shaders changed (before the detail pass: 2.52 s) |
| WebKit, after the object rebuild, headless | video 94.8 MB | 719–1010 ms | 3.48 s; 4.78 s on the first run of this build (no smoke run before it) |
| WebKit, after the vibe pass, filter on, headless | video 67.5 MB | 743–751 ms | 3461–3486 ms (a smoke run before them) |
| WebKit, after the vibe pass, filter off, headless | video 94.8 MB | 738–740 ms | 3477–3542 ms |

The first time Chromium ever ran the game on this Mac, compiling the shaders took 9.7 s; later runs took
about 1.5 s, most likely because the GPU driver kept the compiled shaders. A player's first visit in
Chrome may wait that long on "Loading…". A change to the shaders starts it over: the first run after the
light limit changed took 6.6 s in Chromium and 6.8 s in WebKit, the next 2.6–2.7 s. The download is the engine, `index.wasm`, 39.5 MB raw
(10.1 MB with `gzip -6`), plus the game data, `index.pck`, 6.35 MB raw (6,351,932 bytes after the vibe pass, 6,130,936 with `gzip -6`; it was
5.95 MB after the object rebuild and about 0.74 MB before it).

Desktop downloads after the vibe pass: macOS zip 66,606,827 bytes, Windows exe 115,620,424, Linux binary 79,871,352
(see [the vibe-pass numbers](#after-the-vibe-pass-2026-11-05); they were 61, 110 and 74 MB after the detail pass).

### After the object rebuild (2026-11-05)

Measured on the build that replaced about a dozen box objects with Blender models (`art/<id>/build.py`; see
[architecture.md](architecture.md#look)), with the figure's warm-up fixed (below), same machine, same tour,
`tools/export.sh` then the commands above: Chromium in a visible window, WebKit headless, and no smoke run before
them. The rows marked "after the object rebuild" in the tables above are these runs; the numbers before them are
untouched.

* **Download**: `index.pck` 5.95 MB (5,950,668 bytes; `tools/smoke.sh` prints and checks it in KiB: 5812 against the
  8912 KiB cap), up from about 0.74 MB; `index.wasm` is unchanged at 39.5 MB raw. Desktop: macOS zip 66 MB, Windows exe
  115 MB, Linux binary 79 MB (were 61, 110, 74).
* **Load time** (the table above): the shader warm-up behind the start card is done 0.75–1.2 s later, about 3.5 s
  instead of 2.4–2.7 s (macOS +1.05–1.17 s, Chromium +0.9 s, WebKit +0.75 s), and the condo is built 0.1–0.25 s
  later on macOS and in WebKit (Chromium: inside its earlier range). The pck is 5.2 MB larger, still inside the 8912 KiB cap.
* **Draw calls** average 84–91 a frame, about the same as before (87–93); the maximum is 275–280 (was 283–284).
* **WebKit holds 60 fps** (16.67 ms average, p95 18 ms, p99 19 ms) and Chromium 120 fps. No frame went over 25 ms in
  any run. WebKit's worst, 25 ms in its second run, is on the line rather than over it, and its timer only has 1 ms
  steps.
* **The hitch found and fixed**: before the fix every run had one frame over 25 ms at 16.1–16.2 s (macOS 107, 44 and
  44 ms, Chromium 190 and 31, WebKit 239 and 33), the first frame the figure was on screen, at the corridor's west end
  seen from the hallway under a ceiling light alone; since 52d260b the figure has materials of its own, the warm-up
  drew it only with the phone light on it, and in this renderer an object under a shadowed light uses another variant
  of its first pass, so the variant without one compiled on first sight; the warm-up now shows the figure under each
  light state (ceiling light on or off, phone light on or off).
* **Machine load**: other sessions share the machine. Load averages (1 min) before and after each run: macOS 8.3 and 5.8, 5.8
  and 4.1, 4.1 and 3.4 (before the first, another session's headless Chromium at 70 % CPU); Chromium 3.1 and 3.4, 3.4
  and 2.6; WebKit 2.6 and 7.9, 7.9 and 24.7 (a `node` process at 97 % CPU at the end). The runs with the hitch, before
  the fix, were busier: 12.4 before the macOS runs and 7.7, 5.9 and 28.8 after them, 34.8 before the web runs (another
  session's headless Chromium at 746 % CPU), 35.7 and 19.3 after the Chromium runs, 10.6 and 6.0 after the WebKit
  ones. The load did not cause it: the debug build hit the same frame (44–49 ms) at loads of 5.1 to 22.5, and with the
  fix the figure's first frame on screen took 3.4–3.6 ms. Logs: `/tmp/hitch-t12/after/` for these runs (uptime and the
  top processes beside each), `/tmp/condo-t12-perf/` for the runs before the fix, `/tmp/hitch-t12/` for the
  diagnosis (not committed).

### After the vibe pass (2026-11-05)

Measured on the vibe-pass build (feat/vibe-pass): the soft filter (the 3D view at half the window's lines, 450 at
1600×900 on macOS and 360 at 1280×720 in the browsers, scaled up bilinear, MSAA 4x on as before), the colour grade per act, the still figure, and the fan, fridge and neighbour's TV
in act 1. Same machine, same tour. `tools/export.sh`, then `tools/smoke.sh` (SMOKE ok on macOS, Chromium and WebKit),
then the perf runs: the macOS app `-- --perf` 3 times and `-- --perf --nofilter` 3 times, WebKit headless 2 runs each
way, Chromium in a visible window 1 run each way, filter on first. The first PERF line now prints the 3D scale: 0.50
with the filter on (1600×900 on macOS, 1280×720 in the browsers), 1.00 with it off. The rows marked "after the vibe
pass" in the tables above are these runs. They were made before commit 9f64481, which changed only the grade's
contrast values (shader uniforms), so no frame-cost change is expected; perf was not re-run after it.

* **The budget holds both ways**: WebKit 16.67 ms average (60 fps), p99 18–19 ms, worst 20–23 ms; Chromium 120 fps;
  no frame over 25 ms in any of the 12 runs.
* **The filter makes frames cheaper**: on macOS, with vsync off, 1.98–1.99 ms a frame with the filter on and
  2.99–3.01 ms with it off; render CPU 0.95–0.97 ms against 1.17–1.18 ms. Video memory is 27.2–42.6 MB lower with it on
  (macOS 71.8 against 114.4 MB, WebKit 67.5 against 94.8, Chromium 71.6 against 98.8): the 3D buffers are a quarter
  the size. The browsers wait for the display either way.
* **Against the object rebuild**: with the filter off the macOS frame is 2.99–3.01 ms, against 2.56–2.82 ms before
  this pass, and its video memory and draw calls are about the same. The simulation step is slightly higher at p95 with
  the filter off (86–102 µs against 80–83 on macOS; averages 51–55 µs against 50–52). Whatever else the pass added
  (the grade's adjustment, the home sounds, the still figure), and run-to-run noise, is in that difference; this tour
  does not split it.
* **Memory**: the macOS app peaked at 349–351 MB resident, filter on or off. The last measurement was 280 MB after
  the detail pass; it was not re-measured after the object rebuild, so this pass's own share is unknown.
* **Download**: `index.pck` 6,351,932 bytes (6,130,936 with `gzip -6`; `tools/smoke.sh`: 6204 KiB against the
  8912 KiB cap), up from 5,950,668; `index.wasm` unchanged at 39,514,754 bytes (10,114,302 with `gzip -6`). Desktop:
  macOS zip 66,606,827 bytes, Windows exe 115,620,424, Linux binary 79,871,352.
* **Load**: the shader warm-up is done 3.37–3.54 s after engine start on macOS and in WebKit, about the same as after
  the object rebuild; 4.06 s in Chromium on its first visible-window run of this build and 3.39 s on the next.
* **Machine load**: load averages (1 min) before and after each run: macOS filter on 2.56 and 2.74, 2.68 and 2.95,
  2.95 and 2.89; filter off 2.66 and 2.91, 2.91 and 2.91, 2.91 and 3.14; WebKit filter on 3.05 and 3.29, 3.10 and
  2.58; filter off 2.58 and 1.91, 1.91 and 4.54 (`node` processes this run did not start at 78–140.5 % CPU at its end);
  Chromium filter on 8.58 and 9.71, filter off 9.71 and 6.13. Logs: `/tmp/condo-vibe/perf/` (not committed).

## What the measurements changed

The first tour found frames of 100 ms and more, the kind of stutter a player notices. It recorded when
each one happened and which event had just started:

| Hitch (M1 Max) | When | Cause | Fix |
|---|---|---|---|
| 117–123 ms ×2 | first second of play | shaders compiled on first view | warm-up |
| 99–111 ms | about 1 s after the silhouette was requested | the silhouette's transparent material compiled on its first draw | warm-up draws the silhouette once |
| 27–110 ms | the first light flicker | an object losing its last ceiling light needs another shader variant | warm-up turns the ceiling lights off |
| (not yet measured before the fix) | the first phone light | shadowed spot light variants | warm-up uses a copy of the phone light |
| 112–143 ms, once in each of 3 runs | 0.2 s or 4.7 s into the living room, facing north | the bedroom aircon's blinking LED had a material of its own; the warm-up usually ran while it was dark, so it compiled on its first blink (walls don't hide it from the renderer) | the LED uses the same material as the other indicator lights |

The warm-up (`Main._compile_shaders`) runs while the start card is up, which says "Loading…" and ignores
clicks until it is done. A camera looks around every apartment room and the corridor with the ceiling
lights on, off and with the phone light. Afterwards no frame over 25 ms was seen in any run.

The gap and B-11-07 only exist after the reveal, so they are not part of the warm-up. Their first view
did not cause a hitch over 25 ms in the final runs.

## Known gaps

* **Real Safari is unmeasured.** Playwright's WebKit in a visible window on this Mac drops to about
  2.5 frames a second about 30 s after the page loads. A bare WebGL2 page that only clears the screen
  does the same, so it is the test setup, not the game; the WebKit numbers above are from a headless run.
  Before release, play the web build in Safari for a few minutes.
* **Headless Chromium** renders in software (11 fps here) and is not a result.
* **Windows and Linux builds** are exported but have not been run.
* **One fast machine only.** Integrated graphics and older GPUs are the real risk for the web build.
* The tour teleports instead of walking, and does not include the endings or the long corridor of the
  *Vacant* ending.
