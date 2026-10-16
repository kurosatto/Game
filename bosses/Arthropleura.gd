# Arthropleura.gd — floor 4 (Carboniferous) boss
# Arthropleura was a millipede relative up to about 2.6 m long, the largest
# land arthropod known. It was most likely a plant and litter eater, not a
# hunter, so its danger is its size: dozens of armoured, lobed back plates
# over a carpet of legs that step in waves. Heads found in 2024 showed it had
# stalked eyes like a millipede's distant relatives and chewing mandibles.
# Attacks: a trampling charge that flings leaf litter aside, coiling around
# you, and (phase 2) rearing up to crash its front half down.
extends "res://bosses/BossBase.gd"

const PLATE = Color(0.47, 0.36, 0.25)
const LOBE = Color(0.66, 0.52, 0.34)
const LEG = Color(0.36, 0.27, 0.19)
const SEGMENTS = 22
const SPACING = 25.0

var path: Array = []          # head positions, newest first
var segs: Array = []          # [position, direction] per segment
var gait: float = 0.0
var move_speed: float = 0.0
var lift: float = 0.0         # front half raised off the ground
var charge_dir: Vector2 = Vector2.DOWN
var coil_center: Vector2
var coil_angle: float = 0.0
var coil_r: float = 300.0
var coil_dir: float = 1.0
var litter_timer: float = 0.0
var wander_bias: float = 0.0

func setup():
	boss_title = "ARTHROPLEURA — GIANT CARBONIFEROUS MYRIAPOD"
	boss_fact = "The largest land arthropod ever, up to 2.6 m long. It probably ate plants and leaf litter, but at that size it simply bulldozes through the swamp."
	max_health = 270.0
	damage = 1
	light.color = Color(1.0, 0.75, 0.4)
	light.energy = 1.3
	light.scale = Vector2(4.0, 4.0)

func _ready():
	super._ready()
	facing = Vector2.DOWN
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = 46.0
	for i in 80:
		path.append(global_position - facing * i * 8.0)
	update_segments()

func burst_color() -> Color:
	return LOBE

func think(delta: float):
	var to_p = to_player()
	var spd = 1.3 if phase2 else 1.0
	match state:
		"intro":
			move_speed = 60.0
			if state_time > 1.0:
				set_state("wander")
		"wander":
			# Weaves toward you, steering round the walls
			move_speed = 180.0 * spd
			wander_bias = sin(t * 1.3) * 0.8
			turn_toward(to_p.normalized().rotated(wander_bias), 2.2, delta)
			lift = move_toward(lift, 0.0, delta * 2.0)
			if state_time > randf_range(2.0, 3.0) / spd:
				var r = randf()
				if phase2 and r < 0.35:
					set_state("rear")
					spawn_slam_zones()
				elif r < 0.6:
					set_state("charge_wind")
				else:
					start_coil()
				SoundManager.play_sfx("boss_roar", 0.7)
		"charge_wind":
			move_speed = 30.0
			turn_toward(to_p, 6.0, delta)
			charge_dir = facing
			lift = move_toward(lift, 0.4, delta * 2.0)
			if state_time > 0.75 / spd:
				set_state("charge")
				SoundManager.play_sfx("dash", 0.5)
		"charge":
			# Tramples straight through, kicking litter out to the sides
			move_speed = 640.0 * spd
			lift = move_toward(lift, 0.0, delta * 4.0)
			turn_toward(to_p, 0.6, delta)
			litter_timer -= delta
			if litter_timer <= 0:
				litter_timer = 0.16 if phase2 else 0.24
				kick_litter()
			if state_time > 1.5:
				set_state("wander")
		"coil":
			# Runs a circle round you that keeps tightening
			move_speed = 0.0
			coil_r = max(120.0, coil_r - 55.0 * delta)
			coil_angle += coil_dir * (520.0 * spd / coil_r) * delta
			var target = coil_center + Vector2.RIGHT.rotated(coil_angle) * coil_r
			var step = target - global_position
			if step.length() > 0.1:
				facing = step.normalized()
			move_by(step.limit_length(900.0 * delta), 50.0)
			if state_time > 3.4:
				set_state("wander")
		"rear":
			# Lifts the front segments high, then crashes down on the zones
			move_speed = 20.0
			lift = move_toward(lift, 1.0, delta * 1.6) if state_time < 0.9 else move_toward(lift, 0.0, delta * 9.0)
			if state_time > 0.9 and state_time - delta <= 0.9:
				shake(16.0)
				SoundManager.play_sfx("explosion", 0.8)
			if state_time > 1.5:
				set_state("wander")

	if move_speed > 0:
		var v = facing * move_speed * delta
		if move_by(v, 50.0):
			# Hit a wall: swing the head back toward the middle of the room
			facing = facing.lerp((ARENA.get_center() - global_position).normalized(), 0.25).normalized()
			if state == "charge":
				shake(10.0)
				SoundManager.play_sfx("explosion", 1.2, -4.0)
				set_state("wander")
	gait += delta * (2.0 + max(move_speed, 300.0 if state == "coil" else 0.0) / 30.0)
	if path.is_empty() or path[0].distance_to(global_position) > 4.0:
		path.push_front(global_position)
		if path.size() > SEGMENTS * SPACING / 4.0 + 20:
			path.pop_back()
	update_segments()

	# The head bites; the plated body crushes whatever it rolls over
	if lift < 0.5:
		hurt_circle(global_position, 40.0)
	for i in range(2, SEGMENTS, 2):
		if hurt_circle(segs[i][0], 34.0):
			break
	var pts := []
	var radii := []
	for i in range(3, SEGMENTS, 3):
		pts.append(segs[i][0])
		radii.append(seg_width(i) * 0.8)
	set_hit_circles(pts, radii)

func start_coil():
	set_state("coil")
	coil_center = clamp_arena(player.global_position, 160.0)
	coil_angle = (global_position - coil_center).angle()
	coil_r = max(220.0, global_position.distance_to(coil_center))
	coil_r = min(coil_r, 330.0)
	coil_dir = 1.0 if randf() < 0.5 else -1.0

func spawn_slam_zones():
	var d = (player.global_position - global_position).normalized()
	facing = d
	for k in 3:
		spawn_hazard("zone", global_position + d * (130.0 + k * 115.0), {"r": 80.0, "delay": 0.9 + k * 0.08, "dmg": 1, "color": Color(0.8, 0.6, 0.35)})

func kick_litter():
	var i = randi_range(4, SEGMENTS - 4)
	var p: Vector2 = segs[i][0]
	var d: Vector2 = segs[i][1]
	var side = d.rotated(PI * 0.5) * (1.0 if randf() < 0.5 else -1.0)
	shoot(p + side * 50.0, side.rotated(randf_range(-0.3, 0.3)), 260.0, Color(0.75, 0.55, 0.3))

# Walk back along the head's trail to place each segment
func update_segments():
	segs.clear()
	var prev: Vector2 = global_position
	var want = SPACING
	var idx = 0
	var acc = 0.0
	var cur: Vector2 = global_position
	for s in SEGMENTS:
		var placed = false
		while idx < path.size():
			var nxt: Vector2 = path[idx]
			var gap = cur.distance_to(nxt)
			if acc + gap >= want:
				cur = cur.lerp(nxt, (want - acc) / max(gap, 0.001))
				acc = 0.0
				placed = true
				break
			acc += gap
			cur = nxt
			idx += 1
		if not placed:
			# Ran out of trail: carry on straight behind the last segment
			var back_dir = (cur - prev).normalized() if cur != prev else -facing
			cur = cur + back_dir * (want - acc)
			acc = 0.0
		var dir = (prev - cur).normalized() if prev != cur else facing
		segs.append([cur, dir])
		prev = cur

func seg_width(i: int) -> float:
	var f = i / float(SEGMENTS - 1)
	return lerp(46.0, 28.0, pow(f, 2.0)) + 6.0 * sin(clamp(f * 6.0, 0.0, PI))

func seg_lift(i: int) -> float:
	# Rearing raises the front third, highest at the head
	return lift * 70.0 * clamp(1.0 - i / 7.0, 0.0, 1.0)

func draw_body():
	# Shadow first: it stays on the ground while the front rears up
	for i in range(SEGMENTS - 1, -1, -1):
		var p = to_local(segs[i][0])
		shadow(p + Vector2(0, 12), seg_width(i) + 6.0, 20.0, segs[i][1].angle() + PI * 0.5)
	shadow(Vector2(0, 12), 44, 26)

	# Legs: two pairs per segment, stepping in waves that run along the body
	for i in range(SEGMENTS - 1, -1, -1):
		var p = to_local(segs[i][0]) - Vector2(0, seg_lift(i))
		var d: Vector2 = segs[i][1]
		var n = d.rotated(PI * 0.5)
		var w = seg_width(i)
		for pair in 2:
			var along = (pair - 0.5) * 11.0
			for side in [-1.0, 1.0]:
				var ph = gait - i * 0.55 - pair * 0.3 + (0.0 if side > 0 else PI)
				var swing = sin(ph) * 0.45
				var lifted = 1.0 - max(0.0, cos(ph)) * 0.25
				var hip = p + d * along + n * side * w * 0.7
				var dirl = n.rotated(-side * swing) * side
				var knee = hip + dirl * 22.0 * lifted + d * 3.0
				var foot = knee + dirl.rotated(side * 0.6) * 16.0 * lifted
				draw_polyline(PackedVector2Array([hip, knee, foot]), OUTLINE, 6.0)
				draw_polyline(PackedVector2Array([hip, knee, foot]), LEG, 3.0)

	# Back plates (tergites) with their side lobes, tail to head
	for i in range(SEGMENTS - 1, -1, -1):
		draw_plate(i)
	draw_head()

func draw_plate(i: int):
	var p = to_local(segs[i][0]) - Vector2(0, seg_lift(i))
	var d: Vector2 = segs[i][1]
	var n = d.rotated(PI * 0.5)
	var w = seg_width(i)
	var hl = 17.0
	var pts := PackedVector2Array([
		p + d * hl + n * w * 0.6, p + d * hl * 0.7 + n * w * 1.05, p - d * hl * 0.9 + n * w * 1.15,
		p - d * hl + n * w * 0.5, p - d * hl - n * w * 0.5, p - d * hl * 0.9 - n * w * 1.15,
		p + d * hl * 0.7 - n * w * 1.05, p + d * hl - n * w * 0.6])
	var shade_k = 1.0 + 0.12 * sin(i * 0.9)
	shape(pts, shade(PLATE, shade_k), 3.0)
	# Pale lobe tips and the raised axial ridge with paired tubercles
	for side in [-1.0, 1.0]:
		var tip = p - d * hl * 0.4 + n * side * w * 1.0
		draw_line(p + n * side * w * 0.65, tip, shade(LOBE, 1.1), 5.0, true)
		draw_circle(p + n * side * w * 0.3, 3.5, shade(LOBE, 1.2), true, -1.0, true)
	draw_line(p + d * hl * 0.8, p - d * hl * 0.8, shade(PLATE, 1.3), 4.0, true)

func draw_head():
	var d = facing
	var n = d.rotated(PI * 0.5)
	var p = -Vector2(0, lift * 70.0)
	# Antennae flicking
	for side in [-1.0, 1.0]:
		var a1 = p + d * 26.0 + n * side * 10.0
		var a2 = a1 + d.rotated(side * (0.5 + 0.2 * sin(t * 6.0 + side))) * 28.0
		var a3 = a2 + d.rotated(side * (0.8 + 0.25 * sin(t * 7.0 + side * 2.0))) * 22.0
		limb(PackedVector2Array([a1, a2, a3]), 3.0, LEG)
	# Mandibles working
	for side in [-1.0, 1.0]:
		var m0 = p + d * 22.0 + n * side * 10.0
		var m1 = m0 + d.rotated(-side * (0.4 + 0.3 * abs(sin(t * 8.0)))) * 16.0
		limb(PackedVector2Array([m0, m1]), 5.0, Color(0.25, 0.18, 0.12))
	shape(ellipse_pts(p + d * 8.0, 30, 38, d.angle()), shade(PLATE, 1.15), 3.0)
	# Stalked eyes
	for side in [-1.0, 1.0]:
		var e0 = p + d * 14.0 + n * side * 18.0
		var e1 = e0 + d.rotated(side * 1.0) * 14.0
		limb(PackedVector2Array([e0, e1]), 5.0, shade(PLATE, 1.0))
		draw_circle(e1, 7.0, OUTLINE, true, -1.0, true)
		draw_circle(e1, 5.0, Color(0.15, 0.12, 0.1), true, -1.0, true)
		draw_circle(e1 + d * 1.5 + n * side * -1.5, 2.0, Color(1, 0.95, 0.8), true, -1.0, true)
	# Telegraph for the charge
	if state == "charge_wind":
		warn_line(Vector2.ZERO, charge_dir * 900.0, 100.0)
