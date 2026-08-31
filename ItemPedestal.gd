# ItemPedestal.gd
extends Area2D

@export var item_id: String = "onion" # "onion", "eye", "hormones", "cells", "heart", "key", "bomb"
@export var is_shop_item: bool = false
@export var price: int = 0

var collected: bool = false
var start_y: float = -20.0
var elapsed: float = 0.0

func _ready():
    body_entered.connect(_on_body_entered)
    start_y = $ItemSprite.position.y
    setup_visuals()

func setup_visuals():
    if item_id == "":
        $ItemSprite.visible = false
        $PriceLabel.visible = false
        return
        
    var tex_path = "res://assets/item_onion.png"
    if item_id == "eye":
        tex_path = "res://assets/item_eye.png"
    elif item_id == "hormones":
        tex_path = "res://assets/item_hormones.png"
    elif item_id == "cells":
        tex_path = "res://assets/item_cells.png"
    elif item_id == "heart":
        tex_path = "res://assets/pickup_heart.png"
    elif item_id == "key":
        tex_path = "res://assets/pickup_key.png"
    elif item_id == "bomb":
        tex_path = "res://assets/pickup_bomb.png"
        
    $ItemSprite.texture = load(tex_path)
    $ItemSprite.visible = true
    
    if is_shop_item and price > 0:
        $PriceLabel.text = str(price) + " DNA"
        $PriceLabel.visible = true
    else:
        $PriceLabel.visible = false

func _process(delta: float):
    if item_id == "" or collected:
        return
    elapsed += delta
    $ItemSprite.position.y = start_y + sin(elapsed * 4.0) * 4.0

func _on_body_entered(body: Node):
    if collected or item_id == "":
        return
        
    if body.is_in_group("player"):
        if is_shop_item:
            if (item_id == "heart") and body.health >= body.max_health:
                return
                
            if body.dna_biomass < price:
                return
            body.add_dna(-price)
            
        collected = true
        
        # Apply item upgrades
        apply_item_to_player(body)
        
        SoundManager.play_sfx("level_up", 1.2)
        
        # Display banner
        var main = get_tree().get_first_node_in_group("main")
        if main and main.has_method("display_item_banner"):
            main.display_item_banner(get_item_name(item_id), get_item_description(item_id))
            
        item_id = ""
        setup_visuals()

func apply_item_to_player(player):
    if item_id == "heart":
        player.heal(2)
    elif item_id == "key":
        player.add_key(1)
    elif item_id == "bomb":
        player.add_bomb(1)
    else:
        player.apply_item_upgrade(item_id)

func get_item_name(id: String) -> String:
    match id:
        "onion": return "Cytoplasmic Surge"
        "eye": return "Compound Ocelli"
        "hormones": return "Adrenal Mutagen"
        "cells": return "Cellular Duplication"
        "heart": return "Vitality Biomass"
        "key": return "Enzymatic Key"
        "bomb": return "Volatile Spore"
    return "Unknown Mutation"

func get_item_description(id: String) -> String:
    match id:
        "onion": return "Fluid rate up (faster fire rate)"
        "eye": return "Triple bio-plasma burst"
        "hormones": return "Damage + Movement speed up"
        "cells": return "+1 Vitality Container & Full Heal"
        "heart": return "Restores 1 Vitality container"
        "key": return "+1 Enzymatic Key"
        "bomb": return "+1 Volatile Spore"
    return ""
