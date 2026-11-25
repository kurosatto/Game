# DrawnBoss.gd
# The alternate era bosses: giant individuals of animals drawn with the same
# code as the playable forms (PlayerBody.gd), so they walk, swim, gape and
# snap like the player does, only at boss size. Room.spawn_boss picks one of
# these or the era's original boss at random each run.
# Each species (SPECIES below) has three moves from a shared kit plus one
# move it only starts using once it is down to half health. Every attack is
# telegraphed: an ink "!" over the boss (BossBase.tell) and a red mark on the
# floor where it will land, for long enough to step out of it.
#
# Moves:
#  lunge       wind up, then dash in jaws first along a marked line
#  multi_lunge three lunges in a row, re-aiming between them
#  sweep       a marked arc in front is raked with claws or limbs
#  tail        the same, behind it, with the tail
#  slam        marked circles under and around you burst a moment later
#  slam_line   a row of bursts runs from the boss to you (belly flops)
#  stir        a ring of bursts all round the boss (silt kicked up)
#  ring        a pressure wave spreads out from the boss
#  volley      a fan of spat shots
#  burst       shots in every direction, twice
#  pull        suction or grasping limbs drag you toward the mouth
#  spin        the whole body rolls at you (the cell colony)
#  dive        sinks out of sight (can't be hurt), then bursts up under you
extends "res://bosses/BossBase.gd"

const PlayerBody = preload("res://PlayerBody.gd")

const SPECIES = {
	1: {"name": "Salpingoeca", "form": "ancestral_collar_cell", "rosette": 8, "scale": 2.1, "hp": 100.0, "speed": 150.0,
		"title": "SALPINGOECA ROSETTA — COLLAR CELL COLONY",
		"fact": "A living choanoflagellate, the closest single-celled relative of animals. Its collar cells stick together into a spinning rosette, joined by bridges of cytoplasm, much like the first steps toward a body.",
		"kit": ["spin", "ring", "volley"], "phase2": "burst", "light": Color(0.4, 0.85, 1.0), "burst": Color(0.5, 0.9, 1.0)},
	2: {"name": "Sidneyia", "form": "early_arthropod", "scale": 3.3, "hp": 150.0, "speed": 175.0, "tint": Color(0.92, 0.82, 0.7),
		"title": "SIDNEYIA — BURGESS SHALE HUNTER",
		"fact": "One of the biggest arthropods of the Burgess Shale. Its gut is often found packed with crushed shells, cracked by spiny bases on its legs.",
		"kit": ["lunge", "slam", "sweep"], "phase2": "stir", "light": Color(1.0, 0.7, 0.5), "burst": Color(0.85, 0.6, 0.45)},
	3: {"name": "Pentecopterus", "form": "chelicerate", "scale": 3.4, "hp": 210.0, "speed": 190.0, "tint": Color(0.95, 0.8, 0.75),
		"title": "PENTECOPTERUS — ORDOVICIAN SEA SCORPION",
		"fact": "The oldest known big sea scorpion, about 1.7 m long, named after the penteconter, a Greek warship. It swept prey up in a basket of spiny limbs.",
		"kit": ["lunge", "sweep", "slam"], "phase2": "multi_lunge", "swim": true, "light": Color(0.7, 1.0, 0.85), "burst": Color(0.7, 0.55, 0.5)},
	4: {"name": "Ophiacodon", "form": "synapsid", "scale": 3.4, "hp": 270.0, "speed": 200.0, "tint": Color(0.9, 0.82, 0.7),
		"title": "OPHIACODON — CARBONIFEROUS SYNAPSID",
		"fact": "A synapsid up to 3 m long, one of the first big hunters on land, with a long, deep skull full of sharp teeth. Like all synapsids it is closer kin to mammals than to any reptile.",
		"kit": ["lunge", "tail", "slam"], "phase2": "multi_lunge", "light": Color(1.0, 0.9, 0.6), "burst": Color(0.7, 0.55, 0.42)},
	5: {"name": "Eryops", "form": "lissamphibian", "scale": 3.6, "hp": 420.0, "speed": 170.0, "tint": Color(0.95, 0.85, 0.7),
		"title": "ERYOPS — PERMIAN GIANT AMPHIBIAN",
		"fact": "A 2 m amphibian with a broad, flat skull, living beside Dimetrodon. It probably gulped prey by gaping its wide mouth, sucking in water and food together.",
		"kit": ["lunge", "pull", "slam"], "phase2": "slam_line", "light": Color(1.0, 0.75, 0.45), "burst": Color(0.7, 0.55, 0.4)},
	# The sea worlds of floors 4 and 5 (data/Worlds.gd)
	6: {"name": "Rhizodus", "form": "lobe_finned_shorewalker", "scale": 3.6, "hp": 270.0, "speed": 185.0, "tint": Color(0.85, 0.85, 0.8),
		"title": "RHIZODUS — GIANT LOBE-FINNED FISH",
		"fact": "A 7 m lobe-finned fish of the coal swamps with fangs as long as a hand, the top predator of its rivers and coasts. Lobe-fins like it are our own distant cousins.",
		"kit": ["lunge", "tail", "ring"], "phase2": "dive", "swim": true, "light": Color(0.8, 0.95, 0.7), "burst": Color(0.6, 0.65, 0.5)},
	7: {"name": "Mesosaurus", "form": "sauropsid", "scale": 3.6, "hp": 400.0, "speed": 210.0, "tint": Color(0.85, 0.85, 0.8),
		"title": "MESOSAURUS — PERMIAN SEA REPTILE",
		"fact": "One of the first reptiles to go back to the water, with paddle feet, a long tail and needle teeth for straining small crustaceans. Its fossils lie in both Brazil and southern Africa, a clue that the continents were once joined.",
		"kit": ["lunge", "tail", "pull"], "phase2": "dive", "swim": true, "light": Color(0.8, 0.95, 1.0), "burst": Color(0.65, 0.65, 0.6)},
}

var spec: Dictionary = {}
var floor_num: int = 1
var kit: Array = []
var pivot: Node2D
var bodies: Array = []
var S: float = 3.0           # drawing scale
var move_speed: float = 0.0
var move_vel: Vector2 = Vector2.ZERO
var next_move: String = ""
var aim: Vector2 = Vector2.DOWN
var did_hit: bool = false
var repeats: int = 0
var marks: Array = []        # floor marks for slam_line (global positions)
var spin_angle: float = 0.0
var spin_rate: float = 0.6
var rosette_r: float = 0.0
var dive: float = 0.0        # 1 when fully under
var last_move: String = ""
var orbit_dir: float = 1.0
# Read by PlayerBody (see Player.gd): dash stretch, tuck, grown parts
var is_dashing: bool = false
var rooted_time: float = 0.0
var adaptations_taken: Dictionary = {}

func setup_enemy(floor_number: int):
	floor_num = preload("res://data/Worlds.gd").era(floor_number)
	super.setup_enemy(floor_number)

func setup():
	spec = SPECIES[floor_num]
	boss_title = spec.title
	boss_fact = spec.fact
	max_health = spec.hp
	speed = spec.speed
	S = spec.scale
	kit = spec.kit.duplicate()
	light.color = spec.light
	light.energy = 1.4
	light.scale = Vector2(4.0, 4.0)
	pivot = Node2D.new()
	add_child(pivot)
	var n = int(spec.get("rosette", 1))
	rosette_r = 15.0 * S if n > 1 else 0.0
	for i in n:
		var holder = Node2D.new()
		pivot.add_child(holder)
		var b = PlayerBody.new()
		b.foe = true
		b.pen = preload("res://HitPen.gd").new()
		b.player = self
		b.set_form(spec.form)
		b.scale = Vector2.ONE * S
		b.modulate = spec.get("tint", Color.WHITE)
		holder.add_child(b)
		bodies.append(b)
	(get_node("CollisionShape2D").shape as CircleShape2D).radius = (rosette_r + 14.0 * S) if n > 1 else 15.0 * S

func killer_name() -> String:
	return spec.get("name", super.killer_name())

func body_material() -> String:
	return preload("res://data/Fauna.gd").body_of(spec.get("name", ""))

func burst_color() -> Color:
	return spec.get("burst", Color(0.8, 0.6, 0.5))

func damage_taken_mult() -> float:
	# Under the murky water nothing reaches it
	return 0.0 if dive > 0.6 else 1.0

func on_phase2():
	super.on_phase2()
	if not kit.has(spec.phase2):
		kit.append(spec.phase2)
	# Straight into the new move, so the change is felt at once
	next_move = spec.phase2

func head_pos() -> Vector2:
	return global_position + facing * 42.0 * S

func strike():
	for b in bodies:
		b.on_attack()

func think(delta: float):
	var to_p = to_player()
	var d = to_p.length()
	var spd = 1.2 if phase2 else 1.0
	var start_pos = global_position
	var rosette = bodies.size() > 1
	is_dashing = false
	rooted_time = 0.0
	spin_rate = move_toward(spin_rate, 0.6, delta * 2.0)
	match state:
		"intro":
			turn_toward(to_p, 2.0, delta)
			if state_time > 1.2:
				set_state("approach")
		"approach":
			# Close in (swimmers circle at a distance), then pick a move
			var want = to_p.normalized()
			if spec.get("swim", false):
				var radial = to_p.normalized() * clamp((d - 320.0) / 200.0, -1.0, 1.0)
				var tangent = Vector2(-to_p.y, to_p.x).normalized() * orbit_dir
				want = (radial + tangent).normalized()
			elif d < 200.0:
				want = Vector2.ZERO
			move_vel = move_vel.move_toward(want * speed * spd, 600.0 * delta)
			if move_by(move_vel * delta, 70.0):
				orbit_dir = -orbit_dir
			turn_toward(move_vel if move_vel.length() > 20.0 else to_p, 3.0, delta)
			if state_time > randf_range(1.3, 2.0) / spd:
				start_move(pick_move(d))
		"lunge_wind":
			move_vel = Vector2.ZERO
			turn_toward(to_p, 7.0, delta)
			aim = facing
			if state_time > 0.6 / spd:
				set_state("lunge")
				did_hit = false
				strike()
				SoundManager.play_sfx("dash", 0.6)
		"lunge":
			is_dashing = true
			if move_by(aim * 1250.0 * spd * delta, 70.0) or state_time > 0.42:
				shake(6.0)
				repeats -= 1
				set_state("lunge_wind" if repeats > 0 else "recover")
			elif not did_hit:
				did_hit = hurt_circle(head_pos(), 18.0 * S)
		"sweep_wind", "tail_wind":
			turn_toward(to_p if state == "sweep_wind" else -to_p, 5.0, delta)
			if state_time > 0.65 / spd:
				did_hit = false
				strike()
				SoundManager.play_sfx("dash", 0.75)
				set_state(state.replace("_wind", ""))
		"sweep", "tail":
			var dir = facing if state == "sweep" else -facing
			if not did_hit and state_time < 0.2:
				var rel = player.global_position - global_position
				if rel.length() < sweep_r() + 20.0 and abs(dir.angle_to(rel)) < 1.1:
					player.take_damage(damage, killer_name())
					push_player(rel.normalized() * 600.0)
					did_hit = true
			if state_time > 0.5:
				set_state("recover")
		"slam_wind":
			turn_toward(to_p, 4.0, delta)
			if state_time > 0.35:
				strike()
				var pp = player.global_position
				spawn_hazard("zone", pp, {"delay": 0.9 / spd, "r": 90.0, "dmg": 1, "color": burst_color()})
				for k in (3 if phase2 else 2):
					var off = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(140.0, 240.0)
					spawn_hazard("zone", clamp_arena(pp + off, 40.0), {"delay": 1.1 / spd, "r": 80.0, "dmg": 1, "color": burst_color()})
				SoundManager.play_sfx("boss_roar", 0.9)
				set_state("recover")
		"slam_line_wind":
			turn_toward(to_p, 6.0, delta)
			if state_time > 0.4:
				# A row of belly flops runs out toward you
				strike()
				var dir = to_p.normalized()
				for k in 6:
					var p = clamp_arena(global_position + dir * (120.0 + k * 125.0), 40.0)
					spawn_hazard("zone", p, {"delay": 0.6 + k * 0.16, "r": 85.0, "dmg": 1, "color": burst_color()})
				set_state("slam_line")
		"slam_line":
			if state_time > 0.3:
				move_vel = facing * 300.0
				move_by(move_vel * delta, 70.0)
			if state_time > 1.3:
				shake(10.0)
				set_state("recover")
		"stir_wind":
			if state_time > 0.5:
				strike()
				for k in 10:
					var a = TAU * k / 10.0 + randf() * 0.2
					for rr in [170.0, 320.0]:
						spawn_hazard("zone", clamp_arena(global_position + Vector2.RIGHT.rotated(a + rr * 0.002) * rr, 30.0), {"delay": 0.8 if rr < 200.0 else 1.15, "r": 70.0, "dmg": 1, "color": burst_color()})
				SoundManager.play_sfx("explosion", 1.2, -4.0)
				set_state("recover")
		"ring_wind":
			spin_rate = 3.0
			if state_time > 0.6 / spd:
				strike()
				shake(8.0)
				SoundManager.play_sfx("explosion", 1.3)
				spawn_hazard("ring", global_position, {"speed": 400.0, "max_r": 680.0, "width": 34.0, "dmg": 1, "color": burst_color()})
				if phase2:
					spawn_hazard("ring", global_position, {"speed": 400.0, "start_r": -180.0, "max_r": 680.0, "width": 34.0, "dmg": 1, "color": burst_color()})
				set_state("recover")
		"volley_wind":
			turn_toward(to_p, 6.0, delta)
			if state_time > 0.55 / spd:
				strike()
				var n = 7 if phase2 else 5
				for k in n:
					var a = (k - (n - 1) * 0.5) * 0.16
					shoot(head_pos() if not rosette else global_position, to_p.rotated(a), 330.0, burst_color())
				SoundManager.play_sfx("shoot", 0.6)
				set_state("recover")
		"burst_wind":
			spin_rate = 5.0
			if state_time > 0.6:
				strike()
				fire_burst(16, 0.0)
				set_state("burst")
		"burst":
			spin_rate = 5.0
			if state_time > 0.5:
				fire_burst(16, PI / 16.0)
				set_state("recover")
		"pull_wind":
			turn_toward(to_p, 6.0, delta)
			if state_time > 0.55:
				set_state("pull")
				did_hit = false
				SoundManager.play_sfx("boss_roar", 0.6)
		"pull":
			# Gapes and sucks: everything in front is drawn into the mouth
			turn_toward(to_p, 2.0, delta)
			if fmod(state_time, 0.42) < delta:
				strike()
			var to_mouth = head_pos() - player.global_position
			var dist = to_mouth.length()
			if abs(facing.angle_to(-to_mouth)) < 0.9 and dist > 1.0:
				var pull = 190.0 * spd * clamp(1.2 - dist / 800.0, 0.0, 1.0)
				player.move_and_collide(to_mouth / dist * pull * delta)
			if not did_hit and dist < 14.0 * S:
				did_hit = hurt_circle(head_pos(), 14.0 * S, 2)
				if did_hit:
					push_player(facing * 700.0)
			if state_time > 1.6 or did_hit:
				set_state("recover")
		"spin_wind":
			spin_rate = 2.0 + state_time * 8.0
			aim = to_p.normalized()
			if state_time > 0.7 / spd:
				set_state("spin")
				did_hit = false
		"spin":
			# The rosette rolls at you, every flagellum beating at once
			spin_rate = 9.0
			is_dashing = true
			move_vel = aim * 720.0 * spd
			aim = aim.slerp(to_p.normalized(), delta * 0.8)
			if move_by(move_vel * delta, 70.0):
				aim = aim.bounce(wall_normal()) if repeats > 0 else aim
				repeats -= 1
				shake(5.0)
			if not did_hit:
				did_hit = hurt_circle(global_position, rosette_r + 10.0 * S)
			if state_time > 1.6 or repeats < 0:
				set_state("recover")
		"dive_wind":
			if state_time > 0.4:
				set_state("dive")
				SoundManager.play_sfx("dash", 0.4)
		"dive":
			# Under the murky water: only a ripple shows, drifting toward you
			dive = move_toward(dive, 1.0, delta * 2.5)
			is_dashing = true
			move_vel = to_p.normalized() * min(d / 0.5, 420.0)
			move_by(move_vel * delta, 70.0)
			if state_time > 1.5:
				spawn_hazard("zone", global_position, {"delay": 0.55, "r": 120.0, "dmg": 2, "color": burst_color()})
				set_state("surface")
		"surface":
			if state_time > 0.5:
				dive = move_toward(dive, 0.0, delta * 6.0)
				if state_time - delta <= 0.5:
					strike()
					shake(12.0)
					SoundManager.play_sfx("explosion", 0.9)
			if state_time > 1.0:
				dive = 0.0
				set_state("recover")
		"recover":
			move_vel = move_vel.move_toward(Vector2.ZERO, 900.0 * delta)
			move_by(move_vel * delta, 70.0)
			if state_time > 0.6 / spd:
				orbit_dir = 1.0 if randf() < 0.5 else -1.0
				set_state("approach")
	velocity = (global_position - start_pos) / max(delta, 0.0001)
	spin_angle += spin_rate * delta
	update_pose()
	update_hits()

func pick_move(d: float) -> String:
	if next_move != "":
		var m = next_move
		next_move = ""
		return m
	var options = kit.filter(func(m): return m != last_move)
	# Melee moves only make sense in reach
	if d > 420.0:
		var far = options.filter(func(m): return m not in ["sweep", "tail"])
		if not far.is_empty():
			options = far
	return options.pick_random() if not options.is_empty() else kit.pick_random()

func start_move(m: String):
	last_move = m
	repeats = 3 if m == "multi_lunge" else 2 if m == "spin" else 1
	if m == "multi_lunge":
		m = "lunge"
	set_state(m + "_wind")
	if m in ["lunge", "spin", "dive", "pull"]:
		SoundManager.play_sfx("boss_roar", 1.0 if floor_num < 3 else 0.75)

func sweep_r() -> float:
	return 70.0 * S if bodies.size() == 1 else 200.0

func wall_normal() -> Vector2:
	var p = global_position
	var n = Vector2.ZERO
	if p.x <= ARENA.position.x + 71.0: n.x = 1
	if p.x >= ARENA.end.x - 71.0: n.x = -1
	if p.y <= ARENA.position.y + 71.0: n.y = 1
	if p.y >= ARENA.end.y - 71.0: n.y = -1
	return n.normalized() if n != Vector2.ZERO else -aim

func fire_burst(n: int, off: float):
	for k in n:
		shoot(global_position, Vector2.RIGHT.rotated(TAU * k / n + off + spin_angle), 300.0, burst_color())
	SoundManager.play_sfx("shoot", 0.5)

func update_pose():
	if bodies.size() > 1:
		# The rosette: cells round a hub, flagella out, turning slowly
		pivot.rotation = 0.0
		for i in bodies.size():
			var a = spin_angle + TAU * i / bodies.size()
			var holder: Node2D = bodies[i].get_parent()
			holder.rotation = a
			holder.position = Vector2.RIGHT.rotated(a) * rosette_r * (1.0 + 0.06 * sin(t * 2.0 + i))
		return
	pivot.rotation = facing.angle()
	var under = dive
	pivot.modulate = Color(1, 1, 1, 1.0 - 0.85 * under)
	pivot.scale = Vector2.ONE * (1.0 - 0.15 * under)

func update_hits():
	var pts := []
	var radii := []
	if bodies.size() > 1:
		for b in bodies:
			pts.append((b.get_parent() as Node2D).global_position)
			radii.append(13.0 * S)
	else:
		for k in [0.25, -0.15, -0.5]:
			pts.append(global_position + facing * k * 90.0 * S)
			radii.append(14.0 * S * (1.0 - abs(k) * 0.6))
	set_hit_circles(pts, radii)

# The giant drawings are child nodes, drawn after the boss with their own
# HitPen: read what they drew when asked, so the hit test matches the
# picture on screen (BossBase.gap_to)
var _pieces: Array = []
var _pieces_r: float = 0.0
var _pieces_frame: int = -1

func hit_pieces() -> Array:
	var f = Engine.get_frames_drawn()
	if f != _pieces_frame:
		_pieces_frame = f
		_pieces = []
		var inv = get_global_transform().affine_inverse()
		for b in bodies:
			if not b.visible:
				continue
			# Where the drawing was on screen, not where the node has moved since
			var m: Transform2D = inv * b.hits_xf
			var k: float = m.get_scale().x
			for d in b.hits:
				# capsule [a, b, half width] or polygon [points, centre, radius]
				_pieces.append([m * d[0], m * d[1], d[2] * k])
		_pieces_r = bound_of(_pieces)
	return [_pieces, _pieces_r]

func draw_body():
	var spd = 1.2 if phase2 else 1.0
	# Ground shadow under the animal
	var r = (rosette_r + 16.0 * S) if bodies.size() > 1 else 40.0 * S
	if dive < 0.5:
		shadow(Vector2(0, 14), r * (1.0 if bodies.size() > 1 else 1.0), r * 0.45 if bodies.size() == 1 else r * 0.8, facing.angle() if bodies.size() == 1 else 0.0)
	match state:
		"lunge_wind":
			warn_line(facing * 30.0 * S, facing * (30.0 * S + 1250.0 * spd * 0.42), 26.0 * S)
		"sweep_wind":
			warn_sector(Vector2.ZERO, sweep_r(), facing.angle(), 1.1)
		"tail_wind":
			warn_sector(Vector2.ZERO, sweep_r(), (-facing).angle(), 1.1)
		"spin_wind":
			warn_line(Vector2.ZERO, aim * 600.0, rosette_r * 2.0)
		"pull", "pull_wind":
			var mouth = facing * 42.0 * S
			for k in 4:
				var f = fmod(t * 1.6 + k * 0.25, 1.0)
				var rr = lerp(420.0, 30.0, f)
				pen.draw_arc(mouth, rr, facing.angle() - 0.9, facing.angle() + 0.9, 24, Color(WARN.r, WARN.g, WARN.b, 0.5 * f), 3.0, true)
		"ring_wind", "burst_wind", "stir_wind":
			var k = clamp(state_time / 0.6, 0.0, 1.0)
			pen.draw_arc(Vector2.ZERO, r * (1.0 + 0.4 * k), 0, TAU, 48, Color(WARN.r, WARN.g, WARN.b, 0.3 + 0.4 * k), 4.0, true)
		"dive", "surface":
			# A ripple on the surface where it swims
			for k in 3:
				var f = fmod(t * 1.2 + k / 3.0, 1.0)
				pen.draw_arc(Vector2.ZERO, 30.0 + f * 90.0, 0, TAU, 32, Color(0.2, 0.15, 0.1, 0.5 * (1.0 - f)), 3.0, true)
