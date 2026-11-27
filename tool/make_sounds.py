#!/usr/bin/env python3
"""Writes the game's placeholder street sounds as WAV files (no recordings
yet): the rickshaw bell, CNG and bus horns, the road's hum, rain, a
traffic policeman's whistle, a bus conductor's knock, coins, and the
home screen's tune: an original folk-style loop on a plucked string over
a drone and a hand drum.

    python3 tool/make_sounds.py

Made once here rather than in the game: Godot then imports them like any
recording, and they can be swapped for real ones under the same names.
"""
import math
import os
import random
import shutil
import subprocess
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


def coin():
    """Two coins dropped into a tin: bright, short rings."""
    out = [0.0] * int(RATE * 0.5)
    for start, f in ((0.0, 3150), (0.09, 3720)):
        s0 = int(start * RATE)
        for i in range(s0, len(out)):
            t = (i - s0) / RATE
            env = math.exp(-t * 16)
            out[i] += (math.sin(2 * math.pi * f * t) + 0.5 * math.sin(2 * math.pi * f * 1.51 * t)
                       + 0.25 * math.sin(2 * math.pi * f * 2.33 * t)) * env * 0.3
    return out


def pluck(freq, seconds, rnd, bright=0.5):
    """A plucked string (Karplus-Strong), like a dotara's."""
    n = int(RATE * seconds)
    period = max(2, int(RATE / freq))
    buf = [rnd.uniform(-1, 1) for _ in range(period)]
    out = []
    for i in range(n):
        v = buf[i % period]
        nxt = buf[(i + 1) % period]
        buf[i % period] = (v * bright + nxt * (1 - bright)) * 0.996
        out.append(v)
    return out


def flute(freq, seconds, rnd):
    """A bamboo flute (bansuri): a soft tone with breath and vibrato."""
    n = int(RATE * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        vib = 1 + 0.006 * math.sin(2 * math.pi * 5.5 * t) * min(1, t / 0.25)
        phase += 2 * math.pi * freq * vib / RATE
        env = min(1, t / 0.06) * min(1, (seconds - t) / 0.12)
        v = math.sin(phase) + 0.18 * math.sin(2 * phase) + 0.06 * math.sin(3 * phase)
        out.append((v + rnd.uniform(-0.08, 0.08)) * env * 0.55)
    return out


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# Original melodies in a major pentatonic (and its relatives), as
# (midi note, beats); each tune's phrases add up to 32 beats.
TUNES = {
    # The home screen: easy, plucked, a drone of D.
    'tune': {'bpm': 100, 'voice': 'pluck', 'root': 50, 'drum': 'dha-ta', 'phrases': [
        [(69, 1), (71, .5), (69, .5), (66, 1), (64, 1), (66, .5), (69, .5), (71, 1), (69, 2)],
        [(74, 1), (71, .5), (74, .5), (76, 1), (74, 1), (71, .5), (69, .5), (66, 1), (69, 2)],
        [(66, .5), (69, .5), (71, 1), (69, .5), (66, .5), (64, 1), (62, .5), (64, .5), (66, 1), (64, 2)],
        [(64, 1), (66, .5), (64, .5), (62, 1), (57, 1), (62, 1), (64, 1), (62, 2)]]},
    # The rickshaw: brisk, like pedalling, in G.
    'tune_rickshaw': {'bpm': 116, 'voice': 'pluck', 'root': 43, 'drum': 'busy', 'phrases': [
        [(67, .5), (69, .5), (71, 1), (74, .5), (71, .5), (69, 1), (67, .5), (69, .5), (71, 1), (69, 2)],
        [(71, .5), (74, .5), (76, 1), (74, .5), (71, .5), (74, 1), (76, .5), (79, .5), (76, 1), (74, 2)],
        [(76, .5), (74, .5), (71, 1), (69, .5), (71, .5), (74, 1), (71, .5), (69, .5), (67, 1), (69, 2)],
        [(71, 1), (69, .5), (67, .5), (64, 1), (67, 1), (69, .5), (71, .5), (69, 1), (67, 2)]]},
    # The tea stall: slow, a flute over the drone, in A.
    'tune_tea': {'bpm': 80, 'voice': 'flute', 'root': 45, 'drum': 'soft', 'phrases': [
        [(76, 2), (78, 1), (76, 1), (73, 2), (71, 2)],
        [(69, 1), (71, 1), (73, 2), (76, 1), (73, 1), (71, 2)],
        [(73, 2), (76, 1), (78, 1), (81, 2), (78, 1), (76, 1)],
        [(73, 1), (71, 1), (69, 2), (66, 1), (69, 1), (69, 2)]]},
    # The bus: fast and busy, in E.
    'tune_bus': {'bpm': 128, 'voice': 'pluck', 'root': 40, 'drum': 'busy', 'phrases': [
        [(64, .5), (66, .5), (68, .5), (71, .5), (68, 1), (66, 1), (64, .5), (66, .5), (68, 1), (66, 2)],
        [(71, .5), (73, .5), (76, 1), (73, .5), (71, .5), (68, 1), (71, .5), (73, .5), (71, 1), (68, 2)],
        [(76, 1), (73, .5), (71, .5), (73, 1), (76, 1), (78, .5), (76, .5), (73, 1), (71, 2)],
        [(68, .5), (71, .5), (68, .5), (66, .5), (64, 1), (66, 1), (68, 1), (66, 1), (64, 2)]]},
    # A festival: dhol and flute, bright, in C.
    'tune_festival': {'bpm': 120, 'voice': 'flute', 'root': 48, 'drum': 'dhol', 'phrases': [
        [(72, .5), (74, .5), (76, 1), (79, 1), (76, .5), (74, .5), (72, 1), (74, 1), (76, 2)],
        [(79, .5), (81, .5), (79, 1), (76, 1), (74, .5), (76, .5), (79, 1), (81, 1), (79, 2)],
        [(84, 1), (81, .5), (79, .5), (81, 1), (79, 1), (76, .5), (74, .5), (76, 1), (79, 2)],
        [(76, 1), (74, .5), (72, .5), (69, 1), (72, 1), (74, .5), (76, .5), (74, 1), (72, 2)]]},
    # The theme song: a catchy hook to hum (and the reels' music), fast,
    # dhol under a plucked tune, in D.
    'tune_theme': {'bpm': 132, 'voice': 'pluck', 'root': 50, 'drum': 'dhol', 'phrases': [
        [(74, .5), (74, .5), (76, .5), (78, .5), (81, 1), (78, .5), (76, .5), (74, 1), (76, 1), (78, 2)],
        [(74, .5), (74, .5), (76, .5), (78, .5), (81, 1), (83, .5), (81, .5), (78, 1), (76, 1), (74, 2)],
        [(81, .5), (83, .5), (86, 1), (83, .5), (81, .5), (78, 1), (81, .5), (78, .5), (76, 1), (78, 2)],
        [(76, .5), (78, .5), (81, .5), (78, .5), (76, 1), (74, 1), (71, .5), (74, .5), (76, 1), (74, 2)]]},
}


def ting():
    """A bright little ting for a combo."""
    out = []
    for i in range(int(RATE * 0.35)):
        t = i / RATE
        v = (math.sin(2 * math.pi * 1760 * t) + 0.5 * math.sin(2 * math.pi * 2640 * t)) * math.exp(-t * 12)
        out.append(v * 0.4)
    return out


def sparkle():
    """Rising chimes for five stars."""
    out = [0.0] * int(RATE * 0.9)
    for k, f in enumerate([1318, 1568, 1976, 2637]):
        start = int(k * 0.09 * RATE)
        for i in range(int(RATE * 0.5)):
            j = start + i
            if j < len(out):
                t = i / RATE
                out[j] += math.sin(2 * math.pi * f * t) * math.exp(-t * 9) * 0.25
    return out


def tune(spec, seed=11):
    """32 beats made to loop: the melody, a drone on the root and its
    fifth, and a hand drum in the tune's own pattern."""
    rnd = random.Random(seed)
    beat = 60.0 / spec['bpm']
    total = int(RATE * beat * 32)
    out = [0.0] * total
    at = 0.0
    for phrase in spec['phrases']:
        for m, beats in phrase:
            start = int(at * beat * RATE)
            if spec['voice'] == 'pluck':
                # Each note rings a little past its length, the next pluck over it.
                note = pluck(midi(m), beats * beat + 0.4, rnd)
                gain = 0.32
            else:
                note = flute(midi(m), beats * beat * 0.95, rnd)
                gain = 0.3
            for i, v in enumerate(note):
                j = start + i
                if j < total:
                    out[j] += v * gain * min(1.0, (len(note) - i) / 800)
            at += beats
    root = spec['root']
    for i in range(total):
        t = i / RATE
        out[i] += (math.sin(2 * math.pi * midi(root) * t) * 0.07 + math.sin(2 * math.pi * midi(root + 7) * t) * 0.05
                   + math.sin(2 * math.pi * midi(root + 12) * t) * 0.03)
    # Drum strokes per half beat: L low (dha), H high (ta), . rest.
    patterns = {'dha-ta': 'LHHL', 'busy': 'LHLHHLHH', 'soft': 'L.H.', 'dhol': 'LLHLLHLH'}
    pat = patterns[spec['drum']]
    soft = spec['drum'] == 'soft'
    for k in range(64):
        stroke = pat[k % len(pat)]
        if stroke == '.':
            continue
        start = int(k * beat / 2 * RATE)
        for i in range(int(RATE * 0.25)):
            j = start + i
            if j >= total:
                break
            t = i / RATE
            if stroke == 'L':
                f = (62 if spec['drum'] == 'dhol' else 70) + 50 * math.exp(-t * 30)
                v = math.sin(2 * math.pi * f * t) * math.exp(-t * 11) * (0.5 if spec['drum'] == 'dhol' else 0.45)
            else:
                v = (math.sin(2 * math.pi * 1250 * t) * 0.5 + rnd.uniform(-1, 1) * 0.5) * math.exp(-t * 45) * 0.2
            out[j] += v * (0.5 if soft else 1.0)
    peak = max(abs(v) for v in out)
    return [v / peak * 0.8 for v in out]


def write_music(name, samples):
    """Music is kept as Ogg Vorbis (a tenth of the size) when ffmpeg is
    there to make it."""
    write(name + '.wav', samples)
    wav = os.path.join(OUT, name + '.wav')
    if shutil.which('ffmpeg'):
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', wav, '-c:a', 'libvorbis', '-q:a', '4',
                        os.path.join(OUT, name + '.ogg')], check=True)
        os.remove(wav)


if __name__ == '__main__':
    write('bell.wav', bell())
    write('horn_cng.wav', horn(560, 700, 0.35))
    write('horn_bus.wav', horn(290, 370, 0.9))
    write('hum.wav', hum(12))
    write('rain.wav', rain(8))
    write('whistle.wav', whistle())
    write('thump.wav', thump())
    write('coin.wav', coin())
    write('ting.wav', ting())
    write('sparkle.wav', sparkle())
    for name, spec in TUNES.items():
        write_music(name, tune(spec))
    print('sounds written to', os.path.normpath(OUT))
