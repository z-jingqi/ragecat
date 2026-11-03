# Preview-only layout guard. No simulation or effect pixel coordinates are changed.
extends SceneTree
const Preview = preload("res://previews/group_three/preview.gd")
const JS = preload("res://scripts/core/sf_js.gd")

func _initialize(): call_deferred("run")

func check_label(preview, state):
	var rect = preview.label.get_rect()
	var minimum = preview.label.get_combined_minimum_size()
	assert(preview.label.text.split("\n").size() == 2, state + ": exactly two lines")
	assert(rect.position == Vector2(8, 408), state + ": footer starts below effect canvas")
	assert(rect.end.y <= 456 and minimum.y <= 48, state + ": footer stays inside viewport")
	assert(rect.size.x <= 624 and minimum.x <= 624, state + ": footer width stays inside viewport")
	assert(preview.canvas.position == Vector2.ZERO, state + ": canvas origin unchanged")
	assert(preview.composite_frame.w == 320 and preview.composite_frame.h == 200, state + ": frame unchanged")
	print("PASS layout ", state, " rect=", rect, " minimum=", minimum)

func run():
	# Layout depends on caption values, not the availability of every effect port.
	# Initialize the already-published Pickup host once, then exercise all saved
	# caption variants without loading unreleased effects or advancing simulation.
	var preview = Preview.new()
	preview.slug = "pickup"
	preview.paused = true
	root.add_child(preview)
	assert(root.content_scale_size == Vector2i(640, 456))
	assert(root.size == Vector2i(960, 684))
	assert(not preview.live.is_empty(), "The real host initialized successfully")
	var cases = preview.unpack(JSON.parse_string(FileAccess.get_file_as_string("res://previews/group_three/cases-f64.json")))
	var checks = 0
	for item in cases:
		preview.slug = item.slug
		preview.c = item
		preview.warmup_remaining = int(item.get("warmup", 0))
		preview.last_hook = ""
		preview.present()
		await process_frame
		check_label(preview, item.id + " default/warmup")
		checks += 1
		preview.warmup_remaining = 0
		preview.last_hook = "shake(0.35)"
		preview.present()
		await process_frame
		check_label(preview, item.id + " nonempty hook")
		checks += 1
	preview.free()
	JS.clear_property_cache()
	print("PASS ", checks, " actual Label layout states")
	quit()
