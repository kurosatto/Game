# StatBar.gd
# One stat row on an evolution card: an icon, a short name and a bar. The bar
# is filled to what the offered form would have, with a tick where your form
# is now, and a small arrow says whether the pick raises or lowers it, so a
# card reads at a glance without numbers.
extends Control

const UI = preload("res://data/UIStyle.gd")

var icon: Texture2D = null
var icon_sepia := true
var label := ""
var value := 0.5    # 0..1, the offered form
var current := -1.0 # 0..1, your form now (below 0: no tick)
var colour: Color = UI.SUN
var font: Font
var shown := 0.0    # animated fill
var label_w := 150.0
var font_px := 19

func setup(tex: Texture2D, name_text: String, v: float, now: float = -1.0, c: Color = UI.SUN, sepia: bool = true) -> Control:
	icon = tex
	icon_sepia = sepia
	label = name_text
	value = clampf(v, 0.0, 1.0)
	current = clampf(now, 0.0, 1.0) if now >= 0.0 else -1.0
	colour = c
	font = load(UI.FONT_MEDIUM)
	custom_minimum_size = Vector2(0, 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	if icon:
		var ic = TextureRect.new()
		ic.texture = icon
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(0, 1)
		ic.size = Vector2(32, 32)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if icon_sepia:
			ic.material = UI.sepia_material()
		add_child(ic)
	return self

func _process(delta: float):
	if not is_visible_in_tree():
		return
	if absf(shown - value) > 0.002:
		shown = move_toward(shown, value, delta * 1.6)
		queue_redraw()

func _draw():
	var x0 := 42.0
	var h := size.y
	draw_string(font, Vector2(x0, h * 0.5 + 7), label, HORIZONTAL_ALIGNMENT_LEFT, label_w - 6, font_px, UI.CREAM)
	var arrow_w := 26.0
	var bx := x0 + label_w
	var bw: float = maxf(40.0, size.x - bx - arrow_w - 6.0)
	var by := h * 0.5 - 8.0
	var track := Rect2(bx, by, bw, 16)
	draw_style_box(UI.bar_track(), track)
	var up := current >= 0.0 and value > current + 0.02
	var down := current >= 0.0 and value < current - 0.02
	var fill_c: Color = UI.LEAF if up else (UI.CORAL if down else (UI.MEMBRANE if current >= 0.0 else colour))
	if shown > 0.01:
		draw_style_box(UI.bar_box(fill_c, 0.95), Rect2(bx, by, maxf(12.0, bw * shown), 16))
	if current >= 0.0:
		# Where your form is now: a dark notch with a pale edge
		var tx := bx + bw * current
		draw_rect(Rect2(tx - 2.5, by - 5, 5, 26), UI.CREAM)
		draw_rect(Rect2(tx - 1, by - 3, 2, 22), UI.INK)
	# Up or down arrow
	var ax := bx + bw + 6.0 + arrow_w * 0.5
	var ay := h * 0.5
	if up:
		draw_colored_polygon(PackedVector2Array([Vector2(ax, ay - 9), Vector2(ax + 9, ay + 6), Vector2(ax - 9, ay + 6)]), UI.LEAF)
	elif down:
		draw_colored_polygon(PackedVector2Array([Vector2(ax, ay + 9), Vector2(ax + 9, ay - 6), Vector2(ax - 9, ay - 6)]), UI.CORAL)
	elif current >= 0.0:
		draw_rect(Rect2(ax - 8, ay - 2, 16, 4), UI.MUTED)
