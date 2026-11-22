# StrikeMark.gd
# The mark a blow leaves where it lands, drawn like a quick pen sketch: a dark
# ink stroke with a pale fill line on top, so it reads on the sepia paper and
# under every other art style. Each attack leaves its own kind of mark:
#   jaws     bite, clamp: two toothed jaws slam shut on the spot
#   pinch    pincer: two curved blades scissor closed
#   slash    claw: three raking streaks drawn across
#   crack    lash: a jagged whip-crack line with a spark at the tip
#   pierce   sting, harpoon, spines: a puncture star with flicked droplets
#   boom     smash: a thick shock ring with cracks running out
#   grind    rasp: short wavy scrapes
#   suck     engulf, arms, tongue: rings drawn in toward the mouth
#   splat    vesicle, slime: a blob bursting with droplets
#   splash   jet, spit, spray: droplets thrown forward in a fan
#   web      silk: strands flung round the target
#   hurt     the player is struck: a jagged burst and scratches
#   stain    a kill's ink splash left on the floor, fading over seconds
#   chips    a kill's shell fragments or droplets thrown out
# A crit (a signature move or a doubled hit) adds a jagged impact star behind
# the mark. Rotated so +x is the blow's direction. Frees itself.
extends Node2D

const INK := Color(0.13, 0.09, 0.06)

var kind: String = "splat"
var color: Color = Color(1.0, 0.9, 0.7)
var size: float = 26.0 # roughly the struck body's radius
var crit: bool = false
var shelled: bool = false # chips: shell fragments rather than droplets
var duration: float = 0.34
var t: float = 0.0
var seed_val: int = 0
var bits: Array = [] # chips: [dir, speed, spin, size]

const STYLE_KIND := {
	"bite": "jaws", "clamp": "jaws", "pincer": "pinch", "claw": "slash", "lash": "crack",
	"sting": "pierce", "harpoon": "pierce", "spines": "pierce", "smash": "boom", "rasp": "grind",
	"engulf": "suck", "arms": "suck", "tongue": "suck", "vesicle": "splat", "slime": "splat",
	"jet": "splash", "spit": "splash", "spray": "splash", "silk": "web",
}

static func kind_for(weapon: String) -> String:
	return STYLE_KIND.get(weapon, "splat")

func _ready():
	z_index = 4
	seed_val = randi()
	match kind:
		"boom", "suck":
			duration = 0.4
		"stain":
			duration = 3.5
			z_index = -2
		"chips":
			duration = 0.6
			z_index = 3
		"hurt":
			duration = 0.32
	if crit:
		duration *= 1.25
	if kind == "chips":
		var rng = RandomNumberGenerator.new()
		rng.seed = seed_val
		for i in 9:
			bits.append([Vector2.RIGHT.rotated(rng.randf() * TAU), rng.randf_range(110.0, 260.0), rng.randf_range(-14.0, 14.0), rng.randf_range(3.0, 6.5)])

func _process(delta: float):
	t += delta / duration
	if t >= 1.0:
		queue_free()
		return
	queue_redraw()

static func ease_out(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func ink(a: float) -> Color:
	return Color(INK, clamp(a, 0.0, 1.0) * 0.9)

func pale(a: float) -> Color:
	var c = color.lerp(Color(1.0, 0.97, 0.9), 0.55)
	return Color(c, clamp(a, 0.0, 1.0))

# One pen stroke: dark ink under, a pale line on top
func stroke(a: Vector2, b: Vector2, w: float, alpha: float):
	draw_line(a, b, ink(alpha), w + 2.6, true)
	draw_line(a, b, pale(alpha), w, true)

func poly_stroke(pts: PackedVector2Array, w: float, alpha: float):
	draw_polyline(pts, ink(alpha), w + 2.6, true)
	draw_polyline(pts, pale(alpha), w, true)

func dot(p: Vector2, r: float, alpha: float):
	draw_circle(p, r + 1.3, ink(alpha), true, -1.0, true)
	draw_circle(p, r, pale(alpha), true, -1.0, true)

func ring(c: Vector2, r: float, w: float, alpha: float):
	draw_arc(c, r, 0, TAU, 36, ink(alpha), w + 2.6, true)
	draw_arc(c, r, 0, TAU, 36, pale(alpha), w, true)

func _draw():
	var fade = 1.0 - clamp((t - 0.45) / 0.55, 0.0, 1.0)
	var s = size * (1.25 if crit else 1.0)
	if crit and kind not in ["stain", "chips"]:
		impact_star(s)
	match kind:
		"jaws": jaws(s, fade)
		"pinch": pinch(s, fade)
		"slash": slash(s, fade)
		"crack": crack(s, fade)
		"pierce": pierce(s, fade)
		"boom": boom(s, fade)
		"grind": grind(s, fade)
		"suck": suck(s, fade)
		"splash": splash(s, fade)
		"web": web(s, fade)
		"hurt": hurt(s, fade)
		"stain": stain(s)
		"chips": chips(s)
		_: splat(s, fade)

# A jagged comic burst behind a big hit: pops out fast, then shrinks away
func impact_star(s: float):
	var k = clamp(t / 0.6, 0.0, 1.0)
	var r = s * (0.6 + 1.1 * ease_out(k * 2.5)) * (1.0 - 0.35 * k)
	var a = 1.0 - k
	var pts := PackedVector2Array()
	var n = 9
	for i in n * 2:
		var ang = TAU * i / (n * 2) + 0.2
		var rr = r * (1.0 if i % 2 == 0 else 0.5)
		pts.append(Vector2.from_angle(ang) * rr)
	draw_colored_polygon(pts, Color(1.0, 0.95, 0.75, 0.55 * a))
	pts.append(pts[0])
	draw_polyline(pts, ink(0.85 * a), 2.2, true)

func jaws(s: float, fade: float):
	# The jaws close over the first third, then hold and fade
	var close = ease_out(t / 0.3)
	var gap = s * 1.1 * (1.0 - close) + 3.0
	var w = s * 1.3
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		var teeth := PackedVector2Array()
		for i in 9:
			var f = i / 8.0
			var x = lerp(-w, w, f) * 0.8
			var y = side * (gap + s * 0.5 * (1.0 - pow(2.0 * f - 1.0, 2.0)) * -1.0 + s * 0.5)
			pts.append(Vector2(x + s * 0.2, y))
		poly_stroke(pts, 2.6, fade)
		# Teeth point in toward the bite
		for i in range(1, 8):
			var b = pts[i]
			var tip = b + Vector2(0, -side * s * 0.32)
			draw_colored_polygon(PackedVector2Array([b + Vector2(-3.5, 0), tip, b + Vector2(3.5, 0)]), pale(fade))
			draw_polyline(PackedVector2Array([b + Vector2(-3.5, 0), tip, b + Vector2(3.5, 0)]), ink(fade), 1.4, true)
	if t > 0.28:
		spokes(Vector2(s * 0.2, 0), s * 0.5, s * 1.1, 6, clamp((t - 0.28) / 0.4, 0.0, 1.0), fade)

func pinch(s: float, fade: float):
	var close = ease_out(t / 0.28)
	var open = 0.75 * (1.0 - close) + 0.06
	for side in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 10:
			var f = i / 9.0
			var a = side * (open + 0.5 * f * (1.0 - f))
			pts.append(Vector2(-s * 1.2, 0) + Vector2.from_angle(a) * s * 1.7 * f)
		poly_stroke(pts, 3.0, fade)
	if t > 0.26:
		spokes(Vector2(s * 0.45, 0), s * 0.3, s * 0.9, 5, clamp((t - 0.26) / 0.4, 0.0, 1.0), fade)

func slash(s: float, fade: float):
	# Three streaks raked across the blow, each drawn on a moment after the last
	for i in 3:
		var off = (i - 1) * s * 0.5
		var k = ease_out((t - i * 0.05) / 0.22)
		if k <= 0.0:
			continue
		var a = Vector2(-s * 0.7, -s * 1.3) + Vector2(off, 0)
		var b = Vector2(s * 0.7, s * 1.3) + Vector2(off, 0)
		var w = 3.2 * (1.0 - 0.6 * clamp((t - 0.3) / 0.7, 0.0, 1.0))
		stroke(a, a.lerp(b, k), w, fade)

func crack(s: float, fade: float):
	var k = ease_out(t / 0.18)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	var n = 7
	for i in n:
		var f = i / float(n - 1)
		if f > k:
			break
		var y = sin(f * PI) * -s * 0.9 + (rng.randf() - 0.5) * s * 0.45
		pts.append(Vector2(lerp(-s * 1.6, s * 1.2, f), y))
	if pts.size() >= 2:
		poly_stroke(pts, 2.4, fade)
		spokes(pts[pts.size() - 1], 3.0, s * 0.7, 6, clamp(t / 0.35, 0.0, 1.0), fade)

func pierce(s: float, fade: float):
	# The jab drives in, a star flashes at the wound, venom flicks out
	var k = ease_out(t / 0.15)
	stroke(Vector2(-s * 1.8, 0), Vector2(lerp(-s * 1.8, -s * 0.1, k), 0), 2.2, fade * (1.0 - clamp(t / 0.5, 0.0, 1.0)))
	spokes(Vector2.ZERO, 3.0, s * 0.9, 7, clamp((t - 0.08) / 0.35, 0.0, 1.0), fade)
	droplets(Vector2.ZERO, 0.0, 1.3, 4, s, fade)

func boom(s: float, fade: float):
	var k = ease_out(t / 0.5)
	ring(Vector2.ZERO, s * (0.5 + 1.6 * k), 4.0 * (1.0 - k) + 1.0, fade)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in 5:
		var a = TAU * i / 5.0 + rng.randf() * 0.6
		var d = Vector2.from_angle(a)
		var mid = d * s * 0.9 + d.orthogonal() * (rng.randf() - 0.5) * s * 0.5
		var end = d * s * (0.9 + 0.9 * ease_out(t / 0.2))
		poly_stroke(PackedVector2Array([d * s * 0.3, mid, end]), 1.8, fade)

func grind(s: float, fade: float):
	for i in 3:
		var k = ease_out((t - i * 0.07) / 0.2)
		if k <= 0.0:
			continue
		var pts := PackedVector2Array()
		var y = (i - 1) * s * 0.45
		for j in 9:
			var f = j / 8.0 * k
			pts.append(Vector2(lerp(-s, s, f), y + sin(f * 18.0) * 2.5))
		poly_stroke(pts, 1.8, fade)

func suck(s: float, fade: float):
	# Rings pulled in toward the attacker, behind the target (-x)
	for i in 3:
		var k = clamp(t * 1.6 - i * 0.22, 0.0, 1.0)
		if k <= 0.0 or k >= 1.0:
			continue
		var r = s * (1.5 - 1.2 * ease_out(k))
		draw_arc(Vector2(-s * 0.3 * k, 0), r, PI * 0.6, PI * 1.4, 18, ink(fade * (1.0 - k)), 3.8, true)
		draw_arc(Vector2(-s * 0.3 * k, 0), r, PI * 0.6, PI * 1.4, 18, pale(fade * (1.0 - k)), 1.6, true)

func splat(s: float, fade: float):
	var k = ease_out(t / 0.25)
	ring(Vector2.ZERO, s * (0.3 + 0.7 * k), 2.0 * (1.0 - k) + 0.8, fade * (1.0 - k * 0.6))
	droplets(Vector2.ZERO, 0.0, PI, 6, s * 0.9, fade)

func splash(s: float, fade: float):
	var k = ease_out(t / 0.3)
	draw_arc(Vector2.ZERO, s * (0.4 + 0.9 * k), -1.1, 1.1, 16, ink(fade * (1.0 - k)), 3.6, true)
	draw_arc(Vector2.ZERO, s * (0.4 + 0.9 * k), -1.1, 1.1, 16, pale(fade * (1.0 - k)), 1.4, true)
	droplets(Vector2.ZERO, 0.0, 1.0, 6, s * 1.1, fade)

func web(s: float, fade: float):
	var k = ease_out(t / 0.25)
	var n = 6
	var prev := Vector2.ZERO
	for i in n + 1:
		var d = Vector2.from_angle(TAU * i / n + 0.3) * s * 1.2 * k
		if i < n:
			stroke(Vector2.ZERO, d, 1.0, fade)
		if i > 0:
			stroke(prev * 0.65, d * 0.65, 0.8, fade)
		prev = d

func hurt(s: float, fade: float):
	var k = ease_out(t / 0.2)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	var n = 12
	for i in n + 1:
		var a = TAU * i / n
		var rr = s * (1.2 + 0.9 * k) * (1.0 if i % 2 == 0 else 0.62 + rng.randf() * 0.15)
		pts.append(Vector2.from_angle(a) * rr)
	draw_polyline(pts, Color(0.75, 0.12, 0.08, 0.85 * fade), 2.6, true)
	draw_polyline(pts, ink(0.6 * fade), 1.0, true)

# Short rays bursting from c: r0..r1 grow with k
func spokes(c: Vector2, r0: float, r1: float, n: int, k: float, fade: float):
	var a = fade * (1.0 - k * 0.7)
	for i in n:
		var d = Vector2.from_angle(TAU * i / n + 0.4)
		stroke(c + d * (r0 + (r1 - r0) * k * 0.4), c + d * (r0 + (r1 - r0) * ease_out(k)), 1.6 * (1.0 - k) + 0.6, a)

# Droplets thrown out around angle a0 within +-spread, flying and shrinking
func droplets(c: Vector2, a0: float, spread: float, n: int, s: float, fade: float):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 7
	for i in n:
		var a = a0 + (rng.randf() * 2.0 - 1.0) * spread
		var sp = rng.randf_range(0.8, 1.6)
		var d = Vector2.from_angle(a) * s * (0.4 + sp * ease_out(t / 0.45))
		var r = (2.2 + rng.randf() * 1.8) * (1.0 - t * 0.7)
		dot(c + d, r, fade)

# A kill's splash soaking into the floor: blotchy ink, slowly fading
func stain(s: float):
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	var spread = ease_out(t / 0.06)
	var a = 0.38 * (1.0 - clamp((t - 0.35) / 0.65, 0.0, 1.0))
	var c = color.darkened(0.55)
	c.a = a
	draw_circle(Vector2.ZERO, s * 0.75 * spread, c, true, -1.0, true)
	for i in 11:
		var d = Vector2.from_angle(rng.randf() * TAU) * s * rng.randf_range(0.4, 1.6) * spread
		draw_circle(d, rng.randf_range(2.0, s * 0.3), c, true, -1.0, true)

# Bits thrown out by a kill: angular shell chips for shelled animals,
# droplets for soft ones, both settling as they slow
func chips(s: float):
	var a = 1.0 - clamp((t - 0.5) / 0.5, 0.0, 1.0)
	for b in bits:
		var travel = b[1] * 0.6 * ease_out(t * 1.6) * (s / 26.0)
		var p = b[0] * (s * 0.4 + travel)
		if shelled:
			var rot = b[2] * ease_out(t * 1.6)
			var r = b[3]
			var pts = PackedVector2Array([
				p + Vector2(r, 0).rotated(rot), p + Vector2(-r * 0.6, r * 0.7).rotated(rot),
				p + Vector2(-r * 0.4, -r * 0.8).rotated(rot)])
			draw_colored_polygon(pts, pale(a))
			pts.append(pts[0])
			draw_polyline(pts, ink(a), 1.4, true)
		else:
			dot(p, b[3] * 0.6 * (1.0 - t * 0.6), a)
