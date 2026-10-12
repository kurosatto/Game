# Bestiary.gd
# Every enemy is a real organism from its era. Extinct groups live here:
# they can be fought but never played (see Lineages.gd).
# "ai" picks one of the behaviours already in Enemy.gd:
#   "fly"   = chases the player
#   "pacer" = wanders and shoots
#   "boss"  = leaps and fires a ring of shots
extends RefCounted

const FLY_TEX = "res://assets/enemy_fly.png"
const PACER_TEX = "res://assets/enemy_gusha.png"
const BOSS_TEX = "res://assets/boss.png"

const ENEMIES = {
    # --- Precambrian ---
    "ciliate": {
        "name": "Predatory ciliate", "sci": "Ciliophora",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.8, 1.0, 0.8), "scale": 0.8,
        "health": 3.0, "health_per_floor": 1.0, "speed": 175.0, "radius": 22.0,
    },
    "heliozoan": {
        "name": "Sun animalcule", "sci": "Heliozoa (a grade, not a clade)",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(1.0, 0.95, 0.6), "scale": 0.8,
        "health": 5.0, "health_per_floor": 1.5, "speed": 80.0, "radius": 28.0,
    },
    "dickinsonia": {
        "name": "Dickinsonia", "sci": "Dickinsonia costata",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color(0.9, 0.8, 0.6), "scale": 0.9,
        "health": 60.0, "health_per_floor": 20.0, "speed": 90.0, "radius": 64.0,
    },
    # --- Cambrian ---
    "marrella": {
        "name": "Marrella", "sci": "Marrella splendens",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(1.0, 0.7, 0.9), "scale": 0.9,
        "health": 4.0, "health_per_floor": 1.5, "speed": 185.0, "radius": 24.0,
    },
    "olenellus": {
        "name": "Olenellus trilobite", "sci": "Olenellus",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color.WHITE, "scale": 1.0,
        "health": 7.0, "health_per_floor": 2.0, "speed": 105.0, "radius": 34.0,
    },
    "wiwaxia": {
        "name": "Wiwaxia", "sci": "Wiwaxia corrugata",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.7, 0.9, 0.6), "scale": 0.9,
        "health": 9.0, "health_per_floor": 2.0, "speed": 70.0, "radius": 30.0,
    },
    "opabinia": {
        "name": "Opabinia", "sci": "Opabinia regalis",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.9, 0.6, 0.5), "scale": 1.1,
        "health": 6.0, "health_per_floor": 1.5, "speed": 150.0, "radius": 28.0,
    },
    "anomalocaris": {
        "name": "Anomalocaris", "sci": "Anomalocaris canadensis",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color(1.0, 0.6, 0.5), "scale": 1.0,
        "health": 80.0, "health_per_floor": 30.0, "speed": 130.0, "radius": 72.0,
    },
    # --- Ordovician ---
    "asaphid": {
        "name": "Asaphid trilobite", "sci": "Asaphida",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.8, 0.8, 1.0), "scale": 1.1,
        "health": 8.0, "health_per_floor": 2.0, "speed": 100.0, "radius": 36.0,
    },
    "arandaspis": {
        "name": "Arandaspis", "sci": "Arandaspis prionotolepis",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.7, 0.8, 0.9), "scale": 1.0,
        "health": 5.0, "health_per_floor": 1.5, "speed": 190.0, "radius": 26.0,
    },
    "megalograptus": {
        "name": "Megalograptus", "sci": "Megalograptus ohioensis",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(1.0, 0.75, 0.6), "scale": 1.2,
        "health": 10.0, "health_per_floor": 2.5, "speed": 115.0, "radius": 38.0,
    },
    "cameroceras": {
        "name": "Cameroceras", "sci": "Cameroceras (Endocerida)",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color.WHITE, "scale": 1.0,
        "health": 80.0, "health_per_floor": 30.0, "speed": 120.0, "radius": 72.0,
    },
    # --- Silurian ---
    "eurypterus": {
        "name": "Eurypterus", "sci": "Eurypterus remipes",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.9, 0.7, 0.5), "scale": 1.1,
        "health": 10.0, "health_per_floor": 2.5, "speed": 115.0, "radius": 36.0,
    },
    "birkenia": {
        "name": "Birkenia", "sci": "Birkenia elegans",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.6, 0.9, 1.0), "scale": 0.9,
        "health": 5.0, "health_per_floor": 1.5, "speed": 205.0, "radius": 24.0,
    },
    "phacopid": {
        "name": "Phacopid trilobite", "sci": "Phacopida",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.9, 0.9, 0.7), "scale": 1.0,
        "health": 11.0, "health_per_floor": 2.5, "speed": 95.0, "radius": 34.0,
    },
    "pterygotus": {
        "name": "Pterygotus", "sci": "Pterygotus anglicus",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color(1.0, 0.7, 0.4), "scale": 1.1,
        "health": 90.0, "health_per_floor": 30.0, "speed": 130.0, "radius": 74.0,
    },
    # --- Devonian ---
    "cladoselache": {
        "name": "Cladoselache", "sci": "Cladoselache fyleri",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.6, 0.7, 0.8), "scale": 1.2,
        "health": 8.0, "health_per_floor": 2.0, "speed": 225.0, "radius": 30.0,
    },
    "bothriolepis": {
        "name": "Bothriolepis", "sci": "Bothriolepis canadensis",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.7, 0.75, 0.6), "scale": 1.1,
        "health": 13.0, "health_per_floor": 3.0, "speed": 90.0, "radius": 36.0,
    },
    "agoniatites": {
        "name": "Agoniatites ammonoid", "sci": "Agoniatites",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(1.0, 0.85, 0.7), "scale": 0.9,
        "health": 9.0, "health_per_floor": 2.0, "speed": 120.0, "radius": 30.0,
    },
    "dunkleosteus": {
        "name": "Dunkleosteus", "sci": "Dunkleosteus terrelli",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color(0.6, 0.65, 0.75), "scale": 1.2,
        "health": 110.0, "health_per_floor": 30.0, "speed": 140.0, "radius": 78.0,
    },
    # --- Carboniferous ---
    "meganeura": {
        "name": "Meganeura griffinfly", "sci": "Meganeura monyi",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.6, 1.0, 0.9), "scale": 1.2,
        "health": 8.0, "health_per_floor": 2.0, "speed": 240.0, "radius": 30.0,
    },
    "arthropleura": {
        "name": "Arthropleura", "sci": "Arthropleura armata",
        "ai": "pacer", "texture": PACER_TEX, "tint": Color(0.75, 0.6, 0.45), "scale": 1.4,
        "health": 18.0, "health_per_floor": 3.0, "speed": 70.0, "radius": 44.0,
    },
    "edestus": {
        "name": "Edestus", "sci": "Edestus (Eugeneodontida)",
        "ai": "fly", "texture": FLY_TEX, "tint": Color(0.55, 0.6, 0.75), "scale": 1.3,
        "health": 10.0, "health_per_floor": 2.5, "speed": 210.0, "radius": 34.0,
    },
    "crassigyrinus": {
        "name": "Crassigyrinus", "sci": "Crassigyrinus scoticus",
        "ai": "boss", "texture": BOSS_TEX, "tint": Color(0.6, 0.8, 0.5), "scale": 1.2,
        "health": 120.0, "health_per_floor": 30.0, "speed": 135.0, "radius": 78.0,
    },
}

static func get_enemy(id: String) -> Dictionary:
    return ENEMIES.get(id, ENEMIES["olenellus"])
