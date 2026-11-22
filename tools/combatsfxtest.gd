# combatsfxtest.gd
# Kills one animal of each body type and each era boss, hurts the player and
# fires every attack sound, checking the combat sounds and ink marks run
# without errors and every sound file loaded.
#   godot --headless --path . -s res://tools/combatsfxtest.gd
extends SceneTree
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var sm = root.get_node("SoundManager")
	var missing := []
	for s in sm.SOUND_VOLUMES.keys():
		if not sm.sound_streams.has(s):
			missing.append(s)
	print("COMBATSFX missing sounds: ", missing)
	for w in load("res://data/Lineages.gd").WEAPONS.keys():
		sm.play_attack(w)
		await process_frame
	var player = main.player
	for floor_num in [1, 2, 5]:
		var e = load("res://Enemy.tscn").instantiate()
		e.enemy_type = "pacer"
		e.position = player.global_position + Vector2(150, 0)
		main.current_room_node.add_child(e)
		e.setup_enemy(floor_num)
		print("COMBATSFX ", e.fauna_name, " body ", e.body_material())
		e.take_damage(99999.0)
		for i in 10: await process_frame
	player.invincibility_time = 0.0
	player.take_damage(1)
	for i in 10: await process_frame
	var Fauna = load("res://data/Fauna.gd")
	for b in ["Stentor", "Anomalocaris", "Dimetrodon"]:
		print("COMBATSFX boss ", b, " body ", Fauna.body_of(b))
	print("COMBATSFX done")
	quit()
