# export_sound_check.gd
# Checks the sound effects load and play inside an EXPORTED pack, where the
# source .wav files are not packed (only their imported copies), unlike in
# the editor. tools/ is left out of exports, so pass this file by path:
#   godot --headless --path . --export-pack "Windows Desktop" /tmp/game.pck
#   godot --headless --main-pack /tmp/game.pck -s /path/to/tools/export_sound_check.gd
extends SceneTree
func _initialize():
	await process_frame
	var sm = root.get_node("SoundManager")
	print("EXPORTCHECK sound_streams loaded: ", sm.sound_streams.size(), " of ", sm.SOUND_VOLUMES.size())
	var takes := 0
	for k in sm.sound_takes:
		takes += sm.sound_takes[k].size()
	print("EXPORTCHECK extra takes: ", sm.sound_takes.size(), " sounds with ", takes, " takes")
	sm.play_attack("bite")
	sm.play_hit("shell")
	await process_frame
	var playing := []
	for ap in sm.player_pool:
		if ap.playing: playing.append(ap.stream.resource_path.get_file())
	print("EXPORTCHECK playing after bite+hit: ", playing)
	quit()
