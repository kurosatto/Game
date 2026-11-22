# ArtStyles.gd
# The look of the whole world, picked on the main menu (MainMenu.gd ART STYLE)
# and saved in SettingsManager. Each style is one full-screen shader pass that
# InkFilter.gd runs over everything drawn below the vision fog (rooms,
# scenery, animals, the player), plus the colours the fog and its hints use.
# One pass with a handful of texture reads each, so they all run on the
# phone's Compatibility renderer.
#
# The first eleven entries: the sepia sketchbook look the game has used since
# PR #51 (the default) and the ten style samples kuro chose from
# (screenshots/art-options/all_10_styles.png).
extends RefCounted

const DEFAULT := "sepia"

# id, name, a one-line description, the fog colour around what you can see,
# the faint rim where sight ends, whether the fog is dark (hint arrows
# are then drawn light instead of in ink), and "ui": the menu and HUD
# palette and panel shapes (keys of data/UIStyle.gd SEPIA_UI; missing keys
# keep the sepia value)
const STYLES := [
	{"id": "sepia", "name": "Sepia sketchbook", "desc": "Pen and brown ink on pale paper. The game's own look.",
		"fog": Color(0.93, 0.87, 0.74), "rim": Color(0.55, 0.42, 0.30), "dark": false, "swatch": Color(0.94, 0.88, 0.75)},
	{"id": "chunky_pixel", "name": "Chunky pixel", "desc": "Big readable pixels, black outlines, few shades.",
		"fog": Color(0.06, 0.10, 0.13), "rim": Color(0.16, 0.28, 0.32), "dark": true, "swatch": Color(0.20, 0.42, 0.46),
		"ui": {"INK": Color(0.06, 0.08, 0.11), "INK_SOFT": Color(0.11, 0.15, 0.19), "MEMBRANE": Color(0.45, 0.78, 0.82), "CREAM": Color(0.95, 0.97, 0.92), "MUTED": Color(0.62, 0.72, 0.74), "SUN": Color(1.0, 0.84, 0.30), "LEAF": Color(0.55, 0.90, 0.40), "CORAL": Color(1.0, 0.40, 0.35), "SHADE": Color(0, 0, 0, 0.9), "BACKDROP": Color(0.04, 0.05, 0.08), "TITLE": Color(1.0, 0.84, 0.30), "TITLE_OUTLINE": Color(0.04, 0.03, 0.06), "ROUND": 0.0, "RIM": 6, "CORNER_DETAIL": 1, "SMOOTH": false, "SHADOW_SIZE": 1, "SHADOW_OFFSET": Vector2(8, 8)}},
	{"id": "pixel_16bit", "name": "16-bit pixel", "desc": "Console-era sprites with coloured outlines and hue-shifted shades.",
		"fog": Color(0.09, 0.12, 0.16), "rim": Color(0.22, 0.30, 0.38), "dark": true, "swatch": Color(0.36, 0.50, 0.62),
		"ui": {"INK": Color(0.10, 0.09, 0.20), "INK_SOFT": Color(0.17, 0.15, 0.32), "MEMBRANE": Color(0.70, 0.62, 0.98), "CREAM": Color(0.98, 0.96, 0.90), "MUTED": Color(0.70, 0.68, 0.85), "SUN": Color(1.0, 0.82, 0.42), "LEAF": Color(0.60, 0.92, 0.50), "CORAL": Color(1.0, 0.48, 0.48), "SHADE": Color(0.02, 0.0, 0.08, 0.85), "BACKDROP": Color(0.06, 0.05, 0.12), "TITLE": Color(1.0, 0.86, 0.50), "TITLE_OUTLINE": Color(0.20, 0.10, 0.35), "ROUND": 0.18, "RIM": 5, "CORNER_DETAIL": 2, "SMOOTH": false, "SHADOW_SIZE": 1, "SHADOW_OFFSET": Vector2(6, 6)}},
	{"id": "hibit_pixel", "name": "Hi-bit pixel", "desc": "Fine modern pixel art with dithering and rim light.",
		"fog": Color(0.05, 0.08, 0.14), "rim": Color(0.18, 0.28, 0.42), "dark": true, "swatch": Color(0.30, 0.46, 0.70),
		"ui": {"INK": Color(0.04, 0.07, 0.14), "INK_SOFT": Color(0.08, 0.13, 0.24), "MEMBRANE": Color(0.45, 0.68, 0.98), "CREAM": Color(0.92, 0.96, 1.0), "MUTED": Color(0.58, 0.68, 0.82), "SUN": Color(0.55, 0.92, 1.0), "LEAF": Color(0.55, 0.95, 0.65), "CORAL": Color(1.0, 0.45, 0.50), "SHADE": Color(0, 0.02, 0.06, 0.8), "BACKDROP": Color(0.02, 0.04, 0.09), "TITLE": Color(0.80, 0.94, 1.0), "TITLE_OUTLINE": Color(0.05, 0.10, 0.25), "ROUND": 0.3, "RIM": 3, "CORNER_DETAIL": 3, "SMOOTH": false, "SHADOW_SIZE": 10, "SHADOW_OFFSET": Vector2(0, 6)}},
	{"id": "ink_cel", "name": "Bold ink cel", "desc": "Thick black outlines, flat colour, one hard shadow.",
		"fog": Color(0.90, 0.79, 0.60), "rim": Color(0.20, 0.14, 0.09), "dark": false, "swatch": Color(0.92, 0.70, 0.40),
		"ui": {"INK": Color(0.08, 0.07, 0.06), "INK_SOFT": Color(0.16, 0.13, 0.10), "MEMBRANE": Color(0.98, 0.90, 0.70), "CREAM": Color(1.0, 0.97, 0.90), "MUTED": Color(0.85, 0.78, 0.66), "SUN": Color(1.0, 0.78, 0.20), "LEAF": Color(0.60, 0.88, 0.35), "CORAL": Color(1.0, 0.38, 0.28), "SHADE": Color(0, 0, 0, 0.95), "BACKDROP": Color(0.05, 0.04, 0.03), "TITLE": Color(1.0, 0.78, 0.20), "TITLE_OUTLINE": Color(0.04, 0.03, 0.02), "ROUND": 0.7, "RIM": 7, "CORNER_DETAIL": 8, "SMOOTH": true, "SHADOW_SIZE": 1, "SHADOW_OFFSET": Vector2(9, 10)}},
	{"id": "engraving", "name": "Naturalist engraving", "desc": "Old field-guide plate: fine engraved lines and stipple, hand tinted.",
		"fog": Color(0.92, 0.88, 0.78), "rim": Color(0.40, 0.33, 0.25), "dark": false, "swatch": Color(0.80, 0.74, 0.62),
		"ui": {"INK": Color(0.15, 0.14, 0.12), "INK_SOFT": Color(0.22, 0.20, 0.17), "MEMBRANE": Color(0.80, 0.76, 0.66), "CREAM": Color(0.95, 0.93, 0.86), "MUTED": Color(0.74, 0.71, 0.64), "SUN": Color(0.90, 0.78, 0.52), "LEAF": Color(0.66, 0.78, 0.52), "CORAL": Color(0.88, 0.50, 0.42), "SHADE": Color(0.03, 0.03, 0.02, 0.5), "BACKDROP": Color(0.09, 0.08, 0.07), "TITLE": Color(0.20, 0.15, 0.11), "TITLE_OUTLINE": Color(0.93, 0.89, 0.79), "ROUND": 0.25, "RIM": 2, "CORNER_DETAIL": 4, "SMOOTH": true, "SHADOW_SIZE": 12, "SHADOW_OFFSET": Vector2(0, 5)}},
	{"id": "watercolour", "name": "Watercolour plate", "desc": "Soft pigment washes with bleeding edges, like a museum painting.",
		"fog": Color(0.95, 0.93, 0.88), "rim": Color(0.62, 0.66, 0.70), "dark": false, "swatch": Color(0.55, 0.75, 0.80),
		"ui": {"INK": Color(0.20, 0.27, 0.33), "INK_SOFT": Color(0.27, 0.36, 0.42), "MEMBRANE": Color(0.78, 0.88, 0.90), "CREAM": Color(0.98, 0.97, 0.93), "MUTED": Color(0.78, 0.84, 0.86), "SUN": Color(1.0, 0.76, 0.62), "LEAF": Color(0.70, 0.88, 0.62), "CORAL": Color(0.98, 0.55, 0.52), "SHADE": Color(0.10, 0.15, 0.20, 0.35), "BACKDROP": Color(0.16, 0.21, 0.26), "TITLE": Color(0.25, 0.38, 0.48), "TITLE_OUTLINE": Color(0.97, 0.95, 0.90), "ROUND": 1.3, "RIM": 2, "CORNER_DETAIL": 16, "SMOOTH": true, "SHADOW_SIZE": 30, "SHADOW_OFFSET": Vector2(0, 10)}},
	{"id": "neon", "name": "Bioluminescent neon", "desc": "Glowing outlines in the dark abyss.",
		"fog": Color(0.01, 0.02, 0.05), "rim": Color(0.05, 0.30, 0.40), "dark": true, "swatch": Color(0.20, 0.95, 1.00),
		"ui": {"INK": Color(0.01, 0.03, 0.07), "INK_SOFT": Color(0.03, 0.07, 0.13), "MEMBRANE": Color(0.20, 0.95, 1.0), "CREAM": Color(0.86, 1.0, 1.0), "MUTED": Color(0.45, 0.72, 0.82), "SUN": Color(1.0, 0.45, 0.90), "LEAF": Color(0.45, 1.0, 0.55), "AQUA": Color(0.30, 0.95, 1.0), "CORAL": Color(1.0, 0.35, 0.45), "SHADE": Color(0.10, 0.85, 1.0, 0.30), "BACKDROP": Color(0.0, 0.01, 0.03), "TITLE": Color(0.60, 1.0, 1.0), "TITLE_OUTLINE": Color(0.05, 0.30, 0.55), "ROUND": 0.9, "RIM": 3, "CORNER_DETAIL": 12, "SMOOTH": true, "SHADOW_SIZE": 18, "SHADOW_OFFSET": Vector2(0, 0)}},
	{"id": "silhouette", "name": "Silhouette + rim light", "desc": "Dark shapes lit from behind with warm rims and light shafts.",
		"fog": Color(0.05, 0.15, 0.18), "rim": Color(0.65, 0.50, 0.25), "dark": true, "swatch": Color(0.20, 0.45, 0.48),
		"ui": {"INK": Color(0.02, 0.03, 0.04), "INK_SOFT": Color(0.06, 0.08, 0.09), "MEMBRANE": Color(0.95, 0.72, 0.35), "CREAM": Color(0.94, 0.95, 0.92), "MUTED": Color(0.58, 0.70, 0.70), "SUN": Color(1.0, 0.80, 0.40), "LEAF": Color(0.62, 0.88, 0.62), "CORAL": Color(1.0, 0.48, 0.35), "SHADE": Color(1.0, 0.70, 0.30, 0.18), "BACKDROP": Color(0.02, 0.06, 0.07), "TITLE": Color(0.03, 0.04, 0.05), "TITLE_OUTLINE": Color(1.0, 0.78, 0.40), "ROUND": 1.0, "RIM": 2, "CORNER_DETAIL": 12, "SMOOTH": true, "SHADOW_SIZE": 14, "SHADOW_OFFSET": Vector2(4, -4)}},
	{"id": "low_poly", "name": "Low-poly facets", "desc": "Flat-shaded triangles, like papercraft or a cut gem.",
		"fog": Color(0.11, 0.15, 0.21), "rim": Color(0.28, 0.36, 0.46), "dark": true, "swatch": Color(0.40, 0.55, 0.70),
		"ui": {"INK": Color(0.10, 0.14, 0.20), "INK_SOFT": Color(0.15, 0.21, 0.29), "MEMBRANE": Color(0.58, 0.72, 0.88), "CREAM": Color(0.94, 0.96, 0.98), "MUTED": Color(0.65, 0.72, 0.80), "SUN": Color(0.98, 0.78, 0.42), "LEAF": Color(0.62, 0.86, 0.55), "CORAL": Color(0.98, 0.50, 0.42), "SHADE": Color(0.02, 0.04, 0.08, 0.6), "BACKDROP": Color(0.06, 0.09, 0.13), "TITLE": Color(0.98, 0.82, 0.50), "TITLE_OUTLINE": Color(0.10, 0.14, 0.22), "ROUND": 0.8, "RIM": 3, "CORNER_DETAIL": 1, "SMOOTH": true, "SHADOW_SIZE": 1, "SHADOW_OFFSET": Vector2(0, 7)}},
	{"id": "soft_3d", "name": "Soft 3D", "desc": "Rounded lit volumes, soft shadows and rippling water light.",
		"fog": Color(0.09, 0.24, 0.26), "rim": Color(0.30, 0.55, 0.55), "dark": true, "swatch": Color(0.35, 0.70, 0.68),
		"ui": {"INK": Color(0.07, 0.20, 0.22), "INK_SOFT": Color(0.12, 0.30, 0.32), "MEMBRANE": Color(0.62, 0.92, 0.86), "CREAM": Color(0.97, 1.0, 0.98), "MUTED": Color(0.70, 0.86, 0.84), "SUN": Color(1.0, 0.86, 0.52), "LEAF": Color(0.66, 0.95, 0.60), "CORAL": Color(1.0, 0.55, 0.48), "SHADE": Color(0.0, 0.08, 0.08, 0.5), "BACKDROP": Color(0.04, 0.13, 0.14), "TITLE": Color(1.0, 0.92, 0.70), "TITLE_OUTLINE": Color(0.06, 0.22, 0.24), "ROUND": 1.5, "RIM": 2, "CORNER_DETAIL": 16, "SMOOTH": true, "SHADOW_SIZE": 34, "SHADOW_OFFSET": Vector2(0, 14)}},
]

static func ids() -> Array:
	return STYLES.map(func(s): return s.id)

static func get_style(id: String) -> Dictionary:
	for s in STYLES:
		if s.id == id:
			return s
	return STYLES[0]

# Sample picture for the menu picker (cut from the art options sheet)
static func thumb_path(id: String) -> String:
	return "res://assets/ui/art_styles/%s.png" % id

# Shared by every style: the screen, the era's paper level and noise helpers.
# light_lum is where the era's floor sits in brightness (EraLook ink_light),
# so expose() evens the eras out for the colour styles.
const PRELUDE = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float dark_lum = 0.05;
uniform float light_lum = 0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
vec3 tex(vec2 uv) { return texture(screen_tex, uv).rgb; }
vec3 expose(vec3 c) { return clamp(c * mix(1.0, 0.62 / max(light_lum, 0.2), 0.45), 0.0, 1.0); }
vec3 saturate_by(vec3 c, float k) { float l = luma(c); return clamp(mix(vec3(l), c, k), 0.0, 1.0); }
"""

# ---- Sepia sketchbook (the default; unchanged from PR #51) ----
const SEPIA = """
uniform vec3 paper : source_color = vec3(0.94, 0.88, 0.75);
uniform vec3 ink : source_color = vec3(0.27, 0.16, 0.09);
uniform float edge_threshold = 0.12;
uniform float edge_gain = 3.0;
uniform float wash = 0.14;
uniform float hatch_scale = 0.62;
uniform float boil_rate = 6.0;
uniform float wobble = 1.5;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	float boil = floor(TIME * boil_rate) * 17.0;
	vec2 w = vec2(vnoise(fc / 40.0 + boil), vnoise(fc / 40.0 + vec2(7.0, 3.0) + boil)) - 0.5;
	vec2 uv = SCREEN_UV + w * wobble * 2.0 * px;
	vec3 c = tex(SCREEN_UV);
	float o = 1.5;
	vec3 gx = tex(uv + vec2(o, 0.0) * px) - tex(uv - vec2(o, 0.0) * px);
	vec3 gy = tex(uv + vec2(0.0, o) * px) - tex(uv - vec2(0.0, o) * px);
	float edge = sqrt(dot(gx, gx) + dot(gy, gy));
	float line = clamp((edge - edge_threshold) * edge_gain, 0.0, 1.0);
	float v = smoothstep(dark_lum, light_lum, luma(c));
	float shade = 1.0 - v;
	vec3 chroma = c / max(max(c.r, max(c.g, c.b)), 0.001);
	vec3 base = paper * (1.0 - (1.0 - chroma) * wash);
	float n = vnoise(fc / 6.0) * 2.0;
	float h1 = step(0.55, sin((fc.x + fc.y) * hatch_scale + n) * 0.5 + 0.5);
	float h2 = step(0.55, sin((fc.x - fc.y) * hatch_scale + n) * 0.5 + 0.5);
	float hatch = max(clamp((shade - 0.35) * 3.0, 0.0, 1.0) * h1, clamp((shade - 0.65) * 3.0, 0.0, 1.0) * h2);
	float dark = clamp(shade * 0.35 + hatch * 0.55 + line * 0.9, 0.0, 1.0);
	float grain = (hash(fc) - 0.5) * 0.05 + (vnoise(fc / vec2(3.0, 90.0)) - 0.5) * 0.04;
	COLOR = vec4(mix(base, ink, dark) + grain, 1.0);
}
"""

# ---- 1. Chunky pixel: 6 px blocks, 4 shades a channel, black outline on
# the darker side of every colour edge ----
const CHUNKY_PIXEL = """
const float BLOCK = 6.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / BLOCK);
	vec2 uv = (cell + 0.5) * BLOCK * px;
	vec3 c = expose(tex(uv));
	float l = luma(c);
	float outline = 0.0;
	vec2 dirs[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 4; i++) {
		vec3 n = expose(tex(uv + dirs[i] * BLOCK * px));
		float d = length(n - c);
		if (d > 0.30 && luma(n) > l) outline = 1.0;
	}
	vec3 q = floor(saturate_by(c, 1.05) * 3.0 + 0.5) / 3.0;
	q = mix(q, vec3(0.13, 0.20, 0.24), 0.18); // a cool retro cast
	COLOR = vec4(mix(q, vec3(0.04, 0.03, 0.06), outline), 1.0);
}
"""

# ---- 2. 16-bit pixel: 3 px blocks, five shade bands with hue shifting
# (shadows cool, lights warm), outlines a dark shade of their own colour ----
const PIXEL_16BIT = """
const float BLOCK = 3.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / BLOCK);
	vec2 uv = (cell + 0.5) * BLOCK * px;
	vec3 c = expose(tex(uv));
	float l = luma(c);
	float outline = 0.0;
	vec2 dirs[4] = vec2[4](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 4; i++) {
		vec3 n = expose(tex(uv + dirs[i] * BLOCK * px));
		if (length(n - c) > 0.26 && luma(n) > l) outline = 1.0;
	}
	float band = floor(clamp(l, 0.0, 0.999) * 5.0);
	float target = (band + 0.5) / 5.0;
	vec3 hue = saturate_by(c, 1.1) / max(l, 0.05);
	vec3 shade = clamp(hue * target, 0.0, 1.0);
	// Hue shift: dark bands lean blue-violet, light bands lean warm yellow
	shade = mix(shade, shade * vec3(0.75, 0.80, 1.15), (1.0 - band / 4.0) * 0.5);
	shade = mix(shade, shade * vec3(1.12, 1.05, 0.85), (band / 4.0) * 0.35);
	vec3 line_col = shade * vec3(0.30, 0.25, 0.38);
	COLOR = vec4(mix(shade, line_col, outline), 1.0);
}
"""

# ---- 3. Hi-bit pixel: 2 px pixels, ordered dithering between six levels a
# channel, and a bright rim where light from the top left meets an edge ----
const HIBIT_PIXEL = """
const float BLOCK = 2.0;
float bayer2(vec2 a) { a = floor(a); return fract(a.x / 2.0 + a.y * a.y * 0.75); }
float bayer4(vec2 a) { return bayer2(0.5 * a) * 0.25 + bayer2(a); }
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 cell = floor(FRAGCOORD.xy / BLOCK);
	vec2 uv = (cell + 0.5) * BLOCK * px;
	vec3 c = saturate_by(expose(tex(uv)), 1.15);
	// Gradient over a few pixels for rim light and outlines
	float o = BLOCK * 1.5;
	float lx = luma(tex(uv + vec2(o, 0.0) * px)) - luma(tex(uv - vec2(o, 0.0) * px));
	float ly = luma(tex(uv + vec2(0.0, o) * px)) - luma(tex(uv - vec2(0.0, o) * px));
	vec2 g = vec2(lx, ly);
	float edge = length(g);
	// Light comes from the top left of the screen
	float rim = clamp(dot(-g, normalize(vec2(-1.0, -1.0))) * 3.0, 0.0, 1.0) * smoothstep(0.08, 0.25, edge);
	c += vec3(0.55, 0.75, 0.95) * rim * 0.35;
	float d = bayer4(cell) - 0.5;
	vec3 q = floor(c * 5.0 + d + 0.5) / 5.0;
	q *= 1.0 - smoothstep(0.25, 0.6, edge) * 0.55;
	q = mix(q, vec3(0.06, 0.10, 0.20), 0.12);
	COLOR = vec4(clamp(q, 0.0, 1.0), 1.0);
}
"""

# ---- 4. Bold ink cel: smoothed flat colour split into lit and one hard
# shadow, thick black outlines, a warm comic-paper cast ----
const INK_CEL = """
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 c = (tex(uv) * 2.0 + tex(uv + vec2(2.0, 0.0) * px) + tex(uv - vec2(2.0, 0.0) * px)
		+ tex(uv + vec2(0.0, 2.0) * px) + tex(uv - vec2(0.0, 2.0) * px)) / 6.0;
	c = expose(c);
	float l = luma(c);
	float o = 2.5;
	vec3 gx = tex(uv + vec2(o, 0.0) * px) - tex(uv - vec2(o, 0.0) * px);
	vec3 gy = tex(uv + vec2(0.0, o) * px) - tex(uv - vec2(0.0, o) * px);
	float edge = sqrt(dot(gx, gx) + dot(gy, gy)) / max(light_lum, 0.25) * 0.5;
	float line = smoothstep(0.16, 0.24, edge);
	vec3 hue = c / max(l, 0.2);
	float lit = smoothstep(0.47, 0.51, l);
	vec3 flat_col = clamp(hue * mix(0.40, 0.70, lit), 0.0, 1.0);
	flat_col = mix(vec3(luma(flat_col)), flat_col, 0.8);
	// Shine spot on the brightest parts
	flat_col = mix(flat_col, vec3(1.0, 0.97, 0.88), step(0.88, l) * 0.6);
	flat_col = mix(flat_col, flat_col * vec3(1.08, 0.98, 0.80), 0.6);
	COLOR = vec4(mix(flat_col, vec3(0.06, 0.04, 0.03), line), 1.0);
}
"""

# ---- 5. Naturalist engraving: engraved lines whose width follows the tone,
# crossed in deep shadow, stipple in the half tones, a hand-tinted wash ----
const ENGRAVING = """
uniform vec3 paper : source_color = vec3(0.93, 0.89, 0.79);
uniform vec3 ink : source_color = vec3(0.20, 0.15, 0.11);
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	vec2 uv = SCREEN_UV;
	vec3 c = tex(uv);
	float l = luma(c);
	float tone = 1.0 - smoothstep(dark_lum, light_lum, l);
	vec3 gx = tex(uv + vec2(1.0, 0.0) * px) - tex(uv - vec2(1.0, 0.0) * px);
	vec3 gy = tex(uv + vec2(0.0, 1.0) * px) - tex(uv - vec2(0.0, 1.0) * px);
	float edge = sqrt(dot(gx, gx) + dot(gy, gy));
	float line = smoothstep(0.10, 0.22, edge);
	// Fine parallel cuts, 4 px apart, gently curving
	float bend = vnoise(fc / 60.0) * 6.0;
	float s1 = sin((fc.x * 0.8 + fc.y * 0.6 + bend) * 1.57) * 0.5 + 0.5;
	float s2 = sin((fc.x * 0.6 - fc.y * 0.8 + bend) * 1.57) * 0.5 + 0.5;
	float cut1 = 1.0 - smoothstep(tone * 0.95 - 0.12, tone * 0.95, s1);
	float cut2 = (1.0 - smoothstep((tone - 0.55) * 1.6 - 0.12, (tone - 0.55) * 1.6, s2)) * step(0.55, tone);
	float stip = step(1.0 - tone * 0.22, hash(floor(fc)));
	float dark = clamp(max(max(cut1, cut2), stip) * 0.85 + line * 0.8, 0.0, 1.0);
	vec3 chroma = c / max(max(c.r, max(c.g, c.b)), 0.001);
	vec3 base = paper * mix(vec3(1.0), mix(vec3(1.0), chroma, 0.6), 0.55);
	float grain = (vnoise(fc / 2.0) - 0.5) * 0.04;
	COLOR = vec4(mix(base, ink, dark) + grain, 1.0);
}
"""

# ---- 6. Watercolour plate: colour smeared by a wandering brush, laid on
# white paper as a transparent wash, darker where pigment pools at edges ----
const WATERCOLOUR = """
uniform vec3 paper : source_color = vec3(0.97, 0.95, 0.90);
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	vec2 bleed = (vec2(vnoise(fc / 25.0), vnoise(fc / 25.0 + 9.0)) - 0.5) * 7.0;
	vec2 uv = SCREEN_UV + bleed * px;
	vec3 c = vec3(0.0);
	c += tex(uv);
	c += tex(uv + vec2(3.0, 1.0) * px);
	c += tex(uv + vec2(-1.0, 3.0) * px);
	c += tex(uv + vec2(-3.0, -1.0) * px);
	c += tex(uv + vec2(1.0, -3.0) * px);
	c = saturate_by(expose(c / 5.0), 1.15);
	// Edges from a wider look, so the pooled rim is soft
	float lx = luma(tex(uv + vec2(4.0, 0.0) * px)) - luma(tex(uv - vec2(4.0, 0.0) * px));
	float ly = luma(tex(uv + vec2(0.0, 4.0) * px)) - luma(tex(uv - vec2(0.0, 4.0) * px));
	float edge = smoothstep(0.05, 0.3, length(vec2(lx, ly)) / max(light_lum, 0.25));
	// Transparent wash: lighter than the source, multiplied on the paper
	vec3 wash = 1.0 - (1.0 - c) * 0.8;
	float pool = 1.0 - edge * 0.28;
	float granule = 1.0 - vnoise(fc / 3.0) * 0.06 - vnoise(fc / 70.0) * 0.07;
	COLOR = vec4(paper * wash * pool * granule, 1.0);
}
"""

# ---- 7. Bioluminescent neon: the dark abyss, every edge glowing in its own
# colour with a soft halo, bodies only faintly lit inside ----
const NEON = """
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;
	vec3 c = expose(tex(uv));
	vec3 near = (tex(uv + vec2(1.5, 0.0) * px) + tex(uv - vec2(1.5, 0.0) * px)
		+ tex(uv + vec2(0.0, 1.5) * px) + tex(uv - vec2(0.0, 1.5) * px));
	near = expose(near * 0.25);
	vec3 far = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		far += tex(uv + vec2(cos(a), sin(a)) * 7.0 * px);
	}
	far = expose(far / 8.0);
	float line = smoothstep(0.05, 0.16, length(c - near));
	float glow = smoothstep(0.04, 0.25, length(near - far));
	vec3 hue = saturate_by(max(c, far), 2.2);
	hue = hue / max(max(hue.r, max(hue.g, hue.b)), 0.05);
	hue = mix(vec3(0.3, 0.95, 1.0), hue, 0.65); // lean toward cyan biolight
	float pulse = 0.9 + 0.1 * sin(TIME * 2.0);
	vec3 col = vec3(0.005, 0.012, 0.035) + c * 0.06;
	col += hue * glow * 0.45 * pulse;
	col += mix(hue, vec3(1.0), 0.35) * line * 1.1 * pulse;
	COLOR = vec4(col, 1.0);
}
"""

# ---- 8. Silhouette and rim light: things darker than their surroundings become
# black shapes against a teal sea lit by slanting shafts, with warm rims
# on the side facing the light ----
const SILHOUETTE = """
float shape_at(vec2 uv, vec2 px) {
	float l = luma(tex(uv));
	float far = 0.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		far += luma(tex(uv + vec2(cos(a), sin(a)) * 36.0 * px));
	}
	far /= 8.0;
	// Standing out from its surroundings, lighter or darker: a shape
	float k = abs(far - l) / max(light_lum, 0.25);
	return smoothstep(0.10, 0.22, k);
}
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	vec2 uv = SCREEN_UV;
	float shape = shape_at(uv, px);
	float o = 3.0;
	float sx = shape_at(uv + vec2(o, 0.0) * px, px) - shape;
	float sy = shape_at(uv + vec2(0.0, o) * px, px) - shape;
	vec2 g = vec2(sx, sy);
	// The light is up and to the right of the screen; rims face it
	float rim = clamp(dot(-g, normalize(vec2(0.8, -1.0))) * 1.6, 0.0, 1.0);
	float ray = smoothstep(0.55, 1.0, sin((fc.x * 0.9 + fc.y * 0.45) / 70.0 + TIME * 0.25) * 0.5 + 0.5);
	ray *= 0.6 + 0.4 * vnoise(vec2(fc.x * 0.01 - fc.y * 0.005, TIME * 0.3));
	vec3 sea = mix(vec3(0.10, 0.28, 0.32), vec3(0.20, 0.45, 0.48), SCREEN_UV.y);
	sea += vec3(0.35, 0.55, 0.50) * ray * 0.25;
	// The floor's own pattern shows faintly in the water
	sea *= 0.9 + 0.15 * clamp(luma(tex(uv)) / max(light_lum, 0.25), 0.0, 1.0);
	vec3 col = mix(sea, vec3(0.03, 0.04, 0.05), smoothstep(0.3, 0.7, shape));
	col += vec3(1.0, 0.72, 0.32) * rim * 1.4;
	COLOR = vec4(col, 1.0);
}
"""

# ---- 9. Low-poly facets: the screen cut into 14 px triangles, each one a
# single colour from its middle, shaded by its slope like folded paper ----
const LOW_POLY = """
const float CELL = 14.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy / CELL;
	vec2 cell = floor(fc);
	vec2 f = fract(fc);
	float flip = mod(cell.x + cell.y, 2.0);
	if (flip > 0.5) f.x = 1.0 - f.x;
	bool lower = f.x > f.y;
	// The triangle's three corners in cell space, then on screen
	vec2 a = vec2(0.0, 0.0);
	vec2 b = lower ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec2 d = vec2(1.0, 1.0);
	if (flip > 0.5) { a.x = 1.0 - a.x; b.x = 1.0 - b.x; d.x = 1.0 - d.x; }
	vec2 mid = (a + b + d) / 3.0;
	vec2 to_uv = CELL * px;
	vec3 cm = tex((cell + mid) * to_uv);
	vec3 ca = tex((cell + mix(mid, a, 0.7)) * to_uv);
	vec3 cb = tex((cell + mix(mid, b, 0.7)) * to_uv);
	vec3 cd = tex((cell + mix(mid, d, 0.7)) * to_uv);
	vec3 c = expose((cm * 2.0 + ca + cb + cd) / 5.0);
	// Facet tilt from brightness across its corners
	vec2 slope = vec2(luma(cb) - luma(ca), luma(cd) - luma(cb));
	float facet = 0.92 + clamp(dot(slope, vec2(-1.2, 1.2)), -0.15, 0.15) + (hash(cell * 2.0 + (lower ? 0.5 : 0.0)) - 0.5) * 0.16;
	c = saturate_by(c, 1.1) * facet;
	// A faint fold along each triangle's edges
	float seam = min(min(abs(f.x - f.y), f.y), 1.0 - f.x);
	c *= 1.0 - 0.07 * (1.0 - smoothstep(0.0, 0.08, seam));
	COLOR = vec4(mix(c, vec3(0.10, 0.14, 0.22), 0.1), 1.0);
}
"""

# ---- 10. Soft 3D: brightness read as height and lit like smooth rounded
# volumes, with a soft drop shadow and caustic light rippling over all ----
const SOFT_3D = """
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	vec2 uv = SCREEN_UV;
	vec3 c = (tex(uv) * 2.0 + tex(uv + vec2(1.5, 0.0) * px) + tex(uv - vec2(1.5, 0.0) * px)
		+ tex(uv + vec2(0.0, 1.5) * px) + tex(uv - vec2(0.0, 1.5) * px)) / 6.0;
	c = expose(c);
	float o = 3.0;
	float hx = luma(tex(uv + vec2(o, 0.0) * px)) - luma(tex(uv - vec2(o, 0.0) * px));
	float hy = luma(tex(uv + vec2(0.0, o) * px)) - luma(tex(uv - vec2(0.0, o) * px));
	vec3 n = normalize(vec3(-hx * 3.0, -hy * 3.0, 1.0));
	vec3 L = normalize(vec3(-0.5, -0.6, 0.8));
	float diff = 0.72 + 0.45 * dot(n, L);
	float spec = pow(max(dot(reflect(-L, n), vec3(0.0, 0.0, 1.0)), 0.0), 24.0) * 0.35 * smoothstep(0.02, 0.1, length(vec2(hx, hy)));
	// Drop shadow: something darker up and to the left casts onto here
	float l_here = luma(tex(uv));
	float l_cast = luma(tex(uv - vec2(-7.0, -9.0) * px));
	float shadow = clamp((l_here - l_cast) / max(light_lum, 0.25), 0.0, 1.0) * 0.35;
	vec3 col = saturate_by(c, 1.15) * diff * (1.0 - shadow) + vec3(1.0, 0.98, 0.92) * spec;
	// Caustics: bright wandering ribbons of light through the water
	vec2 q = fc / 160.0;
	float k = abs(vnoise(q + vec2(TIME * 0.12, 0.0)) - vnoise(q * 1.3 - vec2(0.0, TIME * 0.10)));
	col += vec3(0.55, 0.85, 0.80) * smoothstep(0.12, 0.0, k) * 0.07;
	col = mix(col, vec3(0.10, 0.28, 0.30), 0.08);
	COLOR = vec4(col, 1.0);
}
"""

static func shader_code(id: String) -> String:
	var body: String
	match id:
		"chunky_pixel": body = CHUNKY_PIXEL
		"pixel_16bit": body = PIXEL_16BIT
		"hibit_pixel": body = HIBIT_PIXEL
		"ink_cel": body = INK_CEL
		"engraving": body = ENGRAVING
		"watercolour": body = WATERCOLOUR
		"neon": body = NEON
		"silhouette": body = SILHOUETTE
		"low_poly": body = LOW_POLY
		"soft_3d": body = SOFT_3D
		_: body = SEPIA
	return PRELUDE + body

# One compiled shader per style, shared by every filter that uses it
static var _cache := {}
static func shader(id: String) -> Shader:
	if not _cache.has(id):
		var sh = Shader.new()
		sh.code = shader_code(id)
		_cache[id] = sh
	return _cache[id]

# Whether pictures outside the world (menus, codex, pause screen) should get
# the sepia tint: only for the ink-on-paper styles, otherwise they keep
# their own colours
static func uses_sepia(id: String) -> bool:
	return id == "sepia" or id == "engraving"
