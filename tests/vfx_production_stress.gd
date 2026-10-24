extends SceneTree
## Run on a real Compatibility display. Dense production hierarchy, pause and reset.
## Optional -- --capture-dir=/tmp/vfx-production. Never run as a headless visual claim.
var failures := 0
var output := ""
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error(label)
func state_of(arena: RageArena, boss: BossActor) -> Array:
	var result: Array=[arena.stats.hp,boss.get("phase_time"),arena.player.position]
	for arrow in arena.arrows.get_children(): result.append([arrow.get_instance_id(),arrow.position])
	for child in boss.get_children():
		if child is RockWarning or child is SkyfireHazard: result.append([child.get_instance_id(),child.elapsed])
		if child is BossFireRing: result.append([child.get_instance_id(),child.ring_radius])
	return result
func refs_of(node: Node, refs: Array[WeakRef]) -> void:
	refs.append(weakref(node))
	for child in node.get_children(): refs_of(child,refs)
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("Real rendering display required");quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): output=arg.trim_prefix("--capture-dir=")
	if not output.is_empty():
		if not output.is_absolute_path() or output.begins_with(ProjectSettings.globalize_path("res://")): quit(2);return
		DirAccess.make_dir_recursive_absolute(output)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_language("en")
	game.start_run(true,89341)
	game.return_from_practice_navigation()
	var arena: RageArena=game.arena
	arena.set_sound_enabled(false)
	var results: Array=[]
	for element: String in ["fire","lightning","ice","dark"]:
		arena.player.invulnerable=true
		arena.player.position=Vector2(520,420)
		arena.apply_ranks({element+"_enchant":3,element+"_bow":3,"attack_speed":3,"burst":3,"spread_arrow":3,"pierce":3})
		for i in range(56):
			var at:=Vector2(720,420)+Vector2.from_angle(float(i)*2.39996)*(50+(i%8)*18)
			var enemy:=arena.spawn_enemy("spitter" if i%7==0 else "mob",at)
			enemy.max_health=100000;enemy.health=100000;enemy.ai_enabled=false
		var identity: String={"fire":"wildfire","lightning":"beastcaller","ice":"mountainbreaker","dark":"mountainbreaker"}[element]
		var boss:=arena.spawn_enemy(identity,Vector2(330,320)) as BossActor
		boss.force_phase_for_practice(2)
		boss.health=100000;boss.max_health=100000
		if boss is Wildfire:
			boss.skyfires_remaining=boss.boss_definition.skyfire_count;boss._next_skyfire()
		elif boss is Beastcaller: boss._start_summon()
		elif element=="dark": boss._start_rocks()
		else: boss._start_charge_warning()
		var measured: Array[float]=[]
		var last:=Time.get_ticks_usec()
		for frame in range(150):
			await process_frame;await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			if frame>=30: measured.append(float(now-last)/1000.0)
			last=now
			if frame==70 and not output.is_empty(): root.get_texture().get_image().save_png(output.path_join(element+"_dense.png"))
		measured.sort()
		results.append({"element":element,"median_ms":measured[measured.size()/2],"p95_ms":measured[ceili(measured.size()*.95)-1],"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
		paused=true
		var before:=state_of(arena,boss)
		for i in range(12): await process_frame
		check(before==state_of(arena,boss),"pause freezes dense gameplay and hazard clocks: "+element)
		paused=false
		var refs: Array[WeakRef]=[]
		for container in [arena.enemies,arena.arrows,arena.enemy_bullets,arena.effects]:
			for child in container.get_children(): refs_of(child,refs)
		arena.player.invulnerable=false;arena.stats.shields=0;arena.player.health_state.invulnerability=0;arena.player.dash_left=0
		arena.player.receive_hit(100000)
		await process_frame;await process_frame
		check(not arena.finished and arena.stats.hp==arena.stats.max_hp,"practice lethal reset stays playable: "+element)
		check(arena.enemies.get_child_count()==0 and arena.arrows.get_child_count()==0 and arena.enemy_bullets.get_child_count()==0,"practice reset clears dense combat: "+element)
		for ref in refs: check(ref.get_ref()==null,"owned effect released on reset: "+element)
	var scene_refs: Array[WeakRef]=[]
	refs_of(game,scene_refs)
	game.queue_free()
	for i in range(4): await process_frame
	for ref in scene_refs: check(ref.get_ref()==null,"game teardown releases all owned nodes")
	print("VFX_PRODUCTION_STRESS ",JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"cases":results,"failures":failures}))
	quit(1 if failures else 0)
