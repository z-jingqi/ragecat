extends SceneTree
## Continuous production simulation: --fixed-fps 30 --script this file.
## Captures actual movement/dash, true pause, and real window resize without teleporting.
var output := "/tmp/camera-follow-motion"
var game: Node
var arena: RageArena
var failures := 0
var checks := 0
var samples: Array[Dictionary] = []
func _initialize() -> void:
	if not OS.get_environment("CAMERA_MOTION_OUTPUT").is_empty(): output=OS.get_environment("CAMERA_MOTION_OUTPUT")
	call_deferred("run")
func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)
func release_movement() -> void:
	for action in ["move_left","move_right","move_up","move_down","dash"]: Input.action_release(action)
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Continuous camera review requires real rendering")
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
	arena.clear_enemies()
	var pause_position:=Vector2.ZERO
	var previous_player:=arena.player.position
	var previous_camera:=arena.follow_camera.global_position
	for frame in range(360):
		match frame:
			0: Input.action_press("move_right")
			30: Input.action_press("dash")
			31: Input.action_release("dash")
			90:
				release_movement()
				Input.action_press("move_down")
			120: Input.action_press("dash")
			121: Input.action_release("dash")
			150:
				paused=true
				pause_position=arena.player.position
			180:
				check(arena.player.position==pause_position,"True pause leaves player stationary despite held input")
				game.window_settings.begin_preview(WindowSettingsController.WINDOWED,Vector2i(960,600))
			190:
				if not game.window_settings.apply_pending: game.window_settings.confirm_preview()
				paused=false
				release_movement()
				Input.action_press("move_left")
			210: Input.action_press("dash")
			211: Input.action_release("dash")
			240:
				game.window_settings.begin_preview(WindowSettingsController.WINDOWED,Vector2i(1152,720))
			250:
				if not game.window_settings.apply_pending: game.window_settings.confirm_preview()
			270:
				release_movement()
				Input.action_press("move_up")
			300: Input.action_press("dash")
			301: Input.action_release("dash")
		await process_frame
		await RenderingServer.frame_post_draw
		var position_now:Vector2=arena.player.position
		var camera_now:Vector2=arena.follow_camera.global_position
		var expected:=ArenaFollowCamera.clamped_center(position_now,arena.follow_camera.presentation_bounds(),arena.follow_camera.visible_world_rect().size)
		check(camera_now.distance_to(expected)<0.1,"Camera follows without lag or overshoot")
		check(arena.bounds==Rect2(0,0,1280,800) and arena.player.arena_bounds==arena.bounds,"Movement and viewport changes preserve physical world")
		if frame>0 and frame not in [180,181,182,240,241,242]:
			check(camera_now.distance_to(previous_camera)<=position_now.distance_to(previous_player)+0.2,"Clamped camera never adds an unexplained jump")
		if frame>150 and frame<180: check(position_now==pause_position,"Paused continuous frames preserve simulation")
		root.get_texture().get_image().save_png(output.path_join("frame_%04d.png" % frame))
		samples.append({"frame":frame,"paused":paused,"player":str(position_now),"camera":str(camera_now),"dash_left":arena.player.dash_left,"cooldown":arena.player.dash_cooldown,"window":str(root.size)})
		previous_player=position_now
		previous_camera=camera_now
	release_movement()
	paused=false
	var file:=FileAccess.open(output.path_join("motion_samples.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "))
	file.close()
	game.free()
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)
	print("CAMERA CONTINUOUS MOTION: ",checks," checks, ",failures," failures; 360 real simulation frames")
	quit(1 if failures else 0)
