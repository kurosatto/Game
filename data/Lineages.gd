# Lineages.gd
# The playable tree of life. Rule from the design doc: every playable form
# belongs to a group that still has living members. Extinct groups appear
# only as enemies (Bestiary.gd).
#
# "children" are the groups offered at the end of the era this form is
# played in. A form with no children gets an in-clade upgrade instead,
# because no real split is known there.
# "stats" are added on top of the current stats when the form is chosen.
# "abilities" replace the previous form's abilities.
extends RefCounted

const START_ID = "ancestral_cell"

const LINEAGES = {
    # --- Prologue ---
    "ancestral_cell": {
        "name": "Ancestral cell",
        "clade": "Holozoa (choanoflagellate-like ancestor)",
        "clade_path": "Eukaryota > Opisthokonta > Holozoa",
        "living_example": "choanoflagellates, the closest living relatives of animals",
        "fact": "A single cell with a collar of microvilli around one whip-like flagellum.",
        "stats": {},
        "abilities": [],
        "tint": Color(0.8, 1.0, 0.95), "scale": 0.8,
        "children": ["lobopodian", "early_mollusc", "early_vertebrate", "early_medusa", "early_echinoderm"],
    },
    # --- Animal groups offered at the end of the prologue ---
    "lobopodian": {
        "name": "Lobopodian",
        "clade": "Panarthropoda",
        "clade_path": "Animalia > Ecdysozoa > Panarthropoda",
        "living_example": "velvet worms, water bears and arthropods all descend from this grade",
        "fact": "Cambrian lobopodians like Aysheaia walked on soft, stubby legs.",
        "stats": {"max_health": 2, "speed": -20.0, "damage": 0.5},
        "abilities": [],
        "tint": Color(1.0, 0.85, 0.7), "scale": 0.95,
        "children": ["onychophora", "tardigrada", "arthropoda"],
    },
    "early_mollusc": {
        "name": "Early mollusc", "clade": "Mollusca", "locked": true,
        "clade_path": "Animalia > Lophotrochozoa > Mollusca",
        "living_example": "snails, clams and octopuses",
        "fact": "Early Cambrian molluscs were often only millimetres long, under a cap-shaped shell.",
        "stats": {}, "abilities": [], "tint": Color.WHITE, "scale": 1.0, "children": [],
    },
    "early_vertebrate": {
        "name": "Early vertebrate", "clade": "Vertebrata", "locked": true,
        "clade_path": "Animalia > Deuterostomia > Chordata > Vertebrata",
        "living_example": "lampreys, sharks and every other vertebrate",
        "fact": "Haikouichthys, about 518 million years old, is one of the oldest known vertebrates.",
        "stats": {}, "abilities": [], "tint": Color.WHITE, "scale": 1.0, "children": [],
    },
    "early_medusa": {
        "name": "Early jellyfish", "clade": "Cnidaria", "locked": true,
        "clade_path": "Animalia > Cnidaria > Medusozoa",
        "living_example": "jellyfish, corals and sea anemones",
        "fact": "Burgessomedusa, about 505 million years old, is the oldest known swimming jellyfish.",
        "stats": {}, "abilities": [], "tint": Color.WHITE, "scale": 1.0, "children": [],
    },
    "early_echinoderm": {
        "name": "Early echinoderm", "clade": "Echinodermata", "locked": true,
        "clade_path": "Animalia > Deuterostomia > Echinodermata",
        "living_example": "starfish, sea urchins and sea cucumbers",
        "fact": "The five-part body plan of echinoderms is a later addition; their larvae are bilateral.",
        "stats": {}, "abilities": [], "tint": Color.WHITE, "scale": 1.0, "children": [],
    },
    # --- Arthropods and kin: after the Cambrian ---
    "onychophora": {
        "name": "Velvet worm",
        "clade": "Onychophora",
        "clade_path": "Panarthropoda > Onychophora",
        "living_example": "Peripatus and other living velvet worms",
        "fact": "Velvet worms catch prey by squirting sticky slime from glands beside the mouth.",
        "stats": {"fire_delay": 0.04, "range": 0.1},
        "abilities": ["slime_shot"],
        "tint": Color(0.75, 0.55, 0.85), "scale": 1.0,
        "children": [],
    },
    "tardigrada": {
        "name": "Water bear",
        "clade": "Tardigrada",
        "clade_path": "Panarthropoda > Tardigrada",
        "living_example": "living tardigrades, found from oceans to moss",
        "fact": "Tardigrades survive drying out by entering a dormant state called cryptobiosis. Their fossils are rare, so this split is dated by molecules.",
        "stats": {"max_health": 2, "speed": -30.0},
        "abilities": ["cryptobiosis"],
        "tint": Color(0.95, 0.9, 0.8), "scale": 0.85,
        "children": [],
    },
    "arthropoda": {
        "name": "Early arthropod",
        "clade": "Arthropoda",
        "clade_path": "Panarthropoda > Arthropoda",
        "living_example": "insects, spiders, crabs and centipedes",
        "fact": "A hard, jointed exoskeleton that must be molted to grow.",
        "stats": {"max_health": 2, "damage": 0.5},
        "abilities": ["armor"],
        "tint": Color(1.0, 0.75, 0.55), "scale": 1.0,
        "children": ["chelicerata", "mandibulata"],
    },
    # --- After the Ordovician ---
    "chelicerata": {
        "name": "Chelicerate",
        "clade": "Chelicerata",
        "clade_path": "Arthropoda > Chelicerata",
        "living_example": "horseshoe crabs, spiders and scorpions",
        "fact": "Named for the chelicerae, pincer-like mouthparts in front of the mouth.",
        "stats": {"damage": 1.0},
        "abilities": ["armor"],
        "tint": Color(0.9, 0.6, 0.45), "scale": 1.05,
        "children": ["xiphosura", "arachnida"],
    },
    "mandibulata": {
        "name": "Mandibulate",
        "clade": "Mandibulata",
        "clade_path": "Arthropoda > Mandibulata",
        "living_example": "centipedes, millipedes, crustaceans and insects",
        "fact": "Named for the mandibles, jaws that chew sideways.",
        "stats": {"fire_delay": -0.04, "speed": 20.0},
        "abilities": ["armor"],
        "tint": Color(0.95, 0.8, 0.5), "scale": 1.0,
        "children": ["myriapoda", "pancrustacea"],
    },
    # --- After the Silurian ---
    "xiphosura": {
        "name": "Horseshoe crab",
        "clade": "Xiphosura",
        "clade_path": "Chelicerata > Xiphosura",
        "living_example": "Limulus polyphemus, the Atlantic horseshoe crab",
        "fact": "Horseshoe crabs are closer to spiders than to true crabs.",
        "stats": {"max_health": 4, "speed": -30.0},
        "abilities": ["armor"],
        "tint": Color(0.7, 0.6, 0.45), "scale": 1.2,
        "children": [],
    },
    "arachnida": {
        "name": "Arachnid",
        "clade": "Arachnida",
        "clade_path": "Chelicerata > Arachnida",
        "living_example": "spiders, scorpions, mites and harvestmen",
        "fact": "Arachnids were among the first animals to live on land.",
        "stats": {"speed": 30.0, "damage": 0.5},
        "abilities": ["armor"],
        "tint": Color(0.6, 0.45, 0.4), "scale": 1.0,
        "children": ["scorpiones", "araneae"],
    },
    "myriapoda": {
        "name": "Myriapod",
        "clade": "Myriapoda",
        "clade_path": "Mandibulata > Myriapoda",
        "living_example": "centipedes and millipedes",
        "fact": "Pneumodesmus, a Silurian millipede about 425 million years old, is the oldest known land animal.",
        "stats": {"max_health": 2, "speed": 20.0},
        "abilities": ["armor"],
        "tint": Color(0.8, 0.55, 0.35), "scale": 1.05,
        "children": ["diplopoda", "chilopoda"],
    },
    "pancrustacea": {
        "name": "Pancrustacean",
        "clade": "Pancrustacea",
        "clade_path": "Mandibulata > Pancrustacea",
        "living_example": "crabs, shrimp, barnacles and insects",
        "fact": "Insects evolved from within the crustacean group, so crustaceans alone are not a clade.",
        "stats": {"shot_speed": 80.0, "fire_delay": -0.03},
        "abilities": ["armor"],
        "tint": Color(1.0, 0.65, 0.5), "scale": 1.0,
        "children": ["hexapoda", "malacostraca"],
    },
    # --- After the Devonian (final forms in the Carboniferous) ---
    "scorpiones": {
        "name": "Scorpion",
        "clade": "Scorpiones",
        "clade_path": "Arachnida > Scorpiones",
        "living_example": "the emperor scorpion and about 2,500 other living species",
        "fact": "Scorpions glow under ultraviolet light because of compounds in their cuticle.",
        "stats": {"damage": 2.0},
        "abilities": ["armor"],
        "tint": Color(0.55, 0.4, 0.3), "scale": 1.15,
        "children": [],
    },
    "araneae": {
        "name": "Spider",
        "clade": "Araneae",
        "clade_path": "Arachnida > Araneae",
        "living_example": "orb weavers, jumping spiders and segmented trapdoor spiders",
        "fact": "The oldest true spiders are from the Carboniferous and resemble living segmented trapdoor spiders.",
        "stats": {"fire_delay": 0.02, "range": 0.15},
        "abilities": ["slime_shot", "armor"],
        "tint": Color(0.4, 0.35, 0.35), "scale": 1.0,
        "children": [],
    },
    "diplopoda": {
        "name": "Millipede",
        "clade": "Diplopoda",
        "clade_path": "Myriapoda > Diplopoda",
        "living_example": "pill millipedes and giant African millipedes",
        "fact": "Millipedes have two pairs of legs on most body segments.",
        "stats": {"max_health": 4, "speed": -20.0},
        "abilities": ["armor"],
        "tint": Color(0.5, 0.35, 0.25), "scale": 1.1,
        "children": [],
    },
    "chilopoda": {
        "name": "Centipede",
        "clade": "Chilopoda",
        "clade_path": "Myriapoda > Chilopoda",
        "living_example": "house centipedes and giant Scolopendra",
        "fact": "A centipede's venom claws are modified legs, not mouthparts.",
        "stats": {"speed": 40.0, "damage": 1.0},
        "abilities": ["armor"],
        "tint": Color(0.85, 0.45, 0.25), "scale": 1.0,
        "children": [],
    },
    "hexapoda": {
        "name": "Winged insect",
        "clade": "Hexapoda: Pterygota",
        "clade_path": "Pancrustacea > Hexapoda > Pterygota",
        "living_example": "dragonflies, beetles and butterflies",
        "fact": "Insects were the first animals to fly, by the Carboniferous at the latest.",
        "stats": {"speed": 60.0, "max_health": -2},
        "abilities": ["triple_shot"],
        "tint": Color(0.6, 0.9, 0.7), "scale": 0.95,
        "children": [],
    },
    "malacostraca": {
        "name": "Malacostracan",
        "clade": "Malacostraca",
        "clade_path": "Pancrustacea > Malacostraca",
        "living_example": "crabs, lobsters, shrimp and woodlice",
        "fact": "Woodlice are malacostracans that moved onto land.",
        "stats": {"damage": 1.5, "max_health": 2},
        "abilities": ["armor"],
        "tint": Color(0.95, 0.45, 0.35), "scale": 1.1,
        "children": [],
    },
}

static func get_lineage(id: String) -> Dictionary:
    return LINEAGES.get(id, LINEAGES[START_ID])

static func is_locked(id: String) -> bool:
    return get_lineage(id).get("locked", false)

# The choices shown at the end of an era. Always returns at least one entry:
# a form with no real split known offers an in-clade upgrade of itself.
static func get_choices(id: String) -> Array:
    var children: Array = get_lineage(id).get("children", [])
    if children.is_empty():
        return [id]
    return children
