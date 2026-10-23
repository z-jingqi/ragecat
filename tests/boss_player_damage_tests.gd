extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player := Archer.new()
	player.setup(preload("res://resources/characters/archer.tres").create_stats())
	player.arena_bounds = Rect2(-2000,-2000,4000,4000)
	world.add_child(player)
	player.set_physics_process(false)
	player.movement_enabled = false
	var health := player.stats.hp
	check(is_equal_approx(player.stats.dash_cooldown_duration,2.0),"existing dash cooldown unchanged")
	for interval in [0.0,2.5,3.5]:
		player._physics_process(interval)
		check(player.dash_cooldown <= 0.0,"next ring permits cooldown to recover")
		player.position = Vector2(240,0)
		player.dash_direction = Vector2.LEFT
		player.dash_left = player.stats.dash_duration
		player.dash_cooldown = player.stats.dash_cooldown_duration
		var ring := BossFireRing.new()
		ring.target = player
		ring.ring_radius = 180
		ring.hit.connect(player.receive_hit)
		world.add_child(ring)
		ring.set_physics_process(false)
		for step in range(10):
			player._physics_process(1.0/60)
			ring._physics_process(1.0/60)
		check(ring.consumed,"dash crosses actual swept ring band")
		check(player.stats.hp == health,"dash iframe prevents ring damage")
		ring.free()
	player.dash_left = 0.0
	player.stats.shields = 1
	player.health_state.invulnerability = 0.0
	player.receive_hit(12)
	check(player.stats.shields == 0 and player.stats.hp == health,"shield absorbs whole boss hit")
	player.receive_hit(100)
	check(player.stats.hp == health,"shield shared protection blocks simultaneous hazard")
	player._physics_process(1.0)
	player.receive_hit(12)
	check(player.stats.hp == health-12,"damage resumes after protection")
	player.health_state.invulnerability = 0.0
	player.position = Vector2(120,-100)
	var projectile := EnemyBullet.new()
	projectile.setup(Vector2.ZERO,Vector2.RIGHT,SpitterDefinition.new(),player)
	world.add_child(projectile)
	projectile.set_physics_process(false)
	var before_projectile := player.stats.hp
	player.position = Vector2(120,100)
	projectile._physics_process(1.0)
	check(projectile.consumed and player.stats.hp < before_projectile,"moving player cannot tunnel across projectile")
	projectile.free()
	player.health_state.invulnerability = 0.0
	player.position = Vector2(120,-100)
	projectile = EnemyBullet.new()
	projectile.setup(Vector2.ZERO,Vector2.RIGHT,SpitterDefinition.new(),player)
	projectile.arena_bounds = Rect2(-20,-200,70,400)
	world.add_child(projectile)
	projectile.set_physics_process(false)
	before_projectile = player.stats.hp
	player.position = Vector2(120,100)
	projectile._physics_process(1.0)
	check(projectile.consumed and player.stats.hp == before_projectile,"wall cutoff excludes later target crossing")
	projectile.free()
	var skill := ElementSkillDefinition.new()
	for actor: BossActor in [Mountainbreaker.new(),Beastcaller.new(),Wildfire.new()]:
		world.add_child(actor)
		actor.set_physics_process(false)
		for hit in range(5): actor.status.apply_ice(skill,1,true)
		check(not actor.status.is_frozen() and actor.status.has_ice_mark(),"all boss identities use marks not freeze")
		actor.free()
	world.free()
	print("BOSS PLAYER DAMAGE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
