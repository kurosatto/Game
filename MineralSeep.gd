# MineralSeep.gd
# The one side room per floor that isn't a fight or the treasure: a place
# where minerals come out of the ground. In the sea eras it is a cold seep,
# where fluid rich in minerals leaks from the seafloor; on land it is a
# mineral lick, a bank of salty clay that animals eat for what their food
# lacks. Touching it once heals a heart and gives a handful of the era's
# elements (data/Biominerals.gd) for the GROW screen. Drawn in pen and ink
# like the rest of the room; spent seeps lose their crystals.
extends Node2D

const BIOMINERALS = preload("res://data/Biominerals.gd")
const HitFX = preload("res://HitFX.gd")
const FAUNA = preload("res://data/Fauna.gd")
const INK = Color(0.24, 0.15, 0.08)

# Elements and heal handed out, in GROW units (a recipe costs about 4 to 6)
const UNITS := 3.0 # split between two of the era's elements
const ORBS := 6
const HEAL := 2

var floor_num: int = 1
var spot_seed: int = 0 # Room.gd: from the room's place, so a revisit looks the same
var used: bool = false
var on_used: Callable = Callable() # Room.gd saves the state
var time: float = 0.0
var player: Node2D = null
var crystals: Array = [] # [pos, size, angle]
var stones: Array = []
var gives: Array = [] # the two elements this seep is rich in

static func is_land(f: int) -> bool:
	return f >= 4

static func title_for(f: int) -> String:
	return "MINERAL LICK" if is_land(f) else "COLD SEEP"

static func fact_for(f: int) -> String:
	if is_land(f):
		return "Animals from parrots to elephants eat salty clay at mineral licks to get the sodium and calcium their food lacks."
	return "Cold seeps leak mineral-rich fluid from the seafloor. Whole communities live around them, and some of the oldest fossil animals are found at ancient seeps."

# The era's elements: everything its animals were built from
static func era_elements(f: int) -> Array:
	var out: Array = []
	for sp in FAUNA.era_species(f):
		for el in BIOMINERALS.FAUNA.get(sp.name, []):
			if not el in out:
				out.append(el)
	if out.is_empty():
		out = ["Ca", "P"]
	return out

func _ready():
	z_index = -2
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = floor_num * 7919 + spot_seed
	var els = era_elements(floor_num)
	for i in els.size():
		var j = rng.randi_range(i, els.size() - 1)
		var t = els[i]; els[i] = els[j]; els[j] = t
	gives = els.slice(0, 2)
	for i in 14:
		var a = rng.randf() * TAU
		var d = rng.randf_range(10.0, 95.0)
		crystals.append([Vector2.from_angle(a) * Vector2(d, d * 0.6), rng.randf_range(14.0, 30.0), rng.randf_range(-0.5, 0.5)])
	crystals.sort_custom(func(a, b): return a[0].y < b[0].y) # back to front
	for i in 14:
		var a = TAU * i / 14.0 + rng.randf_range(-0.15, 0.15)
		var pts := PackedVector2Array()
		var r = rng.randf_range(11.0, 20.0)
		for k in 6:
			pts.append(Vector2.from_angle(TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)) * r * Vector2(1.0, 0.75) * rng.randf_range(0.75, 1.15))
		stones.append([Vector2.from_angle(a) * Vector2(150, 92) * rng.randf_range(0.92, 1.08), pts])

func _process(delta: float):
	time += delta
	queue_redraw()
	if used or not player or not is_instance_valid(player):
		return
	if player.global_position.distance_to(global_position) < 130.0 and player.health > 0:
		use()

func use():
	used = true
	if on_used.is_valid():
		on_used.call()
	var els = gives
	for i in ORBS:
		var orb = preload("res://BiomassOrb.gd").new()
		orb.value = UNITS / ORBS
		orb.element = els[i % els.size()]
		orb.position = position + Vector2(randf_range(-30, 30), randf_range(-20, 20))
		get_parent().add_child(orb)
	if player.has_method("heal"):
		player.heal(HEAL)
	SoundManager.play_sfx("level_up", 1.25, -6.0)
	HitFX.pop(get_parent(), global_position, Color(0.95, 0.88, 0.7), 40.0, 220.0, 0.4)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("hud"):
		main.hud.show_item_banner(title_for(floor_num), fact_for(floor_num) + "\n+1 heart, and %s to GROW with" % " and ".join(els.map(func(e): return BIOMINERALS.ELEMENTS[e].name)), true)

func _draw():
	var land = is_land(floor_num)
	# Ground: a rough ring of stones (seep) or a bank of clay (lick)
	var fill = Color(0.78, 0.68, 0.5, 0.55) if land else Color(0.6, 0.66, 0.6, 0.45)
	var blob := PackedVector2Array()
	for i in 24:
		var a = TAU * i / 24.0
		var r = 1.0 + 0.08 * sin(a * 3.0 + floor_num) + 0.05 * sin(a * 7.0)
		blob.append(Vector2.from_angle(a) * Vector2(150, 92) * r)
	draw_colored_polygon(blob, fill)
	blob.append(blob[0])
	draw_polyline(blob, Color(INK, 0.8), 2.5, true)
	# Hatching across the ground, like a pen shading
	for i in range(-8, 9):
		var x = i * 16.0
		var h = 80.0 * sqrt(max(0.0, 1.0 - pow(x / 150.0, 2)))
		draw_line(Vector2(x - 10, -h * 0.6), Vector2(x + 10, h * 0.6), Color(INK, 0.18), 1.2, true)
	for s in stones:
		draw_set_transform(s[0])
		draw_colored_polygon(s[1], Color(0.86, 0.8, 0.66, 0.92))
		var outline: PackedVector2Array = s[1].duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color(INK, 0.75), 1.8, true)
		draw_line(outline[1] * 0.5, outline[3] * 0.5, Color(INK, 0.3), 1.2, true)
		draw_set_transform(Vector2.ZERO)
	if used:
		# Spent: just a damp hollow
		draw_arc(Vector2.ZERO, 26.0, 0, TAU, 20, Color(INK, 0.5), 1.6, true)
		return
	# Mineral crystals, each element's tint washed into the ink
	var els = gives
	for i in crystals.size():
		var c = crystals[i]
		var col: Color = BIOMINERALS.ELEMENTS[els[i % els.size()]].color
		var p: Vector2 = c[0]
		var sz: float = c[1]
		var pts = PackedVector2Array([p + Vector2(0, -sz).rotated(c[2]), p + Vector2(sz * 0.4, 0).rotated(c[2]),
			p + Vector2(0, sz * 0.35).rotated(c[2]), p + Vector2(-sz * 0.4, 0).rotated(c[2])])
		draw_colored_polygon(pts, Color(col.lerp(Color(0.95, 0.9, 0.8), 0.45), 0.9))
		pts.append(pts[0])
		draw_polyline(pts, Color(INK, 0.85), 1.8, true)
		draw_line(pts[0], pts[2], Color(INK, 0.4), 1.0, true)
	# Seeps leak a slow trickle of bubbles; licks just glint
	if not land:
		for i in 5:
			var t = fmod(time * 0.5 + i * 0.37, 1.0)
			var x = sin(i * 2.3 + time) * 8.0 + (i - 2) * 14.0
			draw_arc(Vector2(x, -10.0 - t * 90.0), 3.0 + 3.0 * t, 0, TAU, 10, Color(INK, 0.55 * (1.0 - t)), 1.4, true)
	else:
		var g = 0.5 + 0.5 * sin(time * 2.5)
		draw_line(Vector2(-6, -40), Vector2(6, -40), Color(1, 1, 0.9, g), 2.0)
		draw_line(Vector2(0, -46), Vector2(0, -34), Color(1, 1, 0.9, g), 2.0)
