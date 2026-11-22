# Loads every music track the way SoundManager does and checks it loops and
# has a credit. Run: godot --headless --path . -s res://tools/musictest.gd
extends SceneTree

func _init():
	var credits = preload("res://data/MusicCredits.gd")
	var names = ["title"]
	for era in ["ediacaran", "cambrian", "ordovician", "carboniferous", "permian"]:
		names.append(era)
		names.append("boss_" + era)
	var ok = true
	for n in names:
		var path = "res://assets/music/" + n + ".ogg"
		if not ResourceLoader.exists(path):
			print("MISSING ", path); ok = false; continue
		var s: AudioStreamOggVorbis = load(path)
		print("%-20s %6.1fs loop=%s" % [n, s.get_length(), s.loop])
		if s.get_length() < 30.0 or not s.loop:
			ok = false
	if credits.TRACKS.size() != names.size():
		print("credits list has ", credits.TRACKS.size(), " entries for ", names.size(), " tracks"); ok = false
	print("MUSIC OK" if ok else "MUSIC FAIL")
	quit(0 if ok else 1)
