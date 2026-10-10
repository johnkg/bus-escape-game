#!/usr/bin/env python3
"""Synthesizes the placeholder SFX and music loop into assets/audio/.

All sounds are generated from scratch with plain sine/square/noise math, so
they are original to this project (no third-party license). Replace the
files with nicer ones any time; keep the same names.

    python3 tools/generate_audio.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write(name, samples, peak=0.8):
    m = max(1e-9, max(abs(s) for s in samples))
    scale = min(1.0, peak / m) if m > peak else 1.0
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(max(-1, min(1, s * scale)) * 32767)) for s in samples)
        )


def tone(freq, dur, kind="sine", vol=0.6, attack=0.005, decay=6.0, f_end=None):
    n = int(RATE * dur)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq if f_end is None else freq + (f_end - freq) * (i / n)
        phase += 2 * math.pi * f / RATE
        if kind == "square":
            v = 1.0 if math.sin(phase) >= 0 else -1.0
            v *= 0.5
        elif kind == "tri":
            v = (2 / math.pi) * math.asin(math.sin(phase))
        else:
            v = math.sin(phase)
        env = min(1.0, t / attack) * math.exp(-decay * t / dur)
        out.append(v * env * vol)
    return out


def noise(dur, vol=0.3, decay=8.0):
    random.seed(7)
    n = int(RATE * dur)
    return [random.uniform(-1, 1) * vol * math.exp(-decay * i / n) for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def seq(*parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(RATE * gap)
    return out


def offset(track, secs):
    return [0.0] * int(RATE * secs) + track


NOTE = {"C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.0, "A4": 440.0,
        "C5": 523.25, "D5": 587.33, "E5": 659.25, "G5": 783.99, "C6": 1046.5,
        "C3": 130.81, "G3": 196.0, "A3": 220.0, "F3": 174.61}

# --- SFX ---
write("exit.wav", mix(tone(220, 0.28, "tri", 0.5, decay=4, f_end=520), noise(0.28, 0.12, 5)))
write("blocked.wav", seq(tone(140, 0.09, "square", 0.45, decay=5), tone(120, 0.12, "square", 0.45, decay=5), gap=0.03))
write("board.wav", tone(880, 0.07, "sine", 0.6, decay=7, f_end=1100))
write("depart.wav", seq(tone(NOTE["G4"], 0.12, "sine", 0.5, decay=4), tone(NOTE["C5"], 0.25, "sine", 0.5, decay=5)))
write("win.wav", seq(*[tone(NOTE[n], 0.16, "tri", 0.55, decay=3) for n in ["C5", "E5", "G5"]], tone(NOTE["C6"], 0.5, "tri", 0.55, decay=4)))
write("lose.wav", tone(420, 0.6, "tri", 0.55, decay=3, f_end=140))
write("undo.wav", tone(700, 0.15, "sine", 0.5, decay=5, f_end=420))
write("booster.wav", seq(*[tone(f, 0.08, "sine", 0.5, decay=4) for f in (660, 880, 1320)]))

# --- Music: 8-bar loop, C major pentatonic over a simple bass ---
BPM = 100
beat = 60 / BPM
melody = ["E4", "G4", "A4", "G4", "E4", "D4", "E4", "G4",
          "A4", "C5", "A4", "G4", "E4", "G4", "D4", "C4",
          "E4", "G4", "A4", "C5", "D5", "C5", "A4", "G4",
          "A4", "G4", "E4", "D4", "E4", "D4", "C4", "C4"]
bass = ["C3", "C3", "A3", "A3", "F3", "F3", "G3", "G3"]
total = len(melody) * beat * 0.5
music = [0.0] * int(RATE * total)
for i, n in enumerate(melody):
    note = tone(NOTE[n], beat * 0.5, "tri", 0.30, decay=3)
    for j, s in enumerate(note):
        k = int(RATE * i * beat * 0.5) + j
        if k < len(music):
            music[k] += s
for i, n in enumerate(bass):
    note = tone(NOTE[n] / (2 if NOTE[n] > 150 else 1), beat * 2, "sine", 0.28, decay=2)
    for j, s in enumerate(note):
        k = int(RATE * i * beat * 2) + j
        if k < len(music):
            music[k] += s
# fade the ends so the loop point doesn't click
f = int(RATE * 0.02)
for i in range(f):
    music[i] *= i / f
    music[-1 - i] *= i / f
write("music.wav", music, peak=0.6)
print("wrote audio to", os.path.abspath(OUT))
