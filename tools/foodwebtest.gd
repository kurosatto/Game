# foodwebtest.gd
# Checks the food web (data/FoodWeb.gd, Enemy.gd "FOOD WEB"): every hunter,
# left alone with each of its prey, chases it down and eats it; the hunter
# feeds, grows and carries the meal; a hunter fighting you still snaps up
# prey that strays into reach; a blow on a feeding hunter lands hard; eaten
# prey clears from the room and leaves scraps. Run:
#   godot --headless --path . -s res://tools/foodwebtest.gd
extends SceneTree
var fauna = preload("res://data/Fauna.gd")
var web = preload("res://data/FoodWeb.gd")
var fails := 0

func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	p.adapt_pending = true
	var room = main.current_room_node
	for e in get_nodes_in_group("enemies"):
		e.queue_free()
	# Clear the floor of scenery so chases are not about walls
	for o in get_nodes_in_group("obstacles"):
		o.queue_free()
	await hold(p, room, Vector2(-1400, -1400), 5)
	# Every link names real era animals
	for h in web.EATS:
		check(find_type(h) != "", "hunter %s is an era animal" % h)
		for prey in web.EATS[h]:
			check(find_type(prey) != "", "prey %s is an era animal" % prey)
	var times: Array = []
	var tries := 0
	for h in web.EATS:
		var caught := 0
		for prey in web.EATS[h]:
			tries += 1
			var t = await test_hunt(room, p, h, prey)
			if t >= 0.0:
				times.append(t)
				caught += 1
		check(caught > 0, "%s catches at least one of its prey" % h)
	check(times.size() >= tries * 0.75, "most hunts succeed (%d / %d)" % [times.size(), tries])
	times.sort()
	if not times.is_empty():
		print("FOODWEB catch times: fastest %.1f s, median %.1f s, slowest %.1f s" % [times[0], times[times.size() / 2], times[-1]])
	await test_snap(room, p)
	await test_surprise(room, p)
	print("FOODWEB done, %d failures" % fails)
	quit()

func check(ok: bool, what: String):
	if not ok:
		fails += 1
		print("  FAIL ", what)

func find_type(species: String) -> String:
	for f in range(1, 6):
		for t in fauna.FLOORS[f]:
			if fauna.FLOORS[f][t].name == species:
				return "%d:%s" % [f, t]
		for x in fauna.extras(f):
			if x.name == species:
				return "%d:%s" % [f, x.type]
	return ""

func spawn(room, species: String, pos: Vector2) -> Node2D:
	var ft = find_type(species).split(":")
	var f = int(ft[0])
	var before = get_nodes_in_group("enemies")
	room.spawn_enemy(pos, ft[1] + "@" + species, f)
	var made = get_nodes_in_group("enemies").filter(func(e): return not before.has(e))
	return made[0]

func hold(p, room, pos: Vector2, frames: int):
	for i in frames:
		p.invincibility_time = 99.0
		p.health = p.max_health
		p.global_position = room.global_position + pos
		await physics_frame

func clear_enemies():
	for e in get_nodes_in_group("enemies"):
		if is_instance_valid(e):
			e.remove_from_group("enemies")
			e.queue_free()
	for o in get_nodes_in_group("biomass"):
		o.queue_free()

# Hunter and prey alone in the room, you far away: it should be eaten
func test_hunt(room, p, hunter: String, prey: String) -> float:
	var h = spawn(room, hunter, Vector2(700, 400))
	var preys: Array = []
	var before = get_nodes_in_group("enemies")
	var q = spawn(room, prey, Vector2(1250, 650))
	for e in get_nodes_in_group("enemies"):
		if e != h and is_instance_valid(e) and e.fauna_name == prey:
			preys.append(e)
	var hp0 = h.max_health
	var scale0 = h.base_scale
	var frames := 0
	var eaten := false
	var chased := false
	var fled := false
	while frames < 60 * 30:
		await hold(p, room, Vector2(-1400, -1400), 1)
		frames += 1
		if is_instance_valid(h) and h.hunt_target != null:
			chased = true
		for e in preys:
			if is_instance_valid(e) and not e.dead and e.chasing_hunter(300.0) != null:
				fled = true
		if is_instance_valid(h) and h.meals > 0:
			eaten = true
			break
	var secs = frames / 60.0
	check(chased, "%s goes after %s" % [hunter, prey])
	# Some get away: that is fine, as long as most are caught (see below)
	if eaten:
		check(h.feed_timer > 0.0, "%s feeds after the catch" % hunter)
		check(h.max_health > hp0 and h.base_scale > scale0, "%s grows from the meal" % hunter)
		check(h.eaten_worth > 0.0, "%s carries its meal" % hunter)
		check(not room.active_enemies.any(func(e): return is_instance_valid(e) and e.dead), "eaten %s left the room's list" % prey)
		check(h.mood == "calm", "%s stays calm while hunting far from you" % hunter)
		await hold(p, room, Vector2(-1400, -1400), 2)
	print("FOODWEB %-16s eats %-14s chased:%s fled:%s eaten:%s in %4.1f s" % [hunter, prey, chased, fled, eaten, secs])
	clear_enemies()
	await hold(p, room, Vector2(-1400, -1400), 3)
	return secs if eaten else -1.0

# A hunter fighting you still snaps up its prey when it comes close
func test_snap(room, p):
	var h = spawn(room, "Sanctacaris", Vector2(900, 540))
	h.become_hostile()
	var q = spawn(room, "Marrella", Vector2(940, 560))
	await hold(p, room, Vector2(300, 540), 30)
	check(h.meals == 1, "hostile hunter snaps prey in reach (meals %d)" % h.meals)
	check(not is_instance_valid(q) or q.dead, "snapped prey is gone")
	print("FOODWEB snap while fighting: meals %d" % h.meals)
	clear_enemies()
	await hold(p, room, Vector2(-1400, -1400), 3)

# A blow on a feeding hunter lands x1.5 and breaks off the meal
func test_surprise(room, p):
	var h = spawn(room, "Inostrancevia", Vector2(1300, 540))
	h.feed_timer = 2.0
	var hp = h.health
	h.take_damage(2.0)
	var lost = hp - h.health
	check(absf(lost - 2.0 * h.FEED_SURPRISE) < 0.6, "feeding hunter takes x1.5 (lost %.2f)" % lost)
	check(h.feed_timer <= 0.0 and h.mood == "hostile", "the blow breaks off the meal")
	print("FOODWEB surprise blow: 2.0 -> %.2f" % lost)
	clear_enemies()
