# Rubble.gd
# A low bank of ink-drawn pebbles that closes a gap too narrow to walk
# through: between two pieces of scenery, or between one and the wall.
# Without it those gaps looked open but caught you (kuro, 2026-11-23).
# It blocks bodies but is low, so shots fly over it.
extends StaticBody2D

# Painted in the floor's scenery theme (data/SceneryTheme.gd) by Room.add_rubble
var INK = Color(0.24, 0.15, 0.08)
var FILL = Color(0.62, 0.53, 0.42)
var SHADE = Color(0.45, 0.36, 0.27)

func set_theme(era_name: String):
    var T = preload("res://data/SceneryTheme.gd")
    INK = T.dark(era_name).darkened(0.35)
    FILL = T.tone(era_name, 0.72)
    SHADE = T.tone(era_name, 0.42)
var a := Vector2.ZERO
var b := Vector2.ZERO
var stones: Array = [] # [outline points, centre, radius]
var pen = preload("res://InkBatch.gd").new() # all the pebbles in one draw call

func setup(from: Vector2, to: Vector2, thickness: float = 40.0):
    a = from
    b = to
    collision_layer = 4 # the obstacle layer: walkers stop, flyers pass
    collision_mask = 0
    z_index = -1 # tucked under the scenery it joins
    var d := b - a
    var col = CollisionShape2D.new()
    var rect = RectangleShape2D.new()
    rect.size = Vector2(d.length() + 16.0, thickness)
    col.shape = rect
    col.position = (a + b) * 0.5
    col.rotation = d.angle()
    add_child(col)
    # Same pebbles every visit: seed from where it sits
    var rng = RandomNumberGenerator.new()
    rng.seed = int(a.x * 13.0 + a.y * 7.0 + b.x * 3.0 + b.y)
    var n: int = max(4, int((d.length() / 11.0 + 3.0) * max(1.0, thickness / 40.0)))
    var side := d.normalized().orthogonal()
    for i in n:
        var t = (i + 0.5) / float(n)
        var c = a.lerp(b, t) + side * rng.randf_range(-thickness * 0.4, thickness * 0.4)
        var r = rng.randf_range(9.0, 16.0)
        var squash = rng.randf_range(0.6, 0.8)
        var turn = rng.randf_range(-0.4, 0.4)
        # A rough, faceted stone: an uneven ring of 7 corners
        var pts := PackedVector2Array()
        for k in 7:
            var ang = TAU * k / 7.0 + rng.randf_range(-0.2, 0.2)
            var rr = r * rng.randf_range(0.8, 1.12)
            pts.append(c + Vector2(cos(ang) * rr, sin(ang) * rr * squash).rotated(turn))
        stones.append([pts, c, r * squash])
    # Draw the back ones first so the front ones overlap them
    stones.sort_custom(func(p, q): return p[1].y < q[1].y)
    queue_redraw()

func _draw():
    pen.begin(self)
    for s in stones:
        var pts: PackedVector2Array = s[0]
        pen.draw_colored_polygon(pts, FILL)
        # shaded underside, two hatch strokes, then the ink outline
        var c: Vector2 = s[1]
        var h: float = s[2]
        pen.draw_circle(c + Vector2(0, h * 0.4), h * 0.5, SHADE)
        for k in 2:
            var x = (k - 0.5) * h * 0.7
            pen.draw_line(c + Vector2(x - h * 0.25, h * 0.1), c + Vector2(x + h * 0.25, h * 0.6), INK, 1.2, true)
        var ring := pts.duplicate()
        ring.append(pts[0])
        pen.draw_polyline(ring, INK, 2.2, true)
    pen.flush()
