# uishots.gd
# The menus and HUD in every art style: main menu, style picker, a room with
# the HUD, and the pause screen. Needs a window (xvfb on Linux):
# SHOT_DIR=<folder> [STYLES=neon,...] godot --path . --rendering-driver opengl3 --resolution 1920x1080 -s res://tools/uishots.gd
extends SceneTree
var out := OS.get_environment("SHOT_DIR")
func snap(name: String):
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
	print("SHOT ", name)
func _initialize():
	var settings = root.get_node("SettingsManager")
	var before: String = settings.art_style
	var styles: Array = preload("res://data/ArtStyles.gd").ids()
	if OS.get_environment("STYLES") != "":
		styles = Array(OS.get_environment("STYLES").split(","))
	for i in 5: await process_frame
	for id in styles:
		settings.set_art_style(id)
		var menu = load("res://MainMenu.tscn").instantiate()
		root.add_child(menu)
		for i in 15: await process_frame
		await snap("ui_menu_" + id)
		menu.show_art_styles()
		for i in 5: await process_frame
		await snap("ui_picker_" + id)
		menu.queue_free()
		for i in 3: await process_frame
		var main = load("res://Main.tscn").instantiate()
		root.add_child(main)
		current_scene = main
		for i in 40: await process_frame
		main.hud.item_banner.visible = false
		await snap("ui_room_" + id)
		main.hud.toggle_settings()
		for i in 10: await process_frame
		await snap("ui_pause_" + id)
		main.hud.toggle_settings()
		main.queue_free()
		current_scene = null
		for i in 5: await process_frame
	settings.set_art_style(before)
	quit()
