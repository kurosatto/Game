# playtest.gd
# Headless smoke test: plays a whole run by teleporting the player through
# doors, killing every enemy, taking the boss evolution choice and the
# trapdoor, floor after floor. Not part of the game; run it with:
#   godot --headless --path . -s res://tools/playtest.gd
# and look for "PLAYTEST" lines and any ERROR / SCRIPT ERROR output.
extends SceneTree

const MAX_FRAMES := 60 * 60 * 30

var main: Node
var frames := 0
var failures := 0

func _initialize():
	main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	run()

func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		report("TIMEOUT after %d frames" % frames)
		failures += 1
		quit(1)
	return false

func report(msg: String):
	print("PLAYTEST: ", msg)

func wait(n: int):
	for i in n:
		await process_frame

func keep_player_alive():
	var p = main.player
	p.max_health = max(p.max_health, 6)
	p.health = p.max_health
	p.invincibility_time = 999.0
	p.keys = max(p.keys, 5)

func kill_enemies():
	for i in 10:
		var alive = get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
		if alive.is_empty():
			return
		for e in alive:
			e.take_damage(99999.0)
		await wait(10)

# Shortest door path between two grid cells
func find_path(from: Vector2i, to: Vector2i) -> Array:
	var prev := {from: from}
	var queue := [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			break
		for dir in main.dungeon_rooms[cur].connections:
			var nxt: Vector2i = main.dungeon_rooms[cur].connections[dir]
			if not prev.has(nxt):
				prev[nxt] = cur
				queue.append(nxt)
	var path := []
	var c := to
	while c != from:
		path.push_front(c)
		c = prev[c]
	return path

func step_to(target: Vector2i) -> bool:
	var cur: Vector2i = main.current_room_pos
	var dir: Vector2i = target - cur
	keep_player_alive()
	await kill_enemies()
	await wait(40)
	var door = null
	for d in get_nodes_in_group("doors"):
		if d.get_parent() == main.current_room_node and d.direction == dir:
			door = d
	if door == null:
		report("no door %s from %s" % [dir, cur])
		return false
	for attempt in 3:
		keep_player_alive()
		main.player.global_position = door.global_position
		for i in 120:
			await process_frame
			if main.current_room_pos == target and not main.is_transitioning:
				return true
		main.player.global_position = main.current_room_node.global_position + Vector2(960, 540)
		await wait(70)
	report("STUCK at %s trying door %s (open=%s locked=%s time_scale=%s transitioning=%s room=%s)" % [cur, dir, door.is_open, door.is_locked, Engine.time_scale, main.is_transitioning, main.current_room_pos])
	return false

func run():
	await wait(30)
	var floors_done := 0
	while true:
		var floor_num: int = main.floor_number
		var rooms: Dictionary = main.dungeon_rooms
		var boss_pos = null
		for pos in rooms:
			if rooms[pos].type == 3:
				boss_pos = pos
		report("floor %d: %d rooms" % [floor_num, rooms.size()])

		# Visit every room, then the boss
		var order: Array = rooms.keys().filter(func(p): return p != boss_pos)
		order.append(boss_pos)
		for target in order:
			if target == main.current_room_pos:
				continue
			for step in find_path(main.current_room_pos, target):
				if not await step_to(step):
					failures += 1
					finish()
					return

		keep_player_alive()
		await kill_enemies()
		await wait(60)
		var hud = main.hud
		if hud.evolution_modal and hud.evolution_modal.visible:
			hud._on_evolution_choice_clicked(floor_num, randi() % 2)
			await wait(30)
		if hud.victory_screen.visible:
			report("VICTORY after %d floors" % (floors_done + 1))
			finish()
			return
		var trapdoors = main.current_room_node.get_children().filter(func(c): return c is Area2D and c.get_child_count() > 0 and c.get_child(0) is Sprite2D and c.get_child(0).texture and c.get_child(0).texture.resource_path.ends_with("trapdoor.png"))
		if trapdoors.is_empty():
			report("no trapdoor after boss on floor %d" % floor_num)
			failures += 1
			finish()
			return
		keep_player_alive()
		main.player.global_position = trapdoors[0].global_position
		for i in 300:
			await process_frame
			if main.floor_number > floor_num or hud.victory_screen.visible:
				break
		if hud.victory_screen.visible:
			report("VICTORY after %d floors" % (floors_done + 1))
			finish()
			return
		if main.floor_number <= floor_num:
			report("trapdoor did not advance floor %d" % floor_num)
			failures += 1
			finish()
			return
		floors_done += 1
		await wait(60)

func finish():
	report("done, %d failures, %d frames" % [failures, frames])
	quit(1 if failures > 0 else 0)
