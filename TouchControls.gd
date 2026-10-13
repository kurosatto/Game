# TouchControls.gd
# On-screen twin-stick controls for phones and tablets.
# Left half of the screen is a floating movement stick, right half is a floating
# shoot stick, plus dash and discharge buttons. Each control presses the same
# InputMap actions the keyboard uses, so Player.gd needs no touch-specific code.
class_name TouchControls
extends CanvasLayer

const STICK_RADIUS := 130.0
const KNOB_RADIUS := 55.0
const DEADZONE := 0.25
const BUTTON_RADIUS := 80.0
const TOP_BAR_HEIGHT := 90.0 # Leave the HUD bar (settings button) to normal taps

var move_stick := {
    "touch": -1, "origin": Vector2.ZERO, "vec": Vector2.ZERO,
    "actions": ["move_left", "move_right", "move_up", "move_down"],
}
var shoot_stick := {
    "touch": -1, "origin": Vector2.ZERO, "vec": Vector2.ZERO,
    "actions": ["shoot_left", "shoot_right", "shoot_up", "shoot_down"],
}
# Action buttons above the shoot stick: action name -> on-screen label
var buttons := [
    {"action": "dash", "label": "DASH", "touch": -1, "color": Color(0.45, 0.9, 0.85)},
    {"action": "discharge", "label": "ZAP", "touch": -1, "color": Color(1.0, 0.8, 0.4)},
]

var canvas: Control

func _ready():
    layer = 50
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = should_show()

    canvas = Control.new()
    canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
    canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.draw.connect(_on_canvas_draw)
    canvas.resized.connect(canvas.queue_redraw)
    add_child(canvas)

    if visible:
        _connect_player_haptics.call_deferred()

static func should_show() -> bool:
    return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()

func screen_size() -> Vector2:
    return canvas.size if canvas else get_viewport().get_visible_rect().size

func button_center(i: int) -> Vector2:
    var s = screen_size()
    return Vector2(s.x - 140.0 - i * 190.0, s.y - 460.0)

func any_button_held() -> bool:
    for b in buttons:
        if b.touch != -1:
            return true
    return false

func rest_origin(stick: Dictionary) -> Vector2:
    var s = screen_size()
    if is_same(stick, move_stick):
        return Vector2(220.0, s.y - 220.0)
    return Vector2(s.x - 220.0, s.y - 220.0)

func _process(_delta: float):
    # Menus, the evolution cards and end screens: get the sticks out of the way
    if canvas:
        canvas.visible = not get_tree().paused and not _end_screen_up()

func _end_screen_up() -> bool:
    var main = get_tree().get_first_node_in_group("main")
    if main == null or not "hud" in main or main.hud == null:
        return false
    return main.hud.game_over_screen.visible or main.hud.victory_screen.visible

# A short buzz whenever the player loses health
var last_health: int = -1

func _connect_player_haptics():
    var player = get_tree().get_first_node_in_group("player")
    if player and player.has_signal("health_changed"):
        last_health = player.health
        player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(health, _max_health):
    if last_health >= 0 and health < last_health:
        Input.vibrate_handheld(40)
    last_health = health

func _input(event: InputEvent):
    if not visible:
        return
    if get_tree().paused:
        if move_stick.touch != -1 or shoot_stick.touch != -1 or any_button_held():
            release_all()
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            _on_touch_down(event.index, event.position)
        else:
            _on_touch_up(event.index)
    elif event is InputEventScreenDrag:
        for stick in [move_stick, shoot_stick]:
            if stick.touch == event.index:
                _update_stick(stick, event.position)

func _on_touch_down(index: int, pos: Vector2):
    if pos.y < TOP_BAR_HEIGHT:
        return

    for i in buttons.size():
        var b = buttons[i]
        if pos.distance_to(button_center(i)) <= BUTTON_RADIUS and b.touch == -1:
            b.touch = index
            Input.action_press(b.action)
            canvas.queue_redraw()
            return

    var stick = move_stick if pos.x < screen_size().x * 0.5 else shoot_stick
    if stick.touch != -1:
        return
    stick.touch = index
    stick.origin = pos
    _update_stick(stick, pos)

func _on_touch_up(index: int):
    for b in buttons:
        if b.touch == index:
            b.touch = -1
            Input.action_release(b.action)
            canvas.queue_redraw()
            return

    for stick in [move_stick, shoot_stick]:
        if stick.touch == index:
            stick.touch = -1
            stick.vec = Vector2.ZERO
            _apply_stick(stick)
            canvas.queue_redraw()

func _update_stick(stick: Dictionary, pos: Vector2):
    var offset: Vector2 = (pos - stick.origin).limit_length(STICK_RADIUS)
    stick.vec = offset / STICK_RADIUS
    _apply_stick(stick)
    canvas.queue_redraw()

func _apply_stick(stick: Dictionary):
    var v: Vector2 = stick.vec
    if v.length() < DEADZONE:
        v = Vector2.ZERO
    var acts: Array = stick.actions
    _set_action(acts[0], max(0.0, -v.x))
    _set_action(acts[1], max(0.0, v.x))
    _set_action(acts[2], max(0.0, -v.y))
    _set_action(acts[3], max(0.0, v.y))

func _set_action(action: String, strength: float):
    if strength > 0.0:
        Input.action_press(action, strength)
    else:
        Input.action_release(action)

func release_all():
    for stick in [move_stick, shoot_stick]:
        stick.touch = -1
        stick.vec = Vector2.ZERO
        _apply_stick(stick)
    for b in buttons:
        if b.touch != -1:
            b.touch = -1
            Input.action_release(b.action)
    canvas.queue_redraw()

func _notification(what: int):
    # Don't leave actions stuck down if the app is backgrounded mid-touch
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
        release_all()

func _on_canvas_draw():
    _draw_stick(move_stick, Color(0.62, 0.93, 0.5))
    _draw_stick(shoot_stick, Color(1.0, 0.47, 0.4))

    var font = canvas.get_theme_default_font() # the rounded UI font
    var fs = 26
    for i in buttons.size():
        var b = buttons[i]
        var bc = button_center(i)
        var col: Color = b.color
        var alpha = 0.55 if b.touch != -1 else 0.25
        canvas.draw_circle(bc, BUTTON_RADIUS, Color(col.r, col.g, col.b, alpha))
        canvas.draw_arc(bc, BUTTON_RADIUS, 0.0, TAU, 48, Color(col.r, col.g, col.b, 0.8), 3.0)
        var label: String = b.label
        if b.action == "dash":
            var player = get_tree().get_first_node_in_group("player")
            if player and player.has_method("dash_label"):
                label = player.dash_label()
        var tw = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
        canvas.draw_string(font, bc + Vector2(-tw / 2.0, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.98, 0.94, 0.84, 0.95))

func _draw_stick(stick: Dictionary, col: Color):
    var active = stick.touch != -1
    var origin: Vector2 = stick.origin if active else rest_origin(stick)
    var base_alpha = 0.3 if active else 0.15
    canvas.draw_circle(origin, STICK_RADIUS, Color(col.r, col.g, col.b, base_alpha))
    canvas.draw_arc(origin, STICK_RADIUS, 0.0, TAU, 64, Color(col.r, col.g, col.b, 0.7), 3.0)
    var knob: Vector2 = origin + stick.vec * STICK_RADIUS
    canvas.draw_circle(knob, KNOB_RADIUS, Color(col.r, col.g, col.b, 0.6 if active else 0.35))
