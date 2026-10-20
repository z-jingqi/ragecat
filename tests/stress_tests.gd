extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game:=load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena:RageArena=game.arena
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	var ranks:Dictionary={}
	for key:String in game.catalog.definitions: ranks[key]=3
	arena.apply_ranks(ranks)
	arena.player.invulnerable=true
	arena.lab_ai=true
	arena.spawn_enemy("boss",arena.player.position+Vector2(190,0))
	for i in range(50): arena.spawn_enemy("mob")
	for i in range(1000):
		arena._physics_process(1.0/60.0)
		arena.player._physics_process(1.0/60.0)
		arena.bow._physics_process(1.0/60.0)
		for enemy in arena.enemies.get_children(): enemy._physics_process(1.0/60.0)
		for arrow in arena.arrows.get_children():
			if not arrow.is_queued_for_deletion(): arrow._physics_process(1.0/60.0)
		for effect in arena.effects.get_children():
			if not effect.is_queued_for_deletion(): effect._process(1.0/60.0)
		await process_frame
	print("STRESS PASS hits=%d kills=%d live=%d arrows=%d" % [arena.hits,arena.kills,arena.enemies.get_child_count(),arena.arrows.get_child_count()])
	game.free()
	quit(0)
