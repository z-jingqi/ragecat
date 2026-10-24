extends SceneTree
var fails := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: fails += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var initial_budget := ArrowPresentation.active_trails
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		var arena := RageArena.new()
		arena.practice = true; arena.sound_enabled = false; arena.run_seed_override = 71137
		root.add_child(arena)
		arena.feedback.enabled = false
		arena.player.movement_enabled = false
		var target := arena.spawn_enemy("dummy", arena.player.position + Vector2(250, 100))
		target.health = 100000; target.max_health = 100000; target.ai_enabled = false
		var p: ArcherPresentation = arena.player._presentation
		check(p != null, "Production archer has presentation")
		p.appearance = p.appearance.duplicate(true)
		for i in range(p.appearance.muzzle_positions.size()):
			p.appearance.muzzle_positions[i] += Vector2(0, 100)
		var observed := 0
		var corrected := 0
		for tick in range(70):
			await physics_frame
			await process_frame
			for arrow: BowArrow in arena.arrows.get_children():
				observed += 1
				var visual: ArrowPresentation = arrow.get_node("Presentation")
				var expected := Vector2.ZERO
				if arrow.presentation_blend_distance > 0:
					expected = arrow.presentation_origin_offset.rotated(-arrow.rotation) * (1.0-clampf(arrow.traveled/arrow.presentation_blend_distance,0,1))
					if not expected.is_zero_approx(): corrected += 1
				if not visual.position.is_equal_approx(expected): print("MISMATCH hz=",hz," tick=",tick," spawn=",arrow.presentation_spawn_frame," frame=",Engine.get_physics_frames()," actual=",visual.position," expected=",expected," traveled=",arrow.traveled," blend=",arrow.presentation_blend_distance," points=",visual.points.size())
				check(visual.position.is_equal_approx(expected), "Actual scheduled muzzle offset synchronized %dHz frame%d" % [hz,tick])
				check(arrow.rotation == arrow.direction.angle(), "Actual scheduled arrow orientation")
				check(visual.points.size() <= 6, "Actual scheduled trail cap")
				if not visual.points.is_empty(): check(visual.points[-1].distance_to(visual.to_global(visual.definition.tail_position)) < .001, "Tail newest point attaches after handoff")
		print("SCHEDULE hz=",hz," observed=",observed," corrected=",corrected)
		check(observed > 0, "Real bow emitted arrows")
		check(corrected > 0, "Real visual handoff exercised")
		arena.free()
		await process_frame
		check(ArrowPresentation.active_trails == initial_budget, "Arena free releases entire trail budget")
	Engine.physics_ticks_per_second = 60
	print("ARROW_SPAWN_FRAME: %d checks, %d failures" % [checks,fails])
	quit(fails)
