# MoltGathering.gd
# A mass molt (data/SpecialRooms.gd "molt"): a crowd of trilobites gathered
# to shed their shells. Before it molts a trilobite's armour turns most of a
# blow; every couple of seconds one splits its old shell, crawls out and is
# soft for a few seconds, an easy meal, before the new shell hardens. The
# empty moults stay on the floor, with a little calcium to eat from them.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const INK = Color(0.24, 0.15, 0.08)
const EVERY := 1.9        # seconds between molts
const SOFT_TIME := 6.0    # seconds a fresh molt stays soft
const HARD_MULT := 0.35   # damage while still in the old shell
const SOFT_MULT := 3.0    # damage while soft
const SHELL_CA := 0.6     # calcium spilt by each moult
const SOFT_TINT := Color(1.0, 0.92, 0.88, 0.6) # new cuticle: pale and thin

var floor_num: int = 2
var room: Node2D = null
var crowd: Array = []
var timer: float = 1.4
var soft: Dictionary = {} # animal -> seconds of softness left
var shells: Array = []    # [pos, rot, scale, texture, frame, hframes, age]
var time: float = 0.0

var rings: Node2D = null # drawn over the animals

func _ready():
	z_index = -2 # moults lie on the floor, under the animals
	rings = Node2D.new()
	rings.z_as_relative = false
	rings.z_index = 3
	rings.draw.connect(_draw_rings)
	add_child(rings)
	for e in crowd:
		if is_instance_valid(e):
			e.speed *= 0.4 # packed in, shuffling
			e.set_meta("hit_mult", HARD_MULT)
			e.set_meta("molted", false)

func _process(delta: float):
	time += delta
	for s in shells:
		s[6] += delta
	timer -= delta
	if timer <= 0.0:
		timer = EVERY * randf_range(0.8, 1.2)
		var waiting = crowd.filter(func(e): return is_instance_valid(e) and not e.dead and not e.get_meta("molted", false))
		if not waiting.is_empty():
			_molt(waiting.pick_random())
	for e in soft.keys():
		if not is_instance_valid(e) or e.dead:
			soft.erase(e)
			continue
		soft[e] -= delta
		if soft[e] <= 0.0:
			# The new shell has hardened
			soft.erase(e)
			e.set_meta("hit_mult", 1.0)
			e.base_tint = e.get_meta("hard_tint", Color.WHITE)
			e.speed /= 0.6
			e.get_node("Sprite2D").modulate = e.base_tint
	queue_redraw()
	rings.queue_redraw()

func _molt(e: Node2D):
	var spr: Sprite2D = e.get_node("Sprite2D")
	# The empty shell stays where it was, split down the back
	shells.append([e.position, spr.rotation, spr.scale, spr.texture, spr.frame, spr.hframes, 0.0])
	SR.spill(room, e.position, ["Ca"], SHELL_CA, 2)
	# It crawls out forward, pale and soft
	var fwd = Vector2.UP.rotated(spr.rotation)
	var tw = e.create_tween()
	tw.tween_property(e, "position", e.position + fwd * 90.0, 0.5).set_trans(Tween.TRANS_SINE)
	e.set_meta("molted", true)
	e.set_meta("hit_mult", SOFT_MULT)
	e.set_meta("hard_tint", e.base_tint)
	e.base_tint = e.base_tint * SOFT_TINT
	spr.modulate = e.base_tint
	e.speed *= 0.6
	soft[e] = SOFT_TIME
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("popup_text"):
		player.popup_text(e.global_position + Vector2(0, -60), "SOFT!", Color(0.98, 0.78, 0.7))
	var snd = get_node_or_null("/root/SoundManager")
	if snd:
		snd.play_sfx("hit_glance", 0.7, -8.0)

func _draw():
	for s in shells:
		var a = clamp(1.0 - (s[6] - 40.0) / 5.0, 0.0, 1.0) # old moults sink into the mud
		var sc: float = s[2].x
		draw_set_transform(s[0], s[1], Vector2(sc, sc))
		_draw_moult(a)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# An empty trilobite moult, head up: the shield, the three lobes and the
# rings of the thorax, split open along the back where it climbed out
func _draw_moult(a: float):
	var fill = Color(0.78, 0.7, 0.56, 0.55 * a)
	var ink = Color(INK, 0.85 * a)
	var body := PackedVector2Array()
	for i in 20:
		var t = TAU * i / 20.0
		var y = sin(t) * 44.0
		var x = cos(t) * (30.0 if y < -14.0 else 26.0 - max(0.0, y) * 0.3)
		body.append(Vector2(x, y))
	draw_colored_polygon(body, fill)
	body.append(body[0])
	draw_polyline(body, ink, 2.2, true)
	# Head shield edge and the genal spines
	draw_line(Vector2(-29.0, -14.0), Vector2(29.0, -14.0), ink, 1.8, true)
	draw_line(Vector2(-29.0, -14.0), Vector2(-36.0, 6.0), ink, 1.8, true)
	draw_line(Vector2(29.0, -14.0), Vector2(36.0, 6.0), ink, 1.8, true)
	# Axial lobe, split down the middle
	draw_line(Vector2(-8.0, -38.0), Vector2(-7.0, 38.0), Color(INK, 0.6 * a), 1.4, true)
	draw_line(Vector2(8.0, -38.0), Vector2(7.0, 38.0), Color(INK, 0.6 * a), 1.4, true)
	draw_polyline(PackedVector2Array([Vector2(0, -40.0), Vector2(2.0, -20.0), Vector2(-1.5, -4.0), Vector2(1.5, 10.0)]), ink, 2.4, true)
	# Thorax rings
	for k in 6:
		var y = -8.0 + k * 7.5
		draw_line(Vector2(-24.0 + k * 1.2, y), Vector2(24.0 - k * 1.2, y), Color(INK, 0.5 * a), 1.2, true)

# Soft ones: a broken ink ring that turns and pulses, so you can pick them out
func _draw_rings():
	for e in soft:
		if is_instance_valid(e):
			var spr: Sprite2D = e.get_node("Sprite2D")
			var r = 26.0
			if spr.texture:
				r = spr.texture.get_width() / max(1, spr.hframes) * spr.scale.x * 0.36
			r += 4.0 * sin(time * 5.0)
			for k in 8:
				var a0 = TAU * k / 8.0 + time * 0.8
				rings.draw_arc(e.position, r, a0, a0 + TAU / 16.0, 6, Color(INK, 0.85), 3.5, true)
