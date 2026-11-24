# BossPortrait.gd
# A boss drawn live in a menu tile (main menu ENDGAME page): the boss's own
# code draws and animates it, held still, with no fight. Locked bosses show
# as a dark ink silhouette.
extends Control

var script_path: String = ""
var locked: bool = false
var zoom: float = 0.5
var boss: Node2D = null

func setup(path: String, is_locked: bool, size_px: Vector2 = Vector2(320, 210)) -> Control:
	script_path = path
	locked = is_locked
	custom_minimum_size = size_px
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self

func _ready():
	if not ResourceLoader.exists(script_path):
		return
	boss = load(script_path).new()
	boss.setup()
	if boss.light:
		boss.light.enabled = false
	for c in boss.get_children():
		if c is CollisionShape2D:
			c.disabled = true
	boss.scale = Vector2(zoom, zoom)
	boss.modulate = Color(0.12, 0.08, 0.05, 0.85) if locked else Color.WHITE
	add_child(boss)
	boss.set_physics_process(false)
	boss.facing = Vector2(1, 0.12).normalized()
	boss.remove_from_group("enemies")
	resized.connect(_center)
	_center()

func _center():
	if boss:
		boss.position = size * 0.5 + Vector2(20, 0)

func _process(delta: float):
	if boss and not locked:
		# A slow idle: the drawing clock runs, nothing moves
		boss.t += delta
		boss.set("walk", 0.25 + 0.25 * sin(boss.t * 0.8))
		boss.set("gait", float(boss.get("gait")) + delta * 1.5 if boss.get("gait") != null else 0.0)
		boss.queue_redraw()
