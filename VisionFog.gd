# VisionFog.gd
# Darkness around the player whose size follows how well the current form sees
# (data/Lineages.gd VISION). One full-screen rect with a tiny shader, so it
# stays cheap on the phone's Compatibility renderer. SenseHints.gd draws arrows
# toward enemies hidden in the dark on top of it.
extends CanvasLayer

const SHADER_CODE = """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1920.0, 1080.0);
uniform vec2 center = vec2(960.0, 540.0);
uniform float radius = 400.0;
uniform float softness = 300.0;
uniform float darkness = 0.85;
// Unseen parts of the screen are black, in every art style
uniform vec3 fog_color : source_color = vec3(0.0, 0.0, 0.0);
uniform vec3 rim_color : source_color = vec3(0.55, 0.42, 0.3);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
// Doorways stay visible even to a nearly blind form, so exits can be found
// Glowing animals in a dark cave (rooms/GlowCritter.gd): x, y, radius
uniform vec3 lights[12];
uniform int light_count = 0;
// 0 normally, 1 in a glowing cave: the fog turns to real darkness
uniform float cave = 0.0;
// How black the cave is: a glowing cave leaves a trace, a pitch-dark room none
uniform float cave_alpha = 0.97;

void fragment() {
	vec2 p = UV * rect_size;
	float a = smoothstep(radius, radius + softness, distance(p, center));
	for (int i = 0; i < light_count; i++) {
		a = min(a, smoothstep(lights[i].z * 0.35, lights[i].z, distance(p, lights[i].xy)));
	}
	vec3 col = fog_color;
	// A faint tint of the art style's rim colour where sight fades out
	float rim = smoothstep(0.0, 0.5, a) * (1.0 - smoothstep(0.5, 1.0, a));
	col = mix(col, rim_color, rim * 0.18 * (1.0 - cave));
	COLOR = vec4(col, a * mix(darkness, cave_alpha, cave));
}
"""

var rect: ColorRect
var hints: Control
var mat: ShaderMaterial
var player # Player.gd (uses its drawn_position())

# Current values, eased toward the target after each evolution
var radius: float = 0.0
var darkness: float = 0.0
var target_radius: float = 0.0
var cave: float = 0.0
var target_darkness: float = 0.0
var pitch: float = 0.0 # 1 in a pitch-dark room (data/SpecialRooms.gd "dark")

# How far you actually see this frame: a cave closes the light in, and a
# pitch-dark room leaves only a glimmer around your own body
const EYELESS_RADIUS := 110.0
var eyeless: bool = false

func light_radius() -> float:
	# Eyeless forms never used light, so a dark room takes nothing from them
	if eyeless:
		return radius
	return radius * (1.0 - 0.3 * cave - 0.32 * pitch)

func _ready():
	# Above the world, below the HUD (layer 2), touch controls and transitions
	layer = 1
	follow_viewport_enabled = false
	# The ink-sketch pass reads everything drawn so far, so it goes first
	add_child(preload("res://InkFilter.gd").new())
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = SHADER_CODE
	mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
	apply_style(SettingsManager.art_style)
	SettingsManager.art_style_changed.connect(apply_style)
	# Doorways drawn over the fog and ink so exits always show
	add_child(preload("res://DoorMarks.gd").new())
	hints = preload("res://SenseHints.gd").new()
	hints.fog = self
	add_child(hints)
	set_vision(1, true)

# The fog is black in every style (kuro asked for unseen parts to be black);
# only the faint rim where sight fades follows the style (data/ArtStyles.gd)
func apply_style(id: String):
	var st: Dictionary = preload("res://data/ArtStyles.gd").get_style(id)
	mat.set_shader_parameter("fog_color", Color(0, 0, 0))
	mat.set_shader_parameter("rim_color", st.rim)

# rating: 1-10 and the sense's name from Lineages.SENSES
func set_sense(rating: int, kind: String, profile: Dictionary = {}):
	hints.set_sense(rating, kind, profile)

# rating: 0 (eyeless) to 10 (best eyes alive)
func set_vision(rating: int, instant: bool = false):
	var r = clamp(rating, 0, 10)
	# Kept tight so sight matters: even the best eyes leave the far corners of
	# the room in shadow. Forms with no eyes at all (the cell, crinoids, urchins,
	# sea cucumbers, burrowing bivalves) see only a hand's width past their
	# body and live by their other senses, which reach further (SenseHints.gd).
	eyeless = r == 0
	target_radius = EYELESS_RADIUS if eyeless else 180.0 + r * 40.0 # 220 px blind, 580 px for a dragonfly
	# Past the soft edge it is solid black, whatever the eyes
	target_darkness = 1.0
	if instant:
		radius = target_radius
		darkness = target_darkness

func _process(delta: float):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	radius = move_toward(radius, target_radius, delta * 400.0)
	# A glowing cave (rooms/SpecialRoom.gd): darker, and you see less
	var main = get_tree().get_first_node_in_group("main")
	var room = main.get("current_room_node") if main else null
	var special = room.room_data.special if room != null and is_instance_valid(room) and room.get("room_data") != null else ""
	var in_cave = special == "glow" or special == "dark"
	cave = move_toward(cave, 1.0 if in_cave else 0.0, delta * 1.5)
	pitch = move_toward(pitch, 1.0 if special == "dark" else 0.0, delta * 1.5)
	mat.set_shader_parameter("cave", cave)
	mat.set_shader_parameter("cave_alpha", 1.0)
	var lights: Array = []
	if cave > 0.0:
		for g in get_tree().get_nodes_in_group("fog_lights"):
			if lights.size() >= 12:
				break
			if g.is_queued_for_deletion():
				continue
			var lp = rect.get_global_transform_with_canvas().affine_inverse() * (g.get_global_transform_with_canvas() * Vector2.ZERO)
			var scale_f = g.get_global_transform_with_canvas().get_scale().x
			lights.append(Vector3(lp.x, lp.y, g.light_radius * scale_f))
	mat.set_shader_parameter("light_count", lights.size())
	if not lights.is_empty():
		lights.resize(12)
		for i in 12:
			if lights[i] == null:
				lights[i] = Vector3.ZERO
		mat.set_shader_parameter("lights", PackedVector3Array(lights))
	darkness = move_toward(darkness, target_darkness, delta * 0.4)
	# Interpolated position: where the player is drawn this frame
	var screen_pos = player.get_canvas_transform() * player.drawn_position()
	var local_pos = rect.get_global_transform_with_canvas().affine_inverse() * screen_pos
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("center", local_pos)
	mat.set_shader_parameter("radius", light_radius())
	# Pitch dark has a hard edge: the glimmer stops close to your body
	mat.set_shader_parameter("softness", radius * 0.6 * (1.0 - 0.55 * pitch))
	mat.set_shader_parameter("darkness", darkness)
	# No lit patch around doorways (kuro: no lights on doors): the inked
	# DoorMarks are drawn above the fog, so exits still show in the dark
