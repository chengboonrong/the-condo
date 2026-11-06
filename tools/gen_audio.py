#!/usr/bin/env python3
"""Synthesises every sound in assets/audio/ (stdlib only, deterministic). Run: python3 tools/gen_audio.py

All sounds are original and generated here, so they carry the project licence. Replace with recorded
or CC0 sounds later; keep the file names.
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


def creak(sec, f0, f1):
    n = int(sec * SR)
    out, ph = [], 0.0
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * t + 40 * math.sin(2 * math.pi * 7 * t) + rng.uniform(-25, 25)
        ph += 2 * math.pi * f / SR
        saw = (ph / math.pi % 2) - 1
        out.append(saw * (0.6 + 0.4 * math.sin(2 * math.pi * 3 * t)) * math.sin(math.pi * t))
    return lowpass(out, 1800)


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
# Each sound has its own Random (never the module's rng or thud()/creak(), which use it), so the files above never
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
    seamless. Everything in the road that has nothing above 8 kHz is saved this way: QOA costs bytes per second."""
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
    """One flash of a dashboard indicator: the relay's tick at 0 and tock at 0.333 s, 0.667 s long, so playing it
    back to back gives 90 flashes a minute."""
    r = random.Random(1304)
    out = [0.0] * int(2 / 3 * SR)
    for t, f, g in ((0.0, 1.0, 1.0), (1 / 3, 0.78, 0.8)):
        put(out, mix(tick(r, 0.012, 1800, 5000, 0.0025), tone(950 * f, 0.03, 0.008, 0.6), tone(2300 * f, 0.02, 0.004, 0.3)),
            t, g)
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


def car_door_open():
    """A car door opened from outside, near: the handle's clack, the latch let go, the seal's soft pop and the
    door-check clunk as it swings out."""
    r = random.Random(1306)
    out = [0.0] * int(0.55 * SR)
    put(out, tick(r, 0.012, 1200, 5000, 0.004), 0.0, 0.8)
    put(out, tick(r, 0.012, 2000, 5500, 0.004), 0.06, 0.6)
    put(out, puff(r, 0.1, 300, 0.03), 0.1, 1.4)
    put(out, [s * math.sin(math.pi * i / (0.17 * SR)) for i, s in enumerate(lowpass(noise(0.17, r), 600))], 0.1, 0.5)  # the swing
    put(out, puff(r, 0.08, 500, 0.02), 0.27, 1.8)
    put(out, tick(r, 0.01, 1500, 4000, 0.003), 0.27, 0.5)
    put(out, tone(165, 0.2, 0.03, 0.4), 0.27)
    return fade(out, 0.002, 0.08)


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
    """A night jungle: two cicadas droning in different bands, swelling and fading, with four crickets chirping at
    their own rates on top. 6 s; every rate is a whole number of cycles per loop and chirps wrap round the end."""
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


def engine_sputter():
    """The hatchback dying, from inside: firings that come further and further apart, some with an exhaust pop,
    then one heavy cough and the body shuddering as it stops."""
    r = random.Random(1307)
    n = int(2.9 * SR)
    cyl = [firing(r, b) for b in BODIES]
    out = [0.0] * n
    t, gap, k = 0.0, 0.02, 0
    while t < 2.2:
        size = r.uniform(0.5, 1.0)
        put(out, cyl[k % 4], t, size)
        if size < 0.7:
            put(out, puff(r, 0.05, 1200, 0.015), t + 0.004, 2.0)
        t += gap
        gap = gap * 1.22 + r.uniform(0, 0.01)
        k += 1
    put(out, puff(r, 2.2, 120, 1.2), 0.0, 0.5)  # the crank still turning, running down
    put(out, firing(r, 88, 1.5), 2.25)
    put(out, puff(r, 0.5, 55, 0.12), 2.25, 3.0)
    return fade(cabin(out), 0.005, 0.2)


def starter_crank():
    """A starter motor turning an engine that will not catch, from inside: the clack as it engages, a whine that
    dips on every compression, a thump on each, all slowing as the battery tires, then winding down."""
    r = random.Random(1308)
    n = int(1.8 * SR)
    out = [0.0] * n
    put(out, tick(r, 0.02, 1000, 3500, 0.006), 0.0, 1.5)
    thump = puff(r, 0.08, 130, 0.022)
    ph, mph = 0.0, 0.0
    k = 0
    for i in range(n):
        t = i / SR
        spin = max(0.0, min(1.0, (1.65 - t) / 0.15))  # the motor winds down at the end
        ph += (6.2 - 2.4 * min(t, 1.5) / 1.5) * spin / SR
        if ph >= k + 1:
            k += 1
            put(out, thump, t, 2.6 * r.uniform(0.8, 1.1))
        mph += 2 * math.pi * (330 - 70 * min(t, 1.5) / 1.5 - 25 * math.sin(2 * math.pi * ph)) * spin / SR
        saw = sum(math.sin(h * mph) / h for h in (1, 2, 3, 4))
        out[i] += 0.28 * spin * (1 - 0.35 * math.cos(2 * math.pi * ph)) * saw * min(1.0, t / 0.03)
    return fade(lowpass(out, 1800), 0.002, 0.02)


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
    """An ordinary mobile ringing, on a table: two runs of four soft digital beeps and a buzz from the vibration
    motor under them, then a pause. 2.1 s, so playing it back to back keeps the rhythm. No real phone's tune."""
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
    return fade(lowpass(out, 5000), 0.002, 0.05)


def road_sounds():
    """Every sound the road's tasks name. Loops (the three _loop files) are imported with edit/loop_mode=2; the
    rest play once."""
    save_db("engine_loop", engine_loop(), -16.0, loop=True, half=True)
    save_db("old_engine_loop", old_engine_loop(), -20.0, loop=True, half=True)
    save_db("insects_loop", insects_loop(), -27.0, loop=True, half=True)
    save_db("rev", rev(), -16.0, half=True)
    save_db("indicator", indicator(), -24.0)
    save_db("car_door_close", car_door_close(), -17.0)
    save_db("car_door_open", car_door_open(), -23.0)
    save_db("lorry_pass", lorry_pass(), -17.0, half=True)
    for i in range(4):  # peak-normalised like the flat's footsteps, so they sit at the same level
        x = normalize(road_step(i + 20), 0.7)
        save(f"road_step_{i + 1}", x, 0.7)
        print(f"road_step_{i + 1}: loudest 100 ms {loudest_100ms_db(x):.1f} dBFS")
    save_db("engine_sputter", engine_sputter(), -19.0, half=True)
    save_db("starter_crank", starter_crank(), -19.0, half=True)
    save_db("thump_roof", thump_roof(), -15.5)
    save_db("knock_glass", knock_glass(), -19.0)
    save_db("wet_flap", wet_flap(), -27.0)
    save_db("drip", drip(), -28.0)
    save_db("rattle", rattle(), -27.0, half=True)
    save_db("phone_ring_mobile", phone_ring_mobile(), -19.0, half=True)


def main():
    knocks = mix(at(knock(1.0, 1.0), 0.0, 1.3), at(knock(0.97, 0.9), 0.38, 1.3), at(knock(1.03, 1.0), 0.74, 1.3))
    save("knock3", knocks)
    save("knock1", knock())
    for i in range(4):
        save(f"footstep_{i + 1}", footstep(i + 10), 0.7)
    save("door_open", fade(mix(creak(0.9, 260, 420), at(thud(0.05, 4000, 0.006), 0.0, 0.9))))
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


if __name__ == "__main__":
    main()
