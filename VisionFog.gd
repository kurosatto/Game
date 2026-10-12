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

void fragment() {
	float d = distance(UV * rect_size, center);
	float a = smoothstep(radius, radius + softness, d) * darkness;
	COLOR = vec4(fog_color, a);
}
"""

var rect: ColorRect
var hints: Control
var mat: ShaderMaterial
var player: Node2D

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
	var screen_pos = player.get_global_transform_with_canvas().origin
	var local_pos = rect.get_global_transform_with_canvas().affine_inverse() * screen_pos
	mat.set_shader_parameter("rect_size", rect.size)
	mat.set_shader_parameter("center", local_pos)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("softness", radius * 0.7)
	mat.set_shader_parameter("darkness", darkness)
