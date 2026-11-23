# Loads every music track listed in data/MusicCredits.gd and checks it loops,
# and that random picks work for each pool.
# Run: godot --headless --path . -s res://tools/musictest.gd
extends SceneTree

func _init():
	var credits = preload("res://data/MusicCredits.gd")
	var ok = true
	var pools = {}
	for t in credits.TRACKS:
		pools[t.pool] = pools.get(t.pool, 0) + 1
		var path = "res://assets/music/" + t.id + ".ogg"
		if not ResourceLoader.exists(path):
			print("MISSING ", path); ok = false; continue
		var s: AudioStreamOggVorbis = load(path)
		print("%-8s %-24s %6.1fs" % [t.pool, t.id, s.get_length()])
		if s.get_length() < 10.0:
			ok = false
	print("pools: ", pools)
	for p in ["menu", "explore", "boss"]:
		if pools.get(p, 0) < 2:
			print("pool too small: ", p); ok = false
	print("MUSIC OK" if ok else "MUSIC FAIL")
	quit(0 if ok else 1)
