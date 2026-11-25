# Wildfire.gd
# A ground fire sweeping through a Carboniferous or Permian room
# (data/SpecialRooms.gd "fire"). The air then held far more oxygen than
# today, so lightning set the forests alight again and again: coal from these
# periods is full of fossil charcoal. A few seconds after you come in a
# strike lands on the side away from you and a front of flame crosses the
# room. Anything standing in it gets burnt, you and the animals alike, and
# animals run ahead of it; dash through it, or stay ahead. The plants it
# passes are charred, and once it has burnt out the ash holds phosphorus.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)
const DELAY := 4.0        # seconds from walking in to the lightning strike (the warning shows meanwhile)
const SPEED := 95.0       # px/s the front moves
const BAND := 190.0       # depth of the burning band behind the front
const HURT_EVERY := 1.1   # player: one hit per this long in the flames
const ANIMAL_DPS := 4.0   # animals: damage per second in the flames
const ASH_SPOTS := 5
const ASH_UNITS := 0.9    # phosphorus per ash spot

var floor_num: int = 4
var room: Node2D = null
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0
var hurt_cd: float = 0.0
var _tick: float = 0.0
var _charred: Dictionary = {}
var first: bool = true # false on a revisit: whatever was left has burnt out

func _ready():
	z_index = -1
	player = get_tree().get_first_node_in_group("player")
	if not state.has("dir"):
		# Starts on the side away from where you came in
		var px = player.global_position.x - room.global_position.x if player else 300.0
		state["dir"] = 1.0 if px > 960.0 else -1.0
		state["front"] = 0.0
		state["lit"] = false
		state["delay"] = DELAY
	if state.get("done", false):
		_char_all()
	elif not first:
		_burn_out.call_deferred()
	else:
		_add_sign()

# The warning sign goes on the fog layer, so the dark can't hide it
func _add_sign():
	var fog = get_tree().get_first_node_in_group("main").get_node_or_null("VisionFog") if get_tree().get_first_node_in_group("main") else null
	var sign = preload("res://rooms/FireSign.gd").new()
	sign.fire = self
	if fog:
		fog.add_child(sign)
	else:
		add_child(sign)

func left_edge() -> float:
	return -room.side_margin

func right_edge() -> float:
	return 1920.0 + room.side_margin

# Where the flames are, in room coordinates: [from, to] along x
func band() -> Vector2:
	var f: float = state.front
	var d: float = state.dir
	return Vector2(min(f, f - d * BAND), max(f, f - d * BAND))

func lit() -> bool:
	return state.get("lit", false) and not state.get("done", false)

func _process(delta: float):
	time += delta
	queue_redraw()
	if state.get("done", false) or player == null or not is_instance_valid(player):
		return
	if not state.get("lit", false):
		state.delay -= delta
		if state.delay <= 0.0:
			_strike()
		return
	state.front += state.dir * SPEED * delta
	var b = band()
	# Burnt out once the whole band has left the room
	if (state.dir > 0.0 and b.x > right_edge()) or (state.dir < 0.0 and b.y < left_edge()):
		_burn_out()
		return
	# You
	var plx = player.global_position.x - room.global_position.x
	hurt_cd -= delta
	# Burns wherever your drawn body is in the band or the flames leaning
	# out of its front (Player.touched_by_gap)
	var lo: float = b.x - (25.0 if state.dir < 0.0 else 0.0)
	var hi: float = b.y + (25.0 if state.dir > 0.0 else 0.0)
	var ox: float = room.global_position.x
	var in_fire = func(p: Vector2) -> float: return max(0.0, max(lo - (p.x - ox), (p.x - ox) - hi))
	var mid = Vector2(ox + (lo + hi) * 0.5, player.global_position.y)
	var touching = player.touched_by_gap(in_fire, mid, (hi - lo) * 0.5 + 200.0) if player.has_method("touched_by_gap") else (plx > b.x and plx < b.y)
	if player.health > 0 and touching and hurt_cd <= 0.0:
		hurt_cd = HURT_EVERY
		player.take_damage(1, "a wildfire")
	# The animals: burnt in it, and running ahead of it
	_tick -= delta
	var burn = _tick <= 0.0
	if burn:
		_tick = 0.25
	for e in room.active_enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var ex = e.position.x
		if ex > b.x and ex < b.y:
			if burn:
				e.take_damage_if_alive(ANIMAL_DPS * 0.25)
		else:
			var ahead = (ex - state.front) * state.dir
			if ahead > 0.0 and ahead < 300.0 and e.knockback_velocity.length() < 60.0:
				e.knockback_velocity = Vector2(state.dir * 260.0, randf_range(-60.0, 60.0))
	# Plants it passes are charred
	for c in room.get_children():
		if c.is_in_group("obstacles") and not _charred.has(c):
			if (c.position.x - state.front) * state.dir < 0.0:
				_char(c)

func _strike():
	state["lit"] = true
	state.front = left_edge() if state.dir > 0.0 else right_edge()
	SoundManager.play_sfx("boss_roar", 1.8, -6.0)
	var at = Vector2(state.front + state.dir * 60.0, 540)
	HitFX.pop(room, at, Color(1.0, 0.85, 0.5), 60.0, 420.0, 0.5)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("shake_camera"):
		main.shake_camera(10.0)
	if player:
		player.popup_text(player.global_position + Vector2(0, -90), "FIRE!", Color(1.0, 0.62, 0.3))

func _burn_out():
	state["done"] = true
	_char_all()
	# Ash: phosphorus the fire freed from the plants
	var rng = RandomNumberGenerator.new()
	rng.seed = int(room.room_data.grid_pos.x * 97 + room.room_data.grid_pos.y * 31)
	var area = room.interior_rect(120.0)
	var spots: Array = []
	for attempt in 80:
		if spots.size() >= ASH_SPOTS:
			break
		var p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if room.spot_is_free(p, 40.0) and spots.all(func(q): return q.distance_to(p) > 240.0):
			spots.append(p)
	for p in spots:
		SR.spill(room, p, ["P"], ASH_UNITS, 2)
	state["ash"] = spots

func _char(c: Node):
	_charred[c] = true
	if c is CanvasItem:
		var tw = c.create_tween()
		tw.tween_property(c, "modulate", Color(0.42, 0.36, 0.32), 0.6)

func _char_all():
	for c in room.get_children():
		if c.is_in_group("obstacles") and not _charred.has(c):
			_charred[c] = true
			if c is CanvasItem:
				c.modulate = Color(0.42, 0.36, 0.32)

func _draw():
	var m = room.side_margin
	var top := 96.0
	var bottom := 984.0
	# Burnt ground behind the front (all of it, once it is over)
	var burnt := Rect2()
	if state.get("done", false):
		burnt = Rect2(-m, top, 1920.0 + m * 2.0, bottom - top)
	elif lit():
		var b = band()
		if state.dir > 0.0:
			burnt = Rect2(left_edge(), top, max(0.0, b.x - left_edge()), bottom - top)
		else:
			burnt = Rect2(b.y, top, max(0.0, right_edge() - b.y), bottom - top)
	if burnt.size.x > 0.0:
		draw_rect(burnt, Color(0.25, 0.19, 0.15, 0.16))
		# Charred stubble: short dark strokes, the same every frame
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		for k in 260:
			var p = Vector2(rng.randf_range(-m, 1920.0 + m), rng.randf_range(top, bottom))
			var len = rng.randf_range(6.0, 14.0)
			if burnt.has_point(p):
				draw_line(p, p + Vector2(len * 0.3, -len), Color(INK, 0.45), 1.6, true)
	if not lit():
		if not state.get("lit", false) and not state.get("done", false):
			# Before the strike: a dry crackle in the air, storm light at the far side
			var side_x = left_edge() if state.dir > 0.0 else right_edge()
			var flick = 0.5 + 0.5 * sin(time * 2.2) # a slow glow, not a strobe
			draw_rect(Rect2(side_x - (0.0 if state.dir > 0.0 else 70.0), top, 70.0, bottom - top), Color(1.0, 0.95, 0.75, 0.08 + 0.1 * flick))
		return
	var b = band()
	# The burning band: smouldering ground, smoke, then the flame front
	draw_rect(Rect2(b.x, top, b.y - b.x, bottom - top), Color(0.4, 0.22, 0.12, 0.2))
	var f: float = state.front
	var d: float = state.dir
	for k in 9:
		var u = fmod(time * 0.35 + k / 9.0, 1.0)
		var sp = Vector2(f - d * (30.0 + u * BAND * 1.3), top + fmod(k * 131.0, bottom - top))
		draw_circle(sp, 22.0 + u * 40.0, Color(0.35, 0.3, 0.27, 0.22 * (1.0 - u)))
	var y := top
	var i := 0
	while y < bottom:
		var h = 50.0 + 24.0 * sin(time * 9.0 + i * 1.7) + 12.0 * sin(time * 15.0 + i * 0.6)
		var base = Vector2(f - d * 10.0, y + 22.0)
		var lean = Vector2(d * h * 0.45, -h)
		var outer = PackedVector2Array([base + Vector2(-d * 14.0, 0), base + Vector2(d * 18.0, -6.0), base + lean * 0.55 + Vector2(d * 10.0, 0), base + lean, base + lean * 0.5 + Vector2(-d * 10.0, 0)])
		draw_colored_polygon(outer, Color(0.5, 0.24, 0.1, 0.9))
		var inner = PackedVector2Array([base + Vector2(-d * 4.0, -2.0), base + Vector2(d * 8.0, -6.0), base + lean * 0.6, base + lean * 0.3 + Vector2(-d * 4.0, 0)])
		draw_colored_polygon(inner, Color(0.96, 0.82, 0.55, 0.95))
		outer.append(outer[0])
		draw_polyline(outer, Color(INK, 0.95), 2.0, true)
		# Embers behind it
		var ember = Vector2(f - d * (40.0 + fmod(time * 60.0 + i * 37.0, BAND)), y + 10.0 + 8.0 * sin(time * 5.0 + i))
		draw_circle(ember, 3.0, Color(0.5, 0.22, 0.08, 0.9))
		y += 40.0
		i += 1

