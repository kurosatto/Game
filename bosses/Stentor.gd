# Stentor.gd — floor 1 (Ediacaran) boss
# Stentor is a giant trumpet-shaped ciliate, a single cell up to 2 mm long
# that hunts other cells. It anchors by its foot, beats a spiral band of
# fused cilia (membranelles) round its mouth to pull prey into a vortex,
# and can snap its body short in milliseconds with contractile myonemes,
# one of the fastest movements any cell makes. It can also let go and swim.
# Attacks: feeding vortex that pulls you to the mouth, a body-length strike,
# a contraction that ends in a pressure wave, and (phase 2) swimming off to
# a new anchor and egesting undigested food from its cytoproct.
extends "res://bosses/BossBase.gd"

const BODY = Color(0.27, 0.62, 0.78)    # Stentor coeruleus: blue stentorin pigment
const STRIPE = Color(0.55, 0.88, 0.95)
const CILIA = Color(0.8, 1.0, 1.0)

var anchor: Vector2
var body_len: float = 250.0
var target_len: float = 250.0
var crown_r: float = 92.0
var contraction: float = 0.0
var contract_goal: float = 0.0
var beat: float = 6.0          # cilia beat speed
var roll: float = 0.0          # body rotation while swimming
var recent_damage: float = 0.0
var strike_target: Vector2
var swim_target: Vector2
var cycles: int = 0
var vortex_on: bool = false

func setup():
	boss_title = "STENTOR — GIANT TRUMPET CILIATE"
	boss_fact = "One huge cell. Its ring of beating cilia makes a whirlpool that pulls prey into its mouth, and it can snap its body short faster than almost any other cell."
	max_health = 100.0
	damage = 1
	light.color = Color(0.25, 0.55, 1.0)
	light.energy = 1.5

func _ready():
	super._ready()
	anchor = global_position + Vector2(0, 230)
	facing = Vector2.UP
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 70.0

func damage_taken_mult() -> float:
	# Contracted into a tight ball, the pellicle shrugs off much of the hit
	return 0.4 if state == "contract" else 1.0

func take_damage(amount: float):
	recent_damage += amount * damage_taken_mult()
	super.take_damage(amount)

func on_phase2():
	super.on_phase2()
	start_contract()

func start_contract():
	set_state("contract")
	contract_goal = 1.0
	SoundManager.play_sfx("dash", 0.6)

func think(delta: float):
	recent_damage = max(0.0, recent_damage - max_health * 0.06 * delta)
	var to_p = player.global_position - anchor
	var spd = 1.3 if phase2 else 1.0
	beat = 6.0
	vortex_on = false

	match state:
		"intro", "feed":
			# Sway the crown toward the player on its flexible stalk
			target_len = 250.0
			turn_toward(to_p.normalized().rotated(sin(t * 1.4) * 0.35), 2.0, delta)
			if recent_damage > max_health * 0.12:
				start_contract()
			elif state_time > (1.0 if state == "intro" else 2.2 / spd):
				cycles += 1
				if phase2 and cycles % 3 == 0:
					set_state("detach")
					swim_target = pick_new_anchor()
					SoundManager.play_sfx("boss_roar", 1.2)
				elif to_p.length() < 560.0 and randf() < 0.55:
					set_state("strike_wind")
					SoundManager.play_sfx("boss_roar", 1.3)
				else:
					set_state("vortex")
			elif phase2 and state == "feed" and fmod(state_time, 1.1) < delta:
				egest()
		"vortex":
			# Membranelles beat hard and the whirlpool drags the player in
			beat = 22.0
			vortex_on = state_time > 0.5
			target_len = 270.0
			turn_toward(to_p.normalized(), 3.0, delta)
			if vortex_on:
				var to_mouth = mouth_pos() - player.global_position
				var d = to_mouth.length()
				if d > 1.0:
					var pull = (170.0 if phase2 else 130.0) * clamp(1.1 - d / 760.0, 0.0, 1.0)
					player.move_and_collide(to_mouth / d * pull * delta)
				hurt_circle(mouth_pos(), 46.0)
			if recent_damage > max_health * 0.12:
				start_contract()
			elif state_time > 3.2:
				set_state("feed")
		"strike_wind":
			# Draws the crown back, then telegraphs the line it will strike along
			target_len = 170.0
			turn_toward(to_p.normalized(), 6.0, delta)
			strike_target = anchor + facing * min(to_p.length() + 40.0, 600.0)
			if state_time > 0.65 / spd:
				set_state("strike")
		"strike":
			target_len = anchor.distance_to(strike_target)
			body_len = move_toward(body_len, target_len, 2600.0 * delta)
			hurt_circle(global_position, crown_r * 0.7, 1)
			if state_time > 0.45:
				shake(6.0)
				set_state("strike_back")
		"strike_back":
			target_len = 250.0
			if state_time > 0.6:
				set_state("feed")
		"contract":
			# Myonemes fire: a near-instant snap into a ball, then a slow
			# re-extension that pushes a pressure wave out through the water
			if state_time > 1.0:
				contract_goal = 0.0
				set_state("extend")
				spawn_hazard("ring", global_position, {"speed": 420.0, "max_r": 640.0, "width": 34.0, "dmg": 1, "color": Color(0.5, 0.85, 1.0)})
				shake(8.0)
				SoundManager.play_sfx("explosion", 1.3)
				recent_damage = 0.0
		"extend":
			if state_time > 0.7:
				set_state("feed")
		"detach":
			# Let go of the anchor and swim, spiralling about its long axis
			target_len = 210.0
			roll += delta * 6.0
			var to_t = swim_target - global_position
			turn_toward(to_t.normalized(), 3.0, delta)
			var step = facing * 330.0 * spd * delta
			anchor += step
			hurt_circle(global_position, crown_r * 0.6, 1)
			if to_t.length() < 40.0 or state_time > 4.0:
				set_state("feed")

	contraction = move_toward(contraction, contract_goal, delta * (14.0 if contract_goal > contraction else 1.6))
	if state != "strike":
		body_len = move_toward(body_len, target_len, 500.0 * delta)
	anchor = clamp_arena(anchor, 20.0)
	var len_now = lerp(body_len, 60.0, contraction)
	global_position = anchor + facing * len_now
	update_hits(len_now)

func pick_new_anchor() -> Vector2:
	for i in 10:
		var p = Vector2(randf_range(ARENA.position.x + 120, ARENA.end.x - 120), randf_range(ARENA.position.y + 120, ARENA.end.y - 120))
		if p.distance_to(anchor) > 420.0 and p.distance_to(player.global_position) > 260.0:
			return p
	return ARENA.get_center()

func mouth_pos() -> Vector2:
	return global_position + facing * 6.0

func egest():
	# Undigested remains leave through the cytoproct near the crown
	var d = (player.global_position - global_position).normalized()
	for k in [-0.25, 0.0, 0.25]:
		shoot(global_position - facing * 40.0, d.rotated(k), 300.0, Color(0.85, 0.75, 0.45))
	SoundManager.play_sfx("shoot", 0.6, -3.0)

func update_hits(len_now: float):
	var pts := []
	var radii := []
	for f in [0.35, 0.65]:
		pts.append(anchor + facing * len_now * f)
		radii.append(lerp(14.0, crown_r * 0.6, f) * (1.0 + contraction))
	set_hit_circles(pts, radii)

func spine_points(len_now: float) -> Array:
	var a = to_local(anchor)
	var c = Vector2.ZERO
	var perp = Vector2(-facing.y, facing.x)
	var ctrl = a + facing * len_now * 0.5 + perp * sin(t * 1.3) * 28.0 * (1.0 - contraction)
	var pts := []
	for i in 13:
		var f = i / 12.0
		pts.append(a.lerp(ctrl, f).lerp(ctrl.lerp(c, f), f))
	return pts

func draw_body():
	var len_now = lerp(body_len, 60.0, contraction)
	var spine = spine_points(len_now)
	var perp = Vector2(-facing.y, facing.x)
	var cr = lerp(crown_r, 62.0, contraction)

	# Telegraphs
	if state == "strike_wind":
		warn_line(Vector2.ZERO, to_local(strike_target), 44.0)
		warn_circle(to_local(strike_target), crown_r * 0.7)

	# Vortex: food particles spiralling into the mouth
	if state == "vortex":
		var mouth = to_local(mouth_pos())
		var strength = clamp(state_time / 0.5, 0.0, 1.0)
		for i in 30:
			var p = fmod(t * 0.7 + i / 30.0, 1.0)
			var r = (1.0 - p) * 420.0 + 16.0
			var a = i * 2.39 + p * 5.0
			var pos = mouth + Vector2.RIGHT.rotated(a) * r
			draw_circle(pos, 3.0 + p * 4.0, Color(0.8, 1.0, 1.0, 0.8 * p * strength), true, -1.0, true)
		for k in 3:
			draw_arc(mouth, 120.0 + k * 110.0, t * 3.0 + k, t * 3.0 + k + 2.2, 24, Color(0.75, 1.0, 1.0, 0.35 * strength), 5.0)

	# Shadow and holdfast
	shadow(spine[0] + Vector2(0, 10), 34, 14)
	if state != "detach":
		for k in 5:
			var ang = PI * 0.5 + (k - 2) * 0.45
			draw_line(spine[0], spine[0] + Vector2.RIGHT.rotated(ang) * 22.0, shade(BODY, 0.6), 3.0, true)

	# Trumpet-shaped body: thin foot widening to the crown; a contracted
	# Stentor is almost a ball
	var widths := []
	for i in spine.size():
		var f = i / float(spine.size() - 1)
		var w = lerp(8.0, cr * 0.72, pow(f, 1.7))
		w = lerp(w, sin(PI * min(f * 0.9 + 0.1, 1.0)) * cr * 0.95 + 10.0, contraction)
		widths.append(w)
	tube_shaded(spine, widths, BODY)

	# Longitudinal stripes of pigment granules; they slide sideways as it rolls
	for s in 6:
		var k = fmod(s / 6.0 + roll * 0.05, 1.0) * 2.0 - 1.0
		if abs(k) > 0.85:
			continue
		var line := PackedVector2Array()
		for i in spine.size():
			var a: Vector2 = spine[max(i - 1, 0)]
			var b: Vector2 = spine[min(i + 1, spine.size() - 1)]
			var tn = (b - a).normalized()
			line.append(spine[i] + Vector2(-tn.y, tn.x) * widths[i] * k)
		draw_polyline(line, Color(STRIPE.r, STRIPE.g, STRIPE.b, 0.55 * (1.0 - abs(k))), 2.0)

	# Moniliform macronucleus: a chain of beads down the body
	for i in 7:
		var f = 0.25 + i * 0.08
		var idx = f * (spine.size() - 1)
		var p: Vector2 = spine[int(idx)].lerp(spine[min(int(idx) + 1, spine.size() - 1)], idx - int(idx))
		p += perp * sin(i * 1.7) * widths[int(idx)] * 0.3
		draw_circle(p, 7.0 + contraction * 3.0, OUTLINE, true, -1.0, true)
		draw_circle(p, 5.0 + contraction * 3.0, Color(0.95, 0.75, 0.95), true, -1.0, true)

	# Contractile vacuole fills and empties
	var vac = spine[int(spine.size() * 0.7)] - perp * widths[int(spine.size() * 0.7)] * 0.4
	draw_circle(vac, 6.0 + 6.0 * abs(sin(t * 1.6)), Color(0.85, 1.0, 1.0, 0.6), true, -1.0, true)

	# Crown (peristome) seen at an angle, with the oral groove spiralling in
	var u = perp
	var v = facing
	var rim := PackedVector2Array()
	for i in 36:
		var a = TAU * i / 36.0
		rim.append(u * cos(a) * cr + v * sin(a) * cr * 0.42)
	shape(rim, shade(BODY, 1.25))
	var groove := PackedVector2Array()
	for i in 20:
		var f = i / 19.0
		var a = f * PI * 1.6
		var r = cr * (0.92 - f * 0.65)
		groove.append(u * cos(a) * r + v * sin(a) * r * 0.42)
	draw_polyline(groove, shade(BODY, 0.7), 3.0)
	var mouth_l = groove[groove.size() - 1]
	draw_circle(mouth_l, 9.0, OUTLINE, true, -1.0, true)
	draw_circle(mouth_l, 6.0, Color(0.15, 0.25, 0.35), true, -1.0, true)

	# Membranellar band: cilia beating in a metachronal wave round the rim
	for i in 40:
		var a = TAU * i / 40.0
		var base = u * cos(a) * cr + v * sin(a) * cr * 0.42
		var out = (u * cos(a) + v * sin(a) * 0.6).normalized()
		var swing = sin(t * beat - i * 0.6) * 0.7
		var tip = base + out.rotated(swing) * (22.0 if beat > 10.0 else 16.0)
		draw_line(base, tip, Color(CILIA.r, CILIA.g, CILIA.b, 0.9), 2.5, true)
