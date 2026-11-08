#!/usr/bin/env python3
"""Makes every sound in assets/audio/ (stdlib only, deterministic). Run: python3 tools/gen_audio.py

All but four are synthesised here: they are original and carry the project licence. The four (the flat's door opening,
the car door opening, the starter and the engine dying) are cut from CC0 recordings in art/sounds/vendor/ (SOURCE.md).
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
rng = random.Random(1147)


def silence(sec):
    return [0.0] * int(sec * SR)


def noise(sec, r=rng):
    return [r.uniform(-1, 1) for _ in range(int(sec * SR))]


def lowpass(x, cutoff):
    a = 1 - math.exp(-2 * math.pi * cutoff / SR)
    y, out = 0.0, []
    for s in x:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [s - l for s, l in zip(x, lp)]


def env_exp(n, decay):
    return [math.exp(-i / SR / decay) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def at(x, sec, total):
    out = [0.0] * int(total * SR)
    o = int(sec * SR)
    for i, s in enumerate(x):
        if o + i < len(out):
            out[o + i] += s
    return out


def gain(x, g):
    return [s * g for s in x]


def normalize(x, peak=0.9):
    m = max(abs(s) for s in x) or 1.0
    return [s * peak / m for s in x]


def fade(x, fin=0.005, fout=0.02):
    n = len(x)
    a, b = int(fin * SR), int(fout * SR)
    return [s * min(1.0, i / max(a, 1), (n - i) / max(b, 1)) for i, s in enumerate(x)]


def write(name, data, rate=SR):
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in data))


def save(name, x, peak=0.9):
    write(name, normalize(x, peak))


def knock(pitch=1.0, strength=1.0):
    n = int(0.28 * SR)
    body = [
        math.sin(2 * math.pi * 95 * pitch * i / SR) * 0.9 + math.sin(2 * math.pi * 210 * pitch * i / SR) * 0.4
        for i in range(n)
    ]
    body = [b * e for b, e in zip(body, env_exp(n, 0.045))]
    click = lowpass(noise(0.02), 2500)
    click = [c * e for c, e in zip(click, env_exp(len(click), 0.004))]
    return gain(mix(body, gain(click, 1.6)), strength)


def footstep(seed):
    r = random.Random(seed)
    thud = lowpass(noise(0.16), 300 + r.uniform(-60, 60))
    thud = [s * e for s, e in zip(thud, env_exp(len(thud), 0.035))]
    scuff = highpass(lowpass(noise(0.12), 3000), 600)
    scuff = [s * e * 0.25 for s, e in zip(scuff, env_exp(len(scuff), 0.03))]
    return mix(gain(thud, 3.0), at(scuff, 0.02, 0.16))


def thud(sec, cutoff, decay):
    x = lowpass(noise(sec), cutoff)
    return [s * e for s, e in zip(x, env_exp(len(x), decay))]


def tone(freq, sec, decay=None, amp=1.0):
    n = int(sec * SR)
    e = env_exp(n, decay) if decay else [1.0] * n
    return [amp * math.sin(2 * math.pi * freq * i / SR) * e[i] for i in range(n)]


def loudest_100ms_db(x, rate=SR):
    """The highest RMS over any 100 ms of x, in dBFS: how docs/architecture.md's audio table measures files."""
    k = rate // 10
    acc = [0.0]
    for s in x:
        acc.append(acc[-1] + s * s)
    return 10 * math.log10(max(acc[i + k] - acc[i] for i in range(len(x) - k + 1)) / k)


def loopable(x, xfade=0.5):
    """Crossfades the tail into the head so the clip loops without a click."""
    k = int(xfade * SR)
    head, body, tail = x[:k], x[k:-k], x[-k:]
    blended = [tail[i] * (1 - i / k) + head[i] * (i / k) for i in range(k)]
    return body + blended


# ---- The road down (docs/superpowers/specs/2026-11-06-the-road-down-design.md) -------------------------------------
# Each sound has its own Random (never the module's rng or thud(), which uses it), so the files above never
# change. They are saved with save_db(): the loudest 100 ms is set on purpose, the same figure docs/architecture.md's
# audio table lists, and nothing is louder than the flat's knock.

KNOCK_DB = -14.6  # knock1 (the flat's quietest knock); no road sound's loudest 100 ms is above it
HALF_TAPS = 25
FC = 9500 / SR  # cutoff, in cycles per sample
HALF_FIR = [  # a Hann-windowed sinc low-pass, normalised: what halves the sample rate cleanly
    2 * FC * (math.sin(2 * math.pi * FC * m) / (2 * math.pi * FC * m) if m else 1.0) * (0.5 + 0.5 * math.cos(2 * math.pi * m / HALF_TAPS))
    for m in range(-(HALF_TAPS // 2), HALF_TAPS // 2 + 1)
]
HALF_FIR = [h / sum(HALF_FIR) for h in HALF_FIR]


def halve(x, loop=False):
    """Halves the sample rate (low-pass, then every other sample). A loop is filtered round its join so it stays
    seamless. The caller halves a road sound that has nothing above 8 kHz (save_db's half): QOA costs bytes per second."""
    n, half = len(x), HALF_TAPS // 2
    if loop:
        return [sum(h * x[(i + m - half) % n] for m, h in enumerate(HALF_FIR)) for i in range(0, n, 2)]
    return [sum(h * x[i + m - half] for m, h in enumerate(HALF_FIR) if 0 <= i + m - half < n) for i in range(0, n, 2)]


def save_db(name, x, db, loop=False, half=False):
    """Scales x so its loudest 100 ms is db dBFS, refuses to clip or to click at a loop's join, and saves it
    (at half the sample rate if half)."""
    rate = SR // 2 if half else SR
    if half:
        x = halve(x, loop)
    y = gain(x, 10 ** ((db - loudest_100ms_db(x, rate)) / 20))
    peak = max(abs(s) for s in y)
    if db > KNOCK_DB or peak > 0.95:
        raise SystemExit(f"{name}: {db} dB is louder than the knock ({KNOCK_DB}), or peaks at {peak:.2f}")
    seam = abs(y[-1] - y[0])
    p99 = sorted(abs(b - a) for a, b in zip(y, y[1:]))[int(0.99 * (len(y) - 1))]
    if loop and seam > p99:  # the join jumps further than the sound itself does 99% of the time: a click
        raise SystemExit(f"{name}: its loop seam clicks")
    write(name, y, rate)
    print(f"{name}: {len(y) / rate:.2f} s at {rate} Hz, loudest 100 ms {loudest_100ms_db(y, rate):.1f} dBFS, peak {peak:.2f}"
          + (f", loop seam {seam:.4f} (p99 step {p99:.4f})" if loop else ""))


def put(out, x, sec, g=1.0, wrap=False):
    """Adds x into out (in place) at sec. With wrap, what runs past the end carries on at the start: a loop."""
    n, o = len(out), int(round(sec * SR))
    for i, s in enumerate(x):
        j = o + i
        if wrap:
            j %= n
        elif not 0 <= j < n:
            continue
        out[j] += s * g


def circ(f, x):
    """Runs the filter f round a loop three times and keeps the middle pass: its end flows into its start."""
    n = len(x)
    return f(x * 3)[n:2 * n]


def puff(r, sec, cutoff, decay):
    """A burst of low-passed noise that dies away: a thud, a puff of intake, a slap."""
    x = lowpass(noise(sec, r), cutoff)
    return [s * e for s, e in zip(x, env_exp(len(x), decay))]


def tick(r, sec, lo, hi, decay):
    """A short band-passed click."""
    x = highpass(lowpass(noise(sec, r), hi), lo)
    return [s * e for s, e in zip(x, env_exp(len(x), decay))]


BODIES = (82, 104, 92, 118)  # the four cylinders' booms, a little apart so no engine speed makes them all line up


def cabin(x, loop=False):
    """What the car's body does to an engine: a 12 dB/octave roll-off from 900 Hz, and no drift below 30 Hz (a train
    of damped sines has a net area, so it would otherwise carry a DC offset)."""
    def f(y):
        return highpass(lowpass(lowpass(y, 900), 900), 30)
    return circ(f, x) if loop else f(x)


def firing(r, body, size=1.0):
    """One cylinder firing, heard through a car's body: its boom, two overtones and a puff of intake."""
    return gain(mix(tone(body, 0.09, 0.014), tone(body * 2.1, 0.09, 0.009, 0.55), tone(body * 3.6, 0.09, 0.006, 0.25),
                    gain(puff(r, 0.02, 700, 0.006), 4.0)), size)


def firings(rate, n, shapes, amp, r, spread=0.07):
    """Places a firing wherever the integral of rate(t) (Hz) crosses a whole number, so it can speed up and slow down."""
    out, ph, k = [0.0] * n, 0.0, 0
    for i in range(n):
        ph += rate(i / SR) / SR
        if ph >= k + 1:
            k += 1
            put(out, shapes[k % len(shapes)], i / SR, amp(i / SR) * r.uniform(1 - spread, 1 + spread))
    return out


def engine_loop():
    """The couple's hatchback cruising, from the back seat: 100 firings of a four-cylinder in 1.5 s (66.7 Hz) over
    a low road rumble. Built from a whole number of firings so it is seamless; played at 0.7x to 1.6x."""
    r = random.Random(1301)
    n, fire = int(1.5 * SR), 200 / 3
    cyl = [firing(r, b) for b in BODIES]
    out = [0.0] * n
    for k in range(100):
        put(out, cyl[k % 4], k / fire, (1.0, 0.9, 1.06, 0.95)[k % 4] * r.uniform(0.93, 1.07), wrap=True)
    road = circ(lambda x: lowpass(x, 160), noise(1.5, r))
    return cabin(mix(out, gain(road, 1.5)), loop=True)


def old_engine_loop():
    """The slow car ahead: an old engine at a crawl, 25 firings a second, unevenly worn, a few firings missed, with
    a tappet tick on each. 40 firings in 1.6 s, seamless. Heard from outside, so it is dull at the top."""
    r = random.Random(1302)
    n = int(1.6 * SR)
    cyl = [firing(r, b, s) for b, s in ((70, 1.0), (66, 0.7), (74, 0.9), (62, 0.55))]
    out = [0.0] * n
    for k in range(40):
        if k in (9, 23, 34):  # misses
            continue
        t = k / 25 + r.uniform(-0.002, 0.002)
        put(out, cyl[k % 4], t, r.uniform(0.8, 1.2), wrap=True)
        put(out, tick(r, 0.006, 1500, 4500, 0.002), t + 0.007, r.uniform(0.3, 0.6), wrap=True)
    return circ(lambda x: highpass(lowpass(x, 1500), 30), out)


def rev():
    """The hatchback's engine opened up for the overtake: from idle to a high rev in 0.8 s, held a moment, then
    letting go. Same engine as engine_loop."""
    r = random.Random(1303)
    n = int(1.9 * SR)
    cyl = [firing(r, b) for b in BODIES]

    def rate(t):
        if t < 0.12:
            return 45.0
        if t < 0.95:
            s = min(1.0, (t - 0.12) / 0.83)
            return 45 + 95 * s * s * (3 - 2 * s)
        if t < 1.05:
            return 140.0
        return 55 + 85 * math.exp(-(t - 1.05) / 0.3)

    def amp(t):  # the throttle: louder as it opens, quieter on the way down
        return 0.4 + 1.0 * (rate(t) - 45) / 95 if t < 1.05 else 0.3 + 0.9 * (rate(t) - 55) / 85

    air = lowpass(noise(1.9, r), 900)
    roar = [a * amp(i / SR) ** 2 * 0.5 for i, a in enumerate(air)]
    return fade(cabin(mix(firings(rate, n, cyl, amp, r), roar)), 0.01, 0.2)


def indicator():
    """A dashboard indicator as a loop of one flash: the relay's tick at 0 and tock at 0.333 s, 0.667 s long (29400
    samples), so it flashes 90 times a minute. Both clicks have died away by the end, so the join is silence into a tick."""
    r = random.Random(1304)
    out = [0.0] * int(round(2 / 3 * SR))
    for t, f, g in ((0.0, 1.0, 1.0), (1 / 3, 0.78, 0.8)):
        click = mix(tick(r, 0.012, 1800, 5000, 0.0025), tone(950 * f, 0.03, 0.008, 0.6), tone(2300 * f, 0.02, 0.004, 0.3))
        put(out, fade(click, 0.0005, 0.0), t, g, wrap=True)  # 0.5 ms attack: the tick at the join starts from silence
    return out


def car_door_close():
    """A car door shut from outside, near: the panel's thud, a latch clack and a second small click, a puff of air
    past the seal."""
    r = random.Random(1305)
    out = [0.0] * int(0.5 * SR)
    put(out, puff(r, 0.25, 260, 0.045), 0.0, 2.2)
    put(out, tone(130, 0.2, 0.05, 0.5), 0.0)
    put(out, tick(r, 0.03, 1500, 4500, 0.006), 0.006, 0.9)
    put(out, tick(r, 0.02, 2200, 5500, 0.004), 0.038, 0.45)
    put(out, puff(r, 0.12, 1200, 0.05), 0.01, 0.2)
    return fade(out, 0.002, 0.05)


def road_step(seed):
    """A shoe on asphalt: a heel thud, a hard tick, and grit scattered after it."""
    r = random.Random(seed)
    out = [0.0] * int(0.2 * SR)
    put(out, puff(r, 0.16, 360 + r.uniform(-60, 60), 0.03), 0.0, 3.0)
    put(out, tick(r, 0.012, 1200, 4200, 0.003), 0.0, 0.9)
    grain = tick(r, 0.012, 2000, 6000, 0.002)
    for _ in range(r.randint(5, 9)):
        put(out, grain, r.uniform(0.012, 0.11), r.uniform(0.15, 0.5))
    return out


def lorry_pass():
    """A loaded lorry passing in the other lane, from inside our car, in 3.2 s. Closest at 1.5 s. It closes at
    26 m/s from 4 m off, so its diesel drops about 14 % in pitch as it passes (Doppler) and everything swells and
    fades with 1/distance: tyre roar, hiss, and one soft pressure wave as it goes by."""
    r = random.Random(1311)
    L, t0, v, y = 3.2, 1.5, 26.0, 4.0
    n = int(L * SR)

    def dist(t):
        return math.hypot(v * (t - t0), y)

    def g(t):
        return y / dist(t)

    def rate(t):
        return 52 * 343 / (343 + v * v * (t - t0) / dist(t))

    diesel = mix(firing(r, 78, 1.3), gain(tick(r, 0.02, 700, 2500, 0.004), 0.6))
    engine = firings(rate, n, [diesel], g, r)
    low = lowpass(noise(L, r), 420)
    hiss = highpass(lowpass(noise(L, r), 3200), 700)
    roar = [low[i] * g(i / SR) * 2.2 + hiss[i] * g(i / SR) ** 1.6 * 0.5 for i in range(n)]
    whomp = lowpass(noise(L, r), 110)
    whomp = [w * 3.0 * math.exp(-((i / SR - t0) / 0.16) ** 2) for i, w in enumerate(whomp)]
    return fade(highpass(mix(engine, roar, whomp), 30), 0.2, 0.25)


def insects_loop():
    """A night jungle: three cicada bands droning, swelling and fading, with four crickets chirping at their own
    rates on top. 6 s. The cicadas' buzz and swell rates are whole cycles per loop. The crickets' chirp periods do not
    divide the loop, so each chirp sits at a jittered time and wraps round the end."""
    r = random.Random(1312)
    L = 6.0
    n = int(L * SR)

    def band(lo, hi):
        return circ(lambda x: highpass(highpass(lowpass(lowpass(x, hi), hi), lo), lo), noise(L, r))

    out = [0.0] * n
    for lo, hi, buzz, swell, phase, g in ((3800, 6200, 90, 1, 0.0, 2.0), (5200, 7800, 120, 2, 1.3, 1.2),
                                           (1400, 3000, 60, 3, 2.4, 1.5)):
        b = band(lo, hi)
        for i in range(n):
            t = i / SR
            out[i] += g * b[i] * (0.6 + 0.4 * math.cos(2 * math.pi * buzz * t)) \
                * (0.55 + 0.45 * math.sin(2 * math.pi * swell * t / L + phase))
    for fc, period, pulses, gap, g in ((4300, 0.78, 3, 0.030, 1.0), (4800, 0.52, 4, 0.024, 0.8),
                                       (5500, 1.15, 2, 0.040, 0.7), (3900, 0.66, 3, 0.028, 0.45)):
        pulse = [math.sin(2 * math.pi * fc * i / SR) * math.sin(math.pi * i / (0.018 * SR)) ** 2 for i in range(int(0.018 * SR))]
        for k in range(int(L / period)):
            if r.random() < 0.15:  # a chirp missed
                continue
            a, t = r.uniform(0.5, 1.0), k * period + r.uniform(-0.06, 0.06)
            for j in range(pulses):
                put(out, pulse, t + j * gap, g * a * 0.7, wrap=True)
    floor = circ(lambda x: lowpass(x, 3000), noise(L, r))
    return mix(out, gain(floor, 0.1))


def thump_roof():
    """Something heavy landing on the roof, heard from inside: a low boom, the panel's ringing and a settling."""
    r = random.Random(1309)
    out = [0.0] * int(0.9 * SR)
    put(out, mix(tone(80, 0.6, 0.09), tone(160, 0.5, 0.07, 0.8), tone(245, 0.4, 0.08, 0.6), tone(380, 0.3, 0.05, 0.4),
                 gain(puff(r, 0.05, 600, 0.012), 2.0)), 0.0)
    put(out, mix(tone(70, 0.4, 0.07), puff(r, 0.1, 350, 0.03)), 0.19, 0.3)
    return fade(highpass(lowpass(out, 1000), 35), 0.003, 0.15)


def knock_glass():
    """A knuckle on a car window pane from outside: a ringing 740 Hz pane, its overtone, the frame's rattle and
    the tick of the knuckle."""
    r = random.Random(1310)
    out = [0.0] * int(0.4 * SR)
    put(out, mix(tone(740, 0.25, 0.025), tone(1480, 0.12, 0.012, 0.4), tone(310, 0.2, 0.03, 0.3)), 0.0)
    put(out, tick(r, 0.012, 1800, 4500, 0.0025), 0.0, 1.2)
    return fade(out, 0.001, 0.08)


def wet_flap():
    """A wet slap of flesh and a squelch as it peels away. Close, but quiet: it is not meant to startle."""
    r = random.Random(1313)
    out = [0.0] * int(0.6 * SR)
    put(out, puff(r, 0.3, 800, 0.03), 0.0, 1.4)
    put(out, tick(r, 0.03, 500, 2600, 0.007), 0.0, 0.5)
    y, sq = 0.0, []
    for i in range(int(0.35 * SR)):  # noise through a lowpass that closes from 1400 Hz to 180 Hz
        t = i / SR
        y += (1 - math.exp(-2 * math.pi * (180 + 1220 * math.exp(-t / 0.08)) / SR)) * (r.uniform(-1, 1) - y)
        sq.append(y * math.exp(-t / 0.12) * (0.6 + 0.4 * math.sin(2 * math.pi * 31 * t)) * 3.0)
    put(out, sq, 0.02)
    return fade(out, 0.002, 0.1)


def drip():
    """One heavy drop into something wet, in a small hollow space: a rising plink and two dull echoes."""
    d = []
    ph = 0.0
    for i in range(int(0.25 * SR)):
        t = i / SR
        ph += 2 * math.pi * (560 + 1000 * (1 - math.exp(-t / 0.02))) / SR
        d.append(math.sin(ph) * min(1.0, t / 0.002) * math.exp(-t / 0.04))
    dull = lowpass(d, 2200)
    out = [0.0] * int(0.8 * SR)
    put(out, d, 0.0)
    put(out, dull, 0.09, 0.3)
    put(out, dull, 0.17, 0.12)
    return fade(out, 0.001, 0.15)


def rattle():
    """Her breath, wet in the throat: one breath in, one out, the second rougher, each bubbling. Slow in and out,
    low and quiet: no sting."""
    r = random.Random(1314)
    L = 2.2
    n = int(L * SR)
    air = highpass(lowpass(noise(L, r), 1100), 300)

    def breath(t):  # in over 0.1-1.0 s (soft), out over 1.15-2.05 s (rougher)
        if 0.1 <= t < 1.0:
            return 0.6 * math.sin(math.pi * (t - 0.1) / 0.9) ** 2
        if 1.15 <= t < 2.05:
            return math.sin(math.pi * (t - 1.15) / 0.9) ** 2
        return 0.05

    out = [air[i] * breath(i / SR) * (0.55 + 0.45 * math.sin(2 * math.pi * (26 + 6 * math.sin(2 * math.pi * 0.7 * i / SR)) * i / SR))
            for i in range(n)]
    t = 0.0
    while t < L:  # bubbles, more of them where the breath is strong
        e = breath(t)
        if r.random() < 14 * e * 0.01:
            f = r.uniform(170, 420)
            put(out, [math.sin(2 * math.pi * f * (1 + 0.6 * i / (0.025 * SR)) * i / SR) * math.exp(-i / SR / 0.009)
                      for i in range(int(0.04 * SR))], t, r.uniform(0.4, 1.0) * e * 2.0)
        t += 0.01
    return fade(lowpass(out, 1400), 0.1, 0.2)


def phone_ring_mobile():
    """An ordinary mobile ringing, on a table, as a loop of one ring: two runs of four soft digital beeps and a buzz
    from the vibration motor under them, then a pause. 2.1 s; it ends in silence, so the join is silence into a beep.
    No real phone's tune."""
    out = [0.0] * int(2.1 * SR)
    beep = [(math.sin(2 * math.pi * 1480 * i / SR) + math.sin(2 * math.pi * 4440 * i / SR) / 3
             + math.sin(2 * math.pi * 7400 * i / SR) / 5) * math.sin(math.pi * i / (0.085 * SR)) ** 0.5
            for i in range(int(0.085 * SR))]
    buzz = [(1 if math.sin(2 * math.pi * 170 * i / SR) > 0 else -1) * math.sin(math.pi * i / (0.55 * SR))
            for i in range(int(0.55 * SR))]
    buzz = lowpass(buzz, 700)
    for start in (0.0, 0.67):
        for j in range(4):
            put(out, beep, start + j * 0.145)
        put(out, buzz, max(start - 0.01, 0.0), 0.4)
    return circ(lambda x: lowpass(x, 5000), out)


def lorry_idle():
    """A loaded lorry's diesel idling, from a few metres off outside: a six-cylinder at 600 rpm (30 firings a
    second, each a low boom with its injector's clatter) over a rumble. 60 firings in 2 s, so it is seamless."""
    r = random.Random(1315)
    n, fire = 2 * SR, 30
    cyl = [mix(firing(r, b, 1.2), gain(tick(r, 0.015, 900, 3000, 0.003), 0.5)) for b in (58, 66, 61, 70, 63, 68)]
    out = [0.0] * n
    for k in range(60):
        put(out, cyl[k % 6], k / fire, r.uniform(0.85, 1.1), wrap=True)
    rumble = circ(lambda x: lowpass(x, 120), noise(2.0, r))
    return circ(lambda x: highpass(lowpass(x, 2500), 30), mix(out, gain(rumble, 1.2)))


def lorry_brake():
    """A lorry's air brakes as it stops: the valve's chuff, then a long hiss of air that dies away, 1.3 s."""
    r = random.Random(1316)
    n = int(1.3 * SR)
    hiss = highpass(lowpass(noise(1.3, r), 6500), 1600)
    hiss = [s * min(1.0, i / (0.03 * SR)) * math.exp(-i / SR / 0.45) for i, s in enumerate(hiss)]
    out = [0.0] * n
    put(out, puff(r, 0.08, 500, 0.02), 0.0, 1.5)
    put(out, hiss, 0.02)
    return fade(out, 0.002, 0.2)


def shriek():
    """Her shriek in his face when he looks back: a woman's voice torn high and rough, 0.8 s. It leaps to about 1.2 kHz
    in 60 ms, wavers, and sinks as it dies; the mouth wide open (peaks at 1.3, 2.6 and 3.6 kHz), every other cycle
    louder (a growl under the pitch), a rasp of breath through it, and overdriven. Nothing in it swells: it is apart
    from the stinger's low rise."""
    r = random.Random(1317)
    L = 0.8
    n = int(L * SR)
    wander = normalize(lowpass(noise(L, r), 25), 1.0)  # the pitch wavers
    rasp = highpass(lowpass(noise(L, r), 6000), 1500)

    def mouth(f):
        return sum(a / (1 + ((f - c) / w) ** 2) for c, w, a in ((1300, 400, 1.0), (2600, 500, 0.7), (3600, 600, 0.4)))

    voice, ph = [], 0.0
    for i in range(n):
        t = i / SR
        f0 = 650 + 550 * min(1.0, t / 0.06) - 350 * max(0.0, t - 0.35) / 0.45  # leaps up, holds, sinks as it dies
        f0 *= 1 + 0.04 * wander[i] + 0.01 * math.sin(2 * math.pi * 7 * t)
        ph += 2 * math.pi * f0 / SR
        v = sum(mouth(k * f0) * math.sin(k * ph) / math.sqrt(k) for k in range(1, int(9000 / f0) + 1))
        voice.append(v * (1 + 0.4 * math.sin(ph / 2)) + 0.25 * rasp[i])
    voice = normalize(voice, 1.0)
    return fade([math.tanh(1.5 * min(1.0, i / SR / 0.015) * (1 - 0.4 * i / n) * v) for i, v in enumerate(voice)], 0.002, 0.25)


def wind_loop():
    """The wind on the mountain at night, under everything on the road and still there when the insects stop: a low
    rush in the trees that swells and eases in slow gusts, breathier at the top of the strong ones. 12 s. The gusts are
    whole cycles of the loop and every filter runs round it (circ), so it is seamless."""
    r = random.Random(1318)
    L = 12.0
    low = circ(lambda x: highpass(lowpass(lowpass(x, 380), 380), 40), noise(L, r))
    rush = circ(lambda x: highpass(highpass(lowpass(lowpass(x, 1700), 1700), 450), 450), noise(L, r))
    out = []
    for i, (a, b) in enumerate(zip(low, rush)):
        t = i / SR
        gust = 0.75 + 0.17 * math.sin(2 * math.pi * 2 * t / L + 0.7) + 0.08 * math.sin(2 * math.pi * 5 * t / L + 2.1)
        out.append(a * gust + b * 0.35 * gust ** 3)
    return out


# ---- Recorded sounds (art/sounds/vendor/SOURCE.md) -------------------------------------------------------------------
# Four sounds that read as a synthesiser, a drum and a bouncing ball when they were synthesised, cut from recordings.

VENDOR = Path(__file__).resolve().parent.parent / "art" / "sounds" / "vendor"
ROLL = 14.0 / 2.25  # s: StallMission's car rolls to a stop from CRUISE_SPEED at ROLL_DECEL
ROAD_DB = -45.4  # engine_loop's road rumble as heard in the car (the loop's file at -16.0, played at -13.5)


def recording(name, start, end):
    """Seconds start to end of one of the recordings in VENDOR, as floats: they are mono, 16-bit, 44.1 kHz."""
    with wave.open(str(VENDOR / f"{name}.wav")) as w:
        assert (w.getnchannels(), w.getsampwidth(), w.getframerate()) == (1, 2, SR)
        w.setpos(int(start * SR))
        raw = w.readframes(int((end - start) * SR))
    return [v / 32768 for (v,) in struct.iter_unpack("<h", raw)]


def splice(*parts, xfade=0.02):
    """Joins pieces end to end, each crossfading into the next over xfade seconds."""
    out, k = list(parts[0]), int(xfade * SR)
    for p in parts[1:]:
        for i in range(k):
            out[len(out) - k + i] += (p[i] - out[len(out) - k + i]) * i / k
        out += p[k:]
    return out


def curve(keys, t):
    """Piecewise-linear through (seconds, value) keys, held flat past both ends."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            return v0 + (v1 - v0) * (t - t0) / (t1 - t0)
    return keys[-1][1]


def varispeed(x, rate):
    """Plays x at rate(t) times its speed (t in seconds of output), as a tape would: pitch and pace together."""
    out, pos = [], 0.0
    while pos < len(x) - 1:
        i = int(pos)
        out.append(x[i] + (x[i + 1] - x[i]) * (pos - i))
        pos += rate(len(out) / SR)
    return out


def door_open():
    """The flat's door opening: the handle and latch, then the hinge grinding as it swings (a Paris apartment door,
    with the wait between them cut). Close to the microphone the handle was 20 dB over its loudness; it is brought
    down to 2 dB over the hinge's peaks, as the file is peak-normalised like the flat's others."""
    src = "bsb-1702-apartment-door-opening"
    latch, hinge = recording(src, 0.0, 0.42), recording(src, 1.25, 2.25)
    latch = gain(latch, max(abs(s) for s in hinge) * 10 ** (2 / 20) / max(abs(s) for s in latch))
    return fade(splice(latch, hinge, xfade=0.03), 0.002, 0.15)


def car_door_open():
    """A car door opened from outside, near: the handle, then the latch letting go and the door swinging out (a
    Peugeot 107's, with the wait between them cut)."""
    src = "bsb-1526-car-door"
    return fade(splice(recording(src, 0.0, 0.3), recording(src, 0.66, 1.2)), 0.002, 0.08)


def starter_crank():
    """A starter turning an engine that will not catch, through the car's body: 1.7 s of the first try of a hard
    start, then the key let go."""
    src = "bsb-0872-car-difficult-start"
    x = splice(recording(src, 0.1, 1.8), recording(src, 2.75, 3.25), xfade=0.05)
    return fade(lowpass(lowpass(x, 2500), 2500), 0.002, 0.08)


def engine_sputter():
    """The hatchback dying as it rolls, from inside: its revs fall from the cruise to a rough idle that stumbles twice,
    then it coughs and stops (an engine with a damaged muffler), through the car's body. Under it the tyres roll on,
    at the loop's road level and fading as the car slows, until it stands ROLL seconds on. Played in his head, so it
    rides with the car (RoadMain, lights_dying)."""
    src = "bsb-1571-damaged-muffler"
    revs = [(0.0, 1.6), (0.3, 1.0), (0.55, 0.92), (0.7, 0.98), (0.95, 0.85), (1.1, 0.93), (1.3, 0.8)]
    run = varispeed(recording(src, 0.0, 2.2), lambda t: curve(revs, t))[:int(1.35 * SR)]
    dips = [(0.5, 1.0), (0.53, 0.3), (0.62, 0.3), (0.66, 1.0), (0.92, 1.0), (0.95, 0.2), (1.08, 0.25), (1.12, 1.0)]
    run = [s * curve(dips, i / SR) for i, s in enumerate(run)]
    engine = splice(run, recording(src, 2.3, 3.25), xfade=0.04)  # the last cough, and it stops
    engine = highpass(lowpass(lowpass(engine, 1500), 1500), 30)
    engine = gain(engine, 10 ** ((-17.0 - loudest_100ms_db(engine)) / 20))
    road = lowpass(noise(ROLL + 0.3, random.Random(1307)), 246)  # engine_loop's road, at its pitch at 14 m/s (1.54x)
    road = cabin([s * max(0.0, 1 - i / SR / ROLL) ** 1.2 for i, s in enumerate(road)])
    road = gain(road, 10 ** ((ROAD_DB - loudest_100ms_db(road[int(0.1 * SR):int(0.6 * SR)])) / 20))
    return fade(mix(engine, road), 0.0, 0.2)


def road_sounds():
    """Every sound the road's tasks name. Seven are loops, imported with edit/loop_mode=2 and only ever started with
    RoadAudio.set_loop: the four _loop files, the indicator (one flash), the phone (one ring) and the lorry's idle.
    The rest play once."""
    save_db("engine_loop", engine_loop(), -16.0, loop=True, half=True)
    save_db("old_engine_loop", old_engine_loop(), -20.0, loop=True, half=True)
    save_db("insects_loop", insects_loop(), -27.0, loop=True)  # full rate: 13% of its power is above 11 kHz
    save_db("wind_loop", wind_loop(), -24.0, loop=True, half=True)
    save_db("rev", rev(), KNOCK_DB, half=True)  # as loud as a road sound may be: RoadMain plays it at max_db
    save_db("indicator", indicator(), -24.0, loop=True)
    save_db("car_door_close", car_door_close(), -17.0)
    save_db("car_door_open", car_door_open(), -23.0)
    save_db("lorry_pass", lorry_pass(), -17.0, half=True)
    for i in range(4):  # peak-normalised like the flat's footsteps, so they sit at the same level
        x = normalize(fade(road_step(i + 20), 0.0015, 0.01), 0.7)  # a 1.5 ms fade-in: no step at the first sample
        save(f"road_step_{i + 1}", x, 0.7)
        print(f"road_step_{i + 1}: loudest 100 ms {loudest_100ms_db(x):.1f} dBFS")
    # Played in his head at 0 dB, as loud as the pool player at max_db had it (docs/architecture.md, Audio levels).
    save_db("engine_sputter", engine_sputter(), -17.0, half=True)
    save_db("starter_crank", starter_crank(), -19.0, half=True)
    save_db("thump_roof", thump_roof(), -18.5)  # heard at the +3 dB max_db cap near his head: -15.5
    save_db("knock_glass", knock_glass(), -19.0)
    save_db("wet_flap", wet_flap(), -27.0)
    save_db("drip", drip(), -28.0)
    save_db("rattle", rattle(), -27.0, half=True)
    save_db("phone_ring_mobile", phone_ring_mobile(), -19.0, loop=True, half=True)
    save_db("lorry_idle", lorry_idle(), -20.0, loop=True, half=True)
    save_db("lorry_brake", lorry_brake(), -21.0, half=True)
    save_db("shriek", shriek(), KNOCK_DB)  # full rate: 0.7% of its power is above 8 kHz


def thump3():
    """The flat's bedroom wall knocking after the road, with the roof's body (thump_roof) and knock3's timing: three
    thumps at 0, 0.38 and 0.74 s in 1.3 s, the second a little softer."""
    return mix(at(thump_roof(), 0.0, 1.3), at(gain(thump_roof(), 0.9), 0.38, 1.3), at(thump_roof(), 0.74, 1.3))


def intercom_road():
    """What the intercom's last call sounds like after the road: wind that swells and the road's idling engine, for 3 s,
    heard through a door speaker (300 to 3400 Hz)."""
    r = random.Random(1331)
    n = 3 * SR
    wind = lowpass(noise(3.0, r), 1200)
    wind = [s * 1.5 * (0.3 + 0.7 * math.sin(math.pi * i / n)) for i, s in enumerate(wind)]
    engine = gain(engine_loop() * 2, 0.5)  # the loop is 1.5 s: its first 3 s
    return fade(highpass(lowpass(mix(wind, engine), 3400), 300), 0.05, 0.4)


def bridge_sounds():
    """The flat after the road (docs/superpowers/specs/2026-11-06-road-flat-bridge-design.md): the wall knocks with the
    roof's body, and the intercom's last call has the road in it."""
    save_db("thump3", thump3(), KNOCK_DB)
    save_db("thump1", thump_roof(), KNOCK_DB)
    save_db("intercom_road", intercom_road(), -22.0, half=True)


def main():
    knocks = mix(at(knock(1.0, 1.0), 0.0, 1.3), at(knock(0.97, 0.9), 0.38, 1.3), at(knock(1.03, 1.0), 0.74, 1.3))
    save("knock3", knocks)
    save("knock1", knock())
    for i in range(4):
        save(f"footstep_{i + 1}", footstep(i + 10), 0.7)
    for _ in range(int(0.9 * SR) + int(0.05 * SR)):  # the synthesised door's draws on rng: every sound after it is unchanged
        rng.random()
    save("door_open", door_open())
    save("door_close", fade(mix(gain(thud(0.35, 400, 0.05), 2.0), at(thud(0.04, 5000, 0.004), 0.02, 0.35))))
    slam = mix(gain(thud(0.8, 250, 0.12), 3.0), at(gain(highpass(thud(0.5, 3500, 0.08), 800), 0.6), 0.03, 0.8))
    save("door_slam", fade(slam), 1.0)
    save("switch", fade(mix(thud(0.03, 6000, 0.003), at(thud(0.03, 4000, 0.003), 0.012, 0.05))), 0.6)
    buzz = [
        (math.sin(2 * math.pi * 100 * i / SR) + 0.5 * math.sin(2 * math.pi * 200 * i / SR)) * (0.5 + 0.5 * (rng.random() > 0.15))
        for i in range(int(1.5 * SR))
    ]
    save("buzz", fade(buzz, 0.02, 0.1), 0.5)
    ring = []
    for burst in range(2):
        n = int(0.9 * SR)
        seg = [math.sin(2 * math.pi * (850 if (i // (SR // 20)) % 2 else 1050) * i / SR) for i in range(n)]
        ring += fade(seg, 0.01, 0.05) + silence(0.25)
    save("intercom_ring", ring, 0.55)
    drone_len = 12.5
    n = int(drone_len * SR)
    dr = [
        0.5 * math.sin(2 * math.pi * 55 * i / SR) * (0.7 + 0.3 * math.sin(2 * math.pi * 0.08 * i / SR))
        + 0.3 * math.sin(2 * math.pi * 82.6 * i / SR) * (0.6 + 0.4 * math.sin(2 * math.pi * 0.13 * i / SR + 1))
        for i in range(n)
    ]
    dr = mix(dr, gain(lowpass(noise(drone_len), 180), 1.5))
    save("drone", loopable(dr), 0.5)
    hum = [
        0.6 * math.sin(2 * math.pi * 100 * i / SR) + 0.25 * math.sin(2 * math.pi * 200 * i / SR) + 0.1 * math.sin(2 * math.pi * 300 * i / SR)
        for i in range(int(2.0 * SR))
    ]
    save("hum", hum, 0.3)
    n = int(2.6 * SR)
    swell = [
        (math.sin(2 * math.pi * 49 * i / SR) + 0.35 * math.sin(2 * math.pi * 740 * i / SR) + 0.3 * math.sin(2 * math.pi * 777 * i / SR))
        * min(1.0, i / (0.25 * SR)) * math.exp(-i / SR / 1.0)
        for i in range(n)
    ]
    save("stinger", fade(swell, 0.01, 0.3), 0.8)
    ding = mix(tone(1318.5, 1.6, 0.5, 0.6), at(tone(1046.5, 1.6, 0.6, 0.6), 0.35, 2.0))
    save("lift_ding", fade(ding, 0.002, 0.2), 0.6)
    water = highpass(lowpass(noise(3.0), 2500), 300)
    save("tap_running", loopable(water, 0.4), 0.35)
    # The home beds (act 1, then they stop one at a time). Each has its own Random, so the files above never
    # change. Every one is 0.5 s longer than its loop and made seamless by loopable().
    beds = {}
    r = random.Random(1201)
    air = lowpass(noise(6.5, r), 900)
    beds["fan"] = [  # air with a blade-pass swell, 7 per 6 s loop, and a faint motor
        a * (1 + 0.25 * math.sin(2 * math.pi * 7 / 6 * i / SR)) + 0.025 * math.sin(2 * math.pi * 100 * i / SR)
        for i, a in enumerate(air)
    ]
    r = random.Random(1202)
    rumble = lowpass(noise(4.5, r), 300)
    beds["fridge"] = [  # compressor hum, wobbling once per 4 s loop
        (math.sin(2 * math.pi * 50 * i / SR) + 0.5 * math.sin(2 * math.pi * 100 * i / SR) + 0.25 * math.sin(2 * math.pi * 150 * i / SR))
        * (0.85 + 0.15 * math.sin(2 * math.pi * 0.25 * i / SR)) + rumble[i]
        for i in range(len(rumble))
    ]
    r = random.Random(1203)
    n = int(12.5 * SR)
    envs, who, t = ([0.0] * n, [0.0] * n), 0, 0.0
    while t < 12.5:  # two voices taking turns: a phrase of syllables, softer towards its end, then a pause
        start, phrase = t, r.uniform(1.0, 3.0)
        while t < start + phrase:
            d, a = 1 / r.uniform(3.0, 5.0), r.uniform(0.5, 1.0) * (1 - 0.3 * (t - start) / phrase)
            for i in range(int(t * SR), min(int((t + d) * SR), n)):
                envs[who][i] = a * max(0.0, math.sin(math.pi * (i / SR - t) / d))
            t += d
        t += r.uniform(0.3, 0.8)
        who = 1 - who if r.random() < 0.7 else who
    deep, light = lowpass(highpass(noise(12.5, r), 200), 500), lowpass(highpass(noise(12.5, r), 300), 700)
    talk = [deep[i] * envs[0][i] + light[i] * envs[1][i] for i in range(n)]
    beds["tv_murmur"] = lowpass(talk, 450)  # through the wall
    for name, x in beds.items():
        x = normalize(loopable(x, 0.5), 0.5)
        seam = abs(x[-1] - x[0])
        p99 = sorted(abs(b - a) for a, b in zip(x, x[1:]))[int(0.99 * (len(x) - 1))]
        print(f"{name}: loudest 100 ms {loudest_100ms_db(x):.1f} dBFS, loop seam {seam:.4f} (p99 step {p99:.4f})")
        if seam > p99:  # the join jumps further than the sound itself does 99% of the time: a click
            raise SystemExit(f"{name}: its loop seam clicks")
        save(name, x, 0.5)
    road_sounds()
    bridge_sounds()


if __name__ == "__main__":
    main()
