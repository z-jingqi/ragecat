extends SceneTree
## Real production floor/arrow/actors/HUD. Refuses headless. Neutral A/B removes
## the entire continuous energy body so pixel differences can only be UV refraction.
## godot --path . --script tests/dark_distortion_render_fixture.gd -- --capture-dir=/tmp/dark-refraction --size=960x600
var output := "/tmp/dark-refraction"
var capture_size := Vector2i(960, 600)
var arrow_angle := 0.0
var edge_case := false
var game: Node
var arena: RageArena
var arrow: BowArrow
var field: GravityField
var original_library: VfxAtlasLibrary
var settings: VfxAtlasLibrary
var failures := 0
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): output = argument.trim_prefix("--capture-dir=")
		elif argument.begins_with("--angle="): arrow_angle = float(argument.trim_prefix("--angle="))
		elif argument == "--edge": edge_case = true
		elif argument.begins_with("--size="):
			var parts := argument.trim_prefix("--size=").split("x")
			if parts.size() == 2: capture_size = Vector2i(int(parts[0]), int(parts[1]))
	call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless" or not output.begins_with("/tmp/"):
		push_error("Use a real rendering display and an output directory under /tmp.")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("en")
	game.start_run(true, 72103)
	game.return_from_practice_navigation()
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED, capture_size)
	while game.window_settings.apply_pending: await process_frame
	game.window_settings.confirm_preview()
	arena = game.arena
	arena.set_sound_enabled(false)
	arena.player.invulnerable = true
	arena.player.movement_enabled = false
	arena.clear_enemies()
	arena.apply_ranks({"dark_enchant": 3, "dark_bow": 3})
	arena.player.position = Vector2(120, 220) if edge_case else Vector2(535, 410)
	var enemy := arena.spawn_enemy("mob", Vector2(170, 240) if edge_case else Vector2(700, 410))
	enemy.ai_enabled = false
	enemy.health = 100000
	enemy.max_health = 100000
	enemy.show_health_bar = false
	arena.bow.shoot()
	arrow = arena.bow.active_gravity_arrow
	arrow.direction = Vector2.from_angle(arrow_angle)
	arrow.rotation = arrow_angle
	var requested_tip := Vector2(70, 200) if edge_case else Vector2(625, 410)
	arrow.position = requested_tip - Vector2(arena.stats.element_skill.gravity.tip_offset, 0.0).rotated(arrow_angle)
	arrow.presentation_origin_offset = Vector2.ZERO
	field = arrow.gravity_field
	field.age = 0.75
	paused = true
	original_library = VfxAtlasRenderer.library
	settings = original_library.duplicate(true) as VfxAtlasLibrary
	VfxAtlasRenderer.library = settings
	settings.dark_body_opacity = 0.0
	settings.dark_refraction_pull = 0.0
	settings.dark_refraction_swirl = 0.0
	game.update_hud()
	var baseline := await capture("01_uv_off.png")
	settings.dark_refraction_pull = original_library.dark_refraction_pull
	settings.dark_refraction_swirl = original_library.dark_refraction_swirl
	var distorted := await capture("02_uv_on.png")
	# Actors are still drawn after the copy. The test masks opaque actor pixels
	# by separately capturing identical floor-only frames, not by assuming boxes.
	arena.player.hide()
	enemy.hide()
	var ground_warped := await capture("04_ground_uv_on.png")
	settings.dark_refraction_pull = 0.0
	settings.dark_refraction_swirl = 0.0
	var ground_plain := await capture("03_ground_uv_off.png")
	# Derive the real HUD alpha, rather than treating bare top-of-screen floor
	# as HUD. Black/white plates are behind the production CanvasLayer UI.
	game.combat_hud.hide()
	var no_hud_plain := await capture("06_ground_no_hud_plain.png")
	settings.dark_refraction_pull = original_library.dark_refraction_pull
	settings.dark_refraction_swirl = original_library.dark_refraction_swirl
	var no_hud_warped := await capture("07_ground_no_hud_warped.png")
	game.combat_hud.show()
	var plate := ColorRect.new()
	plate.size = Vector2(1280, 800)
	plate.z_index = -4095
	plate.color = Color.BLACK
	game.ui.add_child(plate)
	game.ui.move_child(plate, 0)
	var hud_black := await capture("08_hud_black.png")
	plate.color = Color.WHITE
	var hud_white := await capture("09_hud_white.png")
	plate.free()
	var metrics := measure_pixels(baseline, distorted, ground_plain, ground_warped, no_hud_plain, no_hud_warped, hud_black, hud_white)
	arena.player.show()
	enemy.show()
	VfxAtlasRenderer.library = original_library
	await capture("05_production_dark.png")
	metrics["paused_resize"] = await verify_paused_transforms()
	# Actual arrow flight, fixed simulation deltas. Do not integrate enemies,
	# because pixel stability above is an isolated rendering contract.
	for frame in range(48):
		arrow._physics_process(1.0 / 24.0)
		game.update_hud()
		await capture("frame_%04d.png" % frame)
	var file := FileAccess.open(output.path_join("proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"display": DisplayServer.get_name(), "renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "engine": Engine.get_version_info().string, "native_size": [capture_size.x, capture_size.y], "arrow_angle": arrow_angle, "edge_case": edge_case, "capture_size": [baseline.get_width(), baseline.get_height()], "metrics": metrics, "failures": failures, "note": "Actual rendered production arena. A/B sets continuous body opacity to zero; only screen UV offset differs. Actor check uses opaque observed pixels. Motion uses the real BowArrow physics path."}, "\t"))
	print("DARK_REFRACTION_PIXEL_PROOF ", JSON.stringify(metrics), " failures=", failures)
	game.show_menu()
	game.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures else 0)
func capture(filename: String, force_sync: bool = true) -> Image:
	if force_sync and is_instance_valid(field):
		field._sync_matter_surface()
		field.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.save_png(output.path_join(filename)) != OK:
		failures += 1
		push_error("Failed to save " + filename)
	return image
func measure_pixels(base: Image, bent: Image, plain_ground: Image, bent_ground: Image, no_hud_plain: Image, no_hud_bent: Image, hud_black: Image, hud_white: Image) -> Dictionary:
	var changed_ground := 0
	var unchanged_actors := 0
	var actor_moved := 0
	var outside_changed := 0
	var hud_changed := 0
	var hud_opaque := 0
	var hud_translucent_residual := 0
	var hud_ghosts := 0
	var max_ground_delta := 0.0
	var extent := Vector2(base.get_size())
	var scale := extent / Vector2(1280, 800)
	# World coordinates no longer equal logical screen coordinates. Include
	# both follow-camera translation/zoom and window stretch for pixel masks.
	var world_to_screen := root.get_stretch_transform() * root.canvas_transform
	var world_scale := world_to_screen.x.length()
	var tip := world_to_screen * field.global_position
	var outer := field.outer_radius * world_scale
	for y in range(base.get_height()):
		for x in range(base.get_width()):
			var p := Vector2(x + 0.5, y + 0.5)
			var a := base.get_pixel(x, y)
			var b := bent.get_pixel(x, y)
			var ground_a := plain_ground.get_pixel(x, y)
			var ground_b := bent_ground.get_pixel(x, y)
			var difference := delta(a, b)
			var floor_delta := delta(ground_a, ground_b)
			var actor_pixel := delta(a, ground_a) > 0.16
			var background_transmittance := hud_white.get_pixel(x, y) - hud_black.get_pixel(x, y)
			var hud_alpha := clampf(1.0 - (background_transmittance.r + background_transmittance.g + background_transmittance.b) / 3.0, 0.0, 1.0)
			if hud_alpha >= 0.99:
				hud_opaque += 1
				if difference > 0.005: hud_changed += 1
			var expected_background_change := (no_hud_bent.get_pixel(x, y) - no_hud_plain.get_pixel(x, y)) * (1.0 - hud_alpha)
			var residual := (ground_b - ground_a) - expected_background_change
			# Three 8-bit levels cover quantization of the two alpha probes and
			# two composited frames, not movement of opaque text or icons.
			if maxf(absf(residual.r), maxf(absf(residual.g), absf(residual.b))) > 3.0 / 255.0:
				if hud_alpha > 0.01: hud_translucent_residual += 1
				else: hud_ghosts += 1
			if p.distance_to(tip) > outer + 3.0 and difference > 0.005: outside_changed += 1
			if p.distance_to(tip) < outer - 5.0:
				if floor_delta > 0.005:
					changed_ground += 1
					max_ground_delta = maxf(max_ground_delta, floor_delta)
				if actor_pixel:
					if difference < 0.005: unchanged_actors += 1
					else: actor_moved += 1
	var grid_shifts: Array[float] = []
	# A real arena vertical grid line is straight in A and bends in B. Measure
	# its luminance centroid at separated rows, avoiding horizontal grid lines.
	var line_world_x := ceilf((field.global_position.x + 20.0) / 48.0) * 48.0
	var line_x := (world_to_screen * Vector2(line_world_x, field.global_position.y)).x
	for row_offset in [-120.0, -85.0, -50.0, 50.0, 85.0, 120.0]:
		var row := roundi((world_to_screen * (field.global_position + Vector2(0, row_offset))).y)
		if row < int(100.0 * scale.y) or row >= base.get_height(): continue
		var plain_x := line_centroid(plain_ground, line_x, row, 18.0 * world_scale)
		var bent_x := line_centroid(bent_ground, line_x, row, 18.0 * world_scale)
		if is_finite(plain_x) and is_finite(bent_x): grid_shifts.append(bent_x - plain_x)
	var maximum_grid_shift := 0.0
	var grid_bend_span := 0.0
	if not grid_shifts.is_empty():
		maximum_grid_shift = maxf(absf(grid_shifts.min()), absf(grid_shifts.max()))
		grid_bend_span = grid_shifts.max() - grid_shifts.min()
	# Anti-aliased actor edges can expose a changed subpixel of background.
	# Interior pixels must remain overwhelmingly identical, never displaced.
	if changed_ground < 100 or maximum_grid_shift < 2.0 * scale.x or grid_bend_span < 1.0 * scale.x or unchanged_actors < 50 or actor_moved > unchanged_actors * 0.04 or outside_changed > 0 or hud_opaque < 100 or hud_changed > 0 or hud_translucent_residual > 0 or hud_ghosts > 0:
		failures += 1
		push_error("Rendered refraction pixel contract failed; inspect A/B images and metrics.")
	return {"grid_line_displacement_px": grid_shifts, "maximum_grid_shift_px": maximum_grid_shift, "grid_bend_span_px": grid_bend_span, "changed_ground_pixels": changed_ground, "max_ground_rgb_delta": max_ground_delta, "unchanged_opaque_actor_pixels": unchanged_actors, "changed_actor_edge_pixels": actor_moved, "outside_radius_changed_pixels": outside_changed, "hud_changed_pixels": hud_changed, "opaque_hud_pixels": hud_opaque, "hud_translucent_unexplained_pixels": hud_translucent_residual, "hud_ghost_pixels": hud_ghosts, "field_center_px": [tip.x, tip.y], "outer_radius_px": outer}
func delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

func line_centroid(image: Image, center_x: float, y: int, half_width: float) -> float:
	var start := maxi(0, floori(center_x - half_width))
	var end := mini(image.get_width() - 1, ceili(center_x + half_width))
	var minimum := 1.0
	for x in range(start, end + 1):
		var pixel := image.get_pixel(x, y)
		minimum = minf(minimum, (pixel.r + pixel.g + pixel.b) / 3.0)
	var weighted := 0.0
	var total := 0.0
	for x in range(start, end + 1):
		var pixel := image.get_pixel(x, y)
		var weight := maxf(0.0, (pixel.r + pixel.g + pixel.b) / 3.0 - minimum - 0.001)
		weighted += (float(x) + 0.5) * weight
		total += weight
	return weighted / total if total > 0.003 else INF

func verify_paused_transforms() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var frozen_age := field.age
	var frozen_phase: float = (field._matter_surface.material as ShaderMaterial).get_shader_parameter("phase")
	var frozen_body_phase: float = (field._matter_surface.material as ShaderMaterial).get_shader_parameter("body_phase")
	for size in [Vector2i(960, 600), Vector2i(1280, 800), Vector2i(960, 600)]:
		game.window_settings.begin_preview(WindowSettingsController.WINDOWED, size)
		while game.window_settings.apply_pending: await process_frame
		game.window_settings.confirm_preview()
		await process_frame
		await process_frame
		var label := "resize_%d_%dx%d" % [results.size(), size.x, size.y]
		# No manual synchronization before the first capture: exercise the
		# production pause-safe transform callback, then compare forced sync.
		var automatic := await capture(label + "_automatic.png", false)
		var reference := await capture(label + "_forced.png", true)
		var changed := count_changed(automatic, reference)
		var clock_frozen: bool = field.age == frozen_age and (field._matter_surface.material as ShaderMaterial).get_shader_parameter("phase") == frozen_phase and (field._matter_surface.material as ShaderMaterial).get_shader_parameter("body_phase") == frozen_body_phase
		results.append({"size": [size.x, size.y], "automatic_vs_forced_changed_pixels": changed, "simulation_clock_frozen": clock_frozen})
		if changed != 0 or not clock_frozen:
			failures += 1
			push_error("Paused resize failed: stale capture rectangle or advanced simulation.")
	game.window_settings.begin_preview(WindowSettingsController.WINDOWED, capture_size)
	while game.window_settings.apply_pending: await process_frame
	game.window_settings.confirm_preview()
	return results
func count_changed(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size(): return -1
	var count := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			if delta(a.get_pixel(x, y), b.get_pixel(x, y)) > 0.005: count += 1
	return count
