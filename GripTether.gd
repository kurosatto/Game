# GripTether.gd
# The arms/tentacle grab (cephalopods, sea stars) made visible. When a strike
# lands, an inked tentacle stays wrapped round the animal for as long as it is
# held (Enemy.grabbed_time). Small animals are reeled in to arm's length and
# can't struggle free; big ones and bosses are only held, not moved. Every
# hit on a held animal is the follow-up bite (Player.weapon_special, 1.8x).
extends Node2D

var player: Node2D
var target: Node2D
var color: Color = Color(0.85, 0.4, 1.0)
var hold: bool = true      # reel the animal in and keep it still
var t: float = 0.0
var release: float = 0.0   # 0..1 as the tentacle lets go and snaps back
var letting_go: bool = false
var last_end: Vector2 = Vector2.ZERO

const REEL_SPEED = 14.0

func _ready():
	z_index = 1
	top_level = true

func held() -> bool:
	return is_instance_valid(target) and target.get("grabbed_time") != null \
		and target.grabbed_time > 0.0 and target.get("health") != null and target.health > 0

func _physics_process(delta: float):
	t += delta
	if not is_instance_valid(player):
		queue_free()
		return
	if letting_go or not held():
		letting_go = true
		release += delta * 6.0
		if release >= 1.0:
			queue_free()
		queue_redraw()
		return
	last_end = target.global_position
	if hold:
		# Reel in to just outside touching distance, then keep it there
		var to = target.global_position - player.global_position
		var dist = to.length()
		var want = radius_of(player, 26.0) + radius_of(target, 26.0) + 34.0
		if dist > want + 2.0:
			var goal = player.global_position + to / max(dist, 0.001) * want
			target.velocity = (goal - target.global_position) * REEL_SPEED
			target.move_and_slide()
		target.knockback_velocity = Vector2.ZERO
		target.stun_timer = max(target.stun_timer, 0.12)
	queue_redraw()

func radius_of(node: Node2D, fallback: float) -> float:
	var cs = node.get_node_or_null("CollisionShape2D")
	if cs and cs.shape is CircleShape2D:
		return cs.shape.radius * max(abs(node.scale.x), abs(node.scale.y)) * max(abs(cs.scale.x), abs(cs.scale.y))
	return fallback

func _draw():
	if not is_instance_valid(player):
		return
	var a: Vector2 = player.global_position
	var b: Vector2 = last_end
	var to = b - a
	var dist = to.length()
	if dist < 4.0:
		return
	var dir = to / dist
	var side = dir.orthogonal()
	var pr = radius_of(player, 26.0) * 0.7
	var er = radius_of(target, 24.0) if is_instance_valid(target) else 24.0
	# Snapping back: the tip slides home along the arm
	var reach = 1.0 - release
	var start = a + dir * pr
	var tip = start.lerp(b - dir * er * 0.2, reach)
	var ink = Color(0.16, 0.1, 0.06, 0.9 * reach + 0.1)
	var body = Color(color.r, color.g, color.b, 0.85)
	# A gently wriggling arm, thick at the base, thin at the tip
	var pts: PackedVector2Array = []
	var n = 14
	for i in n + 1:
		var f = float(i) / n
		var wob = sin(t * 9.0 + f * 7.0) * 6.0 * sin(f * PI)
		pts.append(start.lerp(tip, f) + side * wob)
	for i in n:
		var f = float(i) / n
		var w = lerp(9.0, 3.0, f)
		draw_line(pts[i], pts[i + 1], ink, w + 3.0, true)
	for i in n:
		var f = float(i) / n
		draw_line(pts[i], pts[i + 1], body, lerp(9.0, 3.0, f), true)
	# Suckers along the inner edge
	for i in range(2, n, 2):
		var f = float(i) / n
		var p = pts[i] - side * lerp(3.5, 1.2, f)
		draw_circle(p, lerp(2.6, 1.3, f), Color(1.0, 0.92, 0.85, 0.9 * reach))
		draw_arc(p, lerp(2.6, 1.3, f), 0, TAU, 8, ink, 1.0, true)
	if letting_go:
		return
	# The club wraps round the held animal
	var wrap_r = er + 4.0
	var base_ang = (-dir).angle()
	var squeeze = 0.15 * sin(t * 12.0)
	draw_arc(b, wrap_r, base_ang - 2.2 - squeeze, base_ang + 2.2 + squeeze, 18, ink, 7.0, true)
	draw_arc(b, wrap_r, base_ang - 2.2 - squeeze, base_ang + 2.2 + squeeze, 18, body, 4.0, true)
	# A soft pulsing ring so a held animal reads at a glance
	var pulse = 0.5 + 0.5 * sin(t * 10.0)
	draw_arc(b, wrap_r + 8.0 + pulse * 3.0, 0, TAU, 28, Color(1.0, 0.75, 0.95, 0.35 + 0.25 * pulse), 2.0, true)
