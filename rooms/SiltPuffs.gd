# SiltPuffs.gd
# Little clouds of silt (or dust, on land) kicked up where a running foot
# lands: a few stippled ink dots that burst out from the footfall, drift and
# fade, as a naturalist would dot them in. Fed by PlayerBody.gd's planted
# feet (leg()), for you and for every drawn animal. One per room, a child of
# its trace layer, so it sits on the floor under everyone and slides with
# the room.
extends Node2D

const LIFE := 0.6
const MAX_PUFFS := 48
const INK := Color(0.30, 0.22, 0.14)

# The puff layer of the room you are in
static var current: Node2D = null

var pen = preload("res://InkBatch.gd").new()
var time := 0.0
# [pos (local), born, size, drift dir, seed, wake]
var puffs: Array = []

func _ready():
	z_index = -2

func _enter_tree():
	current = self

func _exit_tree():
	if current == self:
		current = null

# A puff at a world position; size ~1 for a player-sized foot
static func puff(world_pos: Vector2, size: float, dir: Vector2):
	if current == null or not is_instance_valid(current) or not current.is_inside_tree():
		return
	current._add(world_pos, size, dir, false)

# A swimmer's wake: ripple lines spreading from behind its tail
static func wake(world_pos: Vector2, size: float, dir: Vector2):
	if current == null or not is_instance_valid(current) or not current.is_inside_tree():
		return
	current._add(world_pos, size, dir, true)

func _add(world_pos: Vector2, size: float, dir: Vector2, is_wake: bool):
	if puffs.size() >= MAX_PUFFS:
		puffs.pop_front()
	puffs.append([world_pos - global_position, time, clamp(size, 0.4, 3.0), dir, randf() * TAU, is_wake])
	set_process(true)

func _process(delta: float):
	time += delta
	while not puffs.is_empty() and time - puffs[0][1] > LIFE:
		puffs.pop_front()
	queue_redraw()
	if puffs.is_empty():
		set_process(false)

func _draw():
	if puffs.is_empty():
		return
	pen.begin(self)
	for p in puffs:
		var k: float = (time - p[1]) / LIFE
		if k < 0.0 or k > 1.0:
			continue
		var s: float = p[2]
		var out := 1.0 - pow(1.0 - k, 3.0) # burst out fast, then hang
		var fade := (1.0 - k) * (1.0 - k)
		var seed0: float = p[4]
		if p[5]:
			# Two curved ripple lines opening out behind the tail
			var back: float = (-(p[3] as Vector2)).angle() if (p[3] as Vector2).length_squared() > 0.0 else seed0
			for j in 2:
				var r := (5.0 + 18.0 * out) * s * (1.0 - 0.35 * j)
				pen.draw_arc(p[0], r, back - 1.0, back + 1.0, 12, Color(INK, (0.32 - 0.1 * j) * fade), 1.3, true)
			continue
		var base: Vector2 = p[0] - (p[3] as Vector2) * (6.0 * s * out)
		# Five stipple dots thrown out round the footfall, kicked back from
		# the direction of travel
		for i in 5:
			var a := seed0 + i * 1.257 + sin(seed0 * 3.0 + i) * 0.4
			var r := (3.0 + 7.0 * out) * s * (0.7 + 0.3 * sin(seed0 + i * 2.1))
			var q := base + Vector2.from_angle(a) * r
			pen.draw_circle(q, (1.3 - 0.5 * k) * s, Color(INK, 0.55 * fade), true, -1.0, true)
		# A faint ring of settling silt
		if s > 0.7:
			pen.draw_arc(base, (4.0 + 9.0 * out) * s, seed0, seed0 + 4.2, 10, Color(INK, 0.18 * fade), 1.0, true)
	pen.flush()
