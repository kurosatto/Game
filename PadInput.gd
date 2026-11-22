# PadInput.gd
# Xbox-style gamepad support (also the Legion Go's built-in pad).
#   Left stick / d-pad: move        Right stick: aim and shoot
#   RT, RB or A: dash                LT, LB or X: ZAP
#   Y: grow                          Start / View: pause
# In menus the d-pad or left stick moves a highlight between buttons, A presses
# and B goes back. Autoloaded, so every scene gets it without its own code.
# `using_pad` flips on when the pad is touched and off again on touch, mouse
# or keyboard, so the touch sticks and mouse cursor hide only while it's used.
extends Node

signal mode_changed(pad: bool)

var using_pad: bool = false

const STICK_DEADZONE := 0.22
const TRIGGER_DEADZONE := 0.35
# Holding a direction in a menu repeats it after a moment
const REPEAT_DELAY := 0.38
const REPEAT_RATE := 0.11

var _held_dir := Vector2.ZERO
var _held_time := 0.0
var _repeat_time := 0.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_bindings()

# The gameplay actions (Main.setup_inputs adds the keyboard keys to the same
# actions, so Player.gd reads one set of actions for every device)
func add_bindings():
	var axes = {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
		"shoot_left": [JOY_AXIS_RIGHT_X, -1.0], "shoot_right": [JOY_AXIS_RIGHT_X, 1.0],
		"shoot_up": [JOY_AXIS_RIGHT_Y, -1.0], "shoot_down": [JOY_AXIS_RIGHT_Y, 1.0],
	}
	for action in axes:
		_ensure(action, STICK_DEADZONE)
		var m = InputEventJoypadMotion.new()
		m.device = -1
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)
	var dpad = {
		"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
		"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	}
	for action in dpad:
		_add_button(action, dpad[action])
	# Godot's menus take A to press (ui_accept has no pad button by default)
	# and B to close a drop-down list
	_add_button("ui_accept", JOY_BUTTON_A)
	_add_button("ui_cancel", JOY_BUTTON_B)
	_ensure("dash", TRIGGER_DEADZONE)
	_add_button("dash", JOY_BUTTON_A)
	_add_button("dash", JOY_BUTTON_RIGHT_SHOULDER)
	_add_trigger("dash", JOY_AXIS_TRIGGER_RIGHT)
	_ensure("discharge", TRIGGER_DEADZONE)
	_add_button("discharge", JOY_BUTTON_X)
	_add_button("discharge", JOY_BUTTON_LEFT_SHOULDER)
	_add_trigger("discharge", JOY_AXIS_TRIGGER_LEFT)

func _ensure(action: String, deadzone: float):
	if not InputMap.has_action(action):
		InputMap.add_action(action, deadzone)
	else:
		InputMap.action_set_deadzone(action, deadzone)

func _add_button(action: String, button: JoyButton):
	_ensure(action, InputMap.action_get_deadzone(action) if InputMap.has_action(action) else 0.5)
	var b = InputEventJoypadButton.new()
	b.device = -1
	b.button_index = button
	InputMap.action_add_event(action, b)

func _add_trigger(action: String, axis: JoyAxis):
	var m = InputEventJoypadMotion.new()
	m.device = -1
	m.axis = axis
	m.axis_value = 1.0
	InputMap.action_add_event(action, m)

func set_using_pad(on: bool):
	if on == using_pad:
		return
	using_pad = on
	# The mouse pointer would sit in the middle of the room; hide it while
	# playing on the pad, and bring it back as soon as the mouse moves
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if on else Input.MOUSE_MODE_VISIBLE
	if not on:
		var f = get_viewport().gui_get_focus_owner()
		if f and in_play():
			f.release_focus()
	mode_changed.emit(on)

# A short buzz on the pad (on hits, like the phone's vibration)
func rumble(strength: float = 0.5, seconds: float = 0.15):
	if not using_pad:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, strength * 0.6, strength, seconds)

# What the prompts say: "A", "Tap" or a key, depending on the last device used
func prompt(pad: String, touch: String, keys: String) -> String:
	if using_pad:
		return pad
	return touch if TouchControls.should_show() else keys

func _pad_active() -> bool:
	for d in Input.get_connected_joypads():
		for b in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_BACK,
				JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
				JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			if Input.is_joy_button_pressed(d, b):
				return true
		for a in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			if absf(Input.get_joy_axis(d, a)) > 0.5:
				return true
	return false

# ---- Which device is in use ----
func _input(event: InputEvent):
	if event is InputEventJoypadButton:
		if event.pressed:
			set_using_pad(true)
			_pad_button(event)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.5:
			set_using_pad(true)
	elif event is InputEventScreenTouch or event is InputEventKey:
		if event.pressed:
			set_using_pad(false)
	elif event is InputEventMouseButton:
		if event.pressed:
			set_using_pad(false)
	elif event is InputEventMouseMotion:
		if event.relative.length() > 6.0:
			set_using_pad(false)

	# Menu moves happen in _process from the d-pad and stick state; stop
	# Godot's own focus moves, which would also reach buttons hidden under an
	# open page or card
	if using_pad and not in_play() and _is_nav_event(event):
		var f = get_viewport().gui_get_focus_owner()
		var horizontal = event.is_action("ui_left") or event.is_action("ui_right")
		if f is Range and horizontal:
			return # sliders take left and right themselves
		get_viewport().set_input_as_handled()

func _is_nav_event(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	for a in ["ui_up", "ui_down", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
		if event.is_action(a):
			return true
	return false

# Buttons that do something outside a focused menu button
func _pad_button(event: InputEventJoypadButton):
	var hud = _hud()
	match event.button_index:
		JOY_BUTTON_START, JOY_BUTTON_BACK:
			if hud and hud.has_method("pad_pause"):
				hud.pad_pause()
				get_viewport().set_input_as_handled()
		JOY_BUTTON_Y:
			if hud and hud.has_method("pad_grow"):
				hud.pad_grow()
				get_viewport().set_input_as_handled()
		JOY_BUTTON_B:
			if in_play():
				return
			var scene = get_tree().current_scene
			if hud and hud.has_method("back_pressed"):
				if hud.game_over_screen.visible or hud.victory_screen.visible or get_tree().paused:
					hud.back_pressed()
					get_viewport().set_input_as_handled()
			elif scene and scene.has_method("pad_back"):
				scene.pad_back()
				get_viewport().set_input_as_handled()

func _main() -> Node:
	return get_tree().get_first_node_in_group("main")

func _hud() -> Node:
	var main = _main()
	return main.hud if main and "hud" in main else null

# Running about in a room: the pad plays, no menu button is highlighted
func in_play() -> bool:
	var main = _main()
	if main == null:
		return false
	return not get_tree().paused

# ---- Menu highlight ----
var _check_timer := 0.0

func _process(delta: float):
	# A scene can swallow a press in its own _input (the era card does), so
	# also notice the pad from its state
	if not using_pad and _pad_active():
		set_using_pad(true)
	if not using_pad:
		return
	var vp = get_viewport()
	var focus = vp.gui_get_focus_owner()
	if in_play():
		if focus:
			focus.release_focus()
		return
	if focus is OptionButton and focus.get_popup().visible:
		return # its list takes the d-pad itself
	_check_timer -= delta
	var recheck = _check_timer <= 0.0
	if recheck:
		_check_timer = 0.15
	if focus == null or not focus.is_visible_in_tree() or (recheck and _blocked(focus, _all_controls())):
		focus = _pick_default()
		if focus:
			_focus(focus)
		# The press that woke the pad only shows the highlight
		_held_dir = _nav_dir()
		return

	var dir = _nav_dir()
	if dir == Vector2.ZERO:
		_held_dir = Vector2.ZERO
		return
	if dir != _held_dir:
		_held_dir = dir
		_held_time = 0.0
		_repeat_time = 0.0
		_step(focus, dir)
		return
	_held_time += delta
	if _held_time >= REPEAT_DELAY:
		_repeat_time -= delta
		if _repeat_time <= 0.0:
			_repeat_time = REPEAT_RATE
			_step(focus, dir)

func _nav_dir() -> Vector2:
	var dir = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if dir.x != 0 and dir.y != 0:
		dir.x = 0 # one step at a time, up/down wins
	return dir

func _step(from: Control, dir: Vector2):
	if from is Range and dir.x != 0:
		return
	# Controls with their own pad moves (the codex tree) get first go
	if from.has_method("pad_navigate") and from.pad_navigate(dir):
		return
	var next = _neighbour(from, dir)
	if next:
		_focus(next)
		SoundManager.play_sfx("dna_pickup", 1.6, -14.0)

func _focus(c: Control):
	c.grab_focus()
	# Scroll lists so the highlighted row is on screen
	var p = c.get_parent()
	while p:
		if p is ScrollContainer:
			p.ensure_control_visible(c)
			break
		p = p.get_parent()

# Every visible control, in the order they are drawn (canvas layer, then tree)
func _all_controls() -> Array:
	var out: Array = []
	_collect(get_tree().root, 0, out)
	out.sort_custom(func(a, b): return a[1] < b[1] if a[1] != b[1] else a[2] < b[2])
	return out

var _order := 0

func _collect(n: Node, layer: int, out: Array):
	if n is CanvasLayer:
		if not n.visible:
			return
		layer = n.layer
	elif n is CanvasItem and not n.visible:
		return
	elif n is Window and n != get_tree().root:
		return
	if n is Control:
		_order += 1
		out.append([n, layer, _order])
	for c in n.get_children():
		_collect(c, layer, out)

func _is_candidate(c: Control) -> bool:
	if c.focus_mode == Control.FOCUS_NONE or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	if c.has_meta("pad_skip"):
		return false
	if c is BaseButton:
		return not c.disabled
	if c.has_signal("picked"): # PauseTile pictures that show info when picked
		return not c.get_signal_connection_list("picked").is_empty()
	return c is Range or c.has_method("pad_navigate")

# Hidden under a full-page card or overlay drawn after it (anything that
# would also stop a mouse click reaching it)
func _blocked(c: Control, all: Array) -> bool:
	var view = get_viewport().get_visible_rect()
	var centre = c.get_global_rect().get_center()
	var mine = -1
	for i in all.size():
		if all[i][0] == c:
			mine = i
			break
	if mine == -1:
		return true
	for i in range(mine + 1, all.size()):
		var o: Control = all[i][0]
		if o.mouse_filter != Control.MOUSE_FILTER_STOP or c.is_ancestor_of(o) or o.is_ancestor_of(c):
			continue
		var r = o.get_global_rect()
		if r.get_area() >= view.get_area() * 0.4 and r.has_point(centre):
			return true
	return false

func _candidates() -> Array:
	var all = _all_controls()
	var out: Array = []
	for e in all:
		var c: Control = e[0]
		if _is_candidate(c) and not _blocked(c, all):
			out.append(c)
	return out

# The button to start on when a screen opens: one marked pad_default, else
# the first one on the top-most page
func _pick_default() -> Control:
	var cands = _candidates()
	if cands.is_empty():
		return null
	for c in cands:
		if c.has_meta("pad_default"):
			return c
	return cands[0]

func _neighbour(from: Control, dir: Vector2) -> Control:
	var a = from.get_global_rect()
	var best: Control = null
	var best_score = INF
	for c in _candidates():
		if c == from:
			continue
		var b = c.get_global_rect()
		var v = b.get_center() - a.get_center()
		# Must lie past the current control's edge in that direction
		var gap: float
		if dir.x > 0:
			gap = b.position.x - a.end.x
		elif dir.x < 0:
			gap = a.position.x - b.end.x
		elif dir.y > 0:
			gap = b.position.y - a.end.y
		else:
			gap = a.position.y - b.end.y
		var along = v.dot(dir)
		if along <= 4.0 or gap < -minf(a.size.dot(dir.abs()), b.size.dot(dir.abs())) * 0.5:
			continue
		var side = absf(v.cross(dir))
		# Overlapping sideways (same row/column) is much preferred
		var overlap = false
		if dir.x != 0:
			overlap = b.position.y < a.end.y and b.end.y > a.position.y
		else:
			overlap = b.position.x < a.end.x and b.end.x > a.position.x
		var score = maxf(gap, 0.0) + along * 0.3 + side * (0.5 if overlap else 2.5)
		if score < best_score:
			best_score = score
			best = c
	return best
