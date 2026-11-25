# Edestus.gd — floor 4 boss in the sea world (Carboniferous seas)
# Edestus was a eugeneodont up to about 6 m long. It is known almost only
# from its teeth: in each jaw one curved row of big serrated teeth that kept
# growing and stuck far out of the mouth, the old worn ones not shed but
# carried forward, so the two rows met like the blades of a pair of shears.
# How it used them is argued; a favoured idea is that it lunged and snapped
# the jaws shut on a fish, or swept the head up and down to slice through a
# school.
# Attacks: shear lunge (jaws open, dash, snap), a fast pass straight through
# you along a marked line, and a head thrash at close range. In phase 2 the
# shear lunges come in threes.
extends "res://bosses/Eugeneodont.gd"

var lunges_left: int = 0
var passes_left: int = 0
var aim: Vector2 = Vector2.DOWN
var snap: float = 0.0          # flash when the shears close

func setup():
	boss_title = "EDESTUS — CARBONIFEROUS SHEAR-TOOTH"
	boss_fact = "A 6 m eugeneodont, kin to ratfish, whose teeth grew in curved rows that jutted from both jaws like a pair of shears. It may have lunged and snapped them shut on its prey."
	max_health = 280.0
	damage = 1
	BODY = Color(0.34, 0.4, 0.47)
	BELLY = Color(0.84, 0.84, 0.8)
	LENGTH = 440.0
	GIRTH = 48.0
	light.color = Color(0.7, 0.95, 1.0)
	light.energy = 1.4
	light.scale = Vector2(4.0, 4.0)

func think(delta: float):
	tick_swim(delta)
	snap = move_toward(snap, 0.0, delta * 3.0)
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.3 if phase2 else 1.0
	match state:
		"intro", "cruise":
			# Circles at a distance with slow sweeps of the tail
			swim_rate = 6.0
			swim_amp = 1.0
			gape = move_toward(gape, 0.1, delta)
			var radial = to_p.normalized() * clamp((d - 400.0) / 200.0, -1.0, 1.0)
			var tangent = Vector2(-to_p.y, to_p.x).normalized() * orbit_dir
			var want = (radial + tangent).normalized() * 260.0 * spd
			vel = vel.move_toward(want, 500.0 * delta)
			if move_by(vel * delta, 80.0):
				orbit_dir = -orbit_dir
			steer(vel, 3.5, delta)
			if state_time > (1.2 if state == "intro" else randf_range(1.6, 2.3) / spd):
				if d < 300.0:
					set_state("thrash_wind")
				elif randf() < 0.55:
					lunges_left = 3 if phase2 else 1
					set_state("shear_wind")
				else:
					passes_left = 3 if phase2 else 2
					set_state("pass_wind")
				SoundManager.play_sfx("boss_roar", 0.7)
		"shear_wind":
			# Turns on you with the shears flung open
			vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
			move_by(vel * delta, 80.0)
			steer(to_p, 5.0, delta)
			gape = move_toward(gape, 1.0, delta * 2.5)
			swim_rate = 14.0
			aim = facing
			if state_time > (0.75 if lunges_left > 1 or not phase2 else 0.5) / spd:
				set_state("shear")
				did_hit = false
				vel = facing * 980.0
				SoundManager.play_sfx("dash", 0.6)
		"shear":
			move_by(vel * delta, 80.0)
			if not did_hit and hurt_circle(head_pos(40.0), 64.0):
				did_hit = true
				shake(8.0)
			if state_time > 0.42:
				# The shears slam shut
				gape = 0.0
				snap = 1.0
				SoundManager.play_sfx("explosion", 1.8, -6.0)
				if not did_hit and hurt_circle(head_pos(40.0), 80.0):
					did_hit = true
				vel = vel * 0.2
				lunges_left -= 1
				if lunges_left > 0:
					set_state("shear_wind")
				else:
					set_state("recover")
		"pass_wind":
			# Swings wide, lines up on you and marks its path
			vel = vel.move_toward(-to_p.normalized() * 160.0, 500.0 * delta)
			move_by(vel * delta, 80.0)
			steer(to_p, 4.0, delta)
			aim = facing
			swim_rate = 12.0
			if state_time > 0.9 / spd:
				set_state("pass")
				did_hit = false
				vel = aim * 1150.0
				SoundManager.play_sfx("dash", 0.5)
		"pass":
			swim_rate = 18.0
			swim_amp = 1.4
			gape = move_toward(gape, 0.6, delta * 4.0)
			if not did_hit:
				for k in [0.0, 0.2]:
					if hurt_circle(global_position + facing * LENGTH * (0.28 - k), 52.0):
						did_hit = true
						push_player(facing.orthogonal() * signf(facing.orthogonal().dot(to_p)) * 700.0)
						break
			var hit_wall = move_by(vel * delta, 80.0)
			if hit_wall or state_time > 1.3:
				passes_left -= 1
				vel = Vector2.ZERO
				swim_amp = 1.0
				if passes_left > 0:
					set_state("pass_wind")
				else:
					set_state("recover")
		"thrash_wind":
			steer(to_p, 6.0, delta)
			gape = move_toward(gape, 0.8, delta * 3.0)
			vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
			move_by(vel * delta, 80.0)
			if state_time > 0.6 / spd:
				set_state("thrash")
				did_hit = false
		"thrash":
			# Shakes the head from side to side, shears scything
			bend = sin(state_time * 22.0) * 0.6
			gape = 0.5 + 0.5 * sin(state_time * 22.0)
			var tip = head_pos(60.0) + facing.orthogonal() * sin(state_time * 22.0) * 70.0
			if not did_hit and hurt_circle(tip, 70.0):
				did_hit = true
				push_player(dir_to_player() * 650.0)
				shake(6.0)
			if state_time > 0.9:
				set_state("recover")
		"recover":
			vel = vel.move_toward(Vector2.ZERO, 500.0 * delta)
			move_by(vel * delta, 80.0)
			gape = move_toward(gape, 0.1, delta * 2.0)
			swim_rate = 5.0
			if state_time > 0.8 / spd:
				set_state("cruise")
	body_hit_circles()

func draw_body():
	if state == "shear_wind":
		warn_line(Vector2.ZERO, aim * 520.0, 120.0)
	if state == "pass_wind":
		warn_line(Vector2.ZERO, aim * 1700.0, 100.0)
	if state == "thrash_wind":
		warn_sector(Vector2.ZERO, LENGTH * 0.28 + 150.0, facing.angle(), 0.9)
	draw_shark()

func draw_teeth(snout: Vector2):
	# Upper and lower tooth rows jutting out ahead of the mouth, curving
	# toward each other; they part as the mouth gapes and cross like the
	# blades of shears when it snaps shut
	var open = gape * 34.0
	for s in [-1.0, 1.0]:
		var path := PackedVector2Array()
		for i in 9:
			var u = i / 8.0
			path.append(snout + Vector2(-20.0 + u * 96.0, s * (12.0 + open * (0.3 + u)) - s * sin(u * PI * 0.9) * 24.0 * (1.0 - gape * 0.5)))
		tooth_row(path, 9, 16.0, -s)
	if snap > 0.0:
		for k in 6:
			var a = TAU * k / 6.0
			pen.draw_line(snout + Vector2(36, 0) + Vector2.from_angle(a) * 16.0, snout + Vector2(36, 0) + Vector2.from_angle(a) * (16.0 + 30.0 * snap), Color(1, 1, 1, snap), 3.0, true)
