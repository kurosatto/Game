# Megarachne.gd — a secret lair boss on land (data/Endgame.gd "lairs")
# Megarachne servinei, from rocks about 300 million years old in Argentina,
# was described in 1980 as the biggest spider that ever lived, with a body
# a third of a metre long, and for 25 years it was drawn that way. When a
# second fossil was studied in 2005 it turned out to be a sea scorpion, a
# mycteroptid eurypterid, close kin to the hibbertopterids, sweeping lake
# beds for food. The "giant spider" was never a spider.
# The fight plays the joke: it starts drawn as the 1980 spider and at half
# health the reconstruction falls away and it fights on as what it was. It
# uses the sweep-feeder kit of Campylocephalus (rake, silt, telson, lurch)
# but doesn't moult.
extends "res://bosses/Campylocephalus.gd"

const HAIR = Color(0.28, 0.2, 0.14)
const SPIDER = Color(0.42, 0.3, 0.22)
const LAKE_SHELL = Color(0.44, 0.4, 0.3)

var disguised: bool = true
var reveal: float = 0.0  # 1 just after the spider falls away
var flakes: Array = []   # bits of the false reconstruction falling off

func setup():
	super.setup()
	moults = false
	boss_title = "MEGARACHNE — THE GIANT SPIDER?"
	boss_fact = "Described in 1980 as the biggest spider ever. Is it?"
	max_health = 380.0
	light.color = Color(0.95, 0.85, 0.65)

func killer_name() -> String:
	return "Megarachne"

func shell_col() -> Color:
	return LAKE_SHELL

func on_phase2():
	super.on_phase2()
	disguised = false
	reveal = 1.0
	boss_title = "MEGARACHNE — NOT A SPIDER: A SEA SCORPION"
	emit_boss_health()
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("display_item_banner"):
		main.display_item_banner("NOT A SPIDER!", "In 2005 a second fossil showed Megarachne was a eurypterid, a sea scorpion, close kin to Campylocephalus. For 25 years the biggest spider in the books had been a misread fossil.", 4.0, "It was a sea scorpion all along")
	for i in 16:
		flakes.append([Vector2.from_angle(randf() * TAU) * randf_range(20, 120), Vector2.from_angle(randf() * TAU) * randf_range(120, 300), randf() * TAU])

func think(delta: float):
	super.think(delta)
	reveal = max(0.0, reveal - delta * 0.6)
	for f in flakes:
		f[0] += f[1] * delta
		f[1] *= 0.94
		f[2] += delta * 4.0
	if reveal <= 0.0:
		flakes.clear()

func draw_body():
	if not disguised:
		super.draw_body()
		for f in flakes:
			var p: Vector2 = f[0]
			var a = reveal
			pen_line(p, p + Vector2(18, 0).rotated(f[2]), Color(HAIR, a), 5.0, true)
		return
	# Warnings as the kit draws them
	if state == "rake_wind":
		warn_sector(Vector2.ZERO, 330.0, facing.angle(), 0.95)
	if state == "tail_wind":
		warn_circle(to_local(telson_tip()), 60.0)
	if state == "lurch_wind":
		warn_line(facing * 90.0, facing * 620.0, 170.0)
	pen_xf(Vector2.ZERO, facing.angle(), Vector2.ONE)
	light_rot = facing.angle()
	shadow(Vector2(-20, 14), 190, 130)
	draw_spider()
	pen_xf(Vector2.ZERO, 0.0, Vector2.ONE)
	light_rot = 0.0

# The 1980 reconstruction: a hairy giant spider, eight legs and a round
# abdomen (forward is +x)
func draw_spider():
	var ph = gait
	# Eight legs, four a side, bent at the knee, stepping in turn
	for k in 4:
		for side in [-1.0, 1.0]:
			var a0 = side * (0.55 + k * 0.42)
			var p = ph + k * 1.3 + (0.0 if side > 0 else PI)
			var hip = Vector2(30 - k * 10, side * 26)
			var knee = hip + Vector2.from_angle(a0 + sin(p) * 0.12 * walk) * 120.0 + Vector2(0, -side * 10)
			var reach_in = rake * 0.5 if k < 2 else 0.0
			var foot = knee + Vector2.from_angle(a0 + side * (0.6 + reach_in)) * 110.0
			limb(PackedVector2Array([hip, knee, foot]), 12.0 - k, SPIDER)
			# Hairs along the leg
			for h in 6:
				var hp = knee.lerp(foot, h / 6.0)
				pen_line(hp, hp + (foot - knee).normalized().orthogonal() * 7.0, HAIR, 1.5, true)
	# Abdomen, round and hairy
	oval(Vector2(-110, 0), 100.0, 82.0, 0.0, shade(SPIDER, 1.05), 3.0)
	for i in 30:
		var a = TAU * i / 30.0
		var p = Vector2(-110, 0) + Vector2(cos(a) * 100.0, sin(a) * 82.0)
		pen_line(p, p + Vector2.from_angle(a) * 8.0, HAIR, 1.5, true)
	# Chevron bands down the abdomen, as tarantula-like drawings show
	for k in 4:
		var cx = -60.0 - k * 30.0
		pen_polyline(PackedVector2Array([Vector2(cx - 14, -40 + k * 6), Vector2(cx + 6, 0), Vector2(cx - 14, 40 - k * 6)]), Color(HAIR, 0.7), 4.0, true)
	# Cephalothorax, fangs and a cluster of eyes
	oval(Vector2(30, 0), 66.0, 58.0, 0.0, shade(SPIDER, 1.12), 3.0)
	for side in [-1.0, 1.0]:
		var base = Vector2(92, side * 16)
		var tip = base + Vector2(22, -side * 8.0 - side * rake * 8.0)
		pen_line(base, tip, OUTLINE, 9.0, true)
		pen_line(base, tip, Color(0.2, 0.14, 0.1), 6.0, true)
	for e in [Vector2(70, -10), Vector2(70, 10), Vector2(62, -24), Vector2(62, 24), Vector2(78, -4), Vector2(78, 4)]:
		pen_circle(e, 4.5, EYE, true, -1.0, true)
		pen_circle(e + Vector2(1, -1), 1.3, Color(1, 1, 1, 0.7), true, -1.0, true)
