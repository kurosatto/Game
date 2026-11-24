# Extinction.gd
# A mass extinction caught in one room (data/SpecialRooms.gd "extinction"):
# elements lie about for the taking, but a countdown runs from the moment you
# walk in, and the era's killer (dead water, ice, drought or poison gas)
# creeps in from the walls. When it reaches the middle the room hurts until
# you leave, and whatever you left behind is lost. The doors stay open.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)
const CACHES := 6
const CACHE_UNITS := 1.3
const HURT_EVERY := 2.0

var floor_num: int = 1
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var left: float = SR.EXTINCTION_TIME
var lethal: bool = false # it ran out while you were here
var hurt_cd: float = 1.0
var last_tick: int = -1

func _ready():
	z_index = -1
	player = get_tree().get_first_node_in_group("player")
	left = float(state.get("left", SR.EXTINCTION_TIME))
	if not state.has("caches"):
		var els = SR.era_elements(floor_num)
		var caches: Array = []
		var area = room.interior_rect(110.0)
		for attempt in 120:
			if caches.size() >= CACHES:
				break
			var p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			var ok = room.spot_is_free(p, 40.0) and p.distance_to(Vector2(960, 540)) > 160.0
			for c in caches:
				if p.distance_to(c.pos) < 260.0:
					ok = false
			if ok:
				caches.append({"pos": p, "el": els[caches.size() % els.size()], "taken": false})
		state["caches"] = caches
		# A heart among the loot, in the middle where the end comes last
		var h = room.pickup_scene.instantiate()
		h.position = Vector2(960, 540)
		h.pickup_type = "heart"
		room.add_child.call_deferred(h)
	if state.get("done", false):
		left = 0.0

func info() -> Dictionary:
	return SR.EXTINCTIONS[preload("res://data/Worlds.gd").era(floor_num)]

func progress() -> float:
	return 1.0 - left / SR.EXTINCTION_TIME

func _process(delta: float):
	time += delta
	queue_redraw()
	if not player or not is_instance_valid(player) or player.health <= 0:
		return
	if state.get("done", false):
		if lethal:
			hurt_cd -= delta
			if hurt_cd <= 0.0:
				hurt_cd = HURT_EVERY
				player.take_damage(1, info().title.to_lower())
				player.popup_text(player.global_position + Vector2(0, -80), "GET OUT!", Color(1.0, 0.5, 0.35))
		return
	left = max(0.0, left - delta)
	state["left"] = left
	var sec = int(ceil(left))
	if sec != last_tick and sec <= 5 and sec > 0:
		SoundManager.play_sfx("parry", 0.5 + 0.06 * (5 - sec), -10.0)
	last_tick = sec
	for c in state.caches:
		if not c.taken and player.global_position.distance_to(c.pos) < 70.0:
			c.taken = true
			SR.spill(room, c.pos, [c.el], CACHE_UNITS, 3)
			SoundManager.play_sfx("dna_pickup", 1.2, -6.0)
	if left <= 0.0:
		state["done"] = true
		lethal = true
		hurt_cd = 0.6
		SoundManager.play_sfx("boss_roar", 0.6, -6.0)
		for c in state.caches:
			if not c.taken:
				HitFX.pop(room, c.pos, Color(0.5, 0.45, 0.4), 20.0, 90.0, 0.4)
		player.popup_text(player.global_position + Vector2(0, -90), "GET OUT!", Color(1.0, 0.5, 0.35))

func _draw():
	var m = room.side_margin
	var full = Rect2(-m, 0, 1920 + m * 2.0, 1080)
	var tint: Color = info().tint
	if state.get("done", false):
		draw_rect(full, Color(tint, 0.42 if lethal else 0.22))
		_hatch(full, 0.25 if lethal else 0.12)
		SR.draw_label(self, Vector2(960, 200), "IT HAS PASSED" if not lethal else "LEAVE!", 30)
		return
	# Caches: little heaps of crystals to grab
	for c in state.caches:
		if c.taken:
			continue
		var col: Color = preload("res://data/Biominerals.gd").ELEMENTS[c.el].color
		for k in 4:
			var p = c.pos + Vector2(cos(k * 2.1) * 16.0, sin(k * 1.7) * 10.0)
			var s = 13.0 + k * 2.0
			var pts = PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.45, 0), p + Vector2(0, s * 0.35), p + Vector2(-s * 0.45, 0)])
			draw_colored_polygon(pts, Color(col.lerp(Color(0.95, 0.9, 0.8), 0.4), 0.95))
			pts.append(pts[0])
			draw_polyline(pts, Color(INK, 0.85), 1.6, true)
		var g = 0.5 + 0.5 * sin(time * 4.0 + c.pos.x)
		draw_arc(c.pos, 34.0 + g * 4.0, 0, TAU, 20, Color(INK, 0.3), 1.4, true)
	# The end creeping in from every wall
	var reach = progress() * 560.0
	var bands = [Rect2(full.position, Vector2(full.size.x, reach)),
		Rect2(Vector2(full.position.x, 1080 - reach), Vector2(full.size.x, reach)),
		Rect2(full.position, Vector2(reach * 1.6, 1080)),
		Rect2(Vector2(full.end.x - reach * 1.6, 0), Vector2(reach * 1.6, 1080))]
	for b in bands:
		draw_rect(b, Color(tint, 0.38))
		_hatch(b, 0.22)
	# The front line, wavering
	var inner = Rect2(full.position + Vector2(reach * 1.6, reach), full.size - Vector2(reach * 3.2, reach * 2.0))
	if inner.size.x > 0 and inner.size.y > 0:
		draw_rect(inner, Color(INK, 0.55), false, 3.0 + sin(time * 6.0))
	var sec = int(ceil(left))
	SR.draw_label(self, Vector2(960, 205), "%s IN %d" % [info().title, sec], 34 if sec > 5 else 40)

func _hatch(r: Rect2, a: float):
	var step = 26.0
	var x = r.position.x - r.size.y
	while x < r.end.x:
		var p0 = Vector2(x, r.end.y)
		var p1 = Vector2(x + r.size.y, r.position.y)
		# clip to the rect
		if p0.x < r.position.x:
			p0 = Vector2(r.position.x, r.end.y - (r.position.x - x))
		if p1.x > r.end.x:
			p1 = Vector2(r.end.x, r.position.y + (p1.x - r.end.x))
		if p0.x <= p1.x:
			draw_line(p0, p1, Color(INK, a), 1.2)
		x += step
