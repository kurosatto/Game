# MeleeSwing.gd
# Short-lived drawing of a melee attack, added as a child of the player and
# rotated so +x points along the aim. The style matches the weapon in
# data/Lineages.gd WEAPONS: jaws snap shut, pincers close, stings and
# tentacles thrust out and back, claws and tails sweep, spines burst outward.
extends Node2D

var style: String = "bite"
var reach: float = 120.0
var half_arc: float = 0.6
var color: Color = Color(0.0, 0.95, 1.0)
var duration: float = 0.18
var t: float = 0.0

func _ready():
    z_index = 2
    if style in ["arms", "tongue", "sting"]:
        duration = 0.24
    elif style == "smash":
        duration = 0.26

func _process(delta: float):
    t += delta / duration
    if t >= 1.0:
        queue_free()
        return
    queue_redraw()

func _draw():
    var fade = 1.0 - t
    var col = Color(min(color.r * 1.3 + 0.3, 1.0), min(color.g * 1.3 + 0.3, 1.0), min(color.b * 1.3 + 0.3, 1.0), 0.9 * fade)
    var white = Color(1, 1, 1, 0.85 * fade)
    match style:
        "bite", "rasp":
            draw_jaws(col, white, 0.7, 7.0, style == "rasp")
        "pincer":
            draw_jaws(col, white, 0.55, 10.0, false)
        "sting":
            draw_thrust(col, white, "sting")
        "arms":
            draw_thrust(col, white, "arms")
        "tongue":
            draw_thrust(Color(1.0, 0.45, 0.55, 0.95 * fade), white, "tongue")
        "spines":
            var n = 14
            var out = reach * ease_out(min(t * 1.6, 1.0))
            for i in n:
                var d = Vector2.RIGHT.rotated(TAU * i / n)
                draw_line(d * 26.0, d * out, col, 4.0)
                draw_circle(d * out, 3.0, white)
        "smash":
            var r = reach * (0.35 + 0.65 * ease_out(t))
            draw_circle(Vector2(reach * 0.75, 0), 26.0 * fade, white)
            draw_arc(Vector2(reach * 0.75, 0), r * 0.55, 0, TAU, 32, col, 5.0 * fade + 1.0)
            draw_arc(Vector2(reach * 0.75, 0), r * 0.3, 0, TAU, 24, white, 3.0)
        _:
            # claw, lash: a sweep across the arc, three rakes for claws
            var lines = 3 if style == "claw" else 1
            var width = 5.0 if style == "claw" else 9.0
            var sweep = ease_out(min(t * 1.7, 1.0))
            var a0 = -half_arc
            var a1 = -half_arc + 2.0 * half_arc * sweep
            for i in lines:
                var r = reach * (0.85 - 0.14 * i)
                draw_arc(Vector2.ZERO, r, a0, a1, 24, col if i > 0 else white, width)

# Two jaws (or pincer fingers) closing on the aim line
func draw_jaws(col: Color, white: Color, open_angle: float, width: float, rasp: bool):
    var close = ease_out(min(t * 2.2, 1.0))
    var a = open_angle * (1.0 - close) + 0.04
    var base = Vector2(26.0, 0)
    var length = reach - 26.0
    for side in [-1.0, 1.0]:
        var pts = PackedVector2Array()
        for i in 9:
            var k = i / 8.0
            # Jaws curve inward toward the tip
            var ang = side * a * (1.0 - k * 0.6) - side * 0.18 * k * k
            pts.append(base + Vector2(length * k, 0).rotated(ang))
        draw_polyline(pts, col, width)
        # Teeth along the inner edge
        for i in range(2, 8, 2 if rasp else 3):
            var p = pts[i]
            var inward = Vector2(0, -side * 9.0).rotated(side * a)
            draw_line(p, p + inward, white, 3.0)

# Something shooting out to full reach and back: a sting, a tongue or tentacles
func draw_thrust(col: Color, white: Color, kind: String):
    var ext = reach * sin(PI * min(t * 1.1, 1.0))
    if kind == "arms":
        for side in [-1.0, 0.0, 1.0]:
            var pts = PackedVector2Array()
            for i in 10:
                var k = i / 9.0
                pts.append(Vector2(ext * k, side * 14.0 * k + sin(k * 6.0 + t * 12.0) * 6.0))
            draw_polyline(pts, col, 5.0 - abs(side) * 1.5)
            draw_circle(pts[9], 4.0, white)
    elif kind == "tongue":
        draw_line(Vector2(18, 0), Vector2(ext, 0), col, 6.0)
        draw_circle(Vector2(ext, 0), 9.0, col)
    else:
        draw_line(Vector2(18, 0), Vector2(ext, 0), col, 5.0)
        var tip = Vector2(ext, 0)
        draw_colored_polygon(PackedVector2Array([tip + Vector2(14, 0), tip + Vector2(-6, 7), tip + Vector2(-6, -7)]), white)

func ease_out(x: float) -> float:
    return 1.0 - (1.0 - x) * (1.0 - x)
