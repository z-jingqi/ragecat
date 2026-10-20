class_name RageArena
extends Node2D

signal hud_changed
signal level_ready
signal run_ended
var practice := false
var bounds := Rect2(48,104,1184,620)
var player: CatPlayer
var enemies := Node2D.new()
var arrows := Node2D.new()
var effects := Node2D.new()
var stats := (preload("res://resources/cat.tres") as CharacterDefinition).create_stats()
var ranks: Dictionary = {}
var director := RunDirector.new()
var rng := RandomNumberGenerator.new()
var kills := 0
var level := 1
var xp := 0
var xp_needed := 8
var pickups: Array[Vector2] = []
var bow: BowController
var lab_ai := false
var boss_mode := "alternate"
var boss_settings: Dictionary = {"warning_duration":1.0,"charge_width":80.0,"rock_radius":35.0}
var hits := 0
var crits := 0
var poison_hits := 0
var bleed_hits := 0
var total_damage := 0.0
var finished := false

func _ready() -> void:
	rng.randomize()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): rng.seed=int(argument.trim_prefix("--seed="))
	if practice: bounds = Rect2(36,104,876,620)
	add_child(enemies)
	add_child(arrows)
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
		if event.spawn_mob: spawn_enemy("mob")
	for node in enemies.get_children():
		var enemy := node as EnemyActor
		if enemy is BossActor or enemy.health <= 0 or enemy.is_dummy: continue
		if enemy.position.distance_to(player.position) < enemy.radius + 16:
			player.receive_hit(10.0)
			if finished: return
	for i in range(pickups.size()-1,-1,-1):
		var distance := pickups[i].distance_to(player.position)
		if distance <= stats.pickup_radius:
			pickups[i] = pickups[i].move_toward(player.position,delta*360)
		if distance < 20:
			pickups.remove_at(i)
			xp += 1
			if xp >= xp_needed:
				award_level()
				return
	hud_changed.emit()
	queue_redraw()

func award_level() -> void:
	xp -= xp_needed
	level += 1
	xp_needed = mini(60,8 + level*3)
	level_ready.emit()

func _on_arrow_hit(arrow: CatArrow, enemy: EnemyActor) -> void:
	var outcome := CombatRules.resolve_direct(stats,enemy.status,stats.arrow_damage,rng.randf(),arrow.retention*arrow.damage_scale)
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
	if float(outcome.sustain) > 0.0: player.regen_buff_left = 3.0
	if outcome.spread and not arrow.spread_used:
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
	if kind != "boss" and enemies.get_child_count() >= 69: return null
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
	else:
		enemy = preload("res://scenes/enemies/chaser.tscn").instantiate() as EnemyActor
		enemy.is_dummy = kind == "dummy"
	enemy.target = player
	enemy.arena_bounds = bounds
	enemy.ai_enabled = lab_ai if practice else true
	var difficulty := 1.0 + minf(director.elapsed/180.0,8.0)
	if kind == "boss":
		enemy.max_health = 900.0 * (1.0+director.boss_count*0.45)
	elif kind == "dummy": enemy.max_health = 100000.0
	else: enemy.max_health = 34.0*difficulty
	enemy.health = enemy.max_health
	if at.x < 0:
		var edge := rng.randi_range(0,3)
		at = Vector2(rng.randf_range(bounds.position.x+40,bounds.end.x-40), bounds.position.y+35 if edge == 0 else bounds.end.y-35)
		if edge > 1: at = Vector2(bounds.position.x+35 if edge == 2 else bounds.end.x-35,rng.randf_range(bounds.position.y+40,bounds.end.y-40))
	enemy.position = at.clamp(bounds.position+Vector2(40,40),bounds.end-Vector2(40,40))
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(_on_enemy_damaged)
	enemies.add_child(enemy)
	return enemy

func _on_enemy_damaged(amount: float, critical: bool, at: Vector2) -> void:
	# All health loss (arrows and DOT) passes through this one accounting point.
	total_damage += amount
	if effects.get_child_count() > 70: return
	var text := FloatingText.new()
	text.position = at
	text.setup(("! " if critical else "")+str(roundi(amount)),Color("ffe395") if critical else Color("c9e9e8"))
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
			for i in range(12): pickups.append(enemy.position+Vector2.from_angle(i*TAU/12)*22)
	elif not practice: pickups.append(enemy.position)
	while pickups.size() > 250:
		# Bound retained pickups without deleting experience: collect the oldest overflow.
		pickups.remove_at(0)
		xp += 1

func apply_ranks(value: Dictionary) -> void:
	ranks = value.duplicate()
	stats.apply_ranks(ranks)
	hud_changed.emit()

func clear_enemies() -> void:
	for node in enemies.get_children(): node.free()
	for node in arrows.get_children(): node.free()
	for node in effects.get_children(): node.queue_free()
	pickups.clear()
	director.boss_alive = false
	queue_redraw()

func _on_death() -> void:
	if finished: return
	finished = true
	bow.enabled = false
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
