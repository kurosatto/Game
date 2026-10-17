# InkFilter.gd
# Turns the world into a naturalist's sepia ink sketch: one full-screen pass
# over everything drawn below it (rooms, scenery, animals, the player) that
# maps light and dark onto paper and brown ink, keeps only a pale wash of the
# original colours, hatches the shadows with pen strokes, and inks every edge
# with a slightly wobbly line that redraws a few times a second like a
# hand-drawn animation. Sits in the VisionFog layer under the fog, so unseen
# parts of the room stay blank paper, and under the HUD.
extends ColorRect

const SHADER_CODE = """
shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec3 paper : source_color = vec3(0.94, 0.88, 0.75);
uniform vec3 ink : source_color = vec3(0.27, 0.16, 0.09);
// Scene brightness that maps to solid ink .. bare paper
uniform float dark_lum = 0.05;
uniform float light_lum = 0.45;
uniform float edge_threshold = 0.12;
uniform float edge_gain = 3.0;
uniform float wash = 0.14;
uniform float hatch_scale = 0.62;
// Line boil: how often (per second) the wobble is redrawn
uniform float boil_rate = 6.0;
uniform float wobble = 1.5;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 fc = FRAGCOORD.xy;
	float boil = floor(TIME * boil_rate) * 17.0;
	vec2 w = vec2(vnoise(fc / 40.0 + boil), vnoise(fc / 40.0 + vec2(7.0, 3.0) + boil)) - 0.5;
	vec2 uv = SCREEN_UV + w * wobble * 2.0 * px;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float o = 1.5;
	vec3 gx = texture(screen_tex, uv + vec2(o, 0.0) * px).rgb - texture(screen_tex, uv - vec2(o, 0.0) * px).rgb;
	vec3 gy = texture(screen_tex, uv + vec2(0.0, o) * px).rgb - texture(screen_tex, uv - vec2(0.0, o) * px).rgb;
	float edge = sqrt(dot(gx, gx) + dot(gy, gy));
	float line = clamp((edge - edge_threshold) * edge_gain, 0.0, 1.0);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float v = smoothstep(dark_lum, light_lum, lum);
	float shade = 1.0 - v;
	// A pale wash of the original hue on the paper
	vec3 chroma = c / max(max(c.r, max(c.g, c.b)), 0.001);
	vec3 base = paper * (1.0 - (1.0 - chroma) * wash);
	// Pen hatching: one direction in mid shadow, crossed in deep shadow
	float n = vnoise(fc / 6.0) * 2.0;
	float h1 = step(0.55, sin((fc.x + fc.y) * hatch_scale + n) * 0.5 + 0.5);
	float h2 = step(0.55, sin((fc.x - fc.y) * hatch_scale + n) * 0.5 + 0.5);
	float hatch = max(clamp((shade - 0.35) * 3.0, 0.0, 1.0) * h1, clamp((shade - 0.65) * 3.0, 0.0, 1.0) * h2);
	float dark = clamp(shade * 0.35 + hatch * 0.55 + line * 0.9, 0.0, 1.0);
	float grain = (hash(fc) - 0.5) * 0.05 + (vnoise(fc / vec2(3.0, 90.0)) - 0.5) * 0.04;
	COLOR = vec4(mix(base, ink, dark) + grain, 1.0);
}
"""

const EraLook = preload("res://data/EraLook.gd")
var mat: ShaderMaterial

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = SHADER_CODE
	mat = ShaderMaterial.new()
	mat.shader = shader
	material = mat

# Each era's floor is a different brightness, so each sets where bare paper
# starts (EraLook "ink_light"): dark swamps still read as paper, not ink
func _process(_delta: float):
	var main = get_tree().current_scene
	if main == null or not ("floor_number" in main):
		return
	var light: float = EraLook.get_look(main.floor_number).get("ink_light", 0.45)
	mat.set_shader_parameter("light_lum", light)
	mat.set_shader_parameter("dark_lum", light * 0.12)
