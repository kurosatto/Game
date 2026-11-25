"""Softens the combat sounds, which kuro found harsh (full-scale peaks and a
lot of hiss above 4 kHz), and can instead build them from CC0 OpenGameArt
recordings (sets A and B, credit the packs below if one is ever used).

    python3 tools/build_combat_sfx.py A        # bubbles and taps
    python3 tools/build_combat_sfx.py B        # squish and knock
    python3 generate_combat_sfx.py && python3 tools/build_combat_sfx.py C
                                               # the synth set, softened (in the game:
                                               # kuro picked it, 2026-11-25)
    python3 tools/build_combat_sfx.py A --out /tmp/setA   # build elsewhere

Downloads the packs listed in PACKS into ~/.cache/evo_sfx, then for every
sound: trims silence, cuts rumble under 180 Hz (phone speakers can't play it
anyway) and the harsh highs (gentle low-pass at 4.2 kHz plus a treble shelf),
fades the tail, matches loudness in the 300-3000 Hz band a phone speaker
does play, and keeps peaks under -3 dBFS. Hits and kills get extra takes
(name_2.wav, name_3.wav) that SoundManager picks between at random, so the
same knock doesn't repeat all fight long. Needs ffmpeg, numpy and py7zr.
"""
import os, sys, glob, json, wave, zipfile, subprocess, urllib.request
import numpy as np

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.expanduser("~/.cache/evo_sfx")
F = "https://opengameart.org/sites/default/files/"
PACKS = {  # folder in the cache: download (all CC0, see data/SoundCredits.gd)
    "water": F + "water-splash-slime-sfx.zip",
    "mud": F + "25-CC0-mud-sfx.zip",
    "creature": F + "80-CC0-creature-sfx-2.zip",
    "sfx100": F + "100-CC0-SFX_0.zip",
    "breaking": F + "sfx_breaking_and_falling.zip",
    "swish": F + "swishes.zip",
    "crunch": F + "crunch_-_tito.zip",
    "punch": F + "independent_nu_ljudbank-hits_and_punches.7z",
    "splat": F + "independent_nu_ljudbank-wet_squish_slurp_impacts.7z",
    "bubbles": [F + "bubbles-single1.wav", F + "bubbles-single2.wav", F + "bubbles-single3.wav"],
    "pops": [F + "pop1.ogg", F + "pop2.ogg", F + "pop3.ogg", F + "pop4.ogg", F + "pop5.ogg"],
    "bite": [F + "crunchybite_0.ogg"],
}

# name: source (or list of sources = takes). A source is "pack/file" or a
# dict with src plus pitch (playback rate), gain (dB) or lp (low-pass Hz).
SET_A = {  # bubbles and taps
    "atk_vesicle": "bubbles/bubbles-single1.wav", "atk_jet": "water/bubble_02.ogg",
    "atk_spit": "sfx100/plop_02.ogg", "atk_harpoon": "swish/swish-10.wav",
    "atk_slime": "water/slime_16.ogg", "atk_silk": "swish/swish-12.wav",
    "atk_spray": "bubbles/bubbles-single3.wav", "atk_engulf": "bubbles/bubbles-single2.wav",
    "atk_clamp": "sfx100/wooden_03.ogg", "atk_bite": "bite/crunchybite_0.ogg",
    "atk_rasp": "mud/mud_06.ogg", "atk_pincer": {"src": "sfx100/wooden_02.ogg", "pitch": 1.15},
    "atk_claw": "swish/swish-11.wav", "atk_lash": "swish/swish-13.wav",
    "atk_sting": {"src": "swish/swish-10.wav", "pitch": 1.2}, "atk_arms": "swish/swish-9.wav",
    "atk_tongue": {"src": "pops/pop1.ogg", "pitch": 0.8}, "atk_spines": "swish/swish-4.wav",
    "atk_smash": "sfx100/hit_04.ogg",
    "hit_soft": ["pops/pop1.ogg", "pops/pop2.ogg", "pops/pop4.ogg"],
    "hit_shell": ["sfx100/wooden_02.ogg", {"src": "sfx100/wooden_03.ogg", "pitch": 1.1}, "sfx100/hit_03.ogg"],
    "hit_flesh": ["mud/mud_08.ogg", "mud/mud_05.ogg", "mud/mud_12.ogg"],
    "hit_crit": "water/bubble_01.ogg",
    "hit_glance": {"src": "pops/pop3.ogg", "gain": -6}, "parry": "sfx100/wooden_03.ogg",
    "kill_soft": ["bubbles/bubbles-single2.wav", {"src": "bubbles/bubbles-single3.wav", "pitch": 0.85}],
    "kill_shell": ["breaking/bfh1_hit_06.ogg", "breaking/bfh1_misc_03.ogg"],
    "kill_flesh": ["mud/mud_19.ogg", "mud/mud_17.ogg"],
    "enemy_lunge": {"src": "swish/swish-5.wav", "gain": -4},
    "enemy_spit": {"src": "sfx100/plop_01.ogg", "gain": -4}, "hurt_thud": "mud/mud_04.ogg",
}
SET_B = {  # squish and knock
    "atk_vesicle": "water/slime_16.ogg", "atk_jet": "creature/slime_07.ogg",
    "atk_spit": "mud/mud_25.ogg", "atk_harpoon": "creature/misc_19.ogg",
    "atk_slime": "water/slime_15.ogg", "atk_silk": "creature/misc_20.ogg",
    "atk_spray": "water/splash_10.ogg", "atk_engulf": "creature/slime_08.ogg",
    "atk_clamp": "sfx100/hit_03.ogg", "atk_bite": {"src": "crunch/crunch.5.ogg", "lp": 3000},
    "atk_rasp": "mud/mud_13.ogg", "atk_pincer": "breaking/bfh1_hit_08.ogg",
    "atk_claw": "creature/misc_21.ogg", "atk_lash": "creature/misc_18.ogg",
    "atk_sting": "creature/attack_01.ogg", "atk_arms": "creature/slime_02.ogg",
    "atk_tongue": "water/slime_09.ogg", "atk_spines": "breaking/bfh1_wood_hit_03.ogg",
    "atk_smash": "punch/hit17.mp3.flac",
    "hit_soft": ["mud/mud_05.ogg", "mud/mud_13.ogg", "water/slime_15.ogg"],
    "hit_shell": ["breaking/bfh1_hit_08.ogg", "sfx100/hit_03.ogg", "sfx100/wooden_02.ogg"],
    "hit_flesh": ["punch/hit10.mp3.flac", "punch/hit23.mp3.flac", "punch/hit32.mp3.flac"],
    "hit_crit": "splat/impactsplat07.mp3.flac",
    "hit_glance": {"src": "sfx100/hit_03.ogg", "gain": -6}, "parry": "sfx100/wooden_02.ogg",
    "kill_soft": ["water/slime_09.ogg", "creature/slime_02.ogg"],
    "kill_shell": ["breaking/bfh1_misc_03.ogg", "breaking/bfh1_hit_06.ogg"],
    "kill_flesh": ["splat/impactsplat04.mp3.flac", "splat/impactsplat03.mp3.flac"],
    "enemy_lunge": {"src": "creature/misc_13.ogg", "gain": -4},
    "enemy_spit": {"src": "mud/mud_24.ogg", "gain": -4}, "hurt_thud": "punch/hit31.mp3.flac",
}
# C: the synthesised set, softened the same way. Run generate_combat_sfx.py
# first: it writes the originals into assets/sfx, which C then reworks in place
SET_C = {k: "synth/" + k + ".wav" for k in SET_A}
SETS = {"A": SET_A, "B": SET_B, "C": SET_C}

# (longest length in s, loudness target in dB on the phone band)
CAT = {"atk": (0.35, -27.0), "hit": (0.30, -20.5), "kill": (0.60, -19.5), "misc": (0.40, -23.5)}

def cat_of(name):
    if name.startswith("atk_"): return "atk"
    if name.startswith("kill_"): return "kill"
    if name.startswith("hit_") or name == "parry": return "hit"
    return "misc"

def fetch():
    for pack, url in PACKS.items():
        d = os.path.join(CACHE, pack)
        if os.path.isdir(d) and os.listdir(d):
            continue
        os.makedirs(d, exist_ok=True)
        for u in (url if isinstance(url, list) else [url]):
            dst = os.path.join(d, os.path.basename(u))
            urllib.request.urlretrieve(u, dst)
            if dst.endswith(".zip"):
                zipfile.ZipFile(dst).extractall(d)
            elif dst.endswith(".7z"):
                import py7zr
                py7zr.SevenZipFile(dst).extractall(d)

def find(src):
    pack, name = src.split("/", 1)
    if pack == "synth":
        return os.path.join(ROOT, "assets", "sfx", name)
    hits = [p for p in glob.glob(os.path.join(CACHE, pack, "**", name), recursive=True)
            if "__MACOSX" not in p]
    if not hits:
        sys.exit("missing source " + src)
    return hits[0]

def decode(path, filt):
    r = subprocess.run(["ffmpeg", "-v", "0", "-i", path, "-af", filt, "-ac", "1",
                        "-ar", str(SR), "-f", "f32le", "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).copy()

def phone_band(x):
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X[(f < 300) | (f > 3000)] = 0
    return np.fft.irfft(X, len(x))

def process(path, maxlen, target_db, lp=4200, pitch=1.0, gain_db=0.0):
    filt = "highpass=f=180:p=2,lowpass=f=%d:p=2,treble=g=-4:f=3000" % lp
    if pitch != 1.0:
        filt = "asetrate=%d,aresample=%d," % (int(SR * pitch), SR) + filt
    x = decode(path, filt)
    a = np.abs(x)
    idx = np.where(a > a.max() * 0.04)[0]
    x = x[max(0, idx[0] - int(0.004 * SR)):min(len(x), idx[-1] + int(0.02 * SR))]
    x = x[:int(maxlen * SR)]
    fade = min(int(0.06 * SR), len(x) // 3)
    x[-fade:] *= np.linspace(1, 0, fade) ** 2
    ramp = int(0.002 * SR)
    x[:ramp] *= np.linspace(0, 1, ramp)
    # loudness of the loud part (top 30% of 10 ms frames) on the phone band
    m = phone_band(x)
    fr = int(0.01 * SR)
    n = len(m) // fr
    rms = np.sqrt((m[:n * fr].reshape(n, fr) ** 2).mean(1)) if n else np.array([np.sqrt((m ** 2).mean())])
    loud = np.sort(rms)[-max(1, int(len(rms) * 0.3)):].mean()
    x *= 10 ** ((target_db + gain_db) / 20) / max(loud, 1e-6)
    cap = 10 ** (-3 / 20)
    pk = np.abs(x).max()
    if pk > cap:
        x *= cap / pk
    return x

def write(path, x):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())

def build(set_name, out):
    if set_name != "C":
        fetch()
    os.makedirs(out, exist_ok=True)
    for name, v in SETS[set_name].items():
        for old in glob.glob(os.path.join(out, name + "_[0-9].wav")):
            os.remove(old)  # takes from an earlier build
        takes = v if isinstance(v, list) else [v]
        for i, t in enumerate(takes):
            t = t if isinstance(t, dict) else {"src": t}
            ml, tdb = CAT[cat_of(name)]
            x = process(find(t["src"]), t.get("max", ml), tdb, t.get("lp", 4200),
                        t.get("pitch", 1.0), t.get("gain", 0.0))
            write(os.path.join(out, name + ("" if i == 0 else "_%d" % (i + 1)) + ".wav"), x)
    print("built set", set_name, "into", out)

if __name__ == "__main__":
    s = sys.argv[1] if len(sys.argv) > 1 else "A"
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(ROOT, "assets", "sfx")
    build(s, out)
