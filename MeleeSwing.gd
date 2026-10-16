# MeleeSwing.gd
# Short-lived motion trail of a melee attack, added as a child of the player
# and rotated so +x points along the aim. The body itself animates the
# strike (PlayerBody.gd: jaws gape, claws snap, the whole body lunges); this
# only adds the motion blur of that strike and the disturbance in the water
# where it lands, in the form's own colour and fading smoothly:
#   jaws, pincers, shells, rasps, engulfing: a lunge smear and a ripple
#   claws and lashes: a swept arc smear that thins out behind the sweep
#   stings, arms, tongues: the limb itself shoots out and back
#   spines: short radial streaks and a ripple; smash: a fast streak and a
#   cavitation bubble that collapses
extends Node2D

var style: String = "bite"
var reach: float = 120.0
var half_arc: float = 0.6
var color: Color = Color(0.0, 0.95, 1.0)
var duration: float = 0.26
var t: float = 0.0

func _ready():
	z_index = 2
	if style in ["arms", "tongue", "sting"]:
		duration = 0.34
	elif style in ["smash", "engulf"]:
		duration = 0.36

func _process(delta: float):
	t += delta / duration
	if t >= 1.0:
		queue_free()
		return
	queue_redraw()

static func ease_out(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

static func smooth(x: float) -> float:
	x = clamp(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

func tint(a: float, lift: float = 0.35) -> Color:
	var c = color.lightened(lift)
	return Color(c.r, c.g, c.b, clamp(a, 0.0, 1.0))

func _draw():
	var hit = Vector2(clamp(reach * 0.65, 55.0, 115.0), 0)
	match style:
		"claw":
			sweep(3, 0.5)
		"lash":
			sweep(1, 0.75)
		"sting":
			thrust(tint(0.9, 0.1), 7.0, 3.0, 1)
		"arms":
			thrust(tint(0.85, 0.1), 6.0, 2.0, 2)
		"tongue":
			thrust(Color(0.95, 0.5, 0.58, 0.95), 6.0, 5.0, 1)
		"spines":
			spines()
		"smash":
			lunge_smear(hit, 0.5)
			cavitation(hit)
		"engulf":
			lunge_smear(hit, 0.35)
			ripple(hit, true)
		_:
			# bite, rasp, pincer, clamp
			lunge_smear(hit, 0.45)
			ripple(hit, false)

# A tapered translucent wedge from the head to the target: the motion blur
# of the body and mouth lunging forward
func lunge_smear(hit: Vector2, strength: float):
	var a = strength * (1.0 - smooth(t * 1.6))
	if a <= 0.01:
		return
	var head = 22.0
	var front = lerp(head, hit.x, ease_out(t * 3.0))
	var w = 13.0
	var steps = 8
	for i in steps:
		var f0 = i / float(steps)
		var f1 = (i + 1) / float(steps)
		var x0 = lerp(head, front, f0)
		var x1 = lerp(head, front, f1)
		# Faint at the tail of the smear, strongest at the front
		var c = tint(a * f1 * f1)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0, -w * f0), Vector2(x1, -w * f1), Vector2(x1, w * f1), Vector2(x0, w * f0)]), c)

# A thin ring spreading through the water where the strike lands
func ripple(c: Vector2, inward: bool):
	var k = clamp((t - 0.15) / 0.85, 0.0, 1.0)
	if k <= 0.0:
		return
	var r = (28.0 - 16.0 * ease_out(k)) if inward else (8.0 + 30.0 * ease_out(k))
	var a = 0.55 * (1.0 - k)
	draw_arc(c, r, 0, TAU, 40, tint(a, 0.6), 2.0 * (1.0 - k) + 1.0, true)
	draw_arc(c, r * 0.6, 0, TAU, 32, tint(a * 0.6, 0.6), 1.2, true)

# Swept arc: the leading edge is the claw or tail tip, and the trail behind
# it thins and fades the way a fast motion blurs
func sweep(lines: int, width_k: float):
	var head_f = ease_out(t * 1.8)
	var arc = min(half_arc, 1.2)
	var lead = -arc + 2.0 * arc * head_f
	var trail = 1.1
	var fade = 1.0 - smooth((t - 0.45) / 0.55)
	for i in lines:
		var r = clamp(reach * 0.62, 55.0, 115.0) + (i - (lines - 1) / 2.0) * 10.0
		var n = 18
		var prev := Vector2.ZERO
		for k in n + 1:
			var f = k / float(n)
			var g = lead - trail * f
			if g < -arc:
				break
			var p = Vector2.RIGHT.rotated(g) * r
			if k > 0:
				var w = (1.0 - f) * 9.0 * width_k + 0.5
				draw_line(prev, p, tint(0.6 * fade * (1.0 - f)), w, true)
			prev = p

# A limb shooting out to full reach and back. Extends fast, retracts eased;
# the strands wave a little and lag at the root like a real whip of tissue
func thrust(col: Color, w0: float, w1: float, strands: int):
	var u = t
	var ext = ease_out(u / 0.35) if u < 0.35 else 1.0 - smooth((u - 0.35) / 0.65)
	var length = 18.0 + (reach - 18.0) * ext
	for s in strands:
		var side = 0.0 if strands == 1 else (s * 2.0 - 1.0)
		var pts := PackedVector2Array()
		var m = 14
		for i in m:
			var f = i / float(m - 1)
			var wave = sin(f * 7.0 - t * 18.0) * 3.0 * f * (1.0 - ext * 0.6)
			pts.append(Vector2(18.0 + (length - 18.0) * f, side * (6.0 + 8.0 * f) + wave))
		for i in m - 1:
			var f = i / float(m - 2)
			draw_line(pts[i], pts[i + 1], col, lerp(w0, w1, f), true)
		draw_circle(pts[m - 1], w1 * 0.6, col, true, -1.0, true)

func spines():
	var pop = sin(PI * clamp(t * 1.2, 0.0, 1.0))
	var n = 14
	for i in n:
		var d = Vector2.RIGHT.rotated(TAU * i / n + 0.12)
		draw_line(d * 26.0, d * (26.0 + (reach - 26.0) * 0.5 * pop), tint(0.5 * pop), 2.5, true)
	ripple(Vector2.ZERO, false)

# Mantis shrimp strike: the water boils into a bubble that collapses with a
# flash, then a ring of small bubbles drifts out
func cavitation(c: Vector2):
	if t < 0.1:
		return
	var k = (t - 0.1) / 0.9
	if k < 0.35:
		var g = k / 0.35
		var r = 6.0 + 18.0 * ease_out(g) * (1.0 - g * g)
		draw_circle(c, r, Color(0.9, 0.97, 1.0, 0.25), true, -1.0, true)
		draw_arc(c, r, 0, TAU, 32, Color(0.95, 1.0, 1.0, 0.8), 1.6, true)
	else:
		var g = (k - 0.35) / 0.65
		draw_circle(c, 10.0 * (1.0 - g), Color(1, 1, 1, 0.5 * (1.0 - g)), true, -1.0, true)
		for i in 8:
			var d = Vector2.RIGHT.rotated(TAU * i / 8.0 + 0.4)
			draw_arc(c + d * (10.0 + 26.0 * ease_out(g)), 2.5 * (1.0 - g) + 0.8, 0, TAU, 10, Color(0.95, 1.0, 1.0, 0.7 * (1.0 - g)), 1.2, true)
