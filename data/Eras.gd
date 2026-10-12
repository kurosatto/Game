# Eras.gd
# One entry per floor. A run walks forward through real geological time:
# a Precambrian prologue as an ancestral cell, then five Paleozoic periods.
extends RefCounted

const ERAS = [
    {
        "id": "precambrian",
        "name": "Precambrian Ocean",
        "dates": "about 700 to 539 million years ago",
        "floor_tint": Color(0.75, 0.85, 0.80),
        "enemies": ["ciliate", "heliozoan"],
        "boss": "dickinsonia",
    },
    {
        "id": "cambrian",
        "name": "Cambrian",
        "dates": "538.8 to 485.4 million years ago",
        "floor_tint": Color(0.95, 0.88, 0.70),
        "enemies": ["marrella", "olenellus", "wiwaxia", "opabinia"],
        "boss": "anomalocaris",
    },
    {
        "id": "ordovician",
        "name": "Ordovician",
        "dates": "485.4 to 443.8 million years ago",
        "floor_tint": Color(0.70, 0.85, 1.00),
        "enemies": ["asaphid", "arandaspis", "megalograptus"],
        "boss": "cameroceras",
    },
    {
        "id": "silurian",
        "name": "Silurian",
        "dates": "443.8 to 419.2 million years ago",
        "floor_tint": Color(0.80, 0.95, 0.85),
        "enemies": ["eurypterus", "birkenia", "phacopid"],
        "boss": "pterygotus",
    },
    {
        "id": "devonian",
        "name": "Devonian",
        "dates": "419.2 to 358.9 million years ago",
        "floor_tint": Color(0.75, 0.80, 0.95),
        "enemies": ["cladoselache", "bothriolepis", "agoniatites"],
        "boss": "dunkleosteus",
    },
    {
        "id": "carboniferous",
        "name": "Carboniferous",
        "dates": "358.9 to 298.9 million years ago",
        "floor_tint": Color(0.70, 0.90, 0.65),
        "enemies": ["meganeura", "arthropleura", "edestus"],
        "boss": "crassigyrinus",
    },
]

static func count() -> int:
    return ERAS.size()

# floor_number is 1-based, as used everywhere else in the game.
static func for_floor(floor_number: int) -> Dictionary:
    var index = clampi(floor_number - 1, 0, ERAS.size() - 1)
    return ERAS[index]
