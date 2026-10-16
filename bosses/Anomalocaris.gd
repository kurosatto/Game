# Anomalocaris.gd — floor 2 (Cambrian) boss
# Anomalocaris canadensis, a radiodont from the Burgess Shale and one of the
# first big predators (around half a metre to a metre long). It swam by
# beating rows of overlapping side flaps in a wave, steered with a tail fan,
# watched with large stalked compound eyes and seized prey with two spiny
# frontal appendages that curled under the head toward a ring-shaped mouth.
# No shots: it circles, then either grabs at close range (appendages open,
# then snap shut) or charges across the room.
extends "res://bosses/BossBase.gd"

const BODY = Color(0.80, 0.33, 0.26)
const FLAP = Color(0.93, 0.52, 0.38)
const LIMB = Color(0.88, 0.40, 0.28)
const SPINE = Color(1.0, 0.9, 0.75)

var vel: Vector2 = Vector2.ZERO
var flap_rate: float = 7.0
var flap_phase: float = 0.0
var curl: float = 0.35      # 0 = appendages straight out, 1 = curled shut
var spread: float = 0.15    # how far the appendages open sideways
var bend: float = 0.0       # body curve while turning
var orbit_dir: float = 1.0
var lunge_dir: Vector2 = Vector2.DOWN
var lunges_left: int = 0
var did_hit: bool = false
var eye_look: float = 0.0

func setup():
	boss_title = "ANOMALOCARIS CANADENSIS — CAMBRIAN RADIODONT"
	boss_fact = "One of the first big predators. It swam with rippling side flaps and grabbed prey with two spiny arms that curled under its head."
	max_health = 150.0
	damage = 1
	light.color = Color(1.0, 0.55, 0.4)
	light.energy = 1.4

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 50.0

func burst_color() -> Color:
	return BODY

func think(delta: float):
	var to_p = to_player()
	var spd = 1.35 if phase2 else 1.0
	var prev_angle = facing.angle()
	match state:
		"intro":
			vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
			turn_toward(to_p, 3.0, delta)
			if state_time > 1.0:
				set_state("cruise")
		"cruise":
			# Circle the player at a distance, flaps rippling
			flap_rate = 8.0
			curl = move_toward(curl, 0.35, delta * 2.0)
			spread = move_toward(spread, 0.15, delta * 2.0)
			var d = to_p.length()
			var radial = to_p.normalized() * clamp((d - 360.0) / 200.0, -1.0, 1.0)
			var tangent = Vector2(-to_p.y, to_p.x).normalized() * orbit_dir
			var want = (radial + tangent).normalized() * 300.0 * spd
			vel = vel.move_toward(want, 700.0 * delta)
			if move_by(vel * delta, 60.0):
				orbit_dir = -orbit_dir
			turn_toward(vel, 4.0, delta)
			if state_time > randf_range(1.8, 2.6) / spd:
				if d < 430.0:
					set_state("grab_wind")
				else:
					lunges_left = 3 if phase2 else 1
					set_state("lunge_wind")
				SoundManager.play_sfx("boss_roar", 1.1)
		"grab_wind":
			# Turns to face you with the appendages flung open
			flap_rate = 12.0
			turn_toward(to_p, 7.0, delta)
			curl = move_toward(curl, 0.0, delta * 3.0)
			spread = move_toward(spread, 1.0, delta * 3.0)
			vel = vel.move_toward(to_p.normalized() * 90.0, 600.0 * delta)
			move_by(vel * delta, 60.0)
			if state_time > 0.6 / spd:
				set_state("grab")
				did_hit = false
				vel = facing * 900.0
				SoundManager.play_sfx("dash", 0.8)
		"grab":
			# Short dart forward while the appendages snap shut
			curl = move_toward(curl, 1.0, delta * 7.0)
			spread = move_toward(spread, 0.0, delta * 7.0)
			vel = vel.move_toward(Vector2.ZERO, 3000.0 * delta)
			move_by(vel * delta, 60.0)
			if not did_hit and in_grab(to_p):
				player.take_damage(2 if phase2 else 1)
				did_hit = true
			if state_time > 0.35:
				set_state("recover")
		"lunge_wind":
			# Backs off a little and lines up a charge
			flap_rate = 3.0
			turn_toward(to_p, 8.0, delta)
			lunge_dir = facing
			vel = -facing * 60.0
			move_by(vel * delta, 60.0)
			curl = move_toward(curl, 0.9, delta * 3.0)
			if state_time > 0.7 / spd:
				set_state("lunge")
				vel = lunge_dir * 1150.0 * (1.1 if phase2 else 1.0)
				SoundManager.play_sfx("dash", 0.6)
		"lunge":
			flap_rate = 22.0
			hurt_circle(global_position + facing * 40.0, 55.0)
			if move_by(vel * delta, 60.0) or state_time > 1.2:
				shake(10.0)
				SoundManager.play_sfx("explosion", 1.4, -6.0)
				lunges_left -= 1
				vel = Vector2.ZERO
				if lunges_left > 0:
					set_state("lunge_wind")
				else:
					set_state("recover")
		"recover":
			flap_rate = 5.0
			vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
			move_by(vel * delta, 60.0)
			if state_time > 0.7:
				orbit_dir = 1.0 if randf() < 0.5 else -1.0
				set_state("cruise")
	flap_phase += delta * flap_rate
	var turn = wrapf(facing.angle() - prev_angle, -PI, PI) / max(delta, 0.001)
	bend = lerp(bend, clamp(turn * 0.15, -0.6, 0.6), delta * 6.0)
	eye_look = lerp_angle(eye_look, clamp(wrapf(to_p.angle() - facing.angle(), -PI, PI), -0.6, 0.6), delta * 5.0)
	var back = Vector2.RIGHT.rotated(facing.angle())
	set_hit_circles([global_position - back * 90.0, global_position - back * 175.0], [44.0, 30.0])

# Is the player inside the closing appendages?
func in_grab(to_p: Vector2) -> bool:
	return to_p.length() < 230.0 and abs(facing.angle_to(to_p)) < 0.75

# Body-frame point (x forward, y to the side), bent along the body curve
func bx(x: float, y: float) -> Vector2:
	# Only the trunk behind the head bends
	return Vector2(x, y + bend * 0.004 * x * x) if x < 0 else Vector2(x, y)

func draw_body():
	if state == "grab_wind":
		warn_sector(Vector2.ZERO, 230.0, facing.angle(), 0.75)
	if state == "lunge_wind":
		warn_line(Vector2.ZERO, lunge_dir * 1400.0, 90.0)

	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	shadow(bx(-90, 0) + Vector2(0, 0), 170, 60)

	# Tail fan: three pairs of blades
	var tail = bx(-235, 0)
	for side in [-1.0, 1.0]:
		for k in 3:
			var a = PI + side * (0.35 + k * 0.32) + sin(flap_phase * 0.5) * 0.1
			var tip = tail + Vector2.RIGHT.rotated(a) * (70.0 - k * 10.0)
			var mid = tail + Vector2.RIGHT.rotated(a + side * 0.12) * 35.0
			shape(PackedVector2Array([tail, mid + Vector2.RIGHT.rotated(a + PI / 2) * 11.0, tip, mid - Vector2.RIGHT.rotated(a + PI / 2) * 11.0]), shade(FLAP, 0.9 + k * 0.05), 2.0)

	# Lateral flaps, back to front so the front ones overlap, beating in a wave
	for i in range(10, -1, -1):
		var x = 10.0 - i * 22.0
		var w = body_w(x)
		for side in [-1.0, 1.0]:
			var stroke = sin(flap_phase - i * 0.65)
			var root = bx(x, side * w * 0.8)
			var length = 64.0 - abs(i - 3) * 3.5
			var ang = side * (PI * 0.5 + 0.55) + side * stroke * 0.35
			var tip = root + Vector2.RIGHT.rotated(ang) * length
			# Broad rounded lobe, its front edge overlapping the next flap
			var lobe = ellipse_pts(root + (tip - root) * 0.5, length * 0.55, 15.0, ang, 14)
			shape(lobe, shade(FLAP, 0.85 + 0.2 * (stroke * 0.5 + 0.5)), 2.0)
			draw_line(root, root + (tip - root) * 0.85, shade(FLAP, 0.65), 1.5, true)

	# Trunk: segmented body tapering to the tail
	var spine := []
	var widths := []
	for i in 13:
		var x = 30.0 - i * 22.0
		spine.append(bx(x, 0))
		widths.append(body_w(x))
	tube_shaded(spine, widths, BODY)
	for i in range(1, 12):
		var p: Vector2 = spine[i]
		draw_line(p + Vector2(0, -widths[i] * 0.9), p + Vector2(4, 0) + Vector2(0, -0.0), shade(BODY, 0.6), 2.0, true)
		draw_line(p + Vector2(0, widths[i] * 0.9), p + Vector2(4, 0), shade(BODY, 0.6), 2.0, true)

	# Frontal appendages
	for side in [-1.0, 1.0]:
		draw_appendage(side)

	# Head: dorsal carapace plate between the eyes
	oval(Vector2(32, 0), 46, 34, 0.0, shade(BODY, 1.08))
	oval(Vector2(40, 0), 26, 16, 0.0, shade(BODY, 1.25), 2.0)

	# Stalked compound eyes, turning to follow you
	for side in [-1.0, 1.0]:
		var base = Vector2(26, side * 26)
		var eye = base + Vector2.RIGHT.rotated(side * 1.05 + eye_look * 0.5) * 34.0
		limb(PackedVector2Array([base, eye]), 7.0, shade(BODY, 0.9))
		oval(eye, 17, 13, side * 0.6 + eye_look * 0.4, Color(0.12, 0.1, 0.12))
		for f in 5:
			draw_circle(eye + Vector2(-6 + f * 3, -4 + (f % 2) * 6).rotated(side * 0.6), 1.8, Color(0.35, 0.6, 0.55, 0.8), true, -1.0, true)
		draw_circle(eye + Vector2(5, -5).rotated(eye_look), 3.5, Color(1, 1, 1, 0.85), true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

func body_w(x: float) -> float:
	# Widest just behind the head, narrowing to the tail
	var f = clamp((30.0 - x) / 270.0, 0.0, 1.0)
	return lerp(40.0, 14.0, pow(f, 1.3)) + 14.0 * sin(clamp(f * 4.0, 0.0, PI))

func draw_appendage(side: float):
	var p = Vector2(64, side * 13)
	var ang = side * (0.08 + spread * 0.75)
	var pts := PackedVector2Array([p])
	var spines := []
	for k in 13:
		var seg = 15.0 - k * 0.6
		# Curl bends each podomere toward the midline and under the head
		ang += -side * curl * 0.24 + side * spread * 0.02
		p += Vector2.RIGHT.rotated(ang) * seg
		pts.append(p)
		spines.append([p, ang])
	limb(pts, 10.0, LIMB)
	for i in pts.size() - 1:
		var w = 10.0 - i * 0.55
		draw_circle(pts[i], w * 0.32, shade(LIMB, 0.7), true, -1.0, true)
	# Paired inner spines on each podomere
	for s in spines:
		var sp: Vector2 = s[0]
		var a: float = s[1]
		var inward = Vector2.RIGHT.rotated(a - side * PI * 0.5)
		var tip = sp + inward.rotated(side * 0.5) * 13.0
		draw_line(sp, tip, OUTLINE, 4.0, true)
		draw_line(sp, tip, SPINE, 2.0, true)
