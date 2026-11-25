# perftest.gd
# Frame-time check: on each floor it walks into the busiest fight room and
# the boss room, keeps the player alive and still, and reports the average
# and worst frame time with the script process / physics times. Not part of
# the game; run it with (rendering included):
#   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 -s res://tools/perftest.gd
# or headless for script cost only:
#   godot --headless --path . -s res://tools/perftest.gd
# Set PERF_ABLATE=1 to also time each system switched off in turn.
extends SceneTree

var main: Node
var last_us := 0
var samples: Array = []
var sampling := false
var t_proc0 := 0
var t_phys0 := 0
var proc_us := 0
var phys_us := 0

class Stamp extends Node:
	var cb: Callable
	func _process(_d): cb.call(0)
	func _physics_process(_d): cb.call(1)

func _initialize():
	seed(int(OS.get_environment("PERF_SEED")) if OS.has_environment("PERF_SEED") else 1234)
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	# Stamps at the very start and end of each frame's process and physics
	var first = Stamp.new()
	first.process_priority = -100000
	first.process_physics_priority = -100000
	first.process_mode = Node.PROCESS_MODE_ALWAYS
	first.cb = func(k): if k == 0: t_proc0 = Time.get_ticks_usec() else: t_phys0 = Time.get_ticks_usec()
	var last = Stamp.new()
	last.process_priority = 100000
	last.process_physics_priority = 100000
	last.process_mode = Node.PROCESS_MODE_ALWAYS
	last.cb = func(k): if k == 0: proc_us = Time.get_ticks_usec() - t_proc0 else: phys_us += Time.get_ticks_usec() - t_phys0
	root.add_child.call_deferred(first)
	root.add_child.call_deferred(last)
	run()

func _process(_delta: float) -> bool:
	var now = Time.get_ticks_usec()
	if sampling and last_us > 0:
		samples.append({
			"frame": (now - last_us) / 1000.0,
			"proc": proc_us / 1000.0,
			"phys": phys_us / 1000.0,
			"rcpu": RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid()) + RenderingServer.get_frame_setup_time_cpu(),
			"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		})
	last_us = now
	phys_us = 0
	return false

func wait(n: int):
	for i in n:
		await process_frame

func keep_alive():
	var p = main.player
	p.max_health = max(p.max_health, 6)
	p.health = p.max_health
	p.invincibility_time = 999.0

func measure(label: String, frames: int = 240) -> Dictionary:
	if OS.has_environment("PERF_FRAMES"):
		frames = int(OS.get_environment("PERF_FRAMES"))
	samples = []
	sampling = true
	for i in frames:
		keep_alive()
		await process_frame
	sampling = false
	var s = {"frame": 0.0, "proc": 0.0, "phys": 0.0, "rcpu": 0.0, "draws": 0.0}
	var worst := 0.0
	var sorted: Array = []
	for x in samples:
		for k in s:
			s[k] += x[k]
		worst = max(worst, x.frame)
		sorted.append(x.frame)
	for k in s:
		s[k] /= max(1, samples.size())
	sorted.sort()
	var p95 = sorted[int(sorted.size() * 0.95)] if not sorted.is_empty() else 0.0
	print("PERF %-34s frame %6.2f ms (p95 %6.2f, worst %6.2f) | process %5.2f | physics %5.2f | render cpu %5.2f | draws %4d | nodes %d | enemies %d" % [
		label, s.frame, p95, worst, s.proc, s.phys, s.rcpu, int(s.draws), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), get_nodes_in_group("enemies").size()])
	s["p95"] = p95
	return s

func busiest_room(type: int) -> Vector2i:
	var best = Vector2i(4, 4)
	var best_n = -1
	for pos in main.dungeon_rooms:
		var r = main.dungeon_rooms[pos]
		if r.type != type:
			continue
		var n = r.get("enemies", []).size() if r.get("enemies") is Array else 0
		if r.special == "" and n >= best_n:
			best_n = n
			best = pos
	return best

func enter(pos: Vector2i):
	main.current_room_pos = pos
	main.load_room(pos)
	main.player.global_position = Vector2(960, 900)
	main.player.reset_physics_interpolation()
	await wait(90)

func run():
	await wait(30)
	var ablate = OS.get_environment("PERF_ABLATE") == "1"
	var totals := {"frame": 0.0, "proc": 0.0, "phys": 0.0, "rcpu": 0.0, "n": 0}
	var last_floor = int(OS.get_environment("PERF_FLOORS")) if OS.has_environment("PERF_FLOORS") else 5
	for f in range(1, last_floor + 1):
		if f > 1:
			main.floor_number = f
			main.generate_floor()
			await wait(30)
		for kind in [["fight", 1], ["boss", 3]]:
			await enter(busiest_room(kind[1]))
			var s = await measure("floor %d %s" % [f, kind[0]])
			for k in ["frame", "proc", "phys", "rcpu"]:
				totals[k] += s[k]
			totals.n += 1
			if ablate and kind[0] == "fight":
				await ablation(f)
	for k in ["frame", "proc", "phys", "rcpu"]:
		totals[k] /= totals.n
	print("PERF AVERAGE frame %.2f ms | process %.2f | physics %.2f | render cpu %.2f" % [totals.frame, totals.proc, totals.phys, totals.rcpu])
	quit(0)

# Switch one system off at a time to see what it costs
func ablation(f: int):
	var groups = {
		"enemies": func(): return get_nodes_in_group("enemies"),
		"obstacles": func(): return main.current_room_node.find_children("*", "StaticBody2D", true, false),
		"player body": func(): return main.player.find_children("*", "Node2D", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("PlayerBody.gd")),
		"hud": func(): return [main.hud],
		"2D lights": func(): return main.find_children("*", "PointLight2D", true, false),
		"scenery shaders": func():
			var out = []
			for o in main.current_room_node.find_children("*", "StaticBody2D", true, false):
				for c in o.get_children():
					if c is CanvasItem and c.material:
						out.append(c)
			return out,
		"fog+ink": func(): return main.get_tree().get_nodes_in_group("vision_fog") + main.find_children("*", "CanvasLayer", true, false).filter(func(n): return n.get_script() != null and n.get_script().resource_path.ends_with("VisionFog.gd")),
	}
	for name in groups:
		var nodes: Array = groups[name].call()
		var hidden: Array = []
		var mats := {}
		for n in nodes:
			if name == "scenery shaders":
				mats[n] = n.material
				n.material = null
				continue
			n.process_mode = Node.PROCESS_MODE_DISABLED
			if (n is CanvasItem or n is CanvasLayer) and n.visible:
				n.visible = false
				hidden.append(n)
		await wait(20)
		await measure("floor %d fight without %s (%d)" % [f, name, nodes.size()], 120)
		for n in nodes:
			if is_instance_valid(n):
				n.process_mode = Node.PROCESS_MODE_INHERIT
		for n in hidden:
			if is_instance_valid(n):
				n.visible = true
		for n in mats:
			if is_instance_valid(n):
				n.material = mats[n]
		await wait(20)
