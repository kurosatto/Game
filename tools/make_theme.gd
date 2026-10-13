# make_theme.gd
# Saves data/UIStyle.gd's theme as the project theme. Run after changing
# UIStyle.gd:
#   godot --headless --path . -s res://tools/make_theme.gd
extends SceneTree
func _initialize():
	var theme = preload("res://data/UIStyle.gd").make_theme()
	var err = ResourceSaver.save(theme, "res://assets/ui/organic_theme.tres")
	print("THEME SAVED " if err == OK else "THEME FAILED ", err)
	quit()
