# Helicoprion.gd — floor 5 boss in the sea world (Permian seas)
# Helicoprion was a eugeneodont of the Early Permian, perhaps 5-8 m long,
# known for its tooth whorl: a spiral of over 100 teeth, the new ones
# growing at the outside and the old ones rolled into the middle. For a
# century nobody knew where it sat. CT scans of a fossil from Idaho (2013)
# showed that it filled the lower jaw, and as the mouth closed the whorl
# rolled back and sliced soft prey like squid and ammonoids against the
# palate, like a saw.
# Attacks: a saw lunge with the whorl spinning, a dive into the dark water
# that comes up under you, and a slap of the tall tail. In phase 2 it hunts
# you down for a while with the whorl spinning.
extends "res://bosses/Eugeneodont.gd"

var spin: float = 0.0          # whorl rotation
var spin_rate: float = 1.0
var aim: Vector2 = Vector2.DOWN
var depth: float = 0.0         # 1 when deep under (can't be hit)
var target: Vector2 = Vector2.ZERO
var hit_cool: float = 0.0

func setup():
	boss_title = "HELICOPRION — PERMIAN BUZZ-SAW JAW"
	boss_fact = "A eugeneodont with a spiral whorl of over 100 teeth in its lower jaw. Scans of a fossil from Idaho showed the whorl filled the jaw and sliced prey like a saw as the mouth shut."
	max_health = 420.0
	damage = 1
	BODY = Color(0.42, 0.37, 0.38)
	BELLY = Color(0.86, 0.84, 0.78)
	LENGTH = 470.0
	GIRTH = 50.0
	light.color = Color(1.0, 0.9, 0.7)
	light.energy = 1.4
	light.scale = Vector2(4.2, 4.2)

func damage_taken_mult() -> float:
	return 0.0 if depth > 0.6 else 1.0

func think(delta: float):
	tick_swim(delta)
	spin += delta * spin_rate
	hit_cool = max(0.0, hit_cool - delta)
	modulate.a = 1.0 - depth * 0.8
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.25 if phase2 else 1.0
	match state:
		"intro", "cruise":
			swim_rate = 5.5
			spin_rate = 1.0
			gape = move_toward(gape, 0.15, delta)
			depth = move_toward(depth, 0.0, delta * 2.0)
			var radial = to_p.normalized() * clamp((d - 420.0) / 200.0, -1.0, 1.0)
			var tangent = Vector2(-to_p.y, to_p.x).normalized() * orbit_dir
			vel = vel.move_toward((radial + tangent).normalized() * 230.0 * spd, 450.0 * delta)
			if move_by(vel * delta, 80.0):
				orbit_dir = -orbit_dir
			steer(vel, 3.0, delta)
			if state_time > (1.2 if state == "intro" else randf_range(1.6, 2.4) / spd):
				var behind = facing.dot(to_p.normalized()) < -0.3
				if behind and d < 420.0:
					set_state("tail_wind")
				elif phase2 and randf() < 0.35:
					set_state("hunt_wind")
				elif randf() < 0.55:
					set_state("saw_wind")
				else:
					set_state("dive_wind")
				SoundManager.play_sfx("boss_roar", 0.65)
		"saw_wind":
			# Jaw drops open and the whorl starts to roll
			vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
			move_by(vel * delta, 80.0)
			steer(to_p, 5.0, delta)
			gape = move_toward(gape, 1.0, delta * 2.5)
			spin_rate = move_toward(spin_rate, 18.0, delta * 30.0)
			aim = facing
			if state_time > 0.8 / spd:
				set_state("saw")
				did_hit = false
				vel = aim * 900.0
				SoundManager.play_sfx("dash", 0.55)
		"saw":
			spin_rate = 22.0
			move_by(vel * delta, 80.0)
			if not did_hit and hurt_circle(head_pos(50.0), 70.0, 2 if phase2 else 1):
				did_hit = true
				shake(9.0)
				push_player(aim * 500.0)
			if state_time > 0.55:
				gape = 0.0
				vel *= 0.2
				set_state("recover")
		"dive_wind":
			# Sinks into the dark water below the reef
			vel = vel.move_toward(Vector2.ZERO, 400.0 * delta)
			move_by(vel * delta, 80.0)
			depth = move_toward(depth, 1.0, delta * 1.4)
			swim_rate = 9.0
			if depth >= 1.0:
				set_state("deep")
		"deep":
			# Unseen and untouchable, it follows under you
			target = clamp_arena(player.global_position, 90.0)
			var go = (target - global_position)
			vel = vel.move_toward(go.normalized() * min(go.length() * 3.0, 380.0 * spd), 900.0 * delta)
			move_by(vel * delta, 80.0)
			steer(vel if vel.length() > 20.0 else facing, 4.0, delta)
			if state_time > 1.6:
				target = global_position
				spawn_hazard("zone", target, {"delay": 0.75 / spd, "r": 130.0, "dmg": 1, "color": Color(0.6, 0.75, 0.85)})
				set_state("breach_wind")
		"breach_wind":
			vel = Vector2.ZERO
			if state_time > 0.72 / spd:
				set_state("breach")
				shake(14.0)
				SoundManager.play_sfx("explosion", 0.9)
				spawn_hazard("ring", global_position, {"speed": 520.0, "max_r": 420.0, "width": 30.0, "dmg": 1, "color": Color(0.8, 0.9, 1.0)})
		"breach":
			depth = move_toward(depth, 0.0, delta * 5.0)
			gape = move_toward(gape, 0.0, delta * 3.0)
			if state_time > 0.5:
				set_state("recover")
		"tail_wind":
			vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
			move_by(vel * delta, 80.0)
			swim_amp = move_toward(swim_amp, 0.2, delta * 3.0)
			if state_time > 0.6 / spd:
				set_state("tail")
				did_hit = false
				SoundManager.play_sfx("dash", 0.4)
		"tail":
			# One huge sweep of the tall tail fin
			swim_amp = 2.6
			swim_rate = 16.0
			var tail = global_position - facing * LENGTH * 0.62
			if not did_hit and player.global_position.distance_to(tail) < 230.0 and drawing_touches_player():
				did_hit = true
				player.take_damage(1, killer_name())
				push_player((player.global_position - tail).normalized() * 900.0)
			if state_time > 0.5:
				swim_amp = 1.0
				set_state("recover")
		"hunt_wind":
			gape = move_toward(gape, 1.0, delta * 3.0)
			spin_rate = move_toward(spin_rate, 22.0, delta * 30.0)
			steer(to_p, 5.0, delta)
			if state_time > 0.7:
				set_state("hunt")
		"hunt":
			# Phase 2: chases you down, the whorl rolling
			spin_rate = 24.0
			swim_rate = 12.0
			vel = vel.move_toward(to_p.normalized() * 300.0, 700.0 * delta)
			move_by(vel * delta, 80.0)
			steer(to_p, 2.6, delta)
			if hit_cool <= 0.0 and hurt_circle(head_pos(50.0), 66.0):
				hit_cool = 0.9
				push_player(facing * 600.0)
				shake(7.0)
			if state_time > 2.4:
				gape = 0.2
				set_state("recover")
		"recover":
			vel = vel.move_toward(Vector2.ZERO, 500.0 * delta)
			move_by(vel * delta, 80.0)
			spin_rate = move_toward(spin_rate, 1.0, delta * 20.0)
			gape = move_toward(gape, 0.15, delta * 2.0)
			swim_rate = 5.0
			if state_time > 0.8 / spd:
				set_state("cruise")
	body_hit_circles()

func draw_body():
	if state == "saw_wind":
		warn_line(Vector2.ZERO, aim * 600.0, 130.0)
	if state == "tail_wind":
		warn_circle(-facing * LENGTH * 0.62, 230.0)
	if state == "deep" or state == "dive_wind":
		# Only a dark shape and a few bubbles mark where it is
		for i in 8:
			var p = fmod(t * 1.3 + i / 8.0, 1.0)
			pen.draw_circle(Vector2(sin(i * 2.4) * 60.0, cos(i * 1.7) * 40.0) - Vector2(0, p * 80.0), 3.0 + 4.0 * p, Color(0.85, 0.95, 1.0, 0.5 * (1.0 - p)), true, -1.0, true)
	draw_shark()

func draw_teeth(snout: Vector2):
	# The whorl: a spiral of teeth in the lower jaw, rolling as it bites.
	# It shows below the snout, more of it as the jaw drops.
	var c = snout + Vector2(-26 + gape * 18.0, 0)
	var r = 22.0 + gape * 12.0
	pen.draw_circle(c, r + 4.0, Shading.ink(BODY), true, -1.0, true)
	pen.draw_circle(c, r, BODY.lightened(0.25), true, -1.0, true)
	var spiral := PackedVector2Array()
	for i in 60:
		var a = i / 59.0 * TAU * 2.6
		spiral.append(c + Vector2.from_angle(a + spin) * r * (1.0 - a / (TAU * 3.0)))
	pen.draw_polyline(spiral, Color(Shading.ink(BODY), 0.7), 2.0, true)
	# Outer ring of teeth, the biggest and newest
	var n = 14
	for i in n:
		var a = TAU * i / n + spin
		var dir = Vector2.from_angle(a)
		var side = dir.orthogonal()
		var base = c + dir * r
		var tooth = PackedVector2Array([base - side * 5.0, base + dir * 12.0 + side * 2.0, base + side * 5.0])
		pen.draw_colored_polygon(tooth, TOOTH)
		tooth.append(tooth[0])
		pen.draw_polyline(tooth, OUTLINE, 1.3, true)
	# Inner, older teeth rolled into the middle
	for i in 8:
		var a = TAU * i / 8.0 + spin * 1.0 + 0.3
		pen.draw_circle(c + Vector2.from_angle(a) * r * 0.5, 3.0, TOOTH.darkened(0.15), true, -1.0, true)
