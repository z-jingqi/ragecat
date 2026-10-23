extends SceneTree
## Presentation integration must not change committed boss timing or hit geometry.
var checks := 0
var failures := 0
var impacts := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var rock := RockWarning.new()
	rock.arena_bounds = Rect2(0, 0, 1280, 800)
	rock.warning_duration = 1.0
	rock.aftermath_duration = 0.3
	rock.impact.connect(func(_center: Vector2, _radius: float) -> void: impacts += 1)
	world.add_child(rock)
	rock.set_physics_process(false)
	rock.ai_enabled = false
	rock._physics_process(0.5)
	check(rock.elapsed == 0.0 and impacts == 0, "disabled rock animation and impact remain frozen")
	rock.ai_enabled = true
	rock._physics_process(0.99)
	check(not rock.impacted and impacts == 0, "rock artwork cannot trigger early impact")
	rock._physics_process(0.01)
	check(rock.impacted and impacts == 1, "rock impact occurs exactly at existing clock")
	rock._physics_process(0.1)
	check(impacts == 1, "rock impact occurs once")
	check(rock.material is ShaderMaterial, "atlas uses existing rock world clip")
	check((rock.material as ShaderMaterial).get_shader_parameter("arena_rect") == Vector4(0, 0, 1280, 800), "rock clipping follows real arena")
	var rock_source := FileAccess.get_file_as_string("res://scripts/bosses/mountainbreaker/rock_warning.gd")
	check(rock_source.contains('-VfxAtlasRenderer.setting(&"rock_drop_height") * (1.0 - progress) - VfxAtlasRenderer.setting(&"rock_target_offset")'), "fall center uses configurable height and target offset with warning progress")
	check(rock_source.contains("Rect2(fall_center - Vector2.ONE * radius"), "falling atlas actually uses displaced center")
	var drop_height := VfxAtlasRenderer.setting(&"rock_drop_height")
	var target_offset := VfxAtlasRenderer.setting(&"rock_target_offset")
	check(is_finite(drop_height) and drop_height > 0.0, "production stone fall has positive travel")
	check(-drop_height - target_offset < -target_offset, "stone starts above its final target")
	var original_library := VfxAtlasRenderer.library
	var alternate_library := original_library.duplicate(true) as VfxAtlasLibrary
	alternate_library.rock_drop_height = 200.0
	alternate_library.rock_target_offset = 20.0
	VfxAtlasRenderer.library = alternate_library
	check(VfxAtlasRenderer.setting(&"rock_drop_height") == 200.0 and VfxAtlasRenderer.setting(&"rock_target_offset") == 20.0, "stone fall tuning reads changed resource values")
	var alternate_rock := RockWarning.new()
	alternate_rock.warning_duration = 1.0
	alternate_rock.aftermath_duration = 0.3
	world.add_child(alternate_rock)
	alternate_rock.set_physics_process(false)
	alternate_rock._physics_process(0.99)
	check(not alternate_rock.impacted, "larger visual fall does not advance damage timing")
	alternate_rock._physics_process(0.01)
	check(alternate_rock.impacted and alternate_rock.elapsed == 1.0, "larger visual fall does not delay damage timing")
	VfxAtlasRenderer.library = original_library
	alternate_library = null
	var sky := SkyfireHazard.new()
	sky.arena_bounds = rock.arena_bounds
	sky.warning = 1.0
	sky.burn_duration = 2.0
	world.add_child(sky)
	sky.set_physics_process(false)
	sky.ai_enabled = false
	sky._physics_process(1.0)
	check(sky.elapsed == 0.0 and not sky.burning(), "skyfire atlas does not run while AI stopped")
	sky.ai_enabled = true
	sky._physics_process(0.99)
	check(not sky.burning(), "skyfire still harmless during warning")
	sky._physics_process(0.01)
	check(sky.burning(), "skyfire hazard active at impact")
	check(sky.contains(sky.global_position + Vector2(sky.radius, 0), 0), "skyfire exact radius unchanged")
	check(not sky.contains(sky.global_position + Vector2(sky.radius + 1, 0), 0), "decorative glow cannot expand damage")
	check(sky.material is ShaderMaterial, "skyfire atlas inherits existing clip")
	var ring := BossFireRing.new()
	ring.arena_bounds = rock.arena_bounds
	ring.ring_radius = 100.0
	ring.width = 28.0
	world.add_child(ring)
	ring.set_physics_process(false)
	ring.ai_enabled = false
	ring._physics_process(1.0)
	check(ring.ring_radius == 100.0 and ring.width == 28.0, "ring frozen radius and width preserved")
	ring.ai_enabled = true
	ring._physics_process(0.5)
	check(ring.ring_radius == 190.0 and ring.width == 28.0, "ring radius expands without widening danger band")
	check(BossFireRing.swept_band_hit(Vector2(190, 0), Vector2(190, 0), 190, 190, 14), "ring band center still hits")
	check(not BossFireRing.swept_band_hit(Vector2(170, 0), Vector2(170, 0), 190, 190, 14), "ring inner interior remains safe")
	check(not BossFireRing.swept_band_hit(Vector2(210, 0), Vector2(210, 0), 190, 190, 14), "ring outside remains safe")
	var boss_bullet := EnemyBullet.new()
	boss_bullet.set_meta("boss_owner_id", 123)
	boss_bullet.arena_bounds = rock.arena_bounds
	world.add_child(boss_bullet)
	boss_bullet.set_physics_process(false)
	check(boss_bullet.material is ShaderMaterial, "boss orb glow clips to arena")
	var normal_bullet := EnemyBullet.new()
	normal_bullet.arena_bounds = rock.arena_bounds
	world.add_child(normal_bullet)
	normal_bullet.set_physics_process(false)
	check(normal_bullet.material == null, "ordinary Spitter remains unchanged")
	var bullet_source := FileAccess.get_file_as_string("res://scripts/projectiles/enemy_bullet.gd")
	check(bullet_source.contains('has_meta("boss_owner_id")'), "boss orb presentation explicitly scoped")
	check(bullet_source.contains("draw_arc(Vector2.ZERO, definition.bullet_radius,"), "boss orb silhouette marks full physical radius, independent of atlas padding")
	check(bullet_source.find("draw_arc(Vector2.ZERO, definition.bullet_radius,") < bullet_source.find("VfxAtlasRenderer.draw_clip(self, &\"energy_orb\""), "physical outline is retained before atlas budget early return")
	check(VfxAtlasRenderer.setting(&"projectile_boundary_opacity") > 0.0, "physical bullet outline is visible")
	check(VfxAtlasRenderer.setting(&"projectile_boundary_width") >= 0.5, "physical bullet outline has readable width")
	check(VfxAtlasRenderer.setting(&"projectile_size_factor") >= 1.0, "decorative orb rectangle cannot shrink below collision diameter")
	for path in ["res://scripts/bosses/mountainbreaker/rock_warning.gd", "res://scripts/bosses/mountainbreaker/mountainbreaker.gd", "res://scripts/bosses/beastcaller/beastcaller.gd", "res://scripts/bosses/wildfire/skyfire_hazard.gd", "res://scripts/bosses/wildfire/fire_ring.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(not source.contains("VfxAtlasRenderer.library."), "boss uses primitive tuning access without static Resource dependency cycles: " + path)
		check(source.contains("VfxAtlasRenderer.draw_"), "boss has atlas presentation: " + path)
		check(not source.contains("Time.get_ticks"), "boss atlas does not use unpausable wall time: " + path)
	world.queue_free()
	await process_frame
	print("Boss atlas checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures > 0 else 0)
