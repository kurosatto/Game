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
uniform vec3 fog_color : source_color = vec3(0.0, 0.02, 0.05);
// Doorways stay visible even to a nearly blind form, so exits can be found
uniform vec2 doors[8];
uniform int door_count = 0;
uniform float door_radius = 150.0;

void fragment() {
	vec2 p = UV * rect_size;
	float a = smoothstep(radius, radius + softness, distance(p, center));
	for (int i = 0; i < door_count; i++) {
		a = min(a, smoothstep(door_radius * 0.6, door_radius, distance(p, doors[i])));
	}
	COLOR = vec4(fog_color, a * darkness);
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
var target_darkness: float = 0.0

func _ready():
	# Above the world, below the HUD (layer 2), touch controls and transitions
	layer = 1
	follow_viewport_enabled = false
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = SHADER_CODE
	mat = ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
	hints = preload("res://SenseHints.gd").new()
	hints.fog = self
	add_child(hints)
	set_vision(1, true)

# rating: 1-10 and the sense's name from Lineages.SENSES
func set_sense(rating: int, kind: String):
	hints.set_sense(rating, kind)

# rating: 1 (blind) to 10 (best eyes alive)
func set_vision(rating: int, instant: bool = false):
	var r = clamp(rating, 1, 10)
	target_radius = 200.0 + r * 110.0      # 310 px for a cell, 1300 px for a dragonfly
	target_darkness = 0.97 - r * 0.06      # 0.91 for a cell, 0.37 for a dragonfly
	if instant:
		radius = target_radius
		darkness = target_darkness

func _process(delta: float):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	radius = move_toward(radius, target_radius, delta * 400.0)
	darkness = move_toward(darkness, target_darkness, delta * 0.4)
	# Interpolated position: where the player is drawn this frame
	var screen_pos = player.get_canvas_transform() * player.drawn_position()
	var local_pos = rect.get_global_transform_with_canvas().affine_inverse() * screen_pos
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("center", local_pos)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("softness", radius * 0.7)
	mat.set_shader_parameter("darkness", darkness)
	var door_pts := PackedVector2Array()
	for door in get_tree().get_nodes_in_group("doors"):
		if door_pts.size() >= 8:
			break
		if door.is_queued_for_deletion():
			continue
		# A point just inside the doorway, so the doorway and its key badge show
		var inside = door.get_global_transform_with_canvas() * Vector2(0, 90)
		door_pts.append(rect.get_global_transform_with_canvas().affine_inverse() * inside)
	var padded = door_pts.duplicate()
	padded.resize(8)
	mat.set_shader_parameter("doors", padded)
	mat.set_shader_parameter("door_count", door_pts.size())
