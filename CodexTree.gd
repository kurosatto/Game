# CodexTree.gd
# The codex as an evolution tree: the ancestral cell at the bottom and every
# playable lineage branching up from it, one row per evolution pick.
# Forms the player has evolved into show their sprite and name; the rest are
# dark silhouettes. Drag to pan, pinch or mouse wheel to zoom, tap a form to
# read about it in the side panel. Drawn in one _draw() so 75 forms stay cheap.
extends Control

const UI = preload("res://data/UIStyle.gd")
var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")

const LEAF_GAP = 175.0   # horizontal room for each tip of the tree
const LEVEL_GAP = 215.0  # vertical gap between evolution picks
const NODE_R = 58.0      # radius of the round bubble behind each sprite
const PICK_LABELS = ["Start", "1st evolution", "2nd evolution", "3rd evolution", "4th evolution"]

var found: Array = []
var nodes: Dictionary = {}   # path -> {pos, form, known}
var content_size := Vector2.ZERO
var font_med: Font
var font_bold: Font
var sheets: Dictionary = {}  # id -> Texture2D

var zoom := 0.8
var offset := Vector2.ZERO   # screen position of the content origin
const NONE = "-"         # the root form's path is "", so "no selection" needs its own key
var selected := NONE
var time := 0.0
var fitted := false

# Input: one finger or mouse button pans, two fingers pinch
var touches: Dictionary = {} # index -> position
var press_pos := Vector2.ZERO
var press_moved := false
var mouse_down := false
var pinch_dist := 0.0

var pick_box: StyleBoxFlat
var info: PanelContainer
var info_icon: TextureRect
var info_name: Label
var info_clade: Label
var info_body: Label

func _ready():
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_med = UI.font(500)
	font_bold = UI.font(650)
	found = codex.load_discovered()
	pick_box = StyleBoxFlat.new()
	pick_box.bg_color = Color(UI.INK, 0.85)
	pick_box.set_corner_radius_all(16)
	layout_tree()
	build_info_panel()
	resized.connect(fit_view)

# ---- Layout ----
func layout_tree():
	var next_leaf := [0.0]
	place("", 0, next_leaf)
	var depth_max = 0
	for p in nodes:
		depth_max = max(depth_max, depth_of(p))
	content_size = Vector2(next_leaf[0] * LEAF_GAP, (depth_max + 1) * LEVEL_GAP)
	# Flip so the root sits at the bottom and the tips grow upwards
	for p in nodes:
		var n = nodes[p]
		n.pos = Vector2(n.pos.x, content_size.y - LEVEL_GAP * 0.5 - depth_of(p) * LEVEL_GAP)

func depth_of(path: String) -> int:
	return 0 if path == "" else path.split(",").size()

# Tips get the next free slot; a parent sits over the middle of its children
func place(path: String, depth: int, next_leaf: Array) -> float:
	var kids = lineages.get_child_paths(path)
	var x := 0.0
	if kids.is_empty():
		x = (next_leaf[0] + 0.5) * LEAF_GAP
		next_leaf[0] += 1.0
	else:
		var xs: Array = []
		for k in kids:
			xs.append(place(k, depth + 1, next_leaf))
		x = (xs[0] + xs[-1]) * 0.5
	var form = lineages.get_form(path)
	nodes[path] = {"pos": Vector2(x, 0), "form": form, "known": found.has(form.id), "kids": kids}
	return x

func sheet(id: String) -> Texture2D:
	if not sheets.has(id):
		var p = "res://assets/lineages/%s_sheet.png" % id
		sheets[id] = load(p) if ResourceLoader.exists(p) else null
	return sheets[id]

# Start zoomed so the whole height fits, centred on the starting cell
func fit_view():
	if size.y < 10:
		return
	if not fitted:
		fitted = true
		zoom = clamp(size.y / content_size.y, min_zoom(), 1.6)
		var root_pos = nodes[""].pos
		offset = Vector2(size.x * 0.5 - root_pos.x * zoom, size.y - content_size.y * zoom)
	clamp_offset()
	queue_redraw()

func min_zoom() -> float:
	return clamp(min(size.x / content_size.x, size.y / content_size.y) * 0.95, 0.12, 0.6)

func clamp_offset():
	var w = content_size.x * zoom
	var h = content_size.y * zoom
	var pad = 120.0
	# Room to slide the right end out from under the open info panel
	var right_pad = pad + (info.size.x + 12.0 if info and info.visible else 0.0)
	if w < size.x:
		offset.x = (size.x - w) * 0.5
	else:
		offset.x = clamp(offset.x, size.x - w - right_pad, pad)
	if h < size.y:
		offset.y = (size.y - h) * 0.5
	else:
		offset.y = clamp(offset.y, size.y - h - pad, pad)

func zoom_at(point: Vector2, factor: float):
	var before = (point - offset) / zoom
	zoom = clamp(zoom * factor, min_zoom(), 1.6)
	offset = point - before * zoom
	clamp_offset()
	queue_redraw()

# ---- Drawing ----
func _process(delta: float):
	time += delta
	queue_redraw()

func _draw():
	draw_set_transform(offset, 0.0, Vector2(zoom, zoom))
	# Faint bands naming each evolution pick
	for d in PICK_LABELS.size():
		var y = content_size.y - LEVEL_GAP * 0.5 - d * LEVEL_GAP
		if d % 2 == 0:
			draw_rect(Rect2(-2000, y - LEVEL_GAP * 0.5, content_size.x + 4000, LEVEL_GAP), Color(UI.MEMBRANE, 0.035))
	# Branches first so bubbles sit on top of them
	for p in nodes:
		var n = nodes[p]
		for k in n.kids:
			var c = nodes[k]
			var lit = n.known and c.known
			var col = Color(c.form.color.clamp(), 0.85) if lit else Color(UI.MEMBRANE, 0.22)
			branch(n.pos, c.pos, col, 7.0 if lit else 4.0)
	for p in nodes:
		draw_node(p, nodes[p])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Pick labels stay pinned to the left edge so they're readable when panned
	for d in PICK_LABELS.size():
		var y = offset.y + (content_size.y - LEVEL_GAP * 0.5 - d * LEVEL_GAP) * zoom
		if y > -20 and y < size.y + 20:
			var w = font_med.get_string_size(PICK_LABELS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_style_box(pick_box, Rect2(6, y - 16, w + 20, 32))
			draw_string(font_med, Vector2(16, y + 7), PICK_LABELS[d], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UI.MUTED)

# A soft S-curve, like a branch in a phylogeny drawn by hand
func branch(from: Vector2, to: Vector2, col: Color, width: float):
	var pts := PackedVector2Array()
	var mid_y = (from.y + to.y) * 0.5
	for i in 21:
		var t = i / 20.0
		var a = from.lerp(Vector2(from.x, mid_y), t)
		var b = Vector2(from.x, mid_y).lerp(Vector2(to.x, mid_y), t)
		var c = Vector2(to.x, mid_y).lerp(to, t)
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	draw_polyline(pts, col, width, true)

func draw_node(p: String, n: Dictionary):
	var pos: Vector2 = n.pos
	var form: Dictionary = n.form
	var tint: Color = form.color.clamp()
	var bob = sin(time * 1.6 + pos.x * 0.013) * 3.0 if n.known else 0.0
	var centre = pos + Vector2(0, bob)
	if p == selected:
		draw_circle(centre, NODE_R + 12, Color(UI.SUN, 0.35 + 0.15 * sin(time * 5.0)))
	draw_circle(centre, NODE_R, Color(UI.INK.lerp(tint, 0.18 if n.known else 0.0), 0.95))
	draw_arc(centre, NODE_R, 0, TAU, 48, Color(tint, 0.95) if n.known else Color(UI.MEMBRANE, 0.3), 4.0, true)
	var tex = sheet(form.id)
	if tex:
		var fw = tex.get_width() / 4.0
		var frame = int(fmod(time * 5.0 + pos.x, 4.0)) if n.known else 0
		var src = Rect2(frame * fw, 0, fw, tex.get_height())
		var s = 92.0
		var mod = Color.WHITE if n.known else Color(0.02, 0.05, 0.04, 0.92)
		draw_texture_rect_region(tex, Rect2(centre - Vector2(s, s) * 0.5, Vector2(s, s)), src, mod)
	if not n.known:
		draw_string(font_bold, centre + Vector2(-NODE_R, 14), "?", HORIZONTAL_ALIGNMENT_CENTER, NODE_R * 2, 40, Color(UI.MEMBRANE, 0.55))
	var title = pretty(form.name) if n.known else "???"
	draw_multiline_string(font_med, centre + Vector2(-LEAF_GAP * 0.5 + 4, NODE_R + 24), title,
		HORIZONTAL_ALIGNMENT_CENTER, LEAF_GAP - 8, 19, 2, UI.CREAM if n.known else Color(UI.MUTED, 0.55))

# "SEA LILY" -> "Sea Lily"
func pretty(s: String) -> String:
	return s.capitalize() if s == s.to_upper() else s

# ---- Input ----
func _input(event: InputEvent):
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if not inside(event.position):
				return
			touches[event.index] = event.position
			if touches.size() == 1:
				begin_press(event.position)
			else:
				press_moved = true
				pinch_dist = pinch_span()
		elif touches.has(event.index):
			touches.erase(event.index)
			if touches.is_empty():
				end_press(event.position)
			pinch_dist = pinch_span()
		accept()
	elif event is InputEventScreenDrag:
		if not touches.has(event.index):
			return
		touches[event.index] = event.position
		if touches.size() >= 2:
			var span = pinch_span()
			if pinch_dist > 0.0 and span > 0.0:
				zoom_at(pinch_centre(), span / pinch_dist)
			pinch_dist = span
		else:
			drag(event.relative, event.position)
		accept()
	elif event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		mouse_input(event)
	elif event is InputEventMagnifyGesture and inside(event.position):
		zoom_at(event.position - global_position, event.factor)
		accept()

func mouse_input(event: InputEventMouse):
	if event is InputEventMouseButton:
		if event.pressed and not inside(event.position):
			return
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				mouse_down = event.pressed
				if event.pressed:
					begin_press(event.position)
				else:
					end_press(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				zoom_at(event.position - global_position, 1.12)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_at(event.position - global_position, 1.0 / 1.12)
		accept()
	elif event is InputEventMouseMotion and mouse_down:
		drag(event.relative, event.position)
		accept()

func accept():
	get_viewport().set_input_as_handled()

# Ignore presses outside the tree or on the info panel and its button
func inside(screen_pos: Vector2) -> bool:
	if not get_global_rect().has_point(screen_pos):
		return false
	return not (info.visible and info.get_global_rect().has_point(screen_pos))

func begin_press(pos: Vector2):
	press_pos = pos
	press_moved = false

func drag(rel: Vector2, pos: Vector2):
	if pos.distance_to(press_pos) > 18.0:
		press_moved = true
	offset += rel
	clamp_offset()
	queue_redraw()

func end_press(pos: Vector2):
	if press_moved:
		return
	var local = (pos - global_position - offset) / zoom
	var hit = NONE
	for p in nodes:
		if nodes[p].pos.distance_to(local) < NODE_R + 14:
			hit = p
	select(hit)

func pinch_span() -> float:
	if touches.size() < 2:
		return 0.0
	var v = touches.values()
	return v[0].distance_to(v[1])

func pinch_centre() -> Vector2:
	var v = touches.values()
	return (v[0] + v[1]) * 0.5 - global_position

# ---- Info panel ----
func build_info_panel():
	info = PanelContainer.new()
	info.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 28, 0.97, 26.0))
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.anchor_top = 0.0
	info.anchor_bottom = 1.0
	info.offset_left = -560
	info.offset_right = -12
	info.offset_top = 12
	info.offset_bottom = -12
	info.visible = false
	add_child(info)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	info.add_child(box)
	var top = HBoxContainer.new()
	box.add_child(top)
	info_icon = TextureRect.new()
	info_icon.custom_minimum_size = Vector2(150, 150)
	info_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	info_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(info_icon)
	var close = Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(72, 72)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_EXPAND
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed"]:
		close.add_theme_stylebox_override(state, UI.button_box(state, UI.MEMBRANE))
	close.pressed.connect(func(): select(NONE))
	top.add_child(close)
	info_name = make_label(32, UI.SUN, font_bold)
	box.add_child(info_name)
	info_clade = make_label(20, UI.MUTED, font_med)
	box.add_child(info_clade)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	info_body = make_label(21, UI.CREAM, font_med)
	info_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(info_body)

func make_label(size_px: int, col: Color, f: Font) -> Label:
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	return l

func select(path: String):
	selected = path
	info.visible = path != NONE
	if path == NONE:
		return
	SoundManager.play_sfx("dna_pickup", 1.4)
	var n = nodes[path]
	var form: Dictionary = n.form
	var tex = sheet(form.id)
	if tex:
		var at = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, 0, tex.get_width() / 4.0, tex.get_height())
		info_icon.texture = at
	info_icon.modulate = Color.WHITE if n.known else Color(0.02, 0.05, 0.04, 0.95)
	if n.known:
		info_name.text = pretty(form.name)
		info_clade.text = form.clade_path
		info_body.text = "%s\n\n%s\n\nLiving today: %s\n\nAttack: %s" % [
			form.clade, form.fact, form.living_example, form.get("weapon_name", "")]
	else:
		info_name.text = "Undiscovered"
		if path == "":
			info_clade.text = "Where every run begins"
		else:
			var parent = path.rsplit(",", true, 1)[0] if path.contains(",") else ""
			info_clade.text = "Branches from: %s" % (pretty(nodes[parent].form.name) if nodes[parent].known else "???")
		info_body.text = "Evolve into this lineage during a run to record it in the codex.\n\nEach evolution pick moves one row up the tree."
	# Keep the chosen form visible beside the panel
	var screen = offset + n.pos * zoom
	var free_w = size.x - info.size.x - 24
	if screen.x > free_w - 80 or screen.x < 80:
		offset.x += free_w * 0.5 - screen.x
		clamp_offset()
