# CupReef.gd
# An archaeocyath reef (data/SpecialRooms.gd "cupreef"): the first reefs
# built by animals, in the early Cambrian, were thickets of archaeocyaths,
# vase-shaped sponges with double, porous walls. Small animals sheltered in
# the cups. Here quick little Marrella hide in them and dart from cup to cup
# when you come close: you can't touch one inside its cup, so drive it out
# and catch it in the open.
extends Node2D

const INK = Color(0.24, 0.15, 0.08)
const CUPS := 9
const HIDERS := 6
const CUP_R := 34.0
const SPOOK := 150.0     # px: this close and whoever is inside bolts
const DART := 520.0      # px/s between cups
const REST := 0.6        # seconds a fresh arrival needs before it can bolt again

var floor_num: int = 2
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var cups: Array = []     # {pos, seed}
var hiders: Array = []   # {e, cup (index or -1), from, to, t, rest}

func _ready():
	z_index = -1
	player = get_tree().get_first_node_in_group("player")
	if not state.has("cups"):
		state["cups"] = _lay()
	cups = state.cups
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D and cups.any(func(q): return q.pos.distance_to(c.position) < 110.0):
			c.queue_free()
	for q in cups:
		var body = StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 0
		var col = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = CUP_R * 0.8
		col.shape = shape
		body.add_child(col)
		body.position = q.pos
		add_child(body)
	var n = int(state.get("hiders", HIDERS))
	state["hiders"] = n
	for i in n:
		var cup = i % cups.size()
		room.spawn_enemy(cups[cup].pos, "skittish@Marrella", floor_num)
		var e = room.active_enemies.back()
		e.set_physics_process(false)
		e.damage = 0
		e.enemy_died.connect(_on_died)
		var h = {"e": e, "cup": cup, "from": Vector2.ZERO, "to": Vector2.ZERO, "t": 0.0, "rest": 0.0, "next": -1}
		hiders.append(h)
		_hide(h, cup)

func _lay() -> Array:
	var out: Array = []
	var rng = RandomNumberGenerator.new()
	rng.seed = int(room.room_data.grid_pos.x * 37 + room.room_data.grid_pos.y * 19 + 7)
	var area = room.interior_rect(200.0)
	var doors = [Vector2(960, 128), Vector2(960, 952), Vector2(128 - room.side_margin, 540), Vector2(1792 + room.side_margin, 540)]
	for attempt in 300:
		if out.size() >= CUPS:
			break
		var p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if out.any(func(q): return q.pos.distance_to(p) < 215.0) or doors.any(func(d): return d.distance_to(p) < 260.0):
			continue
		out.append({"pos": p, "seed": rng.randi()})
	return out

func _hide(h: Dictionary, cup: int):
	var e = h.e
	h.cup = cup
	h.rest = REST
	e.position = cups[cup].pos
	e.visible = false
	e.remove_from_group("enemies") # out of reach inside the cup
	e.get_node("CollisionShape2D").set_deferred("disabled", true)

func _bolt(h: Dictionary):
	var e = h.e
	var pp = player.global_position - global_position
	# To the cup furthest from you that no one else is heading for
	var best = -1
	var best_d = -1.0
	for i in cups.size():
		if i == h.cup or hiders.any(func(o): return o != h and (o.cup == i or o.next == i)):
			continue
		var d = cups[i].pos.distance_to(pp) - cups[i].pos.distance_to(cups[h.cup].pos) * 0.4
		if d > best_d:
			best_d = d
			best = i
	if best < 0:
		return
	h.from = cups[h.cup].pos
	h.to = cups[best].pos
	h.next = best
	h.t = 0.0
	h.cup = -1
	e.visible = true
	e.add_to_group("enemies")
	e.get_node("CollisionShape2D").set_deferred("disabled", false)
	e.get_node("Sprite2D").rotation = (h.to - h.from).angle() + PI / 2

func hidden_count() -> int:
	return hiders.filter(func(h): return is_instance_valid(h.e) and not h.e.dead and h.cup >= 0).size()

func _physics_process(delta: float):
	time += delta
	var pp = player.global_position - global_position if player and is_instance_valid(player) and player.health > 0 else Vector2(-9999, -9999)
	for h in hiders:
		var e = h.e
		if not is_instance_valid(e) or e.dead:
			continue
		if h.cup >= 0:
			h.rest -= delta
			if h.rest <= 0.0 and cups[h.cup].pos.distance_to(pp) < SPOOK:
				_bolt(h)
			continue
		# Darting across open ground, a little zigzag as it goes
		var span = h.from.distance_to(h.to)
		h.t += DART * delta / max(span, 1.0)
		var side = (h.to - h.from).orthogonal().normalized() * sin(h.t * PI * 3.0) * 30.0 * (1.0 - h.t)
		e.position = h.from.lerp(h.to, min(1.0, h.t)) + side
		e.velocity = (h.to - h.from).normalized() * DART
		if h.t >= 1.0:
			var to = h.next
			h.next = -1
			_hide(h, to)

func _on_died():
	state["hiders"] = max(0, int(state.get("hiders", 0)) - 1)

func _process(_delta: float):
	queue_redraw()

func _draw():
	for q in cups:
		_draw_cup(q)

# An archaeocyath seen from above: two porous walls, one inside the other,
# joined by radial partitions, round a hollow middle
func _draw_cup(q: Dictionary):
	var p: Vector2 = q.pos
	var occupied = hiders.any(func(h): return is_instance_valid(h.e) and not h.e.dead and h.cup >= 0 and cups[h.cup] == q)
	draw_circle(p, CUP_R, Color(INK, 0.28))
	draw_arc(p, CUP_R, 0.0, TAU, 32, INK, 3.0, true)
	draw_arc(p, CUP_R * 0.55, 0.0, TAU, 24, INK, 2.2, true)
	draw_circle(p, CUP_R * 0.5, Color(INK, 0.6))
	for k in 16:
		var a = TAU * k / 16.0 + float(int(q.seed) % 100) * 0.01
		draw_line(p + Vector2.from_angle(a) * CUP_R * 0.57, p + Vector2.from_angle(a) * CUP_R * 0.97, Color(INK, 0.75), 1.4, true)
	# Pores in the outer wall
	for k in 12:
		var a = TAU * (k + 0.5) / 12.0
		draw_circle(p + Vector2.from_angle(a) * CUP_R * 0.8, 1.8, Color(INK, 0.8))
	# Someone at home: two antennae and a flick of the long head spines
	if occupied:
		var wig = sin(time * 6.0 + p.x) * 0.25
		for s in [-1.0, 1.0]:
			draw_line(p + Vector2(s * 4.0, -2.0), p + Vector2.from_angle(-PI / 2 + s * (0.5 + wig)) * CUP_R * 1.25, INK, 2.0, true)
