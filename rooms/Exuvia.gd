# Exuvia.gd
# The old skin an arthropod leaves behind when it molts (Player.molt): a pale,
# hollow copy of the body, split along the back where the animal climbed out.
# Many arthropods eat their old skin to win back the calcium in it, so
# touching it returns some calcium for the GROW screen. Kept in RoomData.
extends Node2D

const PlayerBody = preload("res://PlayerBody.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)
const CALCIUM := 1.0

var form_id: String = ""
var parts: Dictionary = {}
var body_rot: float = 0.0
var body_scale: float = 1.35
var eaten: bool = false
var on_eaten: Callable = Callable()
var player: Node2D = null
var _art: Node2D = null
var _frames: int = 0
var armed: bool = false # only once you have stepped away from it

func _ready():
	z_index = -1
	player = get_tree().get_first_node_in_group("player")
	if eaten:
		visible = false
		set_process(false)
		return
	_art = PlayerBody.new()
	_art.preview = true
	_art.preview_parts = parts.duplicate()
	_art.set_form(form_id)
	_art.rotation = body_rot
	_art.scale = Vector2.ONE * body_scale
	# Pale and see-through: a hollow shell, not an animal
	_art.modulate = Color(1.0, 0.96, 0.86, 0.6)
	add_child(_art)

func _process(_delta: float):
	_frames += 1
	if _frames == 3 and _art:
		_art.set_process(false) # a still shell: draw it once
	queue_redraw()
	if eaten or player == null or not is_instance_valid(player) or player.health <= 0:
		return
	var d = player.global_position.distance_to(global_position)
	if d > 120.0:
		armed = true
	elif armed and d < 70.0:
		eat()

func eat():
	eaten = true
	if "elements" in player:
		player.elements["Ca"] = player.elements.get("Ca", 0.0) + CALCIUM
		player.emit_biomass()
		player.popup_text(global_position + Vector2(0, -40), "+%d Ca" % int(CALCIUM), Color(0.96, 0.93, 0.85))
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play_sfx("atk_bite", 1.2, -6.0)
	HitFX.pop(get_parent(), global_position, Color(0.96, 0.92, 0.8), 20.0, 120.0, 0.3)
	if on_eaten.is_valid():
		on_eaten.call()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func(): visible = false; set_process(false))

func _draw():
	if eaten:
		return
	# The split along the back where the animal pulled itself out
	var along = Vector2.RIGHT.rotated(body_rot)
	var side = along.orthogonal()
	var pts := PackedVector2Array()
	for i in 7:
		var u = -1.0 + i / 3.0
		pts.append(along * u * 18.0 + side * (3.0 if i % 2 == 0 else -3.0))
	draw_polyline(pts, Color(INK, 0.75), 1.6, true)
