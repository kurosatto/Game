# Enemy.gd
extends CharacterBody2D

signal enemy_died
signal boss_health_changed(current, max_value, boss_title)

@export var enemy_type: String = "fly" # "fly" (chaser) or "pacer" (wanders and shoots); bosses are in bosses/

var max_health: float = 5.0
var health: float = 5.0
var speed: float = 160.0
var damage: int = 1

# AI State variables
var player: Node2D = null
var shoot_timer: float = 0.0
var wander_dir: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var anim_timer: float = 0.0

# Boss specific states
var boss_state: String = "idle"
var boss_timer: float = 0.0
var boss_target_pos: Vector2 = Vector2.ZERO
var boss_title: String = "APEX ENTITY"
var boss_phase: int = 1  # Phase 2 triggers at 50% HP

# Hit flash & stun/knockback
var hit_flash_timer: float = 0.0
const HitFX = preload("res://HitFX.gd")
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0
# Weapon specials (Player.weapon_special): sting venom stacks, held by
# arms or a tongue, blinded by spit so it can't aim
var venom_stacks: int = 0
var grabbed_time: float = 0.0
var blind_timer: float = 0.0

# Era look for regular enemies (data/Fauna.gd)
var base_tint: Color = Color.WHITE
var base_scale: float = 1.0
var fauna_name: String = ""
var has_species_art: bool = false
var behavior: String = ""
var weave_phase: float = 0.0
var shoot_delay_mult: float = 1.0
# Lunge: "windup" (telegraph) then "dash" at the player
var lunge_state: String = ""
var lunge_timer: float = 0.0
var lunge_cooldown: float = 0.0
var lunge_dir: Vector2 = Vector2.ZERO

# Third-animal behaviours (see data/Fauna.gd)
const SPECIAL_STATS = {
	"tank": {"hp": 14.0, "hp_per_floor": 3.0, "speed": 62.0, "radius": 46.0, "worth": 3.0},
	"armoured": {"hp": 9.0, "hp_per_floor": 2.0, "speed": 90.0, "radius": 34.0, "worth": 2.0},
	"charger": {"hp": 7.0, "hp_per_floor": 1.5, "speed": 110.0, "radius": 24.0, "worth": 2.0},
	"swarm": {"hp": 2.5, "hp_per_floor": 0.5, "speed": 235.0, "radius": 17.0, "worth": 0.5},
	"burrower": {"hp": 8.0, "hp_per_floor": 2.0, "speed": 150.0, "radius": 28.0, "worth": 2.0},
	"colony": {"hp": 5.0, "hp_per_floor": 1.5, "speed": 0.0, "radius": 30.0, "worth": 0.5},
	"skittish": {"hp": 3.0, "hp_per_floor": 0.8, "speed": 265.0, "radius": 20.0, "worth": 3.0},
	"enroll": {"hp": 10.0, "hp_per_floor": 2.0, "speed": 80.0, "radius": 34.0, "worth": 2.0},
	"snarer": {"hp": 6.0, "hp_per_floor": 1.5, "speed": 95.0, "radius": 24.0, "worth": 2.0},
	"orbiter": {"hp": 7.0, "hp_per_floor": 1.5, "speed": 210.0, "radius": 24.0, "worth": 2.0},
}
# Animals that never hurt on contact
const HARMLESS = ["colony", "skittish"]
const COLONY_CAP = 6
var facing: Vector2 = Vector2.DOWN # armoured: where its shielded front points
var charge_state: String = ""
var charge_timer: float = 0.0
var charge_cooldown: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var flee_timer: float = 0.0
var burrow_state: String = "walk"
var burrow_timer: float = 0.0
var dust: CPUParticles2D = null
var floor_num: int = 1
var sprout_timer: float = 0.0 # colony: time to the next runner
var grow: float = 1.0 # colony: new sprouts grow in from small
var enroll_time: float = 0.0 # enroll: rolled up and untouchable
var enroll_cooldown: float = 0.0
var spray_state: String = "" # snarer: "windup" before a slime jet
var spray_timer: float = 0.0
var orbit_sign: float = 1.0 # orbiter: which way it circles

# Preloads
var tear_scene = preload("res://Tear.tscn")
var fauna = preload("res://data/Fauna.gd")
var biomass_orb_script = preload("res://BiomassOrb.gd")

@onready var light = $PointLight2D

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	pick_random_wander()
	setup_hit_feedback()

# ═══════════════════════════════════════════════════════════
# HIT FEEDBACK: white flash, a squash "punch", a little shove and a health bar
# ═══════════════════════════════════════════════════════════
# The sprite's shader turns it white and swells it for a moment on each hit.
# Done in the shader so it works on top of whatever scale and tint the
# behaviour code sets every frame.
const HIT_SHADER = """
shader_type canvas_item;
uniform float flash = 0.0;
uniform float punch = 0.0;
void vertex() {
	VERTEX *= 1.0 + punch;
}
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
"""
static var hit_shader: Shader
var hit_material: ShaderMaterial
var hit_fx_tween: Tween
var health_bar: Node2D
var shown_health: float = -1.0 # bar's trailing "chip" that drains after a hit
var bar_timer: float = 0.0

func setup_hit_feedback():
	if hit_shader == null:
		hit_shader = Shader.new()
		hit_shader.code = HIT_SHADER
	hit_material = ShaderMaterial.new()
	hit_material.shader = hit_shader
	$Sprite2D.material = hit_material
	health_bar = Node2D.new()
	health_bar.z_index = 4
	health_bar.visible = false
	health_bar.draw.connect(draw_health_bar)
	add_child(health_bar)

func hit_feedback(amount: float):
	if hit_material == null:
		return
	if hit_fx_tween and hit_fx_tween.is_valid():
		hit_fx_tween.kill()
	var strength = clamp(amount / max(1.0, max_health) * 2.5, 0.12, 0.3)
	hit_material.set_shader_parameter("flash", 0.85)
	hit_material.set_shader_parameter("punch", strength)
	hit_fx_tween = create_tween().set_parallel(true)
	hit_fx_tween.tween_method(func(v): hit_material.set_shader_parameter("flash", v), 0.85, 0.0, 0.12)
	hit_fx_tween.tween_method(func(v): hit_material.set_shader_parameter("punch", v), strength, 0.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if shown_health < 0.0:
		shown_health = health + amount
	bar_timer = 1.6
	health_bar.visible = true

func update_health_bar(delta: float):
	if health_bar == null or not health_bar.visible:
		return
	bar_timer -= delta
	shown_health = move_toward(shown_health, health, delta * max_health * 1.5)
	health_bar.modulate.a = 1.0 if bar_timer > 0.0 else 0.55
	health_bar.visible = health > 0.0 and not is_burrowed()
	health_bar.queue_redraw()

func draw_health_bar():
	var w = clamp($CollisionShape2D.shape.radius * 1.7, 34.0, 90.0)
	var y = -$CollisionShape2D.shape.radius - 16.0
	var r = Rect2(-w / 2.0, y, w, 7.0)
	health_bar.draw_rect(r.grow(1.5), Color(0.03, 0.04, 0.08, 0.85))
	var chip = clamp(shown_health / max_health, 0.0, 1.0)
	var frac = clamp(health / max_health, 0.0, 1.0)
	health_bar.draw_rect(Rect2(r.position, Vector2(w * chip, r.size.y)), Color(1.0, 0.95, 0.85))
	var col = Color(0.35, 1.0, 0.45).lerp(Color(1.0, 0.3, 0.25), 1.0 - frac)
	health_bar.draw_rect(Rect2(r.position, Vector2(w * frac, r.size.y)), col)

# A small shove from an ordinary shot, without the stun a real knockback gives
func apply_hit_push(force: Vector2):
	if is_burrowed() or is_enrolled() or enemy_type == "colony":
		return
	if enemy_type in ["tank", "armoured"]:
		force *= 0.3
	knockback_velocity = (knockback_velocity + force).limit_length(max(force.length(), 420.0))

func setup_enemy(floor_number: int):
	floor_num = floor_number
	# Each enemy needs its own shape, or a boss radius leaks into every enemy
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	if enemy_type == "fly":
		# Amoeba Swarmer
		max_health = 4.0 + floor_number * 1.5
		speed = 170.0 + randf_range(-15, 25)
		damage = 1
		$Sprite2D.texture = load("res://assets/enemy_fly_sheet.png")
		$Sprite2D.hframes = 4
		$CollisionShape2D.shape.radius = 26.0
		if light:
			light.color = Color(0.85, 0.2, 0.9)
			light.scale = Vector2(1.2, 1.2)
	elif enemy_type == "pacer":
		# Proto-Trilobite Crawler
		max_health = 7.0 + floor_number * 2.0
		speed = 105.0 + randf_range(-10, 10)
		damage = 1
		$Sprite2D.texture = load("res://assets/enemy_gusha_sheet.png")
		$Sprite2D.hframes = 4
		$CollisionShape2D.shape.radius = 34.0
		shoot_timer = randf_range(1.2, 2.2)
		if light:
			light.color = Color(0.0, 0.8, 0.9)
			light.scale = Vector2(1.4, 1.4)

	elif enemy_type in SPECIAL_STATS:
		# The era's third animal (data/Fauna.gd): its own behaviour below
		var st = SPECIAL_STATS[enemy_type]
		max_health = st.hp + floor_number * st.hp_per_floor
		speed = st.speed + randf_range(-10, 10)
		damage = 1
		$Sprite2D.texture = load("res://assets/enemy_gusha_sheet.png")
		$Sprite2D.hframes = 4
		$CollisionShape2D.shape.radius = st.radius
		charge_cooldown = randf_range(1.0, 2.0)
		burrow_timer = randf_range(1.2, 2.2)
		sprout_timer = randf_range(3.0, 5.0)
		spray_timer = randf_range(1.5, 2.5)
		orbit_sign = 1.0 if randf() < 0.5 else -1.0
		if enemy_type in HARMLESS:
			damage = 0
		if light:
			light.color = Color(0.9, 0.75, 0.4)
			light.scale = Vector2(1.3, 1.3)

	health = max_health

	if not is_boss():
		apply_fauna(floor_number)
	if is_boss():
		call_deferred("emit_boss_health")

# Bosses live in bosses/ now; regular enemies never are one
func is_boss() -> bool:
	return false

func apply_fauna(floor_number: int):
	var f = fauna.get_fauna(floor_number, enemy_type)
	if f.is_empty():
		return
	fauna_name = f.name
	base_tint = f.tint
	# Species art from generate_fauna_art.py, when there is a sheet for it
	var sheet_path = "res://assets/fauna/%s_sheet.png" % fauna_name.to_lower()
	if ResourceLoader.exists(sheet_path):
		$Sprite2D.texture = load(sheet_path)
		has_species_art = true
	base_scale = f.scale
	speed *= f.speed
	$Sprite2D.modulate = base_tint
	$Sprite2D.scale = Vector2(base_scale, base_scale)
	$CollisionShape2D.shape.radius *= base_scale
	behavior = f.get("behavior", "")
	shoot_delay_mult = f.get("shoot_delay", 1.0)
	weave_phase = randf() * TAU
	lunge_cooldown = randf_range(1.0, 2.5)

# Ambush predators wind up, then dash at the player. Returns true while lunging.
func process_lunge(delta: float) -> bool:
	if lunge_state == "windup":
		lunge_timer -= delta
		$Sprite2D.modulate = base_tint.lerp(Color(2.0, 1.2, 1.2), 0.5 + 0.5 * sin(anim_timer * 40.0))
		if lunge_timer <= 0:
			lunge_state = "dash"
			lunge_timer = 0.35
		return true
	if lunge_state == "dash":
		lunge_timer -= delta
		velocity = lunge_dir * speed * 4.0
		$Sprite2D.rotation = lunge_dir.angle() + PI/2
		if move_and_slide() or lunge_timer <= 0:
			lunge_state = ""
			lunge_cooldown = randf_range(2.0, 3.2)
			$Sprite2D.modulate = base_tint
		return true
	lunge_cooldown -= delta
	if lunge_cooldown <= 0 and global_position.distance_to(player.global_position) < 420.0:
		lunge_state = "windup"
		lunge_timer = 0.45
		lunge_dir = (player.global_position - global_position).normalized()
		velocity = Vector2.ZERO
		return true
	return false

func emit_boss_health():
	boss_health_changed.emit(health, max_health, boss_title)

func pick_random_wander():
	var angles = [0, PI/2, PI, 3*PI/2, PI/4, 3*PI/4, 5*PI/4, 7*PI/4]
	var angle = angles.pick_random()
	wander_dir = Vector2.RIGHT.rotated(angle)
	wander_timer = randf_range(1.0, 2.0)

func _physics_process(delta: float):
	anim_timer += delta

	if hit_flash_timer > 0:
		hit_flash_timer -= delta
	else:
		$Sprite2D.modulate = base_tint
	update_health_bar(delta)

	if not player or not is_instance_valid(player):
		return
	if grabbed_time > 0:
		grabbed_time -= delta
	if blind_timer > 0:
		blind_timer -= delta

	# Bio-Electric knockback and stun processing
	if knockback_velocity.length_squared() > 1.0:
		velocity = knockback_velocity
		move_and_slide()
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, delta * 2400.0)
		return

	if stun_timer > 0:
		stun_timer -= delta
		return

	if enemy_type == "fly":
		var dir = (player.global_position - global_position).normalized()
		if behavior == "weave":
			# Swimmers and fliers approach in an S-curve instead of a straight line
			dir = dir.rotated(sin(anim_timer * 3.0 + weave_phase) * 0.9)
		elif behavior == "burst":
			# Short sprints with pauses between them
			dir *= 1.6 if fmod(anim_timer + weave_phase, 1.6) < 0.7 else 0.25
		velocity = dir * speed
		move_and_slide()

		var sx = 1.0 + sin(anim_timer * 8.0) * 0.12
		var sy = 1.0 - sin(anim_timer * 8.0) * 0.12
		$Sprite2D.scale = Vector2(sx, sy) * base_scale
		$Sprite2D.frame = int(fmod(anim_timer * 6.0, 4.0))
		# Animal sprites face up; turn them toward where they swim
		if has_species_art and velocity.length_squared() > 1.0:
			$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, velocity.angle() + PI/2, delta * 8.0)

	elif enemy_type == "pacer":
		wander_timer -= delta
		if wander_timer <= 0:
			pick_random_wander()

		if behavior == "lunge" and process_lunge(delta):
			check_contact_damage()
			return

		velocity = wander_dir * speed
		if move_and_slide():
			pick_random_wander()

		$Sprite2D.rotation = wander_dir.angle() + PI/2
		$Sprite2D.frame = int(fmod(anim_timer * 7.0, 4.0))

		shoot_timer -= delta
		if shoot_timer <= 0 and blind_timer <= 0:
			shoot_at_player()
			shoot_timer = randf_range(1.5, 2.5) * shoot_delay_mult

	elif enemy_type in SPECIAL_STATS:
		$Sprite2D.frame = int(fmod(anim_timer * (9.0 if enemy_type == "swarm" else 5.0), 4.0))
		match enemy_type:
			"tank": process_tank(delta)
			"armoured": process_armoured(delta)
			"charger": process_charger(delta)
			"swarm": process_swarm(delta)
			"burrower": process_burrower(delta)
			"colony": process_colony(delta)
			"skittish": process_skittish(delta)
			"enroll": process_enroll(delta)
			"snarer": process_snarer(delta)
			"orbiter": process_orbiter(delta)

	check_contact_damage()

# ═══════════════════════════════════════════════════════════
# THIRD ANIMALS: one new behaviour per era
# ═══════════════════════════════════════════════════════════
func face_sprite(dir: Vector2, delta: float, rate: float = 8.0, offset: float = PI/2):
	if dir.length_squared() > 0.01:
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, dir.angle() + offset, min(1.0, delta * rate))

# Dickinsonia: drifts straight at you, too heavy to push around
func process_tank(delta: float):
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	face_sprite(dir, delta, 2.0)

# Wiwaxia: turns slowly to keep its scaly, spined front toward you
func process_armoured(delta: float):
	var to_p = (player.global_position - global_position).normalized()
	var turn = clamp(facing.angle_to(to_p), -1.3 * delta, 1.3 * delta)
	facing = facing.rotated(turn)
	velocity = facing * speed
	move_and_slide()
	$Sprite2D.rotation = facing.angle() + PI/2

func armour_blocks() -> bool:
	if enemy_type != "armoured" or not player or not is_instance_valid(player):
		return false
	return facing.dot((player.global_position - global_position).normalized()) > 0.45

# Orthoceras: lines up, then jets shell-first across the room until it hits
# something; a wall leaves it dazed
func process_charger(delta: float):
	var to_p = player.global_position - global_position
	match charge_state:
		"windup":
			charge_timer -= delta
			$Sprite2D.modulate = base_tint.lerp(Color(2.0, 1.4, 1.2), 0.5 + 0.5 * sin(anim_timer * 40.0))
			face_sprite(charge_dir, delta, 20.0, -PI/2) # shell points the way it will go
			if charge_timer <= 0:
				charge_state = "dash"
				charge_timer = 1.4
		"dash":
			charge_timer -= delta
			velocity = charge_dir * speed * 6.5
			var hit = move_and_slide()
			if hit or charge_timer <= 0:
				var hit_player = false
				for i in get_slide_collision_count():
					if get_slide_collision(i).get_collider() == player:
						hit_player = true
				charge_state = ""
				charge_cooldown = randf_range(1.6, 2.6)
				$Sprite2D.modulate = base_tint
				if hit and not hit_player:
					stun_timer = 1.4 # dazed against the wall: free hits
					var main = get_tree().get_first_node_in_group("main")
					if main: main.shake_camera(4.0)
		_:
			wander_timer -= delta
			if wander_timer <= 0:
				pick_random_wander()
			velocity = wander_dir * speed * 0.6
			if move_and_slide():
				pick_random_wander()
			face_sprite(velocity, delta, 6.0, -PI/2)
			charge_cooldown -= delta
			if charge_cooldown <= 0 and to_p.length() < 900.0:
				charge_state = "windup"
				charge_timer = 0.65
				charge_dir = to_p.normalized()

# Archimylacris: a jittery pack; when one is hit the ones nearby scatter
func process_swarm(delta: float):
	var dir = (player.global_position - global_position).normalized()
	dir = dir.rotated(sin(anim_timer * 7.0 + weave_phase * 3.0) * 0.8)
	if flee_timer > 0:
		flee_timer -= delta
		dir = -dir
	velocity = dir * speed
	move_and_slide()
	face_sprite(velocity, delta, 14.0)

func scatter_swarm():
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e.get("enemy_type") == "swarm" and e.global_position.distance_to(global_position) < 260.0:
			e.flee_timer = 0.55

# Diictodon: walks at you, digs in (can't be hit), tunnels close, then
# bursts out after a dust warning and bites everything nearby
func process_burrower(delta: float):
	burrow_timer -= delta
	match burrow_state:
		"walk":
			var dir = (player.global_position - global_position).normalized()
			velocity = dir * speed
			move_and_slide()
			face_sprite(dir, delta)
			if burrow_timer <= 0:
				burrow_state = "dig"
				burrow_timer = 0.45
		"dig":
			$Sprite2D.scale = Vector2.ONE * base_scale * max(0.1, burrow_timer / 0.45)
			if burrow_timer <= 0:
				burrow_state = "under"
				burrow_timer = 1.6
				set_burrowed(true)
		"under":
			var to_p = player.global_position - global_position
			if to_p.length() > 70.0:
				global_position += to_p.normalized() * speed * 1.7 * delta
			if burrow_timer <= 0 or to_p.length() <= 70.0:
				burrow_state = "rise"
				burrow_timer = 0.6
				if dust: dust.amount = 40
		"rise":
			if burrow_timer <= 0:
				burrow_state = "walk"
				burrow_timer = randf_range(1.6, 2.4)
				set_burrowed(false)
				$Sprite2D.scale = Vector2.ONE * base_scale
				SoundManager.play_sfx("explosion", 1.6, -8.0)
				if player.global_position.distance_to(global_position) < 100.0:
					player.take_damage(damage)
				var main = get_tree().get_first_node_in_group("main")
				if main: main.shake_camera(5.0)

# ═══════════════════════════════════════════════════════════
# FOURTH ANIMALS: a second new behaviour per era
# ═══════════════════════════════════════════════════════════
# Fractofusus: rooted and harmless, but sends out runners that sprout new
# fronds nearby, so a colony left alone fills the room
func process_colony(delta: float):
	velocity = Vector2.ZERO
	grow = min(1.0, grow + delta / 1.5)
	var sway = 1.0 + 0.04 * sin(anim_timer * 2.0 + weave_phase)
	$Sprite2D.scale = Vector2.ONE * base_scale * (0.4 + 0.6 * grow) * sway
	$Sprite2D.rotation = weave_phase
	if grow < 1.0:
		return
	sprout_timer -= delta
	if sprout_timer <= 0:
		sprout_timer = randf_range(4.5, 6.5)
		spread_runner()

func spread_runner():
	var room = get_parent()
	if room == null or not room.has_method("spawn_enemy"):
		return
	var fronds = get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and e.get("enemy_type") == "colony" and not e.dead)
	if fronds.size() >= COLONY_CAP:
		return
	for attempt in 8:
		var pos = position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(110.0, 170.0)
		if pos.x < 320.0 or pos.x > 1600.0 or pos.y < 260.0 or pos.y > 820.0:
			continue
		if room.to_global(pos).distance_to(player.global_position) < 130.0:
			continue
		var blocked = false
		for c in room.get_children():
			if (c is StaticBody2D or c is CharacterBody2D) and c.position.distance_to(pos) < 75.0:
				blocked = true
				break
		if blocked:
			continue
		# A pale runner thread reaches out first
		var runner = Line2D.new()
		runner.width = 3.0
		runner.default_color = Color(0.95, 0.85, 0.7, 0.8)
		runner.points = PackedVector2Array([position, pos])
		runner.z_index = -1
		room.add_child(runner)
		var tw = runner.create_tween()
		tw.tween_property(runner, "modulate:a", 0.0, 1.6)
		tw.tween_callback(runner.queue_free)
		room.spawn_enemy(pos, "colony", floor_num)
		var sprout = room.active_enemies.back()
		if is_instance_valid(sprout):
			sprout.grow = 0.2
			sprout.health = sprout.max_health * 0.6
			sprout.sprout_timer = randf_range(5.5, 7.5)
		return

# Marrella: harmless and quick; it flees, and slips sideways when cornered
func process_skittish(delta: float):
	var away = global_position - player.global_position
	if flee_timer > 0:
		flee_timer -= delta
		velocity = wander_dir * speed
	elif away.length() < 420.0:
		velocity = away.normalized().rotated(sin(anim_timer * 5.0 + weave_phase) * 0.6) * speed
	else:
		wander_timer -= delta
		if wander_timer <= 0:
			pick_random_wander()
		velocity = wander_dir * speed * 0.3
	if move_and_slide() and get_last_slide_collision():
		var n = get_last_slide_collision().get_normal()
		wander_dir = n.rotated(PI / 2 * (1.0 if randf() < 0.5 else -1.0)).lerp(n, 0.3).normalized()
		flee_timer = 0.45
	face_sprite(velocity, delta, 12.0)

# Isotelus: plods toward you; a hit makes it roll up into an armoured ball
func process_enroll(delta: float):
	if enroll_time > 0:
		enroll_time -= delta
		velocity = Vector2.ZERO
		$Sprite2D.scale = $Sprite2D.scale.lerp(Vector2(0.8, 0.6) * base_scale, min(1.0, delta * 18.0))
		$Sprite2D.modulate = base_tint * Color(0.72, 0.72, 0.85)
		if enroll_time <= 0:
			enroll_cooldown = 2.6
		return
	enroll_cooldown -= delta
	$Sprite2D.scale = $Sprite2D.scale.lerp(Vector2.ONE * base_scale, min(1.0, delta * 10.0))
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * speed
	move_and_slide()
	face_sprite(dir, delta, 3.0)

func is_enrolled() -> bool:
	return enemy_type == "enroll" and enroll_time > 0

# Helenodora: keeps its distance, then squirts a fan of sticky slime
func process_snarer(delta: float):
	var to_p = player.global_position - global_position
	var d = to_p.length()
	if spray_state == "windup":
		spray_timer -= delta
		$Sprite2D.modulate = base_tint.lerp(Color(1.4, 2.0, 1.4), 0.5 + 0.5 * sin(anim_timer * 40.0))
		face_sprite(to_p, delta, 12.0)
		if spray_timer <= 0:
			spray_slime(to_p.normalized())
			spray_state = ""
			spray_timer = randf_range(2.6, 3.4)
		return
	var dir: Vector2
	if d > 330.0:
		dir = to_p.normalized()
	elif d < 220.0:
		dir = -to_p.normalized()
	else:
		dir = to_p.normalized().rotated(PI / 2) * (0.4 if sin(anim_timer * 0.7 + weave_phase) > 0 else -0.4)
	velocity = dir * speed
	move_and_slide()
	face_sprite(to_p if d < 330.0 else dir, delta, 6.0)
	spray_timer -= delta
	if spray_timer <= 0 and d < 440.0 and blind_timer <= 0:
		spray_state = "windup"
		spray_timer = 0.5

func spray_slime(dir: Vector2):
	SoundManager.play_sfx("shoot", 0.5, -4.0)
	for i in 5:
		var tear = tear_scene.instantiate()
		tear.position = global_position + dir * 26.0
		tear.direction = dir.rotated(deg_to_rad(-16.0 + i * 8.0 + randf_range(-2.0, 2.0)))
		tear.is_enemy_tear = true
		tear.is_snare = true
		tear.damage = 0
		tear.speed = randf_range(380.0, 440.0)
		tear.lifetime = 0.75
		get_parent().add_child(tear)

# Euchambersia: circles you, then darts in for a venomous bite
func process_orbiter(delta: float):
	var to_p = player.global_position - global_position
	var d = to_p.length()
	match charge_state:
		"windup":
			charge_timer -= delta
			$Sprite2D.modulate = base_tint.lerp(Color(2.0, 1.3, 1.3), 0.5 + 0.5 * sin(anim_timer * 40.0))
			face_sprite(to_p, delta, 20.0)
			if charge_timer <= 0:
				charge_state = "dash"
				charge_timer = 0.32
				charge_dir = to_p.normalized()
		"dash":
			charge_timer -= delta
			velocity = charge_dir * speed * 3.6
			var hit = move_and_slide()
			for i in get_slide_collision_count():
				if get_slide_collision(i).get_collider() == player:
					player.apply_slow(1.6, 0.6, "VENOM")
			if hit or charge_timer <= 0:
				charge_state = ""
				charge_cooldown = randf_range(2.2, 3.2)
				$Sprite2D.modulate = base_tint
				if randf() < 0.5:
					orbit_sign = -orbit_sign
		_:
			var radial = to_p.normalized() * clamp((d - 250.0) / 120.0, -1.0, 1.0)
			var tangent = to_p.normalized().rotated(PI / 2 * orbit_sign)
			velocity = (tangent + radial).normalized() * speed
			if move_and_slide():
				orbit_sign = -orbit_sign
			face_sprite(velocity, delta, 10.0)
			charge_cooldown -= delta
			if charge_cooldown <= 0 and d < 480.0:
				charge_state = "windup"
				charge_timer = 0.35

func set_burrowed(on: bool):
	$Sprite2D.visible = not on
	if light: light.visible = not on
	# Off the physics layers while underground: shots and bodies pass over
	if on:
		set_meta("layer", collision_layer)
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = get_meta("layer", 2)
		collision_mask = 1 | 4
	if on and dust == null:
		dust = CPUParticles2D.new()
		dust.amount = 16
		dust.lifetime = 0.6
		dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		dust.emission_sphere_radius = 26.0
		dust.gravity = Vector2.ZERO
		dust.initial_velocity_min = 10.0
		dust.initial_velocity_max = 50.0
		dust.scale_amount_min = 4.0
		dust.scale_amount_max = 9.0
		dust.color = Color(0.75, 0.6, 0.4, 0.8)
		add_child(dust)
	if dust:
		dust.amount = 16
		dust.emitting = on

func is_burrowed() -> bool:
	return burrow_state in ["under", "rise"]

func check_contact_damage():
	if damage <= 0:
		return
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and boss_state != "jump" and boss_state != "dash":
			collider.take_damage(damage)

func shoot_at_player():
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	var tear = tear_scene.instantiate()
	tear.position = global_position
	tear.direction = dir
	tear.is_enemy_tear = true
	tear.damage = 1
	tear.speed = 460.0
	get_parent().add_child(tear)
	
	SoundManager.play_sfx("shoot", 0.65, -5.0)  # Quieter, lower pitch than player shots

func fire_radial_tears(num_tears: int = 12):
	for i in range(num_tears):
		var angle = (i * 2 * PI) / num_tears
		var dir = Vector2.RIGHT.rotated(angle)
		var tear = tear_scene.instantiate()
		tear.position = global_position
		tear.direction = dir
		tear.is_enemy_tear = true
		tear.damage = damage
		tear.speed = 400.0 + (num_tears * 4.0)
		get_parent().add_child(tear)

func fire_spinning_fan(num_tears: int = 12, spd: float = 320.0):
	# Rotating fan with slight angular offset per fire (creates spiral over time)
	var base_angle = anim_timer * 1.8
	for i in range(num_tears):
		var angle = base_angle + (i * 2 * PI) / num_tears
		var dir = Vector2.RIGHT.rotated(angle)
		var tear = tear_scene.instantiate()
		tear.position = global_position
		tear.direction = dir
		tear.is_enemy_tear = true
		tear.damage = 1
		tear.speed = spd
		get_parent().add_child(tear)

func fire_arc_tears(num_tears: int, arc_deg: float, center_angle: float):
	# Spread tears in a cone arc
	for i in range(num_tears):
		var offset = deg_to_rad(arc_deg) * (float(i) / max(1, num_tears - 1) - 0.5)
		var dir = Vector2.RIGHT.rotated(center_angle + offset)
		var tear = tear_scene.instantiate()
		tear.position = global_position
		tear.direction = dir
		tear.is_enemy_tear = true
		tear.damage = damage
		tear.speed = 440.0
		get_parent().add_child(tear)

func apply_stun(duration: float):
	if is_enrolled():
		return
	stun_timer = max(stun_timer, duration * (0.2 if is_boss() else 1.0))

func apply_knockback(force: Vector2, stun_duration: float = 0.4):
	if is_burrowed() or is_enrolled() or enemy_type == "colony":
		return
	if enemy_type == "tank":
		knockback_velocity = force * 0.15
		return
	if is_boss():
		knockback_velocity = force * 0.15
		stun_timer = 0.1
	else:
		knockback_velocity = force
		stun_timer = max(stun_timer, stun_duration)

# For delayed hits (venom ticks, rasp scrapes) that may land after death
func take_damage_if_alive(amount: float):
	if not dead and health > 0:
		take_damage(amount)

func take_damage(amount: float):
	if is_burrowed():
		return
	if is_enrolled():
		# Rolled up: the blow glances off the shell
		if randf() < 0.5:
			SoundManager.play_sfx("hit", 2.0, -8.0)
		return
	# Serrated Edges adaptation: some hits do double
	if player and is_instance_valid(player) and player.get("crit_chance") and randf() < player.crit_chance:
		amount *= 2.0
		player.popup_text(global_position, "×2", Color(1.0, 0.8, 0.4))
	if armour_blocks():
		amount *= 0.25
		if randf() < 0.5:
			SoundManager.play_sfx("hit", 1.8, -6.0)
	if enemy_type == "swarm":
		scatter_swarm()
	health = max(0.0, health - amount)
	if enemy_type == "enroll" and health > 0 and enroll_cooldown <= 0:
		enroll_time = 1.8
		knockback_velocity = Vector2.ZERO
	hit_flash_timer = 0.18
	hit_feedback(amount)
	
	if is_boss():
		boss_health_changed.emit(health, max_health, boss_title)
		
	if health <= 0:
		die()

var dead: bool = false

func die():
	if dead:
		return
	dead = true
	SoundManager.play_sfx("enemy_die", 0.6 if is_boss() else 1.0)
	if not is_boss():
		drop_biomass()

	# Spawn colorful death burst particles
	spawn_death_particles()

	# A beat of freeze-frame sells the kill; longer for bosses
	var main = get_tree().get_first_node_in_group("main")
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.22 if is_boss() else 0.045)
	if main and main.has_method("shake_camera"):
		main.shake_camera(4.0)
	# Shockwave ring where it popped
	HitFX.pop(get_parent(), global_position, species_burst_color().lerp(Color.WHITE, 0.4), 30.0, 170.0 * max(1.0, base_scale), 0.28)

	enemy_died.emit()
	queue_free()

# Eaten prey feeds the adaptation bar: chasers are worth 1, shooters 2
func drop_biomass():
	var worth = 2.0 if enemy_type == "pacer" else 1.0
	if enemy_type in SPECIAL_STATS:
		worth = SPECIAL_STATS[enemy_type].worth
	var count = clampi(int(worth * 2.5), 1, 7)
	for i in count:
		var orb = biomass_orb_script.new()
		orb.value = worth / count
		orb.position = position
		get_parent().add_child(orb)

# Average colour of the species sheet's first frame, cached per texture
static var _burst_colors: Dictionary = {}

func species_burst_color() -> Color:
	var tex: Texture2D = $Sprite2D.texture
	var key = tex.resource_path
	if not _burst_colors.has(key):
		var img = tex.get_image()
		var c = Color(0, 0, 0, 0)
		var n = 0
		if img:
			if img.is_compressed():
				img.decompress()
			var fw = img.get_width() / 4
			for x in range(0, fw, 3):
				for y in range(0, img.get_height(), 3):
					var px = img.get_pixel(x, y)
					if px.a > 0.9 and px.get_luminance() > 0.2:
						c += px
						n += 1
		_burst_colors[key] = (c / n).lightened(0.15) if n > 0 else Color(0.9, 0.9, 0.9)
	var base: Color = _burst_colors[key] * base_tint
	return Color(base.r, base.g, base.b, 0.95)

func spawn_death_particles():
	var p = CPUParticles2D.new()
	p.position = global_position
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 0.98
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 240.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	p.amount = 24
	
	if enemy_type == "fly":
		p.amount = 28
		p.lifetime = 0.8
		p.color = Color(0.9, 0.3, 1.0, 0.95)
	elif enemy_type == "pacer":
		p.amount = 32
		p.lifetime = 0.9
		p.color = Color(0.0, 0.9, 0.8, 0.95)
	if has_species_art:
		# Burst in the animal's own colours rather than the old blob purple/teal
		p.color = species_burst_color()
	if not is_boss():
		var fade = Gradient.new()
		fade.set_color(0, Color(1.4, 1.4, 1.4, 1.0))
		fade.add_point(0.25, Color(1, 1, 1, 1))
		fade.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = fade
	elif enemy_type == "boss_stentor":
		p.amount = 70
		p.lifetime = 1.6
		p.initial_velocity_min = 130.0
		p.initial_velocity_max = 380.0
		p.scale_amount_min = 7.0
		p.scale_amount_max = 20.0
		p.color = Color(0.4, 0.1, 1.0, 0.95)  # Indigo burst
	elif enemy_type == "boss_anomalocaris":
		p.amount = 80
		p.lifetime = 1.8
		p.initial_velocity_min = 140.0
		p.initial_velocity_max = 420.0
		p.scale_amount_min = 8.0
		p.scale_amount_max = 22.0
		p.color = Color(0.0, 0.95, 0.9, 0.95)  # Turquoise burst
	elif enemy_type == "boss_cameroceras":
		p.amount = 100
		p.lifetime = 2.0
		p.initial_velocity_min = 150.0
		p.initial_velocity_max = 500.0
		p.scale_amount_min = 10.0
		p.scale_amount_max = 28.0
		p.color = Color(0.7, 0.1, 1.0, 0.95)  # Violet burst
	else:
		p.amount = 60
		p.lifetime = 1.4
		p.initial_velocity_min = 120.0
		p.initial_velocity_max = 400.0
		p.scale_amount_min = 6.0
		p.scale_amount_max = 18.0
		p.color = Color(1.0, 0.2, 0.3, 0.95)
		
		# Secondary white flash burst
		var p2 = CPUParticles2D.new()
		p2.position = global_position
		p2.emitting = true
		p2.one_shot = true
		p2.explosiveness = 1.0
		p2.gravity = Vector2.ZERO
		p2.amount = 20
		p2.lifetime = 0.5
		p2.initial_velocity_min = 60.0
		p2.initial_velocity_max = 180.0
		p2.scale_amount_min = 8.0
		p2.scale_amount_max = 20.0
		p2.color = Color(1.0, 1.0, 1.0, 0.9)
		get_parent().add_child(p2)
		var t2 = get_tree().create_timer(0.6)
		t2.timeout.connect(p2.queue_free)
		
	get_parent().add_child(p)
	var timer = get_tree().create_timer(p.lifetime + 0.1)
	timer.timeout.connect(p.queue_free)
