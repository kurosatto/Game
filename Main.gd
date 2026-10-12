# Main.gd
extends Node2D

@onready var hud = $HUD
@onready var player = $Player
@onready var camera = $Camera2D
@onready var transition_rect = $TransitionLayer/ColorRect

var level_gen = preload("res://LevelGenerator.gd")
var room_scene = preload("res://Room.tscn")

var floor_number: int = 1
var dungeon_rooms: Dictionary = {}
var current_room_pos: Vector2i = Vector2i(4, 4)
var current_room_node = null
var is_transitioning: bool = false

var camera_shake_amount: float = 0.0

func _ready():
    add_to_group("main")
    setup_inputs()
    
    # Connect player signals to HUD
    player.health_changed.connect(hud.update_health)
    player.stats_changed.connect(hud.update_inventory)
    player.dna_changed.connect(hud.update_dna)
    player.player_died.connect(_on_player_died)
    
    SettingsManager.set_brightness(SettingsManager.brightness)
    
    start_new_game()

func setup_inputs():
    var inputs = {
        "move_left": [KEY_A, KEY_LEFT],
        "move_right": [KEY_D, KEY_RIGHT],
        "move_up": [KEY_W, KEY_UP],
        "move_down": [KEY_S, KEY_DOWN],
        "shoot_left": [KEY_J],
        "shoot_right": [KEY_L],
        "shoot_up": [KEY_I],
        "shoot_down": [KEY_K],
        "place_bomb": [KEY_E, KEY_SPACE]
    }
    for action in inputs:
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        for key in inputs[action]:
            var ev = InputEventKey.new()
            ev.physical_keycode = key
            InputMap.action_add_event(action, ev)

func _process(delta: float):
    # Process camera shake
    if camera_shake_amount > 0:
        camera.offset = Vector2(
            randf_range(-camera_shake_amount, camera_shake_amount),
            randf_range(-camera_shake_amount, camera_shake_amount)
        )
        camera_shake_amount = move_toward(camera_shake_amount, 0.0, delta * 40.0)
    else:
        camera.offset = Vector2.ZERO
        
    # Check restart key
    if hud.game_over_screen.visible or hud.victory_screen.visible:
        if Input.is_key_pressed(KEY_R):
            get_tree().reload_current_scene()

func _input(event: InputEvent):
    # Tap anywhere to restart on touch screens (no R key on a phone)
    if event is InputEventScreenTouch and event.pressed:
        if hud.game_over_screen.visible or hud.victory_screen.visible:
            get_tree().reload_current_scene()

func shake_camera(amount: float):
    camera_shake_amount = amount

func start_new_game():
    floor_number = 1
    generate_floor()

func generate_floor():
    hud.update_floor(floor_number)
    
    dungeon_rooms = level_gen.generate_level(floor_number)
    current_room_pos = Vector2i(4, 4)
    
    # Position player at 1080p center
    player.global_position = Vector2(960, 540)
    player.velocity = Vector2.ZERO
    
    load_room(current_room_pos)
    hud.update_minimap(dungeon_rooms, current_room_pos)

func load_room(grid_pos: Vector2i):
    hud.hide_boss_health()
    
    if current_room_node:
        current_room_node.queue_free()
        
    var room_data = dungeon_rooms[grid_pos]
    room_data.visited = true
    
    current_room_node = room_scene.instantiate()
    current_room_node.position = Vector2.ZERO
    add_child(current_room_node)
    move_child(current_room_node, 0)
    
    current_room_node.setup_room(room_data, floor_number)
    current_room_node.room_transition_requested.connect(_on_room_transition_requested)
    
    camera.position = Vector2(960, 540)
    hud.update_minimap(dungeon_rooms, current_room_pos)

func get_room_type(grid_pos: Vector2i) -> int:
    if dungeon_rooms.has(grid_pos):
        return dungeon_rooms[grid_pos].type
    return -1

func is_room_visited(grid_pos: Vector2i) -> bool:
    if dungeon_rooms.has(grid_pos):
        return dungeon_rooms[grid_pos].visited
    return false

func register_boss(boss_node: Node):
    boss_node.boss_health_changed.connect(hud.show_boss_health)
    boss_node.enemy_died.connect(hud.hide_boss_health)

# -------------------------------------------------------------
# Smooth 1080p Sliding Camera Room Transition with Anti-Loop Lock
# -------------------------------------------------------------
func _on_room_transition_requested(direction: Vector2i):
    if is_transitioning or player.door_cooldown > 0:
        return
        
    var target_pos = current_room_pos + direction
    if not dungeon_rooms.has(target_pos):
        return
        
    is_transitioning = true
    player.set_physics_process(false)
    player.door_cooldown = 0.5
    
    # Delete active projectiles on room transition
    for tear in get_tree().get_nodes_in_group("tears"):
        tear.queue_free()
        
    # 1080p full screen offset
    var room_offset = Vector2(direction.x * 1920, direction.y * 1080)
    var next_room_data = dungeon_rooms[target_pos]
    next_room_data.visited = true
    
    var next_room_node = room_scene.instantiate()
    next_room_node.position = room_offset
    add_child(next_room_node)
    move_child(next_room_node, 0)
    next_room_node.setup_room(next_room_data, floor_number)
    
    # Safe entry position inside new room (safely away from door trigger area)
    var local_enter_pos = Vector2(960, 540)
    if direction == Vector2i.UP:
        local_enter_pos = Vector2(960, 840) # Spawn well above bottom door (y=988)
    elif direction == Vector2i.DOWN:
        local_enter_pos = Vector2(960, 240) # Spawn well below top door (y=92)
    elif direction == Vector2i.LEFT:
        local_enter_pos = Vector2(1660, 540) # Spawn well left of right door (x=1856)
    elif direction == Vector2i.RIGHT:
        local_enter_pos = Vector2(260, 540) # Spawn well right of left door (x=64)
        
    var target_player_world_pos = local_enter_pos + room_offset
    var target_cam_pos = Vector2(960, 540) + room_offset
    
    SoundManager.play_sfx("door_open", 1.1, -4.0)
    
    var tween = create_tween()
    tween.set_parallel(true)
    tween.tween_property(camera, "position", target_cam_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(player, "global_position", target_player_world_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    
    tween.chain().tween_callback(func():
        if current_room_node:
            current_room_node.queue_free()
            
        current_room_node = next_room_node
        current_room_node.position = Vector2.ZERO
        current_room_node.room_transition_requested.connect(_on_room_transition_requested)
        
        camera.position = Vector2(960, 540)
        player.global_position = local_enter_pos
        player.velocity = Vector2.ZERO
        player.door_cooldown = 0.4
        
        current_room_pos = target_pos
        hud.update_minimap(dungeon_rooms, current_room_pos)
        
        player.set_physics_process(true)
        is_transitioning = false
    )

func advance_floor():
    if floor_number >= 3:
        hud.show_victory()
        player.set_physics_process(false)
        return
        
    floor_number += 1
    
    transition_rect.visible = true
    transition_rect.color.a = 0.0
    player.set_physics_process(false)
    
    var tween = create_tween()
    tween.tween_property(transition_rect, "color:a", 1.0, 0.4)
    tween.tween_callback(func():
        for tear in get_tree().get_nodes_in_group("tears"):
            tear.queue_free()
        for bomb in get_tree().get_nodes_in_group("bombs"):
            bomb.queue_free()
        for pickup in get_tree().get_nodes_in_group("pickups"):
            pickup.queue_free()
            
        generate_floor()
    )
    tween.tween_property(transition_rect, "color:a", 0.0, 0.4)
    tween.tween_callback(func():
        transition_rect.visible = false
        player.set_physics_process(true)
    )

func display_item_banner(title: String, desc: String):
    hud.show_item_banner(title, desc)

func _on_player_died():
    hud.show_game_over()
