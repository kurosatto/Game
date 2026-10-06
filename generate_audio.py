import os
import wave
import struct
import math
import random

SAMPLE_RATE = 44100

# ─────────────────────────────────────────────────────────
# Design philosophy (publishable quality):
#   - All sounds normalized so no single sound clips or hurts ears
#   - Shoot: soft, wet, low-freq "ploop" with gentle high overtone
#   - Hit: satisfying but not harsh
#   - Enemy die: gooey pop with musical element
#   - Pickups: bright, pleasant micro-jingles
#   - Player hurt: short, clear, not ear-piercing
#   - Explosion: deep, punchy, with controlled noise
#   - Boss roar: cinematic low rumble (no harsh noise)
#   - Level up: euphoric ascending arpeggio
#   - Door open: organic whoosh, quiet
# ─────────────────────────────────────────────────────────

MASTER_VOLUME = 0.38   # Global ceiling — keeps all sounds gentle on the ears

def create_sfx_dir():
    os.makedirs("assets/sfx", exist_ok=True)

def write_wav(filename, samples, normalize=True):
    """Write samples to WAV. Optionally normalizes then applies MASTER_VOLUME."""
    if normalize and samples:
        peak = max(abs(s) for s in samples)
        if peak > 0:
            samples = [s / peak for s in samples]
    # Apply master volume ceiling
    samples = [s * MASTER_VOLUME for s in samples]

    filepath = os.path.join("assets/sfx", filename)
    with wave.open(filepath, "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        for s in samples:
            clamped = max(-32767, min(32767, int(s * 32767)))
            wav_file.writeframesraw(struct.pack("<h", clamped))
    print(f"  Generated: {filepath}")

def lerp(a, b, t):
    return a + (b - a) * t

def adsr_envelope(i, num_samples, attack=0.05, decay=0.1, sustain=0.65, release=0.3):
    """Standard ADSR envelope, returns 0..1."""
    t = i / num_samples
    attack_end   = attack
    decay_end    = attack + decay
    release_start = 1.0 - release

    if t < attack_end:
        return t / attack_end
    elif t < decay_end:
        return lerp(1.0, sustain, (t - attack_end) / decay)
    elif t < release_start:
        return sustain
    else:
        return sustain * (1.0 - (t - release_start) / release)

def sine(freq, t):
    return math.sin(2 * math.pi * freq * t)

def soft_noise(seed_i):
    """Bandlimited-ish noise using summed sines (less harsh than raw random)."""
    random.seed(seed_i)
    return (random.random() * 2.0 - 1.0)


# ─────────────────────────────────────────────────────────
# 1. SHOOT — soft organic "ploop" / wet bubble pop
#    Old: harsh 800Hz chirp at 0.6. New: low freq drop with breathy overtone.
# ─────────────────────────────────────────────────────────
def generate_shoot():
    duration = 0.14
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Frequency drops quickly from 260Hz → 90Hz (low, wet, not piercing)
        freq = 260.0 * math.exp(-p * 4.5)

        # Fast attack, quick exponential decay
        env = math.exp(-p * 10.0)

        # Primary tone: sine + slight harmonic warmth
        tone = sine(freq, t) * 0.65 + sine(freq * 1.5, t) * 0.25 + sine(freq * 2.0, t) * 0.10

        # Very subtle breath noise (not harsh — just adds wetness)
        noise = (random.random() * 2.0 - 1.0) * 0.08 * math.exp(-p * 15.0)

        # Gentle click transient at the very start (adds "pop" feel, <2ms)
        click = max(0.0, 1.0 - i / (SAMPLE_RATE * 0.002)) * 0.3

        samples.append((tone + noise + click) * env)

    write_wav("shoot.wav", samples)


# ─────────────────────────────────────────────────────────
# 2. HIT — satisfying soft "thwap" — enemy getting hit
# ─────────────────────────────────────────────────────────
def generate_hit():
    duration = 0.09
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Downward frequency sweep: punchy but short
        freq = 320.0 * math.exp(-p * 6.0) + 60.0

        env = math.exp(-p * 14.0)

        # Boxy thump tone
        tone = sine(freq, t) * 0.6 + sine(freq * 0.5, t) * 0.3

        # Tiny bit of filtered noise for impact texture
        noise = (random.random() * 2.0 - 1.0) * 0.18 * math.exp(-p * 20.0)

        samples.append((tone + noise) * env)

    write_wav("hit.wav", samples)


# ─────────────────────────────────────────────────────────
# 3. ENEMY DIE — gooey bubble-pop with a little musical ping
# ─────────────────────────────────────────────────────────
def generate_enemy_die():
    duration = 0.30
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Two-part: initial gooey thud + rising tonal ping
        # Part 1: gooey thud (0 → 0.12s)
        thud_env = max(0.0, math.exp(-p * 20.0))
        thud_freq = 200.0 * math.exp(-p * 8.0) + 50.0
        thud = (sine(thud_freq, t) * 0.5 + (random.random() * 2.0 - 1.0) * 0.3) * thud_env

        # Part 2: rising tonal ping (peaks at 0.05s, decays after)
        ping_env = max(0.0, p * 5.0) * math.exp(-p * 7.0)
        ping_freq = 440.0 + p * 220.0  # rises from A4 upward
        ping = sine(ping_freq, t) * 0.4 * ping_env

        samples.append(thud + ping)

    write_wav("enemy_die.wav", samples)


# ─────────────────────────────────────────────────────────
# 4. DNA PICKUP — bright, sparkly, ascending crystal arpeggio
#    Pleasant musical jingle — Cmaj pentatonic: C5 E5 G5 B5 C6
# ─────────────────────────────────────────────────────────
def generate_dna_pickup():
    # C major pentatonic ascending
    notes = [523.25, 659.25, 783.99, 987.77, 1046.50]
    note_dur = 0.038
    tail_dur = 0.14
    samples = []

    for idx, note in enumerate(notes):
        n = int(SAMPLE_RATE * note_dur)
        for i in range(n):
            t = (len(samples) + i) / SAMPLE_RATE
            p = i / n
            env = (1.0 - p * 0.5) * math.exp(-p * 2.0)
            # Bell-like timbre: fundamental + 2nd + 3rd harmonic
            val = (
                sine(note, t) * 0.60 +
                sine(note * 2.0, t) * 0.28 +
                sine(note * 3.0, t) * 0.12
            ) * env
            samples.append(val)

    # Ringing tail on the final note
    tail_n = int(SAMPLE_RATE * tail_dur)
    base_t_offset = len(samples) / SAMPLE_RATE
    for i in range(tail_n):
        t = base_t_offset + i / SAMPLE_RATE
        p = i / tail_n
        env = (1.0 - p) ** 2.0
        val = (
            sine(1046.50, t) * 0.55 +
            sine(1046.50 * 2.0, t) * 0.30 +
            sine(1046.50 * 3.0, t) * 0.15
        ) * env
        samples.append(val)

    write_wav("dna_pickup.wav", samples)


# ─────────────────────────────────────────────────────────
# 5. HEART PICKUP — warm, gentle two-note chime (F5 → A5)
# ─────────────────────────────────────────────────────────
def generate_heart_pickup():
    pairs = [(698.46, 0.10), (880.00, 0.18)]
    samples = []

    for freq, dur in pairs:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = (len(samples) + i) / SAMPLE_RATE
            p = i / n
            env = (1.0 - p * 0.4) * math.exp(-p * 3.0)
            # Soft warm timbre — sine + mellow 2nd harmonic
            val = (sine(freq, t) * 0.70 + sine(freq * 2.0, t) * 0.30) * env
            samples.append(val)

    # Short reverb-like tail
    tail_n = int(SAMPLE_RATE * 0.10)
    base_t = len(samples) / SAMPLE_RATE
    for i in range(tail_n):
        t = base_t + i / SAMPLE_RATE
        p = i / tail_n
        env = (1.0 - p) ** 3.0
        samples.append(sine(880.00, t) * env * 0.4)

    write_wav("heart_pickup.wav", samples)


# ─────────────────────────────────────────────────────────
# 6. DOOR OPEN — organic low swoosh / pressure release
# ─────────────────────────────────────────────────────────
def generate_door_open():
    duration = 0.40
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Frequency rises gently (unsealing pressure)
        freq = 80.0 + p * 160.0

        # Bell-shaped amplitude envelope (soft start & end)
        env = math.sin(p * math.pi) ** 1.4

        # Breathy noise whoosh (dominant component) — very filtered
        noise_raw = (random.random() * 2.0 - 1.0)
        # Simulate low-pass by mixing with previous value
        if i == 0:
            noise = noise_raw * 0.08
        else:
            noise = samples[-1] * 0.4 + noise_raw * 0.08

        # Gentle tonal undertone
        tone = sine(freq, t) * 0.25

        samples.append((tone + noise) * env)

    write_wav("door_open.wav", samples)


# ─────────────────────────────────────────────────────────
# 7. PLAYER HURT — short, clear organic "ouch" thud
#    Old: 450Hz at 0.8 amplitude — harsh. New: soft mid-low thud.
# ─────────────────────────────────────────────────────────
def generate_player_hurt():
    duration = 0.20
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Low thud: starts at 300Hz, drops to 100Hz
        freq = lerp(300.0, 100.0, min(1.0, p * 3.0))

        # Fast attack, gradual decay
        env = math.exp(-p * 8.5)

        # Rounded thud tone with subtle 2nd harmonic
        tone = sine(freq, t) * 0.65 + sine(freq * 0.5, t) * 0.20

        # Very quiet organic noise — just a touch for texture
        noise = (random.random() * 2.0 - 1.0) * 0.10 * math.exp(-p * 20.0)

        samples.append((tone + noise) * env)

    write_wav("player_hurt.wav", samples)


# ─────────────────────────────────────────────────────────
# 8. EXPLOSION — deep, punchy bomb boom with controlled tail
# ─────────────────────────────────────────────────────────
def generate_explosion():
    duration = 0.55
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    prev_noise = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Deep bass punch: starts at 110Hz, falls to 30Hz
        freq = lerp(110.0, 30.0, min(1.0, p * 2.5))

        # Fast attack punch, long exponential decay
        env_tone = math.exp(-p * 5.0)
        env_noise = math.exp(-p * 3.5)

        # Bass tone
        tone = (sine(freq, t) * 0.55 + sine(freq * 0.5, t) * 0.30 + sine(freq * 2.0, t) * 0.15) * env_tone

        # Low-pass filtered noise (run through a one-pole filter to avoid harshness)
        raw_noise = (random.random() * 2.0 - 1.0)
        lp_noise = prev_noise * 0.55 + raw_noise * 0.45
        prev_noise = lp_noise
        noise = lp_noise * env_noise * 0.45

        samples.append(tone + noise)

    write_wav("explosion.wav", samples)


# ─────────────────────────────────────────────────────────
# 9. BOSS ROAR — cinematic low rumble, no harsh noise
#    Layered sub-bass with slow tremolo and harmonic growl
# ─────────────────────────────────────────────────────────
def generate_boss_roar():
    duration = 1.0
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    prev_lp = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        p = i / num_samples

        # Base frequency with slight downward pitch bend
        base_freq = 55.0 + (1.0 - p) * 25.0

        # Slow tremolo / vibrato
        vibrato = math.sin(t * 8.0) * 3.0
        freq = base_freq + vibrato

        # Bell-shaped amplitude envelope with slow attack
        env = math.sin(p * math.pi) ** 0.6

        # Sub-bass foundation
        sub = sine(freq * 0.5, t) * 0.40

        # Growling harmonics
        growl = (
            sine(freq, t) * 0.35 +
            sine(freq * 2.0, t) * 0.15 +
            sine(freq * 3.0, t) * 0.07
        )

        # Very low-pass filtered rumble noise
        raw_noise = (random.random() * 2.0 - 1.0)
        lp_noise = prev_lp * 0.85 + raw_noise * 0.15
        prev_lp = lp_noise
        rumble = lp_noise * 0.15

        samples.append((sub + growl + rumble) * env)

    write_wav("boss_roar.wav", samples)


# ─────────────────────────────────────────────────────────
# 10. LEVEL UP — euphoric rising arpeggio fanfare
#     Bright, musical, not too long — Amaj: A4 C#5 E5 A5 E6
# ─────────────────────────────────────────────────────────
def generate_level_up():
    # A major pentatonic ascending with final sustained chord
    notes_steps = [
        (440.00, 0.07),   # A4
        (554.37, 0.07),   # C#5
        (659.25, 0.07),   # E5
        (880.00, 0.07),   # A5
        (1108.73, 0.07),  # C#6
        (1318.51, 0.30),  # E6 (sustained final)
    ]
    samples = []

    for freq, dur in notes_steps:
        n = int(SAMPLE_RATE * dur)
        is_last = (dur > 0.15)
        for i in range(n):
            t = (len(samples) + i) / SAMPLE_RATE
            p = i / n
            if is_last:
                env = (1.0 - p * 0.85) * math.exp(-p * 1.5)
            else:
                env = (1.0 - p * 0.35) * math.exp(-p * 2.0)
            val = (
                sine(freq, t) * 0.55 +
                sine(freq * 2.0, t) * 0.30 +
                sine(freq * 3.0, t) * 0.15
            ) * env
            samples.append(val)

    # Shimmering tail
    tail_n = int(SAMPLE_RATE * 0.25)
    base_t = len(samples) / SAMPLE_RATE
    for i in range(tail_n):
        t = base_t + i / SAMPLE_RATE
        p = i / tail_n
        env = (1.0 - p) ** 2.5
        val = (
            sine(1318.51, t) * 0.50 +
            sine(880.00, t) * 0.35 +
            sine(659.25, t) * 0.15
        ) * env
        samples.append(val)

    write_wav("level_up.wav", samples)


# ─────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────

if __name__ == "__main__":
    create_sfx_dir()
    print("\n=== Generating publishable-quality SFX ===")
    print("  Master volume ceiling:", MASTER_VOLUME, "(normalized & ear-safe)")
    print()

    generate_shoot()
    generate_hit()
    generate_enemy_die()
    generate_dna_pickup()
    generate_heart_pickup()
    generate_door_open()
    generate_player_hurt()
    generate_explosion()
    generate_boss_roar()
    generate_level_up()

    print("\nAll audio generated!")
