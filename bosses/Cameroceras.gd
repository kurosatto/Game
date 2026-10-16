# Cameroceras.gd — floor 3 (Ordovician) boss
# Cameroceras was an endocerid, a nautiloid with a long straight cone-shaped
# shell (often said to reach several metres; the biggest estimates are
# uncertain). Like living Nautilus it swam by jet propulsion, squirting water
# from a movable funnel (the hyponome), so it shot backwards, shell first,
# and caught prey with a ring of tentacles round a beak. Nautiloids have no
# ink sac (ink came later, in squid and octopus relatives), so no ink here.
# Attacks: tentacle snare that reels you to the beak, a shell-first jet ram,
# and a funnel blast that pushes you away while it recoils the other way.
extends "res://bosses/BossBase.gd"

const SHELL = Color(0.86, 0.80, 0.66)
const BAND = Color(0.55, 0.32, 0.24)
const FLESH = Color(0.82, 0.55, 0.55)
const SHELL_LEN = 430.0
const TENTACLES = 10

var vel: Vector2 = Vector2.ZERO
var reach: float = 70.0        # tentacle length
var splay: float = 0.3         # how wide the tentacles fan
var grip: float = 0.0          # tentacle tips curling shut
var funnel_pulse: float = 0.0
var aim: Vector2 = Vector2.RIGHT
var rams_left: int = 0
var caught: bool = false
var did_hit: bool = false

func setup():
	boss_title = "CAMEROCERAS — ORDOVICIAN ORTHOCONE NAUTILOID"
	boss_fact = "A giant straight-shelled relative of Nautilus. It jetted backwards by squirting water from its funnel and snared prey with its tentacles. No ink: nautiloids never had it."
	max_health = 210.0
	damage = 1
	light.color = Color(0.6, 1.0, 0.85)
	light.energy = 1.4
	light.scale = Vector2(4.0, 4.0)

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 56.0

func burst_color() -> Color:
	return SHELL

func think(delta: float):
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.3 if phase2 else 1.0
	funnel_pulse = move_toward(funnel_pulse, 0.0, delta * 2.0)
	match state:
		"intro", "drift":
			# Hangs in the water, tentacles reaching about; keeps its distance
			# with gentle backward puffs from the funnel
			reach = move_toward(reach, 80.0 + 12.0 * sin(t * 2.0), 300.0 * delta)
			splay = move_toward(splay, 0.35, delta)
			grip = move_toward(grip, 0.0, delta * 2.0)
			turn_toward(to_p, 1.6, delta)
			var want = Vector2.ZERO
			if d < 330.0:
				want = -facing * 140.0
				funnel_pulse = max(funnel_pulse, 0.4)
			elif d > 560.0:
				want = facing * 90.0
			vel = vel.move_toward(want, 200.0 * delta)
			move_by(vel * delta, 70.0)
			if state_time > (1.0 if state == "intro" else 2.0 / spd):
				if d < 470.0:
					set_state("snare_wind")
				elif randf() < 0.5:
					rams_left = 2 if phase2 else 1
					set_state("ram_wind")
				else:
					set_state("blast_wind")
				SoundManager.play_sfx("boss_roar", 0.8)
		"snare_wind":
			turn_toward(to_p, 5.0, delta)
			splay = move_toward(splay, 1.0, delta * 2.5)
			reach = move_toward(reach, 110.0, 200.0 * delta)
			vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
			move_by(vel * delta, 70.0)
			if state_time > 0.7 / spd:
				set_state("snare")
				caught = false
				SoundManager.play_sfx("dash", 0.7)
		"snare":
			# Tentacles shoot out; a hit wraps them round you and reels you in
			splay = move_toward(splay, 0.15, delta * 4.0)
			reach = move_toward(reach, 430.0, 2200.0 * delta)
			if not caught and abs(facing.angle_to(to_p)) < 0.5 and d < reach + 70.0 and d > 40.0:
				caught = true
				did_hit = false
				set_state("reel")
			elif state_time > 0.5:
				set_state("retract")
		"reel":
			grip = move_toward(grip, 1.0, delta * 5.0)
			var beak = global_position + facing * 60.0
			var to_beak = beak - player.global_position
			reach = max(60.0, to_beak.length() + 40.0)
			if to_beak.length() > 30.0:
				player.move_and_collide(to_beak.normalized() * min(520.0 * delta, to_beak.length()))
			if not did_hit and to_beak.length() < 70.0:
				did_hit = true
				player.take_damage(2)
				shake(8.0)
			if did_hit or state_time > 0.9:
				push_player(dir_to_player() * 700.0)
				set_state("retract")
		"retract":
			reach = move_toward(reach, 80.0, 500.0 * delta)
			grip = move_toward(grip, 0.0, delta * 3.0)
			if state_time > 0.7:
				set_state("drift")
		"ram_wind":
			# Turns its shell point toward you and pressurises the mantle
			turn_toward(-to_p, 4.0 * spd, delta)
			funnel_pulse = 0.5 + 0.5 * sin(state_time * 20.0)
			reach = move_toward(reach, 50.0, 200.0 * delta)
			splay = move_toward(splay, 0.1, delta * 2.0)
			vel = vel.move_toward(Vector2.ZERO, 300.0 * delta)
			move_by(vel * delta, 70.0)
			if state_time > 0.9 / spd:
				set_state("ram")
				vel = -facing * 1050.0
				SoundManager.play_sfx("dash", 0.5)
		"ram":
			# Jet propulsion: water out the funnel, animal shoots shell-first
			funnel_pulse = 1.0
			for k in [0.3, 0.6, 0.9]:
				hurt_circle(global_position - facing * SHELL_LEN * k, 46.0 * (1.0 - k * 0.6))
			if move_by(vel * delta, 70.0) or state_time > 1.1:
				shake(14.0)
				SoundManager.play_sfx("explosion", 1.0)
				vel = Vector2.ZERO
				rams_left -= 1
				set_state("ram_wind" if rams_left > 0 else "drift")
		"blast_wind":
			# Aims the funnel at you
			turn_toward(to_p, 4.0, delta)
			aim = facing
			funnel_pulse = 0.4 + 0.4 * sin(state_time * 16.0)
			if state_time > 0.65 / spd:
				set_state("blast")
				did_hit = false
				SoundManager.play_sfx("explosion", 1.6, -4.0)
		"blast":
			# Water jet: shoves you across the room and pushes it back
			funnel_pulse = 1.0
			vel = -aim * 220.0
			move_by(vel * delta, 70.0)
			var rel = player.global_position - funnel_pos()
			var along = rel.dot(aim)
			var across = abs(rel.cross(aim))
			if along > 0.0 and along < 760.0 and across < 60.0:
				push_player(aim * 900.0)
				if not did_hit:
					did_hit = true
					player.take_damage(1)
			if state_time > 1.0:
				vel = Vector2.ZERO
				set_state("drift")
	var back = facing
	set_hit_circles([global_position - back * 120.0, global_position - back * 230.0, global_position - back * 340.0], [50.0, 38.0, 24.0])

func funnel_pos() -> Vector2:
	return global_position + facing * 48.0 + facing.rotated(PI * 0.5) * 40.0

func draw_body():
	if state == "snare_wind":
		warn_sector(Vector2.ZERO, 500.0, facing.angle(), 0.5)
	if state == "ram_wind":
		warn_line(-facing * SHELL_LEN, -facing * 1600.0, 100.0)
	if state == "blast_wind":
		warn_line(to_local(funnel_pos()), to_local(funnel_pos()) + aim * 760.0, 120.0)
	if state == "blast":
		# Bubbles streaming out along the jet
		var f0 = to_local(funnel_pos())
		for i in 28:
			var p = fmod(t * 2.2 + i / 28.0, 1.0)
			var pos = f0 + aim * p * 760.0 + aim.orthogonal() * sin(i * 3.1 + t * 9.0) * 30.0 * p
			draw_circle(pos, 4.0 + 7.0 * p, Color(0.85, 1.0, 1.0, 0.7 * (1.0 - p)), true, -1.0, true)
	if state == "ram":
		var f0 = to_local(funnel_pos())
		for i in 12:
			var p = fmod(t * 4.0 + i / 12.0, 1.0)
			draw_circle(f0 + facing * p * 180.0 + facing.orthogonal() * sin(i * 2.0) * 20.0 * p, 3.0 + 5.0 * p, Color(0.85, 1.0, 1.0, 0.6 * (1.0 - p)), true, -1.0, true)

	draw_set_transform(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	shadow(Vector2(-SHELL_LEN * 0.45, 12), SHELL_LEN * 0.55, 50)

	# Tentacles under the shell's front edge first
	for i in TENTACLES:
		draw_tentacle(i)

	# Head and the funnel tucked beneath it
	oval(Vector2(18, 0), 42, 40, 0.0, FLESH)
	var fun_a = Vector2(20, 34)
	var fun_b = Vector2(48 + funnel_pulse * 10.0, 40)
	limb(PackedVector2Array([fun_a, fun_b]), 12.0 + funnel_pulse * 4.0, shade(FLESH, 0.85))
	draw_circle(fun_b, 5.0, shade(FLESH, 0.5), true, -1.0, true)
	for side in [-1.0, 1.0]:
		var eye = Vector2(26, side * 24)
		draw_circle(eye, 9.0, OUTLINE, true, -1.0, true)
		draw_circle(eye, 7.0, Color(0.95, 0.9, 0.6), true, -1.0, true)
		draw_circle(eye + Vector2(2, 0), 3.5, Color(0.08, 0.08, 0.1), true, -1.0, true)

	# Long straight conical shell with growth lines and colour bands
	var spine := []
	var widths := []
	for i in 15:
		var f = i / 14.0
		spine.append(Vector2(-f * SHELL_LEN, 0))
		widths.append(lerp(50.0, 5.0, f))
	tube_shaded(spine, widths, SHELL)
	for i in 16:
		var f = (i + 0.5) / 16.0
		var x = -f * SHELL_LEN
		var w = lerp(50.0, 5.0, f)
		if i % 2 == 0:
			var band := PackedVector2Array([Vector2(x - 6, -w * 0.95), Vector2(x + 6, -w * 0.95), Vector2(x + 2, w * 0.95), Vector2(x - 10, w * 0.95)])
			draw_colored_polygon(band, Color(BAND.r, BAND.g, BAND.b, 0.55))
		draw_line(Vector2(x + 9, -w * 0.97), Vector2(x + 5, w * 0.97), shade(SHELL, 0.7), 1.5, true)
	# Aperture rim where the body leaves the shell
	draw_arc(Vector2(0, 0), 50.0, -PI * 0.5, PI * 0.5, 16, shade(SHELL, 1.2), 5.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

func draw_tentacle(i: int):
	var f = (i + 0.5) / TENTACLES * 2.0 - 1.0     # -1..1 across the ring
	var root = Vector2(48, f * 30.0)
	var ang = f * (0.15 + splay * 0.8)
	var seg = reach / 10.0
	var p = root
	var pts := PackedVector2Array([p])
	for k in 10:
		var wave = sin(t * 5.0 + i * 1.3 - k * 0.6) * 0.18 * (1.0 - grip)
		ang += wave - f * grip * 0.12
		p += Vector2.RIGHT.rotated(ang) * seg
		pts.append(p)
	var widths := []
	var spine := []
	for k in pts.size():
		spine.append(pts[k])
		widths.append(lerp(7.0, 2.0, k / float(pts.size() - 1)))
	tube(spine, widths, shade(FLESH, 0.9 + 0.1 * abs(f)), 2.0)
