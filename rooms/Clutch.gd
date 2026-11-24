# Clutch.gd
# Eggs, a scorpion brood or a burrow of young (data/SpecialRooms.gd "nest").
# Walk into it to eat it: a big meal. SpecialRoom.gd then brings the parent.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)

var floor_num: int = 2
var taken: bool = false
var own: bool = false # your own clutch (Room.add_clutch): yours, not food
var on_taken: Callable = Callable()
var player: Node2D = null
var time: float = 0.0
var eggs: Array = [] # [pos, size]

func _ready():
	z_index = -2
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = floor_num * 811
	var era = preload("res://data/Worlds.gd").era(floor_num)
	var n = 4 if era == 5 else (7 if era == 6 else 14)
	if own:
		rng.seed = int(position.x * 7.0 + position.y * 13.0)
		n = 9
	for i in n:
		var a = rng.randf() * TAU
		var d = sqrt(rng.randf()) * 52.0
		eggs.append([Vector2.from_angle(a) * Vector2(d, d * 0.75), rng.randf_range(9.0, 13.0) * (1.8 if era == 5 and not own else (1.4 if era == 6 and not own else 1.0))])
	eggs.sort_custom(func(a, b): return a[0].y < b[0].y)

func _process(delta: float):
	time += delta
	queue_redraw()
	if own or taken or not player or not is_instance_valid(player) or player.health <= 0:
		return
	if player.global_position.distance_to(global_position) < 95.0:
		taken = true
		SoundManager.play_sfx("atk_bite", 0.9, -2.0)
		HitFX.pop(get_parent(), global_position, Color(0.95, 0.9, 0.75), 30.0, 180.0, 0.4)
		if on_taken.is_valid():
			on_taken.call()

func _draw():
	# The nest: a scraped hollow (burrow mouth on land in the Permian)
	var hollow := PackedVector2Array()
	for i in 24:
		var a = TAU * i / 24.0
		hollow.append(Vector2.from_angle(a) * Vector2(95, 70) * (1.0 + 0.06 * sin(a * 5.0)))
	if own:
		for i in hollow.size():
			hollow[i] *= 0.62
	draw_colored_polygon(hollow, Color(0.55, 0.45, 0.34, 0.45) if floor_num == 5 else Color(0.7, 0.64, 0.52, 0.4))
	hollow.append(hollow[0])
	draw_polyline(hollow, Color(INK, 0.7), 2.2, true)
	var rim = 0.62 if own else 1.0
	for i in 10:
		var a = TAU * i / 10.0 + 0.3
		draw_line(Vector2.from_angle(a) * Vector2(98, 73) * rim, Vector2.from_angle(a) * Vector2(112, 84) * rim, Color(INK, 0.45), 1.6, true)
	if taken:
		# Broken shells left behind
		for e in eggs.slice(0, 5):
			draw_arc(e[0], e[1] * 0.8, 0.3, PI + 0.3, 8, Color(INK, 0.55), 1.4, true)
		return
	var label = SR.NESTS.get(preload("res://data/Worlds.gd").era(floor_num), SR.NESTS[2]).label
	for i in eggs.size():
		var e = eggs[i]
		var p: Vector2 = e[0]
		var s: float = e[1]
		var wob = sin(time * 2.0 + i) * 0.8
		match (0 if own else preload("res://data/Worlds.gd").era(floor_num)):
			4:
				# Scorplings: pale little scorpions, tails curled
				draw_circle(p, s * 0.6, Color(0.96, 0.93, 0.85))
				draw_arc(p, s * 0.6, 0, TAU, 10, Color(INK, 0.8), 1.2, true)
				draw_arc(p + Vector2(s * 0.7, -s * 0.2), s * 0.5, PI * 0.5, PI * 1.8 + wob * 0.1, 8, Color(INK, 0.8), 1.4, true)
			5:
				# Young dicynodonts curled up asleep
				draw_circle(p, s, Color(0.88, 0.8, 0.66))
				draw_arc(p, s, 0, TAU, 16, Color(INK, 0.85), 1.8, true)
				draw_arc(p + Vector2(s * 0.3, 0), s * 0.55, -1.2 + wob * 0.05, 1.4, 10, Color(INK, 0.7), 1.4, true)
				draw_circle(p + Vector2(s * 0.62, -s * 0.15), 1.8, INK)
			6:
				# Shark egg cases: dark horny purses wound in a spiral collar
				var rot = 0.6 * sin(i * 2.3)
				var body := PackedVector2Array()
				for k in 14:
					var a = TAU * k / 14.0
					body.append(p + Vector2(cos(a) * s * 1.5, sin(a) * s * 0.55).rotated(rot))
				draw_colored_polygon(body, Color(0.36, 0.28, 0.18, 0.95))
				body.append(body[0])
				draw_polyline(body, Color(INK, 0.9), 1.4, true)
				for k in 5:
					var x = (k - 2) * s * 0.55
					draw_line(p + Vector2(x - s * 0.2, -s * 0.5).rotated(rot), p + Vector2(x + s * 0.2, s * 0.5).rotated(rot), Color(0.75, 0.62, 0.42, 0.8), 1.2, true)
				draw_line(p + Vector2(s * 1.5, 0).rotated(rot), p + Vector2(s * 2.2, -s * 0.4 + wob).rotated(rot), Color(INK, 0.8), 1.3, true)
			_:
				# Eggs: pale and glossy, with the embryo's dark eye showing
				var pts := PackedVector2Array()
				for k in 12:
					pts.append(p + Vector2.from_angle(TAU * k / 12.0) * Vector2(s, s * 0.85))
				draw_colored_polygon(pts, Color(0.97, 0.94, 0.84, 0.95))
				pts.append(pts[0])
				draw_polyline(pts, Color(INK, 0.8), 1.3, true)
				draw_circle(p + Vector2(s * 0.2, -s * 0.15), 1.8, Color(INK, 0.7))
	if not own:
		SR.draw_label(self, Vector2(0, -105), "TAKE THE " + label, 24)
