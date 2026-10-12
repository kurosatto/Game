"""Procedural ambient music and extra sound effects (numpy).

Writes:
  assets/music/*.wav   seamless loops, one mood per stretch of the run
  assets/sfx/{dash,zap,evolve,boss_intro,room_clear}.wav
  assets/sfx/{hit,enemy_die}.wav (replacing generate_audio.py's versions)
and fades the tails of shoot/player_hurt/explosion so they don't click.
Only run main() once per fresh set of generate_audio.py files.

Run from the project root:  python generate_music.py
Godot then imports the WAVs; the music .import files use QOA compression
and forward looping so the loops stay small in the APK.
"""
import os
import wave

import numpy as np
from scipy.signal import lfilter

SFX_RATE = 44100
MUSIC_RATE = 22050
rng = np.random.default_rng(7)
MUSIC = True


def write_wav(path, x, rate, peak=0.38):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print("  wrote", path, f"{len(x) / rate:.1f}s")


def t_axis(seconds, rate):
    return np.arange(int(seconds * rate)) / rate


def env(n, attack, release, rate):
    """Linear attack, exponential release over n samples."""
    a = max(1, int(attack * rate))
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    tail = np.arange(n - a) / rate
    e[a:] = np.exp(-tail / max(release, 1e-4))
    return e


def lowpass(x, cutoff, rate):
    """One-pole low-pass, good enough to take the edge off noise and saws."""
    alpha = 1 - np.exp(-2 * np.pi * cutoff / rate)
    return lfilter([alpha], [1, -(1 - alpha)], x)


def reverb(x, rate, decay=0.55, mix=0.35):
    """Small Schroeder-style reverb: parallel feedback combs then an allpass."""
    padded = np.concatenate([x, np.zeros(rate * 2)])
    wet = np.zeros(len(padded))
    for ms in (29.7, 37.1, 41.1, 43.7):
        d = int(rate * ms / 1000)
        a = np.zeros(d + 1)
        a[0], a[d] = 1, -decay
        wet += lfilter([1], a, padded)
    wet /= 4
    d = int(rate * 0.005)
    b = np.zeros(d + 1); b[0], b[d] = -0.5, 1
    a = np.zeros(d + 1); a[0], a[d] = 1, -0.5
    wet = lfilter(b, a, wet)
    return padded * (1 - mix) + wet * mix


# ─────────────────────────── sound effects ───────────────────────────

def sfx_dash():
    # Water whoosh: filtered noise swept up then down, with a soft body
    t = t_axis(0.32, SFX_RATE)
    n = rng.standard_normal(len(t))
    sweep = np.concatenate([np.linspace(400, 3200, len(t) // 3), np.linspace(3200, 600, len(t) - len(t) // 3)])
    y = np.zeros(len(t))
    acc = 0.0
    for i in range(len(t)):
        alpha = 1 - np.exp(-2 * np.pi * sweep[i] / SFX_RATE)
        acc += alpha * (n[i] - acc)
        y[i] = acc
    body = np.sin(2 * np.pi * (180 + 220 * t) * t) * 0.35
    return np.tanh(1.6 * (y / np.max(np.abs(y)) + body)) * env(len(t), 0.03, 0.09, SFX_RATE)


def sfx_zap():
    # Electric discharge: crackle bursts over a falling square-ish buzz
    t = t_axis(0.55, SFX_RATE)
    f = 880 * np.exp(-t * 4) + 110
    phase = 2 * np.pi * np.cumsum(f) / SFX_RATE
    buzz = np.tanh(3 * np.sin(phase)) * 0.6
    crackle = rng.standard_normal(len(t)) * (rng.random(len(t)) < 0.08)
    crackle = lowpass(crackle, 5000, SFX_RATE) * 3
    sub = np.sin(2 * np.pi * 70 * t) * 0.5
    # Soft-clip so the crackle peaks don't leave the body too quiet
    return np.tanh(2.2 * (buzz + crackle + sub)) * env(len(t), 0.005, 0.16, SFX_RATE)


def sfx_evolve():
    # Rising shimmer arpeggio into a warm major chord
    total = t_axis(1.6, SFX_RATE)
    y = np.zeros(len(total))
    notes = [261.6, 329.6, 392.0, 523.3, 659.3, 784.0]
    for k, f in enumerate(notes):
        start = int(k * 0.07 * SFX_RATE)
        tt = t_axis(1.6 - k * 0.07, SFX_RATE)
        tone = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2 * tt) + 0.12 * np.sin(2 * np.pi * f * 3.01 * tt)
        y[start:start + len(tt)] += tone * env(len(tt), 0.01, 0.55, SFX_RATE) * 0.5
    chord_start = int(0.45 * SFX_RATE)
    tt = t_axis(1.6 - 0.45, SFX_RATE)
    pad = sum(np.sin(2 * np.pi * f * tt * (1 + d)) for f in (130.8, 196.0, 261.6, 329.6) for d in (-0.003, 0.003))
    y[chord_start:] += pad * env(len(tt), 0.15, 0.5, SFX_RATE) * 0.18
    return reverb(y, SFX_RATE, 0.5, 0.3)[: int(1.9 * SFX_RATE)]


def sfx_boss_intro():
    # Low swell with a deep drum hit and a dissonant horn
    t = t_axis(2.2, SFX_RATE)
    swell = np.sin(2 * np.pi * 55 * t) + 0.5 * np.sin(2 * np.pi * 58.3 * t)
    swell *= np.clip(t / 1.4, 0, 1) ** 2 * np.exp(-np.clip(t - 1.5, 0, None) * 4)
    horn_f = np.where(t < 1.1, 110, 103.8)
    horn = np.tanh(2.5 * np.sin(2 * np.pi * np.cumsum(horn_f) / SFX_RATE)) * 0.4
    horn = lowpass(horn, 900, SFX_RATE) * np.clip((t - 0.3) / 0.6, 0, 1) * np.exp(-np.clip(t - 1.6, 0, None) * 5)
    drum = np.zeros(len(t))
    hit = int(1.45 * SFX_RATE)
    dt = t_axis(0.7, SFX_RATE)
    drum[hit:hit + len(dt)] = np.sin(2 * np.pi * (45 + 80 * np.exp(-dt * 18)) * dt) * np.exp(-dt * 5) * 1.4
    return reverb(swell * 0.6 + horn + drum, SFX_RATE, 0.6, 0.35)[: int(2.6 * SFX_RATE)]


def sfx_room_clear():
    # Bright two-note chime with bubbly sparkle
    t = t_axis(1.0, SFX_RATE)
    y = np.zeros(len(t))
    for start, f in ((0.0, 659.3), (0.11, 987.8)):
        s = int(start * SFX_RATE)
        tt = t[: len(t) - s]
        bell = np.sin(2 * np.pi * f * tt) + 0.4 * np.sin(2 * np.pi * f * 2.76 * tt) * np.exp(-tt * 8)
        y[s:] += bell * env(len(tt), 0.004, 0.32, SFX_RATE)
    sparkle = np.zeros(len(t))
    for _ in range(9):
        s = int(rng.uniform(0.05, 0.6) * SFX_RATE)
        tt = t_axis(0.06, SFX_RATE)
        f = rng.uniform(1800, 3200)
        blip = np.sin(2 * np.pi * (f + 2000 * tt) * tt) * env(len(tt), 0.002, 0.015, SFX_RATE)
        sparkle[s:s + len(tt)] += blip * 0.25
    return reverb(y + sparkle, SFX_RATE, 0.45, 0.25)[: int(1.3 * SFX_RATE)]


def sfx_hit():
    # Wet thwack: short pitch-dropping body, a little filtered click on top
    t = t_axis(0.12, SFX_RATE)
    body = np.sin(2 * np.pi * (320 * np.exp(-t * 30) + 140) * t) * np.exp(-t * 38)
    click = lowpass(rng.standard_normal(len(t)), 2800, SFX_RATE) * np.exp(-t * 120) * 0.8
    return lowpass(lowpass(np.tanh(1.8 * (body + click)), 3500, SFX_RATE), 3500, SFX_RATE) * fade_out(len(t), 0.01)


def sfx_enemy_die():
    # Gooey pop: bubble burst (fast upward chirp) then a soft squelch
    t = t_axis(0.36, SFX_RATE)
    pop = np.sin(2 * np.pi * (220 + 1600 * t) * t) * np.exp(-t * 26)
    squelch = lowpass(rng.standard_normal(len(t)), 1200, SFX_RATE) * np.exp(-((t - 0.06) / 0.05) ** 2) * 1.6
    low = np.sin(2 * np.pi * (180 * np.exp(-t * 6) + 60) * t) * np.exp(-t * 12) * 0.7
    return lowpass(lowpass(np.tanh(1.5 * (pop + squelch + low)), 3000, SFX_RATE), 3000, SFX_RATE) * fade_out(len(t), 0.03)


def fade_out(n, seconds):
    f = np.ones(n)
    k = min(n, int(seconds * SFX_RATE))
    f[n - k:] = np.linspace(1, 0, k)
    return f


def declick(path, seconds=0.008):
    """Fade the last few ms of an existing effect so it doesn't click when it stops."""
    with wave.open(path) as w:
        rate, frames = w.getframerate(), w.readframes(w.getnframes())
    x = np.frombuffer(frames, "<i2").astype(np.float64)
    k = min(len(x), int(seconds * rate))
    x[len(x) - k:] *= np.linspace(1, 0, k)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(x.astype("<i2").tobytes())
    print("  declicked", path)


# ─────────────────────────────── music ───────────────────────────────

def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def pad_voice(freq, seconds, rate, brightness=0.25):
    t = t_axis(seconds, rate)
    lfo = 1 + 0.002 * np.sin(2 * np.pi * 0.13 * t)
    x = np.zeros(len(t))
    for det in (-0.004, 0.0, 0.004):
        ph = 2 * np.pi * freq * (1 + det) * lfo * t
        x += np.sin(ph) + brightness * np.sin(2 * ph) + brightness * 0.4 * np.sin(3 * ph)
    return x / 3


def bell(freq, seconds, rate):
    t = t_axis(seconds, rate)
    return (np.sin(2 * np.pi * freq * t) + 0.35 * np.sin(2 * np.pi * freq * 2.0 * t) * np.exp(-t * 3)
            + 0.15 * np.sin(2 * np.pi * freq * 3.01 * t) * np.exp(-t * 6)) * np.exp(-t * 1.6)


def render_track(chords, bpm, scale, root_note, seconds, bubble_amount, pulse=False, arp_density=0.55, seed=1):
    """Chords are lists of MIDI notes, one chord per bar of 4 beats."""
    r = np.random.default_rng(seed)
    rate = MUSIC_RATE
    n = int(seconds * rate)
    out = np.zeros(n + rate * 4)  # extra tail, folded back onto the start for a seamless loop
    beat = 60.0 / bpm
    bar = beat * 4
    bars = int(round(seconds / bar))

    for b in range(bars):
        chord = chords[b % len(chords)]
        s = int(b * bar * rate)
        for note in chord:
            v = pad_voice(midi(note), bar + 1.5, rate) * env(int((bar + 1.5) * rate), 1.2, 1.0, rate)
            v[: int(bar * rate)] = pad_voice(midi(note), bar, rate) * np.minimum(1, np.arange(int(bar * rate)) / (1.2 * rate))
            out[s:s + len(v)] += v * 0.16
        # Sub drone on the chord root
        tt = t_axis(bar, rate)
        sub = np.sin(2 * np.pi * midi(chord[0] - 12) * tt) * 0.22
        fade = np.minimum(1, np.minimum(np.arange(len(tt)), len(tt) - np.arange(len(tt))) / (0.4 * rate))
        out[s:s + len(tt)] += sub * fade

        # Sparse bell arpeggio from the scale
        for step in range(8):
            if r.random() < arp_density:
                deg = r.choice(scale)
                octave = r.choice([12, 24])
                bs = s + int(step * beat / 2 * rate)
                bl = bell(midi(root_note + deg + octave), 2.5, rate) * 0.09 * r.uniform(0.6, 1.0)
                out[bs:bs + len(bl)] += bl[: len(out) - bs]

        if pulse:
            for k in range(4):
                ks = s + int(k * beat * rate)
                kt = t_axis(0.4, rate)
                kick = np.sin(2 * np.pi * (48 + 60 * np.exp(-kt * 25)) * kt) * np.exp(-kt * 9) * (0.55 if k % 2 == 0 else 0.35)
                out[ks:ks + len(kt)] += kick

    # Bubbles: short rising sine chirps
    for _ in range(int(seconds * bubble_amount)):
        bs = int(r.uniform(0, seconds) * rate)
        bt = t_axis(r.uniform(0.03, 0.08), rate)
        f0 = r.uniform(500, 1400)
        bub = np.sin(2 * np.pi * (f0 + f0 * 3 * bt / bt[-1]) * bt) * env(len(bt), 0.004, 0.02, rate) * 0.05
        out[bs:bs + len(bub)] += bub

    # Soft water noise bed
    noise = lowpass(r.standard_normal(len(out)), 350, rate) * 0.10
    out += noise * (0.8 + 0.2 * np.sin(2 * np.pi * np.arange(len(out)) / rate / 9.0))

    out = reverb(out, rate, 0.62, 0.4)
    loop = out[:n].copy()
    tail = out[n:]
    loop[: min(len(tail), n)] += tail[: min(len(tail), n)]
    return loop


def main():
    os.makedirs("assets/sfx", exist_ok=True)
    print("SFX")
    write_wav("assets/sfx/dash.wav", sfx_dash(), SFX_RATE)
    write_wav("assets/sfx/zap.wav", sfx_zap(), SFX_RATE)
    write_wav("assets/sfx/evolve.wav", sfx_evolve(), SFX_RATE)
    write_wav("assets/sfx/boss_intro.wav", sfx_boss_intro(), SFX_RATE)
    write_wav("assets/sfx/room_clear.wav", sfx_room_clear(), SFX_RATE)
    write_wav("assets/sfx/hit.wav", sfx_hit(), SFX_RATE)
    write_wav("assets/sfx/enemy_die.wav", sfx_enemy_die(), SFX_RATE)
    for name in ("shoot", "player_hurt", "explosion"):
        declick(f"assets/sfx/{name}.wav")

    if not MUSIC:
        return
    print("Music")
    minor_pent = [0, 3, 5, 7, 10]
    dorian = [0, 2, 3, 5, 7, 9, 10]
    phrygian = [0, 1, 3, 5, 7, 8, 10]
    # Shallow tidepool: calm, open fifths and suspended chords (floors 1-2)
    write_wav("assets/music/tidepool.wav", render_track(
        [[50, 57, 62, 64], [48, 55, 60, 67], [46, 53, 58, 62], [48, 55, 62, 64]],
        bpm=64, scale=minor_pent, root_note=62, seconds=60, bubble_amount=1.2, seed=11), MUSIC_RATE, 0.5)
    # Open reef: brighter dorian colour (floors 3-4)
    write_wav("assets/music/reef.wav", render_track(
        [[45, 52, 57, 60, 64], [43, 50, 55, 62], [41, 48, 53, 60, 64], [43, 50, 57, 62]],
        bpm=70, scale=dorian, root_note=57, seconds=55, bubble_amount=0.8, arp_density=0.65, seed=23), MUSIC_RATE, 0.5)
    # Deep time: darker, slower (floor 5 and beyond)
    write_wav("assets/music/abyss.wav", render_track(
        [[40, 47, 52, 55], [41, 48, 53, 56], [38, 45, 50, 53], [40, 47, 53, 56]],
        bpm=56, scale=phrygian, root_note=52, seconds=69, bubble_amount=0.5, arp_density=0.4, seed=37), MUSIC_RATE, 0.5)
    # Boss: same palette with a heartbeat pulse
    write_wav("assets/music/boss.wav", render_track(
        [[38, 45, 50, 53], [39, 46, 51, 54], [38, 45, 50, 53], [36, 43, 48, 54]],
        bpm=92, scale=phrygian, root_note=50, seconds=41.7, bubble_amount=0.3, pulse=True, arp_density=0.75, seed=41), MUSIC_RATE, 0.55)


if __name__ == "__main__":
    import sys
    if "--sfx-only" in sys.argv:
        MUSIC = False
    main()
