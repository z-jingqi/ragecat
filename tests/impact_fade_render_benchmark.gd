extends SceneTree
## Actual Compatibility rendering and full lifecycle under dense death pressure.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Rendered benchmark requires a display")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.set_sound_enabled(false)
	arena.bow.enabled = false
	var samples: Array[float] = []
	var previous := Time.get_ticks_usec()
	var failed := false
	for frame in range(180):
		if frame % 15 == 0:
			for i in range(40):
				var enemy := arena.spawn_enemy("mob",Vector2(300+(i%8)*40,180+(i/8)*40))
				enemy.receive_damage(enemy.health+1)
			arena.feedback.shield_break(arena.player.position,arena.player.radius)
		for visual in arena.feedback.visuals.get_children():
			if not visual.is_queued_for_deletion(): visual._process(1.0/60.0)
		if arena.feedback.visuals.get_child_count() > arena.feedback.definition.visual_limit:
			failed = true
			printerr("Visual budget exceeded")
		await process_frame
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		if frame >= 30: samples.append(float(now-previous)/1000.0)
		previous = now
	var references: Array[WeakRef] = []
	for visual in arena.feedback.visuals.get_children(): references.append(weakref(visual))
	arena.clear_enemies()
	await process_frame
	await process_frame
	for ref in references:
		if ref.get_ref() != null:
			failed = true
			printerr("Retained visual after deferred-free flush")
	# No actor or VFX remains after the owning arena is destroyed.
	var arena_ref: WeakRef = weakref(arena)
	arena.queue_free()
	await process_frame
	await process_frame
	if arena_ref.get_ref() != null:
		failed = true
		printerr("Retained arena after deferred-free flush")
	samples.sort()
	print("IMPACT_RENDER ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"samples":samples.size(),"median_ms":samples[samples.size()/2],"p95_ms":samples[int(samples.size()*0.95)],"cleanup_ok":not failed}))
	quit(1 if failed else 0)
