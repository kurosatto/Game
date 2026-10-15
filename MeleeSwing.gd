# MeleeSwing.gd
# Short-lived drawing of a melee attack, added as a child of the player and
# rotated so +x points along the aim. Drawn like the player art
# (PlayerBody.gd): soft outlined shapes in the form's own colour, so each
# strike looks like the animal's real weapon in a cute cartoon style:
# jaws chomp, pincers and shells snap, stings and tongues shoot out and back,
# tentacles reach with their suckers, claws leave three slash marks, spines
# pop out all round, and a mantis shrimp club punches out a bubble.
extends Node2D

const INK := Color(0.17, 0.09, 0.15)
const CREAM := Color(1.0, 0.98, 0.92)
# A chomp is drawn as a cartoon mouth, the same pink for every animal
const GUM := Color(1.0, 0.52, 0.6)
const SHELL := Color(0.96, 0.86, 0.72)

var style: String = "bite"
var reach: float = 120.0
var half_arc: float = 0.6
var color: Color = Color(0.0, 0.95, 1.0)
var duration: float = 0.22
var t: float = 0.0

var body: Color
var light: Color
var fade: float = 1.0

func _ready():
	z_index = 2
	if style in ["arms", "tongue", "sting"]:
		duration = 0.28
	elif style in ["smash", "engulf"]:
		duration = 0.3
	var c := Color(color.r, color.g, color.b, 1.0)
	# Pastel version of the form's colour, never too dark to read
	body = Color.from_hsv(c.h, clamp(c.s * 0.85 + 0.05, 0.0, 1.0), max(c.v, 0.55) * 0.8 + 0.2)
	light = body.lightened(0.4)

func _process(delta: float):
	t += delta / duration
	if t >= 1.0:
		queue_free()
		return
	queue_redraw()

func _draw():
	fade = clamp((1.0 - t) / 0.35, 0.0, 1.0)
	var hit = Vector2(clamp(reach * 0.6, 55.0, 110.0), 0)
	match style:
		"bite":
			chomp(hit, 1.0, false)
		"clamp":
			chomp(hit, 1.15, true)
		"rasp":
			rasp(hit)
		"pincer":
			pincer(hit)
		"engulf":
			engulf(hit)
		"claw":
			slashes(3, 0.85)
		"lash":
			slashes(1, 1.0)
		"sting":
			sting()
		"arms":
			tentacles()
		"tongue":
			tongue()
		"spines":
			spines()
		"smash":
			smash(hit)
		_:
			chomp(hit, 1.0, false)

# ── drawing helpers ──
func a(c: Color, k: float = 1.0) -> Color:
	return Color(c.r, c.g, c.b, c.a * fade * k)

func ink_poly(pts: PackedVector2Array, col: Color, w: float = 2.6):
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return
	draw_colored_polygon(pts, a(col))
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, a(INK), w, true)

func ink_circle(c: Vector2, r: float, col: Color, w: float = 2.4):
	draw_circle(c, r + w * 0.5, a(INK), true, -1.0, true)
	draw_circle(c, r, a(col), true, -1.0, true)

func shine(c: Vector2, r: float):
	draw_circle(c + Vector2(-0.35, -0.4).rotated(-global_rotation) * r, r * 0.32, a(Color(1, 1, 1, 0.9)), true, -1.0, true)

func ellipse(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var g = TAU * i / n
		pts.append(c + Vector2(cos(g) * rx, sin(g) * ry).rotated(rot))
	return pts

# Rounded outlined stroke through pts, thinning from w0 to w1
func tube(pts: PackedVector2Array, w0: float, w1: float, col: Color):
	var n = pts.size()
	for pass_ in 2:
		var c = INK if pass_ == 0 else col
		var extra = 3.0 if pass_ == 0 else 0.0
		for i in n - 1:
			var w = lerp(w0, w1, i / float(max(n - 2, 1))) + extra
			draw_line(pts[i], pts[i + 1], a(c), w, true)
			draw_circle(pts[i], w * 0.5, a(c), true, -1.0, true)
		draw_circle(pts[n - 1], (w1 + extra) * 0.5, a(c), true, -1.0, true)

# Little four-point twinkle where a strike lands
func sparkle(c: Vector2, s: float, col: Color = CREAM):
	if s <= 0.05:
		return
	var pts := PackedVector2Array()
	for i in 8:
		var r = s if i % 2 == 0 else s * 0.32
		pts.append(c + Vector2.RIGHT.rotated(i * PI / 4.0 + 0.2) * r)
	ink_poly(pts, col, 2.0)

func puffs(c: Vector2, k: float, r: float, n: int = 5):
	for i in n:
		var g = TAU * i / n + 0.4
		var p = c + Vector2.RIGHT.rotated(g) * r * (0.6 + 0.8 * k)
		draw_circle(p, max(0.0, (1.0 - k) * r * 0.32), a(Color(1, 1, 1, 0.75)), true, -1.0, true)

func ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x)

# ── styles ──
# Two cartoon jaws (or shell valves) snapping shut on the target
func chomp(c: Vector2, size: float, shell: bool):
	var snap = clamp(t / 0.38, 0.0, 1.0)
	snap = snap * snap * snap # slow open, fast snap
	var gap = (1.0 - snap) * 20.0 * size
	var tilt = (1.0 - snap) * 0.45
	var rx = 25.0 * size
	var ry = 17.0 * size
	var hinge = c + Vector2(-rx * 0.8, 0)
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 15:
			var g = PI * i / 14.0
			var q = Vector2(cos(g) * rx, side * sin(g) * ry)
			if shell:
				q *= 1.0 + 0.06 * cos(i * PI) # scalloped edge
			pts.append(q)
		var off = Vector2(0, side * gap)
		var xf = func(q: Vector2) -> Vector2:
			return hinge + (q + Vector2(rx * 0.8, 0)).rotated(side * tilt) + off
		var jaw := PackedVector2Array()
		for q in pts:
			jaw.append(xf.call(q))
		if not shell:
			# Rounded teeth along the biting edge
			for k in 4:
				var x = -rx * 0.7 + k * rx * 0.46
				var tooth = PackedVector2Array([xf.call(Vector2(x - 4.5 * size, side * 0.5)), xf.call(Vector2(x, -side * 7.0 * size)), xf.call(Vector2(x + 4.5 * size, side * 0.5))])
				ink_poly(tooth, CREAM, 2.0)
		ink_poly(jaw, shell_col(side) if shell else GUM)
		if shell:
			for k in 5:
				var g = PI * (k + 1) / 6.0
				draw_line(xf.call(Vector2(cos(g) * rx * 0.25, side * sin(g) * ry * 0.25)), xf.call(Vector2(cos(g) * rx * 0.9, side * sin(g) * ry * 0.9)), a(SHELL.darkened(0.25)), 1.6, true)
		else:
			draw_colored_polygon(ellipse(xf.call(Vector2(-rx * 0.1, side * ry * 0.55)), rx * 0.45, ry * 0.18, side * tilt, 12), a(GUM.lightened(0.35), 0.8))
	if snap >= 1.0:
		var k = clamp((t - 0.38) / 0.4, 0.0, 1.0)
		puffs(c, k, 30.0 * size, 6)
		sparkle(c + Vector2(4, -ry - 6), 9.0 * (1.0 - k) * size)

func shell_col(side: float) -> Color:
	return SHELL if side < 0 else SHELL.darkened(0.08)

# Lamprey / snail radula: a round toothed mouth grinding on the spot
func rasp(c: Vector2):
	var pop = ease_out(clamp(t / 0.25, 0.0, 1.0))
	var r = 21.0 * pop
	ink_circle(c, r, body)
	draw_circle(c, r * 0.55, a(Color(0.42, 0.12, 0.2)), true, -1.0, true)
	for ring in 2:
		var rr = r * (0.88 - ring * 0.3)
		var n = 12 - ring * 4
		for i in n:
			var g = TAU * i / n + t * (6.0 if ring == 0 else -8.0)
			var p = c + Vector2.RIGHT.rotated(g) * rr
			var tip = c + Vector2.RIGHT.rotated(g) * (rr - 5.0)
			ink_poly(PackedVector2Array([p + Vector2(0, -2.2).rotated(g), tip, p + Vector2(0, 2.2).rotated(g)]), CREAM, 1.4)
	for k in 3:
		var y = (k - 1) * 9.0
		var x0 = c.x + 24.0 + k * 3.0
		var len_ = 14.0 * pop
		draw_line(Vector2(x0, y), Vector2(x0 + len_, y + 3.0), a(CREAM, 0.9), 3.0, true)

# A crab claw: the movable finger swings shut against the fixed one
func pincer(c: Vector2):
	var grow = ease_out(clamp(t / 0.2, 0.0, 1.0))
	var shut = clamp((t - 0.12) / 0.2, 0.0, 1.0)
	var open = 0.75 * (1.0 - shut * shut)
	var s = 1.15 * grow
	var palm = c + Vector2(-22, 0) * s
	# Fixed finger along the bottom, movable finger hinged at the top
	var fixed = PackedVector2Array([palm + Vector2(4, 4) * s, palm + Vector2(30, 6) * s, palm + Vector2(40, -1) * s, palm + Vector2(28, 12) * s, palm + Vector2(4, 13) * s])
	ink_poly(fixed, body)
	var h = palm + Vector2(6, -3) * s
	var fing := PackedVector2Array()
	for q in [Vector2(0, 0), Vector2(18, -9), Vector2(34, -4), Vector2(38, 2), Vector2(22, -1), Vector2(0, 9)]:
		fing.append(h + (q * s).rotated(-open))
	ink_poly(fing, body.lightened(0.15))
	ink_poly(ellipse(palm, 14 * s, 12 * s, 0.0, 18), body)
	draw_colored_polygon(ellipse(palm + Vector2(-2, -4) * s, 7 * s, 3.5 * s, -0.3, 12), a(light, 0.8))
	if shut >= 1.0:
		var k = clamp((t - 0.32) / 0.4, 0.0, 1.0)
		sparkle(palm + Vector2(40, -6) * s, 10.0 * (1.0 - k))
		puffs(palm + Vector2(36, 0) * s, k, 20.0, 5)

# A cell's pseudopods flow around the prey and close into a food vacuole
func engulf(c: Vector2):
	var close = ease_out(clamp(t / 0.55, 0.0, 1.0))
	var r = 30.0
	var jelly = Color(body.r, body.g, body.b, 0.5)
	var rim = Color(light.r, light.g, light.b, 0.9)
	var open = (1.0 - close) * 1.4
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 10:
			var f = i / 9.0
			var g = side * (PI - f * (PI - 0.05 - open * 0.5))
			pts.append(c + Vector2(cos(g) * r * 1.05, sin(g) * r) * (0.75 + 0.25 * f))
		draw_polyline(pts, a(jelly), 12.0, true)
		draw_polyline(pts, a(rim), 2.0, true)
		draw_circle(pts[9], 6.0, a(jelly), true, -1.0, true)
	if close > 0.85:
		var k = clamp((t - 0.5) / 0.5, 0.0, 1.0)
		draw_circle(c, r * 0.95, a(Color(body.r, body.g, body.b, 0.25)), true, -1.0, true)
		draw_arc(c, r * 0.95, 0, TAU, 32, a(rim), 2.4, true)
		shine(c, r * 0.8)
		for i in 4:
			var g = i * 1.7 + t * 4.0
			draw_circle(c + Vector2(cos(g), sin(g)) * r * 0.5 * (1.0 - k * 0.5), 2.5, a(light, 0.9), true, -1.0, true)

# Claw rakes (three) or a single tail / arm lash: tapered crescents that
# sweep across the arc and fade
func slashes(n: int, size: float):
	var sweep = ease_out(clamp(t / 0.45, 0.0, 1.0))
	var arc = min(half_arc, 1.1)
	var r0 = clamp(reach * 0.62, 55.0, 115.0) * size
	for i in n:
		var r = r0 + (i - (n - 1) / 2.0) * 13.0
		var a1 = -arc + 2.0 * arc * sweep
		var a0 = max(-arc, a1 - 1.1)
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		var m = 14
		for k in m + 1:
			var f = k / float(m)
			var g = lerp(a0, a1, f)
			var thick = sin(PI * f) * (9.0 if n == 1 else 6.0)
			outer.append(Vector2.RIGHT.rotated(g) * (r + thick * 0.5))
			inner.append(Vector2.RIGHT.rotated(g) * (r - thick * 0.5))
		inner.reverse()
		outer.append_array(inner)
		ink_poly(outer, CREAM if i != 1 or n == 1 else light, 2.2)
	if sweep > 0.95:
		var k = clamp((t - 0.45) / 0.5, 0.0, 1.0)
		sparkle(Vector2.RIGHT.rotated(arc) * r0, 10.0 * (1.0 - k))

# Scorpion tail / sea slug cerata / chimaera spine: a bead-segmented sting
# shoots out to full reach with a curved barb and a drop of venom
func sting():
	var ext = sin(PI * clamp(t * 1.05, 0.0, 1.0))
	var tip = Vector2(20.0 + (reach - 20.0) * ext, 0)
	var len_ = tip.x - 20.0
	var sway = func(x: float) -> Vector2:
		var f = (x - 20.0) / max(len_, 1.0)
		return Vector2(x, sin(f * PI) * 7.0 * (1.0 - ext))
	var pts := PackedVector2Array()
	for i in 9:
		pts.append(sway.call(20.0 + len_ * i / 8.0))
	tube(pts, 10.0, 6.0, body)
	# Segment joints along the tail
	var seg = max(1, int(len_ / 14.0))
	for i in range(1, seg):
		var x = 20.0 + len_ * i / float(seg)
		var p: Vector2 = sway.call(x)
		var w = lerp(10.0, 6.0, i / float(seg)) * 0.5 + 0.5
		draw_line(p + Vector2(0, -w), p + Vector2(0, w), a(INK, 0.7), 1.6, true)
	var barb = PackedVector2Array([tip + Vector2(-4, -6), tip + Vector2(12, -2), tip + Vector2(20, 6), tip + Vector2(6, 4), tip + Vector2(-4, 6)])
	ink_poly(barb, body.darkened(0.15))
	if ext > 0.8:
		ink_circle(tip + Vector2(21, 9), 3.5, Color(0.65, 1.0, 0.45), 1.8)
		shine(tip + Vector2(21, 9), 3.5)

# Octopus / squid / sea star arms: two suckered tentacles reach and curl
func tentacles():
	var ext = sin(PI * clamp(t * 1.05, 0.0, 1.0))
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var m = 12
		for i in m:
			var f = i / float(m - 1)
			var x = 16.0 + (reach - 16.0) * ext * f
			var y = side * (10.0 + 10.0 * f) + sin(f * 5.0 + t * 14.0 + side) * 5.0 * f
			if f > 0.8:
				# Tip curls inward
				var cf = (f - 0.8) / 0.2
				y -= side * cf * 12.0 * ext
			pts.append(Vector2(x, y))
		tube(pts, 9.0, 3.5, body)
		for i in range(2, m - 2, 2):
			var p = pts[i]
			var w = lerp(9.0, 3.5, i / float(m - 2))
			draw_circle(p - Vector2(0, side * w * 0.15), w * 0.26, a(Color(1.0, 0.82, 0.82)), true, -1.0, true)
			draw_arc(p - Vector2(0, side * w * 0.15), w * 0.26, 0, TAU, 8, a(INK, 0.6), 1.0, true)

# Amphibian tongue: a pink sticky tongue flicks out and back
func tongue():
	var ext = sin(PI * clamp(t * 1.05, 0.0, 1.0))
	var tip = Vector2(16.0 + (reach - 16.0) * ext, sin(t * 20.0) * 2.0)
	var pink = Color(1.0, 0.5, 0.62)
	tube(PackedVector2Array([Vector2(14, 0), Vector2(14, 0).lerp(tip, 0.5) + Vector2(0, 3), tip]), 8.0, 7.0, pink)
	draw_line(Vector2(18, 0), tip - Vector2(10, 0), a(pink.darkened(0.25)), 1.6, true)
	ink_circle(tip, 9.0, pink.lightened(0.1), 2.4)
	shine(tip, 9.0)

# Urchin / echinoderm spines pop out all round, then settle back
func spines():
	var pop = sin(PI * clamp(t * 1.1, 0.0, 1.0))
	var n = 16
	var r0 = 24.0
	var len_ = (reach - r0) * 0.55 * pop
	for i in n:
		var g = TAU * i / n + 0.1
		var d = Vector2.RIGHT.rotated(g)
		var nrm = d.orthogonal()
		var base = d * r0
		ink_poly(PackedVector2Array([base + nrm * 4.0, base + d * (len_ + 6.0), base - nrm * 4.0]), body.lightened(0.2) if i % 2 == 0 else body, 2.0)
	draw_arc(Vector2.ZERO, reach * (0.7 + 0.3 * pop), 0, TAU, 48, a(Color(1, 1, 1, 0.25)), 2.0, true)

# Mantis shrimp: the club snaps out, and the collapsing cavitation bubble
# pops in front of it
func smash(c: Vector2):
	var punch = ease_out(clamp(t / 0.16, 0.0, 1.0)) * (1.0 - clamp((t - 0.45) / 0.4, 0.0, 1.0))
	var club = Vector2(18, 0).lerp(c - Vector2(16, 0), punch)
	tube(PackedVector2Array([Vector2(14, 0), club]), 7.0, 8.0, body)
	ink_circle(club, 10.0, body.lightened(0.15))
	shine(club, 10.0)
	if t > 0.14:
		var k = clamp((t - 0.14) / 0.6, 0.0, 1.0)
		var r = 10.0 + 26.0 * ease_out(min(k * 1.6, 1.0))
		if k < 0.55:
			draw_circle(c, r, a(Color(0.85, 0.95, 1.0, 0.35)), true, -1.0, true)
			draw_arc(c, r, 0, TAU, 32, a(INK, 0.8), 2.4, true)
			shine(c, r)
		else:
			for i in 7:
				var g = TAU * i / 7.0 + 0.3
				var p = c + Vector2.RIGHT.rotated(g) * r * (0.8 + 0.6 * (k - 0.55))
				ink_circle(p, 4.0 * (1.0 - k) + 1.5, Color(0.85, 0.95, 1.0), 1.6)
		sparkle(c, 13.0 * (1.0 - k))
