# drawcount.gd
# Draw calls each code-drawn form costs on its own (PlayerBody.gd). Run with:
#   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 320x180 -s res://tools/drawcount.gd
extends SceneTree
const PlayerBody = preload("res://PlayerBody.gd")

func _initialize():
	run()

func draws() -> int:
	for i in 3:
		await process_frame
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func run():
	var base = await draws()
	var total := 0
	var rows: Array = []
	var only = OS.get_environment("FORMS")
	for id in PlayerBody.FORMS:
		if only != "" and not id in only.split(","):
			continue
		var b = PlayerBody.new()
		b.preview = true
		b.preview_live = true
		b.position = Vector2(160, 90)
		b.set_form(id)
		root.add_child(b)
		var d = await draws() - base
		var t0 = Time.get_ticks_usec()
		var IB = load("res://InkBatch.gd")
		IB.prof_us = 0
		for i in 20:
			b.queue_redraw()
			await process_frame
		var us = (Time.get_ticks_usec() - t0) / 20
		var draw_us = IB.prof_us / 20
		b.set_process(false)
		await process_frame
		await process_frame
		t0 = Time.get_ticks_usec()
		for i in 20:
			await process_frame
		var still = (Time.get_ticks_usec() - t0) / 20
		print("FORM %-28s draws %4d  _draw %5d us  frame %6d us  (no redraw %6d us)" % [id, d, draw_us, us, still])
		rows.append([d, id, us])
		total += d
		b.queue_free()
		await process_frame
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		print("DRAWS %4d  %6d us/frame  %s" % [r[0], r[2], r[1]])
	print("DRAWS average %.1f over %d forms" % [float(total) / max(1, rows.size()), rows.size()])
	quit()
