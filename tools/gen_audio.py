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


def save(name, x, peak=0.9):
    OUT.mkdir(parents=True, exist_ok=True)
    data = normalize(x, peak)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in data))


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


def loudest_100ms_db(x):
    """The highest RMS over any 100 ms of x, in dBFS: how docs/architecture.md's audio table measures files."""
    k = SR // 10
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
    r = random.Random(1209)  # chosen so the loop point falls on a small step (on other seeds, a normal one of up to 0.03)
    air = lowpass(lowpass(noise(6.5, r), 900), 900)  # two poles: through one, the air steps 0.04 a sample (hiss)
    beds["fan"] = [  # air with a blade-pass swell, 7 per 6 s loop, and a faint motor
        a * (1 + 0.25 * math.sin(2 * math.pi * 7 / 6 * i / SR)) + 0.025 * math.sin(2 * math.pi * 100 * i / SR)
        for i, a in enumerate(air)
    ]
    r = random.Random(1202)
    rumble = lowpass(lowpass(noise(4.5, r), 300), 300)
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
        x = loopable(x, 0.5)
        save(name, x, 0.5)
        x = normalize(x, 0.5)
        print(f"{name}: loudest 100 ms {loudest_100ms_db(x):.1f} dBFS, loop seam {abs(x[-1] - x[0]):.4f}")


if __name__ == "__main__":
    main()
