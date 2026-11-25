# TraceLayer.gd
# Tracks in the sediment (data/Traces.gd): every animal that walks, creeps
# or ploughs along the bottom leaves its own kind of trace behind it, and so
# do you. Marks fade after a few seconds. The first time you see a kind of
# trace being made it is named, like a trace fossil, and kept on the fossil
# record's TRACES page. One layer per room, on the floor under everyone.
extends Node2D

const Traces = preload("res://data/Traces.gd")
const LIFE := 8.0         # seconds an animal's mark lasts
const PLAYER_LIFE := 10.0 # your own last a little longer
const FADE := 2.5         # the last seconds of a mark fade out
const MAX_MARKS := 520
const NOTE_GAP := 5.0     # seconds between two "new trace" tags

static var _next_note: float = 0.0

var room: Node2D = null
var player: Node2D = null
var time: float = 0.0
# [pos (local), angle, side, phase, size, born, life, id]
var marks: Array = []
var walkers: Dictionary = {} # instance id -> {last, mark_at, dist, walked, side, id, size}
var seen_run: Dictionary = {} # trace ids noted, so the codex is not asked every mark

func _ready():
	z_index = -3
	add_to_group("trace_layer")
	player = get_tree().get_first_node_in_group("player")

func trace_of(e: Node) -> String:
	if e == player:
		# Your trace changes when you evolve
		var form = String(e.get("current_character_id"))
		if e.get_meta("trace_form", "") != form:
			e.set_meta("trace_form", form)
			e.set_meta("trace_id", Traces.for_form(form))
			walkers.erase(e.get_instance_id())
		return e.get_meta("trace_id")
	if e.has_meta("trace_id"):
		return e.get_meta("trace_id")
	var id = Traces.for_animal(animal_name(e), String(e.body_art.form_id) if e.get("body_art") else "")
	e.set_meta("trace_id", id)
	return id

static func animal_name(e: Node) -> String:
	var n = String(e.get("fauna_name")) if e.get("fauna_name") != null else ""
	if n == "" and e.get("boss_title") != null:
		n = String(e.boss_title).split(" —")[0].split(" ")[0].capitalize()
	return n

func _process(delta: float):
	time += delta
	if room == null:
		return
	if player and is_instance_valid(player):
		if player.health > 0:
			_step(player, PLAYER_LIFE)
	for e in room.active_enemies:
		if is_instance_valid(e) and not e.get("dead"):
			_step(e, LIFE)
	# Drop marks that have faded
	while not marks.is_empty() and time - marks[0][5] > marks[0][6]:
		marks.pop_front()
	queue_redraw()

func _step(w: Node2D, life: float):
	var id = trace_of(w)
	if id == "":
		return
	if w.has_method("is_burrowed") and w.is_burrowed():
		walkers.erase(w.get_instance_id())
		return
	var pos = w.global_position - global_position
	var key = w.get_instance_id()
	if not walkers.has(key):
		var r = 22.0
		var shape = w.get_node_or_null("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			r = shape.shape.radius
		walkers[key] = {"last": pos, "mark_at": pos, "dist": 0.0, "walked": 0.0, "side": 1.0, "size": clamp(r / 24.0, 0.7, 2.6)}
		return
	var wk: Dictionary = walkers[key]
	var moved = pos.distance_to(wk.last)
	wk.last = pos
	if moved > 160.0:
		# Teleported (a door, a hatch): start a fresh track
		wk.mark_at = pos
		wk.dist = 0.0
		return
	wk.dist += moved
	wk.walked += moved
	var gap = Traces.gap(id) * wk.size
	if wk.dist < gap:
		return
	var heading = (pos - wk.mark_at).angle()
	wk.dist = 0.0
	wk.mark_at = pos
	wk.side = -wk.side
	marks.append([pos, heading, wk.side, wk.walked / wk.size, wk.size, time, life, id])
	if marks.size() > MAX_MARKS:
		marks.pop_front()
	if not seen_run.has(id) and (w == player or _in_sight(w)):
		_note(id)

func _in_sight(w: Node2D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var main = get_tree().get_first_node_in_group("main")
	var reach = 560.0
	if main:
		var fog = main.get_node_or_null("VisionFog")
		if fog and fog.visible and fog.has_method("light_radius"):
			reach = fog.light_radius()
	return w.global_position.distance_to(player.global_position) < reach

func _note(id: String):
	var now = Time.get_ticks_msec() / 1000.0
	if now < _next_note:
		return # another one was just named; this one will be named on a later mark
	seen_run[id] = true
	var codex = preload("res://data/Codex.gd")
	if not codex.note_trace(id):
		return
	_next_note = now + NOTE_GAP
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("note_new_trace"):
		main.note_new_trace(id)

# Every track in one draw call (InkBatch.gd)
var pen = preload("res://InkBatch.gd").new()

func _draw():
	pen.begin(self)
	for m in marks:
		var age = time - m[5]
		var a = clamp((m[6] - age) / FADE, 0.0, 1.0)
		Traces.draw_mark(pen, m[7], m[0], m[1], m[2], m[3], m[4], a)
	pen.flush()
