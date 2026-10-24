extends SceneTree
## Projectile presentation contracts. Synthetic pose textures isolate mechanics;
## these tests are not a visual-quality or player-difficulty certification.
const DT := 1.0 / 60.0
const CLIPS := ["carry", "raise", "lower", "lower_loaded", "controlled_undraw", "normal_release", "normal_renock", "normal_draw", "short_release", "short_recover", "short_draw", "hold_relaxed", "hold_relaxed_loaded", "short_undraw"]
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("PROJECTILE PRESENTATION: " + label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.00001, label)

func texture(value: Color) -> ImageTexture:
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(value)
	return ImageTexture.create_from_image(image)

func appearance() -> ArcherAppearanceDefinition:
	var value := ArcherAppearanceDefinition.new()
	value.upper = ArcherPoseLibrary.new()
	value.lower = ArcherPoseLibrary.new()
	var color := texture(Color.WHITE)
	var depth := texture(Color(0.5, 0.5, 0.5))
	for library in [value.upper, value.lower]:
		library.colors = SpriteFrames.new()
		library.depths = SpriteFrames.new()
		library.canvas_size = Vector2i(4, 4)
		library.pivot = Vector2(2, 2)
	for index in range(8):
		var direction := value.direction_names[index]
		var axis := Vector2.from_angle(index * TAU / 8.0)
		# Deliberately exceeds the visual limit to exercise clamping in every view.
		value.muzzle_positions.append(axis * 28.0 + axis.rotated(PI / 2.0) * 20.0)
		for suffix in CLIPS:
			var key := StringName(direction + "/" + suffix)
			value.upper.colors.add_animation(key)
			value.upper.depths.add_animation(key)
			value.upper.colors.add_frame(key, color)
			value.upper.depths.add_frame(key, depth)
		var key := StringName(direction + "/idle")
		value.lower.colors.add_animation(key)
		value.lower.depths.add_animation(key)
		value.lower.colors.add_frame(key, color)
		value.lower.depths.add_frame(key, depth)
	return value

func make_arena(visual: bool, ranks: Dictionary = {}) -> RageArena:
	# Both variants use explicit actor scenes, independent of the shipped scene's
	# eventual default artwork, with identical character/bow gameplay resources.
	var actor := Archer.new()
	if visual: actor.appearance = appearance()
	var scene := PackedScene.new()
	check(scene.pack(actor) == OK, "Compatible test actor scene packs")
	actor.free()
	var character := (load("res://resources/characters/archer.tres") as CharacterDefinition).duplicate(true) as CharacterDefinition
	character.actor_scene = scene
	var arena := RageArena.new()
	arena.character_definition = character
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = 71137
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.feedback.enabled = false
	arena.apply_ranks(ranks)
	return arena

func add_target(arena: RageArena, offset: Vector2) -> EnemyActor:
	var target := arena.spawn_enemy("dummy", arena.player.position + offset)
	target.max_health = 100000.0
	target.health = target.max_health
	target.ai_enabled = false
	return target

func update_presentation(arena: RageArena, delta: float = DT) -> void:
	var presentation: ArcherPresentation = arena.player._presentation
	if presentation != null:
		presentation.adapter._physics_process(delta)
		presentation._physics_process(delta)

func arrow_snapshot(arrow: BowArrow) -> Array:
	# Exclude only presentation fields and rotation: collision is direction-based.
	var result: Array = [arrow.position, arrow.direction, arrow.speed, arrow.max_range,
		arrow.traveled, arrow.width, arrow.max_hits, arrow.retention, arrow.damage_scale,
		arrow.decay, arrow.secondary, arrow.split_used, arrow.unlimited_direct_hits,
		arrow.critical_resolved, arrow.critical_result, arrow.impact_position,
		arrow.impact_traveled, arrow.element_proc_used, arrow.hit_ids.size(),
		arrow.ignored_ids.size(), arrow.retired, arrow.is_queued_for_deletion(), arrow.lifetime_remaining]
	if arrow.gravity_field != null:
		var field := arrow.gravity_field
		var exposure: Array = []
		for enemy in arrow.enemies.get_children(): exposure.append(field.exposure.get(enemy.get_instance_id(), 0.0))
		result.append([field.global_position, field.age, field.active, exposure])
	return result

func snapshot(arena: RageArena) -> Array:
	var result: Array = [arena.rng.state, arena.player.position, arena.player.aim_direction,
		arena.stats.hp, arena.stats.shields, arena.hits, arena.crits, arena.total_damage,
		arena.bow.attack_clock, arena.bow.burst_clock, arena.bow.burst_remaining,
		arena.bow.gravity_gap_remaining, arena.feedback.event_counts.get("launch", 0),
		arena.element_procs.proc_counts.duplicate(), arena.arrows.get_child_count()]
	for arrow in arena.arrows.get_children(): result.append(arrow_snapshot(arrow))
	for enemy in arena.enemies.get_children():
		var status := enemy.status as StatusEffects
		var burn := arena.element_procs.burns.get(enemy.get_instance_id()) as BurnEffect
		result.append([enemy.position, enemy.health, enemy.is_dead, enemy.gravity_velocity,
			enemy.gravity_contact_grace, status.shock_remaining, status.shock_bonus,
			status.chill_remaining, status.frost_stacks, status.frost_remaining,
			status.frozen_remaining, status.ice_mark_remaining, status.immunity_remaining,
			[] if burn == null else [burn.remaining, burn.dps, burn.interval, burn.accrued]])
	return result

func test_eight_directions() -> void:
	for index in range(8):
		var arena := make_arena(true)
		var axis := Vector2.from_angle(index * TAU / 8.0)
		add_target(arena, axis * 180.0)
		arena.bow.shoot()
		var arrow := arena.arrows.get_child(0) as BowArrow
		check(arrow.traveled == 0.0, "Orientation case is before first physics tick: %d" % index)
		near(wrapf(arrow.rotation - axis.angle(), -PI, PI), 0.0, "First render already has correct arrow rotation: %d" % index)
		check(arrow.presentation_spawn_frame == Engine.get_physics_frames(), "Ready stamps actual spawn physics frame")
		var before := snapshot(arena)
		seed(91237)
		var expected_random := randi()
		seed(91237)
		update_presentation(arena)
		check(randi() == expected_random, "Muzzle handoff does not consume global RNG")
		check(snapshot(arena) == before, "Eight-direction handoff changes no logical state: %d" % index)
		check(arena.arrows.get_child_count() == 1, "Presentation cannot create an extra arrow")
		near(arrow.presentation_origin_offset.length(), 8.0, "Offset is clamped to 8 pixels")
		near(arrow.presentation_origin_offset.dot(axis), 0.0, "Offset is lateral, not an axial range change")
		check(arrow.presentation_origin_offset.dot(axis.rotated(PI / 2.0)) > 0.0, "Offset chooses matching muzzle side")
		check(arrow.presentation_blend_distance <= 24.0 and arrow.presentation_blend_distance / arrow.speed <= 0.05,
			"Blend remains within both distance and time ceilings")
		arena.free()

func test_suppression_and_limits() -> void:
	var near_arena := make_arena(true)
	add_target(near_arena, Vector2(55, 0))
	near_arena.bow.shoot()
	update_presentation(near_arena)
	var near_arrow := near_arena.arrows.get_child(0) as BowArrow
	check(near_arrow.presentation_origin_offset == Vector2.ZERO and near_arrow.presentation_blend_distance == 0.0, "Nearby hit disables cosmetic offset")
	near_arena.free()

	var split := make_arena(true, {"split": 3})
	var target := add_target(split, Vector2(200, 0))
	split.bow.shoot()
	var source := split.arrows.get_child(0) as BowArrow
	source.impact_position = source.position + Vector2(80, 0)
	source.impact_traveled = 80.0
	split.bow._spawn_fragments(source, target.get_instance_id())
	var count_before := split.arrows.get_child_count()
	update_presentation(split)
	var fragments := 0
	for arrow: BowArrow in split.arrows.get_children():
		if not arrow.secondary: continue
		fragments += 1
		check(arrow.presentation_origin_offset == Vector2.ZERO and arrow.presentation_blend_distance == 0.0, "Split fragment never receives primary muzzle handoff")
		near(wrapf(arrow.rotation - arrow.direction.angle(), -PI, PI), 0.0, "Split fragment also has correct first-frame rotation")
	check(fragments == split.stats.split_angles.size() and fragments > 0 and split.arrows.get_child_count() == count_before, "Fragment exclusion does not add or remove arrows")
	split.free()

	var gravity := make_arena(true, {"dark_enchant": 3, "dark_bow": 3})
	add_target(gravity, Vector2(0, -200))
	gravity.bow.shoot()
	var gravity_arrow := gravity.bow.active_gravity_arrow
	check(gravity_arrow != null and gravity_arrow.gravity_field != null, "Gravity exclusion uses real gravity projectile")
	var gravity_before := snapshot(gravity)
	update_presentation(gravity)
	check(gravity_arrow.presentation_origin_offset == Vector2.ZERO and gravity_arrow.presentation_blend_distance == 0.0, "Gravity projectile never receives muzzle offset")
	check(snapshot(gravity) == gravity_before, "Gravity field position and lifetime remain unchanged by presentation")
	gravity.free()

	for speed in [100.0, 650.0]:
		var limits := make_arena(true)
		add_target(limits, Vector2(220, 0))
		var p: ArcherPresentation = limits.player._presentation
		p.appearance.muzzle_handoff_distance = 100.0
		p.appearance.muzzle_handoff_max_duration = 1.0
		p.appearance.muzzle_handoff_limit = 100.0
		limits.bow.shoot()
		var arrow := limits.arrows.get_child(0) as BowArrow
		arrow.speed = speed
		update_presentation(limits)
		check(arrow.presentation_blend_distance > 0.0, "Overlarge configuration still produces a valid bounded handoff")
		check(arrow.presentation_origin_offset.length() <= 8.00001, "Authored limit cannot exceed hard 8-pixel ceiling")
		check(arrow.presentation_blend_distance <= 24.0 and arrow.presentation_blend_distance / speed <= 0.050001,
			"Authored settings cannot exceed 24px or 0.05 seconds")
		limits.free()

	for mode in ["short_range", "stopped", "hidden", "nonfinite_muzzle"]:
		var disabled := make_arena(true)
		add_target(disabled, Vector2(220, 0))
		disabled.bow.shoot()
		var arrow := disabled.arrows.get_child(0) as BowArrow
		var p: ArcherPresentation = disabled.player._presentation
		if mode == "short_range": arrow.max_range = 24.0
		elif mode == "stopped": arrow.speed = 0.0
		elif mode == "hidden": p.appearance.upper = null
		else: p.appearance.muzzle_positions[0] = Vector2.INF
		update_presentation(disabled)
		check(arrow.presentation_origin_offset == Vector2.ZERO and arrow.presentation_blend_distance == 0.0, "Unsafe/inapplicable handoff stays disabled: " + mode)
		disabled.free()

func test_old_arrow_handoff() -> void:
	var arena := make_arena(true)
	add_target(arena, Vector2(200, 0))
	arena.bow.shoot()
	update_presentation(arena)
	var old := arena.arrows.get_child(0) as BowArrow
	var initial_offset := old.presentation_origin_offset
	var initial_blend := old.presentation_blend_distance
	var p: ArcherPresentation = arena.player._presentation
	p.appearance.muzzle_positions[0] = Vector2(28, -40)
	arena.bow.shoot()
	update_presentation(arena)
	check(old.presentation_origin_offset == initial_offset and old.presentation_blend_distance == initial_blend,
		"Later same-tick burst cannot rewrite an already handed-off arrow")
	var next := arena.arrows.get_child(1) as BowArrow
	check(next.presentation_origin_offset.y < 0.0, "New primary receives its own current muzzle handoff")
	arena.free()

	var untouched := make_arena(true)
	add_target(untouched, Vector2(200, 0))
	untouched.bow.shoot()
	var previous := untouched.arrows.get_child(0) as BowArrow
	var previous_frame := previous.presentation_spawn_frame
	# The arena is disabled: its old arrow remains stationary while actual engine
	# physics frame IDs advance, ruling out a distance-only freshness heuristic.
	await physics_frame
	await physics_frame
	check(Engine.get_physics_frames() > previous_frame and previous.traveled == 0.0, "Old-arrow fixture advances real frame ID without moving arrow")
	untouched.bow.shoot()
	update_presentation(untouched)
	check(previous.presentation_origin_offset == Vector2.ZERO and previous.presentation_blend_distance == 0.0,
		"Older stationary primary is never mistaken for a new arrow")
	check((untouched.arrows.get_child(1) as BowArrow).presentation_blend_distance > 0.0, "Current-frame primary still receives handoff")
	untouched.free()

func test_convergence_and_range() -> void:
	var host := Node2D.new()
	root.add_child(host)
	host.process_mode = Node.PROCESS_MODE_DISABLED
	var plain := BowArrow.new()
	var cosmetic := BowArrow.new()
	for arrow in [plain, cosmetic]:
		arrow.direction = Vector2.UP
		arrow.position = Vector2(300, 300)
		arrow.speed = 100.0
		arrow.max_range = 80.0
		arrow.arena_bounds = Rect2(0, 0, 1000, 1000)
		host.add_child(arrow)
	cosmetic.presentation_origin_offset = Vector2(8, 0)
	cosmetic.presentation_blend_distance = 24.0
	for delta in [0.12, 0.12, 0.56]:
		plain._physics_process(delta)
		cosmetic._physics_process(delta)
		check(arrow_snapshot(plain) == arrow_snapshot(cosmetic), "Visual fade never changes swept path, traveled distance, or retirement")
		if cosmetic.traveled < 24.0:
			var effective := cosmetic.presentation_origin_offset * (1.0 - cosmetic.traveled / cosmetic.presentation_blend_distance)
			near(effective.length(), 4.0, "Half-distance sample has half visual correction")
		else:
			check(cosmetic.presentation_origin_offset == Vector2.ZERO, "Origin offset converges to exact zero at blend distance")
	check(cosmetic.retired and cosmetic.traveled == 80.0 and cosmetic.position == Vector2(300, 220), "Retirement occurs at unchanged logical range endpoint")
	host.free()

func logic_tick(arena: RageArena, visual: bool) -> void:
	arena.bow._physics_process(DT)
	# Match gameplay priority classes: gravity arrows, enemies, ordinary arrows.
	for arrow: BowArrow in arena.arrows.get_children():
		if arrow.gravity_field != null: arrow._physics_process(DT)
	for enemy: EnemyActor in arena.enemies.get_children(): enemy._physics_process(DT)
	for arrow: BowArrow in arena.arrows.get_children():
		if arrow.gravity_field == null: arrow._physics_process(DT)
	arena.element_procs._physics_process(DT)
	if visual: update_presentation(arena)

func test_logical_equivalence() -> void:
	var configurations: Array[Dictionary] = [{}, {"pierce": 3}, {"spread_arrow": 3}, {"burst": 3},
		{"pierce": 3, "spread_arrow": 2, "burst": 3, "split": 3}]
	for element in ["fire", "lightning", "ice", "dark"]:
		var ranks := {"pierce": 3, "spread_arrow": 2, "burst": 3, "split": 3}
		ranks[element + "_enchant"] = 3
		ranks[element + "_bow"] = 3
		configurations.append(ranks)
	for ranks in configurations:
		var baseline := make_arena(false, ranks)
		var presented := make_arena(true, ranks)
		for arena in [baseline, presented]:
			for offset in [Vector2(180, 0), Vector2(245, 12), Vector2(295, -18)]: add_target(arena, offset)
		var corrected_primary_seen := false
		for tick_index in range(120):
			logic_tick(baseline, false)
			logic_tick(presented, true)
			check(snapshot(baseline) == snapshot(presented), "Presentation-on/off logical snapshot matches %s tick %d" % [ranks, tick_index])
			for arrow: BowArrow in presented.arrows.get_children():
				if not arrow.presentation_origin_offset.is_zero_approx(): corrected_primary_seen = true
				if arrow.secondary or arrow.gravity_field != null:
					check(arrow.presentation_origin_offset == Vector2.ZERO, "Split/gravity stays unshifted throughout actual collision/effect simulation")
		if not presented.stats.gravity_mode(): check(corrected_primary_seen, "Non-gravity comparison actually exercises cosmetic handoff")
		else: check(not corrected_primary_seen, "Gravity comparison remains entirely unshifted")
		check(baseline.hits > 0 and presented.hits == baseline.hits, "Comparison includes resolved direct impacts, not merely empty flight")
		baseline.free()
		presented.free()
		await process_frame

func run() -> void:
	test_eight_directions()
	test_suppression_and_limits()
	await test_old_arrow_handoff()
	test_convergence_and_range()
	await test_logical_equivalence()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("ARCHER PROJECTILE PRESENTATION: %d checks, %d failures; 8 first-frame directions, exclusions, bounds, fade/range, 9 x 120 logical ticks" % [checks, failures])
	quit(1 if failures else 0)
