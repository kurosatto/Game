# Vent.gd
# A hydrothermal vent (sea eras) or a hot spring (on land), drawn in pen and
# ink. Resting in the warm ring around it heals you a little at a time, up to
# HEAL_BUDGET half-hearts per vent; right at the mouth the water scalds.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)

const SCALD_R := 100.0
const WARM_R := 270.0
const HEAL_EVERY := 1.3
const HEAL_BUDGET := 6 # half-hearts: three hearts per vent

var floor_num: int = 1
var heal_left: int = HEAL_BUDGET
var on_heal: Callable = Callable()
var player: Node2D = null
var time: float = 0.0
var warm_time: float = 0.0
var scald_cd: float = 0.0
var puffs: Array = [] # [pos, age, size]
var tubes: Array = []
var told_hot: bool = false
var pen = preload("res://InkBatch.gd").new() # the vent in one draw call

func _ready():
	z_index = -2
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = floor_num * 4513
	for i in 16:
		var a = rng.randf() * TAU
		var d = rng.randf_range(130.0, 230.0)
		tubes.append([Vector2.from_angle(a) * Vector2(d, d * 0.7), rng.randf_range(10.0, 22.0), rng.randf_range(-0.6, 0.6)])

func land() -> bool:
	return SR.is_land(floor_num)

func _process(delta: float):
	time += delta
	scald_cd = max(0.0, scald_cd - delta)
	# The plume: ink-wash puffs that rise, swell and fade
	if randf() < delta * (9.0 if not land() else 5.0):
		puffs.append([Vector2(randf_range(-8, 8), -10), 0.0, randf_range(14.0, 22.0)])
	for p in puffs:
		p[1] += delta
		p[0] += Vector2(sin(time * 0.7 + p[2]) * 14.0, -60.0 if not land() else -35.0) * delta
	puffs = puffs.filter(func(p): return p[1] < 3.0)
	queue_redraw()
	if not player or not is_instance_valid(player) or player.health <= 0:
		return
	var d = player.global_position.distance_to(global_position)
	if d < SCALD_R:
		if scald_cd <= 0.0:
			scald_cd = 0.9
			player.take_damage(1, "a scalding vent")
			if not told_hot:
				told_hot = true
				player.popup_text(global_position + Vector2(0, -130), "TOO HOT!", Color(1.0, 0.55, 0.35))
			if player.has_method("apply_knockback"):
				player.apply_knockback((player.global_position - global_position).normalized() * 600.0)
			else:
				player.global_position = global_position + (player.global_position - global_position).normalized() * (SCALD_R + 20.0)
	elif d < WARM_R and heal_left > 0 and player.health < player.max_health:
		warm_time += delta
		if warm_time >= HEAL_EVERY:
			warm_time = 0.0
			heal_left -= 1
			player.heal(1)
			player.popup_text(player.global_position + Vector2(0, -60), "+½ ♥", Color(0.62, 0.93, 0.5))
			HitFX.pop(get_parent(), player.global_position, Color(1.0, 0.85, 0.6), 18.0, 90.0, 0.3)
			if on_heal.is_valid():
				on_heal.call(heal_left)
	else:
		warm_time = 0.0

func _draw():
	pen.begin(self)
	var warm = heal_left > 0
	# Warm ring: a dashed circle where it's good to rest
	var segs = 36
	for i in segs:
		if i % 2 == 0:
			var a0 = TAU * i / segs + time * 0.05
			pen.draw_arc(Vector2.ZERO, WARM_R, a0, a0 + TAU / segs, 6, Color(INK, 0.45 if warm else 0.18), 2.2, true)
	if land():
		_draw_spring()
	else:
		_draw_smoker()
	# Heat shimmer at the mouth: the scald zone
	for k in 3:
		var pts := PackedVector2Array()
		var r = SCALD_R - 6.0 - k * 9.0
		for i in 41:
			var a = TAU * i / 40.0
			pts.append(Vector2.from_angle(a) * (r + sin(a * 9.0 + time * 4.0 + k) * 4.0))
		pen.draw_polyline(pts, Color(0.55, 0.22, 0.1, 0.5 - k * 0.12), 1.6, true)
	pen.flush()
	SR.draw_label(self, Vector2(0, -WARM_R - 14), "WARM: REST HERE" if warm else "COOLED", 24, 0.9 if warm else 0.55)
	SR.draw_label(self, Vector2(0, SCALD_R + 36), "TOO HOT", 20, 0.8)

func _draw_smoker():
	# Tube worms and shells on the warm ground around the vent
	for t in tubes:
		var dir = Vector2.UP.rotated(t[2])
		var base: Vector2 = t[0]
		var tip = base + dir * t[1] + Vector2(sin(time * 1.5 + base.x) * 2.0, 0)
		pen.draw_line(base, tip, Color(0.92, 0.88, 0.78), 5.0, true)
		pen.draw_line(base, tip, Color(INK, 0.8), 1.4, true)
		pen.draw_circle(tip, 3.6, Color(0.78, 0.42, 0.32, 0.9))
		pen.draw_arc(tip, 3.6, 0, TAU, 10, Color(INK, 0.8), 1.2, true)
	# The chimney mound: rough rock, cross-hatched, with a dark mouth
	var mound := PackedVector2Array()
	for i in 20:
		var a = TAU * i / 20.0
		mound.append(Vector2.from_angle(a) * (74.0 + sin(a * 5.0) * 7.0 + sin(a * 11.0) * 3.0))
	pen.draw_colored_polygon(mound, Color(0.62, 0.55, 0.47, 0.95))
	mound.append(mound[0])
	pen.draw_polyline(mound, Color(INK, 0.9), 2.6, true)
	for i in range(-6, 7):
		var x = i * 11.0
		var h = 66.0 * sqrt(max(0.0, 1.0 - pow(x / 72.0, 2)))
		pen.draw_line(Vector2(x - 8, -h * 0.8), Vector2(x + 8, h * 0.8), Color(INK, 0.3), 1.1, true)
	pen.draw_circle(Vector2.ZERO, 24.0, Color(0.12, 0.08, 0.05, 0.95))
	pen.draw_arc(Vector2.ZERO, 24.0, 0, TAU, 20, Color(INK), 2.0, true)
	# The black smoke: ink-wash billows
	for p in puffs:
		var t = p[1] / 3.0
		var r = p[2] * (1.0 + t * 2.2)
		pen.draw_circle(p[0], r, Color(0.16, 0.11, 0.08, 0.5 * (1.0 - t)))
		pen.draw_arc(p[0], r, 0, TAU, 16, Color(INK, 0.35 * (1.0 - t)), 1.2, true)

func _draw_spring():
	# Terraces of mineral crust, then the pool, then bubbles at the mouth
	for k in 4:
		var pts := PackedVector2Array()
		var r = 150.0 - k * 26.0
		for i in 32:
			var a = TAU * i / 32.0
			pts.append(Vector2.from_angle(a) * (r + sin(a * 6.0 + k) * 6.0) * Vector2(1.0, 0.8))
		pen.draw_colored_polygon(pts, Color(0.88, 0.8, 0.62, 0.35) if k < 2 else Color(0.62, 0.72, 0.7, 0.55))
		pts.append(pts[0])
		pen.draw_polyline(pts, Color(INK, 0.55 + k * 0.1), 1.8, true)
	for i in 6:
		var t = fmod(time * 0.8 + i * 0.29, 1.0)
		var p = Vector2(sin(i * 2.1) * 30.0, cos(i * 1.7) * 18.0)
		pen.draw_arc(p, 3.0 + 6.0 * t, 0, TAU, 12, Color(INK, 0.6 * (1.0 - t)), 1.4, true)
	# Steam wisps
	for p in puffs:
		var t = p[1] / 3.0
		var pts := PackedVector2Array()
		for j in 8:
			pts.append(p[0] + Vector2(sin(j * 0.9 + time * 2.0 + p[2]) * 8.0, -j * 6.0))
		pen.draw_polyline(pts, Color(INK, 0.35 * (1.0 - t)), 1.6, true)
