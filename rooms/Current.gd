# Current.gd
# A strong current (data/SpecialRooms.gd "current"): Ordovician seas were
# full of graptolites, little colonies of filter feeders strung along
# saw-toothed branches, drifting in the plankton wherever the water took
# them. Here a current sweeps through the room, pushing you and the
# animals alike, and swings round every few seconds; graptolite colonies
# drift with it, a mouthful each. Swim with the current to fly, against it
# to crawl, and use it to bring the animals to you.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const PUSH := 95.0          # px/s the current carries everything
const TURN_EVERY := 9.0     # seconds between swings of the current
const TURN_TIME := 1.6      # seconds a swing takes
const COLONIES := 7
const COLONY_UNITS := 0.3
const STREAKS := 46

var floor_num: int = 3
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var angle: float = 0.0      # the current's heading
var from_angle: float = 0.0
var to_angle: float = 0.0
var turn_t: float = 1.0
var next_turn: float = TURN_EVERY
var streaks: Array = []     # [pos, length, phase]
var colonies: Array = []    # {pos, spin, stipes, eaten}
var area: Rect2

func _ready():
	z_index = -3
	player = get_tree().get_first_node_in_group("player")
	area = room.interior_rect(30.0)
	angle = float(state.get("angle", randf() * TAU))
	to_angle = angle
	for i in STREAKS:
		streaks.append([_rand_point(), randf_range(30.0, 70.0), randf() * TAU])
	var left = int(state.get("colonies", COLONIES))
	state["colonies"] = left
	for i in left:
		colonies.append({"pos": _rand_point(), "spin": randf() * TAU, "stipes": 2 + (i % 3) * 2, "eaten": false})

func _rand_point() -> Vector2:
	return Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))

func flow() -> Vector2:
	return Vector2.from_angle(angle) * PUSH

func _wrap(p: Vector2) -> Vector2:
	return Vector2(fposmod(p.x - area.position.x, area.size.x) + area.position.x, fposmod(p.y - area.position.y, area.size.y) + area.position.y)

func _physics_process(delta: float):
	time += delta
	next_turn -= delta
	if next_turn <= 0.0:
		next_turn = TURN_EVERY
		from_angle = angle
		to_angle = angle + randf_range(PI * 0.5, PI * 1.2) * (1.0 if randf() < 0.5 else -1.0)
		turn_t = 0.0
	if turn_t < 1.0:
		turn_t = min(1.0, turn_t + delta / TURN_TIME)
		angle = lerp_angle(from_angle, to_angle, smoothstep(0.0, 1.0, turn_t))
		state["angle"] = angle
	var push = flow() * delta
	# Everyone is carried, against the walls and rocks like anything else
	if player and is_instance_valid(player) and player.health > 0 and player.get("is_dashing") != true:
		player.move_and_collide(push)
	for e in room.active_enemies:
		if is_instance_valid(e) and not e.dead and e is CharacterBody2D and not (e.has_method("is_boss") and e.is_boss()):
			e.move_and_collide(push * 0.8)
	# Graptolites drift and turn slowly; touch one to eat it
	var pp = player.global_position - global_position if player and is_instance_valid(player) else Vector2(-9999, -9999)
	for c in colonies:
		if c.eaten:
			continue
		c.pos = _wrap(c.pos + push * 1.1)
		c.spin += delta * 0.4
		if c.pos.distance_to(pp) < 48.0:
			c.eaten = true
			state["colonies"] = max(0, int(state.get("colonies", 0)) - 1)
			SR.spill(room, c.pos, ["P"], COLONY_UNITS, 1)
	for s in streaks:
		s[0] = _wrap(s[0] + push * 2.2)
		s[2] += delta * 3.0
	queue_redraw()

func _draw():
	var d = Vector2.from_angle(angle)
	var n = d.orthogonal()
	# Streaks in the water show which way it runs
	for s in streaks:
		var wob = n * sin(s[2]) * 4.0
		draw_line(s[0] - d * s[1] + wob, s[0] + wob, Color(INK, 0.55), 2.4, true)
		draw_line(s[0] + wob, s[0] + wob - d * 12.0 + n * 7.0, Color(INK, 0.55), 2.2, true)
	# Graptolite colonies: a few saw-toothed branches (stipes) from a thread
	for c in colonies:
		if c.eaten:
			continue
		_draw_colony(c)

func _draw_colony(c: Dictionary):
	var p: Vector2 = c.pos
	var k: int = c.stipes
	# The nema, the thread it hung from
	draw_line(p, p + Vector2.from_angle(c.spin - PI / 2) * 22.0, Color(INK, 0.7), 1.2, true)
	for i in k:
		var a = c.spin + TAU * i / k
		var dir = Vector2.from_angle(a)
		var side = dir.orthogonal()
		var length = 34.0
		draw_line(p, p + dir * length, INK, 2.2, true)
		# Thecae: little cups all along one side, like saw teeth
		for j in 6:
			var b = p + dir * (6.0 + j * 5.0)
			draw_polyline(PackedVector2Array([b, b + side * 5.0 + dir * 2.5, b + dir * 5.0]), Color(INK, 0.85), 1.3, true)
