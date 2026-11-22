"""Soft cues for the senses (numpy + scipy), played by SenseHints.gd when the
player's best non-visual sense first picks up an animal hidden in the dark.
Each sense has its own sound, quiet enough to sit under the music:

  assets/sfx/sense_smell.wav       two quick sniffs
  assets/sfx/sense_chemical.wav    a few tiny bubbly tastes
  assets/sfx/sense_electric.wav    a faint electric crackle
  assets/sfx/sense_lateral.wav     a low swell of pushed water
  assets/sfx/sense_vibration.wav   three soft footstep taps
  assets/sfx/sense_touch.wav       two light antenna taps

Reuses the building blocks of generate_combat_sfx.py. Run from the project root:
  python generate_sense_sfx.py
"""
import numpy as np

from generate_combat_sfx import (band, bubbles, click, env, highp, lowp, mix, noise,
                                 swept_noise, thump, t_of, write)


def sniff(sec):
    # Air drawn in through a nose: band-passed noise that swells then stops
    x = band(noise(sec), 1800, 5200)
    e = np.linspace(0, 1, len(x)) ** 1.5
    e[-int(len(e) * 0.15):] *= np.linspace(1, 0, int(len(e) * 0.15))
    return x * e


def smell():
    return mix(0.42, (sniff(0.11), 0.0, 1.0), (sniff(0.15), 0.17, 1.0))


def chemical():
    return mix(0.4, (bubbles(0.36, 4, 700, 1400, 0.04), 0.0, 1.0),
               (lowp(noise(0.3), 600) * env(0.3, 0.05, 0.08), 0.0, 0.25))


def electric():
    # A thin buzz at a heartbeat-ish pulse plus scattered crackles
    L = 0.4
    t = t_of(L)
    buzz = np.sign(np.sin(2 * np.pi * 120 * t)) * 0.3 + np.sin(2 * np.pi * 240 * t)
    buzz = band(buzz, 200, 2500) * env(L, 0.04, 0.12)
    out = mix(L, (buzz, 0, 0.5))
    for at in [0.02, 0.07, 0.11, 0.19, 0.26]:
        out = out + mix(L, (click(0.006, 3000), at, 0.6))
    return out


def lateral():
    # A pressure wave passing along the body: low whoosh, rising then fading
    x = lowp(swept_noise(0.55, 180, 520, q=0.8), 900)
    return x * env(0.55, 0.2, 0.12)


def vibration():
    return mix(0.45, (thump(0.08, 110, 60, 0.03), 0.0, 1.0),
               (thump(0.08, 120, 60, 0.03), 0.13, 0.8),
               (thump(0.08, 105, 60, 0.03), 0.26, 0.65))


def touch():
    tap = highp(click(0.01, 1500), 800)
    return mix(0.3, (tap, 0.0, 1.0), (tap, 0.12, 0.7))


SENSES = {
    "sense_smell": (smell, 0.4), "sense_chemical": (chemical, 0.38),
    "sense_electric": (electric, 0.35), "sense_lateral": (lateral, 0.45),
    "sense_vibration": (vibration, 0.5), "sense_touch": (touch, 0.35),
}


def main():
    for name, (fn, peak) in SENSES.items():
        write(name, fn(), peak)


if __name__ == "__main__":
    main()
