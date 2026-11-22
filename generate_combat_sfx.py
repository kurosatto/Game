"""Combat sound effects (numpy + scipy), all synthesised, nothing sampled.

Every attack style gets its own sound, every hit sounds like what it struck,
and kills crack, squelch or thump depending on the animal's body:

  assets/sfx/atk_<weapon>.wav   one per Lineages.WEAPONS entry (19)
  assets/sfx/hit_soft.wav       soft-bodied animal hit (wet squelch)
  assets/sfx/hit_shell.wav      exoskeleton or shell hit (chitin clack)
  assets/sfx/hit_flesh.wav      bony, scaly animal hit (dull thud)
  assets/sfx/hit_crit.wav       a signature move or crit lands (crunch)
  assets/sfx/hit_glance.wav     blow glances off armour or a rolled-up ball
  assets/sfx/parry.wav          melee swats an enemy shot out of the water
  assets/sfx/kill_soft.wav, kill_shell.wav, kill_flesh.wav
  assets/sfx/enemy_lunge.wav    an ambusher winds up to strike
  assets/sfx/enemy_spit.wav     an animal shoots at you
  assets/sfx/hurt_thud.wav      body blow layered under player_hurt

Deterministic (fixed seed). Run from the project root:
  python generate_combat_sfx.py
"""
import os
import wave

import numpy as np
from scipy.signal import butter, lfilter, sosfilt

RATE = 44100
OUT = "assets/sfx"
rng = np.random.default_rng(1729)


# ── building blocks ─────────────────────────────────────────────────────────

def n_of(sec):
    return int(sec * RATE)


def t_of(sec):
    return np.arange(n_of(sec)) / RATE


def noise(sec):
    return rng.standard_normal(n_of(sec))


def band(x, lo, hi, order=2):
    sos = butter(order, [lo, hi], btype="band", fs=RATE, output="sos")
    return sosfilt(sos, x)


def lowp(x, cut, order=2):
    sos = butter(order, cut, btype="low", fs=RATE, output="sos")
    return sosfilt(sos, x)


def highp(x, cut, order=2):
    sos = butter(order, cut, btype="high", fs=RATE, output="sos")
    return sosfilt(sos, x)


def env(sec, attack, decay, hold=0.0):
    """Linear attack, optional hold, exponential decay."""
    n = n_of(sec)
    e = np.zeros(n)
    a = max(1, n_of(attack))
    h = n_of(hold)
    e[:a] = np.linspace(0, 1, a)
    e[a:a + h] = 1.0
    rest = np.arange(max(0, n - a - h)) / RATE
    e[a + h:] = np.exp(-rest / max(decay, 1e-4))
    return e


def sweep(sec, f0, f1, curve=1.0, shape="sine"):
    """Oscillator gliding from f0 to f1 (curve > 1 drops fast early)."""
    t = t_of(sec)
    k = (t / max(sec, 1e-6)) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / RATE
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return np.sin(ph)


def swept_noise(sec, f0, f1, q=0.6, steps=24):
    """Noise through a band-pass whose centre glides f0 -> f1 (a whoosh)."""
    x = noise(sec)
    out = np.zeros_like(x)
    seg = len(x) // steps + 1
    win = np.hanning(seg * 2)
    for i in range(steps):
        fc = f0 * (f1 / f0) ** (i / max(1, steps - 1))
        lo, hi = max(40.0, fc * (1 - q / 2)), min(RATE / 2 - 100, fc * (1 + q / 2))
        y = band(x, lo, hi)
        s = max(0, i * seg - seg // 2)
        e = min(len(x), s + seg * 2)
        out[s:e] += y[s:e] * win[: e - s]
    return out


def click(sec=0.012, bright=4000.0):
    """A hard tick: a few ms of high-passed noise with a very fast decay."""
    x = highp(noise(sec), bright) * env(sec, 0.0003, sec / 5)
    return x


def ring(sec, freqs, decay, amps=None):
    """Struck resonance: a few decaying partials (shell, chitin, tooth)."""
    t = t_of(sec)
    out = np.zeros_like(t)
    amps = amps or [1.0] * len(freqs)
    for f, a in zip(freqs, amps):
        out += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / (decay * (1.2 - f / 20000)))
    return out


def thump(sec, f0, f1, decay):
    """Body impact: a sine that drops in pitch, like a fist into a cushion."""
    return sweep(sec, f0, f1, curve=0.35) * env(sec, 0.001, decay)


def bubbles(sec, count, lo=500.0, hi=1600.0, size=0.03):
    """Little rising pings scattered in time, the way bubbles pop in water."""
    out = np.zeros(n_of(sec))
    for _ in range(count):
        start = rng.integers(0, max(1, len(out) - n_of(size)))
        f = rng.uniform(lo, hi)
        b = sweep(size, f, f * 1.7, curve=0.6) * env(size, 0.002, size / 3)
        out[start:start + len(b)] += b * rng.uniform(0.4, 1.0)
    return out


def plus(*xs):
    """Sum buffers of different lengths, padding the shorter ones."""
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[: len(x)] += x
    return out


def mix(length_sec, *parts):
    """Sum (signal, offset_sec, gain) tuples into one buffer."""
    out = np.zeros(n_of(length_sec))
    for sig, at, gain in parts:
        s = n_of(at)
        e = min(len(out), s + len(sig))
        if e > s:
            out[s:e] += sig[: e - s] * gain
    return out


def finish(x, peak=0.5, fade=0.012):
    x = np.asarray(x, dtype=np.float64)
    x = highp(x, 35.0, 1)  # no DC thump through phone speakers
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    f = min(len(x), n_of(fade))
    x[-f:] *= np.linspace(1, 0, f)  # no click at the end
    x[:32] *= np.linspace(0, 1, 32)
    return x


def write(name, x, peak=0.5):
    x = finish(x, peak)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
    print(f"  {path:34s} {len(x) / RATE:.2f}s")


# ── attacks: one per weapon ─────────────────────────────────────────────────

def atk_vesicle():
    # Lysosome vesicle squeezed out of the membrane: a soft rising bloop
    L = 0.22
    body = sweep(L, 260, 720, curve=0.5) * env(L, 0.004, 0.06)
    wet = lowp(noise(L), 1200) * env(L, 0.002, 0.03)
    return mix(L, (body, 0, 1.0), (wet, 0, 0.25), (bubbles(0.15, 3, 900, 1800, 0.02), 0.03, 0.25))


def atk_jet():
    # Water squirted hard through a siphon: a pressurised psssht
    L = 0.3
    hiss = swept_noise(L, 3200, 1400, q=0.9) * env(L, 0.006, 0.09)
    gush = lowp(noise(L), 600) * env(L, 0.01, 0.07)
    return mix(L, (hiss, 0, 1.0), (gush, 0, 0.6), (thump(0.08, 160, 70, 0.03), 0, 0.5))


def atk_spit():
    # Spitting venom: lips part (click), then a short spray and a ptoo blip
    L = 0.2
    spray = band(noise(L), 2000, 6000) * env(L, 0.002, 0.04)
    blip = sweep(0.07, 900, 380, curve=0.5) * env(0.07, 0.001, 0.02)
    return mix(L, (click(0.01, 3000), 0, 0.7), (spray, 0.006, 0.8), (blip, 0.004, 0.8))


def atk_harpoon():
    # Cone snail harpoon: a tight fast thwip and a little twang of the tether
    L = 0.26
    zip_ = sweep(0.09, 2600, 500, curve=0.4) * env(0.09, 0.001, 0.03)
    air = swept_noise(0.12, 5000, 1500, q=0.5) * env(0.12, 0.002, 0.03)
    twang = sweep(L, 330, 300, shape="tri") * env(L, 0.002, 0.07) * (1 + 0.3 * np.sin(2 * np.pi * 18 * t_of(L)))
    return mix(L, (zip_, 0, 0.9), (air, 0, 0.6), (twang, 0.02, 0.35))


def atk_slime():
    # Velvet worm slime: a wet, sticky splorch with a quiver
    L = 0.3
    t = t_of(L)
    gloop = np.sin(2 * np.pi * np.cumsum(180 + 120 * np.sin(2 * np.pi * 22 * t)) / RATE) * env(L, 0.008, 0.07)
    wet = lowp(noise(L), 900) * env(L, 0.003, 0.05)
    return mix(L, (gloop, 0, 0.9), (wet, 0, 0.6), (bubbles(0.2, 4, 300, 900, 0.035), 0.04, 0.4))


def atk_silk():
    # Silk thrown: a thin rising zip with a fine hiss
    L = 0.24
    hiss = highp(noise(L), 5500) * env(L, 0.01, 0.06)
    zip_ = sweep(0.14, 1400, 4200, curve=1.6) * env(0.14, 0.01, 0.04)
    return mix(L, (hiss, 0, 0.8), (zip_, 0, 0.35))


def atk_spray():
    # Bombardier beetle: a hot chemical pop and a crackling boiling fizz
    L = 0.34
    pop = thump(0.06, 420, 140, 0.02)
    fizz = band(noise(L), 2500, 9000) * env(L, 0.003, 0.11)
    crackle = np.zeros(n_of(L))
    for _ in range(26):
        s = rng.integers(0, n_of(L * 0.8))
        c = click(0.004, 3500)
        crackle[s:s + len(c)] += c * rng.uniform(0.3, 1.0) * np.exp(-s / RATE / 0.12)
    return mix(L, (pop, 0, 1.0), (fizz, 0.004, 0.55), (crackle, 0.004, 0.8))


def atk_engulf():
    # Engulfing: the membrane flows out and sucks inward, a reversed gloop
    L = 0.36
    suck = swept_noise(L, 300, 1400, q=0.8)
    e = np.linspace(0, 1, n_of(L)) ** 2
    e[-n_of(0.06):] *= np.linspace(1, 0, n_of(0.06))
    body = sweep(L, 120, 260, curve=1.5) * e
    return mix(L, (suck * e, 0, 0.8), (body, 0, 0.7), (thump(0.08, 200, 80, 0.03), L - 0.07, 0.6))


def atk_clamp():
    # Brachiopod/clam shell snapping shut: castanet double-clack
    L = 0.2
    c1 = plus(click(0.012, 2500), ring(0.06, [1900, 3100], 0.012) * 0.4)
    c2 = plus(click(0.012, 2200), ring(0.08, [1500, 2600], 0.016) * 0.5)
    whoosh = swept_noise(0.07, 600, 1500) * env(0.07, 0.02, 0.02)
    return mix(L, (whoosh, 0, 0.4), (c1, 0.05, 0.9), (c2, 0.075, 1.0))


def atk_bite():
    # Jaws lunge (short whoosh) and slam shut: a bony chomp
    L = 0.26
    whoosh = swept_noise(0.1, 500, 1800, q=0.7) * env(0.1, 0.04, 0.03)
    chomp = thump(0.12, 210, 70, 0.04)
    teeth = plus(click(0.015, 1800), ring(0.05, [1200, 2300], 0.01) * 0.3)
    return mix(L, (whoosh, 0, 0.5), (chomp, 0.08, 1.0), (teeth, 0.08, 0.8))


def atk_rasp():
    # Radula grinding: a gritty buzzing scrape
    L = 0.3
    t = t_of(L)
    grit = band(noise(L), 1200, 5000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 34 * t))) * env(L, 0.01, 0.1)
    return mix(L, (grit, 0, 1.0), (click(0.01, 3000), 0, 0.4))


def atk_pincer():
    # Chelae snipping: a quick swish and a hard, ringing snip
    L = 0.22
    swish = swept_noise(0.08, 800, 2600) * env(0.08, 0.03, 0.02)
    snip = plus(click(0.01, 4000), ring(0.09, [2700, 4100, 5900], 0.012, [1, 0.6, 0.3]) * 0.6)
    return mix(L, (swish, 0, 0.5), (snip, 0.06, 1.0), (click(0.008, 5000), 0.075, 0.5))


def atk_claw():
    # A raking claw swipe: fast swept airy whoosh, three faint scrapes
    L = 0.26
    sw = swept_noise(0.2, 500, 3500, q=0.6) * env(0.2, 0.05, 0.05)
    out = mix(L, (sw, 0, 1.0))
    for i in range(3):
        out += mix(L, (band(noise(0.025), 3000, 7000) * env(0.025, 0.001, 0.007), 0.07 + i * 0.022, 0.35))
    return out


def atk_lash():
    # Tail or flagellum whip: building whoosh, then a sharp crack at the tip
    L = 0.3
    sw = swept_noise(0.17, 300, 2400, q=0.6)
    sw *= np.linspace(0, 1, len(sw)) ** 2
    crack = plus(click(0.02, 1500) * 1.5, highp(noise(0.05), 2000) * env(0.05, 0.0005, 0.01))
    return mix(L, (sw, 0, 0.7), (crack, 0.16, 1.0), (thump(0.06, 300, 120, 0.015), 0.16, 0.3))


def atk_sting():
    # A fast jab: short thin whoosh, a tight tick as the stinger lands
    L = 0.2
    jab = swept_noise(0.08, 1500, 5000, q=0.5) * env(0.08, 0.025, 0.02)
    tick = click(0.008, 6000)
    return mix(L, (jab, 0, 0.8), (tick, 0.07, 0.8), (sweep(0.04, 3000, 1800) * env(0.04, 0.001, 0.01), 0.07, 0.3))


def atk_arms():
    # Arms thrown out: stretchy rising sweep with a wet slap at full reach
    L = 0.32
    stretch = sweep(0.2, 180, 520, curve=0.7, shape="tri") * env(0.2, 0.03, 0.08)
    wet = swept_noise(0.2, 400, 1800) * env(0.2, 0.03, 0.06)
    slap = lowp(noise(0.05), 2500) * env(0.05, 0.001, 0.012)
    return mix(L, (stretch, 0, 0.5), (wet, 0, 0.5), (slap, 0.15, 0.9))


def atk_tongue():
    # Tongue flick: a quick thlup out and a plop on the way back
    L = 0.3
    out_ = sweep(0.1, 300, 1100, curve=0.6) * env(0.1, 0.01, 0.04)
    plop = sweep(0.06, 700, 250, curve=0.5) * env(0.06, 0.001, 0.02)
    wet = lowp(noise(0.12), 1500) * env(0.12, 0.005, 0.03)
    return mix(L, (out_, 0, 0.7), (wet, 0, 0.4), (plop, 0.17, 0.9))


def atk_spines():
    # Bristling: a rattling cluster of tiny dry clicks and a short whoosh
    L = 0.26
    out = mix(L, (swept_noise(0.12, 800, 3000) * env(0.12, 0.02, 0.04), 0, 0.5))
    for i in range(14):
        c = click(0.006, rng.uniform(3000, 6000))
        out += mix(L, (c, 0.02 + rng.uniform(0, 0.09), rng.uniform(0.3, 0.8)))
    return out


def atk_smash():
    # Mantis shrimp strike: whip-fast whoosh, a hard knock and the boom of a
    # cavitation bubble collapsing, then fizz
    L = 0.5
    sw = swept_noise(0.06, 800, 3500) * np.linspace(0, 1, n_of(0.06))
    knock = plus(click(0.015, 1200) * 1.4, thump(0.1, 260, 90, 0.03))
    boom = thump(0.35, 110, 38, 0.11)
    fizz = band(noise(0.3), 2500, 8000) * env(0.3, 0.005, 0.07)
    return mix(L, (sw, 0, 0.5), (knock, 0.055, 1.0), (boom, 0.12, 1.0), (click(0.01, 2000), 0.12, 0.8),
               (fizz, 0.13, 0.35), (bubbles(0.25, 6, 700, 2000, 0.025), 0.16, 0.25))


ATTACKS = {
    "vesicle": (atk_vesicle, 0.42), "jet": (atk_jet, 0.42), "spit": (atk_spit, 0.42),
    "harpoon": (atk_harpoon, 0.45), "slime": (atk_slime, 0.45), "silk": (atk_silk, 0.4),
    "spray": (atk_spray, 0.45), "engulf": (atk_engulf, 0.5), "clamp": (atk_clamp, 0.55),
    "bite": (atk_bite, 0.55), "rasp": (atk_rasp, 0.42), "pincer": (atk_pincer, 0.5),
    "claw": (atk_claw, 0.5), "lash": (atk_lash, 0.55), "sting": (atk_sting, 0.45),
    "arms": (atk_arms, 0.5), "tongue": (atk_tongue, 0.5), "spines": (atk_spines, 0.5),
    "smash": (atk_smash, 0.62),
}


# ── impacts and kills ──────────────────────────────────────────────────────

def hit_soft():
    L = 0.2
    squelch = lowp(noise(L), 1400) * env(L, 0.001, 0.035)
    body = thump(0.12, 240, 110, 0.035)
    return mix(L, (squelch, 0, 0.8), (body, 0, 0.8), (bubbles(0.1, 2, 500, 1100, 0.03), 0.02, 0.3))


def hit_shell():
    L = 0.18
    clack = click(0.01, 2500) * 1.3
    tone = ring(L, [1650, 2480, 3900], 0.02, [1, 0.6, 0.35])
    return mix(L, (clack, 0, 1.0), (tone, 0, 0.6), (thump(0.06, 300, 150, 0.015), 0, 0.4))


def hit_flesh():
    L = 0.2
    body = thump(0.16, 150, 55, 0.045)
    slap = lowp(noise(0.04), 3000) * env(0.04, 0.0005, 0.008)
    return mix(L, (body, 0, 1.0), (slap, 0, 0.6))


def hit_crit():
    # A big crunch: bone/shell giving way, with a bright ring on top
    L = 0.36
    crunch = np.zeros(n_of(L))
    for i in range(7):
        c = click(0.012, rng.uniform(1200, 3000))
        crunch += mix(L, (c, i * 0.011 + rng.uniform(0, 0.004), rng.uniform(0.5, 1.0)))
    body = thump(0.25, 180, 45, 0.07)
    shine = ring(L, [2200, 3300, 4950], 0.06, [1, 0.5, 0.3])
    return mix(L, (crunch, 0, 1.0), (body, 0, 1.0), (shine, 0.01, 0.25))


def hit_glance():
    # Bounces off armour: a dry tink, no body behind it
    L = 0.16
    return mix(L, (click(0.006, 5000), 0, 0.8), (ring(L, [3200, 4700], 0.025), 0, 0.6))


def parry():
    # An enemy shot swatted away: a quick flick and a wet pop
    L = 0.14
    pop = sweep(0.05, 1300, 600, curve=0.5) * env(0.05, 0.001, 0.015)
    return mix(L, (click(0.006, 4000), 0, 0.6), (pop, 0.004, 0.8))


def kill_soft():
    # Soft body bursts: wet splat, a gurgle and a spray of little bubbles
    L = 0.5
    splat = lowp(noise(0.25), 1800) * env(0.25, 0.002, 0.06)
    gurgle = sweep(0.3, 340, 120, curve=0.6) * env(0.3, 0.003, 0.08) * (1 + 0.5 * np.sin(2 * np.pi * 26 * t_of(0.3)))
    return mix(L, (splat, 0, 1.0), (thump(0.15, 200, 60, 0.05), 0, 0.8), (gurgle, 0.02, 0.45),
               (bubbles(0.4, 9, 500, 1800, 0.03), 0.04, 0.35))


def kill_shell():
    # Exoskeleton cracks apart: a run of crunches with chitin ringing
    L = 0.5
    out = np.zeros(n_of(L))
    for i in range(10):
        c = plus(click(0.014, rng.uniform(1000, 3200)), ring(0.05, [rng.uniform(1500, 3500)], 0.01) * 0.4)
        out += mix(L, (c, i * 0.018 + rng.uniform(0, 0.008), rng.uniform(0.4, 1.0) * (1 - i / 14)))
    return mix(L, (out, 0, 1.0), (thump(0.2, 170, 50, 0.06), 0, 0.9), (lowp(noise(0.2), 1200) * env(0.2, 0.002, 0.05), 0, 0.3))


def kill_flesh():
    # A heavy body goes down: deep thump, crunch, a soft exhale of air
    L = 0.55
    breath = band(noise(0.35), 300, 1400) * env(0.35, 0.03, 0.12)
    crunch = mix(0.1, (click(0.012, 1500), 0, 1.0), (click(0.012, 1800), 0.025, 0.7))
    return mix(L, (thump(0.35, 120, 40, 0.1), 0, 1.0), (crunch, 0, 0.6), (breath, 0.05, 0.35))


def enemy_lunge():
    # A predator rearing up: dry chittering rattle rising in pitch
    L = 0.4
    t = t_of(L)
    rate = 30 + 40 * t / L
    gate = (np.sin(2 * np.pi * np.cumsum(rate) / RATE) > 0.3).astype(float)
    chit = band(noise(L), 1800, 5500) * gate * np.linspace(0.4, 1.0, n_of(L)) * env(L, 0.05, 0.25)
    return mix(L, (chit, 0, 1.0), (sweep(L, 160, 260) * env(L, 0.08, 0.15), 0, 0.25))


def enemy_spit():
    # An animal spits at you: duller than the player's shots
    L = 0.18
    blip = sweep(0.08, 600, 260, curve=0.5) * env(0.08, 0.002, 0.025)
    spray = band(noise(0.1), 1200, 3500) * env(0.1, 0.002, 0.025)
    return mix(L, (blip, 0, 1.0), (spray, 0, 0.6))


def hurt_thud():
    # Taking a blow: a heavy body thump and a short crunch, felt more than heard
    L = 0.32
    return mix(L, (thump(0.3, 140, 42, 0.08), 0, 1.0), (click(0.015, 1200), 0, 0.5),
               (lowp(noise(0.08), 900) * env(0.08, 0.001, 0.02), 0, 0.5))


OTHERS = {
    "hit_soft": (hit_soft, 0.5), "hit_shell": (hit_shell, 0.5), "hit_flesh": (hit_flesh, 0.55),
    "hit_crit": (hit_crit, 0.6), "hit_glance": (hit_glance, 0.4), "parry": (parry, 0.42),
    "kill_soft": (kill_soft, 0.6), "kill_shell": (kill_shell, 0.6), "kill_flesh": (kill_flesh, 0.62),
    "enemy_lunge": (enemy_lunge, 0.42), "enemy_spit": (enemy_spit, 0.42), "hurt_thud": (hurt_thud, 0.62),
}


def main():
    for w, (fn, peak) in ATTACKS.items():
        write("atk_" + w, fn(), peak)
    for name, (fn, peak) in OTHERS.items():
        write(name, fn(), peak)


if __name__ == "__main__":
    main()
