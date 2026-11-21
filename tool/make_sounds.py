#!/usr/bin/env python3
"""Writes the game's placeholder street sounds as WAV files (no recordings
yet): the rickshaw bell, CNG and bus horns, the road's hum, rain, a
traffic policeman's whistle and a bus conductor's knock.

    python3 tool/make_sounds.py

Made once here rather than in the game: Godot then imports them like any
recording, and they can be swapped for real ones under the same names.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'game', 'sounds')


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32000)) for s in samples))


def bell():
    n = int(RATE * 0.9)
    out = [0.0] * n
    partials = [(2093, 0.5), (2817, 0.3), (4186, 0.18), (5590, 0.1)]
    for strike in (0.0, 0.28):
        start = int(strike * RATE)
        for i in range(start, n):
            t = (i - start) / RATE
            env = math.exp(-t * 7) * (1 + 0.35 * math.sin(2 * math.pi * 32 * t))
            out[i] += sum(math.sin(2 * math.pi * f * t) * a for f, a in partials) * env * 0.45
    return out


def horn(f1, f2, seconds):
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1, t / 0.015) * min(1, (seconds - t) / 0.05)
        wob = 1 + 0.004 * math.sin(2 * math.pi * 6 * t)
        v = sum(math.sin(2 * math.pi * f * wob * k * t) / k for f in (f1, f2) for k in (1, 3, 5))
        out.append(v * env * 0.22)
    return out


def hum(seconds):
    rnd = random.Random(5)
    n = int(RATE * seconds)
    out, brown, low = [], 0.0, 0.0
    for i in range(n):
        brown = max(-1, min(1, brown + rnd.uniform(-0.02, 0.02)))
        low += (brown - low) * 0.05
        t = i / RATE
        out.append(low * 0.9 + math.sin(2 * math.pi * 55 * t) * 0.03 * (0.6 + 0.4 * math.sin(2 * math.pi * 0.5 * t)))
    fade = RATE // 4
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[n - 1 - i] *= k
    return out


def rain(seconds):
    """Steady rain: hiss (noise through a gentle low-pass) with drops
    pattering on tin roofs and puddles."""
    rnd = random.Random(11)
    n = int(RATE * seconds)
    out, low, prev = [], 0.0, 0.0
    for i in range(n):
        white = rnd.uniform(-1, 1)
        low += (white - low) * 0.35
        out.append((low - prev * 0.6) * 0.32)
        prev = low
    for _ in range(int(seconds * 45)):
        at = rnd.randrange(n - RATE // 20)
        f = rnd.uniform(900, 2600)
        a = rnd.uniform(0.05, 0.22)
        for k in range(RATE // 25):
            t = k / RATE
            out[at + k] += math.sin(2 * math.pi * f * t) * a * math.exp(-t * 160)
    fade = RATE // 3
    for i in range(fade):
        k = i / fade
        out[i] *= k
        out[n - 1 - i] *= k
    return out


def whistle():
    """Two blasts of a pea whistle: a high note warbling as the pea spins."""
    out = []
    for length, gap in ((0.28, 0.12), (0.62, 0.0)):
        n = int(RATE * length)
        for i in range(n):
            t = i / RATE
            env = min(1, t / 0.02) * min(1, (length - t) / 0.04)
            trill = 0.55 + 0.45 * math.sin(2 * math.pi * 34 * t)
            f = 2950 + 60 * math.sin(2 * math.pi * 34 * t)
            out.append(math.sin(2 * math.pi * f * t) * env * trill * 0.5)
        out.extend([0.0] * int(RATE * gap))
    return out


def thump():
    """A bus conductor's palm on the side of the bus, twice: a dull knock
    on thin steel."""
    rnd = random.Random(3)
    out = []
    for gap in (0.16, 0.0):
        n = int(RATE * 0.12)
        for i in range(n):
            t = i / RATE
            env = math.exp(-t * 38)
            v = math.sin(2 * math.pi * 95 * t) * 0.8 + math.sin(2 * math.pi * 230 * t) * 0.3 + rnd.uniform(-1, 1) * 0.25 * math.exp(-t * 90)
            out.append(v * env * 0.7)
        out.extend([0.0] * int(RATE * gap))
    return out


if __name__ == '__main__':
    write('bell.wav', bell())
    write('horn_cng.wav', horn(560, 700, 0.35))
    write('horn_bus.wav', horn(290, 370, 0.9))
    write('hum.wav', hum(12))
    write('rain.wav', rain(8))
    write('whistle.wav', whistle())
    write('thump.wav', thump())
    print('sounds written to', os.path.normpath(OUT))
