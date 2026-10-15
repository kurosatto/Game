# ItemPedestal.gd
extends Area2D

@export var item_id: String = "onion" # an id from data/Items.gd, or "heart", "key"
@export var is_shop_item: bool = false
@export var price: int = 0

const Items = preload("res://data/Items.gd")

var collected: bool = false
var start_y: float = -20.0
var elapsed: float = 0.0

func _ready():
    # Deferred: reacting can add/remove physics nodes, which Godot forbids mid physics step
    body_entered.connect(_on_body_entered, CONNECT_DEFERRED)
    start_y = $ItemSprite.position.y
    setup_visuals()

func setup_visuals():
    var light = get_node_or_null("PointLight2D")
    var aura = get_node_or_null("AuraParticles")
    
    if item_id == "":
        $ItemSprite.visible = false
        $PriceLabel.visible = false
        if aura:
            aura.emitting = false
        if light:
            light.energy = 0.3
            light.color = Color(0.2, 0.4, 0.6)
        return
        
    if aura:
        aura.emitting = true
    if light:
        if is_shop_item:
            light.color = Color(1.0, 0.85, 0.25)
            light.energy = 1.3
            if aura:
                aura.color = Color(1.0, 0.9, 0.3, 0.7)
        else:
            light.color = Color(0.0, 0.95, 1.0)
            light.energy = 1.4
            if aura:
                aura.color = Color(0.1, 1.0, 0.9, 0.7)
        
    var tex_path = "res://assets/ui/icons/item_%s.png" % item_id
    if item_id == "heart":
        tex_path = "res://assets/pickup_heart.png"
    elif item_id == "key":
        tex_path = "res://assets/pickup_key.png"
    elif not ResourceLoader.exists(tex_path):
        tex_path = "res://assets/item_onion.png"
    $ItemSprite.texture = load(tex_path)
    # Item icons are drawn at 96 px; pickups are 64 px sprites
    $ItemSprite.scale = Vector2.ONE * (0.85 if tex_path.contains("/icons/") else 1.0)
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
    if not is_instance_valid(body):
        return
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
    else:
        player.apply_item_upgrade(item_id)

func get_item_name(id: String) -> String:
    match id:
        "heart": return "Vitality Biomass"
        "key": return "Enzymatic Key"
    var it = Items.get_item(id)
    return it.get("name", "Unknown Mutation")

func get_item_description(id: String) -> String:
    match id:
        "heart": return "Restores 1 Vitality container"
        "key": return "+1 Enzymatic Key"
    var it = Items.get_item(id)
    if it.is_empty():
        return ""
    return it.effect + "\n" + it.fact
