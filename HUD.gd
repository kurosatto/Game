# HUD.gd
extends CanvasLayer

signal evolution_selected(floor_num: int, choice_index: int)

const ERA_NAMES = {
    1: "ERA 1: EDIACARAN SOUP (600 MYA)",
    2: "ERA 2: CAMBRIAN RADIANCE (540 MYA)",
    3: "ERA 3: DEVONIAN WATERS (420 MYA)",
    4: "ERA 4: CARBONIFEROUS SWAMPS (350 MYA)",
    5: "ERA 5: APEX EXTINCTION BOUNDARY (250 MYA)"
}

# 15 branching fork nodes: 1 at Floor 1, 2 at Floor 2, 4 at Floor 3, 8 at Floor 4.
# Leads into 16 unique Apex Playable Characters on Floor 5 (31 total characters across game).
const EVOLUTION_TREE = {
    # ═══ FLOOR 1 COMPLETE: Root Speciation (Path "") ═══
    "": {
        "era_title": "ERA 1 COMPLETE — EDIACARAN SOUP",
        "subtitle": "The Dawn of Multicellularity: Select your fundamental body plan:",
        "choice_a": {
            "id": "pikaia",
            "title": "NOTOCHORD & DORSAL AXIS",
            "clade": "Lineage: Phylum Chordata (Pikaia Vertebrata)",
            "desc": "The ancestral flexible dorsal notochord that established the spine of all vertebrates. Unlocks rapid linear propulsion and concussive slipstreams.",
            "perks": "⚡ +80 Movement Speed & +100 Shot Speed\n💨 Dash leaves a hydrodynamic slipstream shockwave\n🎯 Agile streamlined swimming",
            "color": Color(0.0, 0.9, 1.0)
        },
        "choice_b": {
            "id": "trilobita",
            "title": "CHITINOUS CUTICLE CARAPACE",
            "clade": "Lineage: Phylum Arthropoda (Proto-Trilobita)",
            "desc": "Hardened, protein-linked mineralized calcite cuticle forming an external shell against predators. Unlocks defensive retaliatory spine darts.",
            "perks": "❤️ +2 Max HP Containers (Heals 2 Hearts)\n🛡️ Ejects 4 defensive calcified darts whenever damaged\n🪨 Heavy damage resistance",
            "color": Color(1.0, 0.75, 0.2)
        }
    },
    
    # ═══ FLOOR 2 COMPLETE: Second Speciation (Paths "0" & "1") ═══
    "0": {
        "era_title": "ERA 2 COMPLETE — CAMBRIAN RADIANCE",
        "subtitle": "Chordate Speciation: Select your predatory specialization:",
        "choice_a": {
            "id": "dunkleosteus",
            "title": "MINERALIZED CRANIAL JAWS",
            "clade": "Lineage: Placodermi (Dunkleosteus Jaws)",
            "desc": "The revolutionary leap of hinged biting jaws and cranial bone casing, creating the first true vertebrate apex predators.",
            "perks": "⚔️ +3.0 Tear Damage (6.5 base dmg!)\n💥 Heavy concussive knockback on all tear hits\n🦷 Tears crush enemy armor",
            "color": Color(1.0, 0.3, 0.35)
        },
        "choice_b": {
            "id": "nautiloid",
            "title": "SIPHON JET & TENTACLE ARMS",
            "clade": "Lineage: Cephalopoda (Ancient Nautiloid)",
            "desc": "Multi-directional jet siphon propulsion paired with prehensile grasping tentacles for maximum projectile coverage.",
            "perks": "🎯 Triple-Shot spread attack\n🧲 Magnetic homing tears steer toward closest enemies\n💨 Hydrodynamic swimming",
            "color": Color(0.0, 1.0, 0.8)
        }
    },
    "1": {
        "era_title": "ERA 2 COMPLETE — CAMBRIAN RADIANCE",
        "subtitle": "Arthropod Speciation: Select your chitinous adaptation:",
        "choice_a": {
            "id": "eurypterid",
            "title": "NEUROTOXIC CHELICERAL STINGER",
            "clade": "Lineage: Chelicerata (Eurypterid Sea Scorpion)",
            "desc": "Razor grasping appendages paired with a venomous tail barb. Injects corrosive biochemical enzymes that liquefy prey.",
            "perks": "🧪 Tears inflict lingering neurotoxic acid pools\n⚡ Bio-discharge releases a 360° venom shockwave\n⚔️ +1.5 Tear Damage",
            "color": Color(0.3, 1.0, 0.3)
        },
        "choice_b": {
            "id": "bastion",
            "title": "CALCIFIED THORACIC BASTION",
            "clade": "Lineage: Dinocaridida (Anomalocarid Bastion)",
            "desc": "Thick interlocking thoracic plates providing impenetrable defense, paired with massive crushing appendages.",
            "perks": "❤️ +3 Max HP Containers (Heals 3 Hearts)\n🛡️ Post-hit invincibility doubled to 2.0 seconds\n💥 Bio-Dash deals 10 heavy contact damage to enemies",
            "color": Color(0.9, 0.7, 0.2)
        }
    },

    # ═══ FLOOR 3 COMPLETE: Third Speciation (4 Nodes) ═══
    "0,0": {
        "era_title": "ERA 3 COMPLETE — DEVONIAN WATERS",
        "subtitle": "Placoderm Speciation: Select your aquatic dominion:",
        "choice_a": {
            "id": "tiktaalik",
            "title": "TETRAPOD LUNGS & ROBUST LIMBS",
            "clade": "Lineage: Tetrapodomorpha (Tiktaalik Shorewalker)",
            "desc": "First breath of atmospheric air! Muscular fin-limbs with distinct digits capable of crawling from shallows onto land.",
            "perks": "❤️ +2 Max HP Containers (Heals 2 Hearts)\n🌿 Passive cellular oxygen regeneration (1 half-heart / 10s)\n⚔️ Muscular Fin-Dart Volley (+2.0 Damage)",
            "color": Color(0.2, 1.0, 0.5)
        },
        "choice_b": {
            "id": "cladoselache",
            "title": "PELAGIC DORSAL FIN & AMPULLAE",
            "clade": "Lineage: Chondrichthyes (Cladoselache Swift-Shark)",
            "desc": "Streamlined cartilaginous body and electro-receptive ampullae sensing minute bio-electrical impulses of nearby prey.",
            "perks": "⚡ Tears chain high-voltage electric arcs between foes\n💨 +80 Movement Speed & +150 Shot Speed\n🩸 Blood Frenzy: +25% Fire Rate on consecutive hits",
            "color": Color(0.2, 0.85, 1.0)
        }
    },
    "0,1": {
        "era_title": "ERA 3 COMPLETE — DEVONIAN WATERS",
        "subtitle": "Cephalopod Speciation: Select your marine supremacy:",
        "choice_a": {
            "id": "kraken",
            "title": "ABYSSAL BIOLUMINESCENT TENTACLES",
            "clade": "Lineage: Coleoidea (Abyssal Kraken Squid)",
            "desc": "Titanic deep-ocean cephalopod with ten powerful tentacles, pressurized ink jets, and bioluminescent lure organs.",
            "perks": "🎯 5-Way Omnidirectional spread barrage\n🧲 Enhanced magnetic homing on all 5 projectiles\n💨 Ink Jet Dash leaves blinding smoke clouds that slow foes",
            "color": Color(0.7, 0.3, 1.0)
        },
        "choice_b": {
            "id": "ammonite",
            "title": "CHAMBERED SUTURE CITADEL",
            "clade": "Lineage: Ammonoidea (Spherical Ammonite Fortress)",
            "desc": "A heavy mathematical golden-ratio shell with fractal suture lines engineered to withstand crushing hydrostatic pressure.",
            "perks": "🛡️ Rigid Septal Wall: Reduces all incoming damage by 1!\n❤️ +2 Max HP Containers\n⚡ Bio-discharge radius increased by +75%",
            "color": Color(1.0, 0.85, 0.3)
        }
    },
    "1,0": {
        "era_title": "ERA 3 COMPLETE — DEVONIAN WATERS",
        "subtitle": "Chelicerate Speciation: Select your terrestrial or aerial expansion:",
        "choice_a": {
            "id": "pulmonoscorpius",
            "title": "GARGANTUAN CAUSTIC METASOMA",
            "clade": "Lineage: Scorpiones (Pulmonoscorpius Titan)",
            "desc": "One-meter terrestrial scorpion with high-pressure venom reservoirs and chitin-crushing pedipalps.",
            "perks": "🧪 Caustic Acid Slime: Tears create lingering burning pools\n⚡ Discharge cooldown reduced to 2.2s with toxic blast\n💨 Dash leaves an acid slime trail damaging chasers",
            "color": Color(0.4, 1.0, 0.2)
        },
        "choice_b": {
            "id": "meganeura",
            "title": "TRACHEAL HYPER-OXYGENATED WINGS",
            "clade": "Lineage: Meganisoptera (Meganeura Dragonfly Titan)",
            "desc": "High-oxygen Carboniferous atmosphere fuels a 2.5-foot wingspan predator capable of agile aerial dogfights.",
            "perks": "🪶 TRUE FLIGHT: Glides freely over rocks, water & obstacles!\n💨 +120 Movement Speed & +40% Rapid Fire Rate\n🌪️ Every 3rd shot launches a hyper-velocity gale dart",
            "color": Color(0.0, 1.0, 0.9)
        }
    },
    "1,1": {
        "era_title": "ERA 3 COMPLETE — DEVONIAN WATERS",
        "subtitle": "Carapace Speciation: Select your armored offensive evolution:",
        "choice_a": {
            "id": "arthropleura",
            "title": "SEGMENTED DORSAL TERGITES",
            "clade": "Lineage: Myriapoda (Arthropleura Centipede Titan)",
            "desc": "Two-meter millipede colossus with 30 armored body rings and interlocking plates capable of trampling undergrowth.",
            "perks": "❤️ +4 Max HP Containers (Massive 14 HP pool!)\n💥 Trampling Dash: Slams directly through enemies for 12 dmg\n🦷 Heavy concussive mandibles crush enemy armor",
            "color": Color(0.95, 0.45, 0.2)
        },
        "choice_b": {
            "id": "mantis",
            "title": "SPRING-LOADED DACTYL CLUBS",
            "clade": "Lineage: Stomatopoda (Mantis Shrimp Cavitator)",
            "desc": "Biological hammer appendages that accelerate at 10,000G, creating underwater cavitation shockwaves hotter than the sun.",
            "perks": "⚔️ +5.0 Massive Tear Damage (9.5 base dmg!)\n💥 Cavitation Shockwave: High knockback & stun on hits\n⚡ Rapid spring-loaded strike cadence",
            "color": Color(1.0, 0.2, 0.5)
        }
    },

    # ═══ FLOOR 4 COMPLETE: Fourth Speciation (8 Nodes -> 16 Apex Forms!) ═══
    "0,0,0": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Tetrapod Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "gorgonopsid",
            "title": "SABER-FANGED THERAPSID DENTITION",
            "clade": "Lineage: Synapsida (Gorgonopsid — Proto-Mammal Sovereign)",
            "desc": "The crowning apex predator of the Permian. Four-inch saber canine teeth and an endothermic predatory sprint.",
            "perks": "⚔️ +4.0 Tear Damage & Heavy Armor Piercing\n🩸 Vampiric Leech: 30% chance on tear hit to heal half-heart\n⚡ Bio-discharge emits a feral soul-draining predator roar",
            "color": Color(1.0, 0.4, 0.15)
        },
        "choice_b": {
            "id": "diplocaulus",
            "title": "AERODYNAMIC HYDROFOIL CEPHALON",
            "clade": "Lineage: Lepospondyli (Diplocaulus Boomerang Amphibian)",
            "desc": "Massive lateral cheek horns forming a hydrodynamic boomerang wing that channels fluid dynamics for twin piercing projectiles.",
            "perks": "🪃 Boomerang Projectiles: Tears arc out, pierce foes, and return to you!\n💨 +70 Movement Speed & Double Dash charges\n🌿 Enhanced cellular oxygen regeneration (1 heart / 8s)",
            "color": Color(0.2, 1.0, 0.7)
        }
    },
    "0,0,1": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Chondrichthyes Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "megalodon",
            "title": "SERRATED MEGALODON DENTITION",
            "clade": "Lineage: Otodontidae (Megalodon Leviathan)",
            "desc": "The greatest marine apex predator in history. Seven-inch serrated triangular teeth that shear through ancient whales.",
            "perks": "🏹 Razor Serrated Jaws: Tears pierce ALL enemies indefinitely\n⚡ Chained Lightning: Electrical arcs chain through entire rooms\n💨 +90 Movement Speed & +200 Shot Speed",
            "color": Color(0.1, 0.7, 1.0)
        },
        "choice_b": {
            "id": "mosasaur",
            "title": "PTERYGOID JAWS & TIDAL FLUKES",
            "clade": "Lineage: Mosasauridae (Mosasaurus Ocean Tyrant)",
            "desc": "Gargantuan marine reptile with double-hinged jaws and an undulating hypocercal tail capable of shattering fleets.",
            "perks": "💥 Shrapnel Fangs: Tears shatter into 4 secondary razor teeth\n🌊 Tidal Tail-Whip: Bio-Dash slams enemies for 14 damage\n❤️ +3 Max HP Containers",
            "color": Color(0.1, 0.95, 0.8)
        }
    },
    "0,1,0": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Coleoid Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "architeuthis",
            "title": "ABYSSAL VOID JET & CRUSHING SUCKERS",
            "clade": "Lineage: Architeuthidae (Architeuthis Void Sovereign)",
            "desc": "Titanic monarch of the midnight trenches. Ten prehensile tentacles firing 7-way pressurized siphon beams.",
            "perks": "🎯 7-Way Omnidirectional spread barrage\n🌌 Void Singularity: Tears pull enemies toward impact center\n🧲 Maximum magnetic homing curvature on all shots",
            "color": Color(0.8, 0.2, 1.0)
        },
        "choice_b": {
            "id": "cuttlefish",
            "title": "CHROMATOPHORE OPTICAL CAMOUFLAGE",
            "clade": "Lineage: Sepiida (Phantom Cuttlefish)",
            "desc": "Millions of pigment cells and iridophores creating instant active cloaking and hypnotic chromatic pulse waves.",
            "perks": "👻 Stealth Camouflage: Bio-Dash renders you INVISIBLE & INVULNERABLE for 1.5s!\n⚡ Hypnotic Pulse: Tears confuse & stun enemies for 1.2s\n🔥 +45% Rapid Fire Rate",
            "color": Color(0.3, 1.0, 0.9)
        }
    },
    "0,1,1": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Ammonite Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "sphenodiscus",
            "title": "OXYCONIC SHRAPNEL BLAST-SHELL",
            "clade": "Lineage: Sphenodiscidae (Sphenodiscus Blast Shell)",
            "desc": "Ultra-compressed knife-edge keel shell loaded with pressurized gas chambers that explode into razor calcite flechettes.",
            "perks": "💥 Shatter Flechettes: Every tear hit bursts into 4 ricocheting shell shards!\n⚡ Bio-discharge emits a 360° razor calcite shrapnel nova\n⚔️ +3.0 Tear Damage",
            "color": Color(1.0, 0.8, 0.2)
        },
        "choice_b": {
            "id": "prismatic_ammonite",
            "title": "PRISMATIC DIAMOND BULWARK",
            "clade": "Lineage: Pachydiscidae (Prismatic Bastion Ammonite)",
            "desc": "Dense crystalline nacreous aragonite forming an unbreakable pearlescent prism that refracts all incoming kinetic force.",
            "perks": "💎 Kinetic Reflection: Passively reflects 50% of enemy shots as friendly tears!\n🛡️ Rigid Shield: Reduces all incoming damage by 1 (minimum 1)\n❤️ +4 Max HP Containers (Heals 4 Hearts)",
            "color": Color(0.9, 0.95, 1.0)
        }
    },
    "1,0,0": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Scorpiones Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "plague_scorpion",
            "title": "CORROSIVE PLAGUE RESERVOIRS",
            "clade": "Lineage: Heterometrinae (Emperor Plague Scorpion)",
            "desc": "Concentrated necrotic enzymes that melt organic tissue on contact and infect whole groups of predators.",
            "perks": "🧪 Corrosive Plague: Poisoned enemies explode into toxic clouds upon death!\n🔥 Burning acid pools deal 2x damage and last 4 seconds\n⚡ Bio-discharge coats the entire room in toxic miasma",
            "color": Color(0.4, 1.0, 0.1)
        },
        "choice_b": {
            "id": "trapdoor_spider",
            "title": "AMBUSH SPINNERETS & RETRACTABLE CHELICERAE",
            "clade": "Lineage: Araneae (Trapdoor Silk Reaper)",
            "desc": "High-tensile protein silk glands and subterranean ambush sensory hairs detecting microscopic floor vibrations.",
            "perks": "🕸️ Ensnaring Web: Tears pin enemies in place for 1.5 seconds\n💨 Bio-Dash leaves a sticky web snare that strangles enemies\n⚔️ Ambush Strike: +100% damage to immobilized targets",
            "color": Color(0.7, 0.6, 0.9)
        }
    },
    "1,0,1": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Insecta Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "meganeuropsis",
            "title": "SUPERSONIC CORONA WINGS",
            "clade": "Lineage: Meganeuridae (Meganeuropsis Supersonic Ace)",
            "desc": "The largest flying insect ever known. High-velocity aerodynamic wing dynamics capable of supersonic aerial dives.",
            "perks": "🪶 TRUE FLIGHT: Immune to ground hazards, rocks & obstacles\n💨 +160 Movement Speed (580 max speed!)\n🏹 Machine-Gun Cadence: Ultra rapid fire (0.10s delay) with piercing needle darts",
            "color": Color(0.1, 1.0, 0.8)
        },
        "choice_b": {
            "id": "bombardier",
            "title": "PYROTECHNIC HYDROQUINONE CANNON",
            "clade": "Lineage: Carabidae (Pyrotechnic Bombardier Beetle)",
            "desc": "Twin chemical reaction chambers mixing hydrogen peroxide and hydroquinones into boiling 100°C explosive artillery volleys.",
            "perks": "💣 High-Explosive Shells: Tears DETONATE on contact dealing massive radius damage!\n🔥 Leaves burning thermal craters that scorch enemies\n💥 Screen-shaking artillery impact",
            "color": Color(1.0, 0.35, 0.05)
        }
    },
    "1,1,0": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Myriapoda Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "scolopendra",
            "title": "SEISMIC TERGITE EARTH-CRUSHER",
            "clade": "Lineage: Scolopendridae (Scolopendra Earth-Crusher)",
            "desc": "A hundred armored claws marching in rhythmic seismic resonance, shattering subterranean rock formations.",
            "perks": "❤️ +6 Max HP Containers (Unstoppable 16 HP juggernaut!)\n🌍 Seismic Quake: Bio-Dash causes an earthquake that stuns all room enemies for 2s!\n💥 Ramming deals 15 crushing damage to anything in your path",
            "color": Color(0.9, 0.3, 0.2)
        },
        "choice_b": {
            "id": "roller_titan",
            "title": "BALLISTIC ADAMANTINE SPHERE",
            "clade": "Lineage: Armadillidiidae (Ironclad Roller Titan)",
            "desc": "Segmented interlocking titanium-chitin plates that lock into an impenetrable ballistic kinetic wrecking ball.",
            "perks": "🛡️ Ballistic Rolling Ball: Bio-Dash curls into an INVINCIBLE boulder for 25 damage!\n🛡️ Double Invincibility Frames (2.0s post-hit)\n❤️ +4 Max HP Containers",
            "color": Color(0.7, 0.75, 0.85)
        }
    },
    "1,1,1": {
        "era_title": "ERA 4 COMPLETE — CARBONIFEROUS SWAMPS",
        "subtitle": "Stomatopoda Zenith: Select your Apex Floor 5 Creature:",
        "choice_a": {
            "id": "stomatopod_supernova",
            "title": "PLASMA CAVITATION SUPERNOVA",
            "clade": "Lineage: Gonodactylidae (Stomatopod Supernova)",
            "desc": "Club acceleration so violent it generates incandescent 4000°K sonoluminescent plasma flash explosions underwater.",
            "perks": "⚔️ Massive +6.0 Tear Damage (Base 11.5 damage!)\n💥 Supernova Blast: Tears create blinding plasma explosions on impact\n⚡ High stun and concussive shockwave knockback",
            "color": Color(1.0, 0.1, 0.6)
        },
        "choice_b": {
            "id": "orchid_scythe",
            "title": "SERRATED FLORAL EXECUTIONER SCYTHES",
            "clade": "Lineage: Hymenopodidae (Orchid Scythe Predator)",
            "desc": "Femoral spine teeth and razor raptorial scythes that decapitate targets with lightning-fast kinetic efficiency.",
            "perks": "⚔️ Razor Crescent Scythes: Tears slice through multiple foes with critical bleed\n🩸 Executioner's Surge: Kills heal half-heart and grant +50% speed burst for 3s\n💨 Sleek predatory dash cadence",
            "color": Color(1.0, 0.5, 0.85)
        }
    }
}

var evolution_modal: Control = null

@onready var coins_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Coins/Label

@onready var keys_label = $HUDPanel/MarginContainer/HBoxContainer/Counters/Keys/Label
@onready var hearts_container = $HUDPanel/MarginContainer/HBoxContainer/Hearts
@onready var floor_label = $HUDPanel/MarginContainer/HBoxContainer/FloorLabel
@onready var dna_label = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaLabel
@onready var dna_bar = $HUDPanel/MarginContainer/HBoxContainer/DnaContainer/DnaBar
@onready var ability_label = $HUDPanel/MarginContainer/HBoxContainer/AbilityContainer/AbilityLabel
@onready var ability_bar = $HUDPanel/MarginContainer/HBoxContainer/AbilityContainer/AbilityBar
@onready var settings_btn = $HUDPanel/MarginContainer/HBoxContainer/SettingsBtn

@onready var minimap_ctrl = $MinimapContainer/Minimap

@onready var boss_container = $BossHealthContainer
@onready var boss_bar = $BossHealthContainer/ProgressBar
@onready var boss_name_label = $BossHealthContainer/Label

@onready var item_banner = $ItemBanner
@onready var item_title = $ItemBanner/Title
@onready var item_desc = $ItemBanner/Desc

# Settings Modal Nodes
@onready var settings_modal = $SettingsModal
@onready var brightness_label = $SettingsModal/Panel/Margin/VBox/BrightnessSection/BrightnessLabel
@onready var brightness_slider = $SettingsModal/Panel/Margin/VBox/BrightnessSection/BrightnessSlider
@onready var display_option = $SettingsModal/Panel/Margin/VBox/DisplaySection/DisplayOption
@onready var volume_label = $SettingsModal/Panel/Margin/VBox/VolumeSection/VolumeLabel
@onready var volume_slider = $SettingsModal/Panel/Margin/VBox/VolumeSection/VolumeSlider
@onready var resume_btn = $SettingsModal/Panel/Margin/VBox/ResumeBtn

@onready var game_over_screen = $GameOverScreen
@onready var victory_screen = $VictoryScreen

var heart_full_tex = preload("res://assets/pickup_heart.png")
var heart_half_tex = preload("res://assets/pickup_heart_half.png")
var heart_empty_tex = preload("res://assets/pickup_heart_empty.png")

# Minimap data
var dungeon_rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i(4, 4)

func _ready():
    boss_container.visible = false
    item_banner.visible = false
    game_over_screen.visible = false
    victory_screen.visible = false
    settings_modal.visible = false
    clear_hearts()
    
    if minimap_ctrl:
        minimap_ctrl.draw.connect(_on_minimap_draw)
        
    setup_settings_ui()

func setup_settings_ui():
    settings_btn.pressed.connect(toggle_settings)
    resume_btn.pressed.connect(toggle_settings)
    
    # Initialize display options (1080p Standard)
    display_option.clear()
    display_option.add_item("Windowed (1280 x 720 - HD)", 0)
    display_option.add_item("Windowed (1920 x 1080 - 1080p Full HD Default)", 1)
    display_option.add_item("Windowed (2560 x 1440 - 2K QHD)", 2)
    display_option.add_item("Fullscreen Mode", 3)
    display_option.select(SettingsManager.window_mode_index)
    display_option.item_selected.connect(_on_display_mode_selected)
    
    # Initialize brightness slider
    brightness_slider.value = SettingsManager.brightness
    update_brightness_label(SettingsManager.brightness)
    brightness_slider.value_changed.connect(_on_brightness_changed)
    
    # Initialize volume slider
    volume_slider.value = SettingsManager.sfx_volume
    update_volume_label(SettingsManager.sfx_volume)
    volume_slider.value_changed.connect(_on_volume_changed)

func _unhandled_input(event: InputEvent):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            toggle_settings()

func toggle_settings():
    settings_modal.visible = not settings_modal.visible
    get_tree().paused = settings_modal.visible
    
    if not settings_modal.visible:
        SettingsManager.save_settings()

func _on_brightness_changed(val: float):
    SettingsManager.set_brightness(val)
    update_brightness_label(val)

func update_brightness_label(val: float):
    brightness_label.text = "🔆 Brightness: %d%%" % int(val * 100)

func _on_display_mode_selected(index: int):
    SettingsManager.set_window_mode(index)

func _on_volume_changed(val: float):
    SettingsManager.set_sfx_volume(val)
    update_volume_label(val)

func update_volume_label(val: float):
    volume_label.text = "🔊 SFX Volume: %d%%" % int(val * 100)

func clear_hearts():
    for child in hearts_container.get_children():
        child.queue_free()

func update_health(health: int, max_health: int):
    clear_hearts()
    
    var full_hearts = health / 2
    var half_heart = health % 2 == 1
    var total_containers = max_health / 2
    
    for i in range(total_containers):
        var heart_rect = TextureRect.new()
        heart_rect.custom_minimum_size = Vector2(36, 36)
        heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        
        if i < full_hearts:
            heart_rect.texture = heart_full_tex
        elif i == full_hearts and half_heart:
            heart_rect.texture = heart_half_tex
        else:
            heart_rect.texture = heart_empty_tex
            
        hearts_container.add_child(heart_rect)

func update_inventory(dna: int, keys: int):
    coins_label.text = "%02d" % dna
    keys_label.text = "%02d" % keys

func update_dna(current_dna: int, max_dna: int, level: int):
    dna_label.text = "BIOMASS: %d / %d (LVL %d)" % [current_dna, max_dna, level]
    dna_bar.max_value = max_dna
    dna_bar.value = current_dna

func update_discharge_cooldown(current_cd: float, max_cd: float):
    if not is_instance_valid(ability_label) or not is_instance_valid(ability_bar):
        return
    if current_cd <= 0.0:
        ability_bar.value = 1.0
        ability_label.text = "⚡ [E / MMB] DISCHARGE: READY"
        ability_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.9, 1.0))
    else:
        var ratio = 1.0 - (current_cd / max(0.001, max_cd))
        ability_bar.value = ratio
        ability_label.text = "⚡ [E] RECHARGING (%.1fs)" % current_cd
        ability_label.add_theme_color_override("font_color", Color(0.4, 0.75, 0.85, 0.85))

var current_creature_name: String = "PRIMORDIAL PROTOZOA"

func set_current_creature(creature_name: String):
    current_creature_name = creature_name

func update_floor(floor_num: int):
    var era_str = ERA_NAMES.get(floor_num, "ERA %d" % floor_num)
    floor_label.text = "%s | 🧬 %s" % [era_str, current_creature_name]

func update_minimap(rooms: Dictionary, current_pos: Vector2i):
    dungeon_rooms = rooms
    current_room_pos = current_pos
    if minimap_ctrl:
        minimap_ctrl.queue_redraw()

func _on_minimap_draw():
    if dungeon_rooms.is_empty():
        return
        
    var center_screen = minimap_ctrl.size / 2.0
    var cell_size = Vector2(22, 16)
    var gap = Vector2(4, 4)
    var step = cell_size + gap
    
    minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, minimap_ctrl.size), Color(0.04, 0.08, 0.14, 0.75), true)
    minimap_ctrl.draw_rect(Rect2(Vector2.ZERO, minimap_ctrl.size), Color(0.0, 0.7, 0.9, 0.5), false, 2.0)
    
    for pos in dungeon_rooms:
        var r_data = dungeon_rooms[pos]
        var is_current = (pos == current_room_pos)
        var is_visited = r_data.visited
        
        var is_adjacent = false
        for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
            var n_pos = pos + d
            if dungeon_rooms.has(n_pos) and dungeon_rooms[n_pos].visited:
                is_adjacent = true
                break
                
        if not is_visited and not is_adjacent:
            continue
            
        var offset_grid = pos - current_room_pos
        var draw_pos = center_screen + Vector2(offset_grid.x * step.x, offset_grid.y * step.y) - (cell_size / 2.0)
        var rect = Rect2(draw_pos, cell_size)
        
        var room_col = Color(0.15, 0.25, 0.35, 0.7)
        if is_visited:
            room_col = Color(0.25, 0.45, 0.65, 0.9)
            
        minimap_ctrl.draw_rect(rect, room_col, true)
        
        if is_visited or is_adjacent:
            if r_data.type == 3: # BOSS
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.5, Color(1.0, 0.2, 0.3, 1.0))
            elif r_data.type == 2: # TREASURE / MUTATION
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, Color(0.0, 1.0, 0.8, 1.0))
            elif r_data.type == 4: # SHOP / SHRINE
                minimap_ctrl.draw_circle(draw_pos + cell_size/2.0, 4.0, Color(1.0, 0.85, 0.2, 1.0))
                
        if is_current:
            minimap_ctrl.draw_rect(rect, Color(0.0, 1.0, 1.0, 1.0), false, 2.5)
        else:
            minimap_ctrl.draw_rect(rect, Color(0.1, 0.2, 0.3, 0.8), false, 1.0)

func show_boss_health(current: float, max_value: float, boss_title: String = ""):
    boss_container.visible = true
    boss_bar.max_value = max_value
    boss_bar.value = current
    if boss_title != "" and boss_name_label:
        boss_name_label.text = boss_title
    if current <= 0:
        boss_container.visible = false

func hide_boss_health():
    boss_container.visible = false

func show_item_banner(title: String, desc: String):
    item_banner.visible = true
    item_title.text = title
    item_desc.text = desc
    item_banner.modulate.a = 1.0
    var tween = create_tween()
    tween.tween_property(item_banner, "modulate:a", 0.0, 0.4).set_delay(1.8)
    tween.tween_callback(func(): item_banner.visible = false)

func show_game_over():
    game_over_screen.visible = true
    
func show_victory(summary: Dictionary = {}):
    victory_screen.visible = true
    var label = $VictoryScreen/Center/Label
    var sublabel = $VictoryScreen/Center/SubLabel
    if summary.is_empty():
        label.text = "600 MILLION YEARS OF EVOLUTION COMPLETE!"
        sublabel.text = "Your lineage dominated Earth through all 7 geological epochs!"
    else:
        label.text = "APEX EVOLUTION: VICTORY!"
        var text = "Final Evolved Lineage: " + summary.get("title", "Apex Organism") + "\n"
        text += summary.get("clade", "") + "\n\nPhylogenetic Path Across Earth's Eras:\n"
        for h in summary.get("history", []):
            text += "• Era %d: %s (%s)\n" % [h["floor"], h["title"], h["clade"]]
        sublabel.text = text

func show_evolution_modal(floor_num: int, current_path: Array = []):
    var path_key = ""
    if current_path.size() > 0:
        var str_elements = []
        for p in current_path:
            str_elements.append(str(p))
        path_key = ",".join(str_elements)
        
    if not EVOLUTION_TREE.has(path_key):
        if EVOLUTION_TREE.has(""):
            path_key = ""
        else:
            return
            
    _create_evolution_modal()
    var def = EVOLUTION_TREE[path_key]
    
    var header = evolution_modal.get_node("CenterBox/Header") as Label
    var subheader = evolution_modal.get_node("CenterBox/SubHeader") as Label
    header.text = "🧬 " + def["era_title"]
    subheader.text = def["subtitle"]
    
    var cards_row = evolution_modal.get_node("CenterBox/CardsRow") as HBoxContainer
    for c in cards_row.get_children():
        c.queue_free()
        
    _build_choice_card(cards_row, floor_num, 0, def["choice_a"])
    _build_choice_card(cards_row, floor_num, 1, def["choice_b"])
    
    evolution_modal.visible = true
    get_tree().paused = true

func _create_evolution_modal():
    if evolution_modal:
        return
        
    evolution_modal = Control.new()
    evolution_modal.name = "EvolutionModal"
    evolution_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
    evolution_modal.visible = false
    evolution_modal.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(evolution_modal)
    
    var bg = ColorRect.new()
    bg.name = "Backdrop"
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = Color(0.02, 0.04, 0.08, 0.95)
    evolution_modal.add_child(bg)
    
    var center_box = VBoxContainer.new()
    center_box.name = "CenterBox"
    center_box.set_anchors_preset(Control.PRESET_CENTER)
    center_box.custom_minimum_size = Vector2(1640, 860)
    center_box.position = Vector2(140, 110)
    center_box.alignment = BoxContainer.ALIGNMENT_CENTER
    center_box.add_theme_constant_override("separation", 24)
    evolution_modal.add_child(center_box)
    
    var header = Label.new()
    header.name = "Header"
    header.text = "🧬 EPOCH TRANSCENDED: GEOLOGICAL EVOLUTION"
    header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    header.add_theme_font_size_override("font_size", 40)
    header.add_theme_color_override("font_color", Color(0.0, 1.0, 0.85))
    center_box.add_child(header)
    
    var subheader = Label.new()
    subheader.name = "SubHeader"
    subheader.text = "Select your taxonomic branch to permanently alter your organism's lineage:"
    subheader.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subheader.add_theme_font_size_override("font_size", 22)
    subheader.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
    center_box.add_child(subheader)
    
    var cards_row = HBoxContainer.new()
    cards_row.name = "CardsRow"
    cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
    cards_row.add_theme_constant_override("separation", 50)
    center_box.add_child(cards_row)

func _build_choice_card(parent: HBoxContainer, floor_num: int, choice_idx: int, data: Dictionary):
    var card = PanelContainer.new()
    card.custom_minimum_size = Vector2(680, 560)
    
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.05, 0.09, 0.15, 0.96)
    style.border_width_left = 3
    style.border_width_top = 3
    style.border_width_right = 3
    style.border_width_bottom = 3
    style.border_color = data["color"]
    style.corner_radius_top_left = 12
    style.corner_radius_top_right = 12
    style.corner_radius_bottom_right = 12
    style.corner_radius_bottom_left = 12
    style.shadow_color = data["color"] * Color(1, 1, 1, 0.25)
    style.shadow_size = 20
    card.add_theme_stylebox_override("panel", style)
    
    var margin = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 36)
    margin.add_theme_constant_override("margin_top", 30)
    margin.add_theme_constant_override("margin_right", 36)
    margin.add_theme_constant_override("margin_bottom", 30)
    card.add_child(margin)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 16)
    margin.add_child(vbox)
    
    var clade_lbl = Label.new()
    clade_lbl.text = data["clade"].to_upper()
    clade_lbl.add_theme_font_size_override("font_size", 16)
    clade_lbl.add_theme_color_override("font_color", data["color"] * Color(1, 1, 1, 0.8))
    vbox.add_child(clade_lbl)
    
    var title_lbl = Label.new()
    title_lbl.text = data["title"]
    title_lbl.add_theme_font_size_override("font_size", 28)
    title_lbl.add_theme_color_override("font_color", Color.WHITE)
    vbox.add_child(title_lbl)
    
    var desc_lbl = Label.new()
    desc_lbl.text = data["desc"]
    desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    desc_lbl.add_theme_font_size_override("font_size", 17)
    desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.95))
    vbox.add_child(desc_lbl)
    
    var sep = HSeparator.new()
    vbox.add_child(sep)
    
    var perks_lbl = Label.new()
    perks_lbl.text = data["perks"]
    perks_lbl.add_theme_font_size_override("font_size", 19)
    perks_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.75))
    vbox.add_child(perks_lbl)
    
    var spacer = Control.new()
    spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vbox.add_child(spacer)
    
    var btn = Button.new()
    btn.text = "⚡ MUTATE & ADAPT"
    btn.custom_minimum_size = Vector2(0, 56)
    btn.add_theme_font_size_override("font_size", 22)
    btn.pressed.connect(func():
        _on_evolution_choice_clicked(floor_num, choice_idx)
    )
    vbox.add_child(btn)
    
    parent.add_child(card)

func _on_evolution_choice_clicked(floor_num: int, choice_idx: int):
    if evolution_modal:
        evolution_modal.visible = false
    get_tree().paused = false
    evolution_selected.emit(floor_num, choice_idx)
