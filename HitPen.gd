# HitPen.gd
# An InkBatch that also remembers where it drew, so a boss can be hit
# wherever it is drawn: tail, shell, sail, legs and all, in every pose.
# Every solid stroke, dot and polygon is kept as a hit piece in the space of
# the node being drawn (draw_set_transform applied):
#   [a, b, half width, hairline]       a capsule (a == b for a dot)
#   [points, centre, bound radius]     a polygon
# Faint marks (glints, ripples, attack warnings) are left out, and so is
# anything drawn while `solid` is false. bosses/BossBase.gd gap_to() tests
# shots, bites and blasts against the pieces.
extends "res://InkBatch.gd"

const MIN_ALPHA := 0.6
const HAIRLINE := 2.5 # half width, drawing units: thinner strokes are feelers, legs, flagella, outlines
var solid := true
var hits: Array = []
# Polylines are kept whole ([transform, points, half width]) and only cut into
# capsules if something asks where the body is (most frames nobody does)
var polys: Array = []

func begin(target: CanvasItem):
	super.begin(target)
	hits = []
	polys = []

# The pieces drawn since begin(); call after flush()
func take_hits() -> Array:
	var h := expand([hits, polys])
	hits = []
	polys = []
	return h

# The same, still packed: pass it to expand() when the pieces are needed
func take_packed() -> Array:
	var h := [hits, polys]
	hits = []
	polys = []
	return h

static func expand(packed: Array) -> Array:
	var out: Array = packed[0]
	for pl in packed[1]:
		var m: Transform2D = pl[0]
		var q: PackedVector2Array = m * (pl[1] as PackedVector2Array)
		var sc := m.get_scale()
		var w: float = pl[2] * max(abs(sc.x), abs(sc.y))
		var ww: float = max(w, 2.0)
		var hair := w < HAIRLINE
		for i in q.size() - 1:
			out.append([q[i], q[i + 1], ww, hair])
	packed[1] = []
	return out

func hit_seg(a: Vector2, b: Vector2, half_w: float):
	if solid:
		# The fourth entry marks hairlines (feelers, flagella, outlines, hatching),
		# which ArtShape.gd leaves out of body contact
		var w := half_w * _xf_scale
		hits.append([xf * a, xf * b, max(w, 2.0), w < HAIRLINE])

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

func draw_circle(pos: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false):
	if not (filled and antialiased):
		# InkBatch sends these through draw_ellipse, which notes them
		super.draw_circle(pos, radius, color, filled, width, antialiased)
		return
	super.draw_circle(pos, radius, color, filled, width, antialiased)
	if color.a >= MIN_ALPHA:
		hit_seg(pos, pos, radius)

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
	if solid and not colors.is_empty() and colors[0].a >= MIN_ALPHA and points.size() > 1:
		polys.append([xf, points.duplicate(), max(width, 1.0) * 0.5])
