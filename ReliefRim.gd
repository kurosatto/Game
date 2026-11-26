# ReliefRim.gd
# The room's border drawn as a relief map (kuro picked it, 2026-11-26): the
# floor is a basin and its sides rise in contour lines, each terrace a little
# darker, with short hachure strokes running downhill between them. Where a
# door opens, the contours bend back up the slope into a valley, so the floor
# runs out to the door. Drawn once, in one draw call, over the old rocky rim.
# Obstacles are knolls drawn the same way (Obstacle.draw_knoll).
extends Node2D

# Raw floor colour of each era's room.png (the ink filter turns it to paper);
# the slope tones are fractions of it, so every era reads the same through
# the filter whatever its floor light.
const FLOOR = {
	"cambrian": Color(0.389, 0.392, 0.332), "carboniferous": Color(0.144, 0.167, 0.104),
	"carboniferous_sea": Color(0.259, 0.347, 0.338), "ediacaran": Color(0.289, 0.339, 0.314),
	"ordovician": Color(0.248, 0.307, 0.375), "permian": Color(0.354, 0.245, 0.194),
	"permian_sea": Color(0.359, 0.344, 0.332),
}
const WALL = 128.0
# Contour offsets from the wall face (negative = out on the floor)
const RINGS = [-20.0, 0.0, 18.0, 34.0, 48.0, 60.0, 72.0, 84.0, 96.0, 110.0, 126.0, 146.0, 170.0, 200.0, 240.0, 300.0, 380.0, 470.0, 560.0]
const STEPS = 240 # points per contour
# kuro (2026-11-26) didn't want walls as borders: the floor just fades into
# dark water at the edge, no lines. false brings back the contour slopes.
const FADE = true
const FADE_RINGS = [-150.0, -105.0, -65.0, -30.0, 0.0, 35.0, 80.0, 140.0, 700.0]
const FADE_ALPHA = [0.0, 0.12, 0.3, 0.55, 0.78, 0.92, 1.0, 1.0, 1.0]

var floor_col := Color(0.35, 0.35, 0.3)
var rect := Rect2()     # the floor inside the walls
var doors: Array = []   # Vector2 door centres
var knolls: Array = []  # extra knolls drawn with the rim: [centre, a, b] (main menu)
var light := 0.5
var pen = preload("res://InkBatch.gd").new()

static func floor_colour(era_name: String) -> Color:
	return FLOOR.get(era_name, Color(0.33, 0.33, 0.29))

# Colours are set by where they land on the ink filter's scale, from ink
# (0.12 x "ink_light") to bare paper ("ink_light"), as a fraction of where
# the floor itself lands, keeping the floor's hue: every era reads alike
static func at_lum(base: Color, lgt: float, g: float) -> Color:
	var l = maxf(0.02, base.get_luminance())
	var dark = lgt * 0.12
	var t_floor = clampf((l - dark) / (lgt - dark), 0.2, 1.0)
	var want = maxf(0.004, dark + t_floor * g * (lgt - dark))
	var c = base * (want / l)
	c.a = 1.0
	return c

# Slope tone at contour k: from just under the floor to near ink
static func tone(base: Color, lgt: float, k: float) -> Color:
	return at_lum(base, lgt, clampf(0.9 - k * 0.05, 0.3, 0.9))

static func ink(base: Color, lgt: float) -> Color:
	return at_lum(base, lgt, -0.25)

func setup(era_name: String, ink_light: float, floor_rect: Rect2, door_spots: Array):
	floor_col = floor_colour(era_name)
	light = ink_light
	rect = floor_rect
	doors = door_spots
	z_index = -19
	queue_redraw()

# Smooth 1D wobble along the ring, the same every visit
static func wob(t: float, seed_v: float) -> float:
	return (sin(t * TAU * 3.0 + seed_v) * 0.5 + sin(t * TAU * 7.0 + seed_v * 2.3) * 0.3 + sin(t * TAU * 13.0 + seed_v * 0.7) * 0.2)

# A rounded-rectangle ring (superellipse) taken at the same angles for every
# offset, so the fade's bands never cross at the corners
func ring_soft(off: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var c = rect.get_center()
	var hw = rect.size.x * 0.5 + off
	var hh = rect.size.y * 0.5 + off
	var seed_v = rect.size.x * 0.001
	for i in STEPS:
		var t = TAU * i / float(STEPS)
		var cx = cos(t)
		var sy = sin(t)
		var p = c + Vector2(signf(cx) * pow(absf(cx), 0.18) * hw, signf(sy) * pow(absf(sy), 0.18) * hh)
		var n = Vector2(cx * hh, sy * hw).normalized()
		var w = 30.0 * wob(i / float(STEPS), seed_v)
		for d in doors:
			var dd = p.distance_to(d)
			if dd < 260.0:
				var q = 1.0 - dd / 260.0
				w += (maxf(off, 0.0) + 150.0) * q * q * (3.0 - 2.0 * q)
		pts.append(p + n * w)
	return pts

func ring(off: float, rough: float = 1.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0 = rect.position.x - off
	var y0 = rect.position.y - off
	var x1 = rect.end.x + off
	var y1 = rect.end.y + off
	var rad = 60.0 + maxf(off, 0.0) * 0.3
	var w_ = x1 - x0
	var h_ = y1 - y0
	var per = 2.0 * (w_ + h_)
	var seed_v = rect.size.x * 0.001
	for i in STEPS:
		var s = per * i / float(STEPS)
		var p: Vector2
		var n: Vector2
		if s < w_:
			p = Vector2(x0 + s, y0); n = Vector2.UP
		elif s < w_ + h_:
			p = Vector2(x1, y0 + s - w_); n = Vector2.RIGHT
		elif s < 2.0 * w_ + h_:
			p = Vector2(x1 - (s - w_ - h_), y1); n = Vector2.DOWN
		else:
			p = Vector2(x0, y1 - (s - 2.0 * w_ - h_)); n = Vector2.LEFT
		# Round the corners
		var c = Vector2(clampf(p.x, x0 + rad, x1 - rad), clampf(p.y, y0 + rad, y1 - rad))
		if absf(c.x - p.x) > 0.01 and absf(c.y - p.y) > 0.01:
			p = c + (p - c).normalized() * rad
		var w = 14.0 * rough * wob(i / float(STEPS), seed_v)
		# A valley runs up the slope to each door
		for d in doors:
			var dd = p.distance_to(d)
			if dd < 270.0:
				var q = 1.0 - dd / 270.0
				w += (maxf(off, 0.0) + 60.0) * q * q * (3.0 - 2.0 * q) * 1.15
		pts.append(p + n * w)
	return pts

func _draw_fade():
	var deep = at_lum(floor_col, light, -0.35)
	var rings: Array = []
	for off in FADE_RINGS:
		rings.append(ring_soft(off))
	for k in rings.size() - 1:
		var pts := PackedVector2Array()
		pts.append_array(rings[k])
		pts.append_array(rings[k + 1])
		var cols := PackedColorArray()
		cols.resize(STEPS * 2)
		for i in STEPS:
			cols[i] = Color(deep, FADE_ALPHA[k])
			cols[STEPS + i] = Color(deep, FADE_ALPHA[k + 1])
		var tri := PackedInt32Array()
		for i in STEPS:
			var j = (i + 1) % STEPS
			tri.append_array([i, j, STEPS + i, j, STEPS + j, STEPS + i])
		pen.add_triangles(tri, pts, cols)
	for kn in knolls:
		draw_knoll(pen, kn[0], kn[1], kn[2], kn[0].x * 0.01, floor_col, light)

func _draw():
	pen.begin(self)
	if FADE:
		_draw_fade()
		pen.flush()
		return
	var rings: Array = []
	for off in RINGS:
		rings.append(ring(off))
	# Terraces: each band between two contours a shade darker uphill
	for k in rings.size() - 1:
		var a: PackedVector2Array = rings[k]
		var b: PackedVector2Array = rings[k + 1]
		var pts := PackedVector2Array()
		pts.append_array(a)
		pts.append_array(b)
		var tri := PackedInt32Array()
		for i in STEPS:
			var j = (i + 1) % STEPS
			tri.append_array([i, j, STEPS + i, j, STEPS + j, STEPS + i])
		pen.add_triangles(tri, pts, PackedColorArray([tone(floor_col, light, k)]))
	# Past the last contour (tall screens see more): the darkest tone
	var last: PackedVector2Array = rings[rings.size() - 1]
	var outer := PackedVector2Array()
	for i in STEPS:
		var p = last[i]
		var c = rect.get_center()
		var dir = (p - c)
		outer.append(c + dir * 3.0)
	var pts2 := PackedVector2Array()
	pts2.append_array(last)
	pts2.append_array(outer)
	var tri2 := PackedInt32Array()
	for i in STEPS:
		var j = (i + 1) % STEPS
		tri2.append_array([i, j, STEPS + i, j, STEPS + j, STEPS + i])
	pen.add_triangles(tri2, pts2, PackedColorArray([tone(floor_col, light, rings.size() - 1)]))
	var ink_c = ink(floor_col, light)
	# Hachures: short strokes running downhill between contours
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	for k in range(1, rings.size() - 4):
		var a: PackedVector2Array = rings[k]
		var b: PackedVector2Array = rings[k + 1]
		for i in STEPS:
			if rng.randf() < 0.2:
				continue
			var t0 = rng.randf_range(0.0, 0.15)
			var t1 = rng.randf_range(0.75, 1.0)
			pen.draw_line(a[i].lerp(b[i], t0), a[i].lerp(b[i], t1), Color(ink_c, 0.75), 1.3, true)
	# Contour lines; every fourth is an index contour, drawn heavier
	for k in rings.size() - 3:
		var r: PackedVector2Array = (rings[k] as PackedVector2Array).duplicate()
		r.append(r[0])
		var index_line = k % 4 == 1
		pen.draw_polyline(r, ink_c if index_line else Color(ink_c, 0.8), 2.6 if index_line else 1.3, true)
	for kn in knolls:
		draw_knoll(pen, kn[0], kn[1], kn[2], kn[0].x * 0.01, floor_col, light)
	pen.flush()

# A knoll seen on the map: three contour rings rising to a summit a little
# up and left (the light's side), each terrace paler, with hachures running
# down between them. `a`/`b` are the solid footprint's half axes, so the
# outer contour is exactly where bodies stop. `turn` rotates it (ridges).
static func draw_knoll(pen, c: Vector2, a: float, b: float, seed_v: float, base: Color, lgt: float, turn: float = 0.0):
	var levels = [1.0, 0.58]
	var tones = [0.85, 1.0]
	var n := 40
	var rings: Array = []
	for li in levels.size():
		var lv: float = levels[li]
		var pts := PackedVector2Array()
		var shift = Vector2(-a * 0.14, -b * 0.18) * (1.0 - lv)
		for i in n:
			var t = TAU * i / float(n)
			var r = 1.0 + 0.1 * wob(i / float(n), seed_v + li * 0.4)
			var p = Vector2(cos(t) * a * lv * r, sin(t) * b * lv * r) + shift
			pts.append(c + p.rotated(turn))
		rings.append(pts)
	for li in rings.size():
		pen.draw_colored_polygon(rings[li], at_lum(base, lgt, tones[li]))
	var ink_c = ink(base, lgt)
	for li in rings.size() - 1:
		var o: PackedVector2Array = rings[li]
		var q: PackedVector2Array = rings[li + 1]
		# hachures only on the shaded lower-right flank
		for i in range(0, n, 2):
			var t = TAU * i / float(n) + turn
			if cos(t - PI * 0.25) < 0.1:
				continue
			pen.draw_line(q[i].lerp(o[i], 0.2), q[i].lerp(o[i], 0.85), Color(ink_c, 0.6), 1.0, true)
	for li in rings.size():
		var r: PackedVector2Array = (rings[li] as PackedVector2Array).duplicate()
		r.append(r[0])
		pen.draw_polyline(r, ink_c if li == 0 else Color(ink_c, 0.75), 2.2 if li == 0 else 1.2, true)
	var top = c + (Vector2(-a * 0.14, -b * 0.18)).rotated(turn)
	pen.draw_circle(top, 1.5, Color(ink_c, 0.8))
