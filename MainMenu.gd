# MainMenu.gd
# Title screen: play, pick a starting trait, see challenges and the codex.
# Built in code like the HUD cards. Lineages you have discovered drift
# across the background.
extends Control

var lineages = preload("res://data/Lineages.gd")
var codex = preload("res://data/Codex.gd")
var music_credits = preload("res://data/MusicCredits.gd")
var sound_credits = preload("res://data/SoundCredits.gd")
var progress = preload("res://data/Progress.gd")
var adaptations = preload("res://data/Adaptations.gd")
var endgame = preload("res://data/Endgame.gd")

const UI = preload("res://data/UIStyle.gd")
var ACCENT = UI.SUN
var SOFT = UI.CREAM
const LOCKED = Color(0.45, 0.5, 0.45)
# Title ink and its outline: sepia ink on paper by default, set by the art style
var TITLE_INK = UI.TITLE
var PAPER = UI.TITLE_OUTLINE

var menu_box: VBoxContainer
var trait_btn: Button
var trait_info: Label
var style_btn: Button
var overlay: Control = null
var drifters: Array = []
var scenery: Array = []
# [art, x and y as a fraction of the screen, scale]: kept clear of the
# title and the button panel in the middle
const SCENERY = [
	["tall", 0.14, 0.30, 1.4], ["tall_2", 0.87, 0.27, 1.4],
	["mound", 0.17, 0.78, 1.2], ["fossil", 0.83, 0.74, 1.2],
	["rock_2", 0.06, 0.55, 1.1], ["mound_2", 0.94, 0.52, 1.1],
]

func _ready():
	get_tree().paused = false
	Engine.time_scale = 1.0
	set_anchors_preset(Control.PRESET_FULL_RECT)
	SoundManager.play_menu_music()
	build_background()
	build_menu()

func build_background():
	var bg = ColorRect.new()
	bg.color = UI.BACKDROP
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# The first era's floor, lit and inked exactly as the game draws it
	# (Room.gd + Main.gd CanvasModulate + InkFilter at that era's ink_light)
	var look: Dictionary = preload("res://data/EraLook.gd").get_look(1)
	var room = TextureRect.new()
	room.texture = load("res://assets/eras/ediacaran/room.png")
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	room.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.modulate = look.tint * (SettingsManager.brightness / 1.2)
	room.material = preload("res://data/ArtStyles.gd").floor_material(SettingsManager.art_style, "res://assets/eras/ediacaran/")
	add_child(room)
	# Sunlight rippling over the sea floor, as in the first era
	var light = ColorRect.new()
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = preload("res://data/EraLook.gd").FLOOR_LIGHT_SHADER
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", look.light)
	mat.set_shader_parameter("strength", look.light_power)
	mat.set_shader_parameter("rect_size", Vector2(1920, 1080))
	light.material = mat
	if preload("res://data/ArtStyles.gd").keeps_floor(SettingsManager.art_style):
		add_child(light)
	# Ediacaran scenery on the open floor around the buttons, like a room
	var view = get_viewport_rect().size
	for p in SCENERY:
		var tex_path = "res://assets/eras/ediacaran/%s.png" % p[0]
		if not ResourceLoader.exists(tex_path):
			continue
		var prop = Sprite2D.new()
		prop.texture = load(tex_path)
		prop.position = Vector2(p[1] * view.x, p[2] * view.y)
		prop.scale = Vector2.ONE * p[3]
		prop.modulate = room.modulate
		add_child(prop)
		scenery.append({"node": prop, "t": randf() * TAU})
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
		# Sheets are drawn at 256 px a frame; drift past at 128
		s.scale = Vector2.ONE * 128.0 / s.texture.get_height()
		s.modulate = Color(1, 1, 1, 0.7)
		s.material = UI.sepia_material()
		s.position = Vector2(randf_range(100, 1820), randf_range(150, 950))
		var dir = Vector2.RIGHT.rotated(randf() * TAU)
		s.rotation = dir.angle() + PI / 2
		add_child(s)
		drifters.append({"node": s, "vel": dir * randf_range(25.0, 60.0), "t": randf() * 4.0})
	# The same sepia ink sketch as the game (InkFilter.gd). The paper level
	# is tuned by eye so the bare floor is as pale as the first room in play
	var ink = preload("res://InkFilter.gd").new()
	ink.fixed_light = 0.32
	# The floor key is drawn with the room's own modulate, not a CanvasModulate
	ink.fixed_floor_tint = Color.WHITE
	add_child(ink)

func _process(delta: float):
	var size_now = get_viewport_rect().size
	# Fronds sway in the current like the room scenery
	for p in scenery:
		p.t += delta
		p.node.rotation = sin(p.t * 0.9) * 0.05
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

	# Title and subtitle are inked onto the sketchbook page like the rooms
	var title = label("Evo Roguelike", 104, TITLE_INK)
	title.add_theme_font_override("font", UI.font(650))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_outline_color", PAPER)
	menu_box.add_child(title)
	var sub_font = UI.font(500)
	sub_font.spacing_glyph = 8
	var sub = label("PRIMORDIAL GENESIS", 30, TITLE_INK.lerp(PAPER, 0.25))
	sub.add_theme_font_override("font", sub_font)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", PAPER)
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
	play.set_meta("pad_default", true) # where the gamepad highlight starts
	play.custom_minimum_size = Vector2(600, 92)
	play.add_theme_font_size_override("font_size", 40)
	play.add_theme_font_override("font", UI.font(650))
	col.add_child(play)
	# Parts grown into the lineage for good, from elements banked in runs
	grow_btn = button("", show_lineage_grow, UI.LEAF)
	grow_btn.add_theme_font_size_override("font_size", 28)
	grow_btn.custom_minimum_size = Vector2(600, 76)
	col.add_child(grow_btn)
	_update_grow_text()
	SettingsManager.fullscreen_changed.connect(_update_fullscreen_text)
	# Everything else waits one tap away on the MORE page (kuro: the start
	# screen had too much to read)
	var pair = HBoxContainer.new()
	pair.add_theme_constant_override("separation", 16)
	col.add_child(pair)
	var small: Array = [button("CODEX", show_codex), button("MORE  ›", show_more)]
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		small.append(button("QUIT", func(): get_tree().quit(), UI.CORAL))
	for b in small:
		b.custom_minimum_size = Vector2((600 - 16 * (small.size() - 1)) / small.size(), 70)
		b.add_theme_font_size_override("font_size", 24)
		pair.add_child(b)

	# The title drifts gently, like something floating in the shallows
	var tw = title.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	tw.tween_property(title, "position:y", -6.0, 2.2).as_relative()
	tw.tween_property(title, "position:y", 6.0, 2.2).as_relative()

# ---- MORE: the secondary things, one button each ----
func show_more():
	var list = open_overlay("MORE")
	overlay.set_meta("more", true)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(grid)
	trait_btn = button("", cycle_trait)
	style_btn = button("", show_art_styles)
	dark_btn = button("", toggle_dark_rooms)
	var eg = endgame.unlocked_count()
	var items: Array = [
		trait_btn, style_btn,
		button("CHALLENGES  %d / %d" % [progress.completed().size(), progress.CHALLENGES.size()], show_challenges),
		button("ENDGAME" if eg > 0 else "🔒  ENDGAME", show_endgame, UI.CORAL if eg > 0 else UI.MEMBRANE),
	]
	if progress.run_stats().count > 0:
		items.append(button("PAST RUNS", show_past_runs))
	items.append(dark_btn)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		fullscreen_btn = button("", SettingsManager.toggle_fullscreen)
		_update_fullscreen_text(SettingsManager.is_fullscreen())
		items.append(fullscreen_btn)
	items.append(button("MUSIC CREDITS", show_music_credits))
	for b in items:
		b.custom_minimum_size = Vector2(560, 80)
		b.add_theme_font_size_override("font_size", 24)
		grid.add_child(b)
	if PadInput.using_pad:
		items[0].grab_focus.call_deferred()
	trait_info = label("", 19, UI.MUTED)
	list.add_child(trait_info)
	update_trait_text()
	update_style_text()
	update_dark_text()
	# One quiet line of progress at the bottom
	var runs = progress.run_stats()
	var bits: Array = ["Codex %d / %d" % [codex.load_discovered().size(), lineages.TREE.size()],
		"Fossils %d / 25" % codex.load_eaten().size()]
	if runs.count > 0:
		bits.append("Furthest: era %d" % runs.best_era)
	var stats = label("  ·  ".join(bits), 20, UI.MUTED)
	list.add_child(stats)

var fullscreen_btn: Button

func _update_fullscreen_text(on: bool):
	if not is_instance_valid(fullscreen_btn):
		return
	fullscreen_btn.text = "FULLSCREEN: " + ("ON" if on else "OFF")

func start_game():
	endgame.mode = ""
	SoundManager.play_sfx("evolve")
	get_tree().change_scene_to_file("res://Main.tscn")

# ---- Starting trait: one unlocked adaptation to begin a run with ----
func update_trait_text():
	if not is_instance_valid(trait_btn):
		return
	var current = progress.start_trait()
	var unlocked = progress.unlocked_traits()
	if unlocked.is_empty():
		trait_btn.text = "🔒  STARTING TRAIT"
		trait_btn.disabled = true
		trait_info.text = "Win a challenge to unlock a starting trait."
	elif current == "":
		trait_btn.text = "STARTING TRAIT: none"
		trait_info.text = "Tap STARTING TRAIT to pick one."
	else:
		var a = adaptations.get_adaptation(current)
		trait_btn.text = "TRAIT: " + a.name
		trait_info.text = a.name + ": " + a.effect

func cycle_trait():
	var options: Array = [""] + progress.unlocked_traits()
	var i = options.find(progress.start_trait())
	progress.set_start_trait(options[(i + 1) % options.size()])
	SoundManager.play_sfx("dna_pickup", 1.2)
	update_trait_text()

# ---- Art style: the look of the whole game (data/ArtStyles.gd) ----
const ArtStyles = preload("res://data/ArtStyles.gd")

func update_style_text():
	if is_instance_valid(style_btn):
		style_btn.text = "🎨  STYLE: " + ArtStyles.get_style(SettingsManager.art_style).name

func show_art_styles():
	var area = open_overlay("ART STYLE")
	area.add_child(label("How the whole world is drawn: rooms, scenery, animals and you. Tap one to use it; it is saved for next time.", 20, UI.MUTED))
	var grid = GridContainer.new()
	var wide = get_viewport_rect().size.x >= 1500
	grid.columns = 3 if wide else 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	area.add_child(grid)
	for st in ArtStyles.STYLES:
		grid.add_child(style_card(st, st.id == SettingsManager.art_style))

func style_card(st: Dictionary, chosen: bool) -> Control:
	var card = Button.new()
	card.custom_minimum_size = Vector2(540, 290)
	var tint = UI.SUN if chosen else UI.MEMBRANE
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = UI.panel(tint, 14, 0.85 if chosen else 0.55, 14.0)
		if chosen:
			box.border_width_left = 5
			box.border_width_right = 5
			box.border_width_top = 5
			box.border_width_bottom = 5
		card.add_theme_stylebox_override(state, box)
	card.pressed.connect(func(): pick_style(st.id))
	var col = VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var pic = TextureRect.new()
	pic.custom_minimum_size = Vector2(500, 162)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path = ArtStyles.thumb_path(st.id)
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	col.add_child(pic)
	var n = label(("✓  " if chosen else "") + st.name, 24, UI.SUN if chosen else UI.CREAM)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(n)
	var d = label(st.desc, 17, UI.MUTED)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(d)
	return card

func pick_style(id: String):
	SettingsManager.set_art_style(id)
	SoundManager.play_sfx("evolve")
	# Rebuild the menu so its panels, buttons and title take the new style
	get_tree().call_deferred("reload_current_scene")

# ---- Overlays ----
func open_overlay(title: String, scrolling: bool = true) -> VBoxContainer:
	var f = get_viewport().gui_get_focus_owner()
	if f and menu_box.is_ancestor_of(f):
		menu_focus = f
	if overlay == null:
		back_to_more = false
	elif overlay.get_meta("more", false):
		back_to_more = true
	_drop_overlay()
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
	if not scrolling:
		var area = VBoxContainer.new()
		area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer.add_child(area)
		return area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list

# Android back button: leave the open page, or close the game from the menu
func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if overlay:
			close_overlay()
		else:
			get_tree().quit()

# BACK from a page opened on MORE returns to MORE
var back_to_more := false

func _drop_overlay():
	if overlay:
		overlay.queue_free()
		overlay = null

func close_overlay():
	if back_to_more and overlay and not overlay.get_meta("more", false):
		back_to_more = false
		show_more()
		return
	back_to_more = false
	_drop_overlay()
	if menu_box:
		menu_box.visible = true
		_update_grow_text()
		_refocus_menu.call_deferred()

# The menu button that opened a page, so the gamepad highlight goes back to it
var menu_focus: Control = null

func _refocus_menu():
	if overlay == null and PadInput.using_pad and is_instance_valid(menu_focus) and menu_focus.is_visible_in_tree():
		menu_focus.grab_focus()

# Gamepad B (PadInput.gd): close the codex panel or page; never quits
func pad_back():
	if overlay:
		var tree = overlay.find_children("*", "Control", true, false).filter(func(c): return c.has_method("pad_back"))
		if not tree.is_empty() and tree[0].pad_back():
			return
		SoundManager.play_sfx("dna_pickup", 0.8)
		close_overlay()

func row(parent: Container, title: String, body: String, color: Color):
	var t = label(title, 26, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(t)
	var b = label(body, 20, SOFT if color != LOCKED else color)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(b)
	parent.add_child(HSeparator.new())

var dark_btn: Button = null

func update_dark_text():
	if not is_instance_valid(dark_btn):
		return
	dark_btn.text = "DARK ROOMS: " + ("EVERY ROOM" if SettingsManager.dark_rooms_all else "ONE A FLOOR")

func toggle_dark_rooms():
	SettingsManager.dark_rooms_all = not SettingsManager.dark_rooms_all
	SettingsManager.save_settings()
	SoundManager.play_sfx("dna_pickup", 0.8 if SettingsManager.dark_rooms_all else 1.2)
	update_dark_text()
const POOL_NAMES = {"menu": "Menu", "explore": "Floors", "boss": "Bosses"}

var grow_btn: Button = null

func _update_grow_text():
	if grow_btn == null:
		return
	var B = preload("res://data/Biominerals.gd")
	var bank = progress.bank()
	var ranks = progress.lineage_ranks()
	var can = 0
	var U = preload("res://data/Unlocks.gd")
	var st = progress.stats()
	for r in B.lineage_recipes():
		if B.can_grow_lineage(r, bank, ranks) and U.is_unlocked(r.id, st, ranks):
			can += 1
	grow_btn.text = "🌱  GROW YOUR LINEAGE" + ("  (%d ready)" % can if can > 0 else "")

func show_lineage_grow():
	SoundManager.play_sfx("dna_pickup", 1.1)
	var area = open_overlay("GROW YOUR LINEAGE", false)
	area.add_child(preload("res://LineageGrow.gd").new())

func show_music_credits():
	var list = open_overlay("MUSIC CREDITS")
	var intro = label("All music is from OpenGameArt.org. Thank you to the artists!", 22, SOFT)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(intro)
	list.add_child(HSeparator.new())
	for t in music_credits.TRACKS:
		row(list, "#%d  %s  ·  \"%s\"" % [t.get("num", 0), POOL_NAMES.get(t.pool, t.pool), t.title],
			"by %s  ·  %s\n%s" % [t.artist, t.license, t.url], ACCENT)
	list.add_child(HSeparator.new())
	var sfx = label("Combat sounds are CC0 recordings from OpenGameArt.org, softened for the game:", 22, SOFT)
	sfx.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	sfx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(sfx)
	for p in sound_credits.PACKS:
		row(list, "🔊  " + p.title, "by %s  ·  %s\n%s" % [p.artist, p.license, p.url], ACCENT)
	var note = label("CC-BY 4.0: creativecommons.org/licenses/by/4.0  ·  CC0: public domain", 18, UI.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(note)

func show_challenges():
	var list = open_overlay("CHALLENGES")
	for c in progress.CHALLENGES:
		var done = progress.is_complete(c.id)
		var t = label(("✓ " if done else "○ ") + c.name, 26, UI.LEAF if done else UI.CREAM)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(t)
		var g = label(c.goal, 20, SOFT)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(g)
		list.add_child(trait_card(adaptations.get_adaptation(c.unlock), done, progress.start_trait() == c.unlock))
		list.add_child(HSeparator.new())

# ENDGAME: content a won run opens, each with its goal while locked, and the
# bosses waiting there drawn live (BossPortrait.gd), dark until unlocked
func show_endgame():
	var list = open_overlay("ENDGAME  %d / %d" % [endgame.unlocked_count(), endgame.ENTRIES.size()])
	for e in endgame.ENTRIES:
		list.add_child(endgame_card(e))

func endgame_card(e: Dictionary) -> Control:
	var open = endgame.is_unlocked(e.id)
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.CORAL if open else LOCKED, 20, 0.75, 16.0))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var pics = VBoxContainer.new()
	row.add_child(pics)
	for b in e.get("bosses", []):
		var info = endgame.boss_info(b)
		pics.add_child(preload("res://BossPortrait.gd").new().setup(info.script, not open))
		var cap = label(("%s  (%s)" % [info.name, info.world]) if open else "? ? ?", 18, UI.CREAM if open else UI.MUTED)
		pics.add_child(cap)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var title = label(("" if open else "🔒 ") + e.name, 30, UI.SUN if open else UI.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(title)
	var p = endgame.progress_of(e.id)
	var goal = label(("UNLOCKED" if open else "To unlock: %s  (%d / %d)" % [e.goal, p[0], p[1]]), 22, UI.LEAF if open else UI.SUN)
	goal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(goal)
	for t in [e.what, e.fact]:
		var l = label(t, 19, SOFT if open else UI.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	if open and e.get("play", false):
		var go = button("▶  PLAY THE GAUNTLET", start_gauntlet, UI.SUN)
		go.custom_minimum_size = Vector2(420, 70)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(go)
	if open and e.get("toggle", false):
		var tg = button("", func(): pass)
		tg.custom_minimum_size = Vector2(420, 70)
		tg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var show_state = func(): tg.text = "DEEP TIME: " + ("ON for every run" if endgame.deep_time() else "OFF")
		show_state.call()
		tg.pressed.connect(func():
			endgame.set_deep_time(not endgame.deep_time())
			SoundManager.play_sfx("dna_pickup", 0.8)
			show_state.call())
		col.add_child(tg)
	if open:
		for b in e.get("bosses", []):
			var info = endgame.boss_info(b)
			var l = label("%s: %s" % [info.name, info.fact], 18, UI.MUTED)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			col.add_child(l)
	return card

func start_gauntlet():
	endgame.mode = "gauntlet"
	SoundManager.play_sfx("evolve")
	get_tree().change_scene_to_file("res://Main.tscn")

# What a challenge's starting trait does: name, effect and the real biology
func trait_card(a: Dictionary, unlocked: bool, chosen: bool) -> Control:
	var card = PanelContainer.new()
	var tint = UI.LEAF if unlocked else LOCKED
	card.add_theme_stylebox_override("panel", UI.panel(tint, 18, 0.7, 16.0))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var head = "Starting trait: " if unlocked else "Unlocks starting trait: "
	var n = label(head + a.name + ("  (chosen)" if chosen else ""), 22, UI.SUN if unlocked else UI.CREAM)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(n)
	var e = label(a.effect, 20, UI.LEAF if unlocked else UI.MUTED)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(e)
	var f = label(a.fact, 18, UI.MUTED)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(f)
	return card

# The codex opens on the evolution tree (CodexTree.gd); LIST shows the
# same forms as plain text rows.
func show_codex():
	var found: Array = codex.load_discovered()
	var area = open_overlay("CODEX  %d / %d" % [found.size(), lineages.TREE.size()], false)
	add_overlay_button(area, "☰  LIST", show_codex_list)
	add_overlay_button(area, "FOSSILS", show_fossils)
	var hint = label("Drag to explore  ·  pinch to zoom  ·  tap a form to read about it", 18, UI.MUTED)
	area.add_child(hint)
	var tree = preload("res://CodexTree.gd").new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_child(tree)

# The fossil record: every era animal and boss, grouped by era. Eaten ones
# show their picture and the real biology; the rest are dark silhouettes.
const FAUNA = preload("res://data/Fauna.gd")
const ERA_NAMES = ["Ediacaran", "Cambrian", "Ordovician", "Carboniferous", "Permian", "Carboniferous seas", "Permian seas"]
const Worlds = preload("res://data/Worlds.gd")

func show_fossils():
	var eaten: Array = codex.load_eaten()
	var total := 0
	# Era lists start from the land worlds; the sea worlds are eras 6 and 7
	Worlds.sea = false
	Worlds.finale = false
	for era in Worlds.ERA_ORDER:
		total += FAUNA.era_species(era).size() + 2
	var list = open_overlay("FOSSIL RECORD  %d / %d" % [eaten.size(), total])
	add_overlay_button(list.get_parent(), "CODEX", show_codex)
	add_overlay_button(list.get_parent(), "TRACES", show_traces)
	list.add_child(label("Every animal you eat, or sketch from life by holding still near it, is added here, with what is known about it.", 19, UI.MUTED))
	for era in Worlds.ERA_ORDER:
		var head = label(ERA_NAMES[era - 1].to_upper() + ("" if era > 5 else " PERIOD") + ("  ·  ON LAND" if era in [4, 5] else ""), 26, UI.SUN)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		list.add_child(head)
		var species: Array = FAUNA.era_species(era).duplicate()
		var boss: Dictionary = FAUNA.BOSSES[era].duplicate()
		boss["boss"] = true
		species.append(boss)
		var alt: Dictionary = FAUNA.ALT_BOSSES[era].duplicate()
		alt["boss"] = true
		species.append(alt)
		for f in species:
			list.add_child(fossil_row(f, eaten.has(f.name) or codex.load_sketches().has(f.name), ERA_NAMES[era - 1]))

func fossil_row(f: Dictionary, known: bool, era_name: String) -> Control:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.SUN if f.get("boss", false) else UI.MEMBRANE, 18, 0.7, 12.0))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	var pic = TextureRect.new()
	pic.custom_minimum_size = Vector2(96, 96)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path = FAUNA.sheet_path(f)
	var icon = "res://assets/fossils/%s.png" % f.name.to_lower() # bosses, tools/fossil_icons.gd
	if ResourceLoader.exists(icon):
		pic.texture = load(icon)
	elif ResourceLoader.exists(path):
		var sheet: Texture2D = load(path)
		var frame = AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(0, 0, sheet.get_height(), sheet.get_height())
		pic.texture = frame
	if not known:
		pic.modulate = Color(0.10, 0.065, 0.04, 0.95)
	else:
		pic.material = UI.sepia_material()
	if pic.texture:
		row.add_child(pic)
	else:
		# No picture for it: a fossil mark
		var mark = label("✓" if known else "?", 54, UI.SUN if known else UI.MUTED)
		mark.custom_minimum_size = Vector2(96, 96)
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(mark)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var title = f.name + ("  ·  ERA BOSS" if f.get("boss", false) else "")
	var n = label(title if known else "?  " + ("Era boss" if f.get("boss", false) else "Unknown animal"), 22, UI.SUN if known else UI.MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(n)
	var body = label(f.fact if known else "Not yet eaten or sketched. It lived in the %s." % era_name, 18, UI.CREAM if known else UI.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(body)
	if known and codex.load_sketches().has(f.name):
		var sk = label("SKETCHED FROM LIFE", 17, UI.SUN)
		sk.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(sk)
	if known:
		var web = food_web_line(f.name)
		if web != "":
			var w = label(web, 17, UI.MUTED)
			w.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			col.add_child(w)
	return card

# Trace fossils (data/Traces.gd): every kind of track you have seen made,
# drawn as a strip of sediment, with who made it
func show_traces():
	var traces = preload("res://data/Traces.gd")
	var seen: Array = codex.load_traces()
	var ids: Array = traces.all_ids()
	var list = open_overlay("TRACE FOSSILS  %d / %d" % [ids.filter(func(i): return seen.has(i)).size(), ids.size()])
	add_overlay_button(list.get_parent(), "FOSSILS", show_fossils)
	list.add_child(label("Tracks, trails and resting marks left in the mud. They are named as their own genera, because the animal that made one is seldom found with it.", 19, UI.MUTED))
	# Found ones first, in the order of the eras
	for id in ids.filter(func(i): return seen.has(i)) + ids.filter(func(i): return not seen.has(i)):
		list.add_child(trace_row(id, seen.has(id)))

func trace_row(id: String, known: bool) -> Control:
	var t: Dictionary = preload("res://data/Traces.gd").TRACES[id]
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 18, 0.7, 12.0))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card.add_child(row)
	# A strip of pale sediment with the trace pressed into it
	var pic = Control.new()
	pic.custom_minimum_size = Vector2(220, 96)
	var paper = StyleBoxFlat.new()
	paper.bg_color = Color(0.86, 0.8, 0.66)
	paper.border_color = Color(0.45, 0.33, 0.2)
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(10)
	pic.draw.connect(func():
		var box = Rect2(Vector2.ZERO, pic.size)
		pic.draw_style_box(paper, box)
		if known:
			preload("res://data/Traces.gd").draw_sample(pic, id, box.grow(-6.0), 1.6)
		else:
			pic.draw_string(ThemeDB.fallback_font, Vector2(box.get_center().x - 12.0, box.get_center().y + 16.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.24, 0.15, 0.08, 0.5)))
	row.add_child(pic)
	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var n = label(("%s  ·  made by %s" % [t.name, t.maker]) if known else "?  Unknown trace", 22, UI.SUN if known else UI.MUTED)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(n)
	var body = label(t.fact if known else "Not yet seen. Watch the ground behind the animals you meet.", 18, UI.CREAM if known else UI.MUTED)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(body)
	return card

# What it was seen eating and being eaten by (data/FoodWeb.gd); links not
# yet watched in a run show as "?"
func food_web_line(species: String) -> String:
	var web = preload("res://data/FoodWeb.gd")
	var seen: Array = codex.load_hunts()
	var parts: Array = []
	var eats: Array = web.EATS.get(species, [])
	if not eats.is_empty():
		var names = eats.map(func(p): return p if seen.has(web.link(species, p)) else "?")
		parts.append("Hunts: " + ", ".join(names))
	var by: Array = web.eaten_by(species)
	if not by.is_empty():
		var names = by.map(func(h): return h if seen.has(web.link(h, species)) else "?")
		parts.append("Hunted by: " + ", ".join(names))
	return "   ·   ".join(parts)

# Past runs, newest first: the lineage each one walked, in pictures, and
# where and how it ended (Progress.record_run)
func show_past_runs():
	var runs: Array = progress.history().duplicate()
	runs.reverse()
	var list = open_overlay("PAST RUNS  %d" % progress.run_stats().count)
	if runs.is_empty():
		list.add_child(label("Your runs will be kept here from now on.", 20, UI.MUTED))
		return
	for r in runs:
		list.add_child(past_run_row(r))

func past_run_row(r: Dictionary) -> Control:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.panel(UI.SUN if r.get("won", false) else UI.MEMBRANE, 18, 0.7, 12.0))
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var era = int(r.get("era", 1))
	var head: String
	if r.get("won", false):
		head = "Survived to the end as %s" % String(r.get("form", "")).to_lower().capitalize()
		if String(r.get("finale", "")) == "won":
			head = "Lived through the Great Dying as %s" % String(r.get("form", "")).to_lower().capitalize()
	else:
		var where = int(r.get("world_era", era))
		head = "%s, era %d: %s" % [ERA_NAMES[clampi(where, 1, 7) - 1], era, String(r.get("form", "")).to_lower().capitalize()]
		if String(r.get("killer", "")) != "":
			head += "  ·  killed by %s" % r.killer
	if r.get("deep", false):
		head = "DEEP TIME  ·  " + head
	var h = label(head, 22, UI.SUN if r.get("won", false) else UI.CREAM)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(h)
	var strip = HFlowContainer.new()
	strip.add_theme_constant_override("h_separation", 6)
	strip.add_theme_constant_override("v_separation", 6)
	col.add_child(strip)
	var path: Array = r.get("path", [])
	for i in path.size():
		if i > 0:
			var arrow = label("›", 26, UI.MUTED)
			arrow.custom_minimum_size = Vector2(0, 72)
			arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			strip.add_child(arrow)
		var pic = TextureRect.new()
		pic.custom_minimum_size = Vector2(72, 72)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.tooltip_text = String(path[i]).replace("_", " ").capitalize()
		var sheet_path = "res://assets/lineages/%s_sheet.png" % path[i]
		if ResourceLoader.exists(sheet_path):
			var sheet: Texture2D = load(sheet_path)
			var frame = AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(0, 0, sheet.get_height(), sheet.get_height())
			pic.texture = frame
			pic.material = UI.sepia_material()
		strip.add_child(pic)
	var bits: Array = []
	if r.has("kills"):
		bits.append("%d eaten" % int(r.kills))
	if r.has("parts"):
		bits.append("%d parts grown" % int(r.parts))
	if r.has("date"):
		bits.append(String(r.date))
	if not bits.is_empty():
		var foot = label("  ·  ".join(bits), 17, UI.MUTED)
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(foot)
	return card

# Puts an extra button next to BACK in the overlay's top bar
func add_overlay_button(area: Control, text: String, on_press: Callable):
	var top: HBoxContainer = area.get_parent().get_child(0)
	var b = button(text, on_press)
	b.custom_minimum_size = Vector2(200, 64)
	top.add_child(b)
	top.move_child(b, top.get_child_count() - 2)

func show_codex_list():
	var found: Array = codex.load_discovered()
	var list = open_overlay("CODEX  %d / %d" % [found.size(), lineages.TREE.size()])
	add_overlay_button(list.get_parent(), "TREE", show_codex)
	# Tree order: the path keys sort parents before children
	var paths: Array = lineages.TREE.keys()
	paths.sort_custom(func(a, b): return a.split(",").size() < b.split(",").size() or (a.split(",").size() == b.split(",").size() and a < b))
	for p in paths:
		var f = lineages.TREE[p]
		if found.has(f.id):
			row(list, f.name, "%s\n%s\nLiving today: %s" % [f.clade_path, f.fact, f.living_example], UI.ink_tint(f.color))
		else:
			row(list, "??? (undiscovered)", "Evolve into this lineage to record it.", LOCKED)
