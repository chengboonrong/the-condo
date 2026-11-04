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

Measured after the art pass (plaster texture on walls and ceilings, nine props). The debug-build row and
the "before the art pass" row were measured just before it, with the same tour.

| Build | Runs | Avg frame | fps | p50 | p95 | p99 | Worst | Frames > 25 ms | Render CPU avg / p95 |
|---|---|---|---|---|---|---|---|---|---|
| macOS app (release), 1600×900, vsync off | 3 | 2.95–2.98 ms | 335–339 | 2.95–2.98 ms | 3.73 ms | 4.10–4.11 ms | 18.2–20.8 ms | 0 | 1.19–1.20 / 1.58–1.60 ms |
| macOS app (release), before the art pass | 3 | 2.52–2.73 ms | 367–396 | 2.64–2.71 ms | 3.40–3.53 ms | 3.81–3.90 ms | 12.4–13.6 ms | 0 | 0.98–1.05 / 1.43–1.46 ms |
| Project in the editor binary (debug), before the art pass, 1600×900, vsync off | 1 | 2.41 ms | 414 | 2.41 ms | 3.50 ms | 4.07 ms | 11.5 ms | 0 | 0.99 / 1.49 ms |
| Web, Chromium (Playwright 1.63), 1280×720, visible window | 1 | 8.33 ms | 120 | 8.30 ms | 11.1 ms | 12.2 ms | 14.5 ms | 0 | 0.51 / 0.80 ms |
| Web, WebKit (Playwright 1.63), 1280×720, headless | 1 | 16.67 ms | 60 | 17 ms | 18 ms | 19 ms | 23 ms | 0 | 2.12 / 3.00 ms |

| Build | Simulation step avg / p95 / max | Director eval avg / max (153 evals) | Draw calls avg / max |
|---|---|---|---|
| macOS app (release) | 59–62 / 105–110 / 325–347 µs | 3–4 / 7–10 µs | 65–66 / 208 |
| Debug build (before the art pass) | 61 / 127 / 427 µs | 3 / 8 µs | 58 / 191 |
| Chromium | 166 / 300 / 3800 µs | 7 / 100 µs | 68 / 207 |
| WebKit | 118 / 1000 / 4000 µs | under 1 ms (the browser's timer only has 1 ms steps) | 68 / 207 |

Browser timers are coarse (0.1 ms steps in Chromium, 1 ms in WebKit), so the web simulation and director
numbers are rounded, not exact. The simulation costs well under a millisecond per physics tick on every
build measured; the director's scoring pass is a few microseconds.

The simulated playthroughs (`docs/playthroughs.md`, bots driving the simulation headless) report the
director's slowest single evaluation over a whole story: 0.9–1.6 ms in earlier runs on this machine. That
is a maximum, often the first evaluation, not a typical cost.

### Memory and load

| Build | Memory | Condo built | Shader warm-up done |
|---|---|---|---|
| macOS app (release) | 251–253 MB peak resident; video 81.2 MB | 490–519 ms | 1.91–1.95 s |
| Debug build (before the art pass) | static 48.6 MB; video 81.2 MB | 586 ms | 2.08 s |
| Chromium | video 65.6 MB | 729 ms | 2.27 s (first ever run on this Mac: 11.8 s) |
| WebKit | video 63.6 MB | 445 ms | 2.52 s |

The first time Chromium ever ran the game on this Mac, compiling the shaders took 9.7 s; later runs took
about 1.5 s, most likely because the GPU driver kept the compiled shaders. A player's first visit in
Chrome may wait that long on "Loading…". The download is 9.6 MB of gzip-compressed engine (`index.wasm`,
37.7 MB raw) plus 0.6 MB of game data.

Desktop downloads: macOS zip 61 MB, Windows exe 110 MB, Linux binary 74 MB.

## What the measurements changed

The first tour found frames of 100 ms and more, the kind of stutter a player notices. It recorded when
each one happened and which event had just started:

| Hitch (M1 Max) | When | Cause | Fix |
|---|---|---|---|
| 117–123 ms ×2 | first second of play | shaders compiled on first view | warm-up |
| 99–111 ms | about 1 s after the silhouette was requested | the silhouette's transparent material compiled on its first draw | warm-up draws the silhouette once |
| 27–110 ms | the first light flicker | an object losing its last ceiling light needs another shader variant | warm-up turns the ceiling lights off |
| (not yet measured before the fix) | the first phone light | shadowed spot light variants | warm-up uses a copy of the phone light |

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
