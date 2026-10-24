extends SceneTree
## Direction, reset and gameplay-isolation coverage for the character presentation.
var checks := 0
var failures := 0
const UPPER_CLIPS := ["carry", "raise", "lower", "lower_loaded", "controlled_undraw", "normal_release", "normal_renock", "normal_draw", "short_release", "short_recover", "short_draw", "hold_relaxed", "hold_relaxed_loaded", "short_undraw"]

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("EIGHT-DIRECTION AUDIT: " + label)

func near(actual: float, expected: float, label: String) -> void:
	check(absf(actual - expected) < 0.000002, label)

func texture(color: Color) -> ImageTexture:
	var pixels := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	pixels.fill(color)
	return ImageTexture.create_from_image(pixels)

func appearance() -> ArcherAppearanceDefinition:
	var definition := ArcherAppearanceDefinition.new()
	definition.upper = ArcherPoseLibrary.new()
	definition.lower = ArcherPoseLibrary.new()
	for library in [definition.upper, definition.lower]:
		library.canvas_size = Vector2i(4, 4)
		library.pivot = Vector2(2, 2)
		library.colors = SpriteFrames.new()
		library.depths = SpriteFrames.new()
	var white := texture(Color.WHITE)
	var carry := texture(Color.GREEN)
	var depth := texture(Color(0.5, 0.5, 0.5, 1))
	for direction in definition.direction_names:
		for suffix in UPPER_CLIPS:
			var key := StringName(direction + "/" + suffix)
			definition.upper.colors.add_animation(key)
			definition.upper.depths.add_animation(key)
			definition.upper.colors.add_frame(key, carry if suffix == "carry" else white)
			definition.upper.depths.add_frame(key, depth)
		var lower_names: Array[String] = ["idle"]
		for suffix in definition.movement_clips: lower_names.append(suffix)
		for suffix in lower_names:
			var key := StringName(direction + "/" + suffix)
			definition.lower.colors.add_animation(key)
			definition.lower.depths.add_animation(key)
			definition.lower.colors.add_frame(key, white)
			definition.lower.depths.add_frame(key, depth)
			definition.gait_bobs[key] = PackedVector2Array([Vector2(0, -1), Vector2(0, -3)])
		definition.idle_bobs[StringName(direction + "/idle")] = Vector2(0, -2)
	for i in range(64): definition.directional_strides.append(40.0 + float(i) * 2.0)
	return definition

func test_clock(definition: ArcherAppearanceDefinition) -> void:
	var clock := definition.create_pose_clock()
	check(clock.locomotion_directions == 8 and clock.directional_strides.size() == 64, "Factory copies 8 by 8 gait schema")
	for facing in range(8):
		for relative in range(8):
			clock.reset(Vector2.ZERO)
			clock.gait_phase = 0.375
			var aim := Vector2.from_angle(facing * TAU / 8.0)
			var motion := Vector2.from_angle((facing + relative) * TAU / 8.0)
			var stride := float(definition.directional_strides[facing * 8 + relative])
			clock.tick(0.02, motion * stride * 0.125, aim, false, 1000, 0.5, 0.55, false, true)
			check(clock.direction_index == facing and clock.locomotion_index == relative, "Correct quantized facing/movement slot %d/%d" % [facing, relative])
			near(clock.gait_phase, 0.5, "Correct projected stride slot %d/%d" % [facing, relative])
	clock.reset(Vector2.ZERO)
	var at := Vector2.ZERO
	clock.gait_phase = 0.94
	var expected := 0.94
	for facing in range(8):
		var relative := (facing + 3) % 8
		var stride := float(definition.directional_strides[facing * 8 + relative])
		at += Vector2.from_angle((facing + relative) * TAU / 8.0) * stride * 0.1
		clock.tick(0.02, at, Vector2.from_angle(facing * TAU / 8.0), false, 1000, 0.5, 0.55, false, true)
		expected = fposmod(expected + 0.1, 1.0)
		near(clock.gait_phase, expected, "Octant switches preserve and wrap one gait clock %d" % facing)
	clock.reset(Vector2.ZERO)
	var stride := float(definition.directional_strides[1])
	clock.tick(0.02, Vector2.from_angle(deg_to_rad(23.0)) * stride * 0.1,
		Vector2.from_angle(deg_to_rad(20.0)), false, 1000, 0.5, 0.55, false, true)
	check(clock.direction_index == 0 and clock.locomotion_index == 1, "Relative movement uses rendered quantized facing, not unquantized aim")
	near(clock.gait_phase, 0.1, "Quantized-facing stride table drives phase")
	clock.reset(Vector2.ZERO)
	clock.tick(0.02, Vector2(1, 0), Vector2.RIGHT, false, 1000, 0.5, 0.55, false, true)
	var before := clock.gait_phase
	clock.tick(0.02, Vector2(1, 9), Vector2.ZERO, false, 1000, 0.5, 0.55, false, true)
	check(clock.direction_index == 0 and clock.locomotion_index == 2, "Zero aim preserves facing but still resolves changed actual movement")
	near(clock.gait_phase, before + 9.0 / definition.directional_strides[2], "Zero aim still selects current movement stride")
	before = clock.gait_phase
	clock.tick(0.02, Vector2(25, 9), Vector2.LEFT, true, 1000, 0.5, 0.55, false, true)
	near(clock.gait_phase, before, "Dash changes visual facing without advancing walking feet")
	clock.tick(0.0, Vector2(25, 9), Vector2.LEFT, false, 1000, 0.5, 0.55, false, true)
	near(clock.gait_phase, before, "Zero movement and zero delta do not advance gait")
	clock.notify_release()
	clock.tick(0.02, Vector2(1000, 1000), Vector2.RIGHT, false, 20, 0.55, 0.55, true, true)
	check(clock.gait_phase == 0.0 and clock.pose == "release", "Teleport resets gait while preserving this tick's true release")
	clock.notify_release()
	clock.reset(Vector2(30, 40))
	check(clock.gait_phase == 0.0 and clock.pose == "rest" and not clock._release_pending, "Explicit reset clears phase and old release")
	var other := definition.create_pose_clock()
	clock.directional_strides[0] = 999.0
	check(other.directional_strides[0] == definition.directional_strides[0] and definition.directional_strides[0] == 40.0, "Stride tables are independent configuration copies")
	other.directional_strides[0] = 0.0
	other.reset(Vector2.ZERO)
	other.tick(0.02, Vector2(definition.stride_pixels * 0.1, 0), Vector2.RIGHT, false, 1000, 0.5, 0.55, false, true)
	near(other.gait_phase, 0.1, "Missing/nonpositive stride falls back to authored default")

func make_arena(definition: ArcherAppearanceDefinition = null) -> RageArena:
	var arena := RageArena.new()
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = 81963
	# Always author the fixture explicitly. The shipped default scene now has
	# artwork, whereas the null case must remain a genuine no-presentation control.
	var actor := Archer.new()
	actor.appearance = definition
	var packed := PackedScene.new()
	check(packed.pack(actor) == OK, "Test packs explicit optional appearance on actor")
	actor.free()
	var character := (load("res://resources/characters/archer.tres") as CharacterDefinition).duplicate(true) as CharacterDefinition
	character.actor_scene = packed
	arena.character_definition = character
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.spawn_enemy("dummy", arena.player.position + Vector2(100, 40))
	return arena

func combat_snapshot(arena: RageArena) -> Array:
	var result: Array = [arena.rng.state, arena.player.position, arena.player.aim_direction,
		arena.player.radius, arena.player.dash_left, arena.player.dash_cooldown,
		arena.bow.attack_clock, arena.bow.burst_clock, arena.bow.burst_remaining,
		arena.bow.gravity_gap_remaining, arena.stats.hp, arena.stats.shields, arena.hits,
		arena.total_damage, arena.stats.arrow_spawn_offset, arena.stats.move_speed]
	for arrow in arena.arrows.get_children():
		result.append([arrow.position, arrow.direction, arrow.damage_scale, arrow.speed, arrow.max_hits, arrow.traveled, arrow.is_queued_for_deletion()])
	for enemy in arena.enemies.get_children(): result.append(enemy.health)
	return result

func visual_snapshot(presentation: ArcherPresentation) -> Array:
	return [presentation.clock.gait_phase, presentation.clock.release_age, presentation.posture.height,
		presentation.posture.tension, presentation.selector.current_sample(), presentation.view.position]

func run() -> void:
	var definition := appearance()
	test_clock(definition)
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var missing := make_arena(ArcherAppearanceDefinition.new())
	var missing_presentation: ArcherPresentation = missing.player._presentation
	missing_presentation.adapter._physics_process(1.0 / 60.0)
	missing_presentation._physics_process(1.0 / 60.0)
	check(not missing_presentation.has_visible_pose() and not missing_presentation._feedback.visible,
		"Missing appearance frames leave actor fallback active without duplicate feedback")
	missing.free()
	var recoverable := make_arena(appearance())
	var recoverable_presentation: ArcherPresentation = recoverable.player._presentation
	recoverable_presentation.adapter._physics_process(1.0 / 60.0)
	recoverable_presentation._physics_process(1.0 / 60.0)
	check(recoverable_presentation.has_visible_pose() and recoverable_presentation._feedback.visible,
		"Valid optional presentation owns body and feedback")
	var chosen_clip: StringName = recoverable_presentation.selector.current_sample().clip
	var original_depth := recoverable_presentation.appearance.upper.depths.get_frame_texture(chosen_clip, 0)
	recoverable_presentation.appearance.upper.depths.set_frame(chosen_clip, 0, null)
	recoverable_presentation._physics_process(1.0 / 60.0)
	check(not recoverable_presentation.has_visible_pose() and not recoverable_presentation._feedback.visible,
		"A missing current frame clears view and restores fallback predicate")
	recoverable_presentation.appearance.upper.depths.set_frame(chosen_clip, 0, original_depth)
	recoverable_presentation._physics_process(1.0 / 60.0)
	check(recoverable_presentation.has_visible_pose() and recoverable_presentation._feedback.visible,
		"Restoring frame recovers presentation without rebuilding combat actor")
	recoverable.free()
	for ranks in [{}, {"burst":3, "spread_arrow":2}, {"dark_enchant":3, "dark_bow":3}]:
		var baseline := make_arena()
		var presented := make_arena(definition)
		baseline.apply_ranks(ranks)
		presented.apply_ranks(ranks)
		var p: ArcherPresentation = presented.player._presentation
		check(p != null and p.adapter.weapon == presented.bow, "Arena scene hook binds optional presentation")
		check(p.adapter.process_physics_priority > presented.bow.process_physics_priority and p.process_physics_priority > p.adapter.process_physics_priority, "Scheduling is bow then actor then adapter then selector/view")
		presented.player.bind_presentation_weapon(presented.bow, presented)
		check(presented.bow.volley_launched.get_connections().filter(func(c): return c.callable.get_object() == p.adapter).size() == 1, "Scene hook remains idempotent")
		Input.action_press("move_right")
		for i in range(120):
			if i == 40:
				Input.action_release("move_right")
				Input.action_press("move_down")
			if i == 80: Input.action_release("move_down")
			for arena in [baseline, presented]:
				arena.bow._physics_process(1.0 / 60.0)
				arena.player._physics_process(1.0 / 60.0)
				for arrow in arena.arrows.get_children(): arrow._physics_process(1.0 / 60.0)
			p.adapter._physics_process(1.0 / 60.0)
			p._physics_process(1.0 / 60.0)
			check(combat_snapshot(baseline) == combat_snapshot(presented), "Optional full scene presentation cannot change combat %s tick %d" % [ranks, i])
		check(p.view._drawable, "Synthetic complete 8-direction data stays drawable")
		check(baseline.player._presentation == null, "Absent appearance retains existing fallback actor")
		baseline.free()
		presented.free()
		await process_frame

	# Real SceneTree pause and real practice death, not a direct guarded reset call.
	var arena := make_arena(definition)
	var presentation: ArcherPresentation = arena.player._presentation
	arena.process_mode = Node.PROCESS_MODE_PAUSABLE
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	for _i in range(4): await physics_frame
	await process_frame
	check(presentation.view._drawable, "Actual scheduled scene hook renders a pose")
	paused = true
	var frozen := visual_snapshot(presentation)
	var frozen_combat := combat_snapshot(arena)
	await create_timer(0.08, true).timeout
	check(visual_snapshot(presentation) == frozen, "Pause freezes gait, posture, selector and bob together")
	check(combat_snapshot(arena) == frozen_combat, "Pause also freezes combat")
	# Make the stale display unmistakable: an actually selected loaded full draw,
	# a non-idle child offset, and a prior hurt tint. This is visual fixture setup,
	# not another weapon shot; the reset itself still follows real player death.
	presentation.selector.advance(0.0, "release", 0.0, "release", 1.0, 1.0, false, true)
	presentation.selector.advance(0.1, "recover", 1.0, "recover", 1.0, 0.0, false)
	presentation.selector.advance(0.1, "draw", 1.0, "draw", 1.0, 1.0, false)
	presentation.selector.advance(0.1, "draw", 1.0, "draw", 1.0, 1.0, false)
	var old_sample := presentation.selector.current_sample()
	presentation.view.show_pose(old_sample.clip, old_sample.phase, &"east/run_forward", 0.5, true, Vector2(7, 9))
	presentation.view.self_modulate = Color("ff8e98")
	check(old_sample.loaded and old_sample.phase == 1.0 and presentation.view.position == Vector2(7, 9),
		"Reset fixture starts with a loaded full draw and non-idle bob")
	# Exercise reset while paused so there is no following physics sample to hide
	# a stale texture/held arrow or lingering child bob.
	arena.player.invulnerable = false
	arena.player.receive_hit(100000.0)
	await process_frame
	await process_frame
	check(not presentation.adapter._pending and not presentation.adapter.fired_this_tick and presentation.clock.pose == "rest", "Real practice death clears adapter and shot clock")
	check(presentation.selector.current_sample().clip == &"east/carry" and not presentation.selector.loaded, "Real practice death resets selector and held arrow")
	var carry_key := StringName(presentation.appearance.direction_names[presentation.clock.direction_index] + "/carry")
	var idle_key := StringName(presentation.appearance.direction_names[presentation.clock.direction_index] + "/idle")
	var expected_carry: Texture2D = presentation.appearance.upper.sample(carry_key, 0.0).color.texture
	var expected_idle_bob: Vector2 = presentation.appearance.idle_bobs.get(idle_key, Vector2.ZERO)
	check(presentation.view._drawable and presentation.has_visible_pose() and presentation._feedback.visible,
		"Complete assets immediately retain human carry during paused reset")
	check(presentation.view._pose_material.get_shader_parameter("upper_color") == expected_carry,
		"Paused reset replaces old full-draw texture with current-direction carry")
	check(presentation.view.position == expected_idle_bob and presentation.view.position != Vector2(7, 9),
		"Paused reset uses authored idle bob, not stale walking bob or forced zero")
	check(presentation.view.self_modulate == Color.WHITE, "Paused practice reset removes previous hurt tint")
	check(presentation.clock._position == arena.player.position, "Reset position baseline matches final practice spawn")
	var held_carry := visual_snapshot(presentation)
	await create_timer(0.05, true).timeout
	check(visual_snapshot(presentation) == held_carry and presentation.view._pose_material.get_shader_parameter("upper_color") == expected_carry,
		"Paused reset carry stays stable without another physics sample")
	# Only incomplete assets should fall back, and later restoration remains safe.
	var carry_frames := presentation.appearance.upper.colors
	var saved_carry := carry_frames.get_frame_texture(carry_key, 0)
	carry_frames.set_frame(carry_key, 0, null)
	presentation.reset_pose()
	check(not presentation.has_visible_pose() and not presentation._feedback.visible and presentation.view.position == Vector2.ZERO,
		"Missing carry during paused reset clears stale body/bob and enables fallback")
	carry_frames.set_frame(carry_key, 0, saved_carry)
	presentation.reset_pose()
	check(presentation.has_visible_pose() and presentation.view.position == expected_idle_bob and not presentation.selector.loaded,
		"Restored paused reset returns to empty human carry with correct idle bob")
	paused = false
	for _i in range(3): await physics_frame
	await process_frame
	check(presentation.view._drawable and not presentation.selector.loaded, "Resume displays carry without resurrecting old arrow")
	await preload("res://tests/audio_teardown.gd").drain(self)
	arena.free()
	print("EIGHT-DIRECTION/SCENE AUDIT: %d checks, %d failures; 64 direction pairs, 3 x 120 combat ticks, real pause/reset" % [checks, failures])
	quit(1 if failures else 0)
