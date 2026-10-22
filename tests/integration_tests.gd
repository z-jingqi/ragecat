extends SceneTree
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: "+message)
		quit(1)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director:=RunDirector.new()
	director.tick(119.9)
	check(not director.boss_alive,"First boss not early")
	check(director.tick(.1).spawn_boss,"First boss at120 active seconds")
	check(not director.tick(200).spawn_boss,"Only one live boss")
	director.boss_killed()
	check(not director.tick(119.9).spawn_boss,"Kill relative boss delay")
	check(director.tick(.11).spawn_boss,"Next boss 120 after kill")
	var arrow:=CatArrow.new()
	check(arrow.can_hit(42),"Fresh arrow hit eligible")
	arrow.max_hits=3
	arrow.hit_ids[42]=true
	check(not arrow.can_hit(42),"Pierce never hits same target twice")
	check(arrow.can_hit(43),"Pierce may hit new target")
	arrow.free()
	var game:=load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena:RageArena=game.arena
	check(arena.practice,"Shared arena practice mode")
	game.practice_command("preset_fire")
	check(arena.stats.element_damage>0 and arena.stats.pierce_max_hits>1,"Practice preset uses real stats")
	game.practice_command("spawn_line")
	check(arena.enemies.get_child_count()==5,"Practice line spawns")
	await process_frame
	await physics_frame
	check(arena.arrows.get_child_count()>0 or arena.hits>0,"Auto bow launches arrows (first-stop arrows may already have hit)")
	game.practice_option("time_scale",0.0)
	var before:=arena.director.elapsed
	await process_frame
	check(arena.director.elapsed==before and paused,"Pause freezes simulation")
	game.practice_option("time_scale",1.0)
	check(not paused,"Lab unpause remains callable")
	game.practice_command("reset")
	arena=game.arena
	check(arena.ranks.is_empty() and arena.enemies.get_child_count()==0 and arena.hits==0,"Practice reset clears entities upgrades metrics")
	game.start_run(false)
	arena=game.arena
	for i in range(75): arena.spawn_enemy("mob")
	check(arena.enemies.get_child_count()==69,"Mob cap reserves a boss slot")
	arena.director.elapsed=119.99
	await physics_frame
	await physics_frame
	check(arena.director.boss_alive,"Live endless director spawns boss")
	var bosses := 0
	for enemy in arena.enemies.get_children():
		if enemy is BossActor: bosses += 1
	check(bosses==1 and arena.enemies.get_child_count()<=70,"Boss actually spawns at enemy cap")
	game.show_pause()
	before=arena.director.elapsed
	await physics_frame
	check(arena.director.elapsed==before,"Endless pause excludes boss clock")
	game.resume_run()
	game.show_upgrades()
	check(paused,"Upgrade selection pauses real simulation")
	game.choose_upgrade("shield")
	check(arena.stats.shields==1 and not paused,"Shield selection grants and resumes")
	arena.xp=arena.xp_needed-1
	for i in range(30): arena.pickups.append(arena.player.position)
	var level_before:=arena.level
	arena._physics_process(1.0/60.0)
	check(arena.level==level_before+1 and arena.pickups.size()==29,"One level per paused upgrade choice; remaining pickups preserved")
	game.choose_upgrade("damage")
	game.free()
	print("PASS: %d integration checks" % checks)
	quit(0)
