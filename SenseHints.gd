# SenseHints.gd
# Ink marks at the edge of the lit circle pointing at animals hidden in the
# dark, standing in for the form's best sense besides sight (data/Lineages.gd
# SENSES). Every sense draws its own mark, so you can tell at a glance what
# you are sensing with:
#   Smell            wavy scent wisps drifting in toward you
#   Chemical sense   a trail of tiny dots, like dissolved molecules
#   Electroreception a flickering zig-zag spark
#   Lateral line     ripple arcs of pushed water rolling in
#   Vibration        a jagged tremor line, like a seismograph
#   Touch            two twitching antenna strokes reaching out
# A stronger sense reaches further and draws bolder marks. When the sense first
# picks something up, its name is written beside the nearest mark and a soft
# cue plays (generate_sense_sfx.py). Lives on the VisionFog layer and reads its radius.
extends Control

const KIND_COLORS = {
	"Smell": Color(1.0, 0.62, 0.2),
	"Chemical sense": Color(0.45, 0.85, 0.25),
	"Electroreception": Color(0.3, 0.7, 1.0),
	"Lateral line": Color(0.15, 0.8, 0.75),
	"Vibration": Color(0.95, 0.4, 0.3),
	"Touch": Color(0.75, 0.55, 0.95),
}
# The word written beside the mark, and the cue it plays
const KIND_WORDS = {
	"Smell": ["smell", "sense_smell"],
	"Chemical sense": ["taste", "sense_chemical"],
	"Electroreception": ["electric sense", "sense_electric"],
	"Lateral line": ["lateral line", "sense_lateral"],
	"Vibration": ["vibration", "sense_vibration"],
	"Touch": ["touch", "sense_touch"],
}
const LABEL_TIME := 2.6   # seconds the sense's name stays beside the mark
const CUE_GAP := 5.0      # at least this long between two cues

var fog: Node
var player # Player.gd (uses its drawn_position())
var sense: int = 1
var kind: String = "Touch"
var color: Color = Color(1, 1, 1)
var time: float = 0.0
var dark_fog: bool = false
var label_left: float = 0.0
var last_cue: float = -100.0
var sensed_any: bool = false
var font: Font

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()

func set_sense(rating: int, new_kind: String):
	sense = clamp(rating, 1, 10)
	if new_kind != kind:
		label_left = 0.0
		sensed_any = false # a new sense announces itself again
	kind = new_kind if KIND_COLORS.has(new_kind) else "Touch"
	color = KIND_COLORS[kind]

func _process(delta: float):
	time += delta
	label_left = max(0.0, label_left - delta)
	dark_fog = preload("res://data/ArtStyles.gd").get_style(SettingsManager.art_style).dark
	queue_redraw()

func _draw():
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	var to_local = get_global_transform_with_canvas().affine_inverse()
	var center = to_local * (player.get_canvas_transform() * player.drawn_position())
	var radius: float = fog.radius
	var reach = 300.0 + sense * 150.0          # 450 px past the light for 1, 1800 for 10
	var clarity = 0.5 + sense * 0.05           # mark opacity at its strongest
	var ring = clamp(radius * 0.8, 110.0, 320.0)
	var enemies = get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Node2D and e.is_inside_tree() and not e.get("dead"))
	# The last two in a room are always pointed out, however far away, so a
	# straggler hiding in the dark can't keep the doors shut
	var last_ones = enemies.size() <= 2
	# Drawn over the paper fog, so brown ink tinted with the sense's colour
	# (on the dark fog of the pixel, neon and other dark styles, lit instead)
	var inked = color.lerp(Color(0.3, 0.18, 0.1), 0.4)
	if dark_fog:
		inked = color.lerp(Color(1, 1, 1), 0.2)
	var nearest_d := INF
	var nearest_tip := Vector2.ZERO
	var nearest_dir := Vector2.RIGHT
	var count := 0
	for e in enemies:
		var pos = to_local * e.get_global_transform_with_canvas().origin
		var d = center.distance_to(pos)
		if d < radius * 0.9 or (d > radius + reach and not last_ones):
			continue
		var strength = clarity * (1.0 - clamp(max(0.0, d - radius) / reach, 0.0, 1.0))
		if last_ones:
			strength = max(strength, 0.75)
		strength = clamp(strength, 0.0, 1.0)
		var dir = (pos - center) / d
		var size = 18.0 + sense * 1.8
		if e.has_method("is_boss") and e.is_boss():
			size *= 1.7
		var base = center + dir * ring
		var c = Color(inked.r, inked.g, inked.b, strength)
		# Each animal gets its own phase so marks don't pulse in lockstep
		var phase = float(e.get_instance_id() % 97) * 0.37
		_draw_mark(base, dir, size, c, phase)
		count += 1
		if d < nearest_d:
			nearest_d = d
			nearest_tip = base + dir * size * 2.4
			nearest_dir = dir
	# Name the sense when it first picks something up, with a soft cue
	if count > 0 and not sensed_any:
		label_left = LABEL_TIME
		if time - last_cue > CUE_GAP:
			last_cue = time
			SoundManager.play_sfx(KIND_WORDS[kind][1])
	sensed_any = count > 0
	if count > 0 and label_left > 0.0 and font != null:
		_draw_label(nearest_tip, nearest_dir, inked)

func _draw_label(tip: Vector2, dir: Vector2, inked: Color):
	var word: String = KIND_WORDS[kind][0]
	var fs := 26
	var w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a = clamp(label_left / 0.6, 0.0, 1.0) * clamp((LABEL_TIME - label_left) / 0.25, 0.0, 1.0)
	# Beside the mark, never upside down: left of it when pointing left
	var at = tip + dir * 10.0
	if dir.x < -0.3:
		at.x -= w
	elif abs(dir.x) <= 0.3:
		at.x -= w * 0.5
	at.y += fs * 0.35 + (fs * 0.6 if dir.y > 0.3 else 0.0)
	var paper = Color(0.12, 0.1, 0.1, 0.85 * a) if dark_fog else Color(0.96, 0.92, 0.82, 0.85 * a)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, paper)
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(inked.r, inked.g, inked.b, a))

# One sense mark starting at base and reaching out along dir (toward the animal)
func _draw_mark(base: Vector2, dir: Vector2, size: float, c: Color, phase: float):
	var side = dir.orthogonal()
	var t = time + phase
	var width = 3.5 + size * 0.07
	match kind:
		"Smell":
			# Three wavy wisps whose waves travel in toward you
			for k in [-1, 0, 1]:
				var pts := PackedVector2Array()
				var off = side * k * size * 0.55
				var length = size * (2.2 if k == 0 else 1.7)
				for i in 9:
					var f = i / 8.0
					var wave = sin(f * 7.0 + t * 6.0 + k) * size * 0.16 * f
					pts.append(base + off + dir * (f * length + size * 0.2 * abs(k)) + side * wave)
				draw_polyline(pts, Color(c.r, c.g, c.b, c.a * (1.0 if k == 0 else 0.75)), width * 0.85, true)
		"Chemical sense":
			# Dots growing outward, drifting inward, like a trail of molecules
			for i in 5:
				var f = fposmod(i / 5.0 - t * 0.5, 1.0)
				var r = (1.5 + f * 3.5) * (0.6 + size * 0.03)
				var wob = side * sin(f * 9.0 + phase) * size * 0.2
				draw_circle(base + dir * (f * size * 2.4) + wob, r, Color(c.r, c.g, c.b, c.a * (0.4 + 0.6 * sin(f * PI))))
		"Electroreception":
			# A flickering zig-zag spark with a little field arc at its far end
			var flick = 0.65 + 0.35 * float(int(t * 12.0) % 3 != 0)
			var cc = Color(c.r, c.g, c.b, c.a * flick)
			var pts := PackedVector2Array()
			for i in 6:
				var f = i / 5.0
				var jag = (0.0 if i == 0 or i == 5 else (1.0 if i % 2 == 1 else -1.0)) * size * 0.32
				pts.append(base + dir * f * size * 2.2 + side * jag)
			draw_polyline(pts, cc, width, true)
			var etip = base + dir * size * 2.2
			draw_arc(etip, size * 0.5, dir.angle() - 1.1, dir.angle() + 1.1, 8, cc, width * 0.7, true)
			draw_arc(etip, size * 0.85, dir.angle() - 0.9, dir.angle() + 0.9, 8, Color(cc.r, cc.g, cc.b, cc.a * 0.5), width * 0.6, true)
		"Lateral line":
			# Pressure-wave arcs bowing toward you and rolling inward
			var src = base + dir * size * 3.2
			for i in 3:
				var f = fposmod(i / 3.0 - t * 0.45, 1.0)
				var r = size * (0.6 + f * 2.6)
				var a = c.a * sin(f * PI)
				var ang = (-dir).angle()
				draw_arc(src, r, ang - 0.55, ang + 0.55, 10, Color(c.r, c.g, c.b, a), width * 0.85, true)
		"Vibration":
			# A seismograph tremor: a jagged line whose spikes shiver
			var pts := PackedVector2Array()
			for i in 11:
				var f = i / 10.0
				var amp = sin(f * PI) * size * 0.45 * (0.6 + 0.4 * sin(t * 20.0 + i * 2.1))
				pts.append(base + dir * f * size * 2.3 + side * amp * (1.0 if i % 2 == 0 else -1.0))
			draw_polyline(pts, c, width * 0.85, true)
		_:
			# Touch: two antenna strokes reaching out, twitching at the tips
			for k in [-1, 1]:
				var pts := PackedVector2Array()
				for i in 7:
					var f = i / 6.0
					var bend = k * (f * 0.5 + f * f * 0.3 * sin(t * 5.0 + k)) * size * 0.8
					pts.append(base + dir * f * size * 2.2 + side * bend)
				draw_polyline(pts, c, width * 0.85, true)
				draw_circle(pts[pts.size() - 1], width * 0.9, c)
	# A small chevron at the far end so the direction always reads
	var tip = base + dir * size * 2.6
	var back = tip - dir * size * 0.45
	draw_polyline(PackedVector2Array([back + side * size * 0.35, tip, back - side * size * 0.35]), c, width * 0.8, true)
