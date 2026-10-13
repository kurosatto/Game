# MainMenu.gd
# Title screen: play, pick a starting trait, see challenges and the codex.
# Built in code like the HUD cards. Lineages you have discovered drift
# across the background.
extends Control

var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")
var progress = preload("res://data/Progress.gd")
var adaptations = preload("res://data/Adaptations.gd")

const UI = preload("res://data/UIStyle.gd")
const ACCENT = UI.SUN
const SOFT = UI.CREAM
const LOCKED = Color(0.45, 0.5, 0.45)

var menu_box: VBoxContainer
var trait_btn: Button
var overlay: Control = null
var drifters: Array = []

func _ready():
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SoundManager.play_music("title")
	build_background()
	build_menu()

func build_background():
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var room = TextureRect.new()
	room.texture = load("res://assets/eras/ediacaran/room.png")
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.modulate = Color(0.5, 0.62, 0.56, 1.0)
	add_child(room)
	# Darker edges pull the eye to the title and buttons
	var grad = Gradient.new()
	grad.set_color(0, Color(0.0, 0.03, 0.02, 0.0))
	grad.set_color(1, Color(0.0, 0.03, 0.02, 0.75))
	grad.add_point(0.45, Color(0.0, 0.03, 0.02, 0.15))
	var vtex = GradientTexture2D.new()
	vtex.gradient = grad
	vtex.fill = GradientTexture2D.FILL_RADIAL
	vtex.fill_from = Vector2(0.5, 0.5)
	vtex.fill_to = Vector2(1.1, 1.1)
	var vignette = TextureRect.new()
	vignette.texture = vtex
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sunlight rippling over the sea floor, as in the first era
	var light = ColorRect.new()
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = preload("res://data/EraLook.gd").FLOOR_LIGHT_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Color(0.55, 1.0, 0.85))
	mat.set_shader_parameter("strength", 0.09)
	mat.set_shader_parameter("rect_size", Vector2(1920, 1080))
	light.material = mat
	add_child(light)
	add_child(vignette)
	# Discovered lineages drift past; the starting cell if nothing yet
	var found: Array = codex.load_discovered()
	if found.is_empty():
		found = ["ancestral_collar_cell"]
	found.shuffle()
	for id in found.slice(0, 8):
		var path = "res://assets/lineages/%s_sheet.png" % id
		if not ResourceLoader.exists(path):
			continue
		var s = Sprite2D.new()
		s.texture = load(path)
		s.hframes = 4
		s.modulate = Color(1, 1, 1, 0.7)
		s.position = Vector2(randf_range(100, 1820), randf_range(150, 950))
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		s.rotation = dir.angle() + PI / 2
		add_child(s)
		drifters.append({"node": s, "vel": dir * randf_range(25.0, 60.0), "t": randf() * 4.0})

func _process(delta: float):
	var size_now = get_viewport_rect().size
	for d in drifters:
		var s: Sprite2D = d.node
		d.t += delta
		s.position += d.vel * delta
		s.frame = int(fmod(d.t * 5.0, 4.0))
		s.position.x = wrapf(s.position.x, -80.0, size_now.x + 80.0)
		s.position.y = wrapf(s.position.y, -80.0, size_now.y + 80.0)

func label(text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func button(text: String, on_press: Callable, tint: Color = UI.MEMBRANE) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 76)
	b.add_theme_font_size_override("font_size", 30)
	for state in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(state, UI.button_box(state, tint))
	b.pressed.connect(on_press)
	return b

func build_menu():
	menu_box = VBoxContainer.new()
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 18)
	add_child(menu_box)

	var title = label("Evo Roguelike", 104, ACCENT)
	title.add_theme_font_override("font", UI.font(650))
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.12, 0.08))
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_color_override("font_shadow_color", Color(0, 0.03, 0.02, 0.5))
	menu_box.add_child(title)
	var sub_font = UI.font(500)
	sub_font.spacing_glyph = 8
	var sub = label("PRIMORDIAL GENESIS", 30, UI.LEAF)
	sub.add_theme_font_override("font", sub_font)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color(0.02, 0.07, 0.05))
	menu_box.add_child(sub)
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	menu_box.add_child(gap)

	# The buttons sit in a membrane like the cells you start as
	var membrane = PanelContainer.new()
	membrane.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	membrane.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 44, 0.8, 34.0))
	menu_box.add_child(membrane)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	membrane.add_child(col)
	var play = button("▶  PLAY", start_game, UI.SUN)
	play.custom_minimum_size = Vector2(600, 92)
	play.add_theme_font_size_override("font_size", 40)
	play.add_theme_font_override("font", UI.font(650))
	col.add_child(play)
	trait_btn = button("", cycle_trait)
	trait_btn.add_theme_font_size_override("font_size", 24)
	update_trait_text()
	col.add_child(trait_btn)
	var pair = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	col.add_child(pair)
	for b in [button("🏆  CHALLENGES", show_challenges), button("📖  CODEX", show_codex)]:
		b.custom_minimum_size = Vector2(292, 76)
		b.add_theme_font_size_override("font_size", 26)
		pair.add_child(b)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var q = button("QUIT", func(): get_tree().quit(), UI.CORAL)
		q.custom_minimum_size = Vector2(600, 60)
		q.add_theme_font_size_override("font_size", 22)
		col.add_child(q)
	var done = progress.completed().size()
	var stats = label("Codex %d / %d lineages  ·  Challenges %d / %d" % [
		codex.load_discovered().size(), lineages.TREE.size(), done, progress.CHALLENGES.size()], 20, UI.MUTED)
	stats.add_theme_constant_override("outline_size", 6)
	menu_box.add_child(stats)

	# The title drifts gently, like something floating in the shallows
	var tw = title.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "position:y", -6.0, 2.2).as_relative()
	tw.tween_property(title, "position:y", 6.0, 2.2).as_relative()

func start_game():
	SoundManager.play_sfx("evolve")
	get_tree().change_scene_to_file("res://Main.tscn")

# ---- Starting trait: one unlocked adaptation to begin a run with ----
func update_trait_text():
	var current = progress.start_trait()
	var unlocked = progress.unlocked_traits()
	if unlocked.is_empty():
		trait_btn.text = "🔒  STARTING TRAIT: complete a challenge"
		trait_btn.disabled = true
	elif current == "":
		trait_btn.text = "🧬  STARTING TRAIT: none (tap to choose)"
	else:
		trait_btn.text = "🧬  STARTING TRAIT: " + adaptations.get_adaptation(current).name

func cycle_trait():
	var options: Array = [""] + progress.unlocked_traits()
	var i = options.find(progress.start_trait())
	progress.set_start_trait(options[(i + 1) % options.size()])
	SoundManager.play_sfx("dna_pickup", 1.2)
	update_trait_text()

# ---- Overlays ----
func open_overlay(title: String) -> VBoxContainer:
	close_overlay()
	menu_box.visible = false
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 40)
	overlay.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 36, 0.96, 34.0))
	add_child(overlay)
	var outer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	overlay.add_child(outer)
	var top = HBoxContainer.new()
	outer.add_child(top)
	var t = label(title, 40, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var back = button("◀  BACK", close_overlay)
	back.custom_minimum_size = Vector2(220, 64)
	top.add_child(back)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list

func close_overlay():
	if overlay:
		overlay.queue_free()
		overlay = null
	if menu_box:
		menu_box.visible = true
		update_trait_text()

func row(parent: Container, title: String, body: String, color: Color):
	var t = label(title, 26, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(t)
	var b = label(body, 20, SOFT if color != LOCKED else color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	parent.add_child(HSeparator.new())

func show_challenges():
	var list = open_overlay("🏆 CHALLENGES")
	for c in progress.CHALLENGES:
		var a = adaptations.get_adaptation(c.unlock)
		if progress.is_complete(c.id):
			row(list, "✓ " + c.name, "%s.  Unlocked starting trait: %s (%s)" % [c.goal, a.name, a.effect], UI.LEAF)
		else:
			row(list, "○ " + c.name, "%s.  Unlocks starting trait: %s" % [c.goal, a.name], UI.CREAM)

func show_codex():
	var found: Array = codex.load_discovered()
	var list = open_overlay("📖 CODEX  %d / %d" % [found.size(), lineages.TREE.size()])
	# Tree order: the path keys sort parents before children
	var paths: Array = lineages.TREE.keys()
	paths.sort_custom(func(a, b): return a.split(",").size() < b.split(",").size() or (a.split(",").size() == b.split(",").size() and a < b))
	for p in paths:
		var f = lineages.TREE[p]
		if found.has(f.id):
			row(list, f.name, "%s\n%s\nLiving today: %s" % [f.clade_path, f.fact, f.living_example], f.color)
		else:
			row(list, "??? (undiscovered)", "Evolve into this lineage to record it.", LOCKED)
