#!/usr/bin/env python3
"""Synthesises the in-game background music loop.

Bouncy major-key chiptune-ish groove (kick / clap / hat / octave bass /
soft chord pad / sixteenth arp / whistle lead) meant to read as "cheerful
and busy" without a lead line sharp enough to grate on a long session.
Renders a seamless 16-bar loop to WAV; encode to the OGG Main.tscn loads:

    python tools/gen_music.py island_bounce.wav
    ffmpeg -y -i island_bounce.wav -c:a libvorbis -qscale:a 3 \
        assets/audio/music/island_bounce.ogg

The .ogg.import is hand-set to loop=true (whole-stream loop) so the groove
runs gapless.
"""

import sys
import numpy as np

SR = 44100
BPM = 112.0
BEAT = 60.0 / BPM
BAR = 4.0 * BEAT
BARS = 16
DUR = BARS * BAR

# --- note helpers ---------------------------------------------------------
def hz(semi_from_a4: float) -> float:
    return 440.0 * 2.0 ** (semi_from_a4 / 12.0)

# midi-ish: semitone offset from A4
NOTE = {
    "C2": -33, "D2": -31, "E2": -29, "F2": -28, "G2": -26, "A2": -24,
    "C3": -21, "D3": -19, "E3": -17, "F3": -16, "G3": -14, "A3": -12, "B3": -10,
    "C4": -9, "D4": -7, "E4": -5, "F4": -4, "G4": -2, "A4": 0, "B4": 2,
    "C5": 3, "D5": 5, "E5": 7, "F5": 8, "G5": 10, "A5": 12,
}

# 8-bar chord loop (played twice). root, plus triad note names.
PROG = [
    ("C", ["C3", "E4", "G4", "C5"]),
    ("G", ["G2", "D4", "G4", "B4"]),
    ("A", ["A2", "E4", "A4", "C5"]),   # Am
    ("F", ["F2", "C4", "F4", "A4"]),
    ("C", ["C3", "E4", "G4", "C5"]),
    ("G", ["G2", "D4", "G4", "B4"]),
    ("F", ["F2", "C4", "F4", "A4"]),
    ("G", ["G2", "D4", "G4", "B4"]),
]
ROOT = {"C": "C2", "G": "G2", "A": "A2", "F": "F2"}

n_total = int(round(DUR * SR))
L = np.zeros(n_total)
R = np.zeros(n_total)
rng = np.random.default_rng(7)


def add(buf, start_t, sig, gain=1.0, pan=0.0):
    # `buf` is kept for call-site readability; routing is always stereo via
    # the equal-power pan below (pan -1 = hard left .. +1 = hard right).
    sig = np.asarray(sig, dtype=float)
    i = int(round(start_t * SR)) % n_total
    lgain = np.cos((pan + 1) * np.pi / 4)
    rgain = np.sin((pan + 1) * np.pi / 4)
    # Wrap past the end back to the start so note tails / releases that
    # spill over the loop boundary land where they'll actually be heard --
    # this is what keeps the loop seam click-free.
    idx = (np.arange(len(sig)) + i) % n_total
    np.add.at(L, idx, sig * (gain * lgain))
    np.add.at(R, idx, sig * (gain * rgain))


def env(n, a, d, s, r, sus=0.7):
    a = max(int(a * SR), 1)
    d = max(int(d * SR), 1)
    r = max(int(r * SR), 1)
    s = max(n - a - d - r, 0)
    e = np.concatenate([
        np.linspace(0, 1, a, endpoint=False),
        np.linspace(1, sus, d, endpoint=False),
        np.full(s, sus),
        np.linspace(sus, 0, r),
    ])
    if len(e) < n:
        e = np.concatenate([e, np.zeros(n - len(e))])
    return e[:n]


def tone(freq, dur, kind="sine", detune=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq * (1.0 + detune)
    ph = 2 * np.pi * f * t
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2.0 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        return np.sign(np.sin(ph)) * 0.9
    if kind == "saw":
        return 2.0 * (f * t - np.floor(0.5 + f * t))
    return np.sin(ph)


# --- drums --------------------------------------------------------------
def kick(dur=0.28):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = 118 * np.exp(-t * 32) + 46
    body = np.sin(2 * np.pi * np.cumsum(f) / SR)
    click = np.exp(-t * 220) * rng.standard_normal(n) * 0.25
    e = np.exp(-t * 7.5)
    return (body * e + click * np.exp(-t * 60)) * 0.95


def clap(dur=0.22):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    # crude bandpass around 1.6k
    b = np.convolve(nz, np.array([1, 0, -1]), "same")
    b = np.convolve(b, np.array([1, 0, -1]), "same")
    e = (np.exp(-t * 34) + 0.6 * np.exp(-((t - 0.012) ** 2) / 2e-5)
         + 0.5 * np.exp(-((t - 0.024) ** 2) / 2e-5))
    return b * e * 0.5


def hat(dur=0.06, open_=False):
    n = int(dur * SR)
    t = np.arange(n) / SR
    nz = rng.standard_normal(n)
    hp = np.convolve(nz, np.array([1, -2, 1]), "same")
    e = np.exp(-t * (36 if open_ else 90))
    return hp * e * 0.32


for bar in range(BARS):
    b0 = bar * BAR
    # kick: plain 1 & 3, no pushes -- keeps it a relaxed heartbeat
    for bt in (0.0, 2.0):
        add(L, b0 + bt * BEAT, kick(), 0.72, 0.0)
        add(R, b0 + bt * BEAT, kick(), 0.72, 0.0)
    # soft backbeat on 2 & 4
    for bt in (1.0, 3.0):
        c = clap()
        add(L, b0 + bt * BEAT, c, 0.55, -0.15)
        add(R, b0 + bt * BEAT, c, 0.55, 0.15)
    # hats on eighths, gentle offbeat accent, open hat before the next 1
    for k in range(8):
        t = b0 + k * 0.5 * BEAT
        g = 0.42 if k % 2 == 1 else 0.24
        h = hat(open_=(k == 7))
        add(L, t, h, g, -0.25)
        add(R, t, h, g, 0.25)

# --- bass: mostly root on the beat, one octave lift near the bar end --
for bar in range(BARS):
    chord = PROG[bar % 8]
    root = NOTE[ROOT[chord[0]]]
    for k in range(8):
        # play beats + the "and" of 2; rest on the others for air
        if k not in (0, 2, 3, 4, 6):
            continue
        t = bar * BAR + k * 0.5 * BEAT
        semi = root + (12 if k == 6 else 0)
        dur = 0.5 * BEAT * 1.05
        sig = (tone(hz(semi), dur, "saw") * 0.5
               + tone(hz(semi), dur, "square") * 0.35
               + tone(hz(semi - 12), dur, "sine") * 0.3)
        e = env(len(sig), 0.008, 0.06, 0.0, 0.09, sus=0.75)
        add(L, t, sig * e, 0.2, 0.0)
        add(R, t, sig * e, 0.2, 0.0)

# --- chord pad: soft sustained triad ---------------------------------
for bar in range(BARS):
    chord = PROG[bar % 8]
    notes = chord[1][1:]
    t = bar * BAR
    dur = BAR * 0.98
    for idx, nm in enumerate(notes):
        f = hz(NOTE[nm])
        sig = (tone(f, dur, "tri")
               + 0.5 * tone(f, dur, "tri", detune=0.004)
               + 0.3 * tone(f * 2, dur, "sine"))
        e = env(len(sig), 0.10, 0.25, 0.6, 0.35, sus=0.6)
        pan = -0.3 + 0.2 * idx
        add(L, t, sig * e, 0.065, pan)
        add(R, t, sig * e, 0.065, pan)

# --- arp: soft eighth-note pluck through the triad ------------------
for bar in range(BARS):
    chord = PROG[bar % 8]
    voices = chord[1][1:] + [chord[1][2]]
    pat = [0, 1, 2, 3, 2, 1, 2, 3]
    for k in range(8):
        t = bar * BAR + k * 0.5 * BEAT
        nm = voices[pat[k] % len(voices)]
        f = hz(NOTE[nm] + 12)
        dur = 0.5 * BEAT * 1.2
        sig = tone(f, dur, "tri") * 0.7 + tone(f, dur, "square") * 0.3
        e = env(len(sig), 0.006, 0.14, 0.0, 0.08, sus=0.0)
        add(L, t, sig * e, 0.05, -0.4)
        add(R, t + 0.013, sig * e, 0.05, 0.4)

# --- lead: gentle whistle motif -----------------------------------
# One slot per half-bar across the 16-bar loop (32 slots, None = rest).
# Bars 1-8 are a sparse "call"; bars 9-16 answer it a little busier.
MEL = [
    # bars 1-8 : sparse call
    "E5", None, None, None, "C5", None, "D5", None,
    "E5", None, None, None, "G4", None, None, None,
    # bars 9-16 : gentle answer
    "A4", None, "C5", None, "E5", None, "D5", None,
    "C5", None, None, "D5", "C5", None, None, None,
]
half = BAR / 2.0
for i, nm in enumerate(MEL):
    if nm is None:
        continue
    t = i * half
    f = hz(NOTE[nm])
    dur = half * 1.3
    vib = 1.0 + 0.005 * np.sin(2 * np.pi * 5.0 * np.arange(int(dur * SR)) / SR)
    n = int(dur * SR)
    sig = (np.sin(2 * np.pi * f * np.cumsum(vib) / SR) * 0.7
           + 0.3 * tone(f, dur, "tri"))
    e = env(n, 0.04, 0.12, 0.7, 0.3, sus=0.55)
    gain = 0.08 if i >= 16 else 0.07
    add(L, t, sig * e, gain, -0.08)
    add(R, t + 0.013, sig * e, gain, 0.08)

# --- glue -----------------------------------------------------------
mix = np.vstack([L, R])
# gentle saturation for a bit of warmth / glue
mix = np.tanh(mix * 1.15) / np.tanh(1.15)
# circular feedback delay: wraps around the loop so the tail is seamless
delay = int(round(0.75 * BEAT * SR))   # dotted-eighth echo
send = 0.5 * (L + R)
echo = send.copy()
tap = send.copy()
for _ in range(5):
    tap = np.roll(tap, delay) * 0.4
    echo += tap
mix[0] += 0.16 * echo
mix[1] += 0.16 * np.roll(echo, delay // 2)

# equal-power crossfade the tail onto the head, then drop the tail: the
# new end connects to sample 0 exactly where the old signal was already
# continuous, so the loop is truly click-free.
xf = int(0.009 * SR)
fi = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
fo = fi[::-1]
tail = mix[:, -xf:] * fo
mix = mix[:, :-xf]
mix[:, :xf] = mix[:, :xf] * fi + tail

# normalise (a touch below full -- it's a background bed)
peak = np.max(np.abs(mix))
mix = mix / peak * 0.82
out = (mix.T * 32767).astype(np.int16)

path = sys.argv[1] if len(sys.argv) > 1 else "island_bounce.wav"
import wave
with wave.open(path, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(out.tobytes())
print(f"wrote {path}  {DUR:.2f}s  {BPM:g} BPM  {BARS} bars")
