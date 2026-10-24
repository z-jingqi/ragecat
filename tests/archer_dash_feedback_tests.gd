extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DASH FEEDBACK: " + label)
func run() -> void:
	var arena:=RageArena.new()
	arena.practice=true
	arena.sound_enabled=false
	arena.run_seed_override=81963
	root.add_child(arena)
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	var presentation:ArcherPresentation=arena.player._presentation
	var controller:ArcherDashFeedbackController=presentation._dash_feedback
	check(controller != null and controller.owner_arena==arena,"Real scene binds visual feedback")
	check(controller.marker != null and controller.marker.get_parent()==arena.player,"Small readiness symbol follows the actor, not the HUD")
	arena.player.dash_cooldown=arena.stats.dash_cooldown_duration
	controller.marker.update_state()
	check(is_zero_approx(controller.marker.readiness),"Marker starts dark at actual cooldown start")
	arena.player.dash_cooldown=arena.stats.dash_cooldown_duration*0.5
	controller.marker.update_state()
	check(is_equal_approx(controller.marker.readiness,0.5),"Marker fills from real remaining cooldown")
	arena.player.dash_cooldown=0.0
	controller.marker.update_state()
	check(is_equal_approx(controller.marker.readiness,1.0),"Ready is shown only when cooldown ends")
	check(controller.marker.position==controller.settings.marker_offset,"Marker sits at configured foot-level offset")
	var state:=arena.rng.state
	var at:=arena.player.position
	var health:=arena.stats.hp
	seed(9182)
	var expected:=randf()
	seed(9182)
	arena.player.dash_left=arena.stats.dash_duration
	arena.player.dash_direction=Vector2.RIGHT
	for i in range(12):
		controller._physics_process(1.0/60.0)
		arena.player.dash_left=maxf(0.0,arena.player.dash_left-1.0/60.0)
	check(controller._spawned.size()==3,"One dust emission and two restrained pose snapshots")
	check(arena.rng.state==state and randf()==expected,"Feedback consumes neither combat nor global RNG")
	check(arena.player.position==at and arena.stats.hp==health,"Feedback cannot change position or health")
	var ghosts:Array[Node]=controller._spawned.filter(func(n):return n is ArcherDashAfterimage)
	check(ghosts.size()==2,"Two afterimages, not continuous sprite spam")
	for node in ghosts:
		var ghost:=node as ArcherDashAfterimage
		check(ghost.material!=presentation.view.material,"Snapshot material is independent from live pose")
		check(ghost.texture==presentation.view._quad_texture,"Snapshots share existing texture, no new render target")
		check(ghost.z_index+arena.effects.z_index<arena.player.z_index and ghost.z_index+arena.effects.z_index>arena.z_index,"Ghost sits above floor and below player")
		check(ghost.opacity<=0.3 and ghost.modulate.a<=0.3,"Low opacity body does not cover main action")
		var historical_position:=ghost.global_position
		arena.player.position+=Vector2(15,9)
		check(ghost.global_position==historical_position,"Afterimage remains at historical world position behind the moving actor")
		arena.player.position=at
		var before:Vector4=(ghost.material as ShaderMaterial).get_shader_parameter("upper_region")
		presentation.view._pose_material.set_shader_parameter("upper_region",Vector4.ZERO)
		check((ghost.material as ShaderMaterial).get_shader_parameter("upper_region")==before,"Later live pose updates do not move a ghost")
	arena.player.dash_cooldown=arena.stats.dash_cooldown_duration
	controller.marker.update_state()
	arena.player.dash_cooldown=0.0
	controller.reset()
	check(is_equal_approx(controller.marker.readiness,1.0),"Reset refreshes readiness immediately, even without another physics tick")
	await process_frame
	check(controller._spawned.is_empty(),"Practice reset drops all owned feedback")
	for node in ghosts:check(not is_instance_valid(node),"Reset frees existing afterimage nodes")
	controller.settings=controller.settings.duplicate()
	controller.settings.enabled=false
	arena.player.dash_left=0.2
	controller._physics_process(0.1)
	check(controller._spawned.is_empty(),"Disabled appearance has no effects")
	check(not controller.marker.visible,"Disabled appearance also hides the readiness marker")
	controller.settings.enabled=true
	controller.settings.afterimage_times=PackedFloat32Array()
	controller.settings.dust_count=0
	controller.reset()
	controller._physics_process(0.1)
	check(controller._spawned.is_empty(),"Zero configured emissions are supported")
	arena.free()
	await preload("res://tests/audio_teardown.gd").drain(self)
	for path in ["res://scripts/characters/archer/archer.gd", "res://scripts/characters/archer/presentation/feedback_overlay.gd"]:
		var source := FileAccess.get_file_as_string(path)
		check(not source.contains("dash_cooldown"), "Player drawing does not display a dash cooldown ring: " + path)
	var marker_source:=FileAccess.get_file_as_string("res://scripts/characters/archer/presentation/dash/dash_ready_marker.gd")
	check(not marker_source.contains("draw_arc") and not marker_source.contains("draw_circle") and not marker_source.contains("draw_string"),"Foot marker uses no ring or numerical text")
	print("ARCHER DASH FEEDBACK: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
