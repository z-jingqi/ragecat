extends SceneTree
## Presentation geometry and lifecycle only. Run the rendered fixtures separately
## to assess appearance; headless checks are not visual-release certification.
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var library := VfxAtlasRenderer.library
	var isolated := library.duplicate(true) as VfxAtlasLibrary
	VfxAtlasRenderer.library = isolated
	var field := GravityField.new()
	root.add_child(field)
	check(field._matter_surface != null and field._matter_surface.get_parent() == field._distortion_pass, "Dark material belongs to the field-managed refraction pass")
	var matter := field._matter_surface.material as ShaderMaterial
	for radii in [Vector2(140, 50), Vector2(160, 65), Vector2(180, 80)]:
		field.outer_radius = radii.x
		field.inner_radius = radii.y
		field._sync_matter_surface()
		check(is_equal_approx(field._matter_surface.radius, radii.x), "Material rectangle exactly uses attraction radius")
		check(field.inner_radius == radii.y, "Presentation sync cannot alter the gameplay damage radius")
		for sample in range(17):
			field.age = sample * 0.123
			field._sync_matter_surface()
			check(is_equal_approx(matter.get_shader_parameter("body_phase"), field.age * isolated.dark_body_flow_speed), "Continuous body is driven only by the simulation clock")
	field.global_position = Vector2(317, 244)
	check(field._matter_surface.global_position == field.global_position, "Material remains aligned after arrow moves")
	isolated.dark_refraction_pull = 11.0
	isolated.dark_refraction_swirl = 3.0
	isolated.dark_body_opacity = 0.73
	isolated.dark_body_shear = 2.7
	field._sync_matter_surface()
	check(is_equal_approx(matter.get_shader_parameter("pull_pixels"), 11.0), "Ground pull is resource-configured")
	check(is_equal_approx(matter.get_shader_parameter("swirl_pixels"), 3.0), "Ground swirl is resource-configured")
	check(is_equal_approx(matter.get_shader_parameter("body_opacity"), 0.73), "Body density is resource-configured")
	check(is_equal_approx(matter.get_shader_parameter("body_shear"), 2.7), "Body shear is resource-configured")
	seed(72419)
	var expected := randi()
	seed(72419)
	field._sync_matter_surface()
	check(randi() == expected, "Continuous body and ground refraction consume no gameplay RNG")
	field.deactivate()
	check(not field._matter_surface.visible, "Deactivation immediately hides material without adding a timer")
	var shader := load("res://shaders/dark_field_material.gdshader") as Shader
	check(not shader.code.contains("TIME") and shader.code.contains("hint_screen_texture"), "Ground refraction reads real pixels and uses simulation age only")
	check(shader.code.contains("length(p)") and shader.code.contains("radius >= 1.0"), "Body and refraction share the unwarped attraction boundary")
	var source := FileAccess.get_file_as_string("res://scripts/combat/gravity_field.gd")
	check(not source.contains("draw_arc(") and not source.contains("draw_circle(") and not source.contains("draw_polyline") and not source.contains("draw_clip"), "Dark body has no independent disc, lines or atlas branch")
	check(not shader.code.contains("core_shade") and shader.code.contains("trough_detail"), "Body contains advected inter-arm detail rather than a separate black centre")
	isolated.dark_body_opacity = 0.0
	field._sync_matter_surface()
	check(matter.get_shader_parameter("body_opacity") == 0.0, "Neutral UV proof can fully disable the continuous body")
	for spec in [["dark_body_opacity", "body_opacity", 1.5, 1.0], ["dark_body_extent", "body_extent", 9.0, 1.0], ["dark_body_scale", "body_scale", 999.0, 12.0], ["dark_body_shear", "body_shear", -5.0, 0.0]]:
		isolated.set(spec[0], spec[2])
		field._sync_matter_surface()
		check(is_equal_approx(matter.get_shader_parameter(spec[1]), spec[3]), "Hostile body tuning is bounded: " + spec[0])
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	enemy.set_physics_process(false)
	var frost := ElementStatusVisual.new()
	frost.setup(enemy)
	enemy.add_child(frost)
	frost.set_process(false)
	enemy.status.frozen_remaining = 1.0
	frost._process(frost.definition.freeze_growth_duration * 0.5)
	check(is_equal_approx(frost.freeze_coverage, 0.5), "Shell still grows with existing presentation duration")
	enemy.position = Vector2(123, 211)
	check(frost.global_position == enemy.global_position, "Growing ice shell stays actor-local")
	var sprite := Sprite2D.new()
	enemy.add_child(sprite)
	frost.bind_sprite(sprite)
	isolated.frost_tint_strength = 0.37
	isolated.frost_grain_scale = 31.0
	frost._sync_sprite()
	var sprite_material := sprite.material as ShaderMaterial
	check(is_equal_approx(sprite_material.get_shader_parameter("tint_strength"), 0.37), "Frost tint uses resource tuning")
	check(is_equal_approx(sprite_material.get_shader_parameter("noise_scale"), 31.0), "Frost facets use resource tuning")
	check(is_equal_approx(enemy.status.frozen_remaining, 1.0), "Visual growth does not consume gameplay freeze duration")
	enemy.status.consume_ice()
	frost._process(0.001)
	check(frost.freeze_coverage == 0.0, "Shatter cancels old shell immediately")
	# Exercise the production nesting, not only a field attached to a test root.
	# A negative descendant Z sorts behind RageArena's floor, making a working
	# material invisible despite passing isolated shader/geometry checks.
	var arena := RageArena.new()
	arena.practice = true
	arena.sound_enabled = false
	arena.run_seed_override = 0
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.apply_ranks({"element_type": "dark", "enchant_rank": 1, "element_skill_rank": 1})
	arena.player.position = Vector2(350, 350)
	arena.spawn_enemy("chaser", Vector2(600, 350))
	arena.bow.shoot()
	var arrow := arena.bow.active_gravity_arrow
	check(arrow != null and arrow.get_parent() == arena.arrows, "Production bow creates gravity arrow in arena projectile layer")
	if arrow != null:
		var actual_field := arrow.gravity_field
		var actual_surface := actual_field._matter_surface
		check(actual_field.get_parent() == arrow, "Actual field remains attached to moving arrow")
		check(actual_surface.z_index == 0 and actual_field._distortion_pass.get_parent() == arena.ground_distortions, "Ground refraction draws in the dedicated pre-actor layer")
		check(_effective_z(actual_surface) >= _effective_z(arena), "Actual field material cannot sort behind arena floor")
		check(arena.ground_distortions.get_index() < arena.enemies.get_index(), "Ground capture always precedes actor rendering")
		actual_field._sync_matter_surface()
		check(actual_surface.visible and actual_surface.radius == arena.stats.gravity_outer_radius, "Actual arena field owns a visible full-radius material")
	arena.free()
	var frost_shader := load("res://shaders/frost_overlay.gdshader") as Shader
	check(frost_shader.code.contains("vec4(iced, source.a)") and not frost_shader.code.contains("TIME"), "Frost preserves sprite alpha without an independent clock")
	enemy.free()
	field.free()
	VfxAtlasRenderer.library = library
	print("Ice/dark presentation contracts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _effective_z(item: CanvasItem) -> int:
	var result := item.z_index
	var current := item
	while current.z_as_relative and current.get_parent() is CanvasItem:
		current = current.get_parent() as CanvasItem
		result += current.z_index
	return result
