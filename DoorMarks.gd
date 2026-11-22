# DoorMarks.gd
# Inked gateposts over every doorway, drawn above the ink filter and the vision
# fog so exits always read as exits. The ink pass turns the door sprites into
# wall-coloured smudges, so the door state is drawn here in plain pen strokes:
#   open   - a small chevron pointing out of the room
#   shut   - two short ink bars across the doorway
#   locked - ochre bars and a small padlock (the key badge says USE / NEED KEY)
extends Control

const INK = Color(0.27, 0.16, 0.09)
const PAPER = Color(0.97, 0.93, 0.82)
const OCHRE = Color(0.78, 0.52, 0.16)

func _ready():
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float):
	queue_redraw()

func _draw():
	var to_local = get_global_transform_with_canvas().affine_inverse()
	var t = Time.get_ticks_msec() * 0.001
	for door in get_tree().get_nodes_in_group("doors"):
		if door.is_queued_for_deletion() or not door.is_visible_in_tree():
			continue
		# Door space: x runs along the wall, -y points out of the room
		# Nudged into the room so the top door clears the HUD bar and the side
		# doors stay on screen
		draw_set_transform_matrix(to_local * door.get_global_transform_with_canvas() * Transform2D(0.0, Vector2(0, 34)))
		_draw_door(door, t)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_door(door, t: float):
	# Small marks with no frame around them (kuro found the big boxed arrows
	# distracting): a pale outline under each ink stroke keeps them readable
	# on dark fog and on paper alike
	if door.is_open:
		# A small chevron pointing out through the doorway, bobbing gently
		var bob = -sin(t * 3.0) * 4.0
		var pts = PackedVector2Array([Vector2(-14, 6 + bob), Vector2(0, -8 + bob), Vector2(14, 6 + bob)])
		draw_polyline(pts, Color(PAPER, 0.75), 8.0, true)
		draw_polyline(pts, INK, 4.0, true)
	else:
		# Two short ink bars across the doorway
		for y in [-6.0, 6.0]:
			draw_line(Vector2(-20, y), Vector2(20, y), Color(PAPER, 0.75), 8.0, true)
			draw_line(Vector2(-20, y), Vector2(20, y), INK if not door.is_locked else OCHRE.darkened(0.3), 4.0, true)
		if door.is_locked:
			_draw_padlock(Vector2(0, 26))

func _draw_padlock(c: Vector2):
	draw_arc(c + Vector2(0, -5), 7, PI, TAU, 12, INK, 5.0, true)
	draw_arc(c + Vector2(0, -5), 7, PI, TAU, 12, OCHRE, 2.0, true)
	var body = Rect2(c + Vector2(-11, -5), Vector2(22, 17))
	draw_rect(body, INK)
	draw_rect(body.grow(-2), OCHRE)
	draw_circle(c + Vector2(0, 2), 2.5, INK)
