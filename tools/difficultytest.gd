# difficultytest.gd
# Prints what data/Difficulty.gd does in every era, then spawns a few animals
# per era to check the numbers really reach them.
#   godot --headless --path . -s res://tools/difficultytest.gd
extends SceneTree

const Difficulty = preload("res://data/Difficulty.gd")

func _initialize():
	run()

func run():
	print("era  animal_hp  speed  shot_delay  animals/room  wave  boss_hp")
	for f in range(1, 6):
		print("%d    x%.2f      x%.2f  x%.2f       %d-%d          %d%%   x%.2f" % [f,
			Difficulty.enemy_health_mult(f), Difficulty.enemy_speed_mult(f),
			Difficulty.enemy_fire_delay_mult(f), 3 + Difficulty.room_extra_animals(f),
			3 + f + Difficulty.room_extra_animals(f), int(Difficulty.wave_chance(f) * 100),
			Difficulty.boss_health_mult(f)])
	var heart_halves = Difficulty.KILL_DROP_CHANCE * Difficulty.DROP_HEART_SHARE * (1.0 + Difficulty.DROP_FULL_HEART_SHARE)
	print("half hearts per kill: %.3f (was %.3f)" % [heart_halves, 0.35 * 0.3 * 1.7])
	var ok := true
	var scene = load("res://Enemy.tscn")
	for f in range(1, 6):
		var e = scene.instantiate()
		e.enemy_type = "pacer"
		root.add_child(e)
		e.setup_enemy(f)
		var want = (7.0 + f * 2.0) * Difficulty.enemy_health_mult(f)
		if abs(e.max_health - want) > 0.01:
			print("FAIL era %d pacer hp %.2f, want %.2f" % [f, e.max_health, want])
			ok = false
		e.make_elder()
		var want_dmg = 2 if f >= Difficulty.ELDER_HEAVY_FROM_ERA else 1
		if e.damage != want_dmg:
			print("FAIL era %d elder damage %d, want %d" % [f, e.damage, want_dmg])
			ok = false
		e.queue_free()
	for f in range(1, 6):
		var boss = load(load("res://Room.gd").BOSSES[f]).new()
		root.add_child(boss)
		boss.setup_enemy(f)
		print("boss era %d %s hp %.0f" % [f, boss.boss_title, boss.max_health])
		boss.queue_free()
	print("DIFFICULTY OK" if ok else "DIFFICULTY FAILED")
	quit(0 if ok else 1)
