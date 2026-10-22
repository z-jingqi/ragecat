extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(false)
	var arena: RageArena = game.arena
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	arena.bow.enabled=false
	for count in [249,250]:
		arena.clear_enemies()
		arena.xp=0
		for i in range(count): arena.pickups.append(Vector2(100,200))
		var boss := arena.spawn_enemy("boss")
		boss.receive_damage(boss.health)
		check(arena.pickups.size()<=250,"Boss reward at pickup cap stays bounded from "+str(count))
		check(arena.pickups.size()+arena.xp==count+12,"Boss overflow preserves all 12 XP from "+str(count))
	var player:=arena.player
	player.movement_enabled=false
	arena.apply_ranks({"regen":3})
	arena.stats.hp=50.0
	var rate:=arena.stats.regen
	player._physics_process(0.2)
	check(is_equal_approx(arena.stats.hp,50.0+rate*0.2),"Ordinary regen integrates elapsed time")
	var coarse:=arena.stats.hp
	arena.stats.hp=50.0
	for i in range(4): player._physics_process(0.05)
	check(is_equal_approx(arena.stats.hp,coarse),"Regeneration result independent of coarse versus fine frame split")
	arena.stats.hp=0.0
	player._physics_process(0.1)
	check(arena.stats.hp==0.0,"Regeneration cannot resurrect a dead player")
	game.start_run(false)
	arena=game.arena
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	arena.bow.enabled=false
	arena.stats.hp=5.0
	arena.xp=arena.xp_needed-1
	arena.pickups.append(arena.player.position)
	arena.spawn_enemy("mob",arena.player.position)
	arena._physics_process(1.0/60.0)
	check(game.current_mode=="dead" and arena.finished,"Lethal contact plus same-frame XP cannot replace death with an upgrade")
	check(arena.level==1,"Dead player cannot gain a same-frame level after lethal contact")
	game.queue_free()
	await process_frame
	print("BOUNDARIES: %d checks, %d failures" % [checks,failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
