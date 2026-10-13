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

# Palette
const INK = Color(0.055, 0.10, 0.09)      # panel fill: deep kelp water
const INK_SOFT = Color(0.09, 0.16, 0.14)  # raised fill: buttons, bars
const MEMBRANE = Color(0.58, 0.80, 0.55)  # panel rims: moss green
const CREAM = Color(0.98, 0.94, 0.84)     # body text
const MUTED = Color(0.74, 0.80, 0.70)     # secondary text
const SUN = Color(1.0, 0.80, 0.40)        # headings, highlights
const LEAF = Color(0.62, 0.93, 0.50)      # good things: perks, biomass
const AQUA = Color(0.45, 0.90, 0.85)      # energy: the zap charge
const CORAL = Color(1.0, 0.47, 0.40)      # danger: bosses, damage
const SHADE = Color(0.0, 0.03, 0.02, 0.55) # soft shadow under panels

# A rounded membrane panel. tint colours the rim and warms the fill a little.
static func panel(tint: Color = MEMBRANE, radius: int = 28, alpha: float = 0.94, margin: float = 32.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(INK.lerp(tint, 0.07), alpha)
	s.border_color = Color(tint.r, tint.g, tint.b, 0.85)
	s.set_border_width_all(4)
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.shadow_color = SHADE
	s.shadow_size = 22
	s.shadow_offset = Vector2(0, 8)
	s.set_content_margin_all(margin)
	s.anti_aliasing = true
	return s

# Pill-shaped button faces. state: normal, hover, pressed, disabled, focus
static func button_box(state: String, tint: Color = MEMBRANE) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.set_corner_radius_all(40)
	s.corner_detail = 10
	s.set_border_width_all(3)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	s.anti_aliasing = true
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
			s.draw_center = false
			s.border_color = Color(SUN.r, SUN.g, SUN.b, 0.6)
	return s

# A rounded bar track or fill
static func bar_box(color: Color, alpha: float = 1.0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, alpha)
	s.set_corner_radius_all(8)
	s.corner_detail = 6
	s.anti_aliasing = true
	return s

static func bar_track() -> StyleBoxFlat:
	var s = bar_box(Color(0.0, 0.04, 0.03), 0.7)
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
	t.set_color("font_outline_color", "Label", Color(0, 0.03, 0.02, 0.8))
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

# "#rrggbb" for BBCode
static func hex(c: Color) -> String:
	return "#" + c.to_html(false)
