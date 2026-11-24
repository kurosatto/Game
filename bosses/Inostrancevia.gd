# Inostrancevia.gd — the Great Dying's last boss on land (data/Endgame.gd)
# Inostrancevia alexandri was the largest gorgonopsian, about 3.5 m long,
# with a skull some 60 cm long and sabre canines over 12 cm. Gorgonopsians
# were synapsids, on the line to mammals, and the top predators of the Late
# Permian. Their jaws could gape to about 90 degrees so the sabres cleared
# the lower jaw. Its limbs stood more under the body than Dimetrodon's
# sprawl. Fossils found in South Africa (2023) show it moved in there just
# before the Great Dying, after the local gorgonopsians had died out, and
# then it too was gone.
# Attacks: a sabre lunge with the jaws flung open, a pounce that lands with
# a thump where you stood, and a raking swipe of the forefeet. In phase 2 it
# melts into the ash and rushes out of it, and pounces twice.
extends "res://bosses/BossBase.gd"

const SKIN = Color(0.62, 0.5, 0.38)
const SADDLE = Color(0.4, 0.3, 0.22)
const BELLY = Color(0.82, 0.72, 0.56)
const TOOTH = Color(1.0, 0.97, 0.88)
const MOUTH = Color(0.5, 0.12, 0.1)
const RUSH_SPEED := 1250.0

var gait: float = 0.0
var walk: float = 0.0
var gape: float = 0.0          # 0 shut .. 1 the full 90-degree gape
var bend: float = 0.0
var did_hit: bool = false
var lunge_dir: Vector2 = Vector2.DOWN
var leap_from: Vector2
var leap_to: Vector2
var air: float = 0.0           # 0 on the ground .. 1 top of the leap
var pounces_left: int = 0
var swipe: float = 0.0         # forefoot rake, -1..1
var swipe_side: float = 1.0
var haze: float = 0.0          # 1 hidden in the ash
var rush_dir: Vector2 = Vector2.DOWN

func setup():
	boss_title = "INOSTRANCEVIA — LAST OF THE GORGONOPSIANS"
	boss_fact = "The biggest gorgonopsian, a sabre-toothed synapsid 3.5 m long. It reached South Africa just before the Great Dying, and died out with it."
	max_health = 520.0
	damage = 1
	light.color = Color(1.0, 0.55, 0.3)
	light.energy = 1.5
	light.scale = Vector2(4.4, 4.4)

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 52.0

func killer_name() -> String:
	return "Inostrancevia"

func burst_color() -> Color:
	return SKIN

func damage_taken_mult() -> float:
	# Up in the air or lost in the ash it can't be reached
	if air > 0.55 or haze > 0.7:
		return 0.0
	return 1.0

func think(delta: float):
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.2 if phase2 else 1.0
	var prev_angle = facing.angle()
	if not state in ["sabre_wind", "sabre", "pounce", "rush_wind", "rush", "intro"]:
		gape = move_toward(gape, 0.0, delta * 2.5)
	swipe = move_toward(swipe, 0.0, delta * 3.0)
	if not state in ["ash_wind", "ash", "rush_wind"]:
		haze = move_toward(haze, 0.0, delta * 2.5)
	modulate.a = 1.0 - haze * 0.85
	match state:
		"intro":
			walk = 0.0
			turn_toward(to_p, 2.0, delta)
			gape = 0.5 + 0.4 * sin(state_time * 4.0) # a slow, open-mouthed threat
			if state_time > 1.3:
				set_state("stalk")
		"stalk":
			# Prowls in close, a little to one side, head always on you
			walk = 1.0
			turn_toward(to_p, 2.8 * spd, delta)
			var drift = Vector2(-to_p.y, to_p.x).normalized() * 0.35
			move_by((facing + drift).normalized() * 190.0 * spd * delta, 80.0)
			if state_time < 0.7 / spd:
				pass
			elif d < 240.0 and randf() < 0.5:
				swipe_side = 1.0 if facing.cross(to_p) >= 0.0 else -1.0
				set_state("swipe_wind")
			elif d < 420.0 and abs(facing.angle_to(to_p)) < 0.45:
				set_state("sabre_wind")
				SoundManager.play_sfx("boss_roar", 0.7)
			elif d > 380.0 or state_time > 2.6:
				if phase2 and randf() < 0.4:
					set_state("ash_wind")
				else:
					pounces_left = 2 if phase2 else 1
					set_state("pounce_wind")
		"sabre_wind":
			# Jaws flung wide: the sabres clear the lower jaw
			walk = 0.0
			turn_toward(to_p, 6.0, delta)
			lunge_dir = facing
			gape = move_toward(gape, 1.0, delta * 3.0)
			if state_time > 0.6 / spd:
				set_state("sabre")
				did_hit = false
				SoundManager.play_sfx("dash", 0.5)
		"sabre":
			walk = 1.4
			gape = 1.0 if state_time < 0.18 else 0.2
			if state_time < 0.24:
				move_by(lunge_dir * 1350.0 * delta, 80.0)
			if not did_hit and state_time > 0.06 and state_time < 0.28:
				did_hit = hurt_circle(global_position + facing * 150.0, 58.0, 2)
				if did_hit:
					push_player(lunge_dir * 420.0)
			if state_time > 0.22 and state_time - delta <= 0.22:
				shake(8.0)
			if state_time > 0.7:
				set_state("stalk")
		"swipe_wind":
			walk = 0.0
			turn_toward(to_p, 5.0, delta)
			swipe = move_toward(swipe, -swipe_side, delta * 3.5)
			if state_time > 0.45 / spd:
				set_state("swipe")
				did_hit = false
				SoundManager.play_sfx("dash", 0.75)
		"swipe":
			# A rake of the big forefoot across the front
			swipe = lerp(-swipe_side, swipe_side * 1.2, clamp(state_time / 0.18, 0.0, 1.0))
			if not did_hit:
				var paw = global_position + (facing * 120.0 + facing.orthogonal() * swipe * 70.0)
				did_hit = hurt_circle(paw, 62.0)
				if did_hit:
					push_player(facing.orthogonal() * swipe_side * 500.0)
			if state_time > 0.5:
				set_state("stalk")
		"pounce_wind":
			# Crouches, haunches bunched, eyes on where you stand
			walk = 0.0
			turn_toward(to_p, 6.0, delta)
			leap_to = clamp_arena(player.global_position, 100.0)
			if state_time > 0.75 / spd:
				leap_from = global_position
				set_state("pounce")
				SoundManager.play_sfx("dash", 0.4)
		"pounce":
			var k = clamp(state_time / 0.6, 0.0, 1.0)
			air = sin(k * PI)
			global_position = leap_from.lerp(leap_to, k)
			turn_toward(leap_to - leap_from, 8.0, delta)
			gape = k
			if k >= 1.0:
				air = 0.0
				shake(13.0)
				SoundManager.play_sfx("explosion", 0.8, -4.0)
				hurt_circle(global_position, 95.0, 2)
				spawn_hazard("ring", global_position, {"speed": 480.0, "max_r": 340.0, "width": 26.0, "dmg": 1, "color": Color(0.55, 0.45, 0.38)})
				pounces_left -= 1
				set_state("pounce_land")
		"pounce_land":
			walk = 0.0
			if state_time > (0.35 if pounces_left > 0 else 0.9):
				set_state("pounce_wind" if pounces_left > 0 else "stalk")
		"ash_wind":
			# Backs off into the ash cloud and fades
			walk = 0.8
			turn_toward(-to_p, 4.0, delta)
			move_by(facing * 220.0 * delta, 80.0)
			haze = move_toward(haze, 1.0, delta * 1.4)
			if haze >= 1.0 or state_time > 1.5:
				haze = 1.0
				set_state("ash")
		"ash":
			# Unseen, circling to come at you from the far side
			walk = 1.0
			var side = Vector2(-to_p.y, to_p.x).normalized()
			move_by(side * 330.0 * delta, 80.0)
			turn_toward(to_p, 4.0, delta)
			if state_time > 1.3:
				set_state("rush_wind")
		"rush_wind":
			walk = 0.0
			turn_toward(to_p, 7.0, delta)
			rush_dir = facing
			haze = move_toward(haze, 0.35, delta * 1.5)
			gape = move_toward(gape, 0.8, delta * 2.0)
			if state_time > 0.7:
				set_state("rush")
				did_hit = false
				SoundManager.play_sfx("boss_roar", 0.55)
		"rush":
			walk = 1.7
			gape = 1.0
			if not did_hit:
				did_hit = hurt_circle(global_position + facing * 140.0, 64.0, 2)
			if move_by(rush_dir * RUSH_SPEED * delta, 80.0) or state_time > 1.0:
				shake(10.0)
				set_state("stalk")
	gait += delta * walk * 6.5 * spd
	var turn = wrapf(facing.angle() - prev_angle, -PI, PI) / max(delta, 0.001)
	bend = lerp(bend, clamp(turn * 0.22, -0.7, 0.7), delta * 6.0)
	var back = facing
	set_hit_circles([global_position + back * 130.0, global_position - back * 60.0, global_position - back * 150.0], [36.0, 44.0, 24.0])

# Body-frame spine offset at x (forward is +x): a gentler sway than a sprawler
func sway(x: float) -> float:
	var tailness = clamp(-x / 180.0, 0.0, 1.0)
	var y = sin(gait - x * 0.01) * 5.0 * walk * (0.4 + tailness)
	return y + bend * 0.0011 * x * abs(x)

func body_w(x: float) -> float:
	var pts = [[115, 34], [95, 42], [70, 52], [30, 64], [-30, 66], [-80, 52], [-110, 30], [-200, 5]]
	for i in pts.size() - 1:
		if x <= pts[i][0] and x >= pts[i + 1][0]:
			var f = (pts[i][0] - x) / float(pts[i][0] - pts[i + 1][0])
			return lerp(float(pts[i][1]), float(pts[i + 1][1]), f)
	return 3.0

func draw_body():
	if state == "sabre_wind":
		warn_line(facing * 110.0, facing * 470.0, 120.0)
	if state == "swipe_wind":
		warn_sector(Vector2.ZERO, 230.0, facing.angle(), 1.1)
	if state == "pounce_wind":
		warn_circle(to_local(leap_to), 95.0)
	if state == "rush_wind":
		warn_line(facing * 100.0, facing * (100.0 + RUSH_SPEED), 130.0)

	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	# Its shadow drops away below it in a leap
	shadow(Vector2(-20, 14 + air * 40.0), 180 * (1.0 - air * 0.25), 60 * (1.0 - air * 0.25))
	var lift = 1.0 + air * 0.18
	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2(lift, lift))

	# Legs held more under the body than Dimetrodon's: knees in, feet close
	for leg in [[60.0, 0.0, 1.0], [-80.0, PI, 0.9]]:
		for side in [-1.0, 1.0]:
			var x: float = leg[0]
			var ph = gait + leg[1] + (0.0 if side > 0 else PI)
			var hip = Vector2(x, sway(x) + side * body_w(x) * 0.65)
			var step = sin(ph) * 34.0 * walk
			var reach = 0.0
			if x > 0.0 and state in ["swipe_wind", "swipe"]:
				# The raking forefoot swings out across the front
				reach = 1.0 if side == swipe_side else 0.0
			var foot = Vector2(x + 16.0 + step + reach * 46.0, sway(x) + side * (body_w(x) + 34.0) + reach * swipe * 60.0)
			if air > 0.1:
				foot = Vector2(x + (40.0 if x > 0 else -50.0) * air, sway(x) + side * (body_w(x) + 8.0))
			var knee = hip.lerp(foot, 0.5) + Vector2(-14.0 if x > 0 else 16.0, side * 14.0)
			limb(PackedVector2Array([hip, knee, foot]), 22.0 * leg[2], shade(SKIN, 0.85))
			for toe in 5:
				var ta = (toe - 2) * 0.28
				draw_line(foot, foot + Vector2(12, 0).rotated(ta), OUTLINE, 4.5, true)
				draw_line(foot, foot + Vector2(11, 0).rotated(ta), TOOTH, 2.0, true)

	# Body and short tail along the spine
	var spine := []
	var widths := []
	for i in 26:
		var x = 112.0 - i * 12.0
		spine.append(Vector2(x, sway(x)))
		widths.append(body_w(x))
	tube_shaded(spine, widths, SKIN)
	# Dark blotches along the flanks
	for i in range(5, 19, 3):
		var p: Vector2 = spine[i]
		var w: float = widths[i]
		for s in [-1.0, 1.0]:
			draw_circle(p + Vector2(0, s * w * 0.55), 6.0 + (i % 2) * 2.0, Color(SADDLE, 0.6), true, -1.0, true)

	draw_head()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

func draw_head():
	# A long, deep skull; the jaw hinges far back so it can open to 90°
	var hinge = Vector2(100, sway(100))
	var open = gape * 0.75
	var skull := PackedVector2Array()
	for p in [Vector2(-8, 0), Vector2(0, -34), Vector2(30, -40), Vector2(70, -32), Vector2(98, -20), Vector2(108, -8), Vector2(110, 0), Vector2(108, 8), Vector2(98, 20), Vector2(70, 32), Vector2(30, 40), Vector2(0, 34)]:
		skull.append(hinge + p)
	if gape > 0.08:
		# The jaws part around a hinge far back (drawn apart, as the other
		# bosses are): a deep red gape with the sabres bared at the front
		var mouth := PackedVector2Array([hinge + Vector2(6, 0), hinge + Vector2(108, -2).rotated(-open * 0.5), hinge + Vector2(108, 2).rotated(open * 0.5)])
		draw_colored_polygon(mouth, MOUTH)
		for jaw in [-1.0, 1.0]:
			var rot = jaw * open * 0.5
			var pts := PackedVector2Array()
			for p in [Vector2(0, 0), Vector2(0, jaw * 34), Vector2(30, jaw * 40), Vector2(70, jaw * 32), Vector2(98, jaw * 20), Vector2(108, jaw * 6), Vector2(104, 0)]:
				pts.append(hinge + p.rotated(rot))
			shape(pts, shade(SKIN, 1.06), 3.0)
			# The sabre hangs from the front of each upper jaw, the long
			# blade inward across the gape
			var root = hinge + Vector2(84, jaw * 8).rotated(rot)
			var tip = root + Vector2(10, -jaw * (26.0 + gape * 10.0)).rotated(rot)
			draw_line(root, tip, OUTLINE, 9.0, true)
			draw_line(root, tip, TOOTH, 5.0, true)
			for k in 4:
				var tp = hinge + Vector2(40 + k * 10, jaw * 6).rotated(rot)
				draw_line(tp, tp - Vector2(0, jaw * 6).rotated(rot), OUTLINE, 4.0, true)
				draw_line(tp, tp - Vector2(0, jaw * 6).rotated(rot), TOOTH, 2.0, true)
			var eye = hinge + Vector2(32, jaw * 27).rotated(rot)
			draw_circle(eye, 7.0, OUTLINE, true, -1.0, true)
			draw_circle(eye, 5.0, Color(1.0, 0.72, 0.25), true, -1.0, true)
			draw_circle(eye + Vector2(1, 0), 2.2, OUTLINE, true, -1.0, true)
		return
	shape(skull, shade(SKIN, 1.06), 3.0)
	draw_line(hinge + Vector2(12, 0), hinge + Vector2(90, 0), shade(SKIN, 0.78), 2.0, true)
	# The sabres: long upper canines that hang below the snout either side,
	# longer and bared when it gapes
	for side in [-1.0, 1.0]:
		var root = hinge + Vector2(80, side * 28)
		var tip = root + Vector2(-6 + gape * 6.0, side * (20.0 + gape * 16.0))
		draw_line(root, tip, OUTLINE, 8.0, true)
		draw_line(root, tip, TOOTH, 4.5, true)
		# A few smaller incisors at the front
		for k in 3:
			var ip = hinge + Vector2(94 - k * 3, side * (6 + k * 4))
			draw_line(ip, ip + Vector2(4, side * 5), OUTLINE, 3.5, true)
			draw_line(ip, ip + Vector2(4, side * 5), TOOTH, 1.8, true)
		var eye = hinge + Vector2(32, side * 27)
		draw_circle(eye, 7.0, OUTLINE, true, -1.0, true)
		draw_circle(eye, 5.0, Color(1.0, 0.72, 0.25), true, -1.0, true)
		draw_circle(eye + Vector2(1, 0), 2.2, OUTLINE, true, -1.0, true)
		draw_circle(hinge + Vector2(96, side * 4), 2.0, OUTLINE, true, -1.0, true)
