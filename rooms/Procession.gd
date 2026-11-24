# Procession.gd
# A trilobite procession (data/SpecialRooms.gd "procession"): a line of the
# little blind trilobite Ampyx walking nose to tail along a winding path, each
# one feeling the one in front with its long spines, as they were found
# buried at Fezouata, Morocco. They don't see you. Eat them from the back of
# the line and the rest walk on, none the wiser, and each makes a richer meal;
# hit one in the middle, or bump into the line, and it breaks: they scatter
# and run like any other startled prey.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const COUNT := 12
const SPACING := 62.0     # px of path between one and the next
const PACE := 70.0        # px/s along the path
const QUIET_WORTH := 1.5  # a kill taken quietly from the back
const TOUCH := 40.0       # bumping the line this close breaks it

var floor_num: int = 3
var room: Node2D = null
var state: Dictionary = {}
var line: Array = []      # Ampyx, leader first
var path: PackedVector2Array = PackedVector2Array()
var path_len: float = 0.0
var head: float = 0.0     # distance of the leader along the path
var broken: bool = false
var player: Node2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	_build_path()
	# The way they walk is clear ground: no rocks across the path
	for c in room.get_children():
		if c.is_in_group("obstacles") and c is Node2D:
			for i in range(0, path.size(), 2):
				if path[i].distance_to(c.position) < 110.0:
					c.queue_free()
					break
	var n = int(state.get("left", COUNT))
	state["left"] = n
	head = SPACING * n
	for i in n:
		room.spawn_enemy(_at(head - SPACING * i), "skittish@Isotelus", floor_num)
		var e = room.active_enemies.back()
		_make_ampyx(e)
		line.append(e)
		e.enemy_died.connect(_on_died.bind(e))
	for e in line:
		e.set_physics_process(false)

# A wide loop round the room, wavy so the line snakes as it goes
func _build_path():
	var c = Vector2(960, 540)
	var n = 160
	for i in n + 1:
		var t = TAU * i / n
		var r = Vector2(620.0, 300.0) * (1.0 + 0.12 * sin(t * 3.0))
		path.append(c + Vector2(cos(t) * r.x, sin(t) * r.y))
	path_len = 0.0
	for i in range(1, path.size()):
		path_len += path[i].distance_to(path[i - 1])

func _at(d: float) -> Vector2:
	d = fposmod(d, path_len)
	for i in range(1, path.size()):
		var seg = path[i].distance_to(path[i - 1])
		if d <= seg:
			return path[i - 1].lerp(path[i], d / max(seg, 0.001))
		d -= seg
	return path[0]

# Ampyx: small, blind, with a long spine forward from the head and two
# trailing behind (drawn over Isotelus's body plan, a trilobite of the same
# seas)
func _make_ampyx(e: Node2D):
	e.fauna_name = "Ampyx"
	e.base_scale *= 0.55
	var spr: Sprite2D = e.get_node("Sprite2D")
	spr.scale = Vector2.ONE * e.base_scale
	e.get_node("CollisionShape2D").shape.radius *= 0.55
	e.worth_override = 1.0
	e.set_meta("trace_id", "cruziana")
	var spines = Node2D.new()
	spines.name = "Spines"
	spines.draw.connect(_draw_spines.bind(spines, spr))
	spr.add_child(spines)

func _draw_spines(ci: Node2D, spr: Sprite2D):
	var fh = 128.0
	if spr.texture:
		fh = spr.texture.get_height()
	var h = fh * 0.34
	var ink = Color(INK, 0.95)
	# Forward spine from the glabella, as long as the body
	ci.draw_line(Vector2(0, -h * 0.75), Vector2(0, -h * 1.9), ink, 4.0, true)
	# Two genal spines sweeping back past the tail
	for s in [-1.0, 1.0]:
		ci.draw_polyline(PackedVector2Array([Vector2(s * h * 0.55, -h * 0.35), Vector2(s * h * 0.7, h * 0.4), Vector2(s * h * 0.6, h * 1.5)]), ink, 3.5, true)

func _process(delta: float):
	if broken:
		return
	line = line.filter(func(e): return is_instance_valid(e) and not e.dead)
	if line.is_empty():
		return
	head += PACE * delta
	for i in line.size():
		var e = line[i]
		var d = head - SPACING * i
		var p = _at(d)
		var ahead = _at(d + 8.0)
		e.position = p
		e.get_node("Sprite2D").rotation = (ahead - p).angle() + PI / 2
		e.velocity = (ahead - p).normalized() * PACE
		e.worth_override = QUIET_WORTH if i == line.size() - 1 else 1.0
		# Hurt, or bumped: whoever it was, the line breaks
		if e.health < e.max_health and i != line.size() - 1:
			_break(e)
			return
	if player and is_instance_valid(player) and player.health > 0:
		for e in line.slice(0, line.size() - 1): # the tail can be crept up on
			if e.global_position.distance_to(player.global_position) < TOUCH + e.get_node("CollisionShape2D").shape.radius:
				_break(e)
				return

# The last in line was taken quietly: the rest walk on
func _on_died(e: Node2D):
	state["left"] = max(0, int(state.get("left", 0)) - 1)
	if broken:
		return
	var alive = line.filter(func(x): return is_instance_valid(x) and not x.dead and x != e)
	if line.find(e) == line.size() - 1:
		# Close the gap: the tail just ends one sooner
		if player and is_instance_valid(player) and not alive.is_empty():
			player.popup_text(e.global_position + Vector2(0, -50), "UNNOTICED", Color(0.9, 0.85, 0.65))
	else:
		_break(e)

func _break(at: Node2D):
	if broken:
		return
	broken = true
	state["broken"] = true
	if player and is_instance_valid(player) and is_instance_valid(at):
		player.popup_text(at.global_position + Vector2(0, -60), "THE LINE BREAKS!", Color(0.98, 0.76, 0.38))
	for e in line:
		if is_instance_valid(e) and not e.dead:
			e.worth_override = 1.0
			e.set_physics_process(true)
			e.flee_timer = randf_range(0.1, 0.5)
			e.wander_dir = Vector2.from_angle(randf() * TAU)
