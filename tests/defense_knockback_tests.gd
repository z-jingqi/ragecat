extends SceneTree
## Real player, arena contact, boss/rock signals and arrow collision regression.
var checks := 0
var failures := 0
var game: Node
var arena: RageArena
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func reset(shields: int = 0) -> void:
	arena.clear_enemies()
	arena.apply_ranks({})
	arena.stats.hp = 100.0
	arena.stats.shield_capacity = shields
	arena.stats.shields = shields
	arena.player.health_state.invulnerability = 0.0
	arena.player.dash_left = 0.0
	arena.player.invulnerable = false
	arena.player.position = arena.bounds.get_center()
func contact() -> void:
	for i in range(3):
		arena.spawn_enemy("mob", arena.player.position)
	arena._physics_process(0.0)
func rock_at_player() -> void:
	var boss := arena.spawn_enemy("boss", arena.player.position + Vector2(150, 0)) as BossActor
	boss.ai_enabled = true
	boss._start_rocks()
	var rock: RockWarning = boss.rocks[0]
	rock.global_position = arena.player.global_position
	rock._physics_process(rock.warning_duration)
func shoot(enemy: EnemyActor, direction: Vector2 = Vector2.RIGHT) -> void:
	var arrow := CatArrow.new()
	arrow.position = enemy.position - direction * 20.0
	arrow.direction = direction
	arrow.speed = 1000.0
	arrow.enemies = arena.enemies
	arrow.arena_bounds = arena.bounds
	arrow.enemy_hit.connect(arena._on_arrow_hit)
	arena.arrows.add_child(arrow)
	arrow._physics_process(0.04)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.start_run(true)
	arena = game.arena
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.bow.enabled = false
	arena.player.movement_enabled = false
	reset()
	contact()
	check(arena.stats.hp == 90.0, "Three same-frame mob contacts cost HP only once")
	rock_at_player()
	check(arena.stats.hp == 90.0, "Actual rock impact within contact immunity cannot damage")
	for i in range(10): arena._physics_process(0.0)
	check(arena.stats.hp == 90.0, "Repeated contacts without elapsed time cannot damage")
	arena.player._physics_process(0.25)
	arena._physics_process(0.0)
	check(arena.stats.hp == 90.0, "Contact still blocked at 0.25 game seconds")
	arena.player._physics_process(0.25)
	arena._physics_process(0.0)
	check(arena.stats.hp == 80.0, "Contact damage resumes at exact 0.5 game seconds")
	reset(2)
	contact()
	rock_at_player()
	check(arena.stats.hp == 100.0 and arena.stats.shields == 1, "Shield block protects against simultaneous mob and rock hits")
	arena.player._physics_process(0.499)
	arena._physics_process(0.0)
	check(arena.stats.shields == 1, "Shield immunity rejects contacts at 0.499 seconds")
	arena.player._physics_process(0.002)
	arena._physics_process(0.0)
	check(arena.stats.shields == 0 and arena.stats.hp == 100.0, "Final shield absorbs next hit after window")
	rock_at_player()
	arena._physics_process(0.0)
	check(arena.stats.hp == 100.0, "Final shield grants the same protection from rock/contact")
	arena.player._physics_process(0.5)
	rock_at_player()
	check(arena.stats.hp < 100.0, "Rock damage resumes after last-shield immunity ends")
	reset(1)
	arena.player.dash_left = 0.2
	contact()
	rock_at_player()
	check(arena.stats.hp == 100.0 and arena.stats.shields == 1, "Dash blocks contact and actual rock without spending shield")
	check(arena.player.health_state.invulnerability == 0.0, "Dash alone does not create hit-immunity timer")
	arena.player._physics_process(0.2)
	arena.player.receive_hit(10.0)
	check(arena.stats.shields == 0, "Damage accepted after dash ends")
	arena.player.dash_left = 0.2
	arena.player._physics_process(0.2)
	arena.player.receive_hit(10.0)
	check(arena.stats.hp == 100.0, "Hit immunity remains after an overlapping dash ends")
	arena.player._physics_process(0.301)
	arena.player.receive_hit(10.0)
	check(arena.stats.hp == 90.0, "Damage resumes when both dash and hit immunity end")
	reset()
	var mob := arena.spawn_enemy("mob", arena.player.position + Vector2(140,0))
	mob.health = 1000.0
	var start := mob.position
	shoot(mob)
	check(mob.position == start, "Knockback begins without teleporting")
	mob._physics_process(mob.feedback_definition.knockback_duration)
	check(is_equal_approx(mob.position.x - start.x, 45.0), "Real arrow collision smoothly knocks a mob back 45 pixels")
	check(is_equal_approx(mob.position.y, start.y), "Knockback follows arrow direction")
	start = mob.position
	shoot(mob)
	check(mob.position == start, "Knockback begins without teleporting")
	mob._physics_process(mob.feedback_definition.knockback_duration)
	check(is_equal_approx(mob.position.x - start.x, 45.0), "Consecutive arrows do not accumulate knockback speed")
	mob.status.apply_ice(load("res://resources/elements/ice.tres") as ElementSkillDefinition, 1)
	start = mob.position
	mob._physics_process(0.5)
	check(mob.position == start, "Chill timers cause no knockback")
	mob.position.x = arena.bounds.end.x - mob.radius - 1.0
	shoot(mob)
	mob._physics_process(mob.feedback_definition.knockback_duration)
	check(mob.position.x <= arena.bounds.end.x - mob.radius, "Knockback cannot push mobs outside arena")
	var boss := arena.spawn_enemy("boss", arena.player.position + Vector2(140,0)) as BossActor
	boss.ai_enabled = true
	boss._start_charge_warning()
	start = boss.position
	var endpoint := boss.charge_end
	var state := boss.state
	shoot(boss)
	check(boss.position == start and boss.charge_end == endpoint and boss.state == state, "Boss immunity preserves committed charge position/telegraph/state")
	boss._physics_process(boss.warning_duration)
	start = boss.position
	shoot(boss)
	check(boss.position == start and boss.charge_end == endpoint and boss.state == "charge" and boss.charge_active, "Arrow cannot interrupt or displace an active boss charge")
	# Check real engine-scaled physics, not wall-clock guesses from GUI.
	reset()
	arena.player.process_mode = Node.PROCESS_MODE_PAUSABLE
	Engine.time_scale = 1.0
	await physics_frame
	arena.player.receive_hit(10)
	for i in range(12): await physics_frame
	var normal_elapsed := 0.5 - arena.player.health_state.invulnerability
	check(normal_elapsed > 0.15 and normal_elapsed < 0.23, "Engine physics advances immunity in normal game time")
	arena.player.health_state.invulnerability = 0.0
	Engine.time_scale = 0.25
	# Let a rendered frame apply Engine.time_scale before physics measurement.
	await process_frame
	await process_frame
	await physics_frame
	await physics_frame
	arena.player.receive_hit(10)
	for i in range(12): await physics_frame
	var slow_elapsed := 0.5 - arena.player.health_state.invulnerability
	check(slow_elapsed > 0.045 and slow_elapsed < 0.055, "0.25 time scale advances immunity at quarter speed")
	print("IMMUNITY CLOCK: 12 physics frames normal=%.6f slow=%.6f game seconds" % [normal_elapsed, slow_elapsed])
	paused = true
	var before_pause := arena.player.health_state.invulnerability
	for i in range(12): await process_frame
	check(is_equal_approx(arena.player.health_state.invulnerability, before_pause), "Pause freezes hit immunity game-time countdown")
	paused = false
	Engine.time_scale = 1.0
	game.queue_free()
	await process_frame
	print("DEFENSE/KNOCKBACK: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(1 if failures else 0)
