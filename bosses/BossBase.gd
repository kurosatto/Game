# BossBase.gd
# Shared body for the era bosses. Each boss is drawn and posed in code every
# frame (no sprite sheet), so fins beat in a wave, legs step, tentacles reach
# and jaws open instead of one picture being stretched. Subclasses set the
# stats in setup(), run their attacks in think() and draw in draw_body().
# The root never rotates; bosses draw toward `facing` themselves.
extends CharacterBody2D

signal enemy_died
const HitFX = preload("res://HitFX.gd")
const Difficulty = preload("res://data/Difficulty.gd")
signal boss_health_changed(current, max_value, boss_title)

# Shared lighting (preloaded: works even before the editor has rescanned)
const Shading = preload("res://Shading.gd")
# All of a boss's drawing goes out as one draw call (InkBatch.gd), and the
# pen remembers where it drew so the boss is hit there (HitPen.gd)
var pen = preload("res://HitPen.gd").new()
# Open floor of the boss room, inside the walls and clear of the door gaps
const ARENA = Rect2(190, 190, 1540, 700)
const OUTLINE = Color(0.05, 0.07, 0.12, 1.0)
const WARN = Color(1.0, 0.25, 0.2)

var enemy_type: String = "boss"
var boss_title: String = ""
var boss_fact: String = ""
var max_health: float = 100.0
var health: float = 100.0
var damage: int = 1
var speed: float = 150.0
var player: Node2D = null
var light: PointLight2D

var t: float = 0.0 # animation clock
var state: String = "intro"
var state_time: float = 0.0
var facing: Vector2 = Vector2.DOWN
var phase2: bool = false
var hit_flash: float = 0.0
var stun_timer: float = 0.0
var dead: bool = false
var player_push: Vector2 = Vector2.ZERO
# Read by the player's signature moves (sting venom build-up)
var venom_stacks: int = 0
# Held by a cephalopod's arms (Player.grip_grab): follow-up hits bite harder
var grabbed_time: float = 0.0
# Extra hit circles along long bodies: [CollisionShape2D, ...]
var hit_shapes: Array = []

var tear_scene = preload("res://Tear.tscn")
var hazard_script = preload("res://bosses/BossHazard.gd")

func _init():
	collision_layer = 2
	collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	cs.shape = CircleShape2D.new()
	add_child(cs)
	light = PointLight2D.new()
	light.texture = load("res://assets/light.png")
	light.energy = 1.6
	light.scale = Vector2(3.5, 3.5)
	# Off: its additive glow bleached the boss's colours to white
	light.enabled = false
	add_child(light)

func _ready():
	add_to_group("enemies")
	add_to_group("bosses") # shots test their drawn bodies (Tear.gd)
	player = get_tree().get_first_node_in_group("player")
	# The boss is drawn over its long body; the player walks under fins and
	# tentacles and is hurt by the parts that attack, not by the hitbox
	if player and player is PhysicsBody2D:
		player.add_collision_exception_with(self)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("display_item_banner") and boss_fact != "":
		main.display_item_banner(boss_title, boss_fact)

func setup_enemy(_floor_number: int):
	setup()
	# Tougher in every era, more so later (data/Difficulty.gd)
	max_health *= Difficulty.boss_health_mult(_floor_number)
	health = max_health
	call_deferred("emit_boss_health")
	set_state("intro", 1.4) # a moment to see it before it moves

# ── Overridden by each boss ──
func setup():
	pass

func think(_delta: float):
	pass

func draw_body():
	pass

# How the game over screen names this boss ("Killed by Anomalocaris.")
func killer_name() -> String:
	return boss_title.split(" ")[0].capitalize()

func is_boss() -> bool:
	return true

func emit_boss_health():
	boss_health_changed.emit(health, max_health, boss_title)

func _physics_process(delta: float):
	# ARENA and the moves are in room coordinates, which only match the world
	# once the room has slid into place: while the room slides in it sits a
	# whole room away, and a move then clamped the boss to the near wall,
	# right where the player walks in. Hold still until the slide is over.
	if _room_sliding():
		return
	t += delta
	# Less circling between attacks; wind-ups keep their full length
	state_time += delta * Difficulty.boss_clock(state)
	if hit_flash > 0:
		hit_flash -= delta
	if grabbed_time > 0:
		grabbed_time -= delta
	modulate = Color(1.9, 1.7, 1.7) if hit_flash > 0 else Color.WHITE
	queue_redraw()
	if dead or not player or not is_instance_valid(player):
		return
	if player_push.length_squared() > 1.0:
		player.move_and_collide(player_push * delta)
		player_push = player_push.move_toward(Vector2.ZERO, delta * 1600.0)
	if stun_timer > 0:
		stun_timer -= delta
		return
	if not phase2 and health < max_health * 0.5:
		phase2 = true
		on_phase2()
	think(delta)

func on_phase2():
	SoundManager.play_sfx("boss_roar", 0.8)
	shake(14.0)
	# Half health: it rears up in a splash of ink and fights differently
	HitFX.pop(get_parent(), global_position, burst_color().lerp(Color.WHITE, 0.3), 60.0, 420.0, 0.5)
	enraged = 1.0
	tell_time = 1.0

func _draw():
	pen.begin(self)
	draw_body()
	pen.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	pen.solid = false # the "!" marks are not body
	draw_tell()
	pen.solid = true
	pen.flush()
	_drawn_packed = pen.take_packed()

# ── Hit where it is drawn ──
# Everything solid the boss draws (HitPen.gd) is kept, in the boss's own
# space, as capsules and polygons. Shots, bites, stings, blasts and spines
# measure to them (gap_to, nearest_point), so a tail, shell, sail or limb
# takes a hit wherever it is drawn this frame, whatever pose the boss is in.
# Packed by HitPen until something asks (most frames nothing does)
var _drawn_packed: Array = []
var _drawn: Array = []
var _drawn_r: float = 0.0
var drawn: Array:
	get:
		_unpack_drawn()
		return _drawn
var drawn_r: float: # everything drawn lies within this of the centre
	get:
		_unpack_drawn()
		return _drawn_r

func _unpack_drawn():
	if not _drawn_packed.is_empty():
		_drawn = preload("res://HitPen.gd").expand(_drawn_packed)
		_drawn_r = bound_of(_drawn)
		_drawn_packed = []

static func bound_of(pieces: Array) -> float:
	var r := 0.0
	for d in pieces:
		r = max(r, (d[1].length() + d[2]) if d[0] is PackedVector2Array else max(d[0].length(), d[1].length()) + d[2])
	return r

# The drawn pieces to hit test, and how far out they reach. Bosses drawn
# by child nodes (DrawnBoss) override this to read their children.
func hit_pieces() -> Array:
	return [drawn, drawn_r]

# Distance from a global point to the nearest drawn or hit-circle part of
# the boss (0 inside it). Pieces further than `limit` are skipped quickly.
func gap_to(p: Vector2, limit: float = INF) -> float:
	var best := INF
	for part in hurt_parts():
		best = min(best, max(0.0, p.distance_to(part[0]) - part[1]))
	if best <= 0.0:
		return 0.0
	var lp: Vector2 = to_local(p)
	var k: float = max(absf(global_scale.x), 0.001)
	var cap: float = min(best, limit) / k
	var hp: Array = hit_pieces()
	if lp.length() - hp[1] > cap:
		return min(best, limit)
	for d in hp[0]:
		var g: float
		if d[0] is PackedVector2Array:
			if lp.distance_to(d[1]) - d[2] > cap:
				continue
			if Geometry2D.is_point_in_polygon(lp, d[0]):
				return 0.0
			g = INF
			var n = d[0].size()
			for i in n:
				g = min(g, lp.distance_to(Geometry2D.get_closest_point_to_segment(lp, d[0][i], d[0][(i + 1) % n])))
		else:
			g = lp.distance_to(Geometry2D.get_closest_point_to_segment(lp, d[0], d[1])) - d[2]
		if g < cap:
			cap = max(g, 0.0)
			if g <= 0.0:
				return 0.0
	return min(best, cap * k)

# The point of the boss's body nearest to a global point (the point itself
# when it is inside). Melee strikes land here.
func nearest_point(p: Vector2) -> Vector2:
	var best := INF
	var at := global_position
	for part in hurt_parts():
		var g = p.distance_to(part[0]) - part[1]
		if g < best:
			best = g
			at = p if g <= 0.0 else part[0] + (p - part[0]).normalized() * part[1]
	if best <= 0.0:
		return p
	var lp: Vector2 = to_local(p)
	var k: float = max(absf(global_scale.x), 0.001)
	var cap: float = best / k
	var hit = null
	var hp: Array = hit_pieces()
	if lp.length() - hp[1] > cap:
		return at
	for d in hp[0]:
		var q: Vector2
		var g: float
		if d[0] is PackedVector2Array:
			if lp.distance_to(d[1]) - d[2] > cap:
				continue
			if Geometry2D.is_point_in_polygon(lp, d[0]):
				return p
			g = INF
			var n = d[0].size()
			for i in n:
				var c = Geometry2D.get_closest_point_to_segment(lp, d[0][i], d[0][(i + 1) % n])
				if lp.distance_to(c) < g:
					g = lp.distance_to(c)
					q = c
		else:
			var c = Geometry2D.get_closest_point_to_segment(lp, d[0], d[1])
			g = lp.distance_to(c) - d[2]
			if g <= 0.0:
				return p
			q = c + (lp - c).normalized() * d[2]
		if g < cap:
			cap = g
			hit = q
	return to_global(hit) if hit != null else at


# ── Tells ──
# Every attack wind-up (a state ending in "_wind") flashes ink marks over
# the boss with a short hiss, on top of the floor warnings each move draws,
# so a new boss can be read on its first attack.
var tell_time: float = 0.0
var enraged: float = 0.0
const TELL_TIME := 0.55
const INK = Color(0.2, 0.12, 0.06)

func tell():
	tell_time = TELL_TIME
	SoundManager.play_sfx("enemy_lunge", 0.7, -4.0)

func tell_height() -> float:
	var cs = get_node_or_null("CollisionShape2D")
	return (cs.shape.radius if cs else 60.0) + 46.0

func draw_tell():
	enraged = max(0.0, enraged - get_process_delta_time() * 0.8)
	if enraged > 0.0:
		# Phase change: ink rings burst off the boss
		var k = 1.0 - enraged
		for i in 3:
			pen.draw_arc(Vector2.ZERO, tell_height() * (0.8 + k * (1.2 + i * 0.5)), 0, TAU, 48, Color(INK, enraged * 0.7), 5.0 - i, true)
	if tell_time <= 0.0:
		return
	tell_time = max(0.0, tell_time - get_process_delta_time())
	var k = tell_time / TELL_TIME
	var pop = 1.0 + 0.35 * smoothstep(0.7, 1.0, k)
	var top = Vector2(0, -tell_height())
	var marks = 2 if phase2 else 1
	for m in marks:
		var x = (m - (marks - 1) * 0.5) * 22.0
		var a = top + Vector2(x, -30.0 * pop)
		var b = top + Vector2(x, -6.0 * pop)
		pen.draw_line(a, b, Color(0.98, 0.93, 0.82, 0.9 * min(1.0, k * 2.0)), 11.0 * pop, true)
		pen.draw_line(a, b, Color(INK, min(1.0, k * 2.0)), 6.0 * pop, true)
		pen.draw_circle(top + Vector2(x, 6.0 * pop), 5.5 * pop, Color(0.98, 0.93, 0.82, 0.9 * min(1.0, k * 2.0)), true, -1.0, true)
		pen.draw_circle(top + Vector2(x, 6.0 * pop), 3.5 * pop, Color(INK, min(1.0, k * 2.0)), true, -1.0, true)

# ── State and movement helpers ──
func _room_sliding() -> bool:
	var main = get_tree().get_first_node_in_group("main")
	return main != null and main.get("is_transitioning") == true

func set_state(s: String, _unused: float = 0.0):
	state = s
	state_time = 0.0
	if s.ends_with("_wind"):
		tell()

func to_player() -> Vector2:
	return player.global_position - global_position

func dir_to_player() -> Vector2:
	var v = to_player()
	return v.normalized() if v.length_squared() > 1.0 else facing

func clamp_arena(p: Vector2, pad: float = 0.0) -> Vector2:
	return Vector2(
		clamp(p.x, ARENA.position.x + pad, ARENA.end.x - pad),
		clamp(p.y, ARENA.position.y + pad, ARENA.end.y - pad))

func move_by(v: Vector2, pad: float = 0.0) -> bool:
	# Returns true when the wall stopped the move
	var want = global_position + v
	var got = clamp_arena(want, pad)
	global_position = got
	return want.distance_to(got) > 0.5

func turn_toward(dir: Vector2, rate: float, delta: float):
	if dir.length_squared() < 0.0001:
		return
	facing = Vector2.RIGHT.rotated(lerp_angle(facing.angle(), dir.angle(), clamp(rate * delta, 0.0, 1.0)))

func shake(amount: float):
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("shake_camera"):
		main.shake_camera(amount)

# ── The drawing against the player's drawing (ArtShape.gd, Player.touched_by) ──
const ArtShape = preload("res://ArtShape.gd")

func art_gapper() -> Callable:
	var hp: Array = hit_pieces()
	if hp[0].is_empty():
		return func(p: Vector2) -> float: return gap_to(p)
	return ArtShape.samples_gapper(ArtShape.dedupe(ArtShape.pieces_samples(hp[0], get_global_transform(), 5.0), 5.0))

func art_reach() -> float:
	var hp: Array = hit_pieces()
	var k: float = max(absf(global_scale.x), 0.001)
	var r: float = hp[1] * k
	for part in hurt_parts():
		r = max(r, part[0].distance_to(global_position) + part[1])
	return r

# Is any drawn part of the boss touching any drawn part of the player?
func drawing_touches_player() -> bool:
	return player.touched_by(self) if player.has_method("touched_by") else true

# Hurts the player if they are inside a circle (global position)
# kuro (2026-11-25): "make all the damages accurate". A strike lands only
# when your drawn body is inside the strike's circle and the boss's own
# drawing (jaws, claws, tail, shell) is touching your drawing.
func hurt_circle(center: Vector2, radius: float, dmg: int = -1) -> bool:
	var touching: bool
	if player.has_method("hit_by_circle"):
		touching = player.hit_by_circle(center, radius) and drawing_touches_player()
	else:
		touching = player.global_position.distance_to(center) < radius + 22.0
	if touching:
		player.take_damage(damage if dmg < 0 else dmg, killer_name())
		return true
	return false

func push_player(v: Vector2):
	player_push = v

# Updates (creating as needed) the extra hit circles, in global positions
func set_hit_circles(points: Array, radii: Array):
	while hit_shapes.size() < points.size():
		var cs := CollisionShape2D.new()
		cs.shape = CircleShape2D.new()
		add_child(cs)
		hit_shapes.append(cs)
	for i in hit_shapes.size():
		var cs: CollisionShape2D = hit_shapes[i]
		if i < points.size():
			cs.disabled = false
			cs.position = to_local(points[i])
			cs.shape.radius = radii[i]
		else:
			cs.disabled = true

# Every hit circle of the drawn body, as [global centre, radius]: the main
# CollisionShape2D first, then the extra circles along tails, shells and
# limbs. Player weapons and blasts measure to these, so any drawn part can
# be hit (Player.reach_dist, Tear.gd).
func hurt_parts() -> Array:
	var out: Array = []
	var cs = get_node_or_null("CollisionShape2D")
	var k: float = max(absf(global_scale.x), absf(global_scale.y))
	out.append([global_position, (cs.shape.radius if cs else 60.0) * k])
	for e in hit_shapes:
		if not e.disabled:
			out.append([e.global_position, e.shape.radius * k])
	return out

func spawn_hazard(kind: String, pos: Vector2, params: Dictionary) -> Node2D:
	var h = hazard_script.new()
	h.kind = kind
	h.position = pos
	h.params = params
	h.boss = self
	get_parent().add_child(h)
	return h

func shoot(from: Vector2, dir: Vector2, spd: float, tint: Color = Color.WHITE, dmg: int = 1) -> Node:
	var tear = tear_scene.instantiate()
	tear.position = from
	tear.direction = dir.normalized()
	tear.is_enemy_tear = true
	tear.shooter_name = killer_name()
	tear.damage = dmg
	tear.speed = spd
	tear.modulate = tint
	get_parent().add_child(tear)
	return tear

# ── Damage ──
func take_damage(amount: float):
	if dead:
		return
	# Chemical sense: a wounded boss bleeds into the water (Player.taste_bonus)
	if health < max_health and player and is_instance_valid(player) and player.has_method("taste_bonus"):
		amount *= 1.0 + player.taste_bonus()
	health = max(0.0, health - amount * damage_taken_mult())
	hit_flash = 0.1
	boss_health_changed.emit(health, max_health, boss_title)
	if health <= 0:
		die()

# Soft, shelled or bony: what hits and the kill sound like (Fauna.BODIES)
func body_material() -> String:
	return preload("res://data/Fauna.gd").body_of(boss_title.split(" ")[0].capitalize())

func take_damage_if_alive(amount: float):
	if not dead and health > 0:
		take_damage(amount)

func damage_taken_mult() -> float:
	return 1.0

func apply_knockback(force: Vector2, _stun: float = 0.4):
	move_by(force * 0.03)

func apply_stun(duration: float):
	stun_timer = max(stun_timer, min(duration, 0.35))

func die():
	if dead:
		return
	dead = true
	SoundManager.play_kill(body_material(), true)
	death_burst()
	HitFX.kill_marks(get_parent(), global_position, burst_color(), body_material(), 90.0)
	var main = get_tree().get_first_node_in_group("main")
	drop_elements(main.floor_number if main else 1)
	preload("res://data/Codex.gd").note_eaten(boss_title.split(" ")[0].capitalize())
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.22)
	enemy_died.emit()
	queue_free()

# A boss is a feast: a heap of every element it was built from
func drop_elements(floor_num: int):
	var bm = preload("res://data/Biominerals.gd")
	var orb_script = preload("res://BiomassOrb.gd")
	for el in bm.BOSSES.get(preload("res://data/Worlds.gd").era(floor_num), ["P"]):
		for i in 3:
			var orb = orb_script.new()
			orb.value = bm.BOSS_YIELD / 3.0
			orb.element = el
			orb.position = position
			get_parent().call_deferred("add_child", orb)

func burst_color() -> Color:
	return Color(1.0, 0.5, 0.4)

func death_burst():
	var p = CPUParticles2D.new()
	p.position = global_position
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 90
	p.lifetime = 1.6
	p.gravity = Vector2(0, 40)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 70.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 420.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 18.0
	var c = burst_color()
	var fade = Gradient.new()
	fade.set_color(0, Color(c.r * 1.4, c.g * 1.4, c.b * 1.4, 1.0))
	fade.set_color(1, Color(c.r, c.g, c.b, 0.0))
	p.color_ramp = fade
	get_parent().add_child(p)
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

# ── Drawing helpers (local space) ──
static func shade(c: Color, k: float) -> Color:
	if k < 1.0:
		return Color(c.r * k, c.g * k, c.b * k, c.a)
	return Color(c.r + (1.0 - c.r) * (k - 1.0), c.g + (1.0 - c.g) * (k - 1.0), c.b + (1.0 - c.b) * (k - 1.0), c.a)

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a = TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts

# ── Lighting (shared with the player forms, see Shading.gd) ──
# Bosses draw rotated toward `facing` with draw_set_transform; they set
# light_rot to the same angle so the light stays fixed on screen.
var light_rot: float = 0.0

func light_dir() -> Vector3:
	return Shading.light_for(global_rotation + light_rot)

func lit(col: Color, n: Vector3) -> Color:
	return Shading.lit(col, n, light_dir())

# True when every edge of the outline faces the centroid, so the shading
# rings shrunk toward it stay inside the shape
static func star_shaped(pts: PackedVector2Array) -> bool:
	var c := Vector2.ZERO
	for q in pts:
		c += q
	c /= pts.size()
	var sign := 0.0
	for i in pts.size():
		var cr = (pts[i] - c).cross(pts[(i + 1) % pts.size()] - c)
		if abs(cr) < 0.001:
			continue
		if sign == 0.0:
			sign = signf(cr)
		elif signf(cr) != sign:
			return false
	return true

# Shaded fill with an outline in a deep shade of its own colour
func shape(pts: PackedVector2Array, fill: Color, width: float = 3.0) -> bool:
	if pts.size() < 3 or Geometry2D.triangulate_polygon(pts).is_empty():
		return false
	if fill.a >= pen.MIN_ALPHA:
		pen.hit_poly(pts)
	if fill.a > 0.8 and star_shaped(pts):
		Shading.lit_poly(pen, pts, fill, light_dir())
	else:
		pen.draw_colored_polygon(pts, lit(fill, Vector3(0, 0, 1)) if fill.a > 0.8 else fill)
	if width > 0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		pen.draw_polyline(loop, Shading.ink(fill) if fill.a > 0.8 else OUTLINE, width, true)
	return true

func oval(c: Vector2, rx: float, ry: float, rot: float, fill: Color, width: float = 3.0):
	shape(ellipse_pts(c, rx, ry, rot), fill, width)

func limb(pts: PackedVector2Array, w: float, col: Color, outline: bool = true):
	var ink = Shading.ink(col)
	if outline:
		pen.draw_polyline(pts, ink, w + 4.0, true)
		for p in pts:
			pen.draw_circle(p, (w + 4.0) * 0.5, ink, true, -1.0, true)
	var base = lit(col, Vector3(0, 0, 1)).darkened(0.12)
	pen.draw_polyline(pts, base, w, true)
	for p in pts:
		pen.draw_circle(p, w * 0.5, base, true, -1.0, true)
	Shading.limb_shine(pen, pts, w, col, light_dir())

# A body along a spine: points with a half-width at each, closed into one
# outlined polygon. Used for horns, tails, tentacles and trunks.
func tube_pts(spine: Array, widths: Array) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n = spine.size()
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tangent = (b - a).normalized()
		var normal = Vector2(-tangent.y, tangent.x)
		left.append(spine[i] + normal * widths[i])
		right.append(spine[i] - normal * widths[i])
	right.reverse()
	left.append_array(right)
	return left

func tube(spine: Array, widths: Array, fill: Color, width: float = 3.0):
	if fill.a > 0.8 and spine.size() >= 2:
		Shading.lit_tube(pen, spine, widths, fill, light_dir())
		for i in spine.size() - 1:
			pen.hit_seg(spine[i], spine[i + 1], (widths[i] + widths[i + 1]) * 0.5)
		if width > 0:
			var loop := tube_pts(spine, widths)
			loop.append(loop[0])
			pen.draw_polyline(loop, Shading.ink(fill), width, true)
		return
	if not shape(tube_pts(spine, widths), fill, width):
		# Bent too tightly to fill as one polygon: draw it as a thick limb
		var avg = 0.0
		for w in widths:
			avg += w
		limb(PackedVector2Array(spine), 2.0 * avg / max(widths.size(), 1), fill, width > 0)

# Round bodies are lit as cylinders by tube() now
func tube_shaded(spine: Array, widths: Array, fill: Color, width: float = 3.0):
	tube(spine, widths, fill, width)

func shade_band(spine: Array, widths: Array, side: float, depth: float, col: Color, inset: float = 0.0):
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var n = spine.size()
	for i in n:
		var a: Vector2 = spine[max(i - 1, 0)]
		var b: Vector2 = spine[min(i + 1, n - 1)]
		var tn = (b - a).normalized()
		var nm = Vector2(-tn.y, tn.x) * side
		outer.append(spine[i] + nm * widths[i] * (1.0 - inset))
		inner.append(spine[i] + nm * widths[i] * (1.0 - inset - depth))
	inner.reverse()
	outer.append_array(inner)
	if not Geometry2D.triangulate_polygon(outer).is_empty():
		pen.draw_colored_polygon(outer, col)

# Pulsing warning marks shown before an attack lands
func warn_alpha() -> float:
	return 0.25 + 0.2 * sin(t * 18.0)

func warn_circle(c: Vector2, r: float):
	pen.solid = false
	pen.draw_circle(c, r, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6), true, -1.0, true)
	pen.draw_arc(c, r, 0, TAU, 40, Color(WARN.r, WARN.g, WARN.b, 0.8), 3.0)
	pen.solid = true

func warn_line(a: Vector2, b: Vector2, w: float):
	pen.solid = false
	pen.draw_line(a, b, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6), w, true)
	pen.draw_line(a, b, Color(WARN.r, WARN.g, WARN.b, 0.7), 2.0, true)
	pen.solid = true

func warn_sector(c: Vector2, r: float, ang: float, half: float):
	pen.solid = false
	var pts := PackedVector2Array([c])
	for i in 17:
		pts.append(c + Vector2.RIGHT.rotated(ang - half + 2.0 * half * i / 16.0) * r)
	pen.draw_colored_polygon(pts, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6))
	pts.append(c)
	pen.draw_polyline(pts, Color(WARN.r, WARN.g, WARN.b, 0.7), 2.0)
	pen.solid = true

# Ground shadows are gone (kuro disliked the dark blot under the art); the
# calls stay so a boss's drawing order reads as before
func shadow(_c: Vector2, _rx: float, _ry: float, _rot: float = 0.0):
	pass
