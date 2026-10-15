# itemshots.gd
# Screenshots of the treasure items: one on its pedestal, its pickup banner,
# and the pause screen listing finds. Needs a window (xvfb-run on Linux):
#   SHOT_DIR=<folder> godot --path . --resolution 1920x1080 -s res://tools/itemshots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	main.hud.item_banner.visible = false
	var p = main.player
	var room = main.current_room_node
	for e in room.active_enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	var ped = load("res://ItemPedestal.tscn").instantiate()
	ped.item_id = "kleptoplasty"
	ped.position = room.to_local(p.global_position) + Vector2(0, -150)
	room.add_child(ped)
	for i in 40: await process_frame
	await snap("pedestal")
	ped._on_body_entered(p)
	await snap("pickup_banner")
	for id in ["ink_sac", "decomposers", "headshield"]:
		p.apply_item_upgrade(id)
	for id in ["muscle", "toxins", "senses"]:
		p.grant_adaptation(id)
	main.hud.item_banner.visible = false
	main.hud.toggle_settings()
	await snap("pause_finds")
	main.hud._on_pause_tile_picked(main.hud.pause_adapt.get_child(2))
	await snap("pause_find_tapped")
	quit()
