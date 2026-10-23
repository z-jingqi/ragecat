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
	arena.definition.enemy_mass = 2.0
	var normal := arena.spawn_enemy("mob",Vector2(300,300))
	var swift := arena.spawn_enemy("swiftfang",Vector2(400,300))
	var elite := arena.spawn_enemy("elite_hornling",Vector2(500,300))
	check(normal is Hornling and swift is Swiftfang and elite is EliteHornling,"distinct mob classes")
	check(is_equal_approx(swift.max_health / normal.max_health,0.55),"swift health configurable ratio")
	check(is_equal_approx(elite.max_health / normal.max_health,1.5),"elite health ratio")
	check(swift.speed > normal.speed and swift.mass < normal.mass,"swift mobility and mass")
	check(is_equal_approx(swift.contact_damage_multiplier,0.75),"swift damage ratio")
	check(is_equal_approx(normal.mass,2.0) and is_equal_approx(swift.mass,1.4),"global mass tuning preserves archetype scaling")
	var first := arena.spawn_enemy("mountainbreaker",Vector2(600,300))
	check(first is Mountainbreaker,"first boss")
	var second := arena.spawn_enemy("beastcaller",Vector2(600,300)) as BossActor
	check(second is Beastcaller,"practice safely replaces distinct boss")
	check(not is_instance_valid(first),"old boss removed")
	arena.set_practice_boss_phase(2)
	check(second.phase_number == 2,"practice phase")
	arena.definition.enemy_limit = arena._live_enemy_count() + 3
	var positions: Array[Vector2] = [Vector2(600,400),Vector2(640,400),Vector2(680,400)]
	check(arena._reserve_summons(positions,second),"summon capacity reserved")
	check(arena.spawn_enemy("mob",Vector2(300,400)) == null,"ordinary spawn respects reservations")
	arena._commit_summons(second)
	check(arena._reserved_summon_count() == 0,"commit releases reservation")
	var owned := 0
	for actor in arena.enemies.get_children():
		if int(actor.get_meta("summoner_id",0)) == second.get_instance_id(): owned += 1
	check(owned == 3,"reserved batch committed completely")
	check(not arena._reserve_summons(positions,second),"full arena skips summon wholebatch")
	var settings := SpitterDefinition.new()
	arena._spawn_enemy_bullet(Vector2(600,300),Vector2.RIGHT,settings,second)
	check(arena.enemy_bullets.get_child_count() == 1,"boss projectile spawned")
	arena._clear_boss_owned_attacks(second)
	check((arena.enemy_bullets.get_child(0) as EnemyBullet).consumed,"boss cleanup consumes own projectile")
	arena.clear_enemies()
	arena.practice = false
	arena.definition.enemy_limit = 69
	for index in range(6):
		arena.director.boss_count = index
		var boss := arena.spawn_enemy("boss",Vector2(600,300)) as BossActor
		check(boss.boss_identity == arena.definition.boss_order[index % 3],"campaign/endless boss roster cycles")
		arena.clear_enemies()
	arena.free()
	print("ROSTER INTEGRATION: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
