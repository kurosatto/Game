# SenseHints.gd
# Faint arrows at the edge of the lit circle pointing at enemies hidden in the
# dark, standing in for smell, vibration, the lateral line or electric sense
# (data/Lineages.gd SENSES). A stronger sense reaches further and draws clearer
# arrows. Lives on the VisionFog layer and reads its radius.
extends Control

const KIND_COLORS = {
	"Smell": Color(1.0, 0.75, 0.3),
	"Chemical sense": Color(0.6, 1.0, 0.4),
	"Electroreception": Color(0.5, 0.85, 1.0),
	"Lateral line": Color(0.3, 1.0, 0.85),
	"Vibration": Color(1.0, 0.55, 0.45),
	"Touch": Color(0.9, 0.9, 1.0),
}

var fog: Node
var player: Node2D
var sense: int = 1
var color: Color = Color(1, 1, 1)
var time: float = 0.0

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_sense(rating: int, kind: String):
	sense = clamp(rating, 1, 10)
	color = KIND_COLORS.get(kind, Color(1, 1, 1))

func _process(delta: float):
	time += delta
	queue_redraw()

func _draw():
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_local = get_global_transform_with_canvas().affine_inverse()
	var center = to_local * player.get_global_transform_with_canvas().origin
	var radius: float = fog.radius
	var reach = 300.0 + sense * 150.0          # 450 px past the light for 1, 1800 for 10
	var clarity = 0.35 + sense * 0.06          # arrow opacity at its strongest
	var ring = clamp(radius * 0.8, 110.0, 320.0)
	var pulse = 0.85 + 0.15 * sin(time * 4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Node2D) or not e.is_inside_tree():
			continue
		var pos = to_local * e.get_global_transform_with_canvas().origin
		var d = center.distance_to(pos)
		if d < radius * 0.9 or d > radius + reach:
			continue
		var strength = clarity * (1.0 - max(0.0, d - radius) / reach) * pulse
		var dir = (pos - center) / d
		var size = 10.0 + sense * 1.2
		if e.has_method("is_boss") and e.is_boss():
			size *= 1.8
		var tip = center + dir * (ring + size)
		var side = dir.orthogonal() * size * 0.7
		var back = tip - dir * size
		var c = Color(color.r, color.g, color.b, strength)
		draw_polyline(PackedVector2Array([back + side, tip, back - side]), c, 4.0, true)
