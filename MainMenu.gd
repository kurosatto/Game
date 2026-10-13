# MainMenu.gd
# Title screen: play, pick a starting trait, see challenges and the codex.
# Built in code like the HUD cards. Lineages you have discovered drift
# across the background.
extends Control

var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")
var progress = preload("res://data/Progress.gd")
var adaptations = preload("res://data/Adaptations.gd")

const ACCENT = Color(0.0, 1.0, 0.85)
const SOFT = Color(0.72, 0.85, 0.96)

var menu_box: VBoxContainer
var trait_btn: Button
var overlay: Control = null
var drifters: Array = []

func _ready():
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SoundManager.play_music(SoundManager.music_for_floor(1))
	build_background()
	build_menu()

func build_background():
	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.04, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var room = TextureRect.new()
	room.texture = load("res://assets/eras/ediacaran/room.png")
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.modulate = Color(0.35, 0.5, 0.6, 1.0)
	add_child(room)
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
		s.modulate = Color(1, 1, 1, 0.55)
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

func button(text: String, on_press: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 76)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(on_press)
	return b

func build_menu():
	menu_box = VBoxContainer.new()
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_theme_constant_override("separation", 18)
	add_child(menu_box)

	menu_box.add_child(label("EVO ROGUELIKE", 72, ACCENT))
	menu_box.add_child(label("PRIMORDIAL GENESIS", 32, SOFT))
	var done = progress.completed().size()
	menu_box.add_child(label("Codex %d / %d lineages  ·  Challenges %d / %d" % [
		codex.load_discovered().size(), lineages.TREE.size(), done, progress.CHALLENGES.size()], 20, Color(0.55, 0.7, 0.8)))
	var gap = Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	menu_box.add_child(gap)

	for b in [
		button("▶  PLAY", start_game),
		null,
		button("🏆  CHALLENGES", show_challenges),
		button("📖  CODEX", show_codex),
	]:
		if b == null:
			trait_btn = button("", cycle_trait)
			update_trait_text()
			b = trait_btn
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		menu_box.add_child(b)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var q = button("QUIT", func(): get_tree().quit())
		q.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		menu_box.add_child(q)

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
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.07, 0.11, 0.97)
	style.border_color = ACCENT * Color(1, 1, 1, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(30)
	overlay.add_theme_stylebox_override("panel", style)
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
	var b = label(body, 20, SOFT if color != Color(0.4, 0.45, 0.5) else color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	parent.add_child(HSeparator.new())

func show_challenges():
	var list = open_overlay("🏆 CHALLENGES")
	for c in progress.CHALLENGES:
		var a = adaptations.get_adaptation(c.unlock)
		if progress.is_complete(c.id):
			row(list, "✓ " + c.name, "%s.  Unlocked starting trait: %s (%s)" % [c.goal, a.name, a.effect], Color(0.45, 1.0, 0.6))
		else:
			row(list, "○ " + c.name, "%s.  Unlocks starting trait: %s" % [c.goal, a.name], Color(0.9, 0.9, 0.9))

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
			row(list, "??? (undiscovered)", "Evolve into this lineage to record it.", Color(0.4, 0.45, 0.5))
