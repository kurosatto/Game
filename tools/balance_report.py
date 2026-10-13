# balance_report.py
# Rough power score for every playable form in data/Lineages.gd, so forms
# that are slow, half-blind or melee-only can be checked against their
# siblings. Not part of the game; run it with:
#   python3 tools/balance_report.py
# Each form gets four factors relative to the starting cell, and a score:
#   attack  = damage per second x spread x reach (melee arcs, shot range)
#   toughness = health so far on this path x damage reduction, i-frames, regen
#   move    = speed, plus the faster dash recharge slow forms get (Player.gd);
#             forms with an escape move instead (Lineages.ESCAPES) count it
#             as extra toughness and attack
#   senses  = sight rating plus half the other sense
#   score   = attack^1 x toughness^0.8 x move^1 x senses^0.3
# Forms at the same evolution step should score close to each other; the
# report flags any more than 15% off the step's median.
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = (ROOT / "data" / "Lineages.gd").read_text()

def section(start, end):
    return SRC[SRC.index(start):SRC.index(end)]

def num(body, key, default=0.0):
    m = re.search(r'"%s": (-?[\d.]+|TAU)' % key, body)
    if not m:
        return default
    return math.tau if m.group(1) == "TAU" else float(m.group(1))

def text(body, key):
    m = re.search(r'"%s": "([^"]*)"' % key, body)
    return m.group(1) if m else ""

VISION = {k: int(v) for k, v in re.findall(r'"(\w+)": \[(\d+),', section("const VISION =", "const VISION_WORDS"))}
SENSES = {k: int(v) for k, v in re.findall(r'"(\w+)": \[(\d+),', section("const SENSES =", "const SENSE_WORDS"))}
WEAPONS = {}
for name, body in re.findall(r'"(\w+)": \{("melee".*?)\},?\n', section("const WEAPONS =", "static func weapon_stats")):
    WEAPONS[name] = body

ESCAPES = dict(re.findall(r'"(\w+)": \["(\w+)"', section("const ESCAPES =", "const ESCAPE_STYLES")))
# Forms without a dash: how much each escape is worth (toughness, attack)
ESCAPE_VALUE = {"withdraw": (1.25, 1.0), "bristle": (1.1, 1.1), "tubules": (1.15, 1.05), "ink": (1.15, 1.05)}

FORMS = {}
for path, body in re.findall(r'\n    "([\d,]*)": \{(.*?)\n    \}', section("const TREE =", "const VISION ="), re.S):
    FORMS[path] = body

SPREAD = {"single": 1.0, "triple": 1.7, "5way": 2.1, "7way": 2.4, "boomerang": 1.6,
          "needle": 1.33, "explosive": 1.5, "shrapnel": 1.3, "piercing": 1.2}
BASE_SPEED = 390.0  # the starting cell
BASE_HEALTH = 6

def dash_cooldown(speed):
    # Mirrors Player.dash_cooldown_for_speed()
    return 0.9 * min(1.15, max(0.6, speed / 440.0))

def attack(body):
    weapon = WEAPONS.get(text(body, "weapon") or "vesicle")
    dmg, delay = num(body, "damage"), num(body, "fire_delay")
    if '"melee": true' in weapon:
        dps = dmg * num(weapon, "damage") / (delay * num(weapon, "cooldown"))
        arc = num(weapon, "arc")
        reach = num(weapon, "reach")
        # A wide arc hits crowds; reach keeps you out of contact range.
        # Melee forms must close in, so they lose a little against ranged.
        dps *= (0.75 + 0.25 * min(arc, 3.0)) * (reach / 140.0) ** 0.6 * 0.8
        if "stun" in weapon or "venom" in weapon or "drain" in weapon:
            dps *= 1.12
    else:
        dps = dmg / delay * SPREAD.get(text(body, "attack_type"), 1.0)
        shot_range = num(body, "shot_speed") * num(weapon, "speed", 1.0) * 0.85 * num(weapon, "life", 1.0)
        dps *= (shot_range / 520.0) ** 0.4
        if "stun" in weapon or "caustic" in weapon:
            dps *= 1.12
    perks = body[body.index('"tear_perks"'):body.index('"dash_perks"')]
    if "explosive" in perks or "electric" in perks or "piercing" in perks:
        dps *= 1.12
    if "homing" in perks:
        dps *= 1.1
    if num(body, "slam_damage") > 0:
        dps *= 1.0 + num(body, "slam_damage") / 100.0
    return dps

def toughness(path, body):
    health = BASE_HEALTH
    parts = path.split(",") if path else []
    for i in range(1, len(parts) + 1):
        health += num(FORMS[",".join(parts[:i])], "max_health_add")
    passive = text(body, "passive")
    t = health
    if passive.startswith("damage_reduction"):
        t *= 1.35
    if passive == "damage_reduction_plus_reflect":
        t *= 1.1
    if passive == "double_iframes":
        t *= 1.25
    if passive == "regen":
        t *= 1.2
    if passive == "retaliatory_spines":
        t *= 1.08
    if passive == "flight":
        t *= 1.1
    return t

def move(body):
    speed = num(body, "speed")
    if text(body, "id") in ESCAPES:
        # No dash; the escape is counted in toughness and attack instead
        return speed / (BASE_SPEED + 0.5 * 200.0 / dash_cooldown(BASE_SPEED))
    # Each dash covers about 200 px; a faster recharge buys back distance
    dash_px = 200.0 / dash_cooldown(speed)
    return (speed + 0.5 * dash_px) / (BASE_SPEED + 0.5 * 200.0 / dash_cooldown(BASE_SPEED))

def senses(body):
    i = text(body, "id")
    return (VISION.get(i, 1) + 0.5 * SENSES.get(i, 1)) / 3.0

base = FORMS[""]
ref = (attack(base), toughness("", base))
rows = []
for path, body in FORMS.items():
    a = attack(body) / ref[0]
    t = toughness(path, body) / ref[1]
    if text(body, "id") in ESCAPES:
        tv, av = ESCAPE_VALUE[ESCAPES[text(body, "id")]]
        t *= tv
        a *= av
    m = move(body)
    s = senses(body)
    score = a * t ** 0.8 * m * s ** 0.3
    depth = 0 if path == "" else len(path.split(","))
    rows.append((depth, path, text(body, "id"), int(num(body, "speed")), a, t, m, s, score))

bad = 0
for depth in sorted({r[0] for r in rows}):
    group = sorted([r for r in rows if r[0] == depth], key=lambda r: r[3])
    median = sorted(r[8] for r in group)[len(group) // 2]
    print("\nStep %d (median score %.2f)" % (depth, median))
    print("  %-9s %-24s %5s %6s %6s %6s %6s %6s" % ("path", "form", "speed", "attack", "tough", "move", "senses", "score"))
    for r in group:
        off = r[8] / median - 1.0
        flag = "  <-- %+d%%" % round(off * 100) if abs(off) > 0.15 else ""
        bad += 1 if flag else 0
        print("  %-9s %-24s %5d %6.2f %6.2f %6.2f %6.2f %6.2f%s" % (r[1] or "(start)", r[2], r[3], r[4], r[5], r[6], r[7], r[8], flag))
print("\n%d form(s) more than 15%% off their step" % bad)
sys.exit(0)
