# Companion.gd
# The follower from a symbiont room (data/SpecialRooms.gd "symbiont"): an era
# animal that waits in its room until you touch it, then follows you and
# darts at whatever you're fighting, the way egrets follow grazing cattle for
# the insects they flush out. It can't be hurt, and it stays for the rest of
# the era (Main.generate_floor sends it off).
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const INK = Color(0.24, 0.15, 0.08)
const FRIEND = Color(0.3, 0.5, 0.25)

const REACH := 330.0 # how far from you it will go after something
const COOLDOWN := 1.3

var floor_num: int = 2
var on_joined: Callable = Callable()
var joined: bool = false
var puppet: Node2D = null
var player: Node2D = null
var species: String = ""
var time: float = 0.0
var state: String = "follow"
var target: Node2D = null
var strike_time: float = 0.0
var cooldown: float = 0.5
var vel: Vector2 = Vector2.ZERO
var last_room: Node = null

func _ready():
	add_to_group("companions")
	z_index = 1
	player = get_tree().get_first_node_in_group("player")
	var info = SR.SYMBIONTS[clampi(floor_num, 2, 5)]
	species = info.species
	puppet = preload("res://rooms/SpecialRoom.gd").make_puppet(self, floor_num, species, info.type, Vector2.ZERO)

func join():
	joined = true
	if on_joined.is_valid():
		on_joined.call()
	var main = get_tree().get_first_node_in_group("main")
	if main:
		reparent(main)
		last_room = main.get("current_room_node")
	SoundManager.play_sfx("level_up", 1.5, -6.0)
	HitFX.pop(get_parent(), global_position, Color(0.75, 0.9, 0.6), 26.0, 150.0, 0.4)
	player.popup_text(global_position + Vector2(0, -80), species.to_upper() + " JOINS YOU", Color(0.75, 0.95, 0.6))

func _process(delta: float):
	time += delta
	queue_redraw()
	if not player or not is_instance_valid(player):
		return
	if not joined:
		if player.global_position.distance_to(global_position) < 100.0 and player.health > 0:
			join()
		_animate(Vector2(sin(time * 0.8), cos(time * 0.6)) * 10.0, delta)
		return
	var main = get_parent()
	if main.get("is_transitioning"):
		return
	# A new room: it comes through the door with you
	if main.get("current_room_node") != last_room:
		last_room = main.get("current_room_node")
		global_position = player.global_position + Vector2(-70, 40)
		state = "follow"
	cooldown -= delta
	match state:
		"follow":
			var behind = player.global_position + Vector2(-80, 50).rotated(sin(time * 0.5) * 0.6)
			var want = (behind - global_position)
			vel = vel.lerp(want * 4.0, min(1.0, delta * 6.0)).limit_length(520.0)
			if cooldown <= 0.0:
				target = _pick_target()
				if target:
					state = "strike"
					strike_time = 1.0
		"strike":
			strike_time -= delta
			if target == null or not is_instance_valid(target) or target.get("dead") or strike_time <= 0.0:
				state = "follow"
				cooldown = 0.4
			else:
				var to_t = target.global_position - global_position
				vel = to_t.normalized() * 720.0
				var r = 30.0
				var cs = target.get_node_or_null("CollisionShape2D")
				if cs and cs.shape is CircleShape2D:
					r = cs.shape.radius
				if to_t.length() < r + 26.0:
					_bite(target)
	global_position += vel * delta
	if global_position.distance_to(player.global_position) > 900.0:
		global_position = player.global_position + Vector2(-70, 40)
	_animate(vel, delta)

func _pick_target() -> Node2D:
	var best: Node2D = null
	var best_d = REACH
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.get("dead") or (e.has_method("is_burrowed") and e.is_burrowed()):
			continue
		if e.get("mood") == "calm":
			continue # it leaves alone what leaves you alone
		var d = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _bite(e: Node2D):
	var dmg = max(1.5, float(player.get("damage")) * 0.45)
	e.take_damage(dmg)
	if e.has_method("apply_hit_push"):
		e.apply_hit_push(vel.normalized() * 200.0)
	SoundManager.play_hit(e.body_material() if e.has_method("body_material") else "soft", false, -6.0)
	HitFX.strike(get_parent(), e.global_position, vel.normalized(), "vesicle", Color(0.8, 0.9, 0.6), 12.0)
	state = "follow"
	cooldown = COOLDOWN
	vel = -vel * 0.4

func _animate(v: Vector2, delta: float):
	if puppet == null or not is_instance_valid(puppet):
		return
	puppet.face_sprite(v, delta, 10.0)
	var spr = puppet.get_node("Sprite2D")
	if spr.hframes == 4:
		spr.frame = int(fmod(time * (4.0 + v.length() / 60.0), 4.0))

func _draw():
	# A dotted ring in green ink: this one's a friend
	var r = 38.0
	for i in 12:
		var a = TAU * i / 12.0 + time * 0.6
		draw_arc(Vector2.ZERO, r, a, a + 0.28, 4, Color(FRIEND, 0.8), 2.4, true)
	if not joined:
		SR.draw_label(self, Vector2(0, -70), "TOUCH TO BEFRIEND", 22)
