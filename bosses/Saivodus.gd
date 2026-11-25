# Saivodus.gd — a secret lair boss at sea (data/Endgame.gd "lairs")
# Saivodus striatus was a ctenacanthiform shark of the early Carboniferous,
# about 330 million years ago, and one of the biggest sharks of its time:
# estimates put it at 6 to 9 m, the size of a great white. Its teeth have
# been found in the walls of Mammoth Cave in Kentucky, which formed in the
# limestone of that old sea floor. Ctenacanths had a stout spine in front of
# each of their two dorsal fins and "cladodont" teeth, each a tall middle
# cusp with smaller cusps either side, for gripping slippery prey.
# Shares the shark body drawing of the eugeneodonts (bosses/Eugeneodont.gd),
# with its fin spines and cusped teeth added.
# Attacks: a grabbing bite lunge, a fast circle that closes in on you, and a
# tail slap at anything behind. In phase 2 it goes into a feeding frenzy:
# three bites in a row with no rest between.
extends "res://bosses/Eugeneodont.gd"

var aim: Vector2 = Vector2.DOWN
var bites_left: int = 0
var circle_r: float = 420.0
var circle_ang: float = 0.0

func setup():
	boss_title = "SAIVODUS — GIANT OF THE MAMMOTH CAVE SEA"
	boss_fact = "A ctenacanth shark 6 to 9 m long, as big as a great white, 330 million years ago. Its teeth turn up in the walls of Mammoth Cave, Kentucky."
	max_health = 420.0
	damage = 1
	BODY = Color(0.4, 0.42, 0.44)
	BELLY = Color(0.86, 0.85, 0.8)
	LENGTH = 520.0
	GIRTH = 58.0
	light.color = Color(0.75, 0.9, 1.0)
	light.energy = 1.4
	light.scale = Vector2(4.6, 4.6)

func killer_name() -> String:
	return "Saivodus"

func think(delta: float):
	tick_swim(delta)
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.25 if phase2 else 1.0
	match state:
		"intro", "cruise":
			swim_rate = 6.0
			swim_amp = 1.0
			gape = move_toward(gape, 0.1, delta)
			var radial = to_p.normalized() * clamp((d - 430.0) / 200.0, -1.0, 1.0)
			var tangent = Vector2(-to_p.y, to_p.x).normalized() * orbit_dir
			vel = vel.move_toward((radial + tangent).normalized() * 250.0 * spd, 480.0 * delta)
			if move_by(vel * delta, 90.0):
				orbit_dir = -orbit_dir
			steer(vel, 3.2, delta)
			if state_time > (1.2 if state == "intro" else randf_range(1.5, 2.2) / spd):
				var behind = facing.dot(to_p.normalized()) < -0.3
				if behind and d < 420.0:
					set_state("tail_wind")
				elif randf() < 0.55:
					bites_left = 3 if phase2 else 1
					set_state("bite_wind")
				else:
					circle_r = clamp(d, 300.0, 520.0)
					circle_ang = (-to_p).angle()
					set_state("circle")
				SoundManager.play_sfx("boss_roar", 0.6)
		"bite_wind":
			vel = vel.move_toward(Vector2.ZERO, 700.0 * delta)
			move_by(vel * delta, 90.0)
			steer(to_p, 6.0, delta)
			gape = move_toward(gape, 1.0, delta * 3.0)
			swim_rate = 13.0
			aim = facing
			if state_time > (0.7 if bites_left == 3 or not phase2 else 0.35) / spd:
				set_state("bite")
				did_hit = false
				vel = aim * 1000.0
				SoundManager.play_sfx("dash", 0.55)
		"bite":
			move_by(vel * delta, 90.0)
			if not did_hit and hurt_circle(head_pos(40.0), 70.0, 2 if phase2 else 1):
				did_hit = true
				shake(9.0)
				push_player(aim * 450.0)
			if state_time > 0.4:
				gape = 0.0
				SoundManager.play_sfx("explosion", 1.6, -8.0)
				vel *= 0.2
				bites_left -= 1
				set_state("bite_wind" if bites_left > 0 else "recover")
		"circle":
			# A fast circle round you that tightens, then a turn inward
			swim_rate = 12.0
			circle_ang += delta * 2.4 * orbit_dir * spd
			circle_r = move_toward(circle_r, 200.0, delta * 120.0)
			var want = clamp_arena(player.global_position + Vector2.from_angle(circle_ang) * circle_r, 90.0)
			var go = want - global_position
			vel = vel.move_toward(go.normalized() * min(go.length() * 4.0, 620.0), 1600.0 * delta)
			move_by(vel * delta, 90.0)
			steer(vel, 5.0, delta)
			if state_time > 2.2:
				bites_left = 1
				set_state("bite_wind")
		"tail_wind":
			vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
			move_by(vel * delta, 90.0)
			bend = move_toward(bend, 0.6 * orbit_dir, delta * 3.0)
			if state_time > 0.5 / spd:
				set_state("tail")
				did_hit = false
				SoundManager.play_sfx("dash", 0.8)
		"tail":
			bend = lerp(0.6 * orbit_dir, -0.7 * orbit_dir, clamp(state_time / 0.2, 0.0, 1.0))
			swim_amp = 2.0
			if not did_hit:
				var pts = spine_pts()
				var tail = global_position + Vector2(pts[15]).rotated(facing.angle())
				if hurt_circle(tail, 80.0):
					did_hit = true
					push_player((player.global_position - global_position).normalized() * 600.0)
			if state_time > 0.5:
				swim_amp = 1.0
				set_state("recover")
		"recover":
			vel = vel.move_toward(Vector2.ZERO, 500.0 * delta)
			move_by(vel * delta, 90.0)
			gape = move_toward(gape, 0.1, delta * 2.0)
			swim_rate = 5.0
			if state_time > 0.7 / spd:
				set_state("cruise")
	body_hit_circles()

func draw_body():
	if state == "bite_wind":
		warn_line(Vector2.ZERO, aim * 560.0, 130.0)
	if state == "tail_wind":
		warn_circle(Vector2.ZERO - facing * LENGTH * 0.6, 110.0)
	draw_shark()
	# The two dorsal fin spines, raked back, in front of each dorsal fin
	pen_xf(Vector2.ZERO, facing.angle(), Vector2.ONE)
	var pts = spine_pts()
	for i in [5, 10]:
		var p: Vector2 = pts[i]
		var back = (Vector2(pts[i + 2]) - p).normalized()
		var spine = PackedVector2Array([p + back.orthogonal() * 5.0, p + back * 46.0, p - back.orthogonal() * 5.0])
		pen_polygon(spine, Color(0.92, 0.88, 0.76))
		spine.append(spine[0])
		pen_polyline(spine, OUTLINE, 2.0, true)
	pen_xf(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_teeth(snout: Vector2):
	# Cladodont teeth: a tall middle cusp with small ones either side, set
	# round the jaw; they show as the jaws part
	if gape < 0.15:
		return
	var open = gape * 30.0
	for s in [-1.0, 1.0]:
		for k in 6:
			var base = snout + Vector2(-34.0 + k * 9.0, s * (10.0 + open * 0.8 + k * 1.5))
			for c in [-1, 0, 1]:
				var h = 15.0 if c == 0 else 7.0
				var b = base + Vector2(c * 4.0, 0)
				var tooth = PackedVector2Array([b - Vector2(2.0, 0), b + Vector2(0, -s * h), b + Vector2(2.0, 0)])
				pen_polygon(tooth, TOOTH)
				tooth.append(tooth[0])
				pen_polyline(tooth, OUTLINE, 1.2, true)
