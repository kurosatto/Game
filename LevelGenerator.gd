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

static func generate_level(floor_number: int = 1) -> Dictionary:
    # Returns a dictionary of Vector2i -> RoomData
    var max_rooms = 7 + floor_number * 2
    var rooms: Dictionary = {}
    var queue: Array = []
    var start_pos = Vector2i(4, 4)
    
    # Helper to check if a position is in grid bounds
    var is_in_bounds = func(pos: Vector2i) -> bool:
        return pos.x >= 0 and pos.x < 9 and pos.y >= 0 and pos.y < 9
    
    var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    
    var attempts = 0
    while attempts < 100:
        attempts += 1
        rooms.clear()
        queue.clear()
        
        # Create start room
        var start_room = RoomData.new()
        start_room.grid_pos = start_pos
        start_room.type = RoomType.START
        start_room.cleared = true
        start_room.visited = true
        rooms[start_pos] = start_room
        queue.append(start_pos)
        
        while queue.size() > 0 and rooms.size() < max_rooms:
            var curr = queue.pop_front()
            
            # Shuffle directions to add randomness
            var dirs = directions.duplicate()
            dirs.shuffle()
            
            for d in dirs:
                var next_pos = curr + d
                if not is_in_bounds.call(next_pos):
                    continue
                if rooms.has(next_pos):
                    continue
                
                # Count neighbors of the target position to prevent too many loops / clustering
                var neighbor_count = 0
                for check_dir in directions:
                    if rooms.has(next_pos + check_dir):
                        neighbor_count += 1
                
                # If the room has more than 1 neighbor, restrict spawning with a chance
                # to keep the layout branching (Isaac-like) rather than a solid block.
                if neighbor_count > 1 and randf() > 0.15:
                    continue
                
                # Chance to spawn a room
                if randf() < 0.65 or rooms.size() < 4:
                    var new_room = RoomData.new()
                    new_room.grid_pos = next_pos
                    new_room.type = RoomType.NORMAL
                    rooms[next_pos] = new_room
                    queue.append(next_pos)
                    
                    if rooms.size() >= max_rooms:
                        break
        
        # Check if we have enough rooms (minimum 5)
        if rooms.size() >= 5:
            break
    
    # Now connect the rooms
    for pos in rooms:
        var r = rooms[pos]
        for d in directions:
            var neighbor_pos = pos + d
            if rooms.has(neighbor_pos):
                r.connections[d] = neighbor_pos
    
    # Identify leaf rooms (rooms with only 1 neighbor)
    var leaves: Array = []
    for pos in rooms:
        if pos == start_pos:
            continue
        var r = rooms[pos]
        if r.connections.size() == 1:
            leaves.append(r)
    
    # If we don't have enough leaves, sort rooms by distance to start and use those
    if leaves.size() < 3:
        var all_rooms = rooms.values().filter(func(x): return x.grid_pos != start_pos)
        all_rooms.sort_custom(func(a, b):
            var dist_a = (a.grid_pos - start_pos).length_squared()
            var dist_b = (b.grid_pos - start_pos).length_squared()
            return dist_a > dist_b
        )
        leaves = all_rooms
    else:
        # Sort leaves by Manhattan distance to start room
        leaves.sort_custom(func(a, b):
            var dist_a = abs(a.grid_pos.x - start_pos.x) + abs(a.grid_pos.y - start_pos.y)
            var dist_b = abs(b.grid_pos.x - start_pos.x) + abs(b.grid_pos.y - start_pos.y)
            return dist_a > dist_b # Further rooms first
        )
    
    # Assign special room types
    # Furthest is Boss Room
    if leaves.size() > 0:
        leaves[0].type = RoomType.BOSS
    # Second furthest is Treasure Room
    if leaves.size() > 1:
        leaves[1].type = RoomType.TREASURE
    # Third furthest is Shop Room
    if leaves.size() > 2:
        leaves[2].type = RoomType.SHOP
    
    return rooms
