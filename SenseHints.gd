# SenseHints.gd
# What the form's non-visual senses pick up, drawn in ink over the fog. Every
# form has its own mix of senses (data/Lineages.gd SENSE_PROFILES) and each
# sense it has does its own thing, at the animal's real position:
#   Smell            scent trails showing where each animal has been; a strong
#                    nose (6+) also smells where it is heading
#   Chemical sense   wounded animals leak a cloud of taste you can find in the
#                    dark (and take more damage, Player.taste_bonus)
#   Touch            only up close: whatever you brush against stays felt
#                    through the dark for a while; feelers knock aside some
#                    shots (Player.feelers_deflect, Tear.gd)
#   Lateral line     moving water: swimming animals ripple, incoming shots
#                    leave a wake; an animal holding still can't be felt
#   Electroreception heartbeats of every living animal in reach, even still,
#                    hidden or buried ones
#   Vibration        footsteps through the ground, and a tremor ring when an
#                    animal winds up an attack, even inside your light
# A stronger sense reaches further and draws bolder marks. The last two
# animals in a room are always pointed out at the edge of the light, with the
# form's best sense's mark (so a straggler can't keep the doors shut). The
# first time a sense picks something up its name shows briefly beside it and
# a soft cue plays (generate_sense_sfx.py). Lives on the VisionFog layer.
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
const LABEL_TIME := 2.2   # seconds a sense's name stays beside what it found
const CUE_GAP := 5.0      # at least this long between two cues
const TRAIL_STEP := 0.22  # seconds between scent trail points

var fog: Node
var player # Player.gd (uses its drawn_position())
var sense: int = 1          # best sense rating, for the last-ones pointers
var kind: String = "Touch"  # best sense
var profile: Dictionary = {} # {sense name: 1-10}
var time: float = 0.0
var dark_fog: bool = false
var last_cue: float = -100.0
var announced: Dictionary = {} # sense name -> true once it has shown its name
var label_kind: String = ""
var label_left: float = 0.0
var label_at: Vector2 = Vector2.ZERO # world position the label sits beside
var font: Font

# Per animal, keyed by instance id
var trails: Dictionary = {}   # world positions, oldest first
var trail_clock: float = 0.0
var last_pos: Dictionary = {}
var vel: Dictionary = {}      # smoothed world velocity
var felt: Dictionary = {}     # touch: seconds it stays felt
var winding: Dictionary = {}  # vibration: was winding up last frame
var step_clock: Dictionary = {}
var tremors: Array = []       # vibration: [world pos, age, big]
var brushed: Array = []       # touch: [world pos, direction, age] for knocked-aside shots

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = get_theme_default_font()
	add_to_group("sense_hints")

func set_sense(rating: int, new_kind: String, new_profile: Dictionary = {}):
	sense = clamp(rating, 1, 10)
	kind = new_kind if KIND_COLORS.has(new_kind) else "Touch"
	profile = new_profile.duplicate() if not new_profile.is_empty() else {kind: sense}
	announced.clear() # a new form's senses announce themselves again

func level(k: String) -> int:
	return int(profile.get(k, 0))

# Tear.gd: the feelers knocked a shot aside
func felt_shot(world_pos: Vector2, shot_vel: Vector2):
	brushed.append([world_pos, shot_vel.normalized(), 0.0])

func _alive_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemies").filter(func(e): return e is Node2D and e.is_inside_tree() and not e.get("dead"))

func _process(delta: float):
	time += delta
	label_left = max(0.0, label_left - delta)
	dark_fog = preload("res://data/ArtStyles.gd").get_style(SettingsManager.art_style).dark
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
	var enemies = _alive_enemies()
	var ids := {}
	trail_clock += delta
	var sample = trail_clock >= TRAIL_STEP
	if sample:
		trail_clock = 0.0
	var trail_len = 4 + level("Smell") * 2
	var touch_reach = 50.0 + level("Touch") * 12.0
	for e in enemies:
		var id = e.get_instance_id()
		ids[id] = true
		var p: Vector2 = e.global_position
		if last_pos.has(id) and delta > 0.0:
			vel[id] = vel.get(id, Vector2.ZERO).lerp((p - last_pos[id]) / delta, clamp(delta * 8.0, 0.0, 1.0))
		last_pos[id] = p
		# Smell: a breadcrumb of where it went
		if level("Smell") > 0 and sample:
			var tr: Array = trails.get(id, [])
			if tr.is_empty() or tr[tr.size() - 1].distance_to(p) > 6.0:
				tr.append(p)
			elif tr.size() > 1:
				tr.pop_front() # standing still, the old scent fades
			while tr.size() > trail_len:
				tr.pop_front()
			trails[id] = tr
		# Touch: brushing against it
		if level("Touch") > 0 and player and is_instance_valid(player):
			var body_r = 40.0
			var cs = e.get_node_or_null("CollisionShape2D")
			if cs and cs.shape is CircleShape2D:
				body_r = cs.shape.radius
			if p.distance_to(player.global_position) < body_r + touch_reach:
				felt[id] = 1.5 + level("Touch") * 0.45
		if felt.has(id):
			felt[id] -= delta
			if felt[id] <= 0.0:
				felt.erase(id)
		# Vibration: footsteps and wind-ups
		if level("Vibration") > 0:
			var w = _is_winding(e)
			if w and not winding.get(id, false):
				tremors.append([p, 0.0, true])
			winding[id] = w
			var spd = vel.get(id, Vector2.ZERO).length()
			if spd > 40.0:
				step_clock[id] = step_clock.get(id, 0.0) + delta * clamp(spd / 160.0, 0.5, 2.0)
				if step_clock[id] > 0.45:
					step_clock[id] = 0.0
					tremors.append([p, 0.0, false])
	# Forget animals that died or left
	for d in [trails, last_pos, vel, felt, winding, step_clock]:
		for id in d.keys():
			if not ids.has(id):
				d.erase(id)
	for tr in tremors:
		tr[1] += delta
	tremors = tremors.filter(func(tr): return tr[1] < (0.9 if tr[2] else 0.6))
	for b in brushed:
		b[2] += delta
	brushed = brushed.filter(func(b): return b[2] < 0.6)
	queue_redraw()

# Coiling for a lunge, charge or spray, or a boss's tell
func _is_winding(e) -> bool:
	if e.has_method("attack_pose") and e.attack_pose() < -0.05:
		return true
	var tt = e.get("tell_time")
	return tt != null and tt > 0.0

func _inked(k: String, a: float) -> Color:
	var c: Color = KIND_COLORS[k]
	var inked = c.lerp(Color(1, 1, 1), 0.2) if dark_fog else c.lerp(Color(0.3, 0.18, 0.1), 0.4)
	return Color(inked.r, inked.g, inked.b, clamp(a, 0.0, 1.0))

# 1 inside reach, fading to 0 at its edge, for distance d past the light's edge
func _falloff(past_light: float, reach: float) -> float:
	return 1.0 - clamp(past_light / reach, 0.0, 1.0)

# First find by a sense: its name, briefly, and a soft cue
func _announce(k: String, world_pos: Vector2):
	if announced.has(k):
		return
	announced[k] = true
	label_kind = k
	label_left = LABEL_TIME
	label_at = world_pos
	if time - last_cue > CUE_GAP:
		last_cue = time
		SoundManager.play_sfx(KIND_WORDS[k][1])

func _draw():
	if player == null or not is_instance_valid(player) or fog == null:
		return
	var to_local = get_global_transform_with_canvas().affine_inverse()
	var world_to_screen = to_local * player.get_canvas_transform()
	var center = world_to_screen * player.drawn_position()
	var radius: float = fog.radius
	var enemies = _alive_enemies()

	# ── Smell: scent trails, and where a keen nose says it's going ──
	var sm = level("Smell")
	if sm > 0:
		var reach = 300.0 + sm * 140.0
		for e in enemies:
			var id = e.get_instance_id()
			var tr: Array = trails.get(id, [])
			var pos = world_to_screen * e.global_position
			var past = center.distance_to(pos) - radius
			if past > reach:
				continue
			var k = _falloff(max(0.0, past), reach) * (0.55 + sm * 0.05)
			var inside = past < -radius * 0.2
			if inside:
				k *= 0.45 # in plain sight the trail is only a hint
			if k <= 0.02:
				continue
			var found = false
			var n = tr.size()
			# The path itself, a faint dashed line under the scent dots
			for i in range(1, n):
				if i % 2 == 0:
					continue
				var f0 = float(i + 1) / float(n + 1)
				draw_line(world_to_screen * tr[i - 1], world_to_screen * tr[i], _inked("Smell", k * f0 * 0.55), 3.0, true)
			for i in n:
				var f = float(i + 1) / float(n + 1) # 0 old .. 1 fresh
				var q = world_to_screen * tr[i]
				var wob = Vector2(sin(time * 2.0 + i * 1.3), cos(time * 1.7 + i)) * 3.0
				var r = 3.0 + f * 5.0 + sm * 0.25
				draw_circle(q + wob, r, _inked("Smell", k * f))
				# Faint wisps curling off the fresher part of the trail
				if i % 3 == 0 and f > 0.4:
					var up = Vector2(0, -1).rotated(sin(time + i) * 0.6) * (8.0 + r * 2.0)
					draw_line(q + wob, q + wob + up, _inked("Smell", k * f * 0.7), 3.0, true)
				found = true
			if sm >= 6:
				var v: Vector2 = vel.get(id, Vector2.ZERO)
				if v.length() > 30.0:
					var ahead = (world_to_screen.basis_xform(v)).limit_length(60.0 + sm * 12.0)
					var dirn = ahead.normalized()
					for j in 4:
						var f2 = (j + 1) / 4.0
						var dot_at = pos + ahead * f2 + dirn * (18.0 + sin(time * 6.0 - j) * 3.0)
						draw_circle(dot_at, 5.0 - j * 0.6, _inked("Smell", k * (1.0 - f2 * 0.5)))
					var tip = pos + ahead + dirn * 30.0
					var side = dirn.orthogonal() * 9.0
					draw_polyline(PackedVector2Array([tip - dirn * 12.0 + side * 1.3, tip, tip - dirn * 12.0 - side * 1.3]), _inked("Smell", k * 0.85), 4.0, true)
			if found and not inside:
				_announce("Smell", e.global_position)

	# ── Chemical sense: wounded prey bleeds a taste cloud ──
	var ch = level("Chemical sense")
	if ch > 0:
		var reach = 200.0 + ch * 110.0
		for e in enemies:
			var mh = e.get("max_health")
			var hp = e.get("health")
			if mh == null or hp == null or mh <= 0.0 or hp >= mh:
				continue
			var pos = world_to_screen * e.global_position
			var past = center.distance_to(pos) - radius
			if past > reach:
				continue
			var hurt = clamp(1.0 - hp / mh, 0.15, 1.0)
			var k = _falloff(max(0.0, past), reach) * (0.6 + ch * 0.045)
			if past < -radius * 0.2:
				k *= 0.5
			var spread = 26.0 + hurt * 46.0 + ch * 2.0
			var phase = float(e.get_instance_id() % 97) * 0.37
			for i in 16:
				var f = fposmod(i / 16.0 + time * 0.25, 1.0) # each mote drifts out and fades
				var ang = i * 2.39996 + phase
				var off = Vector2.from_angle(ang) * spread * (0.25 + f * 0.75)
				off += Vector2(sin(time * 1.3 + i), cos(time * 1.1 + i * 2.0)) * 4.0
				draw_circle(pos + off, 3.0 + (1.0 - f) * 4.5, _inked("Chemical sense", k * sin(f * PI) * (0.6 + hurt * 0.4)))
			if past > 0.0:
				_announce("Chemical sense", e.global_position)

	# ── Lateral line: ripples off moving animals, wakes behind shots ──
	var ll = level("Lateral line")
	if ll > 0:
		var reach = 200.0 + ll * 120.0
		for e in enemies:
			var v: Vector2 = vel.get(e.get_instance_id(), Vector2.ZERO)
			var spd = v.length()
			if spd < 25.0:
				continue # holding still, it pushes no water
			var pos = world_to_screen * e.global_position
			var past = center.distance_to(pos) - radius
			if past < -radius * 0.15 or past > reach:
				continue
			var k = _falloff(max(0.0, past), reach) * (0.6 + ll * 0.045) * clamp(spd / 120.0, 0.5, 1.0)
			var dirn = world_to_screen.basis_xform(v).normalized()
			var phase = float(e.get_instance_id() % 97) * 0.37
			for i in 3:
				var f = fposmod(i / 3.0 + time * 0.9 + phase, 1.0)
				var r = 18.0 + f * (46.0 + ll * 3.0)
				# Bow waves ahead of it and to the sides, as water is pushed
				draw_arc(pos, r, dirn.angle() - 1.3, dirn.angle() + 1.3, 14, _inked("Lateral line", k * sin(f * PI)), 4.5, true)
			_announce("Lateral line", e.global_position)
		for s in get_tree().get_nodes_in_group("enemy_tears"):
			if not (s is Node2D) or s.is_queued_for_deletion():
				continue
			var pos = world_to_screen * s.global_position
			var past = center.distance_to(pos) - radius
			if past < -radius * 0.3 or past > reach:
				continue
			var sv = s.get("velocity")
			if sv == null or sv.length() < 1.0:
				continue
			var dirn = world_to_screen.basis_xform(sv).normalized()
			var side = dirn.orthogonal()
			var k = _falloff(max(0.0, past), reach) * (0.55 + ll * 0.04)
			var c = _inked("Lateral line", k)
			# A V-shaped wake trailing the shot
			for sgn in [-1.0, 1.0]:
				draw_line(pos - dirn * 6.0, pos - dirn * 34.0 + side * sgn * 16.0, c, 3.0, true)
				draw_line(pos - dirn * 24.0, pos - dirn * 50.0 + side * sgn * 24.0, Color(c, c.a * 0.5), 2.0, true)
			draw_circle(pos, 4.5, c)

	# ── Electroreception: heartbeats, even of still or buried animals ──
	var el = level("Electroreception")
	if el > 0:
		var reach = 150.0 + el * 110.0
		for e in enemies:
			var pos = world_to_screen * e.global_position
			var past = center.distance_to(pos) - radius
			var buried = e.has_method("is_burrowed") and e.is_burrowed()
			if past > reach or (past < -radius * 0.15 and not buried):
				continue
			var k = _falloff(max(0.0, past), reach) * (0.6 + el * 0.04)
			var phase = float(e.get_instance_id() % 97) * 0.21
			# Lub-dub: two quick beats then a rest
			var beat = fposmod(time * 1.1 + phase, 1.0)
			var pulse = max(exp(-pow((beat - 0.08) * 22.0, 2.0)), 0.7 * exp(-pow((beat - 0.28) * 22.0, 2.0)))
			var big = 1.6 if e.has_method("is_boss") and e.is_boss() else 1.0
			var r = (16.0 + pulse * 12.0) * big
			var c = _inked("Electroreception", k * (0.45 + pulse * 0.55))
			draw_arc(pos, r, 0, TAU, 20, c, 4.5, true)
			draw_arc(pos, r + 10.0 + pulse * 14.0, 0, TAU, 24, Color(c, c.a * 0.35 * pulse), 2.0, true)
			# A small spark across the middle
			var pts := PackedVector2Array()
			for i in 5:
				var x = (i / 4.0 - 0.5) * r * 1.4
				pts.append(pos + Vector2(x, (0.0 if i % 4 == 0 else (-1.0 if i % 2 == 1 else 1.0)) * r * 0.35 * (0.5 + pulse)))
			draw_polyline(pts, c, 3.5, true)
			_announce("Electroreception", e.global_position)

	# ── Touch: what you brushed stays felt; feelers knock shots aside ──
	var to = level("Touch")
	if to > 0:
		for e in enemies:
			var id = e.get_instance_id()
			if not felt.has(id):
				continue
			var pos = world_to_screen * e.global_position
			var past = center.distance_to(pos) - radius
			if past < -radius * 0.15:
				continue
			var k = clamp(felt[id] / 1.2, 0.0, 1.0) * (0.5 + to * 0.05)
			var c = _inked("Touch", k)
			# A dotted outline of the body, as if traced by antennae
			var r = 34.0
			var cs = e.get_node_or_null("CollisionShape2D")
			if cs and cs.shape is CircleShape2D:
				r = cs.shape.radius * 1.1
			for i in 10:
				var a0 = i * TAU / 10.0 + time * 0.6
				draw_arc(pos, r, a0, a0 + TAU / 20.0, 4, c, 4.5, true)
			_announce("Touch", e.global_position)
		for b in brushed:
			var pos = world_to_screen * b[0]
			var f = b[2] / 0.6
			var side = Vector2(b[1]).orthogonal()
			var c = _inked("Touch", 1.0 - f)
			# The feeler flick that knocked it aside
			draw_line(pos - side * 22.0, pos + side * 22.0 + Vector2(b[1]) * 10.0 * f, c, 4.0, true)
			draw_arc(pos, 10.0 + f * 26.0, 0, TAU, 16, Color(c, c.a * 0.6), 2.5, true)

	# ── Vibration: footsteps in the dark, tremors before an attack ──
	var vi = level("Vibration")
	if vi > 0:
		var reach = 300.0 + vi * 140.0
		for tr in tremors:
			var pos = world_to_screen * tr[0]
			var past = center.distance_to(pos) - radius
			if past > reach:
				continue
			var big: bool = tr[2]
			if not big and past < -radius * 0.15:
				continue # footsteps you can see anyway
			var life = 0.9 if big else 0.6
			var f = tr[1] / life
			var k = _falloff(max(0.0, past), reach) * (0.6 + vi * 0.045) * (1.0 - f)
			if big:
				k = max(k, 0.8 * (1.0 - f)) # a warning always reads
			var c = _inked("Vibration", k)
			var r = (24.0 + f * (70.0 + vi * 4.0)) if big else (12.0 + f * 30.0)
			# A jagged seismograph ring
			var pts := PackedVector2Array()
			var n = 22 if big else 10
			for i in n + 1:
				var a = i * TAU / n
				var jag = (1.0 if i % 2 == 0 else 0.82) if big else 1.0
				pts.append(pos + Vector2.from_angle(a) * r * jag)
			draw_polyline(pts, c, 5.0 if big else 3.5, true)
			if big:
				_announce("Vibration", tr[0])

	# ── The last ones in a room, always pointed out at the edge of sight ──
	var last_ones = enemies.size() <= 2
	if last_ones:
		var ring = clamp(radius * 0.8, 110.0, 320.0)
		for e in enemies:
			var pos = world_to_screen * e.global_position
			var d = center.distance_to(pos)
			if d < radius * 0.9:
				continue
			var dir = (pos - center) / d
			var size = 18.0 + sense * 1.8
			if e.has_method("is_boss") and e.is_boss():
				size *= 1.7
			draw_glyph(self, kind, center + dir * ring, dir, size, _inked(kind, 0.75), time + float(e.get_instance_id() % 97) * 0.37)

	if label_left > 0.0 and label_kind != "" and font != null:
		_draw_label(world_to_screen * label_at, center, _inked(label_kind, 1.0))

func _draw_label(at_pos: Vector2, center: Vector2, inked: Color):
	var word: String = KIND_WORDS[label_kind][0]
	var fs := 24
	var w = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a = clamp(label_left / 0.6, 0.0, 1.0) * clamp((LABEL_TIME - label_left) / 0.25, 0.0, 1.0)
	# Just below what it found, kept on screen
	var at = at_pos + Vector2(-w * 0.5, 58.0)
	at.x = clamp(at.x, 12.0, size.x - w - 12.0)
	at.y = clamp(at.y, fs + 12.0, size.y - 12.0)
	var paper = Color(0.12, 0.1, 0.1, 0.85 * a) if dark_fog else Color(0.96, 0.92, 0.82, 0.85 * a)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, paper)
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(inked.r, inked.g, inked.b, a))

# One sense's mark starting at base and reaching out along dir. Shared with the
# sense icons on the pause screen and codex (SenseBadges.gd).
static func draw_glyph(ci: CanvasItem, k: String, base: Vector2, dir: Vector2, size: float, c: Color, t: float, chevron: bool = true):
	var side = dir.orthogonal()
	var width = 3.5 + size * 0.07
	match k:
		"Smell":
			# Three wavy wisps whose waves travel in toward you
			for j in [-1, 0, 1]:
				var pts := PackedVector2Array()
				var off = side * j * size * 0.55
				var length = size * (2.2 if j == 0 else 1.7)
				for i in 9:
					var f = i / 8.0
					var wave = sin(f * 7.0 + t * 6.0 + j) * size * 0.16 * f
					pts.append(base + off + dir * (f * length + size * 0.2 * abs(j)) + side * wave)
				ci.draw_polyline(pts, Color(c.r, c.g, c.b, c.a * (1.0 if j == 0 else 0.75)), width * 0.85, true)
		"Chemical sense":
			# Dots growing outward, drifting inward, like a trail of molecules
			for i in 5:
				var f = fposmod(i / 5.0 - t * 0.5, 1.0)
				var r = (1.5 + f * 3.5) * (0.6 + size * 0.03)
				var wob = side * sin(f * 9.0) * size * 0.2
				ci.draw_circle(base + dir * (f * size * 2.4) + wob, r, Color(c.r, c.g, c.b, c.a * (0.4 + 0.6 * sin(f * PI))))
		"Electroreception":
			# A flickering zig-zag spark with a little field arc at its far end
			var flick = 0.65 + 0.35 * float(int(t * 12.0) % 3 != 0)
			var cc = Color(c.r, c.g, c.b, c.a * flick)
			var pts := PackedVector2Array()
			for i in 6:
				var f = i / 5.0
				var jag = (0.0 if i == 0 or i == 5 else (1.0 if i % 2 == 1 else -1.0)) * size * 0.32
				pts.append(base + dir * f * size * 2.2 + side * jag)
			ci.draw_polyline(pts, cc, width, true)
			var etip = base + dir * size * 2.2
			ci.draw_arc(etip, size * 0.5, dir.angle() - 1.1, dir.angle() + 1.1, 8, cc, width * 0.7, true)
			ci.draw_arc(etip, size * 0.85, dir.angle() - 0.9, dir.angle() + 0.9, 8, Color(cc.r, cc.g, cc.b, cc.a * 0.5), width * 0.6, true)
		"Lateral line":
			# Pressure-wave arcs bowing toward you and rolling inward
			var src = base + dir * size * 3.2
			for i in 3:
				var f = fposmod(i / 3.0 - t * 0.45, 1.0)
				var r = size * (0.6 + f * 2.6)
				var a = c.a * sin(f * PI)
				var ang = (-dir).angle()
				ci.draw_arc(src, r, ang - 0.55, ang + 0.55, 10, Color(c.r, c.g, c.b, a), width * 0.85, true)
		"Vibration":
			# A seismograph tremor: a jagged line whose spikes shiver
			var pts := PackedVector2Array()
			for i in 11:
				var f = i / 10.0
				var amp = sin(f * PI) * size * 0.45 * (0.6 + 0.4 * sin(t * 20.0 + i * 2.1))
				pts.append(base + dir * f * size * 2.3 + side * amp * (1.0 if i % 2 == 0 else -1.0))
			ci.draw_polyline(pts, c, width * 0.85, true)
		_:
			# Touch: two antenna strokes reaching out, twitching at the tips
			for j in [-1, 1]:
				var pts := PackedVector2Array()
				for i in 7:
					var f = i / 6.0
					var bend = j * (f * 0.5 + f * f * 0.3 * sin(t * 5.0 + j)) * size * 0.8
					pts.append(base + dir * f * size * 2.2 + side * bend)
				ci.draw_polyline(pts, c, width * 0.85, true)
				ci.draw_circle(pts[pts.size() - 1], width * 0.9, c)
	if chevron:
		# A small chevron at the far end so the direction always reads
		var tip = base + dir * size * 2.6
		var back = tip - dir * size * 0.45
		ci.draw_polyline(PackedVector2Array([back + side * size * 0.35, tip, back - side * size * 0.35]), c, width * 0.8, true)
