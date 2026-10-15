# PauseTile.gd
# One picture on the pause screen (HUD.show_pause_info): an animated sprite
# sheet or an icon on a round membrane disc, with an optional name under it
# and a stack badge. Tapping or hovering it fires `picked` so the pause screen
# can show what it is, which keeps the words out of the way until asked for.
extends Control

signal picked(tile: Control)

const UI = preload("res://data/UIStyle.gd")

var texture: Texture2D = null
var hframes: int = 1
var spin: float = 0.0          # turn the art so it faces up
var tint: Color = UI.MEMBRANE  # rim colour
var caption: String = ""       # name drawn under the disc
var badge: int = 0             # "×n" in the corner when above 1
var animate: bool = true
var selected: bool = false
var info_title: String = ""
var info_body: String = ""

var disc: float = 100.0
var time: float = 0.0
var font: Font

func setup(tex: Texture2D, frames: int, disc_size: float, name_text: String = "") -> Control:
	texture = tex
	hframes = max(1, frames)
	disc = disc_size
	caption = name_text
	font = load(UI.FONT_MEDIUM)
	var text_w = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x + 10.0 if caption != "" else 0.0
	custom_minimum_size = Vector2(max(disc, text_w), disc + (30.0 if caption != "" else 0.0))
	return self

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	time = randf() * 4.0
	mouse_entered.connect(func(): picked.emit(self))

func _process(delta: float):
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()

func _gui_input(event: InputEvent):
	var tap = (event is InputEventScreenTouch and event.pressed) or \
		(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if tap:
		picked.emit(self)
		accept_event()

func _draw():
	var c = Vector2(size.x * 0.5, disc * 0.5)
	if font == null:
		return
	var r = disc * 0.5 - 4.0
	if selected:
		draw_circle(c, r + 4.0, Color(UI.SUN, 0.35 + 0.15 * sin(time * 5.0)))
	draw_circle(c, r, Color(UI.INK.lerp(tint, 0.16), 0.95))
	draw_arc(c, r, 0, TAU, 48, Color(UI.SUN if selected else tint, 0.95), 3.0, true)
	if texture:
		var fw = texture.get_width() / float(hframes)
		var frame = int(fmod(time * 5.0, hframes)) if animate else 0
		var src = Rect2(frame * fw, 0, fw, texture.get_height())
		var s = disc * (0.86 if hframes > 1 else 0.66)
		var bob = sin(time * 1.8) * disc * 0.025 if hframes > 1 else 0.0
		draw_set_transform(c + Vector2(0, bob), spin, Vector2.ONE)
		draw_texture_rect_region(texture, Rect2(-Vector2(s, s) * 0.5, Vector2(s, s)), src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if badge > 1:
		var b = c + Vector2(r * 0.72, r * 0.72)
		draw_circle(b, 15.0, UI.SUN)
		draw_string(font, b + Vector2(-15, 7), "×%d" % badge, HORIZONTAL_ALIGNMENT_CENTER, 30, 17, UI.INK)
	if caption != "":
		draw_string(font, Vector2(0, disc + 22), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, UI.SUN if selected else UI.CREAM)
