# HitFX.gd
# Small, cheap juice effects for shooting: the flash at the mouth when a shot
# leaves, and the spark burst and glow pop where it lands. Shared textures are
# built once; every effect frees itself.
extends RefCounted

static var glow_texture: ImageTexture
static var additive: CanvasItemMaterial
static var spark_ramp: Gradient

static func ensure_resources():
	if glow_texture != null:
		return
	# Built pixel by pixel rather than as a GradientTexture2D, which fills in
	# a frame late and would flash as a square the first time it is used
	var size = 64
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		for y in size:
			var d = Vector2(x + 0.5 - size / 2.0, y + 0.5 - size / 2.0).length() / (size / 2.0)
			var a = clamp(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a * (1.6 - 0.6 * a)))
	glow_texture = ImageTexture.create_from_image(img)
	additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spark_ramp = Gradient.new()
	spark_ramp.set_color(0, Color(1.6, 1.6, 1.6, 1))
	spark_ramp.set_color(1, Color(1, 1, 1, 0))

# A soft additive glow that grows from `from_size` to `to_size` pixels while it fades
static func pop(parent: Node, pos: Vector2, col: Color, from_size: float, to_size: float, time: float):
	ensure_resources()
	var s = Sprite2D.new()
	s.texture = glow_texture
	s.material = additive
	s.position = pos
	s.modulate = col
	s.scale = Vector2.ONE * (from_size / 64.0)
	s.z_index = 3
	parent.add_child(s)
	var tw = s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (to_size / 64.0), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, time)
	tw.chain().tween_callback(s.queue_free)

# Flash at the shooter's mouth as a shot leaves
static func muzzle(parent: Node, pos: Vector2, col: Color):
	pop(parent, pos, Color(col.r, col.g, col.b, 0.9).lerp(Color.WHITE, 0.35), 34.0, 60.0, 0.09)

# A shot landing on something alive: a bright pop plus sparks thrown forward
# along the shot's flight and out to the sides. strength ~1 for a normal shot.
static func impact(parent: Node, pos: Vector2, dir: Vector2, col: Color, strength: float = 1.0):
	ensure_resources()
	pop(parent, pos, Color(col.r, col.g, col.b, 0.95).lerp(Color.WHITE, 0.5), 20.0, 70.0 * strength, 0.14)
	var p = CPUParticles2D.new()
	p.position = pos
	p.texture = glow_texture
	p.material = additive
	p.color_ramp = spark_ramp
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = int(clamp(9.0 * strength, 5.0, 18.0))
	p.lifetime = 0.26
	p.direction = dir if dir != Vector2.ZERO else Vector2.RIGHT
	p.spread = 55.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 140.0 * strength
	p.initial_velocity_max = 320.0 * strength
	p.damping_min = 500.0
	p.damping_max = 700.0
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.24
	p.color = col.lerp(Color.WHITE, 0.3)
	p.z_index = 3
	p.emitting = true
	parent.add_child(p)
	p.get_tree().create_timer(0.4).timeout.connect(p.queue_free)
