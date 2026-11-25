# LevelGenerator.gd
extends RefCounted

enum RoomType {
    START,
    NORMAL,
    TREASURE,
    BOSS,
    SHOP,
    SEEP
}

class RoomData:
    var grid_pos: Vector2i
    var type: int # RoomType
    var connections: Dictionary = {} # Vector2i (dir) -> Vector2i (neighbor_pos)
    var cleared: bool = false
    var visited: bool = false
    
    # State Persistence across re-entries
    var has_initialized_contents: bool = false
    var saved_pickups: Array = [] # [{ "type": String, "pos": Vector2 }]
    var treasure_item_id: String = "" # "" if collected
    var seep_used: bool = false # SEEP room: its minerals taken
    var layout_idx: int = -1
    var hazards: Array = [] # Room.spawn_hazards: [{pos, size, seed}], rolled on first visit
    var hazards_rolled: bool = false
    var covers: Array = [] # Room.spawn_covers: patches of growth to hide in [{pos, size, seed}]
    var covers_rolled: bool = false
    var waves_left: int = 0 # Room.start_wave: animals still to come in through the doors # which RoomLayouts normal layout this room uses
    var clutch_pos: Vector2 = Vector2.INF # where you laid your clutch (Main.lay_clutch)
    var clutch_hatched: bool = false
    var exuviae: Array = [] # shed skins: [{pos, rot, form, parts, eaten}] (Main.add_exuvia)
    var lair: String = "" # a secret lair's boss (data/Endgame.gd LAIRS), "" if none
    var special: String = "" # data/SpecialRooms.gd kind, run by rooms/SpecialRoom.gd
    var special_state: Dictionary = {} # what happened there, kept for revisits
    var shop_inventory: Array = [] # [{ "item_id": String, "price": int, "pos": Vector2, "bought": bool }]

# FOSSIL GAUNTLET (data/Endgame.gd): a start room and the boss room above it
static func generate_gauntlet_level() -> Dictionary:
    var rooms: Dictionary = {}
    var start = RoomData.new()
    start.grid_pos = Vector2i(4, 4)
    start.type = RoomType.START
    var boss = RoomData.new()
    boss.grid_pos = Vector2i(4, 3)
    boss.type = RoomType.BOSS
    start.connections[Vector2i.UP] = boss.grid_pos
    boss.connections[Vector2i.DOWN] = start.grid_pos
    rooms[start.grid_pos] = start
    rooms[boss.grid_pos] = boss
    return rooms

# avoid: special room kinds already met this run, dealt last
static func generate_level(floor_number: int = 1, avoid: Array = []) -> Dictionary:
    # Returns a dictionary of Vector2i -> RoomData
    var min_rooms = max(7, 6 + floor_number * 2)
    var max_rooms = min_rooms + 2
    var rooms: Dictionary = {}
    var queue: Array = []
    var leaves: Array = []
    var start_pos = Vector2i(4, 4)
    
    var is_in_bounds = func(pos: Vector2i) -> bool:
        return pos.x >= 0 and pos.x < 9 and pos.y >= 0 and pos.y < 9
    
    var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    
    var attempts = 0
    var best_rooms: Dictionary = {}
    var best_leaves: Array = []
    
    while attempts < 150:
        attempts += 1
        rooms.clear()
        queue.clear()
        
        # Create start room
        var start_room = RoomData.new()
        start_room.grid_pos = start_pos
        start_room.type = RoomType.START
        start_room.cleared = true
        start_room.visited = true
        start_room.has_initialized_contents = true
        rooms[start_pos] = start_room
        queue.append(start_pos)
        
        while queue.size() > 0 and rooms.size() < max_rooms:
            var curr = queue.pop_front()
            var dirs = directions.duplicate()
            dirs.shuffle()
            
            for d in dirs:
                var next_pos = curr + d
                if not is_in_bounds.call(next_pos):
                    continue
                if rooms.has(next_pos):
                    continue
                
                var neighbor_count = 0
                for check_dir in directions:
                    if rooms.has(next_pos + check_dir):
                        neighbor_count += 1
                
                # Keep branching structure (Isaac-like)
                if neighbor_count > 1 and randf() > 0.12:
                    continue
                
                if randf() < 0.65 or rooms.size() < 4:
                    var new_room = RoomData.new()
                    new_room.grid_pos = next_pos
                    new_room.type = RoomType.NORMAL
                    rooms[next_pos] = new_room
                    queue.append(next_pos)
                    
                    if rooms.size() >= max_rooms:
                        break
        
        # Connect rooms to evaluate topology
        for pos in rooms:
            var r = rooms[pos]
            r.connections.clear()
            for d in directions:
                var neighbor_pos = pos + d
                if rooms.has(neighbor_pos):
                    r.connections[d] = neighbor_pos
        
        # Find true leaf rooms (degree == 1, not start room)
        leaves.clear()
        for pos in rooms:
            if pos == start_pos:
                continue
            var r = rooms[pos]
            if r.connections.size() == 1:
                leaves.append(r)
                
        if leaves.size() > best_leaves.size():
            best_rooms = rooms.duplicate()
            best_leaves = leaves.duplicate()
            
        # Guarantee at least min_rooms AND at least 3 true dead-end leaves
        if rooms.size() >= min_rooms and leaves.size() >= 3:
            break
            
    # Fallback to best configuration if needed
    if rooms.size() < min_rooms or leaves.size() < 3:
        if best_rooms.size() >= 5 and best_leaves.size() > 0:
            rooms = best_rooms
            leaves = best_leaves

    # Ensure connections are finalized
    for pos in rooms:
        var r = rooms[pos]
        r.connections.clear()
        for d in directions:
            var neighbor_pos = pos + d
            if rooms.has(neighbor_pos):
                r.connections[d] = neighbor_pos

    # Re-evaluate leaves
    leaves.clear()
    for pos in rooms:
        if pos == start_pos:
            continue
        var r = rooms[pos]
        if r.connections.size() == 1:
            leaves.append(r)

    # Sort leaves strictly by distance from start (furthest first)
    leaves.sort_custom(func(a, b):
        var dist_a = abs(a.grid_pos.x - start_pos.x) + abs(a.grid_pos.y - start_pos.y)
        var dist_b = abs(b.grid_pos.x - start_pos.x) + abs(b.grid_pos.y - start_pos.y)
        return dist_a > dist_b
    )

    # Furthest leaf is GUARANTEED to be the BOSS room (dead end, never behind locked rooms)
    if leaves.size() > 0:
        leaves[0].type = RoomType.BOSS

    # Second leaf is TREASURE room (dead end)
    if leaves.size() > 1:
        leaves[1].type = RoomType.TREASURE

    # Third dead end is a mineral seep (MineralSeep.gd): a heal and elements
    if leaves.size() > 2:
        leaves[2].type = RoomType.SEEP

    # A few side rooms become special rooms (data/SpecialRooms.gd): the
    # remaining dead ends first, then other fight rooms, never one next to
    # the start. Kinds not met yet this run come first.
    var specials = preload("res://data/SpecialRooms.gd")
    var kinds: Array = specials.kinds_for(floor_number)
    kinds.shuffle()
    kinds.sort_custom(func(a, b): return int(a in avoid) < int(b in avoid))
    var spots: Array = []
    for r in leaves:
        if r.type == RoomType.NORMAL:
            spots.append(r)
    var others: Array = []
    for pos in rooms:
        var r = rooms[pos]
        if r.type == RoomType.NORMAL and not r in spots and (pos - start_pos).length_squared() > 1:
            others.append(r)
    others.shuffle()
    spots.append_array(others)
    # A pitch-dark room leads the deal on every floor, so the senses are
    # always tested (data/SpecialRooms.gd "dark")
    kinds.erase("dark")
    kinds.push_front("dark")
    # kuro's favourite, a swarm of prey scattering from you: one every floor
    if "frenzy" in kinds:
        kinds.erase("frenzy")
        kinds.insert(1, "frenzy")
    for i in mini(specials.count_for(floor_number) + 1, spots.size()):
        spots[i].special = kinds[i % kinds.size()]
    # Main menu SENSE TEST: every other fight room is dark too
    # (looked up at run time: tool scripts preload this before autoloads exist)
    var settings = Engine.get_main_loop().root.get_node_or_null("SettingsManager")
    if settings and settings.dark_rooms_all:
        for pos in rooms:
            var r = rooms[pos]
            if r.type == RoomType.NORMAL and r.special == "" and pos != start_pos:
                r.special = "dark"

    # Deal the fight-room layouts like a shuffled deck, so a floor doesn't
    # repeat one until it has used them all and runs don't always open alike
    var deck: Array = []
    var layout_count = preload("res://RoomLayouts.gd").get_normal_layouts().size()
    for pos in rooms:
        if rooms[pos].type == RoomType.NORMAL:
            if deck.is_empty():
                deck = range(layout_count)
                deck.shuffle()
            rooms[pos].layout_idx = deck.pop_back()

    # A floor with a locked treasure room hides exactly one key, in one
    # random fight room (never the start, boss, seep or the treasure room
    # itself). The treasure room is a dead end, so every other room, the
    # key's included, can be reached without it. Room.gd finds it a clear
    # spot on the first visit, so you find it by walking the floor.
    var has_treasure = false
    var key_rooms: Array = []
    for pos in rooms:
        var r = rooms[pos]
        if r.type == RoomType.TREASURE:
            has_treasure = true
        elif r.type == RoomType.NORMAL:
            key_rooms.append(r)
    if has_treasure and not key_rooms.is_empty():
        var key_room = key_rooms[randi() % key_rooms.size()]
        key_room.saved_pickups.append({
            "type": "key",
            "pos": Vector2(randf_range(400, 1520), randf_range(300, 780)),
            "place": true # Room.gd moves it off any rock on the first visit
        })

    return rooms
