# render_forms.gd
# Renders the code-drawn player forms (PlayerBody.gd). Needs a window
# (xvfb-run on Linux) and the GL renderer:
#   godot --path . --rendering-driver opengl3 -s res://tools/render_forms.gd
# With SHOT_DIR set it saves forms_montage.png (every form, walking, head up)
# into that folder (FORMS=id,id picks some, ZOOM=2 draws them bigger). With SHEETS=1 it rewrites assets/lineages/<id>_sheet.png
# (4 frames of 256 px, head up) that the menu and codex show.
extends SceneTree

const BodyScript = preload("res://PlayerBody.gd")

func _initialize():
	var ids: Array = BodyScript.FORMS.keys()
	if OS.get_environment("FORMS") != "":
		ids = Array(OS.get_environment("FORMS").split(","))
	for i in 5: await process_frame
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	for i in 5: await process_frame
	var out := OS.get_environment("SHOT_DIR")
	if out != "":
		await montage(ids, out)
	if OS.get_environment("SHEETS") == "1":
		await sheets(ids)
	quit()

func pose(b, frame: int, frames: int):
	var ph = TAU * frame / frames
	b.preview = true
	b.move = 0.8
	b.t = 0.6 + frame * 0.25
	b.swim = ph
	b.gait = ph

func montage(ids: Array, out: String):
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.27, 0.3)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	# ZOOM=2 draws them bigger (fewer per row) to check details
	var z := float(OS.get_environment("ZOOM")) if OS.get_environment("ZOOM") != "" else 1.0
	var cols := int(13 / z)
	var bodies := []
	for n in ids.size():
		var holder = Node2D.new()
		holder.position = Vector2(80 * z + (n % cols) * 146 * z, 75 * z + (n / cols) * 150 * z)
		holder.rotation = -PI / 2
		holder.scale = Vector2(z, z)
		root.add_child(holder)
		var b = BodyScript.new()
		b.form_id = ids[n]
		pose(b, 1, 4)
		holder.add_child(b)
		bodies.append(holder)
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/forms_montage.png")
	print("SHOT forms_montage")
	for h in bodies:
		h.queue_free()
	bg.queue_free()

func sheets(ids: Array):
	var vp = SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var holder = Node2D.new()
	holder.position = Vector2(256, 256)
	holder.rotation = -PI / 2
	holder.scale = Vector2(4, 4)
	vp.add_child(holder)
	var b = BodyScript.new()
	holder.add_child(b)
	for id in ids:
		b.form_id = id
		var sheet := Image.create(1024, 256, false, Image.FORMAT_RGBA8)
		for f in 4:
			pose(b, f, 4)
			b.queue_redraw()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var img = vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.resize(256, 256, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(img, Rect2i(0, 0, 256, 256), Vector2i(f * 256, 0))
		sheet.save_png("res://assets/lineages/%s_sheet.png" % id)
		print("SHEET ", id)
