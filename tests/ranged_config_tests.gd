extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.player.position = Vector2(450, 400)
	arena.set_enemy_ai(true)
	var ranged := arena.spawn_enemy("ranged",Vector2(800,400)) as Spitter
	check(is_equal_approx(ranged.max_health, arena.definition.melee_health * 0.6),"Ranged HP is 60% scaled melee")
	var start := ranged.position
	ranged._physics_process(0.1)
	check(ranged.position == start,"Far ranged idles instead of pursuing")
	ranged.position = Vector2(600,400)
	ranged._physics_process(0.5)
	check(ranged.position.x > 600 and ranged.retreating,"Close ranged retreats")
	ranged.position = Vector2(700,400)
	ranged._physics_process(0.1)
	check(ranged.position.x > 700 and ranged.retreating,"Hysteresis keeps retreating between thresholds")
	ranged._physics_process(1.0)
	check(is_equal_approx(ranged.position.distance_to(arena.player.position),280.0),"Retreat stops at outer band without overshoot")
	ranged._physics_process(0.1)
	check(not ranged.retreating,"Retreat exits outer band")
	ranged.position=Vector2(arena.bounds.end.x-ranged.radius,400)
	arena.player.position=ranged.position-Vector2(40,0)
	start=ranged.position
	ranged._physics_process(1.0)
	check(ranged.position==start,"Wall pins outward retreat without teleport or pursuit")
	arena.clear_enemies()
	arena.player.position=Vector2(450,400)
	ranged=arena.spawn_enemy("ranged",Vector2(750,400)) as Spitter
	ranged.shot_cooldown=0
	ranged._physics_process(0.01)
	check(ranged.shot_pending and arena.enemy_bullets.get_child_count()==0,"Warning precedes shot")
	var heading:=ranged.locked_direction
	arena.player.position+=Vector2(0,120)
	ranged._physics_process(0.2)
	check(ranged.locked_direction==heading and arena.enemy_bullets.get_child_count()==0,"Warning locks aim")
	ranged.ai_enabled=false
	var timer:=ranged.warning_remaining
	ranged._physics_process(2.0)
	check(ranged.warning_remaining==timer,"AI off freezes pending warning")
	ranged.ai_enabled=true
	ranged._physics_process(0.2)
	check(arena.enemy_bullets.get_child_count()==1,"Warning expiry fires one bullet")
	var bullet:=arena.enemy_bullets.get_child(0) as EnemyBullet
	check(bullet.direction==heading,"Bullet uses locked nonhoming heading")
	var fired_position:=bullet.position
	ranged.receive_damage(ranged.health)
	check(arena.enemy_bullets.get_child_count()==1,"Fired bullet survives shooter death")
	bullet._physics_process(0.1)
	check(bullet.position==fired_position+heading*24.0,"Bullet follows straight speed-based path")
	arena.set_enemy_ai(false)
	start=bullet.position
	bullet._physics_process(1.0)
	check(bullet.position==start,"AI off freezes already fired bullets")
	arena.clear_enemies()
	ranged=arena.spawn_enemy("ranged",Vector2(750,400)) as Spitter
	ranged.shot_cooldown=0
	ranged.ai_enabled=true
	ranged._physics_process(0.01)
	ranged.receive_damage(ranged.health)
	ranged._physics_process(1.0)
	check(arena.enemy_bullets.get_child_count()==0 and not ranged.shot_pending,"Death interrupts pending shot")
	arena.clear_enemies()
	arena.player.invulnerable=false
	arena.stats.hp=100
	arena.stats.shield_capacity=2
	arena.stats.shields=2
	arena.player.health_state.invulnerability=0
	arena.player.position=Vector2(400,400)
	var settings:=SpitterDefinition.new()
	settings.bullet_speed=1000
	settings.bullet_damage=17
	for i in range(2):
		var shot:=EnemyBullet.new()
		shot.setup(Vector2(300,400),Vector2.RIGHT,settings,arena.player)
		arena.enemy_bullets.add_child(shot)
		shot._physics_process(0.2)
		check(shot.consumed,"Contact consumes shot even inside iframe")
	check(arena.stats.shields==1 and arena.stats.hp==100,"Two simultaneous bullets consume one shield via shared immunity")
	arena.player.health_state.tick(0.5)
	arena.stats.shields=0
	var shot:=EnemyBullet.new()
	shot.setup(Vector2(300,400),Vector2.RIGHT,settings,arena.player)
	arena.enemy_bullets.add_child(shot)
	shot._physics_process(0.2)
	check(arena.stats.hp==83,"Configured bullet damage applies after immunity")
	arena.player.health_state.tick(0.5)
	arena.player.dash_left=0.2
	shot=EnemyBullet.new()
	shot.setup(Vector2(300,400),Vector2.RIGHT,settings,arena.player)
	arena.enemy_bullets.add_child(shot)
	shot._physics_process(0.2)
	check(shot.consumed and arena.stats.hp==83,"Dash avoids bullet but consumes contact")
	arena.player.dash_left=0
	settings.bullet_speed=50
	settings.bullet_range=25
	shot=EnemyBullet.new()
	shot.setup(Vector2(300,200),Vector2.RIGHT,settings,arena.player)
	arena.enemy_bullets.add_child(shot)
	shot._physics_process(0.25)
	check(is_equal_approx(shot.traveled,12.5) and not shot.consumed,"Custom bullet speed uses game delta")
	shot._physics_process(1.0)
	check(is_equal_approx(shot.traveled,25.0) and shot.consumed,"Custom max range clamps travel and consumes")
	arena.clear_enemies()
	check(arena.enemy_bullets.get_child_count()==0,"Clear removes all enemy bullets")
	arena.definition.ranged_intro_time=0
	arena.definition.ranged_fraction=1
	arena.definition.ranged_limit=1
	check(arena._next_enemy_kind()=="ranged","Custom spawn intro and fraction apply")
	arena.spawn_enemy("ranged")
	check(arena._next_enemy_kind()=="mob","Ranged live cap replaces rather than adds spawns")
	arena._spawn_enemy_bullet(Vector2(100,200),Vector2.RIGHT,settings)
	arena.definition.enemy_projectile_limit=1
	arena._spawn_enemy_bullet(Vector2(100,200),Vector2.RIGHT,settings)
	check(arena.enemy_bullets.get_child_count()==1,"Configured enemy projectile budget prevents accumulation")
	arena._on_death()
	check(arena.finished and arena.enemy_bullets.get_child(0).is_queued_for_deletion(),"Run death cleans bullets")
	arena.free()
	var custom:=ArenaDefinition.new()
	custom.initial_xp_needed=11
	custom.xp_base=13
	custom.xp_per_level=4
	custom.boss_interval=17
	custom.spawn_interval=2.5
	custom.minimum_spawn_interval=2.5
	custom.melee_health=50
	var a:=RageArena.new()
	a.definition=custom
	a.practice=true
	root.add_child(a)
	a.process_mode=Node.PROCESS_MODE_DISABLED
	check(a.xp_needed==11 and a.director.next_boss_at==17,"Custom XP and boss interval initialize runtime")
	a.xp=11
	a.award_level()
	check(a.xp_needed==21,"Custom XP growth applies")
	a.director.tick(0.01)
	check(is_equal_approx(a.director.spawn_clock,2.5),"Custom spawn interval applies")
	var mob:=a.spawn_enemy("mob")
	check(is_equal_approx(mob.max_health,50.0*(1.0+a.director.elapsed/custom.difficulty_period)),"Custom melee HP survives spawn")
	a.definition.melee_health=77
	check(custom.melee_health==50,"Arena run snapshot does not mutate input resource")
	a.free()
	var invalid:=SpitterDefinition.new()
	invalid.shot_interval=-1
	invalid.retreat_start=300
	invalid.retreat_end=100
	var clean:=invalid.validated_copy()
	check(clean.shot_interval>0 and clean.retreat_end>clean.retreat_start,"Invalid cadence and hysteresis sanitized")
	check(invalid.shot_interval==-1,"Validation leaves authored definition unchanged")
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	var character := CharacterDefinition.new()
	var damage_upgrade := (load("res://resources/upgrades/damage.tres") as UpgradeDefinition).duplicate(true) as UpgradeDefinition
	damage_upgrade.values=PackedFloat32Array([0,17,24,36])
	damage_upgrade.max_rank=1
	character.upgrades.append(damage_upgrade)
	game.character_definition=character
	game.arena_definition=custom.duplicate(true)
	game.arena_definition.upgrade_choices=1
	game.arena_definition.heal_fraction=0.6
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	game.arena.process_mode=Node.PROCESS_MODE_DISABLED
	game.show_upgrades()
	var card: Button
	for child in game.overlay.get_node("ModalScroll/ModalContent").get_children():
		if child is Button and child.has_meta("upgrade_key"): card=child
	check(card != null and "17%" in card.text and "[1/1]" in card.text,"Real upgrade card reflects edited value and rank cap")
	card.pressed.emit()
	check(game.arena.stats.damage_percent==17,"Selecting actual edited card applies identical runtime value")
	game.arena.stats.hp=20
	game.show_upgrades()
	for child in game.overlay.get_node("ModalScroll/ModalContent").get_children():
		if child is Button and child.has_meta("upgrade_key"): card=child
	check("60%" in card.text,"Real healing card uses edited heal fraction")
	card.pressed.emit()
	check(game.arena.stats.hp==80,"Healing card runtime agrees with edited preview")
	game.start_run(true)
	var rank_control:=game.lab._rank_controls["damage"] as SpinBox
	check("Not selected" in str(rank_control.get_meta("details_text", "")) and "Lv0/1" in str(rank_control.get_meta("details_text", "")), "Practice detail text starts at actual unselected rank")
	rank_control.value = 1
	check("17%" in str(rank_control.get_meta("details_text", "")) and "Lv1/1" in str(rank_control.get_meta("details_text", "")), "Practice selected detail text reflects same edited upgrade data")
	game.show_menu()
	game.free()
	paused=false
	var timed:=RageArena.new()
	timed.practice=true
	timed.process_mode=Node.PROCESS_MODE_PAUSABLE
	root.add_child(timed)
	timed.bow.enabled=false
	timed.player.movement_enabled=false
	timed.set_enemy_ai(true)
	var timer_enemy:=timed.spawn_enemy("ranged",timed.player.position+Vector2(300,0)) as Spitter
	timer_enemy.shot_cooldown=1.5
	paused=true
	var before:=timer_enemy.shot_cooldown
	await create_timer(0.1,true,false,true).timeout
	check(is_equal_approx(timer_enemy.shot_cooldown,before),"Tree pause freezes ranged cadence")
	paused=false
	Engine.time_scale=0.25
	before=timer_enemy.shot_cooldown
	await create_timer(0.2,true,false,true).timeout
	var elapsed:=before-timer_enemy.shot_cooldown
	check(elapsed>0.01 and elapsed<0.12,"Time scale uses game seconds rather than wall seconds")
	Engine.time_scale=1.0
	timed.free()
	await process_frame
	print("RANGED CONFIG: %d checks, %d failures" % [checks,failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
