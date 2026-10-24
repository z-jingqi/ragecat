extends SceneTree
## Complete pose-selection gate. No runtime fallback qualifies as an authored dash.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("DASH DIRECTIONS: " + label)
func run() -> void:
	var arena := RageArena.new()
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = 89134
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var presentation: ArcherPresentation = arena.player._presentation
	var motion := presentation.appearance.dash_motion
	var rng_state := arena.rng.state
	var position := arena.player.position
	var hp := arena.stats.hp
	var arrow_count := arena.arrows.get_child_count()
	for aim in range(8):
		var direction: String = presentation.appearance.direction_names[aim]
		for relative in range(8):
			presentation.reset_pose()
			presentation.clock.direction_index = aim
			presentation.clock.moving = true
			presentation.posture.height = 1.0
			presentation.adapter.fired_this_tick = false
			arena.player.dash_direction = Vector2.RIGHT.rotated((aim + relative) * TAU / 8.0)
			var clip := StringName(direction + "/dash_" + str(relative))
			var selected := {"clip": StringName(direction + "/normal_release"), "phase": 0.0}
			for normalized in [0.0, 0.17, 0.36, 0.56, 0.78, 0.999]:
				arena.player.dash_left = arena.stats.dash_duration * (1.0 - normalized)
				check(presentation._show_dash_pose(1.0 / 60.0, selected), "Pose exists: " + str(clip))
				check(presentation._dash_clip == clip, "Relative travel maps to exact clip")
				var sample := motion.body.sample(clip, motion.sample_phase(normalized))
				check(not sample.is_empty(), "Authored sample exists, no fallback")
				if sample.is_empty(): continue
				var material := presentation.view._pose_material
				check(material.get_shader_parameter("lower_color") == sample.color.texture, "Actual shader uses selected direction atlas")
				check(material.get_shader_parameter("lower_region") == sample.color.region, "Actual shader uses selected frame rectangle")
				check(not material.get_shader_parameter("single_layer"), "Shooting keeps independent upper-body cycle")
			arena.player.dash_left = 0.0
			check(not presentation._show_dash_pose(1.0 / 60.0, selected), "Moving shot resumes locomotion immediately")
			check(is_equal_approx(presentation.clock.gait_phase, motion.gait_entry_phases.get(clip, -1.0)), "Correct support-foot gait handoff")
		presentation.reset_pose()
		presentation.clock.direction_index = aim
		presentation.posture.height = 0.0
		presentation.adapter.fired_this_tick = false
		arena.player.dash_direction = Vector2.RIGHT.rotated(aim * TAU / 8.0)
		arena.player.dash_left = arena.stats.dash_duration
		var carried := {"clip": StringName(direction + "/carry"), "phase": 0.0}
		check(presentation._show_dash_pose(1.0 / 60.0, carried), "Guard exists in every true camera direction")
		check(presentation.view._pose_material.get_shader_parameter("single_layer"), "Guard uses coherent whole-body pose")
		presentation.adapter.fired_this_tick = true
		check(presentation._show_dash_pose(1.0 / 60.0, {"clip": StringName(direction + "/normal_release"), "phase": 0.0}), "Actual fire interrupts guard in every direction")
		check(not presentation._dash_guard and not presentation.view._pose_material.get_shader_parameter("single_layer"), "No hidden or delayed firing pose")
	# Each camera has an independently validated planted-foot walking entry.
	for aim in range(8):
		var direction: String = presentation.appearance.direction_names[aim]
		presentation.reset_pose()
		presentation.clock.direction_index = aim
		presentation.clock.moving = true
		presentation.posture.height = 0.0
		presentation.adapter.fired_this_tick = false
		arena.player.dash_direction = Vector2.RIGHT.rotated(aim * TAU / 8.0)
		arena.player.dash_left = arena.stats.dash_duration
		var carry := {"clip": StringName(direction + "/carry"), "phase": 0.0}
		presentation._show_dash_pose(1.0 / 60.0, carry)
		arena.player.dash_left = 0.0
		for frame in range(12):
			arena.player.position += arena.player.dash_direction * 230.0 / 60.0
			if not presentation._show_dash_pose(1.0 / 60.0, carry): break
		var move_clip := StringName(direction + "/guard_move")
		check(not presentation._dash_move_recovery, "Guard moving recovery completes in every camera")
		check(is_equal_approx(presentation.clock.gait_phase, motion.guard_move_exit_phases.get(move_clip,-1.0)), "Camera-specific walking entry, not hardcoded east phase")
		arena.player.position = position
	check(arena.rng.state == rng_state and arena.player.position == position and arena.stats.hp == hp, "Visual direction sampling does not mutate combat")
	check(arena.arrows.get_child_count() == arrow_count, "No visual sample emits a projectile")
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("ARCHER DASH DIRECTIONS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
