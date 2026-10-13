# Enemy.gd
extends CharacterBody2D

signal enemy_died
signal boss_health_changed(current, max_value, boss_title)

@export var enemy_type: String = "fly" # "fly" (Amoeba), "pacer" (Trilobite), "boss_stentor", "boss_anomalocaris", "boss_cameroceras"

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
}
var facing: Vector2 = Vector2.DOWN # armoured: where its shielded front points
var charge_state: String = ""
var charge_timer: float = 0.0
var charge_cooldown: float = 0.0
var charge_dir: Vector2 = Vector2.ZERO
var flee_timer: float = 0.0
var burrow_state: String = "walk"
var burrow_timer: float = 0.0
var dust: CPUParticles2D = null

# Preloads
var tear_scene = preload("res://Tear.tscn")
var fauna = preload("res://data/Fauna.gd")
var biomass_orb_script = preload("res://BiomassOrb.gd")

@onready var light = $PointLight2D

func _ready():
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	pick_random_wander()

func setup_enemy(floor_number: int):
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
		if light:
			light.color = Color(0.9, 0.75, 0.4)
			light.scale = Vector2(1.3, 1.3)

	elif enemy_type == "boss_stentor":
		# Floor 1: STENTOR TITAN — colossal trumpet predatory ciliate
		boss_title = "STENTOR TITAN — THE APEX HETEROTRICH"
		max_health = 95.0
		speed = 140.0
		damage = 1
		$Sprite2D.texture = load("res://assets/boss_stentor_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.15, 1.15)
		$CollisionShape2D.shape.radius = 80.0
		boss_state = "idle"
		boss_timer = randf_range(1.5, 2.5)
		shoot_timer = randf_range(2.0, 3.5)
		if light:
			light.color = Color(0.25, 0.05, 0.85)  # Deep bioluminescent indigo
			light.scale = Vector2(3.2, 3.2)
			light.energy = 1.8

	elif enemy_type == "boss_anomalocaris":
		# Floor 2: ANOMALOCARIS BRIGGSI — Cambrian apex radiodont
		boss_title = "ANOMALOCARIS BRIGGSI — APEX RADIODONT"
		max_health = 140.0
		speed = 190.0
		damage = 2
		$Sprite2D.texture = load("res://assets/boss_anomalocaris_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.3, 1.1)
		$CollisionShape2D.shape.radius = 90.0
		boss_state = "idle"
		boss_timer = randf_range(1.2, 2.0)
		shoot_timer = randf_range(1.5, 2.5)
		if light:
			light.color = Color(0.0, 0.85, 0.9)  # Vibrant Cambrian sea turquoise
			light.scale = Vector2(3.5, 3.5)
			light.energy = 1.9

	elif enemy_type == "boss_cameroceras":
		# Floor 3: CAMEROCERAS TRENTONENSE — titanic apex orthocone
		boss_title = "CAMEROCERAS TRENTONENSE — TITANIC APEX ORTHOCONE"
		max_health = 200.0
		speed = 105.0
		damage = 3
		$Sprite2D.texture = load("res://assets/boss_cameroceras_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.5, 1.3)
		$CollisionShape2D.shape.radius = 100.0
		boss_state = "idle"
		boss_timer = randf_range(1.8, 3.0)
		shoot_timer = randf_range(1.0, 2.0)
		if light:
			light.color = Color(0.45, 0.05, 0.75)  # Abyssal midnight trench violet
			light.scale = Vector2(4.0, 4.0)
			light.energy = 2.2

	elif enemy_type == "boss_arthropleura":
		# Floor 4: ARTHROPLEURA GIGANTEA — Carboniferous titanic centipede
		boss_title = "ARTHROPLEURA GIGANTEA — TITANIC PRIMEVAL CENTIPEDE"
		max_health = 260.0
		speed = 175.0
		damage = 2
		$Sprite2D.texture = load("res://assets/boss_arthropleura_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.3, 1.2)
		$CollisionShape2D.shape.radius = 95.0
		boss_state = "idle"
		boss_timer = randf_range(1.4, 2.2)
		shoot_timer = randf_range(1.5, 2.5)
		if light:
			light.color = Color(0.9, 0.5, 0.1) # Amber / Carboniferous moss
			light.scale = Vector2(3.8, 3.8)
			light.energy = 2.0

	elif enemy_type == "boss_postosuchus":
		# Floor 5: POSTOSUCHUS KIRKPATRICKI — Triassic apex archosaur
		boss_title = "POSTOSUCHUS KIRKPATRICKI — APEX TRIASSIC ARCHOSAUR"
		max_health = 340.0
		speed = 210.0
		damage = 3
		$Sprite2D.texture = load("res://assets/boss_postosuchus_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.35, 1.25)
		$CollisionShape2D.shape.radius = 95.0
		boss_state = "idle"
		boss_timer = randf_range(1.2, 2.0)
		shoot_timer = randf_range(1.8, 2.8)
		if light:
			light.color = Color(1.0, 0.3, 0.1) # Triassic badlands rust
			light.scale = Vector2(4.0, 4.0)
			light.energy = 2.1

	elif enemy_type == "boss_tyrannosaurus":
		# Floor 6: TYRANNOSAURUS REX — Cretaceous saurian monarch
		boss_title = "TYRANNOSAURUS REX — CRETACEOUS SAURIAN MONARCH"
		max_health = 440.0
		speed = 190.0
		damage = 4
		$Sprite2D.texture = load("res://assets/boss_tyrannosaurus_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.4, 1.35)
		$CollisionShape2D.shape.radius = 110.0
		boss_state = "idle"
		boss_timer = randf_range(1.5, 2.5)
		shoot_timer = randf_range(1.6, 2.6)
		if light:
			light.color = Color(1.0, 0.15, 0.05) # Burning volcanic crater
			light.scale = Vector2(4.5, 4.5)
			light.energy = 2.4

	elif enemy_type == "boss_apex_sovereign":
		# Floor 7: THE EXTINCTION SOVEREIGN — apex modern entity
		boss_title = "THE EXTINCTION SOVEREIGN — APEX CALAMITY"
		max_health = 600.0
		speed = 220.0
		damage = 4
		$Sprite2D.texture = load("res://assets/boss_apex_sovereign_sheet.png")
		$Sprite2D.hframes = 6
		$Sprite2D.scale = Vector2(1.45, 1.45)
		$CollisionShape2D.shape.radius = 115.0
		boss_state = "idle"
		boss_timer = randf_range(1.2, 2.0)
		shoot_timer = randf_range(1.2, 2.2)
		if light:
			light.color = Color(0.7, 0.05, 1.0) # Celestial extinction violet
			light.scale = Vector2(5.0, 5.0)
			light.energy = 2.8

	health = max_health

	if not is_boss():
		apply_fauna(floor_number)
	if is_boss():
		call_deferred("emit_boss_health")

func is_boss() -> bool:
	return enemy_type in [
		"boss_stentor", "boss_anomalocaris", "boss_cameroceras",
		"boss_arthropleura", "boss_postosuchus", "boss_tyrannosaurus", "boss_apex_sovereign"
	]

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

	elif enemy_type == "boss_stentor":
		$Sprite2D.frame = int(fmod(anim_timer * 4.5, 6.0))
		process_stentor_ai(delta)

	elif enemy_type == "boss_anomalocaris":
		$Sprite2D.frame = int(fmod(anim_timer * 6.0, 6.0))
		process_anomalocaris_ai(delta)

	elif enemy_type == "boss_cameroceras":
		$Sprite2D.frame = int(fmod(anim_timer * 3.5, 6.0))
		process_cameroceras_ai(delta)

	elif enemy_type == "boss_arthropleura":
		$Sprite2D.frame = int(fmod(anim_timer * 5.0, 6.0))
		process_arthropleura_ai(delta)

	elif enemy_type == "boss_postosuchus":
		$Sprite2D.frame = int(fmod(anim_timer * 4.5, 6.0))
		process_postosuchus_ai(delta)

	elif enemy_type == "boss_tyrannosaurus":
		$Sprite2D.frame = int(fmod(anim_timer * 4.0, 6.0))
		process_tyrannosaurus_ai(delta)

	elif enemy_type == "boss_apex_sovereign":
		$Sprite2D.frame = int(fmod(anim_timer * 5.5, 6.0))
		process_apex_sovereign_ai(delta)

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

# ═══════════════════════════════════════════════════════════
# BOSS 1: STENTOR TITAN — Ciliary vortex, myoneme spring lunges
# ═══════════════════════════════════════════════════════════
func process_stentor_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.4 if is_phase2 else 1.0

	if boss_state == "idle":
		# Trumpet-shaped ciliate slowly spirals toward player
		var dir = (player.global_position - global_position).normalized()
		var perp = Vector2(-dir.y, dir.x) * sin(anim_timer * 2.0) * 0.4
		velocity = (dir + perp).normalized() * speed * 0.6 * spd_mult
		move_and_slide()
		var s = 1.0 + sin(anim_timer * 2.5) * 0.08
		$Sprite2D.scale = Vector2(s * 1.15, s * 1.15)

		if shoot_timer <= 0:
			# Ciliary vortex: 16-point spinning tear fan
			fire_spinning_fan(16 if is_phase2 else 12, 300.0)
			SoundManager.play_sfx("shoot", 0.9, -2.0)
			shoot_timer = randf_range(2.5, 3.5) / spd_mult

		if boss_timer <= 0:
			boss_state = "prep_lunge"
			boss_timer = 0.7
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 1.0)

	elif boss_state == "prep_lunge":
		# Myoneme spring wind-up: contract
		$Sprite2D.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		$Sprite2D.scale = Vector2(0.7 * 1.15, 1.4 * 1.15)
		if boss_timer <= 0:
			$Sprite2D.position = Vector2.ZERO
			boss_state = "lunge"
			boss_timer = 0.55
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "lunge":
		# Myoneme spring release: fast elastic launch
		var diff = boss_target_pos - global_position
		var step = diff.normalized() * speed * 5.5 * spd_mult
		if step.length() * delta >= diff.length():
			global_position = boss_target_pos
		else:
			global_position += step * delta
		var t_ratio = max(0.0, boss_timer / 0.55)
		$Sprite2D.scale = Vector2((1.0 + t_ratio * 0.5) * 1.15, (1.0 + t_ratio * 0.5) * 1.15)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.15, 1.15)
			boss_state = "land"
			boss_timer = 0.35
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)
			SoundManager.play_sfx("explosion", 1.0)
			fire_radial_tears(8 if is_phase2 else 6)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(10.0)

	elif boss_state == "land":
		$Sprite2D.position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		$Sprite2D.scale = Vector2(1.3 * 1.15, 0.75 * 1.15)
		if boss_timer <= 0:
			$Sprite2D.position = Vector2.ZERO
			$Sprite2D.scale = Vector2(1.15, 1.15)
			boss_state = "cooldown"
			boss_timer = 1.0

	elif boss_state == "cooldown":
		velocity = Vector2.ZERO
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(1.2, 2.2) / spd_mult


# ═══════════════════════════════════════════════════════════
# BOSS 2: ANOMALOCARIS BRIGGSI — lateral flap charges, appendage sweeps
# ═══════════════════════════════════════════════════════════
func process_anomalocaris_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.55 if is_phase2 else 1.0

	if boss_state == "idle":
		# Undulating lateral flap swimming — strafe + approach
		var dir = (player.global_position - global_position).normalized()
		var perp = Vector2(-dir.y, dir.x)
		var wave = sin(anim_timer * 5.0) * 0.7
		velocity = (dir * 0.85 + perp * wave).normalized() * speed * spd_mult
		move_and_slide()
		# Face movement direction
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, velocity.angle(), delta * 4.0)

		if shoot_timer <= 0:
			# Radial spine volley from mouth cone
			fire_radial_tears(10 if is_phase2 else 7)
			SoundManager.play_sfx("shoot", 1.0, -1.0)
			shoot_timer = randf_range(1.8, 2.8) / spd_mult

		if boss_timer <= 0:
			boss_state = "prep_dash"
			boss_timer = 0.5
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 1.1)

	elif boss_state == "prep_dash":
		# Great frontal appendage sweep wind-up
		$Sprite2D.scale = Vector2(1.5, 0.85)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.3, 1.1)
			boss_state = "dash"
			boss_timer = 0.45
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "dash":
		# High-speed lateral flap charge
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 6.5 * spd_mult
		if diff.length() < 30:
			boss_state = "sweep"
			boss_timer = 0.5
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)
			fire_arc_tears(5, 60.0, (player.global_position - global_position).angle())
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(16.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "sweep"
			boss_timer = 0.5
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)

	elif boss_state == "sweep":
		$Sprite2D.scale = Vector2(0.9 * 1.3, 1.25 * 1.1)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.3, 1.1)
			boss_state = "cooldown"
			boss_timer = 1.1

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 5.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(0.8, 1.6) / spd_mult


# ═══════════════════════════════════════════════════════════
# BOSS 3: CAMEROCERAS TRENTONENSE — jet dashes, cephalopod fluid storms
# ═══════════════════════════════════════════════════════════
func process_cameroceras_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.3 if is_phase2 else 1.0

	if boss_state == "idle":
		# Heavy armored slow approach, slightly rotates shell toward player
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed * 0.45 * spd_mult
		move_and_slide()
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, dir.angle() - PI * 0.5, delta * 1.5)
		var s = 1.0 + sin(anim_timer * 1.8) * 0.04
		$Sprite2D.scale = Vector2(s * 1.5, s * 1.3)

		if shoot_timer <= 0:
			# 16-point tentacle radial fluid storm
			fire_radial_tears(16 if is_phase2 else 12)
			SoundManager.play_sfx("shoot", 0.85, -3.0)
			shoot_timer = randf_range(2.0, 3.5) / spd_mult

		if boss_timer <= 0:
			if is_phase2 and randf() < 0.4:
				# Ink cloud: brief invulnerability + burst
				boss_state = "ink_prep"
				boss_timer = 0.8
			else:
				boss_state = "jet_prep"
				boss_timer = 0.9
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 0.85)

	elif boss_state == "jet_prep":
		# Hyponome siphon pressurization
		$Sprite2D.position = Vector2(randf_range(-6, 6), randf_range(-6, 6))
		$Sprite2D.scale = Vector2(1.2, 1.65)
		if boss_timer <= 0:
			$Sprite2D.position = Vector2.ZERO
			$Sprite2D.scale = Vector2(1.5, 1.3)
			boss_state = "jet_dash"
			boss_timer = 0.7
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "jet_dash":
		# Pressurized hyponome jet burst
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 7.0 * spd_mult
		if diff.length() < 50:
			boss_state = "jet_land"
			boss_timer = 0.45
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)
			fire_radial_tears(8 if is_phase2 else 6)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(20.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "jet_land"
			boss_timer = 0.45
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)

	elif boss_state == "jet_land":
		$Sprite2D.scale = Vector2(1.7, 0.95)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.5, 1.3)
			boss_state = "cooldown"
			boss_timer = 1.5

	elif boss_state == "ink_prep":
		# Ink miasma: spin and burst
		$Sprite2D.rotation += delta * 8.0
		$Sprite2D.scale = Vector2(1.6, 1.6)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.5, 1.3)
			boss_state = "ink_burst"
			boss_timer = 0.2
			# 3 staggered rings of tears
			fire_radial_tears(10)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(18.0)
			SoundManager.play_sfx("explosion", 1.3)

	elif boss_state == "ink_burst":
		if boss_timer <= 0:
			fire_radial_tears(8)
			boss_state = "cooldown"
			boss_timer = 1.8

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 3.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(1.5, 2.5) / spd_mult

# ═══════════════════════════════════════════════════════════
# BOSS 4: ARTHROPLEURA GIGANTEA — serpentine slither rush & venom thorn volleys
# ═══════════════════════════════════════════════════════════
func process_arthropleura_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.45 if is_phase2 else 1.0

	if boss_state == "idle":
		var dir = (player.global_position - global_position).normalized()
		var wave = sin(anim_timer * 6.0) * 0.8
		var perp = Vector2(-dir.y, dir.x)
		velocity = (dir + perp * wave).normalized() * speed * spd_mult
		move_and_slide()
		$Sprite2D.rotation = lerp_angle($Sprite2D.rotation, velocity.angle() + PI/2, delta * 5.0)

		if shoot_timer <= 0:
			fire_radial_tears(12 if is_phase2 else 8)
			SoundManager.play_sfx("shoot", 0.9, -1.0)
			shoot_timer = randf_range(1.8, 2.8) / spd_mult

		if boss_timer <= 0:
			boss_state = "prep_slither"
			boss_timer = 0.6
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 1.1)

	elif boss_state == "prep_slither":
		$Sprite2D.scale = Vector2(1.5, 0.9)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.3, 1.2)
			boss_state = "slither_rush"
			boss_timer = 0.65
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "slither_rush":
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 4.8 * spd_mult
		if diff.length() < 40:
			boss_state = "cooldown"
			boss_timer = 0.8
			set_collision_mask_value(3, true)
			fire_arc_tears(7, 75.0, (player.global_position - global_position).angle())
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(12.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "cooldown"
			boss_timer = 0.8
			set_collision_mask_value(3, true)

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 4.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(1.0, 1.8) / spd_mult

# ═══════════════════════════════════════════════════════════
# BOSS 5: POSTOSUCHUS KIRKPATRICKI — predatory leaping pounce & bone-crushing shockwave
# ═══════════════════════════════════════════════════════════
func process_postosuchus_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.5 if is_phase2 else 1.0

	if boss_state == "idle":
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed * 0.7 * spd_mult
		move_and_slide()
		$Sprite2D.scale.x = (1.35 if dir.x >= 0 else -1.35)

		if shoot_timer <= 0:
			# Razor tooth cone volley
			fire_arc_tears(6 if is_phase2 else 4, 50.0, dir.angle())
			SoundManager.play_sfx("shoot", 0.8, -2.0)
			shoot_timer = randf_range(2.0, 3.0) / spd_mult

		if boss_timer <= 0:
			boss_state = "prep_pounce"
			boss_timer = 0.55
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 1.15)

	elif boss_state == "prep_pounce":
		# Crouch before leap
		$Sprite2D.scale = Vector2(1.5, 0.8)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.35, 1.25)
			boss_state = "pounce_leap"
			boss_timer = 0.5
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "pounce_leap":
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 6.0 * spd_mult
		move_and_slide()
		var t_ratio = max(0.0, boss_timer / 0.5)
		$Sprite2D.scale = Vector2(1.35, 1.25) * (1.0 + sin(t_ratio * PI) * 0.45)
		if boss_timer <= 0 or diff.length() < 35.0:
			global_position = boss_target_pos
			boss_state = "land_stomp"
			boss_timer = 0.35
			velocity = Vector2.ZERO
			set_collision_mask_value(3, true)
			SoundManager.play_sfx("explosion", 1.2)
			fire_radial_tears(14 if is_phase2 else 10)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(18.0)

	elif boss_state == "land_stomp":
		$Sprite2D.scale = Vector2(1.6, 0.9)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.35, 1.25)
			boss_state = "cooldown"
			boss_timer = 1.0

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 4.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(1.0, 1.8) / spd_mult

# ═══════════════════════════════════════════════════════════
# BOSS 6: TYRANNOSAURUS REX — earth-shattering saurian roar & crushing lunge
# ═══════════════════════════════════════════════════════════
func process_tyrannosaurus_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.45 if is_phase2 else 1.0

	if boss_state == "idle":
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed * 0.8 * spd_mult
		move_and_slide()
		$Sprite2D.scale.x = (1.4 if dir.x >= 0 else -1.4)

		if shoot_timer <= 0:
			fire_arc_tears(7 if is_phase2 else 5, 60.0, dir.angle())
			SoundManager.play_sfx("shoot", 0.7, -3.0)
			shoot_timer = randf_range(1.8, 2.6) / spd_mult

		if boss_timer <= 0:
			if randf() < 0.5:
				boss_state = "roar_prep"
				boss_timer = 0.75
			else:
				boss_state = "lunge_prep"
				boss_timer = 0.6
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 0.9)

	elif boss_state == "roar_prep":
		$Sprite2D.position = Vector2(randf_range(-6, 6), randf_range(-6, 6))
		$Sprite2D.scale = Vector2(1.6, 1.6)
		if boss_timer <= 0:
			$Sprite2D.position = Vector2.ZERO
			$Sprite2D.scale = Vector2(1.4, 1.35)
			boss_state = "roar_burst"
			boss_timer = 0.3
			SoundManager.play_sfx("explosion", 0.95)
			fire_radial_tears(20 if is_phase2 else 14)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(24.0)

	elif boss_state == "roar_burst":
		if boss_timer <= 0:
			boss_state = "cooldown"
			boss_timer = 1.2

	elif boss_state == "lunge_prep":
		$Sprite2D.scale = Vector2(1.7, 1.0)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.4, 1.35)
			boss_state = "lunge_bite"
			boss_timer = 0.65
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "lunge_bite":
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 5.5 * spd_mult
		move_and_slide()
		if diff.length() < 40 or boss_timer <= 0:
			boss_state = "cooldown"
			boss_timer = 1.0
			set_collision_mask_value(3, true)
			fire_arc_tears(6, 45.0, (player.global_position - global_position).angle())
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(16.0)

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 3.5)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(1.0, 1.8) / spd_mult

# ═══════════════════════════════════════════════════════════
# BOSS 7: THE EXTINCTION SOVEREIGN — celestial spiral nova & dimensional warp
# ═══════════════════════════════════════════════════════════
func process_apex_sovereign_ai(delta: float):
	boss_timer -= delta
	shoot_timer -= delta
	var is_phase2 = health < max_health * 0.5
	var spd_mult = 1.6 if is_phase2 else 1.0

	if boss_state == "idle":
		var dir = (player.global_position - global_position).normalized()
		var perp = Vector2(-dir.y, dir.x) * sin(anim_timer * 3.5) * 0.7
		velocity = (dir + perp).normalized() * speed * 0.85 * spd_mult
		move_and_slide()
		var s = 1.45 + sin(anim_timer * 4.0) * 0.08
		$Sprite2D.scale = Vector2(s, s)

		if shoot_timer <= 0:
			# Dual rotating spiral nova
			fire_spinning_fan(16 if is_phase2 else 12, 380.0)
			SoundManager.play_sfx("shoot", 1.1, -1.0)
			shoot_timer = randf_range(1.2, 2.0) / spd_mult

		if boss_timer <= 0:
			if randf() < 0.5:
				boss_state = "nova_prep"
				boss_timer = 0.8
			else:
				boss_state = "vortex_prep"
				boss_timer = 0.6
			velocity = Vector2.ZERO
			SoundManager.play_sfx("boss_roar", 1.3)

	elif boss_state == "nova_prep":
		$Sprite2D.rotation += delta * 12.0
		$Sprite2D.scale = Vector2(1.8, 1.8)
		if boss_timer <= 0:
			$Sprite2D.rotation = 0.0
			$Sprite2D.scale = Vector2(1.45, 1.45)
			boss_state = "nova_fire"
			boss_timer = 0.3
			SoundManager.play_sfx("explosion", 1.4)
			fire_radial_tears(24 if is_phase2 else 18)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(26.0)

	elif boss_state == "nova_fire":
		if boss_timer <= 0:
			fire_spinning_fan(12, 420.0)
			boss_state = "cooldown"
			boss_timer = 1.0

	elif boss_state == "vortex_prep":
		$Sprite2D.scale = Vector2(0.8, 1.9)
		if boss_timer <= 0:
			$Sprite2D.scale = Vector2(1.45, 1.45)
			boss_state = "vortex_warp"
			boss_timer = 0.5
			boss_target_pos = player.global_position
			set_collision_mask_value(3, false)

	elif boss_state == "vortex_warp":
		var diff = boss_target_pos - global_position
		velocity = diff.normalized() * speed * 7.5 * spd_mult
		move_and_slide()
		if diff.length() < 50 or boss_timer <= 0:
			boss_state = "cooldown"
			boss_timer = 0.9
			set_collision_mask_value(3, true)
			fire_radial_tears(16)
			var main = get_tree().get_first_node_in_group("main")
			if main: main.shake_camera(20.0)

	elif boss_state == "cooldown":
		velocity = lerp(velocity, Vector2.ZERO, delta * 4.0)
		move_and_slide()
		if boss_timer <= 0:
			boss_state = "idle"
			boss_timer = randf_range(0.8, 1.5) / spd_mult

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
	stun_timer = max(stun_timer, duration * (0.2 if is_boss() else 1.0))

func apply_knockback(force: Vector2, stun_duration: float = 0.4):
	if is_burrowed():
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
	if armour_blocks():
		amount *= 0.25
		if randf() < 0.5:
			SoundManager.play_sfx("hit", 1.8, -6.0)
	if enemy_type == "swarm":
		scatter_swarm()
	health = max(0.0, health - amount)
	hit_flash_timer = 0.18
	
	# Bright white flash Tween
	$Sprite2D.modulate = Color(3.0, 2.5, 2.5, 1.0)
	var flash_tween = create_tween()
	flash_tween.tween_property($Sprite2D, "modulate", base_tint, 0.20)
	
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
		main.hit_stop(0.22 if is_boss() else 0.035)

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
