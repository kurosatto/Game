# Hazard.gd
# Ground that fights back, from era 2 on (Room.spawn_hazards). Each era has
# its own, drawn in pen and ink like the scenery:
#   brine   (sea eras)   a pool of dense, super-salty water on the seafloor.
#                        Wading through it slows you; the local animals know
#                        to go round, so they are not slowed.
#   bog     (era 4)      waterlogged peat in the coal swamps; slows you.
#   fumarole (era 5)     a gas vent of the Siberian Traps eruptions. It hisses
#                        for a moment, then bursts, hurting anything on it,
#                        animals included, so you can lure them onto it.
# Flying forms (passive "flight") pass over pools but not over gas.
extends Node2D

const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)

const INFO = {
	"brine": {"name": "Brine pool", "fact": "Brine pools are lakes of super-salty water on the seafloor, so dense they have shores and waves."},
	"bog": {"name": "Peat bog", "fact": "Carboniferous swamp plants piled up as peat, which became most of the world's coal."},
	"fumarole": {"name": "Fumarole", "fact": "The Siberian Traps eruptions poured out gas for thousands of years and drove the end-Permian extinction, the worst in Earth's history."},
}

const SLOW := 0.55
const VENT_PERIOD := 3.4
const VENT_WARN := 0.9
const VENT_RADIUS := 95.0

var kind: String = "brine"
var size: Vector2 = Vector2(150, 90) # half extents of the pool
var seed_val: int = 0
var time: float = 0.0
var vent_timer: float = 0.0
var burst_flash: float = 0.0
var player: Node2D = null
var outline := PackedVector2Array()
var marks: Array = []
var told: bool = false

static func kind_for_floor(f: int) -> String:
	if f >= 5:
		return "fumarole"
	if f == 4:
		return "bog"
	return "brine"

func _ready():
	z_index = -3
	player = get_tree().get_first_node_in_group("player")
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val
	if kind == "fumarole":
		size = Vector2(VENT_RADIUS, VENT_RADIUS * 0.7)
		vent_timer = rng.randf_range(0.5, VENT_PERIOD)
	for i in 28:
		var a = TAU * i / 28.0
		var r = 1.0 + 0.07 * sin(a * 3.0 + rng.randf() * 6.0) + rng.randf_range(-0.04, 0.04)
		outline.append(Vector2.from_angle(a) * size * r)
	outline.append(outline[0])
	for i in 10:
		var a = rng.randf() * TAU
		var d = sqrt(rng.randf()) * 0.75
		marks.append([Vector2.from_angle(a) * size * d, rng.randf_range(0.6, 1.4), rng.randf() * TAU])

# Inside the pool's ellipse
func covers(pos: Vector2, pad: float = 0.0) -> bool:
	var d = pos - global_position
	var sx = size.x + pad
	var sy = size.y + pad
	return (d.x * d.x) / (sx * sx) + (d.y * d.y) / (sy * sy) <= 1.0

func _physics_process(delta: float):
	time += delta
	burst_flash = max(0.0, burst_flash - delta * 3.0)
	queue_redraw()
	if not player or not is_instance_valid(player) or player.health <= 0:
		return
	if player.global_position.distance_to(global_position) < size.x + 220.0:
		introduce()
	if kind == "fumarole":
		vent_timer -= delta
		if vent_timer <= 0.0:
			vent_timer = VENT_PERIOD
			burst()
		return
	if player.get("current_passive") == "flight":
		return
	if covers(player.global_position):
		if player.has_method("apply_slow"):
			player.apply_slow(0.12, SLOW, "" if told else INFO[kind].name.to_upper())
			told = true

# The first time each kind is met in a run, say what it is and does
func introduce():
	var main = get_tree().get_first_node_in_group("main")
	if main == null or main.has_meta("hazard_" + kind) or not main.get("hud"):
		return
	main.set_meta("hazard_" + kind, true)
	var effect = "It bursts every few seconds and hurts anything standing on it. Lure animals onto it!" \
		if kind == "fumarole" else "Wading through it slows you down; the animals here know to go round."
	main.hud.show_item_banner(INFO[kind].name.to_upper(), INFO[kind].fact + "\n" + effect, true)

func burst():
	burst_flash = 1.0
	HitFX.pop(get_parent(), global_position, Color(0.85, 0.6, 0.4), 30.0, VENT_RADIUS * 2.2, 0.35)
	if player.global_position.distance_to(global_position) < 700.0:
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play_sfx("explosion", 0.55, -12.0)
	if covers(player.global_position, 20.0) and player.has_method("take_damage"):
		player.take_damage(1, "a fumarole")
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead and covers(e.global_position, 20.0) \
				and not e.is_boss() and not e.is_burrowed():
			e.take_damage(6.0)
			var main = get_tree().get_first_node_in_group("main")
			if main and main.has_method("field_event"):
				main.field_event("fumarole")

func _draw():
	match kind:
		"brine": _draw_brine()
		"bog": _draw_bog()
		_: _draw_vent()

func _draw_brine():
	draw_colored_polygon(outline, Color(0.42, 0.5, 0.5, 0.32))
	draw_polyline(outline, Color(INK, 0.8), 2.4, true)
	# The brine's own shoreline a little inside, rippling
	for k in [0.8, 0.55]:
		var pts := PackedVector2Array()
		for i in outline.size():
			pts.append(outline[i] * (k + 0.025 * sin(time * 1.6 + i * 0.9 + k * 5.0)))
		draw_polyline(pts, Color(INK, 0.35 if k > 0.6 else 0.22), 1.4, true)
	# Dense water hatching
	for i in range(-9, 10):
		var x = i * size.x / 10.0
		var h = size.y * sqrt(max(0.0, 1.0 - pow(x / size.x, 2))) * 0.85
		draw_line(Vector2(x - 6, -h), Vector2(x + 6, h), Color(INK, 0.14), 1.2, true)

func _draw_bog():
	draw_colored_polygon(outline, Color(0.38, 0.32, 0.2, 0.38))
	draw_polyline(outline, Color(INK, 0.8), 2.4, true)
	for i in range(-9, 10):
		var x = i * size.x / 10.0
		var h = size.y * sqrt(max(0.0, 1.0 - pow(x / size.x, 2))) * 0.85
		draw_line(Vector2(x - 8, -h), Vector2(x + 8, h), Color(INK, 0.2), 1.3, true)
		draw_line(Vector2(x + 8, -h), Vector2(x - 8, h), Color(INK, 0.1), 1.0, true)
	# Reeds and a slow bubble
	for m in marks:
		var p: Vector2 = m[0]
		var sway = sin(time * 1.3 + m[2]) * 3.0
		draw_line(p, p + Vector2(sway, -26.0 * m[1]), Color(INK, 0.7), 1.6, true)
		draw_line(p + Vector2(3, 0), p + Vector2(4 + sway, -18.0 * m[1]), Color(INK, 0.5), 1.2, true)
	var t = fmod(time * 0.6 + seed_val % 7 * 0.13, 1.0)
	var bp: Vector2 = marks[0][0] * 0.6
	draw_arc(bp, 4.0 + t * 7.0, 0, TAU, 12, Color(INK, 0.6 * (1.0 - t)), 1.4, true)

func _draw_vent():
	var warn = clamp(1.0 - vent_timer / VENT_WARN, 0.0, 1.0) if vent_timer < VENT_WARN else 0.0
	# Scorched ground, darker as it is about to go
	draw_colored_polygon(outline, Color(0.35, 0.22, 0.14, 0.18 + 0.25 * warn + 0.3 * burst_flash))
	draw_polyline(outline, Color(INK, 0.55 + 0.4 * warn), 1.6 + 2.0 * warn, true)
	# Cracks out from the mouth
	for m in marks:
		var a: float = m[2]
		var p1 = Vector2.from_angle(a) * size * 0.25
		var p2 = Vector2.from_angle(a + 0.2) * size * (0.6 + 0.3 * m[1] / 1.4)
		draw_line(p1, p2, Color(INK, 0.55), 1.5, true)
	# The vent's mouth
	draw_circle(Vector2.ZERO, 16.0, Color(0.2, 0.12, 0.07, 0.85))
	draw_arc(Vector2.ZERO, 22.0, 0, TAU, 18, Color(INK, 0.8), 2.0, true)
	# Wisps: thin and lazy, thick and fast before a burst, a cloud as it goes
	var n = 3 + int(warn * 5.0)
	for i in n:
		var t = fmod(time * (0.4 + warn * 1.4) + i / float(n), 1.0)
		var x = sin(i * 2.1 + time * 2.0) * (6.0 + 20.0 * t)
		var r = 5.0 + 12.0 * t + 10.0 * warn
		draw_arc(Vector2(x, -t * (50.0 + 50.0 * warn)), r, 0, TAU, 14, Color(INK, (0.35 + 0.4 * warn) * (1.0 - t)), 1.6, true)
	if burst_flash > 0.0:
		var r = VENT_RADIUS * (1.2 - burst_flash * 0.4)
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(0.55, 0.25, 0.1, burst_flash), 4.0, true)
