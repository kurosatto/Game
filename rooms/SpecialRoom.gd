# SpecialRoom.gd
# Runs one special room (data/SpecialRooms.gd) inside Room.gd: builds its
# feature, decides whether it starts as a fight or with open doors, and keeps
# what happened in room_data.special_state so a revisit looks the same.
extends Node2D

const SR = preload("res://data/SpecialRooms.gd")
const HitFX = preload("res://HitFX.gd")
const ROOMS = "res://rooms/"

var room: Node2D = null # Room.gd
var kind: String = ""
var floor_num: int = 1
var layout: Dictionary = {}
var state: Dictionary = {}
var player: Node2D = null
var time: float = 0.0

# ambush
var ambush_wait: float = 0.0
var ambush_armed: bool = false
# frenzy
var prey_left: int = 0

func begin(first: bool):
	state = room.room_data.special_state
	player = get_tree().get_first_node_in_group("player")
	match kind:
		"vent": _vent()
		"tar": _tar(first)
		"dig": _dig()
		"frenzy": _frenzy(first)
		"extinction": _extinction()
		"nest": _nest()
		"tide": _tide(first)
		"symbiont": _symbiont()
		"ambush": _ambush()
		"glow": _glow(first)
		"dark": fight(first)
	if first and kind != "ambush":
		introduce()

# The first meeting of each kind in a run says what it is and what to do;
# after that just the name
func introduce():
	var main = get_tree().get_first_node_in_group("main")
	if main == null or not main.get("hud"):
		return
	var key = "special_" + kind
	if main.has_meta(key):
		if player:
			player.popup_text(player.global_position + Vector2(0, -90), SR.title(kind, floor_num), Color(0.98, 0.82, 0.5))
		return
	main.set_meta(key, true)
	var how = SR.how(kind, floor_num)
	main.hud.show_item_banner(SR.title(kind, floor_num), SR.fact(kind, floor_num) + ("\n" + how if how != "" else ""), true, -1.0, how)

func peaceful():
	room.room_data.cleared = true
	for d in room.door_nodes:
		room.door_nodes[d].open_door()

func fight(first: bool, enemies: bool = true):
	if room.room_data.cleared and not first:
		for d in room.door_nodes:
			room.door_nodes[d].open_door()
		return false
	for d in room.door_nodes:
		room.door_nodes[d].close_door()
	if enemies:
		room.spawn_tactical_enemies(layout, floor_num)
	return true

# Properties are set before it enters the room, so its _ready sees them
func add_feature(script_name: String, props: Dictionary = {}) -> Node2D:
	var n = load(ROOMS + script_name).new()
	n.set("floor_num", floor_num)
	for k in props:
		n.set(k, props[k])
	room.add_child(n)
	return n

# A spot on open floor, away from the doors you come in by
func open_spot(near: Vector2, radius: float = 60.0) -> Vector2:
	return room.free_spot(near, radius)

# An era animal that isn't a foe: drawn and animated like the rest but out of
# the "enemies" group, with no body, moved by whoever owns it
static func make_puppet(parent: Node, f: int, species: String, type: String, pos: Vector2) -> Node2D:
	var e = preload("res://Enemy.tscn").instantiate()
	e.enemy_type = type
	e.species_name = species
	e.setup_enemy(f)
	e.position = pos
	e.collision_layer = 0
	e.collision_mask = 0
	parent.add_child(e)
	e.remove_from_group("enemies")
	e.set_physics_process(false)
	e.mood = "calm"
	return e

func _process(delta: float):
	time += delta
	if kind == "ambush":
		_ambush_watch(delta)

func on_cleared():
	match kind:
		"frenzy":
			if player:
				player.popup_text(player.global_position + Vector2(0, -90), "FEAST!", Color(0.98, 0.82, 0.5))

# ---- 1. Hydrothermal vent / hot spring ----
func _vent():
	peaceful()
	add_feature("Vent.gd", {"position": Vector2(960, 520),
		"heal_left": int(state.get("heal_left", preload("res://rooms/Vent.gd").HEAL_BUDGET)),
		"on_heal": func(left): state["heal_left"] = left})

# ---- 2. Mud or tar: everything is slowed; a trapped animal to free ----
func _tar(first: bool):
	fight(first)
	if not state.has("pools"):
		var pools: Array = [{"pos": open_spot(Vector2(960, 560), 110.0), "size": Vector2(230, 135)}]
		var area = room.interior_rect(170.0)
		for attempt in 40:
			if pools.size() >= 3:
				break
			var p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
			var ok = true
			for q in pools:
				if p.distance_to(q.pos) < 420.0:
					ok = false
			for door in [Vector2(960, 68), Vector2(960, 1012), Vector2(128 - room.side_margin, 540), Vector2(1792 + room.side_margin, 540)]:
				if p.distance_to(door) < 300.0:
					ok = false
			if ok:
				pools.append({"pos": p, "size": Vector2(randf_range(140, 190), randf_range(85, 110))})
		state["pools"] = pools
	for i in state.pools.size():
		var props = {"position": state.pools[i].pos, "size": state.pools[i].size, "seed_val": i * 97 + floor_num}
		if i == 0 and not state.get("freed", false):
			props["trapped_species"] = SR.TRAPPED[clampi(floor_num, 1, 5)]
			props["on_freed"] = func(): state["freed"] = true
		add_feature("MudPool.gd", props)

# ---- 3. Fossil bed: break the rock for a fact and a rare element ----
func _dig():
	peaceful()
	add_feature("FossilSlab.gd", {"position": Vector2(960, 520), "broken": state.get("dug", false),
		"on_broken": func(): state["dug"] = true})

# ---- 4. Feeding frenzy: a crowd of small, harmless prey ----
func _frenzy(first: bool):
	if not fight(first, false):
		return
	var info = SR.FRENZY[clampi(floor_num, 1, 5)]
	var sp = SR.species(floor_num, info.species)
	var ppos = player.global_position if player else Vector2(960, 540)
	var area = room.interior_rect(90.0)
	var placed := 0
	for attempt in 200:
		if placed >= info.count:
			break
		var p = Vector2(randf_range(area.position.x, area.end.x), randf_range(area.position.y, area.end.y))
		if p.distance_to(ppos) < 360.0 or not room.spot_is_free(p, 30.0):
			continue
		room.spawn_enemy(p, "skittish@" + info.species, floor_num)
		var e = room.active_enemies.back()
		# Small and slow enough to catch; a crowd of them is the meal
		e.speed *= 0.55
		e.max_health = 2.0 + floor_num * 0.6
		e.health = e.max_health
		e.worth_override = 1.6
		e.enemy_died.connect(_on_prey_eaten)
		placed += 1
	prey_left = placed
	if sp.is_empty():
		push_warning("frenzy: no species " + info.species)

func _on_prey_eaten():
	prey_left -= 1
	if player and prey_left > 0 and prey_left % 3 == 0:
		player.popup_text(player.global_position + Vector2(0, -70), "%d LEFT" % prey_left, Color(0.98, 0.76, 0.38))

# ---- 5. Mass extinction: loot, a countdown, then the room turns deadly ----
func _extinction():
	peaceful()
	add_feature("Extinction.gd", {"state": state, "room": room})

# ---- 6. Nest: a big meal, and then the parent ----
func _nest():
	peaceful()
	add_feature("Clutch.gd", {"position": Vector2(960, 540), "taken": state.get("taken", false), "on_taken": _on_clutch_taken})

func _on_clutch_taken():
	state["taken"] = true
	var info = SR.NESTS[clampi(floor_num, 2, 5)]
	SR.spill(room, Vector2(960, 540), preload("res://data/Biominerals.gd").fauna_elements(info.parent), 6.0, 8)
	if player and player.has_method("heal"):
		player.heal(2)
	# The parent comes in through the door farthest from you
	await get_tree().create_timer(0.7, false).timeout
	if not is_inside_tree() or player == null or player.health <= 0:
		return
	room.begin_fight()
	var spot = _far_door_spot()
	HitFX.pop(room, spot, Color(0.9, 0.75, 0.55), 40.0, 260.0, 0.5)
	SoundManager.play_sfx("boss_roar", 1.25, -6.0)
	room.spawn_enemy(spot, "%s@%s" % [info.type, info.parent], floor_num)
	var parent = room.active_enemies.back()
	parent.make_elder()
	parent.become_hostile()
	player.popup_text(player.global_position + Vector2(0, -90), "THE PARENT IS BACK!", Color(1.0, 0.6, 0.4))

func _far_door_spot() -> Vector2:
	var ppos = player.global_position if player else Vector2(960, 540)
	var inward = {Vector2i.UP: Vector2(0, 190), Vector2i.DOWN: Vector2(0, -190), Vector2i.LEFT: Vector2(190, 0), Vector2i.RIGHT: Vector2(-190, 0)}
	var best = Vector2(960, 300)
	var best_d = -1.0
	for d in room.door_nodes:
		var p = room.door_nodes[d].position + inward.get(d, Vector2.ZERO)
		if p.distance_to(ppos) > best_d:
			best_d = p.distance_to(ppos)
			best = p
	return room.free_spot(best)

# ---- 7. Tidal channel: the water rises and splits the room ----
func _tide(first: bool):
	var t = add_feature("TideChannel.gd", {"room": room})
	t.clear_obstacles()
	fight(first)

# ---- 8. Symbiont: a follower that hunts beside you for this era ----
func _symbiont():
	peaceful()
	if state.get("joined", false):
		return
	var c = preload("res://rooms/Companion.gd").new()
	c.floor_num = floor_num
	c.position = Vector2(960, 520)
	c.on_joined = func(): state["joined"] = true
	room.add_child(c)

# ---- 9. Predator ambush: a quiet room with an elder hiding in it ----
func _ambush():
	if state.get("sprung", false):
		fight(false, false)
		return
	peaceful()
	ambush_armed = true

func _ambush_watch(delta: float):
	if not ambush_armed or player == null or not is_instance_valid(player) or player.health <= 0:
		return
	ambush_wait += delta
	var inside = room.interior_rect(260.0).has_point(player.global_position)
	if ambush_wait < 1.2 or (not inside and ambush_wait < 3.5):
		return
	ambush_armed = false
	state["sprung"] = true
	_spring_ambush()

func _spring_ambush():
	var info = SR.AMBUSHERS[clampi(floor_num, 2, 5)]
	# It was hiding by the scenery farthest from you, or in a far corner
	var ppos = player.global_position
	var spot = Vector2.ZERO
	var best = -1.0
	for c in room.get_children():
		if c.is_in_group("obstacles") and c.position.distance_to(ppos) > best:
			best = c.position.distance_to(ppos)
			spot = c.position + (ppos - c.position).normalized() * 90.0
	if best < 420.0:
		var r = room.interior_rect(120.0)
		spot = Vector2(r.end.x if ppos.x < 960 else r.position.x, r.end.y if ppos.y < 540 else r.position.y)
	spot = room.free_spot(spot)
	room.begin_fight()
	room.wave_pending = true # holds the doors shut until it's out
	HitFX.pop(room, spot, Color(0.85, 0.7, 0.5), 36.0, 220.0, 0.45)
	SoundManager.play_sfx("enemy_lunge", 0.8, -2.0)
	player.popup_text(spot + Vector2(0, -70), "!", Color(1.0, 0.45, 0.3))
	await get_tree().create_timer(0.6, false).timeout
	room.wave_pending = false
	if not is_inside_tree() or player.health <= 0:
		return
	room.spawn_enemy(spot, "%s@%s" % [info.type, info.species], floor_num)
	var e = room.active_enemies.back()
	e.make_elder()
	e.become_hostile()
	if floor_num >= 4:
		room.spawn_enemy(room.free_spot(spot + Vector2(0, 140)), room.roll_enemy_type("fly", floor_num), floor_num)
		room.active_enemies.back().become_hostile()
	SoundManager.play_sfx("boss_roar", 1.4, -8.0)
	var main = get_tree().get_first_node_in_group("main")
	if main and main.get("hud"):
		var key = "special_ambush"
		var text = SR.fact("ambush", floor_num) if not main.has_meta(key) else "An elder %s was lying in wait." % info.species
		main.set_meta(key, true)
		main.hud.show_item_banner("AMBUSH!", text, true, 2.0, text if text.length() < 60 else "")

# ---- 10. Glowing cave: dark, lit by glowing animals ----
func _glow(first: bool):
	fight(first)
	var rng = RandomNumberGenerator.new()
	rng.seed = room.room_data.grid_pos.x * 131 + room.room_data.grid_pos.y * 17 + floor_num
	var area = room.interior_rect(120.0)
	var n = 9
	var spots: Array = []
	for attempt in 120:
		if spots.size() >= n:
			break
		var p = Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		var ok = room.spot_is_free(p, 40.0)
		for q in spots:
			if p.distance_to(q) < 300.0:
				ok = false
		if ok:
			spots.append(p)
	for i in spots.size():
		# Sea pens stay put; in the Ordovician comb jellies drift about too
		add_feature("GlowCritter.gd", {"position": spots[i], "drifter": floor_num >= 3 and i % 3 == 0, "seed_val": rng.randi()})
