import os
import wave
import struct
import math
import random

SAMPLE_RATE = 44100

def create_sfx_dir():
    os.makedirs("assets/sfx", exist_ok=True)

def write_wav(filename, samples):
    filepath = os.path.join("assets/sfx", filename)
    with wave.open(filepath, "w") as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        for s in samples:
            # Clamp to 16-bit signed integer range
            clamped = max(-32767, min(32767, int(s * 32767)))
            data = struct.pack("<h", clamped)
            wav_file.writeframesraw(data)
    print(f"Generated: {filepath}")

def generate_shoot():
    # Wet bio-plasma spit: fast downward frequency chirp with noise burst
    duration = 0.12
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 800 * (1.0 - progress * 0.7) + math.sin(t * 120) * 100
        env = (1.0 - progress) ** 1.5
        noise = (random.random() * 2.0 - 1.0) * 0.15
        val = (math.sin(2 * math.pi * freq * t) + noise) * env * 0.6
        samples.append(val)
    write_wav("shoot.wav", samples)

def generate_hit():
    # Squishy flesh impact
    duration = 0.1
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 240 * (1.0 - progress * 0.8)
        env = (1.0 - progress) ** 2
        noise = (random.random() * 2.0 - 1.0) * 0.35
        val = (math.sin(2 * math.pi * freq * t) * 0.6 + noise * 0.4) * env * 0.7
        samples.append(val)
    write_wav("hit.wav", samples)

def generate_enemy_die():
    # Gooey burst
    duration = 0.25
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 350 * (1.0 - progress * 0.85) + math.sin(t * 80) * 40
        env = (1.0 - progress) ** 1.8
        noise = (random.random() * 2.0 - 1.0) * (0.4 * (1.0 - progress))
        val = (math.sin(2 * math.pi * freq * t) * 0.5 + noise) * env * 0.75
        samples.append(val)
    write_wav("enemy_die.wav", samples)

def generate_dna_pickup():
    # Bright upward crystal arpeggio (C5 -> E5 -> G5 -> C6)
    notes = [523.25, 659.25, 783.99, 1046.50]
    note_dur = 0.04
    samples = []
    for note in notes:
        n_samples = int(SAMPLE_RATE * note_dur)
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            progress = i / n_samples
            env = 1.0 - progress * 0.6
            # Sine with overtone
            val = (math.sin(2 * math.pi * note * t) * 0.7 + math.sin(4 * math.pi * note * t) * 0.3) * env * 0.5
            samples.append(val)
    # Add a little ringing tail
    tail_samples = int(SAMPLE_RATE * 0.1)
    for i in range(tail_samples):
        t = (len(samples)) / SAMPLE_RATE
        progress = i / tail_samples
        env = (1.0 - progress) ** 2
        val = math.sin(2 * math.pi * 1046.50 * t) * env * 0.3
        samples.append(val)
    write_wav("dna_pickup.wav", samples)

def generate_heart_pickup():
    # Warm two-tone chime (F5 -> A5)
    notes = [698.46, 880.00]
    samples = []
    for note in notes:
        n_samples = int(SAMPLE_RATE * 0.09)
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            progress = i / n_samples
            env = 1.0 - progress * 0.5
            val = (math.sin(2 * math.pi * note * t) * 0.8 + math.sin(3 * math.pi * note * t) * 0.2) * env * 0.5
            samples.append(val)
    write_wav("heart_pickup.wav", samples)

def generate_door_open():
    # Low organic unseal / whoosh
    duration = 0.35
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 150 + progress * 250
        env = math.sin(progress * math.pi)
        noise = (random.random() * 2.0 - 1.0) * 0.2
        val = (math.sin(2 * math.pi * freq * t) + noise) * env * 0.6
        samples.append(val)
    write_wav("door_open.wav", samples)

def generate_player_hurt():
    # Ouch / squish sound
    duration = 0.18
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 450 * (1.0 - progress * 0.6)
        env = (1.0 - progress) ** 1.5
        noise = (random.random() * 2.0 - 1.0) * 0.25
        val = (math.sin(2 * math.pi * freq * t) * 0.6 + noise * 0.4) * env * 0.8
        samples.append(val)
    write_wav("player_hurt.wav", samples)

def generate_explosion():
    # Deep bass boom with crackle
    duration = 0.45
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 90 * (1.0 - progress * 0.7)
        env = (1.0 - progress) ** 1.6
        noise = (random.random() * 2.0 - 1.0) * 0.7 * env
        val = (math.sin(2 * math.pi * freq * t) * 0.5 * env + noise * 0.5) * 0.85
        samples.append(val)
    write_wav("explosion.wav", samples)

def generate_boss_roar():
    # Low rumbling guttural roar
    duration = 0.8
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        progress = i / num_samples
        freq = 70 + math.sin(t * 25) * 20 + (1.0 - progress) * 40
        env = math.sin(progress * math.pi) ** 0.8
        noise = (random.random() * 2.0 - 1.0) * 0.4
        val = (math.sin(2 * math.pi * freq * t) * 0.6 + noise * 0.4) * env * 0.9
        samples.append(val)
    write_wav("boss_roar.wav", samples)

def generate_level_up():
    # Evolution milestone fanfare
    notes = [440, 554.37, 659.25, 880, 1108.73]
    samples = []
    for idx, note in enumerate(notes):
        dur = 0.08 if idx < len(notes) - 1 else 0.35
        n_samples = int(SAMPLE_RATE * dur)
        for i in range(n_samples):
            t = i / SAMPLE_RATE
            progress = i / n_samples
            env = 1.0 - progress * (0.3 if idx < len(notes) - 1 else 0.8)
            val = (math.sin(2 * math.pi * note * t) * 0.7 + math.sin(3 * math.pi * note * t) * 0.2) * env * 0.6
            samples.append(val)
    write_wav("level_up.wav", samples)

if __name__ == "__main__":
    create_sfx_dir()
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
    print("All audio generated!")
