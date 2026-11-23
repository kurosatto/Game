# TideChannel.gd
# A tidal channel across the room (data/SpecialRooms.gd "tide"). The tide
# runs out, leaving rippled sand you can walk over, then floods back in and
# the channel becomes a strong current nothing can cross: the room is split
# in two, animals included. Flying forms pass over. The cycle is short and
# announced, so you can time a crossing.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)

const CX := 660.0 # clear of the top and bottom doors at x 896..1024
const HALF := 120.0
const LOW_T := 5.0
const RISE_T := 2.5
const HIGH_T := 6.0
const FALL_T := 2.5
const TOP := 128.0
const BOTTOM := 952.0

var floor_num: int = 1
var room: Node2D = null
var player: Node2D = null
var time: float = 0.0
var body: StaticBody2D = null
var shape: RectangleShape2D = null
var blocking: bool = false

func _ready():
	z_index = -3
	player = get_tree().get_first_node_in_group("player")
	body = StaticBody2D.new()
	body.collision_layer = 4 # with obstacles: fliers go over
	body.collision_mask = 0
	var col = CollisionShape2D.new()
	shape = RectangleShape2D.new()
	shape.size = Vector2(HALF * 2.0, BOTTOM - TOP)
	col.shape = shape
	body.add_child(col)
	body.position = Vector2(CX, (TOP + BOTTOM) / 2.0)
	add_child(body)
	body.process_mode = Node.PROCESS_MODE_DISABLED

func clear_obstacles():
	for c in room.get_children():
		if c.is_in_group("obstacles") and absf(c.position.x - CX) < HALF + 80.0:
			c.queue_free()

func cycle() -> float:
	return fmod(time, LOW_T + RISE_T + HIGH_T + FALL_T)

# Water level, 0 (low tide) to 1 (flood)
func level() -> float:
	var t = cycle()
	if t < LOW_T:
		return 0.0
	t -= LOW_T
	if t < RISE_T:
		return t / RISE_T
	t -= RISE_T
	if t < HIGH_T:
		return 1.0
	t -= HIGH_T
	return 1.0 - t / FALL_T

func in_band(p: Vector2, pad: float = 0.0) -> bool:
	return absf(p.x - CX) < HALF + pad and p.y > TOP and p.y < BOTTOM

func _physics_process(delta: float):
	time += delta
	var lv = level()
	var now_blocking = lv > 0.75
	if now_blocking != blocking:
		blocking = now_blocking
		body.process_mode = Node.PROCESS_MODE_INHERIT if blocking else Node.PROCESS_MODE_DISABLED
		if blocking:
			SoundManager.play_sfx("door_open", 0.5, -8.0)
	# The flood washes whatever is standing in it to the nearer bank
	if lv > 0.6:
		for e in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(e) and not e.get("dead") and in_band(e.global_position, 30.0):
				e.global_position.x = move_toward(e.global_position.x, CX + signf(e.global_position.x - CX + 0.01) * (HALF + 40.0), 600.0 * delta)
		if player and is_instance_valid(player) and player.get("current_passive") != "flight" and in_band(player.global_position, 26.0):
			player.global_position.x = move_toward(player.global_position.x, CX + signf(player.global_position.x - CX + 0.01) * (HALF + 36.0), 700.0 * delta)
	elif lv > 0.0 and player and is_instance_valid(player) and in_band(player.global_position) and player.get("current_passive") != "flight":
		player.apply_slow(0.12, 0.65, "")

func _process(_delta: float):
	queue_redraw()

func _draw():
	var lv = level()
	var w = HALF * (0.35 + 0.65 * lv)
	# Sand banks: always there, rippled by the last tide
	var sand = Rect2(CX - HALF - 20.0, TOP, (HALF + 20.0) * 2.0, BOTTOM - TOP)
	draw_rect(sand, Color(0.86, 0.79, 0.62, 0.45))
	for i in 18:
		var y = TOP + 20.0 + i * 45.0
		var pts := PackedVector2Array()
		for k in 13:
			var x = sand.position.x + 10.0 + k * (sand.size.x - 20.0) / 12.0
			pts.append(Vector2(x, y + sin(k * 1.3 + i) * 5.0))
		draw_polyline(pts, Color(INK, 0.28), 1.2, true)
	draw_line(Vector2(sand.position.x, TOP), Vector2(sand.position.x, BOTTOM), Color(INK, 0.5), 1.6, true)
	draw_line(Vector2(sand.end.x, TOP), Vector2(sand.end.x, BOTTOM), Color(INK, 0.5), 1.6, true)
	if lv > 0.0:
		var water = Rect2(CX - w, TOP, w * 2.0, BOTTOM - TOP)
		draw_rect(water, Color(0.42, 0.55, 0.58, 0.25 + 0.4 * lv))
		# Current lines streaming along the channel
		for i in 7:
			var x = CX - w + (i + 0.5) * w * 2.0 / 7.0
			var off = fmod(time * 160.0 + i * 70.0, 90.0)
			var y = TOP + off
			while y < BOTTOM - 30.0:
				draw_line(Vector2(x, y), Vector2(x + sin(y * 0.05 + i) * 6.0, y + 34.0), Color(INK, 0.25 + 0.4 * lv), 1.6, true)
				y += 90.0
		# Foam at the edges
		for side in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for k in 26:
				var y = TOP + k * (BOTTOM - TOP) / 25.0
				pts.append(Vector2(CX + side * (w + sin(k * 0.9 + time * 3.0) * 6.0), y))
			draw_polyline(pts, Color(INK, 0.7), 2.4, true)
	var t = cycle()
	var text = "LOW TIDE: CROSS NOW"
	if t >= LOW_T - 1.5 and t < LOW_T + RISE_T:
		text = "TIDE COMING IN"
	elif blocking:
		text = "HIGH TIDE"
	elif lv > 0.0:
		text = "TIDE GOING OUT"
	SR.draw_label(self, Vector2(CX, TOP + 40.0), text, 24)
