# escapetest.gd
# Headless check of the escape moves that replace the dash for forms that
# can't dart (data/Lineages.gd ESCAPES): puts the player in each such form,
# presses the dash, and checks it stays put, turns untouchable and labels the
# button right. Not part of the game; run it with:
#   godot --headless --path . -s res://tools/escapetest.gd
extends SceneTree

var main: Node
var failures := 0

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	run()

func wait(n: int):
	for i in n:
		await process_frame

func check(ok: bool, msg: String):
	if not ok:
		failures += 1
	print("ESCAPETEST: ", "ok   " if ok else "FAIL ", msg)

func run():
	await wait(30)
	var lineages = preload("res://data/Lineages.gd")
	var p = main.player
	for path in lineages.TREE:
		var form: Dictionary = lineages.TREE[path]
		p.apply_form(form)
		p.dash_cooldown = 0.0
		p.invincibility_time = 0.0
		var start: Vector2 = p.global_position
		var style: String = lineages.get_escape(form)[0]
		p.perform_bio_dash()
		await wait(6)
		if style == "dart":
			check(p.dash_label() == "DASH" and p.global_position.distance_to(start) > 20.0, "%s dashes" % form.id)
		else:
			check(p.dash_label() == lineages.ESCAPE_STYLES[style].label, "%s button says %s" % [form.id, p.dash_label()])
			check(p.invincibility_time > 0.0, "%s untouchable during %s" % [form.id, style])
			if style != "ink":
				check(p.global_position.distance_to(start) < 1.0, "%s holds still" % form.id)
			check(p.max_dash_cooldown == lineages.ESCAPE_STYLES[style].cooldown, "%s recharge %.1fs" % [form.id, p.max_dash_cooldown])
		await wait(70)
		p.global_position = main.current_room_node.global_position + Vector2(960, 540)
		await wait(2)
	print("ESCAPETEST: done, %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
