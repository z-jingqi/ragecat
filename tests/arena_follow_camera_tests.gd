extends SceneTree
## Run later in the parent's scheduled Godot window; no textures/actors needed.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 800)
	root.content_scale_size = Vector2i(1280, 800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var bounds := Rect2(0, 0, 1280, 800)
	var actor := Node2D.new()
	root.add_child(actor)
	actor.position = bounds.get_center()
	var camera := ArenaFollowCamera.new()
	camera.configure(actor, bounds, 2.0)
	root.add_child(camera)
	var hud := CanvasLayer.new()
	root.add_child(hud)
	var label := Node2D.new()
	label.position = Vector2(30, 30)
	hud.add_child(label)
	var hud_transform := label.get_global_transform_with_canvas()
	check(camera.is_current(), "Arena camera owns the world canvas")
	check(camera.visible_world_rect().size.is_equal_approx(Vector2(640, 400)), "2x reveals 640x400, does not resize world")
	for zoom_value in [1.0, 1.8, 2.0, 2.3, 3.0]:
		camera.set_magnification(zoom_value)
		for point in [Vector2.ZERO, Vector2(1280, 0), Vector2(0, 800), bounds.end, bounds.get_center(), Vector2(510, 390)]:
			actor.position = point
			camera.sync_now()
			var visible := camera.visible_world_rect()
			check(camera.presentation_bounds().grow(0.01).encloses(visible), "Visible world stays inside bounded decorative overscan at edges/corners")
			check(camera.edge_padding == 64.0, "Overscan stays at authored small margin")
			check(actor.position == point, "Camera never moves its target")
			check(camera.world_bounds == bounds, "Camera never changes simulation bounds")
			check(label.get_global_transform_with_canvas().is_equal_approx(hud_transform), "HUD does not zoom or pan")
	check(ArenaFollowCamera.clamped_center(Vector2(500, 500), Rect2(10, 20, 100, 80), Vector2(640, 400)) == Vector2(60, 60), "Small arenas centre without inverted clamp")
	check(ArenaFollowCamera.clamped_center(Vector2(-100, 900), Rect2(100, 200, 1280, 800), Vector2(640, 400)) == Vector2(420, 800), "Nonzero-origin bounds clamp correctly")
	for invalid in [NAN, INF, -INF]:
		camera.set_magnification(invalid)
		check(camera.zoom == Vector2(2, 2), "Nonfinite zoom uses provisional safe default")
	camera.set_magnification(-2)
	check(camera.zoom == Vector2.ONE, "Zoom cannot invert or disappear")
	camera.set_magnification(100)
	check(camera.zoom == Vector2(3, 3), "Zoom respects review range")
	camera.configure(actor, bounds, 2.0, 0.0)
	actor.position = Vector2.ZERO
	camera.sync_now()
	check(bounds.encloses(camera.visible_world_rect()), "Zero padding restores strict world clamping")
	for invalid_padding in [NAN, INF, -INF]:
		camera.configure(actor, bounds, 2.0, invalid_padding)
		check(camera.edge_padding == 64.0, "Nonfinite overscan uses conservative default")
	camera.configure(actor, bounds, 2.0, 10000.0)
	check(camera.edge_padding == 96.0, "Overscan cannot reveal unlimited empty space")
	camera.configure(actor, bounds, 2.0, -10.0)
	check(camera.edge_padding == 0.0, "Overscan cannot shrink playable framing")
	camera.configure(actor, bounds, 2.0, 64.0)
	for zoom_value in [2.0, 2.3]:
		camera.set_magnification(zoom_value)
		for corner in [Vector2(18,18),Vector2(1262,18),Vector2(18,782),Vector2(1262,782)]:
			actor.position = corner
			camera.sync_now()
			var screen_point: Vector2 = (corner - camera.visible_world_rect().position) * camera.zoom
			check(screen_point.x > 64.0 and screen_point.y > 64.0, "Legal wall position clears top/left HUD and clipping margin")
			check(screen_point.x < 1280.0 - 64.0 and screen_point.y < 800.0 - 64.0, "Legal wall position clears right/bottom clipping margin")
	camera.set_magnification(2.0)
	paused = true
	actor.position = Vector2(700, 450)
	await process_frame
	await process_frame
	check(camera.global_position.is_equal_approx(actor.position), "Presentation follow updates while simulation paused")
	root.size = Vector2i(960, 600)
	await process_frame
	await process_frame
	check(camera.visible_world_rect().size.is_equal_approx(Vector2(640, 400)), "Window resize preserves logical framing")
	paused = false
	camera.free()
	await process_frame
	check(root.get_camera_2d() == null, "Retiring arena camera leaves no active camera")
	hud.free()
	actor.free()
	print("arena_follow_camera_tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
