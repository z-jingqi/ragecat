extends SceneTree
## Independent atlas/presentation contracts. Pixel alpha, not the padded quad,
## establishes the visible envelope. These are not frame-time benchmarks.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FIREBALL VOLUME: " + label)

func phase_of(visual: FireballPresentation) -> float:
	return float(visual.surface.get_shader_parameter("phase"))

func premultiplied(color: Color) -> Color:
	return Color(color.r * color.a, color.g * color.a, color.b * color.a, color.a)

func frame_delta(image: Image, a: int, b: int, grid: Vector2i, size: Vector2i) -> float:
	var sum := 0.0
	var origin_a := Vector2i(a % grid.x, a / grid.x) * size
	var origin_b := Vector2i(b % grid.x, b / grid.x) * size
	for y in range(size.y):
		for x in range(size.x):
			var ca := premultiplied(image.get_pixel(origin_a.x + x, origin_a.y + y))
			var cb := premultiplied(image.get_pixel(origin_b.x + x, origin_b.y + y))
			sum += absf(ca.r-cb.r) + absf(ca.g-cb.g) + absf(ca.b-cb.b) + absf(ca.a-cb.a)
	return sum / float(size.x * size.y * 4)

func check_atlas(definition: FireballVisualDefinition) -> void:
	var atlas := definition.texture.get_image()
	check(atlas != null, "Authored atlas is readable")
	if atlas == null: return
	check(definition.atlas_grid == Vector2i(6,4) and definition.frame_count == 24, "24 frames in 6 by 4 atlas")
	check(atlas.get_size() == Vector2i(960,360), "Atlas is 24 authored 160 by 90 frames")
	var size := atlas.get_size() / definition.atlas_grid
	var lowest_front := INF
	var highest_front := -INF
	for frame in range(definition.frame_count):
		var origin := Vector2i(frame % definition.atlas_grid.x, frame / definition.atlas_grid.x) * size
		var front := -INF
		var upper := INF
		var lower := -INF
		var core_front := -INF
		var core_upper := INF
		var core_lower := -INF
		var edge_alpha := 0.0
		for y in range(size.y):
			for x in range(size.x):
				var alpha := atlas.get_pixel(origin.x+x, origin.y+y).a
				if x == 0 or y == 0 or x == size.x-1 or y == size.y-1:
					edge_alpha = maxf(edge_alpha, alpha)
				var at := definition.bounds_in_radii.position + (Vector2(x,y)+Vector2(0.5,0.5)) / Vector2(size) * definition.bounds_in_radii.size
				# Exclude the cosmetic wake when measuring the central body.
				if at.x < -0.9: continue
				if alpha >= 0.1:
					front = maxf(front, at.x)
					upper = minf(upper, at.y)
					lower = maxf(lower, at.y)
				if alpha >= 0.5:
					core_front = maxf(core_front, at.x)
					core_upper = minf(core_upper, at.y)
					core_lower = maxf(core_lower, at.y)
		lowest_front = minf(lowest_front, front)
		highest_front = maxf(highest_front, front)
		check(front >= 0.9 and front <= 1.15, "Frame %d actual visible front closely matches physical radius" % frame)
		check(-upper >= 0.9 and -upper <= 1.3 and lower >= 0.9 and lower <= 1.3, "Frame %d visible body has radius-scale lateral volume" % frame)
		check(core_front >= 0.75 and core_front <= 1.1, "Frame %d substantial front is not hidden inside padding" % frame)
		check(-core_upper >= 0.75 and -core_upper <= 1.2 and core_lower >= 0.75 and core_lower <= 1.2, "Frame %d substantial lateral body is neither tiny nor inflated" % frame)
		check(edge_alpha <= 0.001, "Frame %d transparent edge padding prevents cell bleed" % frame)
	var largest_neighbor_delta := 0.0
	for frame in range(definition.frame_count-1):
		largest_neighbor_delta = maxf(largest_neighbor_delta, frame_delta(atlas, frame, frame+1, definition.atlas_grid, size))
	var seam := frame_delta(atlas, definition.frame_count-1, 0, definition.atlas_grid, size)
	check(seam > 0.001 and seam <= largest_neighbor_delta * 1.25, "Loop seam is no larger than ordinary evolving flame frames")
	# The last-to-first blend converges to frame zero from either side of wrap.
	var origin_last := Vector2i(5,3) * size
	for y in range(0,size.y,9):
		for x in range(0,size.x,8):
			var first := premultiplied(atlas.get_pixel(x,y))
			var last := premultiplied(atlas.get_pixel(origin_last.x+x,origin_last.y+y))
			var second := premultiplied(atlas.get_pixel(size.x+x,y))
			var before := last.lerp(first,0.99999)
			var after := first.lerp(second,0.00001)
			check(absf(before.a-after.a) < 0.00003 and Vector3(before.r-after.r,before.g-after.g,before.b-after.b).length() < 0.00006, "Premultiplied frame23-to0 interpolation is continuous")
	print("ATLAS_ALPHA front_radii=",lowest_front,"..",highest_front," seam_mae=",seam)

func make_target() -> PlayerActor:
	var player := PlayerActor.new()
	player.setup(CombatStats.new())
	player.position = Vector2(-5000,-5000)
	player.movement_enabled = false
	player.set_physics_process(false)
	root.add_child(player)
	player.set_physics_process(false)
	return player

func make_bullet(player: PlayerActor, heading: Vector2, radius: float) -> EnemyBullet:
	var settings := SpitterDefinition.new()
	settings.bullet_radius = radius
	settings.bullet_range = 10000.0
	var bullet := EnemyBullet.new()
	bullet.setup(Vector2(1000,1000),heading,settings,player)
	bullet.arena_bounds = Rect2(-10000,-10000,20000,20000)
	root.add_child(bullet)
	return bullet

func check_directions_and_clocks(player: PlayerActor) -> void:
	for hz in [30,60,120]:
		for direction_index in range(8):
			for radius in [6.0,12.0]:
				var heading := Vector2.RIGHT.rotated(direction_index*TAU/8.0)
				var bullet := make_bullet(player,heading,radius)
				bullet.set_physics_process(false)
				var visual := bullet.get_node("FireballPresentation") as FireballPresentation
				visual.set_physics_process(false)
				check(absf(angle_difference(visual.rotation,heading.angle())) < 0.00001, "First rendered frame faces the velocity in all eight directions")
				var center := visual.definition.bounds_in_radii.get_center()
				var physical_center_uv := -visual.definition.bounds_in_radii.position / visual.definition.bounds_in_radii.size
				var physical_center_local := (physical_center_uv-Vector2(0.5,0.5))*2.0
				check(visual.to_global(physical_center_local).distance_to(bullet.global_position) < 0.001, "Atlas physical center maps to unchanged collision center")
				check(visual.position.distance_to(center.rotated(heading.angle())*radius) < 0.001, "Quad placement rotates consistently with every heading")
				check(visual.surface.get_shader_parameter("arena_rect") == Vector4(-10000,-10000,20000,20000), "World clipping receives original arena rectangle")
				check(phase_of(visual) == 0.0, "First frame starts at travel age zero")
				for tick in range(hz*2):
					bullet._physics_process(1.0/hz)
					var position_before := bullet.position
					var traveled_before := bullet.traveled
					var hp_before := player.stats.hp
					visual._physics_process(1.0/hz)
					check(is_equal_approx(phase_of(visual),traveled_before/bullet.definition.bullet_speed*visual.definition.frames_per_second), "Frame selection follows distance-derived travel age")
					check(bullet.position == position_before and bullet.traveled == traveled_before and player.stats.hp == hp_before, "Presentation never changes movement or health")
				var surface_ref: WeakRef = weakref(visual.surface)
				var texture_ref: WeakRef = weakref(visual.texture)
				bullet.consume()
				visual._physics_process(0.0)
				check(not visual.visible, "Consumed presentation hides before next render")
				bullet.free()
				check(surface_ref.get_ref() == null and texture_ref.get_ref() == null, "Per-shot material and quad texture are released")

func check_real_pause(player: PlayerActor) -> void:
	var original_hz := Engine.physics_ticks_per_second
	for hz in [30,60,120]:
		Engine.physics_ticks_per_second = hz
		var bullet := make_bullet(player,Vector2.RIGHT,6.0)
		var visual := bullet.get_node("FireballPresentation") as FireballPresentation
		await physics_frame
		await process_frame
		check(bullet.traveled > 0.0, "Real automatic physics advances bullet")
		bullet.ai_enabled = false
		var traveled_before := bullet.traveled
		var phase_before := phase_of(visual)
		await physics_frame
		await physics_frame
		await process_frame
		check(bullet.traveled == traveled_before and phase_of(visual) == phase_before, "AI disable freezes motion and animation together")
		bullet.ai_enabled = true
		paused = true
		await physics_frame
		await physics_frame
		await process_frame
		check(bullet.traveled == traveled_before and phase_of(visual) == phase_before, "SceneTree pause freezes atlas playback")
		paused = false
		await physics_frame
		await process_frame
		check(bullet.traveled > traveled_before and phase_of(visual) > phase_before, "Resume continues travel age without wall-time catchup")
		bullet.free()
	Engine.physics_ticks_per_second = original_hz

func check_reset_and_damage() -> void:
	var arena := RageArena.new()
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = 71137
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.stats.shields = 0
	arena.player.invulnerable = false
	arena.player.radius = 0.1
	arena.player.position = Vector2(288,300)
	var settings := SpitterDefinition.new()
	var shot := EnemyBullet.new()
	shot.setup(Vector2(300,300),Vector2.RIGHT,settings,arena.player)
	arena.enemy_bullets.add_child(shot)
	var hp_before := arena.stats.hp
	shot._physics_process(1.0/120.0)
	check(not shot.consumed and arena.stats.hp == hp_before, "Cosmetic wake overlapping the player has no extra damage volume")
	arena.clear_enemies()
	for repetition in range(3):
		var references: Array[WeakRef] = []
		for i in range(12):
			shot = EnemyBullet.new()
			shot.setup(Vector2(600+i*2,400),Vector2.LEFT,settings,arena.player)
			arena.enemy_bullets.add_child(shot)
			references.append(weakref(shot.get_node("FireballPresentation").surface))
		arena._on_death()
		await process_frame
		check(not arena.finished and not arena._practice_restart_pending and arena.enemy_bullets.get_child_count() == 0, "Practice reset removes every hostile projectile")
		for reference in references: check(reference.get_ref() == null, "Practice reset releases every projectile material")
	arena.free()

func run() -> void:
	var definition := load("res://resources/projectiles/enemy_fireball.tres") as FireballVisualDefinition
	check_atlas(definition)
	var shader := FileAccess.get_file_as_string("res://shaders/enemy_fireball.gdshader")
	check(not shader.contains("TIME"), "Shader has no wall-time animation source")
	check(shader.contains("a.rgb*a.a") and shader.contains("b.rgb*b.a") and shader.contains("mod(current + 1.0, frame_count)"), "Shader wraps frames and interpolates alpha-weighted colors")
	check(shader.contains("MODEL_MATRIX") and shader.contains("world_position.x<arena_rect.x") and shader.contains("world_position.y>arena_rect.y+arena_rect.w"), "Shader clips in world coordinates rather than atlas UV")
	check(shader.contains("clamp(uv, inset") and shader.contains("repeat_disable"), "Atlas sampling is clamped to each frame")
	var player := make_target()
	check_directions_and_clocks(player)
	await check_real_pause(player)
	player.free()
	await check_reset_and_damage()
	print("FIREBALL_VOLUME_PRESENTATION: %d checks, %d failures" % [checks,failures])
	quit(failures)
