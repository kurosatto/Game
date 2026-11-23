# bitesound.gd
# Records real game audio (Godot's movie writer mixes every bus exactly as a
# player hears it) while a biting form bites the air twice, then bites an
# animal three times. Run, then measure the audio track:
#   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 60 \
#     --write-movie /tmp/bite.avi -s res://tools/bitesound.gd
# FORM=<lineage id> picks another form (default jawed_fish).
extends SceneTree
func _initialize():
	for i in 5: await process_frame
	var main = load("res://Main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 30: await process_frame
	var sm = root.get_node("SoundManager")
	sm.audio_unlocked = true
	sm.play_music(sm.music_for_floor(1)) # play over real music, as in a run
	var player = main.player
	var lineages = load("res://data/Lineages.gd")
	var form = OS.get_environment("FORM") if OS.get_environment("FORM") != "" else "jawed_fish"
	for path in lineages.TREE:
		if lineages.TREE[path].id == form:
			player.apply_form(lineages.TREE[path])
	player.health = 99
	for e in get_nodes_in_group("enemies"): e.queue_free()
	for i in 60: await process_frame # 1 s: music only
	print("BITESOUND t=%.2f misses start, weapon %s" % [Time.get_ticks_msec() / 1000.0, player.current_weapon])
	for k in 2:
		player.shoot_cooldown = 0.0
		player.shoot_tear(Vector2.LEFT)
		for i in 60: await process_frame
	var prey = load("res://Enemy.tscn").instantiate()
	prey.enemy_type = "pacer"
	prey.position = player.global_position + Vector2(100, 0)
	main.current_room_node.add_child(prey)
	prey.setup_enemy(2)
	prey.speed = 0.0
	prey.health = 999.0
	for i in 10: await process_frame
	for k in 3:
		player.shoot_cooldown = 0.0
		player.shoot_tear(Vector2.RIGHT)
		for i in 60: await process_frame
	print("BITESOUND prey hp ", prey.health, " played ", sm.last_played.keys())
	quit()
