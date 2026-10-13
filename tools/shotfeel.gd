# shotfeel.gd
# Renders a few frames of shooting and biting a crawler, for checking the
# muzzle flash, hit flash, sparks, health bar and kill pop (needs a window,
# not --headless). --fixed-fps keeps effects from finishing between frames
# on slow software rendering.
# Run: SHOT_DIR=<folder> godot --fixed-fps 60 --path . -s res://tools/shotfeel.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var p = main.player
	var prey = load("res://Enemy.tscn").instantiate()
	prey.enemy_type = "pacer"
	prey.position = p.position + Vector2(300, 0)
	main.current_room_node.add_child(prey)
	prey.setup_enemy(3)
	prey.speed = 0.0
	await physics_frame
	p.current_weapon = "vesicle"
	p.shoot_tear(Vector2.RIGHT)
	await physics_frame
	await snap("1_muzzle")
	for i in 60:
		await physics_frame
		if prey.hit_flash_timer > 0.15:
			break
	await snap("2_hit")
	for i in 6: await physics_frame
	await snap("3_after_hit")
	p.current_weapon = "engulf"
	prey.global_position = p.global_position + Vector2(70, 0)
	await physics_frame
	p.shoot_tear(Vector2.RIGHT)
	await snap("4_melee")
	prey.take_damage(9999.0)
	for i in 4: await process_frame
	await snap("5_kill")
	quit()
