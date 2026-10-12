# EvolutionScreen.gd
# Shown between eras: pick which real descendant group to evolve into.
# Built in code so it does not touch the HUD scene.
extends CanvasLayer

signal lineage_chosen(id: String)

var lineages = preload("res://data/Lineages.gd")
var root: Control = null

func _ready():
    layer = 110 # above the fade-to-black TransitionLayer (100)
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false

func show_choices(current_id: String, next_era: Dictionary):
    if root:
        root.queue_free()

    var choices: Array = lineages.get_choices(current_id)
    var is_upgrade = choices.size() == 1 and choices[0] == current_id

    root = Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    add_child(root)

    var backdrop = ColorRect.new()
    backdrop.color = Color(0.02, 0.05, 0.09, 0.94)
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.add_child(backdrop)

    var margin = MarginContainer.new()
    margin.set_anchors_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "right", "top", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 48)
    root.add_child(margin)

    var column = VBoxContainer.new()
    column.alignment = BoxContainer.ALIGNMENT_CENTER
    column.add_theme_constant_override("separation", 20)
    margin.add_child(column)

    column.add_child(make_label("EVOLVE", 56, Color(0.4, 1.0, 0.9)))
    var heading = "Entering the %s, %s" % [next_era.name, next_era.dates]
    column.add_child(make_label(heading, 26, Color(0.8, 0.9, 1.0)))
    if is_upgrade:
        column.add_child(make_label("No real split is known for your group here, so it adapts instead.", 22, Color(0.7, 0.75, 0.8)))

    var row = HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 24)
    column.add_child(row)

    var first_button: Button = null
    for i in range(choices.size()):
        var button = add_card(row, choices[i], i + 1, is_upgrade, choices.size())
        if button and not first_button:
            first_button = button

    visible = true
    get_tree().paused = true
    if first_button:
        first_button.grab_focus()

func add_card(row: HBoxContainer, id: String, number: int, is_upgrade: bool, total: int) -> Button:
    var data = lineages.get_lineage(id)
    var locked = lineages.is_locked(id)

    var card = PanelContainer.new()
    card.custom_minimum_size = Vector2(min(420.0, 1700.0 / total), 0)
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.12, 0.18, 1.0) if not locked else Color(0.08, 0.08, 0.1, 1.0)
    style.border_color = Color(0.0, 0.7, 0.9, 0.8) if not locked else Color(0.3, 0.3, 0.35, 0.8)
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(18)
    card.add_theme_stylebox_override("panel", style)
    row.add_child(card)

    var box = VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    card.add_child(box)

    var title = data.name if not is_upgrade else "Refine: " + data.name
    box.add_child(make_label(title, 30, Color.WHITE if not locked else Color(0.6, 0.6, 0.65)))
    box.add_child(make_label(data.clade, 20, Color(0.4, 1.0, 0.9) if not locked else Color(0.5, 0.5, 0.55)))
    box.add_child(make_label(data.clade_path, 16, Color(0.6, 0.7, 0.8)))
    box.add_child(make_label("Living today: " + data.living_example, 18, Color(0.85, 0.9, 0.75)))
    box.add_child(make_label(data.fact, 18, Color(0.85, 0.85, 0.9)))
    var summary = describe_stats(data)
    if summary != "":
        box.add_child(make_label(summary, 18, Color(1.0, 0.85, 0.4)))

    var button = Button.new()
    button.custom_minimum_size = Vector2(0, 56)
    button.add_theme_font_size_override("font_size", 24)
    if locked:
        button.text = "Not playable yet"
        button.disabled = true
    else:
        button.text = "[%d] Evolve" % number
        button.pressed.connect(_on_choice.bind(id))
    box.add_child(button)
    return button if not locked else null

func describe_stats(data: Dictionary) -> String:
    var parts: Array = []
    var stats: Dictionary = data.stats
    var names = {"max_health": "health", "speed": "speed", "damage": "damage", "fire_delay": "fire delay", "shot_speed": "shot speed", "range": "range"}
    for key in names:
        if stats.has(key):
            var value = stats[key]
            parts.append("%s%s %s" % ["+" if value > 0 else "", str(value), names[key]])
    for ability in data.abilities:
        parts.append(ability.replace("_", " "))
    return ", ".join(parts)

func make_label(text: String, size: int, color: Color) -> Label:
    var label = Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    return label

func _unhandled_input(event: InputEvent):
    if not visible or not root:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var index = event.keycode - KEY_1
        var buttons: Array = []
        for b in root.find_children("*", "Button", true, false):
            buttons.append(b)
        if index >= 0 and index < buttons.size() and not buttons[index].disabled:
            buttons[index].pressed.emit()
            get_viewport().set_input_as_handled()

func _on_choice(id: String):
    visible = false
    get_tree().paused = false
    if root:
        root.queue_free()
        root = null
    lineage_chosen.emit(id)
