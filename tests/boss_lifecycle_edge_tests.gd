extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := RageArena.new()
	arena.practice = true
	root.add_child(arena)
	arena.set_physics_process(false)
	arena.bow.enabled = false
	arena.player.set_physics_process(false)
	arena.set_sound_enabled(false)
	var boss := arena.spawn_enemy("beastcaller",Vector2(600,300)) as Beastcaller
	boss.set_physics_process(false)
	var points: Array[Vector2] = [Vector2(600,400),Vector2(650,400),Vector2(700,400)]
	arena.definition.enemy_limit = 20
	check(arena._reserve_summons(points,boss),"reserve before runtime cap change")
	arena.definition.enemy_limit = 3
	arena._commit_summons(boss)
	check(arena._live_enemy_count() == 1,"reduced cap skips whole summon batch instead of partial")
	arena.clear_enemies()
	arena.definition.enemy_limit = 20
	boss = arena.spawn_enemy("beastcaller",Vector2(600,300)) as Beastcaller
	boss.set_physics_process(false)
	check(arena._reserve_summons(points,boss),"reserve before elite cap change")
	boss.boss_definition.elite_live_cap = 1
	arena._commit_summons(boss)
	check(arena._live_enemy_count() == 1,"reduced elite cap skips batch")
	boss.boss_definition.elite_live_cap = 16
	check(arena._reserve_summons(points,boss),"reserve before practice phase reset")
	arena.set_practice_boss_phase(2)
	check(arena._reserved_summon_count() == 0,"phase reset cancels pending summons")
	arena._commit_summons(boss)
	check(arena._live_enemy_count() == 1,"cancelled batch never commits")
	var settings := SpitterDefinition.new()
	arena._spawn_enemy_bullet(Vector2(300,300),Vector2.RIGHT,settings)
	arena._spawn_enemy_bullet(Vector2(300,400),Vector2.RIGHT,settings,boss)
	var ordinary := arena.enemy_bullets.get_child(0) as EnemyBullet
	var owned := arena.enemy_bullets.get_child(1) as EnemyBullet
	boss.receive_damage(boss.health+1)
	check(owned.consumed and not ordinary.consumed,"boss death removes only owned projectiles")
	await process_frame
	arena.clear_enemies()
	boss = arena.spawn_enemy("beastcaller",Vector2(600,300)) as Beastcaller
	boss.set_physics_process(false)
	check(arena._reserve_summons(points,boss),"reserve before player death")
	arena.player.invulnerable = false
	arena.player.stats.hp = 1
	arena.player.stats.shields = 0
	arena.player.health_state.invulnerability = 0.0
	arena.player.receive_hit(1000)
	check(arena.finished and arena._reserved_summon_count() == 0,"player death clears all reservations")
	arena._commit_summons(boss)
	check(arena._live_enemy_count() == 1,"no ghost summon after player death")
	arena.free()
	await process_frame
	print("Boss lifecycle edge tests: %s checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
