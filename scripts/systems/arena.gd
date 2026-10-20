class_name RageArena
extends Node2D

signal hud_changed
signal level_ready
signal run_ended
@export var character_definition: CharacterDefinition = preload("res://resources/cat.tres")
@export var definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
@export var ranged_definition: RangedDefinition = preload("res://resources/settings/ranged.tres")
var practice := false
var bounds: Rect2 = definition.normal_bounds
var player: CatPlayer
var enemies := Node2D.new()
var arrows := Node2D.new()
var enemy_bullets := Node2D.new()
var effects := Node2D.new()
var stats: CombatStats = character_definition.create_stats()
var ranks: Dictionary = {}
var director := RunDirector.new()
var rng := RandomNumberGenerator.new()
var kills := 0
var level := 1
var xp := 0
var xp_needed: int = definition.initial_xp_needed
var pickups: Array[Vector2] = []
var bow: BowController
var lab_ai := false
var boss_mode := "alternate"
var boss_settings: Dictionary = {}
var hits := 0
var crits := 0
var poison_hits := 0
var bleed_hits := 0
var total_damage := 0.0
var finished := false

func _ready() -> void:
	if character_definition == null: character_definition = CharacterDefinition.new()
	if definition == null: definition = ArenaDefinition.new()
	if ranged_definition == null: ranged_definition = RangedDefinition.new()
	stats = character_definition.create_stats()
	definition = definition.validated_copy()
	ranged_definition = ranged_definition.validated_copy()
	director.configure(definition)
	xp_needed = definition.initial_xp_needed
	bounds = definition.practice_bounds if practice else definition.normal_bounds
	boss_settings = {"warning_duration":definition.boss_warning_duration,"charge_width":definition.boss_charge_width,"rock_radius":definition.boss_rock_radius}
	rng.randomize()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): rng.seed=int(argument.trim_prefix("--seed="))
	add_child(enemies)
	add_child(arrows)
	add_child(enemy_bullets)
	add_child(effects)
	effects.z_index = 4
	player = preload("res://scenes/characters/cat.tscn").instantiate() as CatPlayer
	player.setup(stats)
	player.arena_bounds = bounds
	player.position = bounds.get_center()
	player.invulnerable = practice
	player.z_index = 3
	player.hit_feedback.connect(_on_player_hit_feedback)
	player.died.connect(_on_death)
	add_child(player)
	bow = preload("res://scenes/weapons/bow.tscn").instantiate() as BowController
	bow.setup(player, stats, enemies, arrows, bounds)
	bow.arrow_hit.connect(_on_arrow_hit)
	player.add_child(bow)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if finished: return
	if not practice and xp >= xp_needed:
		award_level()
		return
	if not practice:
		var event := director.tick(delta)
		if event.spawn_boss: spawn_enemy("boss")
		if event.spawn_mob: spawn_enemy(_next_enemy_kind())
	for node in enemies.get_children():
		var enemy := node as EnemyActor
		if enemy is BossActor or enemy.health <= 0 or enemy.is_dummy: continue
		if enemy.position.distance_to(player.position) < enemy.radius + player.radius:
			player.receive_hit(definition.contact_damage)
			if finished: return
	for i in range(pickups.size()-1,-1,-1):
		var distance := pickups[i].distance_to(player.position)
		if distance <= stats.pickup_radius:
			pickups[i] = pickups[i].move_toward(player.position,delta*definition.pickup_speed)
		if distance < definition.pickup_collect_radius:
			pickups.remove_at(i)
			xp += definition.pickup_value
			if xp >= xp_needed:
				award_level()
				return
	hud_changed.emit()
	queue_redraw()

func award_level() -> void:
	xp -= xp_needed
	level += 1
	xp_needed = mini(definition.xp_limit,definition.xp_base + level*definition.xp_per_level)
	level_ready.emit()

func _on_arrow_hit(arrow: CatArrow, enemy: EnemyActor) -> void:
	var outcome := CombatRules.resolve_direct(stats,enemy.status,stats.arrow_damage,rng.randf(),arrow.retention*arrow.damage_scale,arrow.secondary)
	hits += 1
	if outcome.crit: crits += 1
	enemy.receive_damage(float(outcome.damage),bool(outcome.crit))
	enemy.knockback(arrow.direction, stats.knockback)
	if stats.poison_dps > 0:
		enemy.status.apply_poison(stats.poison_dps,stats.poison_duration)
		poison_hits += 1
	if stats.bleed_dps > 0:
		enemy.status.apply_bleed(stats.bleed_dps,stats.bleed_duration)
		bleed_hits += 1
	if float(outcome.sustain) > 0.0: player.regen_buff_left = stats.bleed_regen_duration
	if outcome.spread and not arrow.spread_used and stats.spread_max_targets > 0:
		arrow.spread_used = true
		var count := 0
		for node in enemies.get_children():
			var nearby := node as EnemyActor
			if nearby == enemy or nearby.health <= 0: continue
			if nearby.position.distance_to(enemy.position) <= stats.spread_radius:
				nearby.status.apply_poison(stats.poison_dps,stats.poison_duration)
				count += 1
				if count >= stats.spread_max_targets: break

func spawn_enemy(kind: String, at: Vector2 = Vector2(-1,-1)) -> EnemyActor:
	if kind != "boss" and enemies.get_child_count() >= definition.enemy_limit: return null
	var enemy: EnemyActor
	if kind == "boss":
		for existing in enemies.get_children():
			if existing is BossActor and existing.health > 0: return existing
		var boss := preload("res://scenes/bosses/arena_boss.tscn").instantiate() as BossActor
		boss.rock_rng.seed = rng.randi()
		boss.ability_mode = boss_mode
		boss.attack_player.connect(player.receive_hit)
		for key: String in boss_settings: boss.set(key,boss_settings[key])
		enemy = boss
	elif kind == "ranged":
		var ranged := preload("res://scenes/enemies/ranged.tscn").instantiate() as RangedEnemy
		ranged.definition = ranged_definition
		ranged.shot_requested.connect(_spawn_enemy_bullet)
		enemy = ranged
	else:
		enemy = preload("res://scenes/enemies/chaser.tscn").instantiate() as EnemyActor
		enemy.is_dummy = kind == "dummy"
	enemy.status.configure(stats.combat_definition)
	enemy.target = player
	enemy.arena_bounds = bounds
	enemy.ai_enabled = lab_ai if practice else true
	var difficulty := 1.0 + minf(director.elapsed/definition.difficulty_period,definition.difficulty_bonus_cap)
	if kind == "boss":
		enemy.max_health = definition.boss_health * (1.0+director.boss_count*definition.boss_health_increment)
	elif kind == "dummy": enemy.max_health = definition.dummy_health
	else: enemy.max_health = definition.melee_health*difficulty*(ranged_definition.health_multiplier if kind == "ranged" else 1.0)
	enemy.health = enemy.max_health
	if at.x < 0:
		var edge := rng.randi_range(0,3)
		at = Vector2(rng.randf_range(bounds.position.x+definition.spawn_inset,bounds.end.x-definition.spawn_inset), bounds.position.y+definition.spawn_edge_inset if edge == 0 else bounds.end.y-definition.spawn_edge_inset)
		if edge > 1: at = Vector2(bounds.position.x+definition.spawn_edge_inset if edge == 2 else bounds.end.x-definition.spawn_edge_inset,rng.randf_range(bounds.position.y+definition.spawn_inset,bounds.end.y-definition.spawn_inset))
	enemy.position = at.clamp(bounds.position+Vector2.ONE*definition.spawn_inset,bounds.end-Vector2.ONE*definition.spawn_inset)
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(_on_enemy_damaged)
	enemies.add_child(enemy)
	enemy._clamp_to_arena()
	return enemy

func _on_enemy_damaged(amount: float, critical: bool, at: Vector2) -> void:
	# All health loss (arrows and DOT) passes through this one accounting point.
	total_damage += amount
	if effects.get_child_count() >= definition.effect_limit: return
	var text := FloatingText.new()
	text.position = at
	text.setup(("! " if critical else "")+UpgradeDefinition.number(amount),Color("ffe395") if critical else Color("c9e9e8"))
	effects.add_child(text)

func _on_player_hit_feedback(kind: String, amount: float) -> void:
	var text := FloatingText.new()
	text.position = player.position + Vector2(0, -44)
	text.life = 0.9
	var caption := "-%d HP" % roundi(amount)
	var color := Color("ff8295")
	if kind == "block":
		caption = "BLOCK"
		color = Color("8ceaff")
	elif kind == "break":
		caption = "SHIELD BROKEN"
		color = Color("8ceaff")
	text.setup(caption, color)
	effects.add_child(text)
	text.limit_to_area(bounds.grow(-6))

func _on_enemy_killed(enemy: EnemyActor) -> void:
	kills += 1
	if enemy is BossActor:
		director.boss_killed()
		if not practice:
			for i in range(definition.boss_pickup_count): pickups.append(enemy.position+Vector2.from_angle(i*TAU/definition.boss_pickup_count)*definition.boss_pickup_ring)
	elif not practice: pickups.append(enemy.position)
	while pickups.size() > definition.pickup_limit:
		# Bound retained pickups without deleting experience: collect the oldest overflow.
		pickups.remove_at(0)
		xp += definition.pickup_value

func apply_ranks(value: Dictionary) -> void:
	ranks = value.duplicate()
	stats.apply_ranks(ranks)
	hud_changed.emit()

func clear_enemies() -> void:
	for node in enemies.get_children(): node.free()
	for node in arrows.get_children(): node.free()
	for node in enemy_bullets.get_children(): node.free()
	for node in effects.get_children(): node.queue_free()
	pickups.clear()
	director.boss_alive = false
	queue_redraw()

func _on_death() -> void:
	if finished: return
	finished = true
	bow.enabled = false
	for bullet in enemy_bullets.get_children(): bullet.queue_free()
	for enemy in enemies.get_children():
		enemy.ai_enabled = false
		if enemy is RangedEnemy: enemy.shot_pending = false
	hud_changed.emit()
	run_ended.emit()

func _draw() -> void:
	draw_rect(bounds.grow(8),Color("323d54"),true)
	draw_rect(bounds,Color("172333"),true)
	for x in range(int(bounds.position.x),int(bounds.end.x),48):
		draw_line(Vector2(x,bounds.position.y),Vector2(x,bounds.end.y),Color(0.2,0.3,0.36,0.18),1)
	for y in range(int(bounds.position.y),int(bounds.end.y),48):
		draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color(0.2,0.3,0.36,0.18),1)
	draw_rect(bounds.grow(-5),Color("42516a"),false,2)
	for corner in [bounds.position+Vector2(20,20),bounds.end-Vector2(20,20),Vector2(bounds.end.x-20,bounds.position.y+20),Vector2(bounds.position.x+20,bounds.end.y-20)]:
		draw_circle(corner,6,Color("6d7297"))
	for pickup in pickups:
		draw_circle(pickup,8,Color(0.25,0.9,0.7,0.13))
		draw_colored_polygon(PackedVector2Array([pickup+Vector2(0,-5),pickup+Vector2(4,0),pickup+Vector2(0,5),pickup+Vector2(-4,0)]),Color("74f0ba"))

func _next_enemy_kind() -> String:
	if director.elapsed < definition.ranged_intro_time: return "mob"
	var count := 0
	for enemy in enemies.get_children():
		if enemy is RangedEnemy and not enemy.is_dead: count += 1
	if count >= definition.ranged_limit: return "mob"
	return "ranged" if rng.randf() < definition.ranged_fraction else "mob"

func _spawn_enemy_bullet(at: Vector2, direction: Vector2, settings: RangedDefinition) -> void:
	if finished or enemy_bullets.get_child_count() >= definition.enemy_projectile_limit: return
	var bullet := EnemyBullet.new()
	bullet.setup(at, direction, settings, player)
	bullet.ai_enabled = lab_ai if practice else true
	enemy_bullets.add_child(bullet)

func set_enemy_ai(enabled: bool) -> void:
	lab_ai = enabled
	for enemy in enemies.get_children(): enemy.ai_enabled = enabled
	for bullet in enemy_bullets.get_children(): bullet.ai_enabled = enabled
