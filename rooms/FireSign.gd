# FireSign.gd
# The oxygen-room warning (kuro): from walking into a WILDFIRE room until the
# lightning lands, an inked sign floats beside you on the side the fire will
# come from, with a ring that runs down to the strike. Drawn on the fog layer
# (like DoorMarks) so the dark never hides it. Pen and ochre, no glow.
extends Control

const INK = Color(0.24, 0.15, 0.08)

var fire: Node2D = null # rooms/Wildfire.gd

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float):
	if fire == null or not is_instance_valid(fire) or not fire.is_inside_tree() or fire.state.get("lit", false) or fire.state.get("done", false):
		queue_free()
		return
	queue_redraw()

func _draw():
	var player = fire.player
	if player == null or not is_instance_valid(player):
		return
	var room = fire.room
	# Room space, like DoorMarks: beside the player, toward the far side where
	# the strike will land, kept on screen
	draw_set_transform_matrix(get_global_transform_with_canvas().affine_inverse() * room.get_global_transform_with_canvas())
	var p = player.global_position - room.global_position
	var c = p + Vector2(-fire.state.dir * 170.0, -120.0)
	c.x = clamp(c.x, 110.0, 1810.0)
	c.y = clamp(c.y, 190.0, 860.0)
	_draw_sign(c)
	draw_set_transform_matrix(Transform2D.IDENTITY)

# A triangle with a flame in it, "HIGH OXYGEN" under it, and a ring that runs
# down to the lightning. Pen and ochre like the door marks, no glow.
func _draw_sign(c: Vector2):
	var left: float = clamp(fire.state.get("delay", fire.DELAY) / fire.DELAY, 0.0, 1.0)
	var time: float = fire.time
	# Pulses faster as the strike nears
	var pulse = 1.0 + 0.06 * sin(time * lerp(16.0, 7.0, left))
	var r = 52.0 * pulse
	var ochre = Color(0.86, 0.5, 0.14)
	var paper = Color(0.97, 0.93, 0.82)
	var tri = PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.95, r * 0.62), c + Vector2(-r * 0.95, r * 0.62)])
	draw_colored_polygon(tri, Color(paper, 0.92))
	var edge = tri.duplicate()
	edge.append(tri[0])
	draw_polyline(edge, Color(paper, 0.8), 13.0, true)
	draw_polyline(edge, INK, 7.0, true)
	draw_polyline(edge, ochre, 3.0, true)
	# A flame inside
	var f = c + Vector2(0, r * 0.38)
	var sway = sin(time * 9.0) * 4.0
	var flame = PackedVector2Array([f + Vector2(-20, 0), f + Vector2(-18, -24), f + Vector2(-6, -34), f + Vector2(sway, -60), f + Vector2(10, -30), f + Vector2(20, -22), f + Vector2(18, 0)])
	draw_colored_polygon(flame, Color(0.62, 0.26, 0.1))
	var core = PackedVector2Array([f + Vector2(-9, -2), f + Vector2(-6, -18), f + Vector2(sway * 0.5, -34), f + Vector2(8, -16), f + Vector2(8, -2)])
	draw_colored_polygon(core, Color(0.96, 0.78, 0.45))
	var fl = flame.duplicate()
	fl.append(flame[0])
	draw_polyline(fl, INK, 2.5, true)
	# Countdown ring to the strike
	draw_arc(c + Vector2(0, 8), r + 26.0, -PI / 2.0, -PI / 2.0 + TAU * left, 48, Color(paper, 0.8), 9.0, true)
	draw_arc(c + Vector2(0, 8), r + 26.0, -PI / 2.0, -PI / 2.0 + TAU * left, 48, INK, 4.5, true)
	# Caption
	var font = ThemeDB.fallback_font
	var txt = "HIGH OXYGEN"
	var size = 26
	var w = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at = c + Vector2(-w / 2.0, r + 64.0)
	draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color(paper, 0.9))
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, INK)
	var sub = "FIRE COMING"
	var w2 = font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var at2 = c + Vector2(-w2 / 2.0, r + 92.0)
	draw_string_outline(font, at2, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 7, Color(paper, 0.9))
	draw_string(font, at2, sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ochre.darkened(0.35))
