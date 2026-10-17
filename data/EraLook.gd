# EraLook.gd
# The mood of each era in one place, so a floor's art, light, particles and
# music agree (art: generate_room_art.py ERA_LOOK, music: generate_soundtrack.py).
#   tint        CanvasModulate colour for ordinary rooms (before brightness)
#   boss_tint   the same, once the boss appears
#   light       colour of the moving light on the floor (shader below)
#   light_mode  0 water caustics, 1 sun through leaves, 2 hot haze
#   light_power how strong that light is
#   motes       drifting particles: colour and kind ("plankton", "spores", "ash")
#   shafts      colour of the slanting sun rays (alpha 0 = none)
#   bubbles     rising bubble streams (underwater eras only)
#   shadow      something big passing overhead: seconds to cross the room,
#               opacity, scale, whether it turns to face its path, and the
#               turn that does it (PI/2 head first, -PI/2 tail first, like a
#               nautiloid jetting backwards)
#   door_light  glow of an open door
extends RefCounted

const ERAS = [
	{ # 1 Ediacaran: still teal shallows over pink microbial mats
		"tint": Color(0.84, 0.95, 1.0), "ink_light": 0.55, "boss_tint": Color(0.72, 0.80, 1.0),
		"light": Color(0.55, 1.0, 0.85), "light_mode": 0, "light_power": 0.11,
		"motes": Color(0.6, 1.0, 0.9, 0.28), "mote_kind": "plankton",
		"shafts": Color(0.75, 1.0, 0.95, 0.07), "bubbles": true,
		"shadow_time": 40.0, "shadow_alpha": 0.12, "shadow_scale": 4.0, "shadow_facing": 0.0, "shadow_turns": false,
		"door_light": Color(0.5, 1.0, 0.85),
	},
	{ # 2 Cambrian: sunlit sand, turquoise water, colourful sponges
		"tint": Color(0.95, 1.0, 1.0), "ink_light": 0.72, "boss_tint": Color(0.70, 0.90, 0.95),
		"light": Color(0.9, 1.0, 0.85), "light_mode": 0, "light_power": 0.15,
		"motes": Color(0.9, 1.0, 0.85, 0.26), "mote_kind": "plankton",
		"shafts": Color(1.0, 0.97, 0.85, 0.08), "bubbles": true,
		"shadow_time": 26.0, "shadow_alpha": 0.2, "shadow_scale": 3.6, "shadow_facing": PI / 2, "shadow_turns": true,
		"door_light": Color(1.0, 0.95, 0.75),
	},
	{ # 3 Ordovician: deep blue reef with pink and cream corals
		"tint": Color(0.84, 0.90, 1.0), "ink_light": 0.47, "boss_tint": Color(0.70, 0.86, 0.90),
		"light": Color(0.6, 0.75, 1.0), "light_mode": 0, "light_power": 0.1,
		"motes": Color(0.75, 0.85, 1.0, 0.28), "mote_kind": "plankton",
		"shafts": Color(0.65, 0.8, 1.0, 0.07), "bubbles": true,
		"shadow_time": 32.0, "shadow_alpha": 0.2, "shadow_scale": 4.4, "shadow_facing": -PI / 2, "shadow_turns": true,
		"door_light": Color(0.75, 0.8, 1.0),
	},
	{ # 4 Carboniferous: peat swamp under tree ferns, golden light
		"tint": Color(0.92, 0.94, 0.86), "ink_light": 0.3, "boss_tint": Color(0.80, 0.88, 0.70),
		"light": Color(1.0, 0.88, 0.6), "light_mode": 1, "light_power": 0.08,
		"motes": Color(0.85, 1.0, 0.6, 0.26), "mote_kind": "spores",
		"shafts": Color(1.0, 0.9, 0.6, 0.06), "bubbles": false,
		"shadow_time": 9.0, "shadow_alpha": 0.24, "shadow_scale": 2.6, "shadow_facing": PI / 2, "shadow_turns": true,
		"door_light": Color(1.0, 0.9, 0.55),
	},
	{ # 5 End-Permian: red beds, ash and distant volcanic glow
		"tint": Color(0.96, 0.88, 0.86), "ink_light": 0.47, "boss_tint": Color(1.0, 0.76, 0.64),
		"light": Color(1.0, 0.6, 0.35), "light_mode": 2, "light_power": 0.08,
		"motes": Color(0.85, 0.8, 0.78, 0.3), "mote_kind": "ash",
		"shafts": Color(1.0, 0.7, 0.45, 0.06), "bubbles": false,
		"shadow_time": 50.0, "shadow_alpha": 0.16, "shadow_scale": 6.0, "shadow_facing": 0.0, "shadow_turns": false,
		"door_light": Color(1.0, 0.65, 0.4),
	},
]

static func get_look(floor_num: int) -> Dictionary:
	return ERAS[clampi(floor_num - 1, 0, ERAS.size() - 1)]

# Light moving over the floor: water caustics, leaf-dappled sun or heat haze.
# Additive, a few sines per pixel, so it stays cheap on phones.
const FLOOR_LIGHT_SHADER = """
shader_type canvas_item;
render_mode blend_add, unshaded;
uniform vec4 tint : source_color = vec4(0.6, 1.0, 0.9, 1.0);
uniform float strength = 0.1;
uniform int mode = 0;
uniform vec2 rect_size = vec2(1920.0, 1080.0);

float caustic(vec2 uv, float t) {
	vec2 p = mod(uv * 6.2831, 6.2831) - 250.0;
	vec2 i = p;
	float c = 1.0;
	float inten = 0.005;
	for (int n = 0; n < 3; n++) {
		float tt = t * (1.0 - (3.5 / float(n + 1)));
		i = p + vec2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
		c += 1.0 / length(vec2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
	}
	c /= 3.0;
	c = 1.17 - pow(c, 1.4);
	return clamp(pow(abs(c), 8.0), 0.0, 1.0);
}

void fragment() {
	vec2 world = UV * rect_size;
	float t = TIME;
	float l = 0.0;
	if (mode == 0) {
		l = caustic(world / 520.0, t * 0.35);
	} else if (mode == 1) {
		vec2 p = world / 260.0;
		float n = sin(p.x * 1.3 + t * 0.25 + sin(p.y * 0.9 + t * 0.18) * 1.6)
				* sin(p.y * 1.1 - t * 0.2 + sin(p.x * 0.7 - t * 0.13) * 1.6);
		l = smoothstep(0.25, 0.7, n) * 1.6;
	} else {
		vec2 p = world / 600.0;
		float n = sin(p.x * 1.1 + p.y * 0.6 + t * 0.08 + sin(p.y * 1.7 + t * 0.11) * 0.8);
		l = n * n;
	}
	float edge = smoothstep(0.0, 0.1, UV.x) * smoothstep(1.0, 0.9, UV.x)
			* smoothstep(0.0, 0.14, UV.y) * smoothstep(1.0, 0.86, UV.y);
	COLOR = vec4(tint.rgb * l * strength * edge, 1.0);
}
"""
