extends SceneTree
## Presentation contracts, not visual release certification. Rendered review is separate.
var checks := 0
var failures := 0
var impacts := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/bosses/wildfire/skyfire_hazard.gd")
	var ring_source := FileAccess.get_file_as_string("res://scripts/bosses/wildfire/fire_ring.gd")
	check(source.contains("HazardWarningVisual.draw_circle_warning(self, radius, fraction, false)"), "skyfire uses shared restrained landing warning styling")
	check(not source.contains("draw_circle(") and not source.contains("draw_arc("), "skyfire does not hardcode legacy filled circles or timer styling")
	check(source.find("HazardWarningVisual.draw_circle_warning") < source.find("if fall_progress <= 0.0: return"), "simple warning remains visible before falling mass appears")
	check(not ring_source.contains("draw_arc"), "fire ring no longer overlays mechanical core outlines")
	var original := VfxAtlasRenderer.library
	var tuned := original.duplicate(true) as VfxAtlasLibrary
	tuned.skyfire_ground_opacity = .51
	tuned.fire_ring_surface_opacity = .67
	tuned.skyfire_fall_start = .3
	tuned.skyfire_fall_exponent = 2.0
	VfxAtlasRenderer.library = tuned
	var sky := SkyfireHazard.new()
	sky.position = Vector2(150,200)
	sky.radius = 70.0
	sky.warning = 1.2
	sky.burn_duration = 3.0
	sky.arena_bounds = Rect2(10,20,800,600)
	sky.impact.connect(func(_hazard: SkyfireHazard): impacts += 1)
	root.add_child(sky)
	sky.set_physics_process(false)
	check(sky.ground_surface.show_behind_parent, "burning ground stays below the impact and low flames")
	check(sky.ground_surface.polygon.size() == 4, "ground material is one bounded quad")
	check(sky.ground_material.get_shader_parameter("arena_rect") == Vector4(10,20,800,600), "heat and ash clip at arena boundary")
	check(not sky.ground_surface.visible, "warning starts with no heat or ash material beneath the simple marker")
	check(is_equal_approx(sky.ground_material.get_shader_parameter("ground_opacity"),.51), "scorch opacity uses resource")
	sky.radius = 90.0
	check(sky.ground_surface.polygon[0] == Vector2(-90,-90), "ground footprint responds to radius changes")
	check(sky.ground_material.get_shader_parameter("hazard_radius") == 90.0, "shader uses exact gameplay radius")
	check(sky.visual_fall_progress(.29) == 0.0, "mass waits while the simple landing marker is visible")
	check(is_equal_approx(sky.visual_fall_progress(.65),.25), "mass uses configured acceleration")
	check(sky.visual_fall_progress(1.0) == 1.0, "mass reaches ground at exact original impact time")
	seed(9182)
	var expected := randi()
	seed(9182)
	for i in range(100): sky.visual_fall_progress(float(i)/100)
	check(randi() == expected, "visual fall does not touch combat RNG")
	sky.ai_enabled = false
	sky._physics_process(.9)
	check(sky.elapsed == 0.0 and sky.ground_material.get_shader_parameter("phase") == 0.0, "stopped AI pauses heat animation")
	sky.ai_enabled = true
	sky._physics_process(1.19)
	check(not sky.burning() and impacts == 0, "warning never starts damage early")
	check(not sky.ground_surface.visible, "heat and ash stay hidden for the full pre-impact warning")
	sky._physics_process(.01)
	check(sky.burning() and impacts == 1, "impact stays at unchanged deadline")
	check(sky.ground_material.get_shader_parameter("active") and sky.ground_surface.visible, "burning material appears exactly on impact")
	check(sky.contains(sky.global_position + Vector2(90,0),0), "original inclusive hazard edge still hits")
	check(not sky.contains(sky.global_position + Vector2(90.1,0),0), "decorative material cannot enlarge damage")
	sky._physics_process(2.99)
	check(sky.burning() and sky.ground_surface.visible, "footprint remains until end of burning window")
	sky._physics_process(.02)
	check(sky.is_queued_for_deletion() and not sky.burning(), "original burn deadline removes hazard")
	var splash := SkyfireHazard.new()
	splash.splash = true
	splash.radius = 40.0
	splash.warning = .6
	root.add_child(splash)
	splash.set_physics_process(false)
	check(not splash.ground_surface.visible, "splash uses the same simple warning without material overlap")
	splash._physics_process(.59)
	check(not splash.ground_surface.visible and not splash.burning(), "splash warning remains material-free until original deadline")
	splash._physics_process(.01)
	check(splash.ground_surface.visible and splash.burning(), "splash retains the new post-impact burning material")
	check(splash.ground_material.get_shader_parameter("hazard_radius") == 40.0 and splash.contains(splash.global_position+Vector2(40,0),0) and not splash.contains(splash.global_position+Vector2(40.1,0),0), "splash visual and damage radii remain unchanged")
	splash.queue_free()
	var ring := BossFireRing.new()
	ring.ring_radius = 100.0
	ring.width = 28.0
	ring.arena_bounds = Rect2(10,20,800,600)
	root.add_child(ring)
	ring.set_physics_process(false)
	check(ring.flame_band.show_behind_parent, "unbroken band persists below optional atlas detail")
	check(ring.flame_material.get_shader_parameter("band_width") == 28.0, "flame material uses exact unchanged band width")
	check(is_equal_approx(ring.flame_material.get_shader_parameter("opacity"),.67), "ring density opacity uses resource")
	ring.ai_enabled = false
	ring._physics_process(1.0)
	check(ring.ring_radius == 100.0, "stopped ring does not move")
	ring.ai_enabled = true
	ring._physics_process(.5)
	check(ring.ring_radius == 190.0 and ring.width == 28.0, "expansion speed and width unchanged")
	check(ring.flame_material.get_shader_parameter("ring_radius") == 190.0, "material tracks actual collision radius")
	check(ring.flame_band.polygon[0] == Vector2(-204,-204), "render quad includes exactly outer collision edge")
	check(BossFireRing.swept_band_hit(Vector2(190,0),Vector2(190,0),190,190,14), "original ring center still hits")
	check(not BossFireRing.swept_band_hit(Vector2(175,0),Vector2(175,0),190,190,14), "inner region stays safe")
	check(not BossFireRing.swept_band_hit(Vector2(205,0),Vector2(205,0),190,190,14), "outer region stays safe")
	# Exhaust even the renderer's minimum-one guard. The critical owned surface
	# remains exact-width when zero decorative draws are left this frame.
	tuned.boss_quad_budget = 0
	VfxAtlasRenderer._frame = Engine.get_process_frames()
	VfxAtlasRenderer._boss_draws = 1
	check(not VfxAtlasRenderer._reserve(true), "zero remaining boss atlas budget rejects decorative layers")
	check(VfxAtlasRenderer.draw_ring(ring, &"fire_ring", 1.0, ring.ring_radius, ring.width, Color.WHITE, true), "budget-exhausted ring gracefully skips only its optional atlas")
	check(not ring.has_meta(&"vfx_ring_meshes"), "no atlas mesh was created with exhausted budget")
	ring._update_flame_band()
	check(ring.flame_band.visible and ring.flame_material.get_shader_parameter("band_width") == 28.0, "uncullable material retains full exact width with zero decorative budget")
	var ring_shader := FileAccess.get_file_as_string("res://shaders/fire_ring_surface.gdshader")
	check(ring_shader.contains("full_width_envelope=1.0-smoothstep(.86,1.0,across)"), "fixed full-width envelope reaches the actual band boundary")
	check(ring_shader.contains("continuous_bed=full_width_envelope*(.20+.06*flecks)"), "full-width fallback is a nonzero textured density bed, not a rim stroke")
	check(ring_shader.contains("envelope=max(continuous_bed,irregular_flame)"), "inward decorative fringe cannot erase the full-width safety bed")
	for across: float in [.0,.5,.76,.9,.98,.995]:
		check((1.0-smoothstep(.86,1.0,across))*.20 > 0.0, "continuous fallback coverage exists inside the exact band at %.3f" % across)
	tuned.enabled = false
	ring._update_flame_band()
	check(ring.flame_band.visible and sky.ground_surface.visible, "atlas toggle cannot hide full danger footprint")
	for path in ["res://shaders/fire_ground_surface.gdshader", "res://shaders/fire_ring_surface.gdshader"]:
		var shader := FileAccess.get_file_as_string(path)
		check(not shader.contains("TIME"), "fire shaders use simulation clocks")
		check(shader.contains("world_position"), "fire material has world boundary clipping")
	var wildfire_source := FileAccess.get_file_as_string("res://scripts/bosses/wildfire/wildfire.gd")
	check(not wildfire_source.contains("draw_arc"), "ring release warning has no remaining rigid circle")
	var boss := Wildfire.new()
	root.add_child(boss)
	boss.set_physics_process(false)
	boss.position = Vector2(200,200)
	boss.ring_center = Vector2(240,200)
	boss.state = "ring_warning"
	boss.phase_time = boss.boss_definition.ring_warning
	boss._sync_ring_warning_surface()
	check(boss._ring_warning_surface.visible, "full ring warning exists from start of original warning")
	check(boss._ring_warning_surface.position == Vector2(40,0), "launch footprint follows locked ring center")
	check(boss._ring_warning_material.get_shader_parameter("band_width") == boss.boss_definition.ring_width, "launch warning uses exact future collision band width")
	check(boss.phase_time == boss.boss_definition.ring_warning and boss.rings_released == 0, "warning material cannot advance ring release")
	boss.state = "ring_gap"
	boss._sync_ring_warning_surface()
	check(not boss._ring_warning_surface.visible, "launch footprint hides when original release ends warning")
	boss.state = "ring_warning"
	boss._sync_ring_warning_surface()
	boss.ai_enabled = false
	boss.reset_state()
	check(not boss._ring_warning_surface.visible and boss.state == "recovery", "paused practice reset clears old ring-warning surface without requiring another frame")
	boss.queue_free()
	ring.queue_free()
	await process_frame
	check(not is_instance_valid(sky) and not is_instance_valid(ring), "owned presentation layers die with their hazards")
	VfxAtlasRenderer.library = original
	print("FIRE MATERIAL VISUALS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
