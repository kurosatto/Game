# UIStyle.gd
# The look of every menu, card and HUD panel, so the interface matches the
# handcrafted era art (data/EraLook.gd) instead of a sci-fi console: warm
# cream text in the rounded Fredoka font, panels like soft cell membranes
# over dark kelp-green water, sunlit amber for headings.
# make_theme() builds the project theme (assets/ui/organic_theme.tres, made
# by tools/make_theme.gd); panel() and friends are for UI built in code.
extends RefCounted

# Fredoka (SIL OFL, assets/ui/Fredoka_OFL.txt), cut to two static weights
# with fontTools because Godot ignored the variable font's weight axis
const FONT_MEDIUM = "res://assets/ui/Fredoka-Medium.ttf"
const FONT_BOLD = "res://assets/ui/Fredoka-SemiBold.ttf"

# Palette: set by the art style (data/ArtStyles.gd "ui") through apply().
# The defaults are the sepia sketchbook: dark ink-wash panels with
# paper-coloured text, tan rims like the edge of a page, amber headings;
# green and red stay for good and bad.
static var INK := Color(0.16, 0.11, 0.075)      # panel fill: dark sepia wash
static var INK_SOFT := Color(0.23, 0.16, 0.105) # raised fill: buttons, bars
static var MEMBRANE := Color(0.82, 0.68, 0.48)  # panel rims: parchment tan
static var CREAM := Color(0.97, 0.92, 0.81)     # body text: paper
static var MUTED := Color(0.80, 0.72, 0.60)     # secondary text
static var SUN := Color(0.98, 0.76, 0.38)       # headings, highlights
static var LEAF := Color(0.72, 0.84, 0.50)      # good things: perks, biomass
static var AQUA := Color(0.55, 0.82, 0.80)      # energy: the zap charge
static var CORAL := Color(0.95, 0.50, 0.40)     # danger: bosses, damage
static var SHADE := Color(0.05, 0.03, 0.01, 0.55) # soft shadow under panels
static var BACKDROP := Color(0.10, 0.065, 0.04) # full-screen dimming behind cards
# Over-the-world text (menu title, stats): fill and outline
static var TITLE := Color(0.27, 0.16, 0.09)
static var TITLE_OUTLINE := Color(0.94, 0.88, 0.75)
# Panel shape: corner rounding (x the usual radius), rim width, corner
# detail (1 cuts facets), smooth edges, and the shadow's size and offset
static var ROUND := 1.0
static var RIM := 4
static var CORNER_DETAIL := 12
static var SMOOTH := true
static var SHADOW_SIZE := 22
static var SHADOW_OFFSET := Vector2(0, 8)
static var style_id := ""

const PALETTE_KEYS = ["INK", "INK_SOFT", "MEMBRANE", "CREAM", "MUTED", "SUN", "LEAF", "AQUA", "CORAL",
	"SHADE", "BACKDROP", "TITLE", "TITLE_OUTLINE", "ROUND", "RIM", "CORNER_DETAIL", "SMOOTH", "SHADOW_SIZE", "SHADOW_OFFSET"]
const SEPIA_UI = {
	"INK": Color(0.16, 0.11, 0.075), "INK_SOFT": Color(0.23, 0.16, 0.105), "MEMBRANE": Color(0.82, 0.68, 0.48),
	"CREAM": Color(0.97, 0.92, 0.81), "MUTED": Color(0.80, 0.72, 0.60), "SUN": Color(0.98, 0.76, 0.38),
	"LEAF": Color(0.72, 0.84, 0.50), "AQUA": Color(0.55, 0.82, 0.80), "CORAL": Color(0.95, 0.50, 0.40),
	"SHADE": Color(0.05, 0.03, 0.01, 0.55), "BACKDROP": Color(0.10, 0.065, 0.04),
	"TITLE": Color(0.27, 0.16, 0.09), "TITLE_OUTLINE": Color(0.94, 0.88, 0.75),
	"ROUND": 1.0, "RIM": 4, "CORNER_DETAIL": 12, "SMOOTH": true, "SHADOW_SIZE": 22, "SHADOW_OFFSET": Vector2(0, 8),
}

# Switches every menu, card and HUD panel to an art style's palette and
# shapes, and rebuilds the project theme in place so themed controls follow.
# Screens built afterwards pick it up (the main menu reloads itself).
static func apply(id: String):
	var ui: Dictionary = SEPIA_UI.duplicate()
	ui.merge(preload("res://data/ArtStyles.gd").get_style(id).get("ui", {}), true)
	INK = ui.INK; INK_SOFT = ui.INK_SOFT; MEMBRANE = ui.MEMBRANE; CREAM = ui.CREAM
	MUTED = ui.MUTED; SUN = ui.SUN; LEAF = ui.LEAF; AQUA = ui.AQUA; CORAL = ui.CORAL
	SHADE = ui.SHADE; BACKDROP = ui.BACKDROP; TITLE = ui.TITLE; TITLE_OUTLINE = ui.TITLE_OUTLINE
	ROUND = ui.ROUND; RIM = ui.RIM; CORNER_DETAIL = ui.CORNER_DETAIL; SMOOTH = ui.SMOOTH
	SHADOW_SIZE = ui.SHADOW_SIZE; SHADOW_OFFSET = ui.SHADOW_OFFSET
	style_id = id
	var theme: Theme = ThemeDB.get_project_theme()
	if theme:
		theme.merge_with(make_theme())

# Screens laid out in .tscn files (HUD.tscn) were coloured with the sepia
# palette; this swaps each colour override for the same role in the current
# style (the nearest sepia role colour decides which role it is)
const ROLE_KEYS = ["CREAM", "MUTED", "SUN", "LEAF", "AQUA", "CORAL"]
static func restyle_tree(root: Node):
	if style_id == "" or style_id == "sepia":
		return
	var stack: Array = [root]
	while not stack.is_empty():
		var n = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is Control):
			continue
		for prop in ["font_color", "font_outline_color"]:
			if n.has_theme_color_override(prop):
				var c: Color = n.get_theme_color(prop)
				n.add_theme_color_override(prop, Color(_role_colour(c, prop == "font_outline_color"), c.a))

static func _role_colour(c: Color, outline: bool) -> Color:
	if outline or (c.r + c.g + c.b) < 0.6:
		return INK.darkened(0.5)
	var best := "CREAM"
	var best_d := 99.0
	for k in ROLE_KEYS:
		var r: Color = SEPIA_UI[k]
		var d = Vector3(c.r - r.r, c.g - r.g, c.b - r.b).length()
		if d < best_d:
			best_d = d
			best = k
	return {"CREAM": CREAM, "MUTED": MUTED, "SUN": SUN, "LEAF": LEAF, "AQUA": AQUA, "CORAL": CORAL}[best]

static func _r(radius: int) -> int:
	return int(round(radius * ROUND))

# A rounded membrane panel. tint colours the rim and warms the fill a little.
static func panel(tint: Color = MEMBRANE, radius: int = 28, alpha: float = 0.94, margin: float = 32.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(INK.lerp(tint, 0.07), alpha)
	s.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	s.set_border_width_all(RIM)
	s.set_corner_radius_all(_r(radius))
	s.corner_detail = CORNER_DETAIL
	s.shadow_color = SHADE
	s.shadow_size = SHADOW_SIZE
	s.shadow_offset = SHADOW_OFFSET
	s.set_content_margin_all(margin)
	s.anti_aliasing = SMOOTH
	return s

# Pill-shaped button faces. state: normal, hover, pressed, disabled, focus
static func button_box(state: String, tint: Color = MEMBRANE) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(_r(40))
	s.corner_detail = mini(CORNER_DETAIL, 10)
	s.set_border_width_all(maxi(RIM - 1, 2))
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = SMOOTH
	match state:
		"normal":
			s.bg_color = Color(INK_SOFT.lerp(tint, 0.10), 0.92)
			s.border_color = Color(tint.r, tint.g, tint.b, 0.75)
			s.border_width_bottom = 6 # a soft lip so it reads as pressable
			s.shadow_color = Color(0, 0, 0, 0.3)
			s.shadow_size = 6
			s.shadow_offset = Vector2(0, 3)
		"hover":
			s.bg_color = Color(INK_SOFT.lerp(tint, 0.28), 0.96)
			s.border_color = SUN
			s.border_width_bottom = 6
			s.shadow_color = Color(SUN.r, SUN.g, SUN.b, 0.25)
			s.shadow_size = 12
		"pressed":
			s.bg_color = Color(INK_SOFT.lerp(tint, 0.40), 1.0)
			s.border_color = SUN
			s.content_margin_top = 11 # sinks onto its lip
			s.content_margin_bottom = 7
		"disabled":
			s.bg_color = Color(INK_SOFT, 0.6)
			s.border_color = Color(MUTED.r, MUTED.g, MUTED.b, 0.3)
		"focus":
			# The gamepad / keyboard highlight: a bright ring with a glow
			s.draw_center = false
			s.set_border_width_all(4)
			s.border_color = SUN
			s.expand_margin_left = 5
			s.expand_margin_right = 5
			s.expand_margin_top = 5
			s.expand_margin_bottom = 5
			s.shadow_color = Color(SUN.r, SUN.g, SUN.b, 0.45)
			s.shadow_size = 14
	return s

# A rounded bar track or fill
static func bar_box(color: Color, alpha: float = 1.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, alpha)
	s.set_corner_radius_all(_r(8))
	s.corner_detail = mini(CORNER_DETAIL, 6)
	s.anti_aliasing = SMOOTH
	return s

static func bar_track() -> StyleBoxFlat:
	var s = bar_box(Color(0.06, 0.04, 0.02), 0.7)
	s.border_color = Color(MEMBRANE.r, MEMBRANE.g, MEMBRANE.b, 0.35)
	s.set_border_width_all(2)
	s.expand_margin_left = 2
	s.expand_margin_right = 2
	s.expand_margin_top = 2
	s.expand_margin_bottom = 2
	return s

# weight 600 or more is the semibold cut. Returns a FontVariation so callers
# can add spacing.
static func font(weight: int = 500) -> FontVariation:
	var v = FontVariation.new()
	v.base_font = load(FONT_BOLD if weight >= 600 else FONT_MEDIUM)
	return v

static func make_theme() -> Theme:
	var t = Theme.new()
	t.default_font = font(500)
	t.default_font_size = 22

	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(INK.darkened(0.5), 0.8))
	t.set_color("default_color", "RichTextLabel", CREAM)
	t.set_font("bold_font", "RichTextLabel", font(650))

	for type in ["Button", "OptionButton", "CheckBox", "CheckButton"]:
		t.set_color("font_color", type, CREAM)
		t.set_color("font_hover_color", type, SUN)
		t.set_color("font_pressed_color", type, SUN)
		t.set_color("font_focus_color", type, CREAM)
		t.set_color("font_hover_pressed_color", type, SUN)
		t.set_color("font_disabled_color", type, Color(MUTED.r, MUTED.g, MUTED.b, 0.6))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		t.set_stylebox(state, "Button", button_box(state))
		t.set_stylebox(state, "OptionButton", button_box(state))
	t.set_font("font", "Button", font(600))

	t.set_stylebox("panel", "Panel", panel())
	t.set_stylebox("panel", "PanelContainer", panel())
	var popup = panel(MEMBRANE, 16, 0.98, 10.0)
	t.set_stylebox("panel", "PopupMenu", popup)
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_color("font_hover_color", "PopupMenu", SUN)
	t.set_stylebox("hover", "PopupMenu", bar_box(MEMBRANE, 0.25))

	t.set_stylebox("background", "ProgressBar", bar_track())
	t.set_stylebox("fill", "ProgressBar", bar_box(LEAF))

	var slider = bar_track()
	slider.content_margin_top = 4
	slider.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", bar_box(LEAF, 0.85))
	t.set_stylebox("grabber_area_highlight", "HSlider", bar_box(SUN, 0.9))

	for type in ["HSeparator", "VSeparator"]:
		var line = StyleBoxLine.new()
		line.color = Color(MEMBRANE.r, MEMBRANE.g, MEMBRANE.b, 0.35)
		line.thickness = 2
		line.vertical = type == "VSeparator"
		line.grow_begin = -12
		line.grow_end = -12
		t.set_stylebox("separator", type, line)

	t.set_stylebox("scroll", "VScrollBar", bar_box(Color(0, 0, 0), 0.25))
	for s in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(s, "VScrollBar", bar_box(MEMBRANE, 0.6 if s == "grabber" else 0.9))
	return t

# Creature pictures shown outside the inked world (codex, menus, pause
# screen) get the same sepia look as InkFilter.gd: brightness mapped from
# brown ink to paper, with a pale wash of the original colour
const SEPIA_SHADER = """
shader_type canvas_item;
uniform vec3 ink : source_color = vec3(0.27, 0.16, 0.09);
uniform vec3 paper : source_color = vec3(0.96, 0.90, 0.78);
uniform float wash = 0.22;
void fragment() {
	vec4 c = COLOR;
	float l = smoothstep(0.04, 0.85, dot(c.rgb, vec3(0.299, 0.587, 0.114)));
	COLOR = vec4(mix(mix(ink, paper, l), c.rgb, wash), c.a);
}
"""
static var _sepia: ShaderMaterial = null

# Only for the ink-on-paper art styles; the others leave pictures in colour
static func sepia_material() -> ShaderMaterial:
	if not preload("res://data/ArtStyles.gd").uses_sepia(SettingsManager.art_style):
		return null
	if _sepia == null:
		var sh = Shader.new()
		sh.code = SEPIA_SHADER
		_sepia = ShaderMaterial.new()
		_sepia.shader = sh
	return _sepia

# A form's own colour (data/Lineages.gd, often bright) pulled toward the
# parchment rim, so cards and discs keep a hint of it without neon edges
static func ink_tint(c: Color) -> Color:
	return Color(c.clamp().lerp(MEMBRANE, 0.55), 1.0)

# "#rrggbb" for BBCode
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)

# ═══════════════════════════════════════════════════════════
# SCREEN MOTION: screens fade in and their panel settles like a page laid
# on the desk; card rows are dealt one after another. They run while the
# game is paused (most screens pause it).
# ═══════════════════════════════════════════════════════════
static func reveal(screen: CanvasItem, panel: Control = null, time: float = 0.2):
	if screen == null:
		return
	screen.modulate.a = 0.0
	var tw = screen.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(screen, "modulate:a", 1.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if panel:
		var settle = func(v: float):
			if is_instance_valid(panel):
				panel.pivot_offset = panel.size / 2.0
				panel.scale = Vector2.ONE * v
				panel.rotation = (1.0 - v) * -0.25
		settle.call(0.93)
		tw.parallel().tween_method(settle, 0.93, 1.0, time + 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

static func deal(cards: Array, delay: float = 0.12, step: float = 0.08):
	for i in cards.size():
		var c = cards[i]
		if not (c is Control):
			continue
		c.modulate.a = 0.0
		var lift = func(v: float):
			if is_instance_valid(c):
				c.pivot_offset = Vector2(c.size.x / 2.0, c.size.y)
				c.scale = Vector2.ONE * (0.82 + 0.18 * v)
				c.rotation = (1.0 - v) * (0.12 if i % 2 == 0 else -0.12)
		lift.call(0.0)
		var tw = c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(delay + step * i)
		tw.tween_property(c, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_method(lift, 0.0, 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
