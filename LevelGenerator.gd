# LevelGenerator.gd
extends RefCounted

enum RoomType {
    START,
    NORMAL,
    TREASURE,
    BOSS,
    SHOP
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
    var shop_inventory: Array = [] # [{ "item_id": String, "price": int, "pos": Vector2, "bought": bool }]

static func generate_level(floor_number: int = 1) -> Dictionary:
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

    # Third leaf is SHOP room (dead end)
    if leaves.size() > 2:
        leaves[2].type = RoomType.SHOP

    # Every floor has a guaranteed key in a normal room, so the locked
    # treasure room and shop can always be opened
    if true:
        for pos in rooms:
            var r = rooms[pos]
            if r.type == RoomType.NORMAL:
                r.saved_pickups.append({
                    "type": "key",
                    "pos": Vector2(960, 540)
                })
                break

    return rooms
