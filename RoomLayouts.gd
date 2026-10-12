# RoomLayouts.gd
extends RefCounted

# Room Layout Repository for 15x8 Grid (13x6 playable cells, gx: 1..13, gy: 1..6)
# Coordinates map to pos: Vector2(gx * 128 + 64, gy * 128 + 64 + 28)

const OBSTACLE_TYPES = ["rock", "coral_spire", "biocrystal", "fossil_bone", "stromatolite", "ediacaran_frond", "hydrothermal_vent", "calcified_sponge"]

static func get_normal_layouts() -> Array:
    return [
        # Layout 1: The Four Monoliths (Quad Pillars)
        {
            "id": "quad_monoliths",
            "name": "The Four Monoliths",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "rock"},
                {"gx": 4, "gy": 2, "type": "coral_spire"},
                {"gx": 10, "gy": 2, "type": "coral_spire"},
                {"gx": 11, "gy": 2, "type": "rock"},
                {"gx": 3, "gy": 5, "type": "rock"},
                {"gx": 4, "gy": 5, "type": "biocrystal"},
                {"gx": 10, "gy": 5, "type": "biocrystal"},
                {"gx": 11, "gy": 5, "type": "rock"},
            ],
            "decals": [
                {"gx": 3, "gy": 3, "type": "decal_moss"},
                {"gx": 11, "gy": 3, "type": "decal_moss"},
                {"gx": 7, "gy": 3, "type": "decal_rune"},
                {"gx": 7, "gy": 4, "type": "decal_fossil"},
            ],
            "enemy_spawns": [
                {"gx": 3, "gy": 1, "type": "pacer"},
                {"gx": 11, "gy": 1, "type": "pacer"},
                {"gx": 7, "gy": 2, "type": "fly"},
                {"gx": 7, "gy": 5, "type": "fly"},
            ]
        },

        # Layout 2: The Sunken Atoll (Center Ring)
        {
            "id": "sunken_atoll",
            "name": "The Sunken Atoll",
            "obstacles": [
                {"gx": 5, "gy": 2, "type": "coral_spire"},
                {"gx": 6, "gy": 2, "type": "biocrystal"},
                {"gx": 8, "gy": 2, "type": "biocrystal"},
                {"gx": 9, "gy": 2, "type": "coral_spire"},
                {"gx": 4, "gy": 3, "type": "rock"},
                {"gx": 10, "gy": 3, "type": "rock"},
                {"gx": 4, "gy": 4, "type": "rock"},
                {"gx": 10, "gy": 4, "type": "rock"},
                {"gx": 5, "gy": 5, "type": "coral_spire"},
                {"gx": 6, "gy": 5, "type": "biocrystal"},
                {"gx": 8, "gy": 5, "type": "biocrystal"},
                {"gx": 9, "gy": 5, "type": "coral_spire"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_rune"},
                {"gx": 2, "gy": 2, "type": "decal_moss"},
                {"gx": 12, "gy": 5, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 2, "gy": 3, "type": "pacer"},
                {"gx": 12, "gy": 4, "type": "pacer"},
                {"gx": 7, "gy": 1, "type": "fly"},
                {"gx": 7, "gy": 6, "type": "fly"},
            ],
            "pickups": [
                {"gx": 7, "gy": 4, "type": "coin"}
            ]
        },

        # Layout 3: Crossroads Trenches (4 L-shaped fortifications)
        {
            "id": "crossroads_trenches",
            "name": "Crossroads Trenches",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "rock"},
                {"gx": 4, "gy": 2, "type": "biocrystal"},
                {"gx": 3, "gy": 1, "type": "coral_spire"},
                {"gx": 10, "gy": 2, "type": "biocrystal"},
                {"gx": 11, "gy": 2, "type": "rock"},
                {"gx": 11, "gy": 1, "type": "coral_spire"},
                {"gx": 3, "gy": 5, "type": "coral_spire"},
                {"gx": 3, "gy": 6, "type": "rock"},
                {"gx": 4, "gy": 5, "type": "fossil_bone"},
                {"gx": 10, "gy": 5, "type": "fossil_bone"},
                {"gx": 11, "gy": 5, "type": "coral_spire"},
                {"gx": 11, "gy": 6, "type": "rock"},
            ],
            "decals": [
                {"gx": 5, "gy": 2, "type": "decal_moss"},
                {"gx": 9, "gy": 5, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 4, "gy": 1, "type": "pacer"},
                {"gx": 10, "gy": 1, "type": "pacer"},
                {"gx": 4, "gy": 6, "type": "fly"},
                {"gx": 10, "gy": 6, "type": "fly"},
            ]
        },

        # Layout 4: Twin Bastions (Horizontal Defenses)
        {
            "id": "twin_bastions",
            "name": "Twin Bastions",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "rock"},
                {"gx": 4, "gy": 2, "type": "fossil_bone"},
                {"gx": 5, "gy": 2, "type": "coral_spire"},
                {"gx": 9, "gy": 2, "type": "coral_spire"},
                {"gx": 10, "gy": 2, "type": "fossil_bone"},
                {"gx": 11, "gy": 2, "type": "rock"},
                {"gx": 3, "gy": 5, "type": "rock"},
                {"gx": 4, "gy": 5, "type": "biocrystal"},
                {"gx": 5, "gy": 5, "type": "coral_spire"},
                {"gx": 9, "gy": 5, "type": "coral_spire"},
                {"gx": 10, "gy": 5, "type": "biocrystal"},
                {"gx": 11, "gy": 5, "type": "rock"},
            ],
            "decals": [
                {"gx": 7, "gy": 2, "type": "decal_fossil"},
                {"gx": 7, "gy": 5, "type": "decal_fossil"},
                {"gx": 7, "gy": 3, "type": "decal_rune"},
            ],
            "enemy_spawns": [
                {"gx": 4, "gy": 1, "type": "pacer"},
                {"gx": 10, "gy": 1, "type": "pacer"},
                {"gx": 7, "gy": 4, "type": "fly"},
            ]
        },

        # Layout 5: Vertical Channels (Colonnade Lanes)
        {
            "id": "vertical_channels",
            "name": "Vertical Channels",
            "obstacles": [
                {"gx": 4, "gy": 2, "type": "coral_spire"},
                {"gx": 4, "gy": 5, "type": "biocrystal"},
                {"gx": 10, "gy": 2, "type": "coral_spire"},
                {"gx": 10, "gy": 5, "type": "biocrystal"},
                {"gx": 4, "gy": 1, "type": "rock"},
                {"gx": 4, "gy": 6, "type": "rock"},
                {"gx": 10, "gy": 1, "type": "rock"},
                {"gx": 10, "gy": 6, "type": "rock"},
            ],
            "decals": [
                {"gx": 2, "gy": 3, "type": "decal_moss"},
                {"gx": 12, "gy": 4, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 2, "gy": 2, "type": "fly"},
                {"gx": 12, "gy": 5, "type": "fly"},
                {"gx": 7, "gy": 2, "type": "pacer"},
                {"gx": 7, "gy": 5, "type": "pacer"},
            ]
        },

        # Layout 6: Diamond Sanctuary (Central Altar Shape)
        {
            "id": "diamond_sanctuary",
            "name": "Diamond Sanctuary",
            "obstacles": [
                {"gx": 7, "gy": 2, "type": "biocrystal"},
                {"gx": 5, "gy": 3, "type": "coral_spire"},
                {"gx": 9, "gy": 3, "type": "coral_spire"},
                {"gx": 5, "gy": 4, "type": "fossil_bone"},
                {"gx": 9, "gy": 4, "type": "fossil_bone"},
                {"gx": 7, "gy": 5, "type": "biocrystal"},
                {"gx": 2, "gy": 1, "type": "rock"},
                {"gx": 12, "gy": 1, "type": "rock"},
                {"gx": 2, "gy": 6, "type": "rock"},
                {"gx": 12, "gy": 6, "type": "rock"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_rune"},
                {"gx": 7, "gy": 4, "type": "decal_rune"},
                {"gx": 3, "gy": 2, "type": "decal_moss"},
                {"gx": 11, "gy": 5, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 3, "gy": 2, "type": "pacer"},
                {"gx": 11, "gy": 2, "type": "pacer"},
                {"gx": 3, "gy": 5, "type": "fly"},
                {"gx": 11, "gy": 5, "type": "fly"},
            ]
        },

        # Layout 7: Scattered Archipelago (Checkerboard Covers)
        {
            "id": "scattered_archipelago",
            "name": "Scattered Archipelago",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "coral_spire"},
                {"gx": 5, "gy": 2, "type": "rock"},
                {"gx": 9, "gy": 2, "type": "rock"},
                {"gx": 11, "gy": 2, "type": "coral_spire"},
                {"gx": 2, "gy": 4, "type": "biocrystal"},
                {"gx": 4, "gy": 5, "type": "fossil_bone"},
                {"gx": 10, "gy": 5, "type": "fossil_bone"},
                {"gx": 12, "gy": 3, "type": "biocrystal"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_fossil"},
                {"gx": 6, "gy": 4, "type": "decal_moss"},
                {"gx": 8, "gy": 4, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 3, "gy": 3, "type": "fly"},
                {"gx": 11, "gy": 4, "type": "fly"},
                {"gx": 7, "gy": 2, "type": "pacer"},
                {"gx": 7, "gy": 5, "type": "pacer"},
            ]
        },

        # Layout 8: Canyon Chokepoint (Narrow Center Pass)
        {
            "id": "canyon_chokepoint",
            "name": "Canyon Chokepoint",
            "obstacles": [
                {"gx": 5, "gy": 1, "type": "rock"},
                {"gx": 5, "gy": 2, "type": "coral_spire"},
                {"gx": 9, "gy": 1, "type": "rock"},
                {"gx": 9, "gy": 2, "type": "coral_spire"},
                {"gx": 5, "gy": 6, "type": "rock"},
                {"gx": 5, "gy": 5, "type": "biocrystal"},
                {"gx": 9, "gy": 6, "type": "rock"},
                {"gx": 9, "gy": 5, "type": "biocrystal"},
            ],
            "decals": [
                {"gx": 3, "gy": 3, "type": "decal_moss"},
                {"gx": 11, "gy": 4, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 7, "gy": 3, "type": "pacer"},
                {"gx": 3, "gy": 2, "type": "fly"},
                {"gx": 11, "gy": 5, "type": "fly"},
            ]
        },

        # Layout 9: Corner Fortresses (Wide Open Swarm Arena)
        {
            "id": "corner_fortresses",
            "name": "Corner Fortresses",
            "obstacles": [
                {"gx": 2, "gy": 1, "type": "rock"},
                {"gx": 3, "gy": 1, "type": "coral_spire"},
                {"gx": 2, "gy": 2, "type": "coral_spire"},
                {"gx": 12, "gy": 1, "type": "rock"},
                {"gx": 11, "gy": 1, "type": "coral_spire"},
                {"gx": 12, "gy": 2, "type": "coral_spire"},
                {"gx": 2, "gy": 6, "type": "rock"},
                {"gx": 3, "gy": 6, "type": "biocrystal"},
                {"gx": 2, "gy": 5, "type": "biocrystal"},
                {"gx": 12, "gy": 6, "type": "rock"},
                {"gx": 11, "gy": 6, "type": "biocrystal"},
                {"gx": 12, "gy": 5, "type": "biocrystal"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_rune"},
                {"gx": 7, "gy": 4, "type": "decal_fossil"},
                {"gx": 5, "gy": 3, "type": "decal_moss"},
                {"gx": 9, "gy": 4, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 6, "gy": 2, "type": "fly"},
                {"gx": 8, "gy": 2, "type": "fly"},
                {"gx": 6, "gy": 5, "type": "fly"},
                {"gx": 8, "gy": 5, "type": "fly"},
                {"gx": 7, "gy": 3, "type": "fly"},
            ]
        },

        # Layout 10: Serpentine S-Curves (Winding Sightlines)
        {
            "id": "serpentine_scurves",
            "name": "Serpentine S-Curves",
            "obstacles": [
                {"gx": 4, "gy": 2, "type": "rock"},
                {"gx": 5, "gy": 2, "type": "coral_spire"},
                {"gx": 6, "gy": 2, "type": "biocrystal"},
                {"gx": 8, "gy": 5, "type": "biocrystal"},
                {"gx": 9, "gy": 5, "type": "coral_spire"},
                {"gx": 10, "gy": 5, "type": "rock"},
                {"gx": 3, "gy": 4, "type": "fossil_bone"},
                {"gx": 11, "gy": 3, "type": "fossil_bone"},
            ],
            "decals": [
                {"gx": 5, "gy": 3, "type": "decal_moss"},
                {"gx": 9, "gy": 4, "type": "decal_moss"},
                {"gx": 7, "gy": 3, "type": "decal_fossil"},
            ],
            "enemy_spawns": [
                {"gx": 5, "gy": 1, "type": "pacer"},
                {"gx": 9, "gy": 6, "type": "pacer"},
                {"gx": 7, "gy": 4, "type": "fly"},
            ]
        },

        # Layout 11: The Crystal Grove (Luminescent Cluster)
        {
            "id": "crystal_grove",
            "name": "The Crystal Grove",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "biocrystal"},
                {"gx": 4, "gy": 2, "type": "coral_spire"},
                {"gx": 4, "gy": 3, "type": "biocrystal"},
                {"gx": 10, "gy": 4, "type": "biocrystal"},
                {"gx": 10, "gy": 5, "type": "coral_spire"},
                {"gx": 11, "gy": 5, "type": "biocrystal"},
                {"gx": 6, "gy": 5, "type": "coral_spire"},
                {"gx": 8, "gy": 2, "type": "coral_spire"},
            ],
            "decals": [
                {"gx": 3, "gy": 3, "type": "decal_moss"},
                {"gx": 11, "gy": 4, "type": "decal_moss"},
                {"gx": 7, "gy": 3, "type": "decal_rune"},
            ],
            "enemy_spawns": [
                {"gx": 3, "gy": 1, "type": "fly"},
                {"gx": 11, "gy": 6, "type": "fly"},
                {"gx": 7, "gy": 2, "type": "pacer"},
                {"gx": 7, "gy": 4, "type": "pacer"},
            ]
        },

        # Layout 12: The Divide (Bisected Chamber)
        {
            "id": "the_divide",
            "name": "The Divide",
            "obstacles": [
                {"gx": 7, "gy": 1, "type": "fossil_bone"},
                {"gx": 7, "gy": 2, "type": "rock"},
                {"gx": 7, "gy": 5, "type": "rock"},
                {"gx": 7, "gy": 6, "type": "fossil_bone"},
                {"gx": 3, "gy": 3, "type": "coral_spire"},
                {"gx": 3, "gy": 4, "type": "coral_spire"},
                {"gx": 11, "gy": 3, "type": "biocrystal"},
                {"gx": 11, "gy": 4, "type": "biocrystal"},
            ],
            "decals": [
                {"gx": 6, "gy": 3, "type": "decal_moss"},
                {"gx": 8, "gy": 4, "type": "decal_moss"},
                {"gx": 7, "gy": 3, "type": "decal_fossil"},
                {"gx": 7, "gy": 4, "type": "decal_fossil"},
            ],
            "enemy_spawns": [
                {"gx": 4, "gy": 2, "type": "pacer"},
                {"gx": 10, "gy": 5, "type": "pacer"},
                {"gx": 4, "gy": 5, "type": "fly"},
                {"gx": 10, "gy": 2, "type": "fly"},
            ]
        },

        # Layout 13: Apex Arena (Ring of Perimeters)
        {
            "id": "apex_arena",
            "name": "Apex Arena",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "rock"},
                {"gx": 3, "gy": 5, "type": "rock"},
                {"gx": 11, "gy": 2, "type": "rock"},
                {"gx": 11, "gy": 5, "type": "rock"},
                {"gx": 6, "gy": 2, "type": "coral_spire"},
                {"gx": 8, "gy": 2, "type": "coral_spire"},
                {"gx": 6, "gy": 5, "type": "biocrystal"},
                {"gx": 8, "gy": 5, "type": "biocrystal"},
            ],
            "decals": [
                {"gx": 7, "gy": 4, "type": "decal_rune"},
                {"gx": 2, "gy": 3, "type": "decal_moss"},
                {"gx": 12, "gy": 4, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 5, "gy": 3, "type": "fly"},
                {"gx": 9, "gy": 4, "type": "fly"},
                {"gx": 7, "gy": 2, "type": "pacer"},
                {"gx": 7, "gy": 5, "type": "pacer"},
            ]
        },

        # Layout 14: Primordial Meadow (Open Space with Decals)
        {
            "id": "primordial_meadow",
            "name": "Primordial Meadow",
            "obstacles": [
                {"gx": 3, "gy": 3, "type": "biocrystal"},
                {"gx": 11, "gy": 4, "type": "biocrystal"},
                {"gx": 5, "gy": 5, "type": "coral_spire"},
                {"gx": 9, "gy": 2, "type": "coral_spire"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_rune"},
                {"gx": 7, "gy": 4, "type": "decal_fossil"},
                {"gx": 4, "gy": 2, "type": "decal_moss"},
                {"gx": 10, "gy": 5, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 4, "gy": 3, "type": "fly"},
                {"gx": 10, "gy": 4, "type": "fly"},
                {"gx": 7, "gy": 2, "type": "pacer"},
                {"gx": 7, "gy": 5, "type": "pacer"},
            ]
        },

        # Layout 15: Stromatolite Grove (Archean Precambrian microbial mound field)
        {
            "id": "stromatolite_grove",
            "name": "The Stromatolite Grove",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "stromatolite"},
                {"gx": 5, "gy": 2, "type": "stromatolite"},
                {"gx": 9, "gy": 2, "type": "stromatolite"},
                {"gx": 11, "gy": 2, "type": "stromatolite"},
                {"gx": 4, "gy": 4, "type": "calcified_sponge"},
                {"gx": 10, "gy": 4, "type": "calcified_sponge"},
                {"gx": 3, "gy": 5, "type": "stromatolite"},
                {"gx": 11, "gy": 5, "type": "stromatolite"},
            ],
            "decals": [
                {"gx": 7, "gy": 3, "type": "decal_moss"},
                {"gx": 7, "gy": 4, "type": "decal_moss"},
                {"gx": 5, "gy": 3, "type": "decal_fossil"},
                {"gx": 9, "gy": 4, "type": "decal_fossil"},
                {"gx": 2, "gy": 1, "type": "decal_moss"},
                {"gx": 12, "gy": 6, "type": "decal_moss"},
            ],
            "enemy_spawns": [
                {"gx": 2, "gy": 3, "type": "fly"},
                {"gx": 12, "gy": 4, "type": "fly"},
                {"gx": 6, "gy": 1, "type": "pacer"},
                {"gx": 8, "gy": 6, "type": "fly"},
            ]
        },

        # Layout 16: Ediacaran Garden (635-541 Ma rangeomorph fronds + vent chimneys)
        {
            "id": "ediacaran_garden",
            "name": "The Ediacaran Garden",
            "obstacles": [
                {"gx": 2, "gy": 2, "type": "ediacaran_frond"},
                {"gx": 4, "gy": 1, "type": "ediacaran_frond"},
                {"gx": 6, "gy": 2, "type": "hydrothermal_vent"},
                {"gx": 8, "gy": 2, "type": "hydrothermal_vent"},
                {"gx": 10, "gy": 1, "type": "ediacaran_frond"},
                {"gx": 12, "gy": 2, "type": "ediacaran_frond"},
                {"gx": 2, "gy": 5, "type": "ediacaran_frond"},
                {"gx": 12, "gy": 5, "type": "ediacaran_frond"},
                {"gx": 6, "gy": 5, "type": "calcified_sponge"},
                {"gx": 8, "gy": 5, "type": "calcified_sponge"},
            ],
            "decals": [
                {"gx": 4, "gy": 3, "type": "decal_fossil"},
                {"gx": 10, "gy": 4, "type": "decal_fossil"},
                {"gx": 3, "gy": 5, "type": "decal_rune"},
                {"gx": 11, "gy": 2, "type": "decal_rune"},
            ],
            "enemy_spawns": [
                {"gx": 3, "gy": 3, "type": "pacer"},
                {"gx": 11, "gy": 4, "type": "pacer"},
                {"gx": 7, "gy": 1, "type": "fly"},
                {"gx": 7, "gy": 6, "type": "fly"},
                {"gx": 2, "gy": 6, "type": "fly"},
            ]
        },

        # Layout 17: Precambrian Vent Field (hydrothermal sulfide chimneys + sponge reef)
        {
            "id": "precambrian_vent_field",
            "name": "The Precambrian Vent Field",
            "obstacles": [
                {"gx": 3, "gy": 2, "type": "hydrothermal_vent"},
                {"gx": 7, "gy": 2, "type": "hydrothermal_vent"},
                {"gx": 11, "gy": 2, "type": "hydrothermal_vent"},
                {"gx": 3, "gy": 5, "type": "hydrothermal_vent"},
                {"gx": 7, "gy": 5, "type": "hydrothermal_vent"},
                {"gx": 11, "gy": 5, "type": "hydrothermal_vent"},
                {"gx": 5, "gy": 3, "type": "calcified_sponge"},
                {"gx": 9, "gy": 4, "type": "calcified_sponge"},
                {"gx": 5, "gy": 4, "type": "stromatolite"},
                {"gx": 9, "gy": 3, "type": "stromatolite"},
            ],
            "decals": [
                {"gx": 2, "gy": 3, "type": "decal_fossil"},
                {"gx": 12, "gy": 4, "type": "decal_fossil"},
            ],
            "enemy_spawns": [
                {"gx": 2, "gy": 2, "type": "fly"},
                {"gx": 12, "gy": 2, "type": "fly"},
                {"gx": 2, "gy": 5, "type": "pacer"},
                {"gx": 12, "gy": 5, "type": "pacer"},
                {"gx": 7, "gy": 3, "type": "fly"},
            ]
        },
    ]

# ─────────────────────────────────────────────────────────
# SPECIAL ROOM LAYOUTS
static func get_start_layout() -> Dictionary:
    return {
        "id": "start_chamber",
        "name": "Ancestral Spawning Pool",
        "obstacles": [
            {"gx": 2, "gy": 1, "type": "coral_spire"},
            {"gx": 12, "gy": 1, "type": "coral_spire"},
            {"gx": 2, "gy": 6, "type": "biocrystal"},
            {"gx": 12, "gy": 6, "type": "biocrystal"},
        ],
        "decals": [
            {"gx": 7, "gy": 3, "type": "decal_rune"},
            {"gx": 7, "gy": 4, "type": "decal_rune"},
            {"gx": 4, "gy": 2, "type": "decal_moss"},
            {"gx": 10, "gy": 2, "type": "decal_moss"},
            {"gx": 4, "gy": 5, "type": "decal_fossil"},
            {"gx": 10, "gy": 5, "type": "decal_fossil"},
        ],
        "enemy_spawns": []
    }

static func get_treasure_layout() -> Dictionary:
    return {
        "id": "treasure_vault",
        "name": "The Evolution Vault",
        "obstacles": [
            {"gx": 5, "gy": 2, "type": "biocrystal"},
            {"gx": 9, "gy": 2, "type": "biocrystal"},
            {"gx": 5, "gy": 5, "type": "biocrystal"},
            {"gx": 9, "gy": 5, "type": "biocrystal"},
            {"gx": 3, "gy": 2, "type": "coral_spire"},
            {"gx": 11, "gy": 2, "type": "coral_spire"},
            {"gx": 3, "gy": 5, "type": "coral_spire"},
            {"gx": 11, "gy": 5, "type": "coral_spire"},
        ],
        "decals": [
            {"gx": 7, "gy": 3, "type": "decal_rune"},
            {"gx": 7, "gy": 4, "type": "decal_rune"},
            {"gx": 6, "gy": 3, "type": "decal_moss"},
            {"gx": 8, "gy": 3, "type": "decal_moss"},
            {"gx": 6, "gy": 4, "type": "decal_moss"},
            {"gx": 8, "gy": 4, "type": "decal_moss"},
        ],
        "enemy_spawns": []
    }

static func get_shop_layout() -> Dictionary:
    return {
        "id": "shop_bazaar",
        "name": "The Deep Sea Bazaar",
        "obstacles": [
            # Merchant backdrop
            {"gx": 5, "gy": 2, "type": "coral_spire"},
            {"gx": 6, "gy": 2, "type": "fossil_bone"},
            {"gx": 8, "gy": 2, "type": "fossil_bone"},
            {"gx": 9, "gy": 2, "type": "coral_spire"},
            # Side sconces
            {"gx": 3, "gy": 3, "type": "biocrystal"},
            {"gx": 11, "gy": 3, "type": "biocrystal"},
            {"gx": 3, "gy": 5, "type": "rock"},
            {"gx": 11, "gy": 5, "type": "rock"},
        ],
        "decals": [
            {"gx": 5, "gy": 4, "type": "decal_rune"},
            {"gx": 7, "gy": 4, "type": "decal_rune"},
            {"gx": 9, "gy": 4, "type": "decal_rune"},
            {"gx": 7, "gy": 2, "type": "decal_moss"},
        ],
        "enemy_spawns": []
    }

static func get_boss_layout() -> Dictionary:
    return {
        "id": "boss_abyss",
        "name": "The Abyssal Primordial Arena",
        "obstacles": [
            # 4 Monumental corner hydrothermal vents (dramatic boss atmosphere)
            {"gx": 2, "gy": 2, "type": "hydrothermal_vent"},
            {"gx": 3, "gy": 2, "type": "stromatolite"},
            {"gx": 11, "gy": 2, "type": "stromatolite"},
            {"gx": 12, "gy": 2, "type": "hydrothermal_vent"},
            {"gx": 2, "gy": 5, "type": "hydrothermal_vent"},
            {"gx": 3, "gy": 5, "type": "calcified_sponge"},
            {"gx": 11, "gy": 5, "type": "calcified_sponge"},
            {"gx": 12, "gy": 5, "type": "hydrothermal_vent"},
        ],
        "decals": [
            {"gx": 6, "gy": 3, "type": "decal_rune"},
            {"gx": 8, "gy": 4, "type": "decal_rune"},
            {"gx": 4, "gy": 3, "type": "decal_fossil"},
            {"gx": 10, "gy": 4, "type": "decal_fossil"},
        ],
        "enemy_spawns": []
    }

# ─────────────────────────────────────────────────────────
# DOOR SAFETY FILTERING
# Guarantees no obstacle blocks player passage from/to any active door.
# ─────────────────────────────────────────────────────────

static func filter_layout_for_doors(layout: Dictionary, connections: Dictionary) -> Dictionary:
    var clean_layout = {
        "id": layout.get("id", ""),
        "name": layout.get("name", ""),
        "obstacles": [],
        "decals": layout.get("decals", []).duplicate(true),
        "enemy_spawns": [],
        "pickups": layout.get("pickups", []).duplicate(true),
    }

    var blocked_coords: Dictionary = {}

    # Door corridor coordinates that must remain clear for player transit
    if connections.has(Vector2i.UP):
        for gx in range(6, 9):
            for gy in range(1, 3):
                blocked_coords[Vector2i(gx, gy)] = true

    if connections.has(Vector2i.DOWN):
        for gx in range(6, 9):
            for gy in range(5, 7):
                blocked_coords[Vector2i(gx, gy)] = true

    if connections.has(Vector2i.LEFT):
        for gx in range(1, 4):
            for gy in range(3, 5):
                blocked_coords[Vector2i(gx, gy)] = true

    if connections.has(Vector2i.RIGHT):
        for gx in range(11, 14):
            for gy in range(3, 5):
                blocked_coords[Vector2i(gx, gy)] = true

    # Center transit point
    blocked_coords[Vector2i(7, 3)] = true
    blocked_coords[Vector2i(7, 4)] = true

    # Filter obstacles
    for obs in layout.get("obstacles", []):
        var coord = Vector2i(obs["gx"], obs["gy"])
        if not blocked_coords.has(coord):
            clean_layout["obstacles"].append(obs)

    # Door safety coordinates where enemies should NEVER spawn (at least 2-3 cells away from all doors)
    var door_danger_zone: Dictionary = {}
    for gx in range(5, 10):
        for gy in range(1, 3): # Top door area
            door_danger_zone[Vector2i(gx, gy)] = true
        for gy in range(5, 7): # Bottom door area
            door_danger_zone[Vector2i(gx, gy)] = true
    for gx in range(1, 4):     # Left door area
        for gy in range(2, 6):
            door_danger_zone[Vector2i(gx, gy)] = true
    for gx in range(11, 14):   # Right door area
        for gy in range(2, 6):
            door_danger_zone[Vector2i(gx, gy)] = true
    
    # Center exclusion zone around player spawn (960, 540) to prevent instant contact damage
    for gx in range(6, 9):
        for gy in range(3, 5):
            door_danger_zone[Vector2i(gx, gy)] = true

    # Filter enemy spawns
    for sp in layout.get("enemy_spawns", []):
        var coord = Vector2i(sp["gx"], sp["gy"])
        if not door_danger_zone.has(coord):
            clean_layout["enemy_spawns"].append(sp)

    # Fallback safe quadrant spawns if layout enemy spawns were cleared
    if clean_layout["enemy_spawns"].is_empty():
        clean_layout["enemy_spawns"] = [
            {"gx": 4, "gy": 2, "type": "pacer"},
            {"gx": 10, "gy": 2, "type": "pacer"},
            {"gx": 4, "gy": 5, "type": "fly"},
            {"gx": 10, "gy": 5, "type": "fly"},
        ]

    return clean_layout
