# SenseBadge.gd
# One sense as a picture: the sense's own ink mark (SenseHints.draw_glyph) on a
# small disc, with five pips under it for how strong it is (half a pip per
# level). A sense the animal lacks is a faint empty disc, so every animal
# shows the same six in the same order and can be compared at a glance.
# Used on the pause screen (tappable like a PauseTile: it fires `picked` and
# carries info_title/info_body) and in the codex (row(), not tappable).
extends Control

signal picked(tile: Control)

const UI = preload("res://data/UIStyle.gd")
const Hints = preload("res://SenseHints.gd")

var kind: String = "Smell"
var rating: int = 0
var disc: float = 64.0
var selected: bool = false
var info_title: String = ""
var info_body: String = ""
var time: float = 0.0

func setup(k: String, r: int, disc_size: float = 64.0, tappable: bool = true) -> Control:
	kind = k
	rating = r
	disc = disc_size
	custom_minimum_size = Vector2(disc, disc + disc * 0.26)
	mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
	var lineages = preload("res://data/Lineages.gd")
	info_title = "%s: %s" % [kind, (lineages.SENSE_WORDS[clampi(r, 1, 10)] if r > 0 else "none")]
	info_body = lineages.describe_sense_kind(kind, r)
	return self

# A row of all six senses for one form
static func row(form: Dictionary, disc_size: float, tappable: bool) -> Array:
	var lineages = preload("res://data/Lineages.gd")
	var prof: Dictionary = lineages.sense_profile(form)
	var out: Array = []
	for k in lineages.SENSE_ORDER:
		out.append(load("res://SenseBadge.gd").new().setup(k, int(prof.get(k, 0)), disc_size, tappable))
	return out

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	time = randf() * 4.0
	if mouse_filter == Control.MOUSE_FILTER_STOP:
		mouse_entered.connect(func(): picked.emit(self))
		focus_mode = Control.FOCUS_ALL
		focus_entered.connect(func(): picked.emit(self))

func _process(delta: float):
	if not is_visible_in_tree():
		return
	time += delta
	if rating > 0:
		queue_redraw()

func _gui_input(event: InputEvent):
	var tap = (event is InputEventScreenTouch and event.pressed) or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or \
		event.is_action_pressed("ui_accept")
	if tap:
		picked.emit(self)
		accept_event()

func _draw():
	var c = Vector2(size.x * 0.5, disc * 0.5)
	var r = disc * 0.5 - 3.0
	var col: Color = Hints.KIND_COLORS.get(kind, UI.CREAM).lerp(UI.CREAM, 0.25)
	if selected or has_focus():
		draw_circle(c, r + 4.0, Color(UI.SUN, 0.35 + 0.15 * sin(time * 5.0)))
	if rating <= 0:
		draw_circle(c, r, Color(UI.INK, 0.5))
		draw_arc(c, r, 0, TAU, 32, Color(UI.MUTED, 0.3), 2.0, true)
		Hints.draw_glyph(self, kind, c + Vector2(-r * 0.62, 0), Vector2.RIGHT, r * 0.42, Color(UI.MUTED, 0.22), 0.0, false)
		return
	draw_circle(c, r, Color(UI.INK.lerp(col, 0.14), 0.95))
	draw_arc(c, r, 0, TAU, 32, Color(UI.SUN if selected else col, 0.9), 2.5, true)
	# The mark, pointing right, a little bolder for a stronger sense
	var a = 0.65 + rating * 0.035
	Hints.draw_glyph(self, kind, c + Vector2(-r * 0.62, 0), Vector2.RIGHT, r * 0.42, Color(col, a), time, false)
	# Five pips: full, half or empty
	var pr = max(3.0, disc * 0.055)
	var gap = pr * 2.9
	var y = disc + disc * 0.12
	for i in 5:
		var at = Vector2(c.x + (i - 2) * gap, y)
		var fill = clamp(rating / 2.0 - i, 0.0, 1.0)
		draw_arc(at, pr, 0, TAU, 12, Color(col, 0.7), 1.5, true)
		if fill >= 1.0:
			draw_circle(at, pr, col)
		elif fill > 0.0:
			# Half pip: the left half filled
			var pts := PackedVector2Array([at + Vector2(0, -pr)])
			for j in 7:
				pts.append(at + Vector2.from_angle(-PI / 2 - j * PI / 6.0) * pr)
			draw_colored_polygon(pts, col)
