# Campylocephalus.gd — the Great Dying's last boss at sea (data/Endgame.gd)
# Campylocephalus was a hibbertopterid eurypterid, a "sea scorpion" with a
# broad, rounded head shield and a heavy body. Hibbertopterids were sweep-
# feeders: their front legs carried rows of long spines that raked through
# the mud, combing out small animals. Campylocephalus permianus, from the
# Late Permian of Russia, is the last eurypterid known: the whole group,
# some 200 million years old, ended in the Great Dying.
# Attacks: a rake of the spined front legs that combs you in toward it, a
# cloud of silt kicked up in rings, and a jab of the spiked tail at anything
# behind it. In phase 2 it moults like every arthropod: it crawls out of
# its old shell, which stays lying in the mud, and is soft and fast for a
# while (soft, it takes more damage) until the new shell hardens.
extends "res://bosses/BossBase.gd"

const SHELL = Color(0.5, 0.42, 0.34)
const SHELL_DARK = Color(0.33, 0.27, 0.22)
const SOFT = Color(0.78, 0.68, 0.58)
const SPINE = Color(0.95, 0.9, 0.78)
const EYE = Color(0.15, 0.1, 0.08)
const SOFT_TIME := 8.0

var gait: float = 0.0
var walk: float = 0.0
var rake: float = 0.0          # front legs: 0 held forward .. 1 swept in
var tail_aim: float = 0.0      # telson swing
var did_hit: bool = false
var soft_time: float = 0.0     # after the moult: soft and fast
var moulting: float = 0.0      # 0..1 crawling out of the old shell
var exuvia_pos: Vector2 = Vector2.ZERO
var exuvia_rot: float = 0.0
var has_exuvia: bool = false
var lurch_dir: Vector2 = Vector2.DOWN

func setup():
	boss_title = "CAMPYLOCEPHALUS — THE LAST SEA SCORPION"
	boss_fact = "A sweep-feeding sea scorpion that combed the mud with spined legs. The last eurypterid known: the whole group, 200 million years old, ended in the Great Dying."
	max_health = 540.0
	damage = 1
	speed = 120.0
	light.color = Color(0.75, 0.95, 0.75)
	light.energy = 1.3
	light.scale = Vector2(4.4, 4.4)

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 70.0

func killer_name() -> String:
	return "Campylocephalus"

func burst_color() -> Color:
	return SHELL

func damage_taken_mult() -> float:
	if moulting > 0.0 and moulting < 1.0:
		return 0.3 # half out of the old shell, still covered
	return 1.6 if soft_time > 0.0 else 1.0

# Megarachne (bosses/Megarachne.gd) reuses this body and doesn't moult
var moults: bool = true

func on_phase2():
	super.on_phase2()
	if moults:
		set_state("moult")

func think(delta: float):
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.5 if soft_time > 0.0 else (1.1 if phase2 else 1.0)
	soft_time = max(0.0, soft_time - delta)
	rake = move_toward(rake, 0.0, delta * 2.0)
	tail_aim = move_toward(tail_aim, 0.0, delta * 2.5)
	match state:
		"intro":
			walk = 0.0
			turn_toward(to_p, 1.5, delta)
			if state_time > 1.3:
				set_state("crawl")
		"crawl":
			walk = 1.0
			turn_toward(to_p, 1.6 * spd, delta)
			move_by(facing * speed * spd * delta, 110.0)
			var behind = abs(facing.angle_to(to_p)) > 2.1
			if state_time < 0.8 / spd:
				pass
			elif behind and d < 360.0:
				set_state("tail_wind")
			elif d < 360.0 and abs(facing.angle_to(to_p)) < 0.8:
				set_state("rake_wind")
				SoundManager.play_sfx("boss_roar", 0.5)
			elif state_time > 2.6 / spd:
				if phase2 and randf() < 0.45:
					set_state("lurch_wind")
				else:
					set_state("silt_wind")
		"rake_wind":
			# The spined front legs reach far out ahead, spread like a comb
			walk = 0.0
			turn_toward(to_p, 3.0, delta)
			rake = move_toward(rake, -0.6, delta * 2.0)
			if state_time > 0.75 / spd:
				set_state("rake")
				did_hit = false
				SoundManager.play_sfx("dash", 0.6)
		"rake":
			# ...and sweep in, combing whatever is in front toward the mouth
			rake = lerp(-0.6, 1.0, clamp(state_time / 0.3, 0.0, 1.0))
			var front = global_position + facing * 190.0
			if player.global_position.distance_to(front) < 230.0 and abs(facing.angle_to(to_p)) < 1.0:
				push_player(-to_p.normalized() * 380.0)
				if not did_hit and d < 250.0:
					did_hit = hurt_circle(global_position + facing * 130.0, 90.0)
			if state_time > 0.75:
				set_state("crawl")
		"silt_wind":
			walk = 0.3
			rake = move_toward(rake, 0.5, delta * 2.0)
			if state_time > 0.6 / spd:
				set_state("silt")
				shake(6.0)
				SoundManager.play_sfx("explosion", 0.5, -8.0)
				for i in (3 if phase2 else 2):
					var p = clamp_arena(player.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 140.0), 60.0)
					spawn_hazard("zone", p, {"delay": 0.9, "r": 95.0, "dmg": 1, "color": Color(0.62, 0.55, 0.42)})
				spawn_hazard("ring", global_position, {"speed": 380.0, "max_r": 380.0, "width": 34.0, "dmg": 1, "color": Color(0.6, 0.52, 0.4)})
		"silt":
			walk = 0.0
			if state_time > 0.9:
				set_state("crawl")
		"tail_wind":
			walk = 0.0
			var back = -facing
			tail_aim = move_toward(tail_aim, clamp(back.angle_to(to_p), -0.7, 0.7), delta * 3.0)
			if state_time > 0.55 / spd:
				set_state("tail")
				did_hit = false
				SoundManager.play_sfx("dash", 0.8)
		"tail":
			if not did_hit and state_time < 0.25:
				did_hit = hurt_circle(telson_tip(), 55.0)
			if state_time > 0.6:
				set_state("crawl")
		"lurch_wind":
			walk = 0.0
			turn_toward(to_p, 4.0, delta)
			lurch_dir = facing
			if state_time > 0.6:
				set_state("lurch")
				did_hit = false
				SoundManager.play_sfx("dash", 0.5)
		"lurch":
			# A heavy surge forward across the mud
			walk = 2.0
			if not did_hit:
				did_hit = hurt_circle(global_position + facing * 120.0, 85.0)
			if move_by(lurch_dir * 760.0 * delta, 110.0) or state_time > 0.7:
				shake(8.0)
				set_state("crawl")
		"moult":
			# The old shell splits at the front and it pulls itself out
			walk = 0.0
			if moulting <= 0.0:
				exuvia_pos = global_position
				exuvia_rot = facing.angle()
				has_exuvia = true
				SoundManager.play_sfx("boss_roar", 0.9)
			moulting = min(1.0, moulting + delta / 1.6)
			global_position = clamp_arena(exuvia_pos + facing * 130.0 * moulting, 110.0)
			if moulting >= 1.0:
				soft_time = SOFT_TIME
				set_state("crawl")
	gait += delta * walk * 4.5 * spd
	set_hit_circles([global_position + facing * 70.0, global_position - facing * 60.0, global_position - facing * 150.0], [70.0, 54.0, 30.0])

func telson_tip() -> Vector2:
	return global_position + (-facing).rotated(tail_aim) * 330.0

func shell_col() -> Color:
	if soft_time > 0.0:
		return SOFT.lerp(SHELL, 1.0 - soft_time / SOFT_TIME)
	return SHELL

func draw_body():
	if state == "rake_wind":
		warn_sector(Vector2.ZERO, 330.0, facing.angle(), 0.95)
	if state == "tail_wind":
		warn_circle(to_local(telson_tip()), 60.0)
	if state == "lurch_wind":
		warn_line(facing * 90.0, facing * 620.0, 170.0)
	if has_exuvia:
		# The cast-off shell stays in the mud, split open at the front
		pen_xf(to_local(exuvia_pos), exuvia_rot, Vector2.ONE)
		draw_animal(Color(SHELL_DARK, 0.55), 0.0, true)
	pen_xf(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	shadow(Vector2(-30, 14), 210, 110)
	draw_animal(shell_col(), walk, false)
	pen_xf(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

# Forward is +x. empty: the cast-off moult, no legs moving, split shield
func draw_animal(col: Color, w: float, empty: bool):
	var ph = gait if not empty else 0.0
	# Walking legs (the back two pairs), out to the sides, stepping in turn
	for k in 2:
		var x = 30.0 - k * 42.0
		for side in [-1.0, 1.0]:
			var p = ph + k * PI * 0.6 + (0.0 if side > 0 else PI)
			var hip = Vector2(x, side * 70.0)
			var knee = hip + Vector2(-10.0 + sin(p) * 14.0 * w, side * 52.0)
			var foot = knee + Vector2(-34.0 + sin(p) * 22.0 * w, side * 38.0)
			limb(PackedVector2Array([hip, knee, foot]), 10.0, shade(col, 0.8))
	# Front legs: long, forward-reaching, lined with comb spines
	for k in 3:
		for side in [-1.0, 1.0]:
			var base = Vector2(80.0 - k * 10.0, side * (34.0 + k * 12.0))
			var sweep = (rake if not empty else 0.0)
			var ang = side * (0.35 + k * 0.28 - sweep * 0.45) + sin(ph + k) * 0.05 * w
			var mid = base + Vector2.from_angle(ang) * (90.0 - k * 10.0)
			var tip = mid + Vector2.from_angle(ang - side * (0.25 + sweep * 0.3)) * (80.0 - k * 12.0)
			limb(PackedVector2Array([base, mid, tip]), 8.0, shade(col, 0.9))
			# The spines that rake the mud
			for s in 5:
				var f = (s + 1) / 6.0
				var sp = mid.lerp(tip, f)
				var out = (tip - mid).normalized().rotated(side * -1.3) * (16.0 - s * 1.5)
				pen_line(sp, sp + out, OUTLINE, 3.5, true)
				pen_line(sp, sp + out, Color(SPINE, col.a), 1.8, true)
	# Body: twelve segments, broad then narrowing to the spiked tail
	var segs := 12
	for i in segs:
		var j = segs - 1 - i # back to front so the front plates overlap
		# A broad, rounded preabdomen (7 plates), then a narrow tail section
		var x = -10.0 - j * 19.0
		var half = [96.0, 108.0, 112.0, 108.0, 98.0, 82.0, 62.0][j] if j < 7 else 36.0 - (j - 7) * 4.0
		var plate := PackedVector2Array()
		for p in [Vector2(x + 8, -half), Vector2(x + 12, -half * 0.5), Vector2(x + 12, half * 0.5), Vector2(x + 8, half), Vector2(x - 10, half * 0.92), Vector2(x - 12, 0), Vector2(x - 10, -half * 0.92)]:
			plate.append(p)
		shape(plate, shade(col, 1.0 - 0.03 * (j % 2)), 2.5)
		if not empty and j < 7:
			# A row of small tubercles across each broad plate
			for k in range(-2, 3):
				pen_circle(Vector2(x, k * half * 0.3), 2.0, Color(SHELL_DARK, 0.45 * col.a), true, -1.0, true)
	# The spiked telson
	var tbase = Vector2(-10.0 - segs * 19.0, 0)
	var tdir = Vector2.LEFT.rotated(tail_aim if not empty else 0.0)
	var tip = tbase + tdir * 100.0
	var side_v = tdir.orthogonal() * 12.0
	shape(PackedVector2Array([tbase + side_v, tip, tbase - side_v]), shade(col, 0.85), 2.5)
	# The broad, rounded head shield (prosoma)
	var shield := PackedVector2Array()
	for i in 25:
		var a = -PI * 0.5 + PI * i / 24.0
		shield.append(Vector2(10.0 + cos(a) * 95.0, sin(a) * 92.0))
	shield.append(Vector2(-6, 86))
	shield.append(Vector2(-6, -86))
	if empty:
		# Split along the front edge where the animal crawled out
		var a_side := PackedVector2Array()
		var b_side := PackedVector2Array()
		for p in shield:
			if p.y < 0:
				a_side.append(p + Vector2(0, -8))
			else:
				b_side.append(p + Vector2(0, 8))
		if a_side.size() >= 3:
			shape(a_side, col, 2.5)
		if b_side.size() >= 3:
			shape(b_side, col, 2.5)
		return
	shape(shield, shade(col, 1.06), 3.5)
	# A raised rim and a scatter of tubercles over the shield
	var rim := PackedVector2Array()
	for i in 21:
		var a = -PI * 0.45 + PI * 0.9 * i / 20.0
		rim.append(Vector2(10.0 + cos(a) * 82.0, sin(a) * 80.0))
	pen_polyline(rim, Color(SHELL_DARK, 0.5), 1.6, true)
	var rng = RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var p = Vector2(rng.randf_range(-4, 85), rng.randf_range(-70, 70))
		if (p - Vector2(10, 0)).length() < 78.0:
			pen_circle(p, rng.randf_range(1.5, 3.0), Color(SHELL_DARK, 0.55), true, -1.0, true)
	# Small compound eyes close together near the middle, as on
	# hibbertopterids
	for side in [-1.0, 1.0]:
		var e = Vector2(30, side * 13)
		pen_polygon(ellipse_pts(e, 7.0, 4.0, 0.0, 10), EYE)
	if soft_time > 0.0:
		# Fresh soft cuticle, still pale, glistens
		draw_arc(Vector2(10, 0), 88.0, -PI * 0.4, PI * 0.4, 18, Color(1, 1, 1, 0.25 + 0.15 * sin(t * 5.0)), 3.0, true)
