# FieldSketch.gd
# Sketching from life, the way naturalists always have. Hold still near an
# animal that has not noticed you and an ink ring is drawn round it, stroke
# by stroke. Finish before it notices you and the sketch goes in the book:
# for the rest of the run you know how it moves and where it is soft, so your
# blows on its kind land harder (Enemy.take_damage), and the fossil record
# keeps the sketch even if you never eat one. Moving lets the drawing slip
# back; if it notices you, the sketch is spoilt. Hiding in cover (Cover.gd)
# and holding still both keep animals from noticing you.
extends Node2D

const FAUNA = preload("res://data/Fauna.gd")
const INK = Color(0.24, 0.15, 0.08)
const RANGE := 400.0      # how far off you can sketch from
const TIME := 2.6         # seconds of stillness to finish one
const STILL := 45.0       # px/s: slower than this counts as holding still
const BONUS := 1.25       # damage to a sketched kind (Enemy.take_damage)

var room: Node2D = null
var player: Node2D = null
var target: Node2D = null
var progress: float = 0.0
var time: float = 0.0
var _done_flash: float = 0.0
var _done_at: Vector2 = Vector2.ZERO
var _done_r: float = 0.0

func _ready():
	z_index = 15
	add_to_group("field_sketch")
	player = get_tree().get_first_node_in_group("player")

static func can_sketch(e, p) -> bool:
	if not is_instance_valid(e) or e.get("dead") or e.get("mood") != "calm":
		return false
	var nm = String(e.get("fauna_name")) if e.get("fauna_name") != null else ""
	if nm == "" or p.sketched.has(nm):
		return false
	if e.has_method("is_boss") and e.is_boss():
		return false
	if e.has_method("is_burrowed") and e.is_burrowed():
		return false
	return true

func _process(delta: float):
	time += delta
	_done_flash = max(0.0, _done_flash - delta)
	if room == null or player == null or not is_instance_valid(player) or player.health <= 0 or not ("sketched" in player):
		target = null
		queue_redraw()
		return
	# Spoilt: it noticed you or went
	if target and not (is_instance_valid(target) and target.get("mood") == "calm" and not target.get("dead")):
		if is_instance_valid(target) and progress > 0.25:
			player.popup_text(target.global_position + Vector2(0, -60), "SPOILT", Color(0.85, 0.7, 0.55))
		target = null
		progress = 0.0
	# The nearest calm animal not yet sketched this run
	var best: Node2D = null
	var best_d := RANGE
	for e in room.active_enemies:
		if is_instance_valid(e) and can_sketch(e, player):
			var d = e.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = e
	if best != target:
		# Keep the drawing going while it is still in range
		if target == null or not is_instance_valid(target) or target.global_position.distance_to(player.global_position) > RANGE:
			target = best
			progress = 0.0
	if target == null:
		queue_redraw()
		return
	var still = player.velocity.length() < STILL
	if still:
		progress += delta / TIME
	else:
		progress = max(0.0, progress - delta * 0.6)
	if progress >= 1.0:
		_finish(target)
		target = null
		progress = 0.0
	queue_redraw()

func _finish(e: Node2D):
	var nm = String(e.fauna_name)
	player.sketched[nm] = true
	preload("res://data/Codex.gd").note_sketch(nm)
	_done_flash = 0.9
	_done_at = e.global_position - global_position
	_done_r = _ring_r(e)
	player.popup_text(e.global_position + Vector2(0, -70), "SKETCHED", Color(0.95, 0.88, 0.7))
	var snd = get_node_or_null("/root/SoundManager")
	if snd:
		snd.play_sfx("dna_pickup", 1.3, -4.0)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("note_sketch"):
		var f = FAUNA.get_species(main.floor_number, nm)
		main.note_sketch(nm, String(f.get("fact", "")))

func _ring_r(e: Node2D) -> float:
	var r = 26.0
	var shape = e.get_node_or_null("CollisionShape2D")
	if shape and shape.shape is CircleShape2D:
		r = shape.shape.radius
	return r * 1.5 + 18.0

func _draw():
	if target and is_instance_valid(target) and progress > 0.0:
		var c = target.global_position - global_position
		var r = _ring_r(target)
		var end = -PI * 0.5 + TAU * progress
		# Two loose pencil strokes, a little off each other, drawn on as it fills
		draw_arc(c, r, -PI * 0.5, end, 48, Color(INK, 0.85), 3.0, true)
		draw_arc(c + Vector2(1.5, -1.0), r + 3.0 + sin(time * 3.0), -PI * 0.5 + 0.08, end - 0.05, 48, Color(INK, 0.45), 1.6, true)
		# The pen nib at the end of the stroke
		var tip = c + Vector2.from_angle(end) * r
		var dir = Vector2.from_angle(end + PI * 0.5)
		var nib = PackedVector2Array([tip, tip - dir * 16.0 + dir.orthogonal() * 4.0, tip - dir * 16.0 - dir.orthogonal() * 4.0])
		draw_colored_polygon(nib, Color(0.95, 0.9, 0.78))
		nib.append(nib[0])
		draw_polyline(nib, Color(INK, 0.95), 1.6, true)
		# Hatching appears inside as the sketch fills in
		var n = int(progress * 8.0)
		for k in n:
			var a = -2.4 + k * 0.6
			var p0 = c + Vector2.from_angle(a) * (r - 6.0)
			draw_line(p0, p0 + Vector2(-7.0, 7.0), Color(INK, 0.4), 1.2, true)
	if _done_flash > 0.0:
		var a = _done_flash / 0.9
		draw_arc(_done_at, _done_r + (1.0 - a) * 24.0, 0.0, TAU, 48, Color(INK, 0.8 * a), 3.0, true)
