# BossBase.gd
# Shared body for the era bosses. Each boss is drawn and posed in code every
# frame (no sprite sheet), so fins beat in a wave, legs step, tentacles reach
# and jaws open instead of one picture being stretched. Subclasses set the
# stats in setup(), run their attacks in think() and draw in draw_body().
# The root never rotates; bosses draw toward `facing` themselves.
extends CharacterBody2D

signal enemy_died
signal boss_health_changed(current, max_value, boss_title)

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
	add_child(light)

func _ready():
	add_to_group("enemies")
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
	health = max_health
	call_deferred("emit_boss_health")
	set_state("intro", 1.0)

# ── Overridden by each boss ──
func setup():
	pass

func think(_delta: float):
	pass

func draw_body():
	pass

func is_boss() -> bool:
	return true

func emit_boss_health():
	boss_health_changed.emit(health, max_health, boss_title)

func _physics_process(delta: float):
	t += delta
	state_time += delta
	if hit_flash > 0:
		hit_flash -= delta
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

func _draw():
	draw_body()

# ── State and movement helpers ──
func set_state(s: String, _unused: float = 0.0):
	state = s
	state_time = 0.0

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

# Hurts the player if they are inside a circle (global position)
func hurt_circle(center: Vector2, radius: float, dmg: int = -1) -> bool:
	if player.global_position.distance_to(center) < radius + 22.0:
		player.take_damage(damage if dmg < 0 else dmg)
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
	tear.damage = dmg
	tear.speed = spd
	tear.modulate = tint
	get_parent().add_child(tear)
	return tear

# ── Damage ──
func take_damage(amount: float):
	if dead:
		return
	health = max(0.0, health - amount * damage_taken_mult())
	hit_flash = 0.1
	boss_health_changed.emit(health, max_health, boss_title)
	if health <= 0:
		die()

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
	SoundManager.play_sfx("enemy_die", 0.6)
	death_burst()
	var main = get_tree().get_first_node_in_group("main")
	drop_elements(main.floor_number if main else 1)
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.22)
	enemy_died.emit()
	queue_free()

# A boss is a feast: a heap of every element it was built from
func drop_elements(floor_num: int):
	var bm = preload("res://data/Biominerals.gd")
	var orb_script = preload("res://BiomassOrb.gd")
	for el in bm.BOSSES.get(floor_num, ["P"]):
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
	if fill.a > 0.8 and star_shaped(pts):
		Shading.lit_poly(get_canvas_item(), pts, fill, light_dir())
	else:
		draw_colored_polygon(pts, lit(fill, Vector3(0, 0, 1)) if fill.a > 0.8 else fill)
	if width > 0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		draw_polyline(loop, Shading.ink(fill) if fill.a > 0.8 else OUTLINE, width, true)
	return true

func oval(c: Vector2, rx: float, ry: float, rot: float, fill: Color, width: float = 3.0):
	shape(ellipse_pts(c, rx, ry, rot), fill, width)

func limb(pts: PackedVector2Array, w: float, col: Color, outline: bool = true):
	var ink = Shading.ink(col)
	if outline:
		draw_polyline(pts, ink, w + 4.0, true)
		for p in pts:
			draw_circle(p, (w + 4.0) * 0.5, ink, true, -1.0, true)
	var base = lit(col, Vector3(0, 0, 1)).darkened(0.12)
	draw_polyline(pts, base, w, true)
	for p in pts:
		draw_circle(p, w * 0.5, base, true, -1.0, true)
	Shading.limb_shine(self, pts, w, col, light_dir())

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
		Shading.lit_tube(get_canvas_item(), spine, widths, fill, light_dir())
		if width > 0:
			var loop := tube_pts(spine, widths)
			loop.append(loop[0])
			draw_polyline(loop, Shading.ink(fill), width, true)
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
		draw_colored_polygon(outer, col)

# Pulsing warning marks shown before an attack lands
func warn_alpha() -> float:
	return 0.25 + 0.2 * sin(t * 18.0)

func warn_circle(c: Vector2, r: float):
	draw_circle(c, r, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6), true, -1.0, true)
	draw_arc(c, r, 0, TAU, 40, Color(WARN.r, WARN.g, WARN.b, 0.8), 3.0)

func warn_line(a: Vector2, b: Vector2, w: float):
	draw_line(a, b, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6), w, true)
	draw_line(a, b, Color(WARN.r, WARN.g, WARN.b, 0.7), 2.0, true)

func warn_sector(c: Vector2, r: float, ang: float, half: float):
	var pts := PackedVector2Array([c])
	for i in 17:
		pts.append(c + Vector2.RIGHT.rotated(ang - half + 2.0 * half * i / 16.0) * r)
	draw_colored_polygon(pts, Color(WARN.r, WARN.g, WARN.b, warn_alpha() * 0.6))
	pts.append(c)
	draw_polyline(pts, Color(WARN.r, WARN.g, WARN.b, 0.7), 2.0)

func shadow(c: Vector2, rx: float, ry: float, rot: float = 0.0):
	draw_colored_polygon(ellipse_pts(c, rx, ry, rot, 20), Color(0, 0, 0, 0.28))
