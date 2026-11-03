extends SceneTree
const Warning = preload("res://effects/VFX-17_boss_warning/hostile_warning.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func snapshot(view: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return view.get_texture().get_image()
func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var w := Warning.new()
	view.add_child(w)
	for data in [["circle", Vector2(300, 300), Vector2(300, 300), 62.0], ["capsule", Vector2(150, 300), Vector2(410, 300), 23.0], ["line", Vector2(150, 300), Vector2(606, 300), 7.0], ["capsule", Vector2(300, 300), Vector2(300, 300), 23.0], ["capsule", Vector2(50, 120), Vector2(1200, 600), 31.0], ["circle", Vector2.ZERO, Vector2(640, 360), 300.0]]:
		w.play(data[0], data[1], data[2], data[3])
		var start: Image = await snapshot(view)
		var boundary := w.boundary_points()
		# Every perimeter sample must have a visible orange edge within 3 pixels.
		# Inset stroke + polygon chord error are <2 px for these native fixtures.
		for p in boundary:
			var visible := false
			for y in range(int(p.y) - 3, int(p.y) + 4):
				for x in range(int(p.x) - 3, int(p.x) + 4):
					if x >= 0 and y >= 0 and x < 1280 and y < 720 and start.get_pixel(x, y).a > 0.8: visible = true
			check(visible, "entire outline visible, including long capsule endcaps")
		w.seek(0.6)
		var middle: Image = await snapshot(view)
		check(start.get_data() != middle.get_data(), "visible progress")
		var outside := 0
		var occupied := 0
		for y in range(720):
			for x in range(1280):
				if middle.get_pixel(x, y).a <= 0: continue
				occupied += 1
				var p := Vector2(x + 0.5, y + 0.5)
				var closest: Vector2 = data[2] if data[0] == "circle" else Geometry2D.get_closest_point_to_segment(p, data[1], data[2])
				if p.distance_to(closest) > data[3] + 1.0: outside += 1
		check(occupied > 100 and outside == 0, "pixels remain inside caller geometry with <=1px raster tolerance")
		var paused: Image = await snapshot(view)
		check(paused.get_data() == middle.get_data(), "no visual drift while paused")
		w.stop()
		var stopped: Image = await snapshot(view)
		check(stopped.get_used_rect().size == Vector2i.ZERO, "cancel clears every pixel")
	view.queue_free()
	print("HOSTILE WARNING GPU: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
