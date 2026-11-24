# LineageGrow.gd
# The main menu GROW page (kuro, 2026-11-24): parts grown here are grown
# into the lineage for good, so every run starts with them. It spends the
# elements banked from every run so far (data/Progress.gd), with the same
# fixed grid of real biomineral parts the in-run screen used to have
# (data/Biominerals.gd lineage_*). Tap a part to read it, tap again to grow
# it; each part has up to three ranks, each dearer than the last.
extends VBoxContainer

const UI = preload("res://data/UIStyle.gd")
const B = preload("res://data/Biominerals.gd")
const PROGRESS = preload("res://data/Progress.gd")
const START_FORM := "ancestral_collar_cell"
# Parts PlayerBody draws on the creature
const VISIBLE = ["calcite_spines", "keratin_horn", "keratin_claws", "magnetite_teeth",
	"photoreceptors", "calcite_lenses", "zinc_jaws"]

var bank: Dictionary = {}
var ranks: Dictionary = {}
var selected: String = ""
var just_grown: String = ""
var tiles: Dictionary = {} # id -> {tile, name, cost, effect, icon, meter, pips}
var chips: Dictionary = {}
var title: Label
var change: RichTextLabel
var body: Label
var go: Button
var portrait: Control
var body_art: Node2D
var caption: Label
var total_label: Label

# A thin bar along the bottom of a tile: how close the bank is to the next rank
class Meter extends Control:
	var frac: float = 0.0
	var col: Color = Color.WHITE
	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		if frac > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * frac, size.y)), col)

# Rank pips: one ring per rank, filled once grown
class Pips extends Control:
	var have: int = 0
	var most: int = 3
	var col: Color = Color.WHITE
	func _draw():
		for i in most:
			var c = Vector2(size.x - 10.0 - (most - 1 - i) * 18.0, size.y / 2.0)
			if i < have:
				draw_circle(c, 6.0, col)
			draw_arc(c, 6.0, 0.0, TAU, 20, Color(col, 0.9), 1.6, true)

class Mote extends Control:
	var col: Color = Color.WHITE
	func _draw():
		var c = size / 2.0
		var pts = PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(0, 8), c + Vector2(-6, 0)])
		draw_colored_polygon(pts, col)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.18, 0.11, 0.06), 1.5, true)

# Scales the drawing to fill the frame, whatever the form's size
class Fit extends Node2D:
	var body: Node2D = null
	var room: float = 140.0
	func _process(delta: float):
		if body == null or body._hull.size() < 3:
			return
		var r := 1.0
		for q in body._hull:
			r = max(r, q.length())
		var want = clampf(room / (r + 14.0), 1.0, 4.0)
		scale = Vector2.ONE * (want if scale.x < 0.01 or absf(scale.x - want) > 0.6 else lerpf(scale.x, want, 1.0 - exp(-delta * 6.0)))

func _ready():
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	bank = PROGRESS.bank()
	ranks = PROGRESS.lineage_ranks()
	_build()
	_fill()

func _build():
	var have_row = HBoxContainer.new()
	have_row.alignment = BoxContainer.ALIGNMENT_CENTER
	have_row.add_theme_constant_override("separation", 26)
	add_child(have_row)
	var have_l = Label.new()
	have_l.text = "Banked from your runs:"
	have_l.add_theme_font_size_override("font_size", 24)
	have_l.add_theme_color_override("font_color", UI.CREAM)
	have_row.add_child(have_l)
	for el in B.ORDER:
		var chip = Label.new()
		chip.add_theme_font_size_override("font_size", 26)
		chip.add_theme_color_override("font_color", B.ELEMENTS[el].color)
		chip.tooltip_text = B.ELEMENTS[el].name
		have_row.add_child(chip)
		chips[el] = chip
	total_label = Label.new()
	total_label.add_theme_font_size_override("font_size", 20)
	total_label.add_theme_color_override("font_color", UI.MUTED)
	have_row.add_child(total_label)

	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(grid)
	for r in B.lineage_recipes():
		_make_tile(grid, r)

	var info = PanelContainer.new()
	info.add_theme_stylebox_override("panel", UI.panel(UI.MEMBRANE, 20, 0.9, 14.0))
	info.custom_minimum_size = Vector2(0, 220)
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(info)
	var irow = HBoxContainer.new()
	irow.add_theme_constant_override("separation", 20)
	info.add_child(irow)
	var pcol = VBoxContainer.new()
	pcol.add_theme_constant_override("separation", 0)
	irow.add_child(pcol)
	portrait = Control.new()
	portrait.custom_minimum_size = Vector2(260, 200)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pcol.add_child(portrait)
	var vp = SubViewport.new()
	vp.size = Vector2i(380, 300)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var holder = Fit.new()
	holder.position = Vector2(190, 150)
	holder.rotation = -PI / 2
	holder.scale = Vector2.ONE * 2.0
	vp.add_child(holder)
	body_art = preload("res://PlayerBody.gd").new()
	holder.body = body_art
	body_art.preview = true
	body_art.preview_live = true
	body_art.move = 0.35
	holder.add_child(body_art)
	body_art.set_form(START_FORM)
	var tr = TextureRect.new()
	tr.texture = vp.get_texture()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.material = UI.sepia_material()
	portrait.add_child(tr)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", UI.MUTED)
	pcol.add_child(caption)

	var itext = VBoxContainer.new()
	itext.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	itext.add_theme_constant_override("separation", 4)
	irow.add_child(itext)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UI.SUN)
	itext.add_child(title)
	change = RichTextLabel.new()
	change.bbcode_enabled = true
	change.fit_content = true
	change.scroll_active = false
	change.mouse_filter = Control.MOUSE_FILTER_IGNORE
	change.add_theme_font_size_override("normal_font_size", 21)
	change.add_theme_font_size_override("bold_font_size", 21)
	itext.add_child(change)
	body = Label.new()
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", UI.CREAM)
	itext.add_child(body)
	go = Button.new()
	go.text = "GROW IT"
	go.custom_minimum_size = Vector2(240, 70)
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.add_theme_font_size_override("font_size", 24)
	for state in ["normal", "hover", "pressed", "disabled"]:
		go.add_theme_stylebox_override(state, UI.button_box(state, UI.LEAF))
	go.pressed.connect(_on_grow)
	irow.add_child(go)

func _make_tile(grid: GridContainer, r: Dictionary):
	var tile = Button.new()
	tile.custom_minimum_size = Vector2(330, 112)
	tile.pressed.connect(_on_tile.bind(r.id))
	tile.focus_entered.connect(func():
		if PadInput.using_pad and selected != r.id:
			selected = r.id
			just_grown = ""
			_fill()
	)
	var row = HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	row.offset_bottom = -14
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	tile.add_child(row)
	var ic = TextureRect.new()
	var icon_path = "res://assets/ui/icons/adapt_%s.png" % r.get("icon", "")
	if ResourceLoader.exists(icon_path):
		ic.texture = load(icon_path)
	ic.custom_minimum_size = Vector2(56, 56)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.material = UI.sepia_material()
	row.add_child(ic)
	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	var top = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var t = Label.new()
	t.text = r.name
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.add_theme_font_size_override("font_size", 17)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(t)
	var pips = Pips.new()
	pips.most = B.max_rank(r)
	pips.custom_minimum_size = Vector2(18 * pips.most + 4, 18)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pips)
	var cost = RichTextLabel.new()
	cost.bbcode_enabled = true
	cost.fit_content = true
	cost.scroll_active = false
	cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.add_theme_font_size_override("normal_font_size", 16)
	v.add_child(cost)
	var e = Label.new()
	e.text = _effect(r)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	e.add_theme_font_size_override("font_size", 14)
	e.add_theme_color_override("font_color", UI.LEAF)
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(e)
	var meter = Meter.new()
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meter.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	meter.offset_left = 20
	meter.offset_right = -20
	meter.offset_top = -12
	meter.offset_bottom = -7
	tile.add_child(meter)
	grid.add_child(tile)
	tiles[r.id] = {"tile": tile, "name": t, "cost": cost, "icon": ic, "meter": meter, "pips": pips}
	if r.id == B.lineage_recipes()[0].id:
		tile.set_meta("pad_default", true)

# Effects as they read for a whole lineage ("healed now" means nothing here)
func _effect(r: Dictionary) -> String:
	return String(r.effect).replace(", healed now", "")

func _on_tile(id: String):
	if selected == id and B.can_grow_lineage(B.get_recipe(id), bank, ranks):
		_on_grow()
		return
	selected = id
	just_grown = ""
	SoundManager.play_sfx("dna_pickup", 1.2, -6.0)
	_fill()

func _cost_bbcode(cost: Dictionary) -> String:
	var parts: Array = []
	for el in B.ORDER:
		if cost.has(el):
			var short = int(bank.get(el, 0.0)) < cost[el]
			parts.append("[color=#%s]%d %s[/color]" % [("ff7766" if short else B.ELEMENTS[el].color.to_html(false)), cost[el], el])
	return "Needs " + "  ".join(parts)

func _fill():
	var total := 0
	for el in B.ORDER:
		chips[el].text = "%s %d" % [el, int(bank.get(el, 0.0))]
	var grown := 0
	var most := 0
	for r in B.lineage_recipes():
		var w: Dictionary = tiles[r.id]
		var tile: Button = w.tile
		var n = int(ranks.get(r.id, 0))
		var top = B.max_rank(r)
		grown += n
		most += top
		var maxed = n >= top
		var ok = B.can_grow_lineage(r, bank, ranks)
		var sel = r.id == selected
		var tint = UI.LEAF if ok else (UI.SUN if sel else UI.MEMBRANE)
		for state in ["normal", "hover", "pressed", "disabled"]:
			tile.add_theme_stylebox_override(state, UI.button_box(state, tint))
		if sel:
			tile.add_theme_stylebox_override("normal", UI.button_box("pressed", tint))
			tile.add_theme_stylebox_override("hover", UI.button_box("pressed", tint))
		tile.modulate = Color(1, 1, 1, 1.0 if (ok or sel or n > 0) else 0.62)
		w.icon.modulate = Color(1, 1, 1, 1.0 if (ok or n > 0) else 0.55)
		w.name.add_theme_color_override("font_color", UI.SUN if ok else UI.CREAM)
		w.pips.have = n
		w.pips.col = UI.LEAF if n > 0 else UI.MUTED
		w.pips.queue_redraw()
		if maxed:
			w.cost.text = "[color=#%s]FULLY GROWN[/color]" % UI.LEAF.to_html(false)
		else:
			w.cost.text = _cost_bbcode(B.lineage_cost(r, n))
		w.meter.frac = B.lineage_progress(r, bank, ranks)
		w.meter.col = UI.LEAF if (ok or maxed) else Color(UI.SUN, 0.85)
		w.meter.queue_redraw()
	total_label.text = "  ·  %d / %d grown" % [grown, most]
	# The creature every run starts as, with the lineage's parts on it
	var parts := {}
	for id in ranks:
		parts[id] = int(ranks[id])
	var showing = selected in VISIBLE and just_grown != selected and int(ranks.get(selected, 0)) < B.max_rank(B.get_recipe(selected))
	if showing:
		parts[selected] = int(parts.get(selected, 0)) + 1
	body_art.preview_parts = parts
	caption.text = ("With " + B.get_recipe(selected).name.to_lower()) if showing else "Every run starts like this"

	var r = B.get_recipe(selected)
	if r.is_empty():
		title.text = PadInput.prompt("Move to a part to see what it is made of", "Tap a part to see what it is made of", "Click a part to see what it is made of")
		change.text = ""
		body.text = "What you eat in a run is banked here when the run ends. Parts grown here are part of your lineage for good: every run starts with them. Each part grows up to three times."
		go.disabled = true
		return
	var n = int(ranks.get(r.id, 0))
	var top = B.max_rank(r)
	title.text = r.name + ("  ·  GROWN!" if just_grown == r.id else "")
	var ok = B.can_grow_lineage(r, bank, ranks)
	var line = "Every run: %s" % _effect(r)
	if top > 1:
		line += "   (×%d → ×%d)" % [n, min(top, n + 1)] if n < top else "   (×%d, fully grown)" % n
	elif n > 0:
		line += "   (grown)"
	var how = ""
	if ok:
		how = "   [color=#%s]%s[/color]" % [UI.MUTED.to_html(false), PadInput.prompt("Press A to grow it", "Tap again to grow it", "Click again to grow it")]
	elif n < top:
		how = "   " + _cost_bbcode(B.lineage_cost(r, n))
	change.text = "[color=#%s][b]%s[/b][/color]%s" % [UI.LEAF.to_html(false), line, how]
	var el_facts: Array = []
	for el in r.cost:
		el_facts.append(B.ELEMENTS[el].name + ": " + B.ELEMENTS[el].fact)
	body.text = r.fact + "\n" + "\n".join(el_facts)
	go.disabled = not ok
	go.text = "GROW IT" if n < top else "FULLY GROWN"

func _on_grow():
	var r = B.get_recipe(selected)
	if r.is_empty():
		return
	var cost = B.lineage_cost(r, int(ranks.get(r.id, 0)))
	if not PROGRESS.grow_lineage(r.id):
		return
	bank = PROGRESS.bank()
	ranks = PROGRESS.lineage_ranks()
	just_grown = r.id
	SoundManager.play_sfx("evolve", 1.2)
	_fill()
	_feedback(r, cost)

# Elements fly from the bank into the creature, which swells as the part
# grows in
func _feedback(r: Dictionary, cost: Dictionary):
	PadInput.rumble(0.6, 0.25)
	var target = portrait.get_global_rect().get_center()
	var delay := 0.0
	for el in cost:
		var chip: Label = chips[el]
		var from = chip.get_global_rect().get_center()
		chip.pivot_offset = chip.size / 2.0
		var ctw = chip.create_tween()
		ctw.tween_property(chip, "scale", Vector2.ONE * 1.35, 0.08)
		ctw.tween_property(chip, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		for i in min(int(cost[el]), 10):
			var mote = Mote.new()
			mote.col = B.ELEMENTS[el].color
			mote.size = Vector2(16, 16)
			mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mote.top_level = true
			add_child(mote)
			var start = from - mote.size / 2.0 + Vector2(randf_range(-14, 14), randf_range(-6, 6))
			mote.global_position = start
			var mid = from.lerp(target, 0.5) + Vector2(randf_range(-200, 200), randf_range(-60, 60))
			var end = target - mote.size / 2.0 + Vector2(randf_range(-20, 20), randf_range(-20, 20))
			var mtw = mote.create_tween()
			mtw.tween_interval(delay)
			mtw.tween_method(func(u: float):
				if is_instance_valid(mote):
					mote.global_position = start.lerp(mid, u).lerp(mid.lerp(end, u), u)
					mote.rotation = u * 6.0
			, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			mtw.tween_callback(mote.queue_free)
			delay += 0.035
	var arrive = delay + 0.5
	portrait.pivot_offset = portrait.size / 2.0
	var ptw = portrait.create_tween()
	ptw.tween_interval(arrive)
	ptw.tween_property(portrait, "scale", Vector2.ONE * 1.18, 0.1).set_trans(Tween.TRANS_SINE)
	ptw.parallel().tween_property(portrait, "modulate", Color(1.6, 1.5, 1.2), 0.1)
	ptw.tween_property(portrait, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	ptw.parallel().tween_property(portrait, "modulate", Color.WHITE, 0.4)
	if r.id in VISIBLE:
		var now: Dictionary = body_art.preview_parts.duplicate()
		var before = now.duplicate()
		before[r.id] = max(0, int(before.get(r.id, 0)) - 1)
		body_art.preview_parts = before
		var btw = body_art.create_tween()
		btw.tween_interval(arrive)
		btw.tween_callback(func(): body_art.preview_parts = now)
	var w = tiles[r.id]
	var tile: Button = w.tile
	tile.pivot_offset = tile.size / 2.0
	var ttw = tile.create_tween()
	ttw.tween_property(tile, "scale", Vector2.ONE * 1.08, 0.1)
	ttw.tween_property(tile, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	var pop = Label.new()
	pop.text = _effect(r)
	pop.top_level = true
	pop.add_theme_font_size_override("font_size", 40)
	pop.add_theme_color_override("font_color", UI.LEAF)
	pop.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	pop.add_theme_constant_override("outline_size", 8)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop.modulate.a = 0.0
	add_child(pop)
	pop.reset_size()
	var top = portrait.get_global_rect().position.y
	pop.global_position = Vector2(get_viewport_rect().size.x / 2.0 - pop.size.x / 2.0, top - 30)
	var ltw = pop.create_tween()
	ltw.tween_interval(arrive)
	ltw.tween_property(pop, "modulate:a", 1.0, 0.12)
	ltw.parallel().tween_property(pop, "global_position:y", top - 170, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ltw.tween_property(pop, "modulate:a", 0.0, 0.35)
	ltw.tween_callback(pop.queue_free)
