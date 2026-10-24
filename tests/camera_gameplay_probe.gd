extends SceneTree
## Diagnostic only: advances real attack scripts, reports exposure-to-contact.
## Geometric exposure is NOT pixel visibility: rendered screenshots remain required.
const DT := 1.0 / 120.0
var rows: Array[Dictionary] = []
var arena: RageArena
func _initialize() -> void: call_deferred("run")
func band_visible(center: Vector2, radius: float, width: float, view: Rect2) -> bool:
	var nearest := center.clamp(view.position, view.end).distance_to(center)
	var farthest := 0.0
	for corner in [view.position, view.end, Vector2(view.end.x, view.position.y), Vector2(view.position.x, view.end.y)]:
		farthest = maxf(farthest, center.distance_to(corner))
	return radius + width * 0.5 >= nearest and radius - width * 0.5 <= farthest
func run() -> void:
	root.size = Vector2i(1280,800)
	root.content_scale_size = Vector2i(1280,800)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	arena = RageArena.new()
	arena.practice = true
	arena.run_seed_override = 72103
	arena.sound_enabled = false
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.player.invulnerable = true
	arena.bow.enabled = false
	var points := [Vector2(640,400),Vector2(18,400),Vector2(1262,400),Vector2(640,18),Vector2(640,782),Vector2(18,18),Vector2(1262,18),Vector2(18,782),Vector2(1262,782)]
	for magnification in [2.0,2.3]:
		arena.follow_camera.set_magnification(magnification)
		for point: Vector2 in points:
			arena.player.position = point
			arena.follow_camera.sync_now()
			var view := arena.follow_camera.visible_world_rect()
			for direction_index in range(8):
				var direction := Vector2.from_angle(direction_index * TAU / 8.0)
				var source := (point + direction * 500.0).clamp(Vector2(40,40),Vector2(1240,760))
				if source.distance_to(point) < 80: continue
				var bullet := EnemyBullet.new()
				bullet.setup(source,source.direction_to(point),arena.ranged_definition,arena.player)
				bullet.arena_bounds = arena.bounds
				arena.enemy_bullets.add_child(bullet)
				var seen := -1.0
				var t := 0.0
				while not bullet.consumed and t < 5.0:
					if seen < 0 and view.grow(bullet.definition.bullet_radius).has_point(bullet.position): seen = t
					bullet._physics_process(DT)
					t += DT
				rows.append({"kind":"ranged_fireball","zoom":magnification,"player":str(point),"source":str(source),"source_offscreen":not view.has_point(source),"visible_flight_seconds":t-seen if seen>=0 else -1,"elapsed":t,"consumed":bullet.consumed})
				var ring := BossFireRing.new()
				ring.position = source
				ring.target = arena.player
				var ring_settings := preload("res://resources/bosses/wildfire.tres") as BossDefinition
				ring.speed = ring_settings.ring_speed
				ring.width = ring_settings.ring_width
				ring.ring_radius = ring_settings.ring_initial_radius
				ring.arena_bounds = arena.bounds
				arena.effects.add_child(ring)
				seen = -1.0
				t = 0.0
				while not ring.consumed and t < 10.0:
					if seen < 0 and band_visible(source,ring.ring_radius,ring.width,view): seen=t
					ring._physics_process(DT)
					t += DT
				rows.append({"kind":"wildfire_ring","zoom":magnification,"player":str(point),"source":str(source),"source_offscreen":not view.has_point(source),"visible_band_to_contact_seconds":t-seen if seen>=0 else -1,"contact":ring.consumed})
				ring.queue_free()
				await process_frame
			# Real Mountainbreaker state machine, with offscreen source chosen opposite target.
			var far_corner := Vector2(1230 if point.x <= 640 else 50,750 if point.y <= 400 else 50)
			var boss := arena.spawn_enemy("boss",far_corner) as Mountainbreaker
			boss.ai_enabled = true
			boss._start_charge_warning()
			var start := boss.charge_start
			var endpoint := boss.charge_end
			var warning_visible := false
			for sample in range(129):
				if view.grow(boss.charge_width * .5).has_point(start.lerp(endpoint,float(sample)/128.0)): warning_visible=true
			var warning_seconds := boss.phase_time
			var elapsed := 0.0
			while not boss.charge_hit and elapsed<5.0 and boss.state in ["warning","charge"]:
				boss._physics_process(DT)
				elapsed += DT
			rows.append({"kind":"mountainbreaker_charge","zoom":magnification,"player":str(point),"source_offscreen":not view.has_point(start),"path_intersects_view":warning_visible,"endpoint_visible":view.has_point(endpoint),"warning_seconds":warning_seconds,"actual_contact_seconds":elapsed,"contact":boss.charge_hit})
			for phase in [1,2]:
				boss.force_phase_for_practice(phase)
				boss._start_rocks()
				var warnings := boss.rocks.duplicate()
				for rock: RockWarning in warnings:
					if rock.impacted: continue
					var warning_time := rock.warning_duration - rock.elapsed
					var landing_visible := view.grow(rock.radius).has_point(rock.global_position)
					var dangerous := rock.global_position.distance_to(point) <= rock.radius + arena.player.radius
					var rock_time := 0.0
					while not rock.impacted and rock_time < 5.0:
						rock._physics_process(DT)
						rock_time += DT
					rows.append({"kind":"mountainbreaker_rock","phase":phase,"zoom":magnification,"player":str(point),"landing":str(rock.global_position),"dangerous_to_stationary_player":dangerous,"landing_warning_visible":landing_visible,"authored_warning_seconds":warning_time,"actual_impact_seconds":rock_time})
			arena.clear_enemies()
			await process_frame
			arena.practice_boss_identity = "wildfire"
			var wildfire := arena.spawn_enemy("boss",far_corner) as Wildfire
			wildfire.ai_enabled = true
			for phase in [1,2]:
				wildfire.force_phase_for_practice(phase)
				var skyfire := wildfire._create_skyfire(point,false)
				var impact_time := 0.0
				while not skyfire.impacted and impact_time < 5.0:
					skyfire._physics_process(DT)
					impact_time += DT
				rows.append({"kind":"wildfire_skyfire","phase":phase,"zoom":magnification,"player":str(point),"boss_offscreen":not view.has_point(wildfire.position),"landing_warning_visible":view.grow(skyfire.radius).has_point(skyfire.global_position),"actual_impact_seconds":impact_time})
			arena.clear_enemies()
			arena.practice_boss_identity = "mountainbreaker"
			await process_frame
	var out := OS.get_environment("CAMERA_PROBE_OUTPUT")
	if out.is_empty(): out="/tmp/camera_gameplay_probe.json"
	var file := FileAccess.open(out,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	file.close()
	print("CAMERA GAMEPLAY PROBE: ",rows.size()," measured real-script attack scenarios; geometric exposure only, pixel QA still required")
	arena.free()
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit()
