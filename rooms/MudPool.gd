# MudPool.gd
# Soft silt, mud or tar (by era, data/SpecialRooms.gd "tar"): everything in
# it, you and the animals alike, moves at half speed. Flying forms pass over.
# The middle pool can hold a trapped animal: stand beside it for a moment to
# pull it free, and it leaves you what it was made of.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const BIOMINERALS = preload("res://data/Biominerals.gd")
const INK = Color(0.24, 0.15, 0.08)

const SLOW := 0.5
const FREE_TIME := 1.6
const FREE_REACH := 120.0

var floor_num: int = 1
var size: Vector2 = Vector2(200, 120)
var seed_val: int = 0
var trapped_species: String = ""
var on_freed: Callable = Callable()

var player: Node2D = null
var time: float = 0.0
var outline := PackedVector2Array()
var marks: Array = []
var trapped: Node2D = null
var free_progress: float = 0.0
var freed: bool = false
var last_pos: Dictionary = {} # enemy instance id -> position after the last physics frame
var told: bool = false

func _ready():
	z_index = -3
	# After every animal has moved this frame, so their step can be halved
	process_physics_priority = 100
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	for i in 30:
		var a = TAU * i / 30.0
		var r = 1.0 + 0.08 * sin(a * 3.0 + rng.randf() * 6.0) + rng.randf_range(-0.04, 0.04)
		outline.append(Vector2.from_angle(a) * size * r)
	outline.append(outline[0])
	for i in 12:
		var a = rng.randf() * TAU
		var d = sqrt(rng.randf()) * 0.8
		marks.append([Vector2.from_angle(a) * size * d, rng.randf_range(0.6, 1.4), rng.randf() * TAU])
	if trapped_species != "":
		_spawn_trapped.call_deferred()

func _spawn_trapped():
	var sp = SR.species(floor_num, trapped_species)
	var type = "pacer"
	if sp.has("type"):
		type = sp.type
	else:
		for t in ["fly", "pacer"] + preload("res://data/Fauna.gd").special_types(floor_num):
			if preload("res://data/Fauna.gd").get_fauna(floor_num, t).get("name", "") == trapped_species:
				type = t
	trapped = preload("res://rooms/SpecialRoom.gd").make_puppet(get_parent(), floor_num, trapped_species, type, position)
	trapped.z_index = -1

func tar() -> bool:
	return preload("res://data/Worlds.gd").era(floor_num) == 5

func covers(pos: Vector2, pad: float = 0.0) -> bool:
	var d = pos - global_position
	var sx = size.x + pad
	var sy = size.y + pad
	return (d.x * d.x) / (sx * sx) + (d.y * d.y) / (sy * sy) <= 1.0

func _physics_process(delta: float):
	time += delta
	# Animals wade at half speed: undo half of each step taken in the mud
	var seen := {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead") or e.is_boss():
			continue
		var id = e.get_instance_id()
		seen[id] = true
		var p: Vector2 = e.global_position
		if last_pos.has(id) and covers(p) and not e.is_burrowed():
			var prev: Vector2 = last_pos[id]
			if prev.distance_to(p) < 60.0:
				e.global_position = prev + (p - prev) * SLOW
		last_pos[id] = e.global_position
	for id in last_pos.keys():
		if not seen.has(id):
			last_pos.erase(id)
	if not player or not is_instance_valid(player) or player.health <= 0:
		return
	if player.get("current_passive") != "flight" and covers(player.global_position):
		player.apply_slow(0.12, SLOW, "" if told else SR.title("tar", floor_num))
		told = true
	if trapped and not freed:
		_struggle(delta)

func _struggle(delta: float):
	# It heaves and sinks back; you pull it out by staying beside it
	trapped.rotation = sin(time * 3.0) * 0.12
	var spr = trapped.get_node("Sprite2D")
	spr.frame = int(fmod(time * 7.0, 4.0)) if spr.hframes == 4 else 0
	if player.global_position.distance_to(trapped.global_position) < FREE_REACH:
		free_progress += delta
		if free_progress >= FREE_TIME:
			free_it()
	else:
		free_progress = max(0.0, free_progress - delta * 0.5)

func free_it():
	freed = true
	if on_freed.is_valid():
		on_freed.call()
	var els = BIOMINERALS.fauna_elements(trapped_species)
	SR.spill(get_parent(), trapped.position, els, 4.0, 6)
	if player.has_method("heal"):
		player.heal(1)
	SoundManager.play_sfx("level_up", 1.3, -6.0)
	HitFX.pop(get_parent(), trapped.global_position, Color(0.78, 0.68, 0.5), 30.0, 180.0, 0.4)
	player.popup_text(trapped.global_position + Vector2(0, -110), "FREED!", Color(0.98, 0.82, 0.5))
	# Grateful, it follows you and hunts beside you for the rest of the era
	var c = preload("res://rooms/Companion.gd").new()
	c.floor_num = floor_num
	c.position = trapped.position
	c.start_joined = true
	get_parent().add_child(c)
	trapped.queue_free()

func _process(_delta: float):
	queue_redraw()

func _draw():
	var fill = Color(0.2, 0.15, 0.1, 0.55) if tar() else Color(0.5, 0.42, 0.32, 0.5)
	draw_colored_polygon(outline, fill)
	draw_polyline(outline, Color(INK, 0.85), 2.6, true)
	# Slow rings and a sheen; tar gets oily bubbles
	for m in marks:
		var t = fmod(time * 0.25 * m[1] + m[2], 1.0)
		draw_arc(m[0], 6.0 + 16.0 * t, 0, TAU, 14, Color(INK, 0.35 * (1.0 - t)), 1.3, true)
	for i in range(-6, 7):
		var x = i * size.x / 7.0
		var h = size.y * 0.8 * sqrt(max(0.0, 1.0 - pow(x / size.x, 2)))
		draw_line(Vector2(x - 6, -h * 0.5), Vector2(x + 14, -h * 0.5 + 6), Color(INK, 0.2), 1.2, true)
	if trapped and not freed:
		# Mud heaped round it, and how close it is to coming free
		var p = trapped.position - position
		draw_arc(p, 46.0, PI * 0.1, PI * 0.9, 16, Color(INK, 0.8), 3.0, true)
		draw_arc(p, 54.0, PI * 0.2, PI * 0.8, 16, Color(INK, 0.4), 2.0, true)
		if free_progress > 0.0:
			draw_arc(p, 70.0, -PI / 2, -PI / 2 + TAU * free_progress / FREE_TIME, 40, Color(0.35, 0.55, 0.25, 0.95), 6.0, true)
		SR.draw_label(self, p + Vector2(0, -88), "STUCK: FREE IT AND IT JOINS YOU", 22)
