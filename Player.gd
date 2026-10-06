# Player.gd
extends CharacterBody2D

signal health_changed(health, max_health)
signal stats_changed(dna, keys)
signal dna_changed(current_dna, max_dna, level)
signal dash_updated(current_cooldown, max_cooldown)
signal discharge_updated(current_cooldown, max_cooldown)
signal player_died
signal creature_changed(character_name, clade, color)

@export var max_health: int = 6
@export var health: int = 6

# Base stats (Scaled for 1080p)
@export var speed: float = 390.0
@export var damage: float = 3.5
@export var fire_delay: float = 0.28
@export var range_lifetime: float = 0.85
@export var shot_speed: float = 720.0

# Organism Evolution & Inventory
var dna_biomass: int = 0
var keys: int = 0
var evolution_choices: Array = [] # Tracks chosen path index per floor [0 or 1, ...]
var evolution_history: Array = [] # [{ "floor": 1, "title": "...", "clade": "...", "choice": 0 }]

# Active Creature State (Transforms on every floor into a distinct character)
var current_character_id: String = "protozoa"
var current_character_name: String = "PRIMORDIAL PROTOZOA"
var current_character_clade: String = "Ediacaran Microbiota — The First Spark"
var current_modulate: Color = Color(0.0, 0.95, 1.0)
var current_accessory: String = "cilia"
var current_attack_type: String = "single"
var current_tear_perks: Dictionary = {}
var current_dash_perks: Dictionary = {}
var current_passive: String = "none"

# Passive timer
var regen_timer: float = 0.0
var regen_interval: float = 8.0

# Tear counter for burst cadences
var shot_counter: int = 0

# Bio-Hydro Dash
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_duration: float = 0.22
var dash_speed: float = 900.0
var dash_direction: Vector2 = Vector2.UP
var dash_cooldown: float = 0.0
var max_dash_cooldown: float = 0.9

# Bio-Electric Discharge (Replaces legacy bombs with tactical ability)
var discharge_cooldown: float = 0.0
var max_discharge_cooldown: float = 4.5
var discharge_radius: float = 290.0

# Visual animation & cooldowns
var swim_time: float = 0.0
var shoot_cooldown: float = 0.0
var invincibility_time: float = 0.0
var door_cooldown: float = 0.0

# Preloads
var tear_scene = preload("res://Tear.tscn")

# ══════════════════════════════════════════════════════════════════════════════
# 31 DISTINCT PLAYABLE CHARACTERS (1 Root + 2 Floor 2 + 4 Floor 3 + 8 Floor 4 + 16 Floor 5)
# ══════════════════════════════════════════════════════════════════════════════
const CHARACTERS = {
    # ── Level 1 / Floor 1 (Root) ──
    "": {
        "id": "protozoa",
        "name": "PRIMORDIAL PROTOZOA",
        "clade": "Ediacaran Microbiota — The First Spark",
        "desc": "Single-celled ancestral organism pulsing in the primordial soup.",
        "color": Color(0.0, 0.95, 1.0),
        "light_color": Color(0.0, 0.95, 1.0),
        "light_energy": 1.3,
        "scale": Vector2(1.0, 1.0),
        "speed": 390.0,
        "damage": 3.5,
        "fire_delay": 0.28,
        "shot_speed": 720.0,
        "max_health_add": 0,
        "attack_type": "single",
        "tear_perks": {},
        "dash_perks": {},
        "passive": "none",
        "accessory": "cilia"
    },

    # ── Level 2 / Floor 2 (2 Playable Characters) ──
    "0": {
        "id": "pikaia",
        "name": "PIKAIA VERTEBRATA",
        "clade": "Phylum Chordata — The First Spine",
        "desc": "Agile eel-like chordate with flexible dorsal nerve cord and slipstream dash.",
        "color": Color(0.1, 0.9, 1.25),
        "light_color": Color(0.0, 0.9, 1.0),
        "light_energy": 1.5,
        "scale": Vector2(1.1, 0.95),
        "speed": 470.0,
        "damage": 3.8,
        "fire_delay": 0.25,
        "shot_speed": 820.0,
        "max_health_add": 0,
        "attack_type": "single",
        "tear_perks": {},
        "dash_perks": {"slipstream": true},
        "passive": "none",
        "accessory": "fin"
    },
    "1": {
        "id": "trilobita",
        "name": "PROTO-CARAPACE TRILOBITA",
        "clade": "Phylum Arthropoda — Mineralized Exoskeleton",
        "desc": "Heavily armored benthic arthropod with mineralized calcite plates and defensive spines.",
        "color": Color(1.2, 0.85, 0.35),
        "light_color": Color(1.0, 0.75, 0.2),
        "light_energy": 1.4,
        "scale": Vector2(1.15, 1.15),
        "speed": 360.0,
        "damage": 4.2,
        "fire_delay": 0.30,
        "shot_speed": 680.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"knockback": 250.0},
        "dash_perks": {},
        "passive": "retaliatory_spines",
        "accessory": "carapace"
    },

    # ── Level 3 / Floor 3 (4 Playable Characters) ──
    "0,0": {
        "id": "dunkleosteus",
        "name": "DUNKLEOSTEUS JAWS",
        "clade": "Placodermi — Armored Jawed Predator",
        "desc": "Heavy cranial bone armor with armor-crushing concussive bite force.",
        "color": Color(1.25, 0.45, 0.45),
        "light_color": Color(1.0, 0.35, 0.3),
        "light_energy": 1.6,
        "scale": Vector2(1.25, 1.2),
        "speed": 420.0,
        "damage": 6.8,
        "fire_delay": 0.29,
        "shot_speed": 760.0,
        "max_health_add": 2,
        "attack_type": "single",
        "tear_perks": {"knockback": 550.0},
        "dash_perks": {"slam_damage": 6.0},
        "passive": "none",
        "accessory": "fin"
    },
    "0,1": {
        "id": "nautiloid",
        "name": "NAUTILOID CEPHALOPOD",
        "clade": "Cephalopoda — Siphon Jet Hunter",
        "desc": "Buoyant chambered shell and multi-directional tentacles firing magnetic homing spreads.",
        "color": Color(0.2, 1.2, 0.95),
        "light_color": Color(0.0, 1.0, 0.85),
        "light_energy": 1.5,
        "scale": Vector2(1.1, 1.1),
        "speed": 430.0,
        "damage": 4.0,
        "fire_delay": 0.23,
        "shot_speed": 730.0,
        "max_health_add": 0,
        "attack_type": "triple",
        "tear_perks": {"homing": true},
        "dash_perks": {},
        "passive": "none",
        "accessory": "tentacles"
    },
    "1,0": {
        "id": "eurypterid",
        "name": "EURYPTERID SEA SCORPION",
        "clade": "Chelicerata — Apex Stalker of the Shallows",
        "desc": "Venomous tail stinger and raptorial appendages injecting caustic poison.",
        "color": Color(0.4, 1.25, 0.35),
        "light_color": Color(0.3, 1.0, 0.3),
        "light_energy": 1.5,
        "scale": Vector2(1.2, 1.15),
        "speed": 400.0,
        "damage": 4.8,
        "fire_delay": 0.26,
        "shot_speed": 750.0,
        "max_health_add": 2,
        "attack_type": "single",
        "tear_perks": {"caustic": true},
        "dash_perks": {"poison_trail": true},
        "passive": "none",
        "accessory": "stinger"
    },
    "1,1": {
        "id": "bastion",
        "name": "CALCIFIED BASTION",
        "clade": "Dinocaridida — Armored Dreadnought",
        "desc": "Titanic interlocking thoracic shield plates that crush obstacles and ram foes.",
        "color": Color(1.2, 0.85, 0.25),
        "light_color": Color(0.95, 0.75, 0.2),
        "light_energy": 1.5,
        "scale": Vector2(1.35, 1.35),
        "speed": 360.0,
        "damage": 5.2,
        "fire_delay": 0.32,
        "shot_speed": 680.0,
        "max_health_add": 6,
        "attack_type": "single",
        "tear_perks": {"knockback": 400.0},
        "dash_perks": {"slam_damage": 10.0},
        "passive": "double_iframes",
        "accessory": "carapace"
    },

    # ── Level 4 / Floor 4 (8 Playable Characters) ──
    "0,0,0": {
        "id": "tiktaalik",
        "name": "TIKTAALIK SHOREWALKER",
        "clade": "Tetrapodomorpha — The Land Pioneer",
        "desc": "First lungs and muscular weight-bearing limbs with cellular oxygen regeneration.",
        "color": Color(0.35, 1.3, 0.65),
        "light_color": Color(0.2, 1.0, 0.5),
        "light_energy": 1.5,
        "scale": Vector2(1.25, 1.25),
        "speed": 420.0,
        "damage": 7.5,
        "fire_delay": 0.26,
        "shot_speed": 780.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"knockback": 450.0},
        "dash_perks": {"slipstream": true},
        "passive": "regen",
        "accessory": "fin"
    },
    "0,0,1": {
        "id": "cladoselache",
        "name": "CLADOSELACHE SWIFT-SHARK",
        "clade": "Chondrichthyes — Pelagic Razor Phantom",
        "desc": "Hydrodynamic cartilaginous predator firing piercing high-voltage electric tears.",
        "color": Color(0.25, 0.95, 1.35),
        "light_color": Color(0.2, 0.85, 1.0),
        "light_energy": 1.6,
        "scale": Vector2(1.2, 1.0),
        "speed": 490.0,
        "damage": 6.5,
        "fire_delay": 0.20,
        "shot_speed": 920.0,
        "max_health_add": 2,
        "attack_type": "single",
        "tear_perks": {"piercing": true, "electric": true},
        "dash_perks": {"slipstream": true},
        "passive": "none",
        "accessory": "fin"
    },
    "0,1,0": {
        "id": "kraken",
        "name": "ABYSSAL KRAKEN SQUID",
        "clade": "Coleoidea — Terror of the Deep Trenches",
        "desc": "Titanic deep-ocean cephalopod with 5-way omnidirectional magnetic homing spray.",
        "color": Color(0.85, 0.4, 1.35),
        "light_color": Color(0.7, 0.3, 1.0),
        "light_energy": 1.6,
        "scale": Vector2(1.25, 1.25),
        "speed": 440.0,
        "damage": 5.0,
        "fire_delay": 0.19,
        "shot_speed": 760.0,
        "max_health_add": 2,
        "attack_type": "5way",
        "tear_perks": {"homing": true},
        "dash_perks": {"smoke_cloud": true},
        "passive": "none",
        "accessory": "tentacles"
    },
    "0,1,1": {
        "id": "ammonite",
        "name": "SPHERICAL AMMONITE FORTRESS",
        "clade": "Ammonoidea — Eternal Living Vault",
        "desc": "Fractal suture chambered shell absorbing kinetic shocks and reducing damage.",
        "color": Color(1.25, 1.05, 0.45),
        "light_color": Color(1.0, 0.85, 0.3),
        "light_energy": 1.5,
        "scale": Vector2(1.35, 1.3),
        "speed": 370.0,
        "damage": 5.8,
        "fire_delay": 0.28,
        "shot_speed": 720.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"knockback": 350.0},
        "dash_perks": {},
        "passive": "damage_reduction",
        "accessory": "shell"
    },
    "1,0,0": {
        "id": "pulmonoscorpius",
        "name": "PULMONOSCORPIUS TITAN",
        "clade": "Scorpiones — Terrestrial Venom Monarch",
        "desc": "One-meter Carboniferous scorpion leaving burning pools of corrosive caustic acid.",
        "color": Color(0.5, 1.3, 0.25),
        "light_color": Color(0.4, 1.0, 0.2),
        "light_energy": 1.6,
        "scale": Vector2(1.3, 1.25),
        "speed": 410.0,
        "damage": 6.5,
        "fire_delay": 0.23,
        "shot_speed": 770.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"caustic": true},
        "dash_perks": {"poison_trail": true},
        "passive": "none",
        "accessory": "stinger"
    },
    "1,0,1": {
        "id": "meganeura",
        "name": "MEGANEURA DRAGONFLY",
        "clade": "Meganisoptera — Giant Carboniferous Aviator",
        "desc": "Hyper-oxygenated aviator soaring over rocks with rapid aerodynamic gale shots.",
        "color": Color(0.2, 1.35, 1.2),
        "light_color": Color(0.0, 1.0, 0.9),
        "light_energy": 1.6,
        "scale": Vector2(1.15, 1.1),
        "speed": 520.0,
        "damage": 5.2,
        "fire_delay": 0.15,
        "shot_speed": 940.0,
        "max_health_add": 0,
        "attack_type": "needle",
        "tear_perks": {"piercing": true},
        "dash_perks": {},
        "passive": "flight",
        "accessory": "wings"
    },
    "1,1,0": {
        "id": "arthropleura",
        "name": "ARTHROPLEURA CENTIPEDE",
        "clade": "Myriapoda — Forest Floor Colossus",
        "desc": "Two-meter millipede titan with 30 armored body rings trampling everything in its path.",
        "color": Color(1.3, 0.6, 0.3),
        "light_color": Color(0.95, 0.45, 0.2),
        "light_energy": 1.5,
        "scale": Vector2(1.45, 1.35),
        "speed": 390.0,
        "damage": 6.2,
        "fire_delay": 0.26,
        "shot_speed": 730.0,
        "max_health_add": 8,
        "attack_type": "single",
        "tear_perks": {"knockback": 500.0},
        "dash_perks": {"slam_damage": 12.0},
        "passive": "double_iframes",
        "accessory": "carapace"
    },
    "1,1,1": {
        "id": "mantis",
        "name": "MANTIS SHRIMP CAVITATOR",
        "clade": "Stomatopoda — Kinetic Shockwave Striker",
        "desc": "10,000G spring-loaded cavitation clubs unleashing explosive stun shockwaves.",
        "color": Color(1.35, 0.3, 0.7),
        "light_color": Color(1.0, 0.2, 0.5),
        "light_energy": 1.7,
        "scale": Vector2(1.2, 1.2),
        "speed": 440.0,
        "damage": 9.8,
        "fire_delay": 0.28,
        "shot_speed": 820.0,
        "max_health_add": 2,
        "attack_type": "single",
        "tear_perks": {"knockback": 700.0, "stun": true},
        "dash_perks": {"cavitation_burst": true},
        "passive": "none",
        "accessory": "clubs"
    },

    # ── Level 5 / Floor 5: THE 16 APEX PLAYABLE CHARACTERS! ──
    "0,0,0,0": {
        "id": "gorgonopsid",
        "name": "GORGONOPSID THERAPSID",
        "clade": "Synapsida — Proto-Mammal Sovereign",
        "desc": "Saber canines and endothermic predatory power with vampiric life leech on hits.",
        "color": Color(1.3, 0.5, 0.2),
        "light_color": Color(1.0, 0.4, 0.15),
        "light_energy": 1.8,
        "scale": Vector2(1.35, 1.3),
        "speed": 450.0,
        "damage": 9.5,
        "fire_delay": 0.22,
        "shot_speed": 840.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"vampiric": true, "knockback": 550.0},
        "dash_perks": {"slam_damage": 10.0},
        "passive": "none",
        "accessory": "fin"
    },
    "0,0,0,1": {
        "id": "diplocaulus",
        "name": "DIPLOCAULUS BOOMERANG",
        "clade": "Lepospondyli — Boomerang Hydrofoil Amphibian",
        "desc": "Wide aerodynamic cephalic wing firing twin piercing boomerang projectiles that return.",
        "color": Color(0.25, 1.3, 0.85),
        "light_color": Color(0.2, 1.0, 0.7),
        "light_energy": 1.7,
        "scale": Vector2(1.35, 1.15),
        "speed": 470.0,
        "damage": 7.0,
        "fire_delay": 0.22,
        "shot_speed": 800.0,
        "max_health_add": 4,
        "attack_type": "boomerang",
        "tear_perks": {"piercing": true, "boomerang": true},
        "dash_perks": {"slipstream": true},
        "passive": "regen",
        "accessory": "horns"
    },
    "0,0,1,0": {
        "id": "megalodon",
        "name": "MEGALODON LEVIATHAN",
        "clade": "Otodontidae — Apex Lord of the Deep",
        "desc": "Greatest apex shark: serrated razor jaws piercing all enemies with chained high-voltage lightning.",
        "color": Color(0.15, 0.85, 1.45),
        "light_color": Color(0.1, 0.7, 1.0),
        "light_energy": 1.9,
        "scale": Vector2(1.4, 1.35),
        "speed": 500.0,
        "damage": 8.5,
        "fire_delay": 0.18,
        "shot_speed": 960.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"piercing": true, "electric": true},
        "dash_perks": {"slipstream": true},
        "passive": "none",
        "accessory": "fin"
    },
    "0,0,1,1": {
        "id": "mosasaur",
        "name": "MOSASAURUS OCEAN TYRANT",
        "clade": "Mosasauridae — Cretaceous Marine Juggernaut",
        "desc": "Gargantuan marine reptile: shrapnel fangs burst into secondary teeth, tidal tail-whip dash.",
        "color": Color(0.15, 1.25, 1.05),
        "light_color": Color(0.1, 0.95, 0.8),
        "light_energy": 1.8,
        "scale": Vector2(1.4, 1.3),
        "speed": 480.0,
        "damage": 8.0,
        "fire_delay": 0.21,
        "shot_speed": 880.0,
        "max_health_add": 6,
        "attack_type": "shrapnel",
        "tear_perks": {"shrapnel": true},
        "dash_perks": {"slam_damage": 14.0},
        "passive": "none",
        "accessory": "fin"
    },
    "0,1,0,0": {
        "id": "architeuthis",
        "name": "ARCHITEUTHIS VOID SQUID",
        "clade": "Architeuthidae — Midnight Trench Sovereign",
        "desc": "7-way omnidirectional siphon barrage pulling targets into gravitational void singularities.",
        "color": Color(1.0, 0.25, 1.4),
        "light_color": Color(0.8, 0.2, 1.0),
        "light_energy": 1.9,
        "scale": Vector2(1.35, 1.35),
        "speed": 450.0,
        "damage": 5.8,
        "fire_delay": 0.17,
        "shot_speed": 800.0,
        "max_health_add": 4,
        "attack_type": "7way",
        "tear_perks": {"homing": true},
        "dash_perks": {"smoke_cloud": true},
        "passive": "none",
        "accessory": "tentacles"
    },
    "0,1,0,1": {
        "id": "cuttlefish",
        "name": "PHANTOM CUTTLEFISH",
        "clade": "Sepiida — Master of Chromatic Deception",
        "desc": "Active optical camouflage: dash turns player invisible and invulnerable for 1.5s, rapid pulse fire.",
        "color": Color(0.35, 1.3, 1.2),
        "light_color": Color(0.3, 1.0, 0.9),
        "light_energy": 1.7,
        "scale": Vector2(1.2, 1.2),
        "speed": 480.0,
        "damage": 6.0,
        "fire_delay": 0.15,
        "shot_speed": 880.0,
        "max_health_add": 2,
        "attack_type": "triple",
        "tear_perks": {"stun": true},
        "dash_perks": {"camouflage": true, "invulnerable_duration": 1.5},
        "passive": "none",
        "accessory": "tentacles"
    },
    "0,1,1,0": {
        "id": "sphenodiscus",
        "name": "SPHENODISCUS SHRAPNEL SHELL",
        "clade": "Sphenodiscidae — Oxyconic Blast Shell",
        "desc": "Knife-edge compressed shell: every tear hit bursts into 4 ricocheting shell flechettes.",
        "color": Color(1.3, 1.05, 0.3),
        "light_color": Color(1.0, 0.8, 0.2),
        "light_energy": 1.8,
        "scale": Vector2(1.35, 1.35),
        "speed": 400.0,
        "damage": 8.5,
        "fire_delay": 0.24,
        "shot_speed": 820.0,
        "max_health_add": 4,
        "attack_type": "shrapnel",
        "tear_perks": {"shrapnel": true, "knockback": 450.0},
        "dash_perks": {},
        "passive": "damage_reduction",
        "accessory": "shell"
    },
    "0,1,1,1": {
        "id": "prismatic_ammonite",
        "name": "PRISMATIC BASTION AMMONITE",
        "clade": "Pachydiscidae — Radiant Diamond Citadel",
        "desc": "Unbreakable pearlescent prism: reduces damage by 1 and passively reflects enemy projectiles.",
        "color": Color(1.2, 1.25, 1.4),
        "light_color": Color(0.9, 0.95, 1.0),
        "light_energy": 1.8,
        "scale": Vector2(1.4, 1.4),
        "speed": 380.0,
        "damage": 7.5,
        "fire_delay": 0.26,
        "shot_speed": 760.0,
        "max_health_add": 8,
        "attack_type": "single",
        "tear_perks": {"knockback": 400.0},
        "dash_perks": {},
        "passive": "damage_reduction_plus_reflect",
        "accessory": "shell"
    },
    "1,0,0,0": {
        "id": "plague_scorpion",
        "name": "EMPEROR PLAGUE SCORPION",
        "clade": "Heterometrinae — Sovereign of Corrosive Venom",
        "desc": "Concentrated necrotic enzymes: toxic acid pools melt enemies and explode into venom clouds.",
        "color": Color(0.5, 1.4, 0.15),
        "light_color": Color(0.4, 1.0, 0.1),
        "light_energy": 1.8,
        "scale": Vector2(1.35, 1.3),
        "speed": 430.0,
        "damage": 8.5,
        "fire_delay": 0.20,
        "shot_speed": 820.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"caustic": true},
        "dash_perks": {"poison_trail": true},
        "passive": "none",
        "accessory": "stinger"
    },
    "1,0,0,1": {
        "id": "trapdoor_spider",
        "name": "TRAPDOOR SILK REAPER",
        "clade": "Araneae — Ancient Silkweaver Stalker",
        "desc": "High-tensile silk webs pin enemies in place, dash drops an ensnaring ambush trap.",
        "color": Color(0.85, 0.75, 1.2),
        "light_color": Color(0.7, 0.6, 0.9),
        "light_energy": 1.7,
        "scale": Vector2(1.25, 1.25),
        "speed": 450.0,
        "damage": 7.5,
        "fire_delay": 0.22,
        "shot_speed": 800.0,
        "max_health_add": 4,
        "attack_type": "single",
        "tear_perks": {"stun": true},
        "dash_perks": {"web_snare": true},
        "passive": "none",
        "accessory": "stinger"
    },
    "1,0,1,0": {
        "id": "meganeuropsis",
        "name": "MEGANEUROPSIS SUPERSONIC",
        "clade": "Meganeuridae — 30-Inch Winged Supersonic Ace",
        "desc": "Largest flying creature of its era: 580 max speed, true flight, ultra-rapid piercing needlegun.",
        "color": Color(0.15, 1.35, 1.05),
        "light_color": Color(0.1, 1.0, 0.8),
        "light_energy": 1.9,
        "scale": Vector2(1.2, 1.15),
        "speed": 580.0,
        "damage": 6.0,
        "fire_delay": 0.10,
        "shot_speed": 1000.0,
        "max_health_add": 2,
        "attack_type": "needle",
        "tear_perks": {"piercing": true},
        "dash_perks": {},
        "passive": "flight",
        "accessory": "wings"
    },
    "1,0,1,1": {
        "id": "bombardier",
        "name": "PYROTECHNIC BOMBARDIER BEETLE",
        "clade": "Carabidae — Hydroquinone Blast Cannon",
        "desc": "Twin chemical reaction chambers firing 100°C high-explosive artillery shells.",
        "color": Color(1.35, 0.45, 0.1),
        "light_color": Color(1.0, 0.35, 0.05),
        "light_energy": 1.9,
        "scale": Vector2(1.3, 1.25),
        "speed": 420.0,
        "damage": 11.0,
        "fire_delay": 0.30,
        "shot_speed": 800.0,
        "max_health_add": 4,
        "attack_type": "explosive",
        "tear_perks": {"explosive": true},
        "dash_perks": {"slam_damage": 8.0},
        "passive": "none",
        "accessory": "carapace"
    },
    "1,1,0,0": {
        "id": "scolopendra",
        "name": "SCOLOPENDRA EARTH-CRUSHER",
        "clade": "Scolopendridae — 100-Legged Seism Titan",
        "desc": "Unstoppable 16 HP colossus: dash triggers an earthquake that stuns all room enemies for 2s.",
        "color": Color(1.2, 0.35, 0.25),
        "light_color": Color(0.9, 0.3, 0.2),
        "light_energy": 1.8,
        "scale": Vector2(1.5, 1.4),
        "speed": 410.0,
        "damage": 8.5,
        "fire_delay": 0.24,
        "shot_speed": 760.0,
        "max_health_add": 10,
        "attack_type": "single",
        "tear_perks": {"knockback": 600.0},
        "dash_perks": {"seismic": true, "slam_damage": 15.0},
        "passive": "double_iframes",
        "accessory": "carapace"
    },
    "1,1,0,1": {
        "id": "roller_titan",
        "name": "IRONCLAD ROLLER TITAN",
        "clade": "Armadillidiidae — Adamantine Ballistic Sphere",
        "desc": "Bio-Dash curls organism into an INVINCIBLE rolling boulder dealing 25 crushing damage.",
        "color": Color(0.85, 0.9, 1.1),
        "light_color": Color(0.7, 0.75, 0.85),
        "light_energy": 1.7,
        "scale": Vector2(1.45, 1.45),
        "speed": 400.0,
        "damage": 7.0,
        "fire_delay": 0.26,
        "shot_speed": 740.0,
        "max_health_add": 8,
        "attack_type": "single",
        "tear_perks": {"knockback": 500.0},
        "dash_perks": {"rolling_boulder": true, "slam_damage": 25.0},
        "passive": "double_iframes",
        "accessory": "carapace"
    },
    "1,1,1,0": {
        "id": "stomatopod_supernova",
        "name": "STOMATOPOD SUPERNOVA",
        "clade": "Gonodactylidae — Plasma Cavitation God",
        "desc": "10,000G sonoluminescent punch generating 4000°K plasma cavitation flash explosions.",
        "color": Color(1.35, 0.15, 0.75),
        "light_color": Color(1.0, 0.1, 0.6),
        "light_energy": 2.0,
        "scale": Vector2(1.3, 1.3),
        "speed": 460.0,
        "damage": 12.5,
        "fire_delay": 0.26,
        "shot_speed": 880.0,
        "max_health_add": 4,
        "attack_type": "explosive",
        "tear_perks": {"explosive": true, "stun": true, "knockback": 800.0},
        "dash_perks": {"cavitation_burst": true},
        "passive": "none",
        "accessory": "clubs"
    },
    "1,1,1,1": {
        "id": "orchid_scythe",
        "name": "ORCHID SCYTHE PREDATOR",
        "clade": "Hymenopodidae — Bladed Floral Executioner",
        "desc": "Razor crescent scythes slicing through foes: kills heal half-heart and grant +50% speed frenzy.",
        "color": Color(1.3, 0.6, 1.15),
        "light_color": Color(1.0, 0.5, 0.85),
        "light_energy": 1.8,
        "scale": Vector2(1.25, 1.25),
        "speed": 500.0,
        "damage": 9.0,
        "fire_delay": 0.18,
        "shot_speed": 900.0,
        "max_health_add": 2,
        "attack_type": "piercing",
        "tear_perks": {"piercing": true, "vampiric": true},
        "dash_perks": {"slipstream": true},
        "passive": "none",
        "accessory": "scythe"
    }
}

func _ready():
    add_to_group("player")
    update_creature_visuals()
    call_deferred("emit_all_signals")

func emit_all_signals():
    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, keys)
    dna_changed.emit(dna_biomass, 0, evolution_choices.size() + 1)
    dash_updated.emit(dash_cooldown, max_dash_cooldown)
    discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
    creature_changed.emit(current_character_name, current_character_clade, current_modulate)

func _physics_process(delta: float):
    # Dynamic redraw for animated creature anatomical accessories
    queue_redraw()

    # Cooldowns
    if shoot_cooldown > 0:
        shoot_cooldown -= delta
        
    if dash_cooldown > 0:
        dash_cooldown -= delta
        dash_updated.emit(dash_cooldown, max_dash_cooldown)
        
    if discharge_cooldown > 0:
        discharge_cooldown = max(0.0, discharge_cooldown - delta)
        discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
        
    if invincibility_time > 0:
        invincibility_time -= delta
        $Sprite2D.visible = sin(invincibility_time * 32.0) > 0.0
    else:
        $Sprite2D.visible = true
        
    if door_cooldown > 0:
        door_cooldown -= delta

    # Passive cellular oxygen regeneration (Tiktaalik, Diplocaulus)
    if current_passive == "regen" and health < max_health:
        regen_timer += delta
        if regen_timer >= regen_interval:
            regen_timer = 0.0
            heal(1)

    # Passive tear reflection (Prismatic Bastion Ammonite)
    if current_passive == "damage_reduction_plus_reflect":
        var enemy_tears = get_tree().get_nodes_in_group("enemy_tears")
        for tear in enemy_tears:
            if is_instance_valid(tear) and global_position.distance_to(tear.global_position) < 65.0:
                if not tear.get_meta("reflected", false):
                    tear.set_meta("reflected", true)
                    tear.is_enemy_tear = false
                    tear.remove_from_group("enemy_tears")
                    tear.add_to_group("tears")
                    tear.collision_layer = 8
                    tear.collision_mask = 2 + 4
                    tear.direction = -tear.direction
                    tear.velocity = tear.direction * tear.speed * 1.2
                    if tear.has_node("Sprite2D"):
                        tear.get_node("Sprite2D").modulate = Color(0.3, 1.2, 1.5)

    # 1. Movement & Bio-Hydro Dash
    var move_dir = Vector2.ZERO
    move_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    move_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
    
    if move_dir != Vector2.ZERO:
        dash_direction = move_dir.normalized()

    # Trigger Bio-Dash (Spacebar / Shift / Right-Click)
    if (Input.is_action_just_pressed("dash") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and dash_cooldown <= 0 and not is_dashing:
        perform_bio_dash()

    # Trigger Bio-Electric Discharge (E / Q / Middle-Click)
    if (Input.is_action_just_pressed("discharge") or Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE)) and discharge_cooldown <= 0:
        perform_bio_discharge()

    if is_dashing:
        dash_timer -= delta
        velocity = dash_direction * dash_speed
        move_and_slide()
        spawn_dash_particles()
        
        # Slipstream shockwave
        if current_dash_perks.get("slipstream", false):
            var enemies = get_tree().get_nodes_in_group("enemies")
            for e in enemies:
                if is_instance_valid(e) and global_position.distance_to(e.global_position) < 120.0:
                    var push = (e.global_position - global_position).normalized()
                    if e.has_method("apply_knockback"):
                        e.apply_knockback(push * 420.0, 0.25)

        # Contact dash damage (Bastion, Arthropleura, Scolopendra, Roller Titan)
        var slam_dmg = current_dash_perks.get("slam_damage", 0.0)
        if slam_dmg > 0:
            var enemies = get_tree().get_nodes_in_group("enemies")
            for e in enemies:
                if is_instance_valid(e) and global_position.distance_to(e.global_position) < 100.0:
                    if e.has_method("take_damage"):
                        e.take_damage(slam_dmg)

        # Poison acid slime trail (Eurypterid, Pulmonoscorpius, Plague Scorpion)
        if current_dash_perks.get("poison_trail", false) and randf() < 0.35:
            spawn_dash_acid_pool()

        if dash_timer <= 0:
            is_dashing = false
    else:
        velocity = move_dir.normalized() * speed
        move_and_slide()

    # Dynamic Swimming Squash & Stretch + Multi-Frame Cilia Animation
    if move_dir != Vector2.ZERO:
        swim_time += delta * 11.0
        var stretch_x = 1.0 + sin(swim_time) * 0.15
        var stretch_y = 1.0 - sin(swim_time) * 0.15
        $Sprite2D.scale = Vector2(stretch_x, stretch_y)
        $Sprite2D.rotation = lerp_angle($Sprite2D.rotation, move_dir.angle() - PI/2, delta * 9.0)
        $Sprite2D.frame = int(fmod(swim_time, 4.0))
    else:
        swim_time += delta * 3.5
        var pulse = 1.0 + sin(swim_time) * 0.06
        $Sprite2D.scale = Vector2(pulse, pulse)
        $Sprite2D.rotation = lerp_angle($Sprite2D.rotation, 0.0, delta * 8.0)
        $Sprite2D.frame = int(fmod(swim_time, 4.0))

    # 2. Shooting: 8-Direction Keyboard + Mouse Aim
    handle_shooting()

func _draw():
    # Render rich creature anatomical accessories that physically animate with swimming
    var t = swim_time
    
    match current_accessory:
        "fin":
            var fin_col = current_modulate * Color(1.2, 1.2, 1.2, 0.85)
            # Dorsal fin
            var fin_pts = PackedVector2Array([
                Vector2(-6, -26), Vector2(0, -42 - sin(t * 8.0) * 4.0), Vector2(6, -26)
            ])
            draw_colored_polygon(fin_pts, fin_col)
            # Caudal tail
            var tail_pts = PackedVector2Array([
                Vector2(-14, 26), Vector2(0, 20), Vector2(14, 26), Vector2(0, 42 + sin(t * 10.0) * 6.0)
            ])
            draw_colored_polygon(tail_pts, fin_col)
            
        "carapace":
            var shell_col = current_modulate * Color(0.8, 0.8, 0.8, 0.9)
            for r in [18.0, 24.0, 30.0]:
                draw_arc(Vector2.ZERO, r, -PI * 0.7, PI * 0.7, 12, shell_col, 3.0)
            # Lateral spines
            draw_line(Vector2(-26, -10), Vector2(-38, -16), shell_col, 3.0)
            draw_line(Vector2(26, -10), Vector2(38, -16), shell_col, 3.0)
            draw_line(Vector2(-28, 10), Vector2(-42, 14), shell_col, 3.0)
            draw_line(Vector2(28, 10), Vector2(42, 14), shell_col, 3.0)
            
        "tentacles":
            var tent_col = current_modulate * Color(1.3, 1.1, 1.4, 0.85)
            for i in range(6):
                var base_angle = (float(i) / 6.0) * TAU
                var start = Vector2(cos(base_angle), sin(base_angle)) * 22.0
                var mid = start + Vector2(cos(base_angle + sin(t * 6.0 + i) * 0.5), sin(base_angle + sin(t * 6.0 + i) * 0.5)) * 18.0
                var tip = mid + Vector2(cos(base_angle + cos(t * 8.0 + i) * 0.7), sin(base_angle + cos(t * 8.0 + i) * 0.7)) * 14.0
                draw_polyline(PackedVector2Array([start, mid, tip]), tent_col, 3.0)
                draw_circle(tip, 2.5, Color.WHITE)
                
        "shell":
            var shell_col = current_modulate * Color(1.1, 1.0, 0.8, 0.9)
            draw_arc(Vector2.ZERO, 32.0, 0, TAU, 24, shell_col, 4.0)
            draw_arc(Vector2(-6, 2), 22.0, 0, TAU * 0.85, 20, shell_col * 0.85, 3.0)
            draw_arc(Vector2(-10, 4), 14.0, 0, TAU * 0.75, 16, shell_col * 0.7, 2.5)
            
        "wings":
            var wing_col = Color(0.3, 0.95, 1.0, 0.65)
            var flutter = sin(t * 24.0) * 12.0
            draw_line(Vector2(-16, -6), Vector2(-54, -28 + flutter), wing_col, 3.0)
            draw_line(Vector2(-16, 6), Vector2(-48, 18 - flutter), wing_col, 2.5)
            draw_line(Vector2(16, -6), Vector2(54, -28 + flutter), wing_col, 3.0)
            draw_line(Vector2(16, 6), Vector2(48, 18 - flutter), wing_col, 2.5)
            
        "stinger":
            var sting_col = current_modulate * Color(0.9, 1.2, 0.8, 0.95)
            var p1 = Vector2(0, 24)
            var p2 = Vector2(sin(t * 5.0) * 6.0, 38)
            var p3 = Vector2(sin(t * 5.0) * 10.0, 52)
            var p4 = Vector2(sin(t * 5.0) * 8.0, 62)
            draw_polyline(PackedVector2Array([p1, p2, p3, p4]), sting_col, 5.0)
            draw_circle(p4, 5.5, Color(0.4, 1.0, 0.2, 1.0))
            draw_line(p4, p4 + Vector2(4, -8), Color.WHITE, 2.0)
            
        "horns":
            var horn_col = current_modulate * Color(1.1, 1.2, 1.0, 0.9)
            var left_horn = PackedVector2Array([
                Vector2(-16, -14), Vector2(-55, -2), Vector2(-22, 16)
            ])
            var right_horn = PackedVector2Array([
                Vector2(16, -14), Vector2(55, -2), Vector2(22, 16)
            ])
            draw_colored_polygon(left_horn, horn_col)
            draw_colored_polygon(right_horn, horn_col)
            
        "scythe":
            var scythe_col = current_modulate * Color(1.3, 0.8, 1.2, 0.95)
            draw_arc(Vector2(-26, -14), 22.0, -PI*0.8, -PI*0.2, 12, scythe_col, 4.0)
            draw_line(Vector2(-44, -26), Vector2(-36, -34), Color.WHITE, 2.0)
            draw_arc(Vector2(26, -14), 22.0, -PI*0.8, -PI*0.2, 12, scythe_col, 4.0)
            draw_line(Vector2(44, -26), Vector2(36, -34), Color.WHITE, 2.0)
            
        "clubs":
            var club_col = Color(1.0, 0.2, 0.6, 0.95)
            var p_l = Vector2(-22, -24 + sin(t * 8.0) * 4.0)
            var p_r = Vector2(22, -24 + sin(t * 8.0) * 4.0)
            draw_line(Vector2(-14, -10), p_l, club_col, 5.0)
            draw_line(Vector2(14, -10), p_r, club_col, 5.0)
            draw_circle(p_l, 7.0, Color(1.0, 0.9, 0.2))
            draw_circle(p_r, 7.0, Color(1.0, 0.9, 0.2))
            
        _:
            var cilia_col = current_modulate * Color(1.0, 1.0, 1.0, 0.5)
            for i in range(12):
                var a = (float(i) / 12.0) * TAU
                var p1 = Vector2(cos(a), sin(a)) * 26.0
                var p2 = p1 + Vector2(cos(a + sin(t * 7.0 + i) * 0.4), sin(a + sin(t * 7.0 + i) * 0.4)) * 9.0
                draw_line(p1, p2, cilia_col, 2.0)

func perform_bio_dash():
    is_dashing = true
    dash_timer = dash_duration
    dash_cooldown = max_dash_cooldown
    
    var iframe_dur = current_dash_perks.get("invulnerable_duration", 0.28)
    invincibility_time = iframe_dur
    
    SoundManager.play_sfx("door_open", 1.9, -1.0)
    
    # Camouflage active stealth (Phantom Cuttlefish)
    if current_dash_perks.get("camouflage", false):
        $Sprite2D.modulate.a = 0.25
        var tw = create_tween()
        tw.tween_interval(1.5)
        tw.tween_property($Sprite2D, "modulate:a", 1.0, 0.3)
    
    # Seismic Room Quake (Scolopendra Earth-Crusher)
    if current_dash_perks.get("seismic", false):
        var enemies = get_tree().get_nodes_in_group("enemies")
        for e in enemies:
            if is_instance_valid(e) and e.has_method("apply_stun"):
                e.apply_stun(2.0)
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("shake_camera"):
            main.shake_camera(18.0)
        SoundManager.play_sfx("explosion", 0.8, 3.0)

    # Cavitation Burst (Mantis, Stomatopod Supernova)
    if current_dash_perks.get("cavitation_burst", false):
        var enemies = get_tree().get_nodes_in_group("enemies")
        for e in enemies:
            if is_instance_valid(e) and global_position.distance_to(e.global_position) < 160.0:
                if e.has_method("take_damage"):
                    e.take_damage(12.0)
                if e.has_method("apply_stun"):
                    e.apply_stun(1.5)
        SoundManager.play_sfx("explosion", 1.4, 2.0)
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("shake_camera"):
            main.shake_camera(12.0)

    $Sprite2D.scale = Vector2(1.45, 0.65)
    $Sprite2D.rotation = dash_direction.angle() - PI/2

func spawn_dash_acid_pool():
    var pool = Area2D.new()
    pool.position = global_position
    pool.collision_layer = 0
    pool.collision_mask = 2
    
    var col = CollisionShape2D.new()
    var shape = CircleShape2D.new()
    shape.radius = 45.0
    col.shape = shape
    pool.add_child(col)
    
    var p = CPUParticles2D.new()
    p.amount = 14
    p.lifetime = 1.8
    p.color = Color(0.4, 1.2, 0.1, 0.8)
    p.initial_velocity_min = 5.0
    p.initial_velocity_max = 20.0
    pool.add_child(p)
    
    get_parent().add_child(pool)
    
    var timer_node = Timer.new()
    timer_node.wait_time = 0.3
    timer_node.autostart = true
    pool.add_child(timer_node)
    timer_node.timeout.connect(func():
        for body in pool.get_overlapping_bodies():
            if body.is_in_group("enemies") and body.has_method("take_damage"):
                body.take_damage(2.0)
    )
    var tw = get_tree().create_timer(3.0)
    tw.timeout.connect(func(): if is_instance_valid(pool): pool.queue_free())

func spawn_dash_particles():
    var p = CPUParticles2D.new()
    p.position = global_position
    p.emitting = true
    p.one_shot = true
    p.explosiveness = 0.85
    p.amount = 8
    p.lifetime = 0.25
    p.spread = 60.0
    p.direction = -dash_direction
    p.initial_velocity_min = 40.0
    p.initial_velocity_max = 120.0
    p.scale_amount_min = 2.0
    p.scale_amount_max = 5.5
    p.color = current_modulate * Color(1, 1, 1, 0.75)
    get_parent().add_child(p)
    var tw = get_tree().create_timer(0.3)
    tw.timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func perform_bio_discharge():
    discharge_cooldown = max_discharge_cooldown
    discharge_updated.emit(discharge_cooldown, max_discharge_cooldown)
    
    SoundManager.play_sfx("explosion", 1.8, 1.0)
    SoundManager.play_sfx("shoot", 0.7, 2.0)
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(8.0)
        
    spawn_discharge_fx()
    
    # Clear enemy projectiles
    var enemy_tears = get_tree().get_nodes_in_group("enemy_tears")
    for tear in enemy_tears:
        if is_instance_valid(tear):
            var dist = global_position.distance_to(tear.global_position)
            if dist <= discharge_radius:
                spawn_electric_spark_line(global_position, tear.global_position)
                if tear.has_method("destroy_tear"):
                    tear.destroy_tear()
                else:
                    tear.queue_free()
                    
    var all_tears = get_tree().get_nodes_in_group("tears")
    for tear in all_tears:
        if is_instance_valid(tear) and tear.get("is_enemy_tear") == true:
            if global_position.distance_to(tear.global_position) <= discharge_radius:
                spawn_electric_spark_line(global_position, tear.global_position)
                if tear.has_method("destroy_tear"):
                    tear.destroy_tear()
                else:
                    tear.queue_free()

    # Damage nearby enemies
    var enemies = get_tree().get_nodes_in_group("enemies")
    for e in enemies:
        if is_instance_valid(e):
            var dist = global_position.distance_to(e.global_position)
            if dist <= discharge_radius:
                spawn_electric_spark_line(global_position, e.global_position)
                if e.has_method("take_damage"):
                    e.take_damage(damage * 1.8)
                if e.has_method("apply_knockback"):
                    var push_dir = (e.global_position - global_position).normalized()
                    e.apply_knockback(push_dir * 500.0, 0.35)

func spawn_electric_spark_line(from_pos: Vector2, to_pos: Vector2):
    var line = Line2D.new()
    line.width = 3.5
    line.default_color = current_modulate * Color(1.2, 1.2, 1.5, 0.95)
    
    var pts = PackedVector2Array()
    var segs = 4
    for i in range(segs + 1):
        var t = float(i) / float(segs)
        var p = from_pos.lerp(to_pos, t)
        if i > 0 and i < segs:
            p += Vector2(randf_range(-14, 14), randf_range(-14, 14))
        pts.append(p)
        
    line.points = pts
    get_parent().add_child(line)
    
    var tween = create_tween()
    tween.tween_property(line, "modulate:a", 0.0, 0.16)
    tween.tween_callback(line.queue_free)

func spawn_discharge_fx():
    var ring = Line2D.new()
    ring.width = 4.0
    ring.default_color = current_modulate * Color(1.2, 1.2, 1.5, 0.9)
    var num_pts = 36
    var pts = PackedVector2Array()
    for i in range(num_pts + 1):
        var a = (float(i) / float(num_pts)) * TAU
        pts.append(Vector2(cos(a), sin(a)) * 12.0)
    ring.points = pts
    ring.position = global_position
    get_parent().add_child(ring)
    
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(ring, "scale", Vector2.ONE * (discharge_radius / 12.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "modulate:a", 0.0, 0.28)
    tween.chain().tween_callback(ring.queue_free)

func handle_shooting():
    if shoot_cooldown > 0:
        return
        
    var shoot_dir = Vector2.ZERO
    shoot_dir.x = Input.get_action_strength("shoot_right") - Input.get_action_strength("shoot_left")
    shoot_dir.y = Input.get_action_strength("shoot_down") - Input.get_action_strength("shoot_up")
    
    if shoot_dir != Vector2.ZERO:
        shoot_tear(shoot_dir.normalized())
    elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        var mouse_pos = get_global_mouse_position()
        var to_mouse = (mouse_pos - global_position).normalized()
        if to_mouse != Vector2.ZERO:
            shoot_tear(to_mouse)

func shoot_tear(dir: Vector2):
    shoot_cooldown = fire_delay
    SoundManager.play_sfx("shoot", 1.05 + randf_range(-0.08, 0.08))
    $Sprite2D.scale = Vector2(1.25, 0.8)
    
    shot_counter += 1
    var is_alpha = (shot_counter % 3 == 0) and (current_attack_type == "needle")

    match current_attack_type:
        "triple":
            for angle in [-0.22, 0.0, 0.22]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "5way":
            for angle in [-0.36, -0.18, 0.0, 0.18, 0.36]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "7way":
            for angle in [-0.48, -0.32, -0.16, 0.0, 0.16, 0.32, 0.48]:
                spawn_tear(dir.rotated(angle), is_alpha)
        "boomerang":
            for angle in [-0.15, 0.15]:
                spawn_tear(dir.rotated(angle), false, true)
        _:
            spawn_tear(dir, is_alpha)

func spawn_tear(dir: Vector2, alpha: bool = false, boomerang: bool = false):
    var tear = tear_scene.instantiate()
    tear.position = global_position
    tear.damage = damage * (2.0 if alpha else 1.0)
    tear.lifetime = range_lifetime * (1.3 if alpha else 1.0)
    tear.speed = shot_speed * (1.3 if alpha else 1.0)
    tear.velocity = dir * tear.speed + velocity * 0.25
    
    # Configure tear traits from active character archetype
    tear.is_piercing = current_tear_perks.get("piercing", false) or alpha
    tear.is_electric = current_tear_perks.get("electric", false)
    tear.is_homing = current_tear_perks.get("homing", false)
    tear.is_caustic = current_tear_perks.get("caustic", false)
    tear.is_vampiric = current_tear_perks.get("vampiric", false)
    tear.is_explosive = current_tear_perks.get("explosive", false)
    tear.is_shrapnel = current_tear_perks.get("shrapnel", false)
    tear.is_stun = current_tear_perks.get("stun", false)
    tear.is_boomerang = boomerang or current_tear_perks.get("boomerang", false)
    tear.knockback_force = current_tear_perks.get("knockback", 0.0)
    
    if tear.has_node("Sprite2D"):
        tear.get_node("Sprite2D").modulate = current_modulate * Color(1.2, 1.2, 1.2)
        if alpha:
            tear.get_node("Sprite2D").scale = Vector2(1.8, 1.8)
    
    get_parent().add_child(tear)

func add_dna(amount: int):
    dna_biomass += amount
    SoundManager.play_sfx("dna_pickup", 1.0 + (dna_biomass % 10) * 0.05)
    stats_changed.emit(dna_biomass, keys)
    dna_changed.emit(dna_biomass, 0, evolution_choices.size() + 1)

# Called by Main.gd after the player picks an evolution on the choice screen
func apply_evolution(floor_num: int, choice: int):
    evolution_choices.append(choice)
    SoundManager.play_sfx("level_up", 1.0)
    
    var path_key = ""
    var str_elements = []
    for p in evolution_choices:
        str_elements.append(str(p))
    path_key = ",".join(str_elements)
    
    if not CHARACTERS.has(path_key):
        return
        
    var data = CHARACTERS[path_key]
    current_character_id = data["id"]
    current_character_name = data["name"]
    current_character_clade = data["clade"]
    current_modulate = data["color"]
    current_accessory = data["accessory"]
    current_attack_type = data["attack_type"]
    current_tear_perks = data["tear_perks"]
    current_dash_perks = data["dash_perks"]
    current_passive = data["passive"]
    
    # Apply stats
    speed = data["speed"]
    damage = data["damage"]
    fire_delay = data["fire_delay"]
    shot_speed = data["shot_speed"]
    
    var hp_add = data.get("max_health_add", 0)
    if hp_add > 0:
        add_max_health(hp_add)
        heal(hp_add)
        
    # Flight collision mask
    if current_passive == "flight":
        set_collision_mask_value(3, false) # Fly over obstacle layer
    else:
        set_collision_mask_value(3, true)
        
    update_creature_visuals()
    
    evolution_history.append({
        "floor": floor_num,
        "title": current_character_name,
        "clade": current_character_clade,
        "choice": choice
    })
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("display_item_banner"):
        main.display_item_banner(current_character_name, data["desc"])
    
    creature_changed.emit(current_character_name, current_character_clade, current_modulate)
    dna_changed.emit(dna_biomass, 0, evolution_choices.size() + 1)
    health_changed.emit(health, max_health)

func update_creature_visuals():
    $Sprite2D.modulate = current_modulate
    if has_node("PointLight2D"):
        $PointLight2D.color = current_modulate
        $PointLight2D.energy = 1.5
    if has_node("SwimParticles"):
        $SwimParticles.color = current_modulate * Color(1, 1, 1, 0.6)

func get_evolution_summary() -> Dictionary:
    return {
        "title": current_character_name,
        "clade": current_character_clade,
        "history": evolution_history
    }

func add_coin(amount: int):
    add_dna(amount)

func take_damage(amount: int):
    if invincibility_time > 0 or is_dashing:
        return
    
    var actual_amount = amount
    
    # Passive damage reduction (Ammonite, Prismatic Ammonite)
    if (current_passive == "damage_reduction" or current_passive == "damage_reduction_plus_reflect") and actual_amount > 1:
        actual_amount = max(1, actual_amount - 1)
        
    health = max(0, health - actual_amount)
    
    # Invincibility frames (doubled for heavy carapace)
    invincibility_time = 2.0 if current_passive == "double_iframes" else 1.0
    
    SoundManager.play_sfx("player_hurt", 1.0)
    $Sprite2D.scale = Vector2(0.7, 1.4)
    
    # White flash tween
    $Sprite2D.modulate = Color(2.5, 2.5, 2.5, 1.0)
    var flash_tween = create_tween()
    flash_tween.tween_property($Sprite2D, "modulate", current_modulate, 0.25)
    
    var main = get_tree().get_first_node_in_group("main")
    if main and main.has_method("shake_camera"):
        main.shake_camera(9.0)
        
    # Retaliatory spine darts (Trilobita)
    if current_passive == "retaliatory_spines":
        for angle_deg in [0, 90, 180, 270]:
            var a = deg_to_rad(angle_deg)
            spawn_tear(Vector2(cos(a), sin(a)))
        
    health_changed.emit(health, max_health)
    
    if health <= 0:
        die()

func heal(amount: int):
    health = min(max_health, health + amount)
    SoundManager.play_sfx("heart_pickup", 1.0)
    health_changed.emit(health, max_health)

func add_max_health(amount: int):
    max_health += amount
    health += amount
    SoundManager.play_sfx("heart_pickup", 1.1)
    health_changed.emit(health, max_health)

func add_key(amount: int):
    keys = min(99, keys + amount)
    SoundManager.play_sfx("dna_pickup", 0.9)
    stats_changed.emit(dna_biomass, keys)

func apply_item_upgrade(item_id: String):
    if item_id == "onion":
        fire_delay = max(0.08, fire_delay - 0.08)
    elif item_id == "eye":
        current_attack_type = "triple"
        fire_delay = fire_delay * 1.15
    elif item_id == "hormones":
        damage += 2.0
        speed += 50.0
    elif item_id == "cells":
        add_max_health(2)
        heal(2)
        
    health_changed.emit(health, max_health)
    stats_changed.emit(dna_biomass, keys)

func die():
    SoundManager.play_sfx("player_hurt", 0.7)
    player_died.emit()
    set_physics_process(false)
    set_process(false)
    
    var burst = CPUParticles2D.new()
    burst.position = global_position
    burst.amount = 48
    burst.lifetime = 1.2
    burst.one_shot = true
    burst.explosiveness = 0.95
    burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
    burst.emission_sphere_radius = 10.0
    burst.initial_velocity_min = 80.0
    burst.initial_velocity_max = 320.0
    burst.gravity = Vector2(0, 0)
    burst.scale_amount_min = 3.0
    burst.scale_amount_max = 8.0
    burst.color = current_modulate * Color(1, 1, 1, 0.9)
    get_parent().add_child(burst)
    burst.restart()
    
    var tween = create_tween()
    tween.tween_property($Sprite2D, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.5)
