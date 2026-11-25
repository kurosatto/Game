# HitPen.gd
# An InkBatch that also remembers where it drew, so a boss can be hit
# wherever it is drawn: tail, shell, sail, legs and all, in every pose.
# Every solid stroke, dot and polygon is kept as a hit piece in the space of
# the node being drawn (draw_set_transform applied):
#   [a, b, half width]                 a capsule (a == b for a dot)
#   [points, centre, bound radius]     a polygon
# Faint marks (glints, ripples, attack warnings) are left out, and so is
# anything drawn while `solid` is false. bosses/BossBase.gd gap_to() tests
# shots, bites and blasts against the pieces.
extends "res://InkBatch.gd"

const MIN_ALPHA := 0.6
var solid := true
var hits: Array = []

func begin(target: CanvasItem):
	super.begin(target)
	hits = []

# The pieces drawn since begin(); call after flush()
func take_hits() -> Array:
	var h := hits
	hits = []
	return h

func hit_seg(a: Vector2, b: Vector2, half_w: float):
	if solid:
		hits.append([xf * a, xf * b, max(half_w * _xf_scale, 2.0)])

func hit_poly(pts: PackedVector2Array):
	if not solid or pts.size() < 3:
		return
	var q: PackedVector2Array = xf * pts
	var c := Vector2.ZERO
	for v in q:
		c += v
	c /= q.size()
	var r := 0.0
	for v in q:
		r = max(r, c.distance_to(v))
	hits.append([q, c, r])

func draw_ellipse(pos: Vector2, major: float, minor: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	super.draw_ellipse(pos, major, minor, color, filled, width, antialiased)
	if color.a >= MIN_ALPHA:
		hit_seg(pos, pos, max(major, minor) + (0.0 if filled else max(width, 1.0) * 0.5))

func draw_polygon(points: PackedVector2Array, colors: PackedColorArray, _uvs: PackedVector2Array = PackedVector2Array(), _texture: Texture2D = null):
	super.draw_polygon(points, colors, _uvs, _texture)
	if not colors.is_empty() and colors[0].a >= MIN_ALPHA:
		hit_poly(points)

func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false):
	super.draw_line(from, to, color, width, antialiased)
	if color.a >= MIN_ALPHA:
		hit_seg(from, to, max(width, 1.0) * 0.5)

func draw_polyline_colors(points: PackedVector2Array, colors: PackedColorArray, width: float = -1.0, antialiased: bool = false):
	super.draw_polyline_colors(points, colors, width, antialiased)
	if not colors.is_empty() and colors[0].a >= MIN_ALPHA:
		for i in points.size() - 1:
			hit_seg(points[i], points[i + 1], max(width, 1.0) * 0.5)
