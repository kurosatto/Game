"""Original procedural soundtrack: one theme that evolves with life.

Every track is built from the same eight-bar "Genesis" melody. Each era
plays it in its own mode, tempo and instruments, the way the animals change
from floor to floor:

  title          D major      glass bells and a warm pad (main menu)
  ediacaran      D lydian     slow glass bells, water drops, no drums
  cambrian       G major      kalimba and bright plucks, shaker: life explodes
  ordovician     A dorian     wooden flute over marimba, whale calls
  carboniferous  E mixolydian harp plucks, hand drums, insects in the ferns
  permian        D aeolian    low breathy flute, frame drum, dry wind
  boss_<era>     the same instruments, minor, with a driving ostinato

Chords are picked bar by bar to fit the melody in each mode, so the theme
always sounds harmonised. Tracks are rendered as stereo, the reverb is
circular so loops are seamless, and they are written as Ogg Vorbis (needs
ffmpeg). SoundManager.gd loads assets/music/<name>.ogg and loops it.

Run from the project root:  python generate_soundtrack.py [track ...]
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.signal import lfilter

SR = 32000
MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "harmonic": [0, 2, 3, 5, 7, 8, 11],
}
# Chords that are not diminished or augmented in each mode (scale degrees)
GOOD_CHORDS = {
    "ionian": [0, 1, 2, 3, 4, 5],
    "lydian": [0, 1, 2, 4, 5],
    "mixolydian": [0, 1, 3, 4, 6],
    "dorian": [0, 1, 2, 3, 4, 6],
    "aeolian": [0, 2, 3, 4, 5, 6],
    "phrygian": [0, 1, 2, 3, 6],
    "harmonic": [0, 3, 4, 5],
}

# Hand-picked chords for THEME in each mode (scale degrees, one per bar),
# checked note by note against the melody; harmonise() covers any other theme
PROGRESSIONS = {
    "ionian": [0, 4, 3, 1, 5, 4, 3, 0],      # I V IV ii vi V IV I
    "lydian": [0, 4, 1, 4, 5, 2, 1, 0],      # I V II V vi iii II I
    "mixolydian": [0, 4, 3, 6, 5, 4, 3, 0],  # I v IV bVII vi v IV I
    "dorian": [0, 2, 3, 6, 0, 4, 3, 0],      # i III IV VII i v IV i
    "aeolian": [5, 2, 3, 6, 0, 2, 5, 0],     # VI III iv VII i III VI i
}
BOSS_PROGRESSIONS = {
    "harmonic": [5, 4, 0, 4],                # VI V i V
    "phrygian": [5, 6, 0, 1],                # VI vii i bII
}

# The Genesis theme: (scale degree, beats) per bar, 4 beats a bar
THEME = [
    [(2, 1.5), (4, 0.5), (5, 2)],
    [(4, 1), (2, 1), (1, 2)],
    [(0, 1.5), (1, 0.5), (2, 1), (4, 1)],
    [(1, 3), (None, 1)],
    [(2, 1.5), (4, 0.5), (7, 2)],
    [(6, 1), (5, 1), (4, 2)],
    [(5, 1), (4, 1), (2, 1), (1, 1)],
    [(0, 3), (None, 1)],
]


def midi_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def deg_to_midi(deg, mode, root):
    sc = MODES[mode]
    return root + sc[deg % 7] + 12 * (deg // 7)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def onepole(x, cutoff):
    a = 1 - np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([a], [1, -(1 - a)], x)


def adsr(n, attack, release, sustain_n=None):
    """Attack ramp, hold, then a smooth release over the last part."""
    e = np.ones(n)
    a = max(1, min(n, int(attack * SR)))
    e[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    r = max(1, min(n - a, int(release * SR)))
    e[n - r:] *= np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return e


# ───────────────────────────── instruments ─────────────────────────────
# Each returns a mono note; amplitudes are roughly matched (peak ~1).

def inst_glass(f, dur, rng):
    t = t_axis(max(dur, 3.5))
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t / 2.2)
         + 0.22 * np.sin(2 * np.pi * f * 2.0 * t + 0.3) * np.exp(-t / 0.9)
         + 0.07 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t / 0.4)
         + 0.04 * np.sin(2 * np.pi * f * 4.16 * t) * np.exp(-t / 0.15))
    return x * adsr(len(t), 0.006, 0.3)


def inst_kalimba(f, dur, rng):
    t = t_axis(2.2)
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.75)
         + 0.25 * np.sin(2 * np.pi * f * 5.95 * t) * np.exp(-t / 0.05)
         + 0.08 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / 0.3))
    click = onepole(rng.standard_normal(len(t)), 3000) * np.exp(-t / 0.003) * 0.6
    return (x + click) * adsr(len(t), 0.002, 0.2)


def inst_marimba(f, dur, rng):
    t = t_axis(1.8)
    x = (np.sin(2 * np.pi * f * t) * np.exp(-t / 0.55)
         + 0.28 * np.sin(2 * np.pi * f * 3.99 * t) * np.exp(-t / 0.09)
         + 0.06 * np.sin(2 * np.pi * f * 9.9 * t) * np.exp(-t / 0.02))
    return x * adsr(len(t), 0.003, 0.2)


def inst_pluck(f, dur, rng, bright=0.45):
    """Plucked string, additive so it stays in tune: harp or nylon guitar."""
    t = t_axis(max(2.4, dur))
    x = np.zeros(len(t))
    for k in range(1, 14):
        if f * k > SR * 0.45:
            break
        amp = np.sin(np.pi * k * bright) / k ** 1.1
        tau = 1.4 / k ** 0.8
        x += amp * np.sin(2 * np.pi * f * k * (1 + 0.0004 * k) * t) * np.exp(-t / tau)
    return x / 1.4 * adsr(len(t), 0.002, 0.25)


def inst_flute(f, dur, rng, breath=0.05, vib_rate=5.0):
    t = t_axis(dur + 0.35)
    vib = 1 + 0.004 * np.sin(2 * np.pi * vib_rate * t) * np.clip((t - 0.25) / 0.4, 0, 1)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    tone = np.sin(ph) + 0.12 * np.sin(2 * ph) + 0.05 * np.sin(3 * ph)
    noise = rng.standard_normal(len(t))
    air = onepole(noise - onepole(noise, 600), 2500) * breath * 4
    chiff = onepole(noise, 4000) * np.exp(-t / 0.03) * 0.25
    return (tone + air + chiff) * adsr(len(t), 0.09, 0.3)


def inst_ney(f, dur, rng):
    return inst_flute(f, dur, rng, breath=0.11, vib_rate=4.2)


def inst_pad(f, dur, rng, attack=1.6, release=2.2, bright=1.0):
    t = t_axis(dur + release)
    x = np.zeros(len(t))
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * t + rng.uniform(0, 6))
    for cents in (-6, 0, 6):
        ff = f * 2 ** (cents / 1200)
        ph0 = rng.uniform(0, 2 * np.pi)
        for k in range(1, 7):
            if ff * k > 5000:
                break
            amp = 1 / k ** 2.2 * (1 if k == 1 else bright * (0.6 + 0.4 * lfo))
            x += amp * np.sin(2 * np.pi * ff * k * t + ph0 * k)
    return x / 3 * adsr(len(t), attack, release)


def inst_choir(f, dur, rng):
    """Soft 'aah' pad: harmonics weighted toward vowel formants."""
    t = t_axis(dur + 2.0)
    x = np.zeros(len(t))
    for cents in (-8, 0, 7):
        ff = f * 2 ** (cents / 1200)
        vib = 1 + 0.003 * np.sin(2 * np.pi * rng.uniform(4.5, 5.5) * t)
        ph = 2 * np.pi * ff * np.cumsum(vib) / SR
        for k in range(1, 16):
            fk = ff * k
            if fk > 4500:
                break
            w = 0.25 / k ** 2 + np.exp(-((fk - 750) / 260) ** 2) + 0.5 * np.exp(-((fk - 1150) / 320) ** 2)
            x += w * np.sin(k * ph)
    return x / 4 * adsr(len(t), 1.4, 2.0)


def inst_bass(f, dur, rng):
    t = t_axis(dur + 0.4)
    x = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.4)
    return x * adsr(len(t), 0.03, 0.4)


def inst_pluck_bass(f, dur, rng):
    return inst_pluck(f, dur, rng, bright=0.3)


INSTRUMENTS = {
    "glass": inst_glass, "kalimba": inst_kalimba, "marimba": inst_marimba,
    "pluck": inst_pluck, "flute": inst_flute, "ney": inst_ney,
    "pad": inst_pad, "choir": inst_choir, "bass": inst_bass, "pluck_bass": inst_pluck_bass,
}


# ───────────────────────────── percussion ─────────────────────────────

def drum_shaker(rng):
    t = t_axis(0.09)
    n = rng.standard_normal(len(t))
    hp = n - onepole(n, 5000)
    return hp * (1 - np.exp(-t / 0.006)) * np.exp(-t / 0.025) * 0.8


def drum_hand(rng, low=False):
    t = t_axis(0.5)
    f = (95 if low else 165) * (1 + 0.6 * np.exp(-t / 0.02))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (0.22 if low else 0.13))
    slap = onepole(rng.standard_normal(len(t)), 2500) * np.exp(-t / 0.01) * 0.35
    return (body + slap) * adsr(len(t), 0.001, 0.05)


def drum_frame(rng):
    t = t_axis(0.9)
    f = 62 * (1 + 0.5 * np.exp(-t / 0.03))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.35)
    skin = onepole(rng.standard_normal(len(t)), 900) * np.exp(-t / 0.05) * 0.5
    return (body + skin) * adsr(len(t), 0.002, 0.1)


def drum_taiko(rng):
    t = t_axis(1.2)
    f = 52 * (1 + 0.9 * np.exp(-t / 0.025))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.42)
    skin = onepole(rng.standard_normal(len(t)), 1400) * np.exp(-t / 0.04) * 0.6
    return np.tanh(1.5 * (body + skin)) * adsr(len(t), 0.002, 0.1)


def drum_tick(rng):
    t = t_axis(0.12)
    return (np.sin(2 * np.pi * 1750 * t) * np.exp(-t / 0.012) + 0.4 * np.sin(2 * np.pi * 2900 * t) * np.exp(-t / 0.006))


DRUMS = {"shaker": drum_shaker, "hand": drum_hand, "hand_low": lambda r: drum_hand(r, True),
         "frame": drum_frame, "taiko": drum_taiko, "tick": drum_tick}


# ───────────────────────────── mixing helpers ─────────────────────────────

class Bus:
    def __init__(self, n):
        self.n = n
        self.buf = np.zeros((2, n))

    def add(self, x, start_s, gain=1.0, pan=0.0):
        """Wraps past the end so note tails ring into the loop start."""
        s = int(start_s * SR) % self.n
        ang = (pan + 1) * np.pi / 4
        lg, rg = np.cos(ang) * gain, np.sin(ang) * gain
        pos = 0
        while pos < len(x):
            chunk = x[pos:pos + self.n - s]
            self.buf[0, s:s + len(chunk)] += chunk * lg
            self.buf[1, s:s + len(chunk)] += chunk * rg
            pos += len(chunk)
            s = 0


def circular_reverb(stereo, seconds=2.6, mix=0.3, rng=None, dark=3500):
    """Convolution with decaying noise, done circularly so loops stay seamless."""
    n = stereo.shape[1]
    out = np.zeros_like(stereo)
    t = t_axis(min(seconds * 1.6, n / SR * 0.9))
    tau = seconds / 6.9
    pre = int(0.022 * SR)
    for ch in range(2):
        ir = rng.standard_normal(len(t)) * np.exp(-t / tau)
        # Darker as it decays: blend a heavily filtered copy in over time
        ir = onepole(ir, dark) * np.exp(-t / (tau * 1.5)) + onepole(ir, dark / 4) * (1 - np.exp(-t / (tau * 1.5)))
        ir = np.concatenate([np.zeros(pre), ir])
        ir /= np.sqrt(np.sum(ir ** 2))
        padded = np.zeros(n)
        padded[: len(ir)] = ir
        wet = np.fft.irfft(np.fft.rfft(stereo[ch]) * np.fft.rfft(padded), n)
        out[ch] = stereo[ch] * (1 - mix) + wet * mix * 1.6
    return out


def circular_delay(stereo, delay_s, feedback=0.35, mix=0.25, taps=5):
    """Ping-pong echo that wraps around the loop."""
    n = stereo.shape[1]
    d = int(delay_s * SR)
    mono = stereo.mean(axis=0)
    wet = np.zeros_like(stereo)
    g = 1.0
    for k in range(1, taps + 1):
        g *= feedback
        wet[k % 2] += np.roll(onepole(mono, 4000 - 400 * k), d * k) * g
    return stereo + wet * mix / feedback


def write_ogg(path, stereo, quality=4):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_path = tmp.name
    with wave.open(tmp_path, "w") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp_path, "-c:a", "libvorbis",
                    "-q:a", str(quality), path], check=True)
    os.remove(tmp_path)
    print(f"  wrote {path}  {stereo.shape[1] / SR:.1f}s  {os.path.getsize(path) // 1024} KB")


# ───────────────────────────── composition ─────────────────────────────

def harmonise(mode, bars, rng):
    """Pick one chord per bar that fits the melody best in this mode."""
    sc = MODES[mode]
    chords = []
    prev = None
    for b, bar in enumerate(bars):
        if b == 0 or b == len(bars) - 1:
            chords.append(0)
            prev = 0
            continue
        best, best_score = 0, -99
        for c in GOOD_CHORDS[mode]:
            tones = {sc[(c + i) % 7] for i in (0, 2, 4)}
            colour = {sc[(c + i) % 7] for i in (6, 8)}
            score = 0.0
            for deg, beats in bar:
                if deg is None:
                    continue
                pc = sc[deg % 7]
                if pc in tones:
                    score += beats
                elif pc in colour:
                    score += beats * 0.4
                if any((pc - tt) % 12 == 1 for tt in tones):
                    score -= beats * 1.2
            if c == prev:
                score -= 0.6
            score += rng.uniform(0, 0.05)
            if score > best_score:
                best, best_score = c, score
        chords.append(best)
        prev = best
    return chords


def chord_voicing(c, mode, root):
    """Root low, then fifth, ninth (if it doesn't clash) and tenth on top."""
    sc = MODES[mode]
    r = deg_to_midi(c, mode, root - 12)
    notes = [r, deg_to_midi(c + 4, mode, root - 12), deg_to_midi(c + 9, mode, root - 12)]
    ninth = deg_to_midi(c + 8, mode, root - 12)
    if (ninth - r) % 12 == 2:
        notes.append(ninth)
    notes.append(deg_to_midi(c + 11, mode, root - 12))
    return notes


def render(cfg):
    rng = np.random.default_rng(cfg["seed"])
    mode, root, bpm = cfg["mode"], cfg["root"], cfg["bpm"]
    beat = 60.0 / bpm
    bar_s = beat * 4
    theme = cfg.get("theme", THEME)
    form = cfg["form"]  # list of section letters, each 8 bars (or len(theme))
    sec_bars = len(theme)
    total_bars = len(form) * sec_bars
    n = int(round(total_bars * bar_s * SR))
    bus = Bus(n)
    lead_bus = Bus(n)
    chords = cfg.get("chords") or harmonise(mode, theme, rng)

    for si, sec in enumerate(form):
        for b in range(sec_bars):
            bar_start = (si * sec_bars + b) * bar_s
            c = chords[b]
            voicing = chord_voicing(c, mode, root)
            # Pad
            for k, note in enumerate(voicing[1:]):
                x = INSTRUMENTS[cfg["pad"]](midi_hz(note), bar_s + 0.3, rng)
                bus.add(x, bar_start, cfg.get("pad_gain", 0.12), pan=(-0.5 + k * 0.33))
            # Bass on the root
            bpat = cfg.get("bass_pattern", [(0, 4)])
            for off, length in bpat:
                x = INSTRUMENTS[cfg["bass"]](midi_hz(voicing[0] - 12), length * beat, rng)
                bus.add(x, bar_start + off * beat, cfg.get("bass_gain", 0.35))
            # Melody
            if sec in ("A", "C"):
                inst = cfg["lead"] if sec == "A" else cfg.get("lead2", cfg["lead"])
                octave = 0 if sec == "A" else cfg.get("lead2_octave", 12)
                pos = 0.0
                for deg, beats in theme[b]:
                    if deg is not None:
                        f = midi_hz(deg_to_midi(deg, mode, root) + octave)
                        jitter = rng.uniform(-0.012, 0.012)
                        x = INSTRUMENTS[inst](f, beats * beat, rng)
                        g = cfg.get("lead_gain", 0.3) * rng.uniform(0.85, 1.0)
                        lead_bus.add(x, bar_start + pos * beat + max(0, jitter), g, pan=cfg.get("lead_pan", 0.1))
                    pos += beats
            # Generative arpeggio from chord tones
            arp_density = cfg["arp_density"].get(sec, 0)
            steps = cfg.get("arp_steps", 8)
            if arp_density > 0:
                tones = sorted(set(voicing[1:] + [v + 12 for v in voicing[1:]]))
                tones = [t + cfg.get("arp_octave", 12) for t in tones]
                idx = rng.integers(0, len(tones))
                for s in range(steps):
                    if rng.random() > arp_density:
                        continue
                    idx = int(np.clip(idx + rng.choice([-2, -1, 1, 1, 2]), 0, len(tones) - 1))
                    x = INSTRUMENTS[cfg["arp"]](midi_hz(tones[idx]), beat * 4 / steps, rng)
                    pan = rng.uniform(-0.7, 0.7)
                    bus.add(x, bar_start + s * bar_s / steps + rng.uniform(0, 0.008),
                            cfg.get("arp_gain", 0.12) * rng.uniform(0.6, 1.0), pan)
            # Percussion: 16 steps a bar, 'x' loud, 'o' soft
            for drum, sections, pattern, gain in cfg.get("drums", []):
                if sec not in sections:
                    continue
                for s, ch in enumerate(pattern):
                    if ch == ".":
                        continue
                    v = 1.0 if ch == "x" else 0.55
                    x = DRUMS[drum](rng)
                    bus.add(x, bar_start + s * bar_s / 16 + rng.uniform(0, 0.006), gain * v * rng.uniform(0.85, 1.0),
                            pan=rng.uniform(-0.25, 0.25))

    # Textures across the whole loop
    seconds = n / SR
    for kind, amount in cfg.get("textures", {}).items():
        add_texture(bus, kind, amount, seconds, rng)

    lead = lead_bus.buf
    if cfg.get("echo"):
        lead = circular_delay(lead, beat * 0.75, mix=cfg["echo"])
    mix = bus.buf + lead
    mix = circular_reverb(mix, cfg.get("reverb", 2.6), cfg.get("wet", 0.3), rng)
    # Phone speakers can't play deep bass: tame the lows (-6 dB shelf under
    # ~120 Hz) and set the level from what a phone can play (above 150 Hz)
    for ch in range(2):
        mix[ch] -= onepole(mix[ch], 120) * 0.5
        mix[ch] -= onepole(mix[ch], 30)
    audible = mix - np.stack([onepole(mix[0], 150), onepole(mix[1], 150)])
    rms = np.sqrt(np.mean(audible ** 2))
    mix = mix / rms * 0.13
    mix = np.tanh(mix * 1.4) / 1.4
    return mix


def add_texture(bus, kind, amount, seconds, rng):
    n = bus.n
    if kind == "bubbles":
        for _ in range(int(seconds * amount)):
            bt = t_axis(rng.uniform(0.03, 0.08))
            f0 = rng.uniform(500, 1400)
            x = np.sin(2 * np.pi * (f0 + f0 * 2.5 * bt / bt[-1]) * bt) * adsr(len(bt), 0.004, 0.03)
            bus.add(x, rng.uniform(0, seconds), 0.035, rng.uniform(-0.8, 0.8))
    elif kind == "drops":
        for _ in range(int(seconds * amount)):
            dt = t_axis(0.25)
            f0 = rng.uniform(900, 1800)
            x = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 0.7 * np.exp(-dt / 0.02))) / SR) * np.exp(-dt / 0.06)
            bus.add(x, rng.uniform(0, seconds), 0.04, rng.uniform(-0.9, 0.9))
    elif kind == "sea":
        x = onepole(rng.standard_normal(n), 300)
        swell = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(n) / n * 5)
        bus.buf += np.stack([x * swell, np.roll(x, n // 3) * swell]) * amount
    elif kind == "wind":
        x = rng.standard_normal(n)
        lfo = 0.5 + 0.5 * np.sin(2 * np.pi * np.arange(n) / n * 4 + 1.0)
        band = onepole(x, 900) - onepole(x, 250)
        bus.buf += np.stack([band * lfo, np.roll(band, n // 2) * (1 - lfo * 0.6)]) * amount
    elif kind == "insects":
        # Cricket-like chirp trains, far off
        for _ in range(int(seconds * amount)):
            dur = rng.uniform(0.3, 0.9)
            ct = t_axis(dur)
            f = rng.uniform(4200, 5600)
            am = (np.sin(2 * np.pi * rng.uniform(28, 45) * ct) > 0.3).astype(float)
            x = np.sin(2 * np.pi * f * ct) * onepole(am, 400) * adsr(len(ct), 0.05, 0.1)
            bus.add(x, rng.uniform(0, seconds), 0.018, rng.uniform(-0.9, 0.9))
    elif kind == "whale":
        for _ in range(int(max(1, seconds * amount))):
            wt = t_axis(rng.uniform(2.5, 4.0))
            u = wt / wt[-1]
            f = 180 + 160 * np.sin(np.pi * u) ** 2 - 60 * u
            ph = 2 * np.pi * np.cumsum(f) / SR
            x = (np.sin(ph) + 0.3 * np.sin(2 * ph)) * np.sin(np.pi * u) ** 2
            bus.add(onepole(x, 1200), rng.uniform(0, seconds), 0.05, rng.uniform(-0.5, 0.5))


# ───────────────────────────── track list ─────────────────────────────

TRACKS = {
    "title": dict(mode="ionian", root=74, bpm=62, seed=3, form=["A", "B", "C"],
                  lead="glass", lead2="flute", lead2_octave=-12, pad="pad", bass="bass", arp="glass",
                  arp_density={"A": 0.15, "B": 0.35, "C": 0.2}, arp_steps=8, arp_gain=0.06,
                  lead_gain=0.32, echo=0.35, textures={"sea": 0.05, "bubbles": 0.4}, reverb=3.2, wet=0.38),
    "ediacaran": dict(mode="lydian", root=74, bpm=56, seed=11, form=["A", "B", "C"],
                      lead="glass", lead2="glass", lead2_octave=12, pad="pad", bass="bass", arp="glass",
                      arp_density={"A": 0.12, "B": 0.3, "C": 0.15}, arp_steps=8, arp_gain=0.05,
                      lead_gain=0.3, echo=0.4, textures={"sea": 0.06, "drops": 0.5, "bubbles": 0.6},
                      reverb=3.4, wet=0.4),
    "cambrian": dict(mode="ionian", root=67, bpm=84, seed=23, form=["A", "B", "C"],
                     lead="kalimba", lead2="glass", lead2_octave=12, pad="pad", bass="pluck_bass", arp="kalimba",
                     bass_pattern=[(0, 1.5), (1.5, 1), (2.5, 1.5)],
                     arp_density={"A": 0.4, "B": 0.75, "C": 0.55}, arp_steps=8, arp_gain=0.1, arp_octave=12,
                     lead_gain=0.4, echo=0.3, pad_gain=0.09,
                     drums=[("shaker", "ABC", "x.o.x.o.x.o.x.oo", 0.12), ("tick", "BC", "....x.......x...", 0.06)],
                     textures={"sea": 0.03, "bubbles": 1.0}, reverb=2.4, wet=0.3),
    "ordovician": dict(mode="dorian", root=69, bpm=68, seed=31, form=["A", "B", "C"],
                       lead="flute", lead2="flute", lead2_octave=12, pad="choir", bass="bass", arp="marimba", bass_gain=0.22,
                       arp_density={"A": 0.35, "B": 0.6, "C": 0.4}, arp_steps=8, arp_gain=0.11, arp_octave=0,
                       lead_gain=0.26, echo=0.25, pad_gain=0.1,
                       drums=[("hand_low", "BC", "x.......o.......", 0.18)],
                       textures={"sea": 0.07, "whale": 0.03, "bubbles": 0.4}, reverb=3.6, wet=0.38),
    "carboniferous": dict(mode="mixolydian", root=64, bpm=92, seed=43, form=["A", "B", "C"],
                          lead="pluck", lead2="flute", lead2_octave=12, pad="pad", bass="pluck_bass", arp="pluck",
                          bass_pattern=[(0, 1.5), (1.5, 0.5), (2, 2)],
                          arp_density={"A": 0.45, "B": 0.7, "C": 0.5}, arp_steps=16, arp_gain=0.07, arp_octave=12,
                          lead_gain=0.4, echo=0.2, pad_gain=0.08,
                          drums=[("hand", "ABC", "x..o..x.o.x..o..", 0.2), ("hand_low", "ABC", "x.......x.....o.", 0.22),
                                 ("shaker", "BC", "o.o.o.o.o.o.o.o.", 0.07)],
                          textures={"insects": 0.6, "drops": 0.3}, reverb=2.0, wet=0.26),
    "permian": dict(mode="aeolian", root=62, bpm=64, seed=53, form=["A", "B", "C"],
                    lead="ney", lead2="ney", lead2_octave=12, pad="pad", bass="pluck_bass", arp="pluck",
                    arp_density={"A": 0.2, "B": 0.4, "C": 0.25}, arp_steps=8, arp_gain=0.09, arp_octave=0,
                    lead_gain=0.3, echo=0.3, pad_gain=0.1,
                    drums=[("frame", "ABC", "x.........o.....", 0.3)],
                    textures={"wind": 0.05}, reverb=2.8, wet=0.32),
}

# Boss fights: first half of the theme in minor, ostinato and drums
BOSS_THEME = [THEME[0], THEME[1], THEME[2], THEME[3]]
BOSS_ERAS = {
    "ediacaran": ("glass", "glass", 62, "phrygian"),
    "cambrian": ("kalimba", "marimba", 67, "harmonic"),
    "ordovician": ("flute", "marimba", 69, "phrygian"),
    "carboniferous": ("pluck", "pluck", 64, "harmonic"),
    "permian": ("ney", "pluck", 62, "harmonic"),
}
for era, (lead, arp, root, mode) in BOSS_ERAS.items():
    TRACKS["boss_" + era] = dict(
        mode=mode, root=root, bpm=112, theme=BOSS_THEME, form=["B", "A", "B", "C"],
        lead=lead, lead2=lead, lead2_octave=12, pad="pad", bass="pluck_bass", arp=arp,
        bass_pattern=[(0, 0.5), (0.75, 0.5), (1.5, 0.5), (2, 0.5), (2.75, 0.5), (3.5, 0.5)],
        arp_density={"A": 0.7, "B": 0.85, "C": 0.8}, arp_steps=16, arp_gain=0.07, arp_octave=0,
        lead_gain=0.38, pad_gain=0.08, bass_gain=0.4,
        drums=[("taiko", "ABC", "x.....x...x.....", 0.3), ("hand", "ABC", "..o...o...o.o.oo", 0.16),
               ("shaker", "BC", "o.o.o.o.o.o.o.o.", 0.06)],
        textures={"sea": 0.03} if era in ("ediacaran", "cambrian", "ordovician") else {"wind": 0.03},
        reverb=2.2, wet=0.24)
# hash() of a str changes between runs; keep boss seeds stable
for i, era in enumerate(BOSS_ERAS):
    TRACKS["boss_" + era]["seed"] = 101 + i * 7
    TRACKS["boss_" + era]["chords"] = BOSS_PROGRESSIONS[BOSS_ERAS[era][3]]
for name, cfg in TRACKS.items():
    if "theme" not in cfg:
        cfg["chords"] = PROGRESSIONS[cfg["mode"]]


def main(names):
    for name in names or TRACKS:
        print(name)
        write_ogg(f"assets/music/{name}.ogg", render(TRACKS[name]))


if __name__ == "__main__":
    main(sys.argv[1:])
