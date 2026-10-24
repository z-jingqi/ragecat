extends SceneTree
## Production scene, real attack objects and camera. No mock sprites or screenshots.
var game: Node
var arena: RageArena
var output := "/tmp/camera-gameplay-frames"
func _initialize() -> void:
	if not OS.get_environment("CAMERA_FRAME_OUTPUT").is_empty(): output=OS.get_environment("CAMERA_FRAME_OUTPUT")
	call_deferred("run")
func capture(name: String) -> void:
	arena.follow_camera.sync_now()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Real display required for gameplay visibility QA")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run(true,72103)
	game.return_from_practice_navigation()
	arena=game.arena
	arena.set_sound_enabled(false)
	arena.bow.enabled=false
	arena.player.invulnerable=true
	arena.player.movement_enabled=false
	paused=true
	var points := [Vector2(640,400),Vector2(18,18),Vector2(1262,782),Vector2(1262,18),Vector2(18,782)]
	for zoom_value in [2.0,2.3]:
		arena.follow_camera.set_magnification(zoom_value)
		for index in range(points.size()):
			var point: Vector2=points[index]
			arena.player.position=point
			arena.follow_camera.sync_now()
			var view:=arena.follow_camera.visible_world_rect()
			var prefix:="zoom%.1f_position%d_" % [zoom_value,index]
			var source:=Vector2(1230 if point.x<=640 else 50,750 if point.y<=400 else 50)
			arena.practice_boss_identity="mountainbreaker"
			var boss:=arena.spawn_enemy("boss",source) as Mountainbreaker
			boss.ai_enabled=true
			boss._start_charge_warning()
			boss._physics_process(.25)
			await capture(prefix+"01_charge_warning")
			boss._start_rocks()
			boss.queue_redraw()
			for rock: RockWarning in boss.rocks: rock._physics_process(.3)
			await capture(prefix+"02_rock_landing")
			arena.clear_enemies()
			await process_frame
			var ring:=BossFireRing.new()
			ring.target=arena.player
			ring.position=source
			ring.arena_bounds=arena.bounds
			arena.effects.add_child(ring)
			var edge_distance:=source.distance_to(source.clamp(view.position,view.end))
			ring._physics_process(maxf(0,edge_distance-ring.ring_radius)/ring.speed+.02)
			await capture(prefix+"03_ring_entering")
			ring._physics_process(maxf(0,source.distance_to(point)-ring.ring_radius-60)/ring.speed)
			await capture(prefix+"04_ring_approaching")
			ring.queue_free()
			await process_frame
			var origin:=(point+point.direction_to(source)*500).clamp(Vector2(40,40),Vector2(1240,760))
			var bullet:=EnemyBullet.new()
			bullet.setup(origin,origin.direction_to(point),arena.ranged_definition,arena.player)
			bullet.arena_bounds=arena.bounds
			arena.enemy_bullets.add_child(bullet)
			for tick in range(600):
				if view.grow(-8).has_point(bullet.position): break
				bullet._physics_process(1.0/120)
			await capture(prefix+"05_fireball_entering")
			for tick in range(600):
				if bullet.position.distance_to(point)<75 or bullet.consumed: break
				bullet._physics_process(1.0/120)
			await capture(prefix+"06_fireball_approaching")
			bullet.queue_free()
			await process_frame
			arena.practice_boss_identity="wildfire"
			var wildfire:=arena.spawn_enemy("boss",source) as Wildfire
			var skyfire:=wildfire._create_skyfire(point,false)
			skyfire._physics_process(.5)
			await capture(prefix+"07_skyfire_landing")
			arena.clear_enemies()
			await process_frame
	paused=false
	game.free()
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("CAMERA GAMEPLAY RENDER: 70 production-scene frames captured; visual review required")
	quit()
