# DoorMarks.gd
# Inked gateposts over every doorway, drawn above the ink filter and the vision
# fog so exits always read as exits. The ink pass turns the door sprites into
# wall-coloured smudges, so the door state is drawn here in plain pen strokes:
#   open   - posts with a bright gap and an arrow pointing out of the room
#   shut   - posts with ink bars across the gap
#   locked - bars plus an ochre padlock (the key badge says USE / NEED KEY)
extends Control

const INK = Color(0.27, 0.16, 0.09)
const PAPER = Color(0.97, 0.93, 0.82)
const OCHRE = Color(0.78, 0.52, 0.16)
const HALF_GAP = 64.0   # the wall opening is 128 px wide (Room.gd)

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
	var top = -44.0
	var bottom = 44.0
	# Gap between the posts
	var gap = Rect2(-HALF_GAP + 8, top, HALF_GAP * 2 - 16, bottom - top)
	var fill = PAPER
	if door.is_open:
		fill = PAPER.lerp(Color(1, 1, 0.92), 0.5 + 0.5 * sin(t * 4.0))
	draw_rect(gap, Color(fill, 0.9))
	if door.is_open:
		# Arrow pointing out through the doorway, bobbing outward
		var bob = -sin(t * 4.0) * 6.0
		var tip = Vector2(0, -28 + bob)
		var pts = PackedVector2Array([Vector2(-26, 2 + bob), tip, Vector2(26, 2 + bob)])
		draw_polyline(pts, INK, 9.0, true)
		draw_line(Vector2(0, tip.y + 4), Vector2(0, 30 + bob), INK, 7.0, true)
	else:
		# Ink bars across the gap, a little uneven like a pen stroke
		for i in 4:
			var y = lerp(top + 12, bottom - 12, i / 3.0)
			draw_line(Vector2(-HALF_GAP + 4, y - 3), Vector2(HALF_GAP - 4, y + 3), INK, 7.0, true)
		if door.is_locked:
			_draw_padlock(Vector2(0, 0))
	# Gateposts on each side, outlined in ink
	for sx in [-1.0, 1.0]:
		var post = Rect2(sx * HALF_GAP - 10, top - 8, 20, bottom - top + 16)
		draw_rect(post, OCHRE if door.is_locked else INK)
		draw_rect(post.grow(-5), PAPER.darkened(0.15))
	# Threshold line on the room side
	draw_line(Vector2(-HALF_GAP - 12, bottom + 10), Vector2(HALF_GAP + 12, bottom + 10), INK, 5.0, true)

func _draw_padlock(c: Vector2):
	draw_arc(c + Vector2(0, -10), 14, PI, TAU, 16, INK, 9.0, true)
	draw_arc(c + Vector2(0, -10), 14, PI, TAU, 16, OCHRE, 4.0, true)
	var body = Rect2(c + Vector2(-22, -10), Vector2(44, 34))
	draw_rect(body, INK)
	draw_rect(body.grow(-4), OCHRE)
	draw_circle(c + Vector2(0, 3), 5, INK)
	draw_line(c + Vector2(0, 5), c + Vector2(0, 16), INK, 4.0)
