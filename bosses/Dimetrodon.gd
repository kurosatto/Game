# Dimetrodon.gd — floor 5 (Permian) boss
# Dimetrodon was a sail-backed synapsid, closer kin to mammals than to any
# dinosaur, and the top predator of its Early Permian world (up to about
# 3.5 m long). It walked with sprawling legs and a side-to-side swaying
# spine. Its name means "two measures of teeth": big stabbing teeth up front,
# smaller ones behind. The sail of long neural spines may have helped it warm
# up in the sun (an old, still-debated idea); here basking makes it faster.
# Attacks: a lunging bite, a tail sweep at anyone behind it, and basking in a
# sunbeam to warm up (hit it hard enough while it basks to scare it off).
extends "res://bosses/BossBase.gd"

const SKIN = Color(0.56, 0.44, 0.34)
const STRIPE = Color(0.36, 0.26, 0.2)
const SAIL = Color(0.78, 0.44, 0.30)
const SAIL_SPINE = Color(0.95, 0.88, 0.72)
const TOOTH = Color(1.0, 0.97, 0.88)

var gait: float = 0.0
var walk: float = 0.0          # 0 standing .. 1 striding
var gape: float = 0.0          # jaw opening
var warmth: float = 0.0        # sail glow; above 0 it moves faster
var warm_time: float = 0.0
var bask_damage: float = 0.0
var sun_pos: Vector2
var lunge_dir: Vector2
var bites_left: int = 0
var did_hit: bool = false
var tail_swing: float = 0.0    # tail sweep angle
var sweep_side: float = 1.0
var bend: float = 0.0
var attacks: int = 0           # since it last warmed up

func setup():
	boss_title = "DIMETRODON — SAIL-BACKED SYNAPSID"
	boss_fact = "Not a dinosaur: a synapsid, on the line that led to mammals. Its name means two measures of teeth, and its sail may have soaked up the morning sun."
	max_health = 420.0
	damage = 1
	light.color = Color(1.0, 0.65, 0.35)
	light.energy = 1.5
	light.scale = Vector2(4.2, 4.2)

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 50.0
	sun_pos = pick_sun()

func burst_color() -> Color:
	return SAIL

func pick_sun() -> Vector2:
	return Vector2(randf_range(ARENA.position.x + 200, ARENA.end.x - 200), randf_range(ARENA.position.y + 150, ARENA.end.y - 150))

func take_damage(amount: float):
	if state == "bask":
		bask_damage += amount
	super.take_damage(amount)

func is_warm() -> bool:
	return warm_time > 0.0

func think(delta: float):
	var to_p = to_player()
	var d = to_p.length()
	var spd = (1.45 if is_warm() else 1.0) * (1.15 if phase2 else 1.0)
	var wind = 0.7 if is_warm() else 1.0
	var prev_angle = facing.angle()
	warm_time = max(0.0, warm_time - delta)
	if state != "bask":
		warmth = move_toward(warmth, 1.0 if is_warm() else 0.0, delta * 0.6)
	gape = move_toward(gape, 0.0, delta * 3.0)
	tail_swing = move_toward(tail_swing, 0.0, delta * 3.0)
	match state:
		"intro":
			walk = 0.0
			turn_toward(to_p, 2.0, delta)
			if state_time > 1.2:
				set_state("stalk")
		"stalk":
			walk = 1.0
			turn_toward(to_p, 2.6 * spd, delta)
			move_by(facing * 175.0 * spd * delta, 70.0)
			var behind = abs(facing.angle_to(to_p)) > 2.0
			if behind and d < 330.0 and state_time > 0.6:
				attacks += 1
				set_state("tail_wind")
				sweep_side = sign(facing.cross(to_p)) if facing.cross(to_p) != 0 else 1.0
			elif not is_warm() and (attacks >= 3 or state_time > 4.0):
				# Cooling down: off to the sunbeam
				attacks = 0
				sun_pos = pick_sun()
				set_state("to_sun")
			elif d < 360.0 and abs(facing.angle_to(to_p)) < 0.5 and state_time > 0.8:
				attacks += 1
				bites_left = 2 if phase2 else 1
				set_state("bite_wind")
				SoundManager.play_sfx("boss_roar", 0.75)
		"to_sun":
			walk = 1.0
			var to_s = sun_pos - global_position
			turn_toward(to_s, 3.0, delta)
			move_by(facing * 210.0 * delta, 70.0)
			if to_s.length() < 30.0 or state_time > 5.0:
				bask_damage = 0.0
				set_state("bask")
		"bask":
			# Stands broadside in the sun and the sail warms through
			walk = 0.0
			warmth = move_toward(warmth, 1.0, delta * 0.55)
			if bask_damage > max_health * 0.08:
				# Startled out of the sun before it warmed up
				SoundManager.play_sfx("boss_roar", 1.2)
				warmth = 0.0
				set_state("stalk")
			elif state_time > 2.0:
				warm_time = 9.0
				SoundManager.play_sfx("boss_roar", 0.65)
				shake(6.0)
				set_state("stalk")
		"bite_wind":
			# Head low, jaws open: the stabbing front teeth show
			walk = 0.0
			turn_toward(to_p, 6.0, delta)
			lunge_dir = facing
			gape = move_toward(gape, 1.0, delta * 4.0)
			if state_time > 0.5 * wind:
				set_state("bite")
				did_hit = false
				SoundManager.play_sfx("dash", 0.55)
		"bite":
			walk = 1.0
			gape = 1.0 if state_time < 0.16 else 0.0
			move_by(lunge_dir * 1500.0 * delta if state_time < 0.2 else Vector2.ZERO, 70.0)
			if not did_hit and state_time > 0.08 and state_time < 0.24:
				did_hit = hurt_circle(global_position + facing * 135.0, 55.0, 2)
			if state_time > 0.2 and state_time - delta <= 0.2:
				shake(7.0)
			if state_time > 0.55 * wind:
				bites_left -= 1
				set_state("bite_wind" if bites_left > 0 else "stalk")
		"tail_wind":
			walk = 0.0
			tail_swing = move_toward(tail_swing, -sweep_side * 0.5, delta * 3.0)
			if state_time > 0.55 * wind:
				set_state("tail")
				did_hit = false
				SoundManager.play_sfx("dash", 0.7)
		"tail":
			# A sweep of the heavy tail across everything behind it
			tail_swing = lerp(-sweep_side * 0.5, sweep_side * 1.4, clamp(state_time / 0.25, 0.0, 1.0))
			if not did_hit:
				var tip = tail_tip_global()
				did_hit = hurt_circle(tip, 50.0) or hurt_circle((tip + global_position) * 0.5, 40.0)
			if state_time > 0.6:
				set_state("stalk")
	gait += delta * walk * 5.5 * spd
	var turn = wrapf(facing.angle() - prev_angle, -PI, PI) / max(delta, 0.001)
	bend = lerp(bend, clamp(turn * 0.25, -0.8, 0.8), delta * 6.0)
	var back = facing
	set_hit_circles([global_position + back * 115.0, global_position - back * 70.0, global_position - back * 150.0], [30.0, 42.0, 22.0])

# Body-frame y offset of the spine at x (forward is +x): the sprawling sway
func sway(x: float) -> float:
	var tailness = clamp(-x / 200.0, 0.0, 1.0)
	var y = sin(gait - x * 0.012) * 9.0 * walk * (0.5 + tailness)
	y += bend * 0.0012 * x * abs(x)
	if x < -90.0:
		y += tail_swing * (-x - 90.0) * 0.9
	return y

func tail_tip_global() -> Vector2:
	return global_position + Vector2(-250.0, sway(-250.0)).rotated(facing.angle())

func body_w(x: float) -> float:
	var pts = [[150, 7], [125, 20], [100, 26], [80, 20], [40, 42], [-20, 44], [-70, 36], [-100, 22], [-260, 3]]
	for i in pts.size() - 1:
		if x <= pts[i][0] and x >= pts[i + 1][0]:
			var f = (pts[i][0] - x) / float(pts[i][0] - pts[i + 1][0])
			return lerp(float(pts[i][1]), float(pts[i + 1][1]), f)
	return 3.0

func draw_body():
	if is_warm() or state == "to_sun" or state == "bask":
		# The sunbeam it heads for, lit on the floor
		var sp = to_local(sun_pos)
		draw_circle(sp, 120.0, Color(1.0, 0.9, 0.5, 0.10 + 0.04 * sin(t * 2.0)), true, -1.0, true)
		draw_circle(sp, 80.0, Color(1.0, 0.95, 0.6, 0.10), true, -1.0, true)
	if state == "bite_wind":
		warn_line(facing * 100.0, facing * 380.0, 110.0)
	if state == "tail_wind":
		warn_sector(Vector2.ZERO, 300.0, (-facing).angle(), 1.3)

	var up = Vector2(0, -1).rotated(-facing.angle())
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	shadow(Vector2(-30, 14), 190, 64)

	# Sprawling legs: upper leg out to the side, foot planted, diagonal pairs
	for leg in [[40.0, 0.0], [-65.0, PI]]:
		for side in [-1.0, 1.0]:
			var ph = gait + leg[1] + (0.0 if side > 0 else PI)
			var hip = Vector2(leg[0], sway(leg[0]) + side * body_w(leg[0]) * 0.7)
			var step = sin(ph) * 26.0 * walk
			var foot = Vector2(leg[0] + 18.0 + step, sway(leg[0]) + side * (body_w(leg[0]) + 46.0))
			var knee = Vector2(leg[0] + step * 0.4 - 6.0, sway(leg[0]) + side * (body_w(leg[0]) + 26.0))
			limb(PackedVector2Array([hip, knee, foot]), 13.0, shade(SKIN, 0.85))
			for toe in 4:
				var ta = (toe - 1.5) * 0.35
				draw_line(foot, foot + Vector2(11, 0).rotated(ta), OUTLINE, 4.0, true)
				draw_line(foot, foot + Vector2(10, 0).rotated(ta), TOOTH, 2.0, true)

	# Body, tail and neck along the swaying spine
	var spine := []
	var widths := []
	for i in 30:
		var x = 100.0 - i * 12.0
		spine.append(Vector2(x, sway(x)))
		widths.append(body_w(x))
	tube_shaded(spine, widths, SKIN)
	for i in range(3, 22, 2):
		var p: Vector2 = spine[i]
		var w: float = widths[i]
		draw_line(p + Vector2(0, -w * 0.9), p + Vector2(-8, -w * 0.3), Color(STRIPE.r, STRIPE.g, STRIPE.b, 0.8), 3.0, true)
		draw_line(p + Vector2(0, w * 0.9), p + Vector2(-8, w * 0.3), Color(STRIPE.r, STRIPE.g, STRIPE.b, 0.8), 3.0, true)

	draw_head()

	# The sail stands up off the back; seen from above at an angle it rises
	# toward the top of the screen whichever way the animal faces
	var base := PackedVector2Array()
	var tips := []
	var top := PackedVector2Array()
	var n = 13
	for i in n:
		var x = 55.0 - i * 11.0
		var f = i / float(n - 1)
		var h = sin(f * PI) * 105.0 + 8.0
		var b = Vector2(x, sway(x))
		base.append(b)
		tips.append(b + up * (h + 10.0))
		top.append(b + up * h)
		# The membrane sags a little between spine tips
		if i < n - 1:
			var x2 = x - 5.5
			var h2 = sin((i + 0.5) / float(n - 1) * PI) * 105.0 + 8.0
			top.append(Vector2(x2, sway(x2)) + up * (h2 - 9.0))
	var glow = SAIL.lerp(Color(1.0, 0.45, 0.15), warmth)
	var membrane := base.duplicate()
	var rev := top.duplicate()
	rev.reverse()
	membrane.append_array(rev)
	shape(membrane, Color(glow.r, glow.g, glow.b, 0.9), 3.0)
	# Darker blotches along the membrane, as many reconstructions show
	for i in range(2, n - 2, 3):
		draw_circle(base[i].lerp(tips[i], 0.5), 7.0, shade(glow, 0.8), true, -1.0, true)
	for i in base.size():
		draw_line(base[i], tips[i], OUTLINE, 5.0, true)
		draw_line(base[i], tips[i], SAIL_SPINE.lerp(Color(1.0, 0.8, 0.5), warmth), 2.5, true)
	if warmth > 0.05:
		draw_polyline(top, Color(1.0, 0.85, 0.4, warmth * (0.6 + 0.3 * sin(t * 6.0))), 4.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

func draw_head():
	# Deep skull; jaws part around a hinge behind the eye when it bites
	var hinge = Vector2(98, sway(98))
	var open = gape * 0.45
	if gape <= 0.05:
		var skull := PackedVector2Array()
		for p in [Vector2(-4, 0), Vector2(6, -22), Vector2(30, -24), Vector2(54, -14), Vector2(64, -5), Vector2(66, 0), Vector2(64, 5), Vector2(54, 14), Vector2(30, 24), Vector2(6, 22)]:
			skull.append(hinge + p)
		shape(skull, shade(SKIN, 1.05), 3.0)
		draw_line(hinge + Vector2(10, 0), hinge + Vector2(60, 0), shade(SKIN, 0.75), 2.0, true)
		draw_circle(hinge + Vector2(60, -4), 2.0, OUTLINE, true, -1.0, true)
		draw_circle(hinge + Vector2(60, 4), 2.0, OUTLINE, true, -1.0, true)
	if gape > 0.05:
		var mouth := PackedVector2Array([hinge + Vector2(6, 0)])
		mouth.append(hinge + Vector2(58, -2).rotated(-open * 0.5))
		mouth.append(hinge + Vector2(58, 2).rotated(open * 0.5))
		draw_colored_polygon(mouth, Color(0.55, 0.12, 0.12))
	for jaw in ([-1.0, 1.0] if gape > 0.05 else []):
		var rot = jaw * open * 0.5
		var pts := PackedVector2Array()
		for p in [Vector2(0, 0), Vector2(22, jaw * 24), Vector2(52, jaw * 16), Vector2(62, jaw * 4), Vector2(56, 0)]:
			pts.append(hinge + p.rotated(rot))
		shape(pts, shade(SKIN, 1.05 - jaw * 0.05), 3.0)
		if gape > 0.05:
			# Two measures of teeth: a big stabbing pair near the front
			for k in 5:
				var tp = hinge + Vector2(22 + k * 8, jaw * (3 + k * 0.5)).rotated(rot)
				var tl = 10.0 if k == 3 else 5.0
				draw_line(tp, tp - Vector2(0, jaw * tl).rotated(rot), OUTLINE, 5.0, true)
				draw_line(tp, tp - Vector2(0, jaw * tl).rotated(rot), TOOTH, 3.0, true)
	for side in [-1.0, 1.0]:
		var eye = hinge + Vector2(14, side * 13)
		draw_circle(eye, 6.0, OUTLINE, true, -1.0, true)
		draw_circle(eye, 4.5, Color(1.0, 0.8, 0.25), true, -1.0, true)
		draw_circle(eye + Vector2(1, 0), 2.0, OUTLINE, true, -1.0, true)
