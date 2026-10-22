class_name RageArena
extends Node2D

signal hud_changed
signal level_ready
signal run_ended
@export var character_definition: CharacterDefinition = preload("res://resources/cat.tres")
@export var definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
@export var ranged_definition: RangedDefinition = preload("res://resources/settings/ranged.tres")
var practice := false
var show_enemy_health: bool = true
var sound_enabled: bool = true
var feedback := FeedbackController.new()
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
var element_procs := ElementProcController.new()
var total_damage := 0.0
var finished := false
var _damage_feedback_packet: Dictionary = {}

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
	element_procs.arena = self
	add_child(element_procs)
	element_procs.z_index = 2
	effects.z_index = 4
	feedback.definition = definition.hit_feedback
	add_child(feedback)
	feedback.set_audio_enabled(sound_enabled)
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
	bow.volley_launched.connect(feedback.launch)
	bow.gravity_damage_callback = _deal_gravity_damage
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
		if enemy is BossActor or enemy.health <= 0 or enemy.is_dummy or enemy.contact_damage_suppressed(): continue
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
	if finished or enemy.is_dead: return
	var impact := arrow.impact_position
	var outcome := CombatRules.resolve_direct(stats, enemy.status, stats.arrow_damage, rng.randf(), arrow.retention * arrow.damage_scale, arrow.secondary)
	hits += 1
	if outcome.crit: crits += 1
	var event := FeedbackEvent.impact(FeedbackEvent.Source.DIRECT, impact, arrow.direction)
	event.shattered = bool(outcome.get("ice_consumed", false))
	deal_damage_packet(enemy, outcome, event)
	# Resolve even lethal first impacts using recorded collision geometry.
	element_procs.on_hit(arrow, enemy, outcome, impact)
	var converts_knockback := stats.active_element == "dark" and stats.element_skill_rank > 0
	if not converts_knockback and not enemy.is_dead: enemy.knockback(arrow.direction, stats.knockback)

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
	enemy.show_health_bar = show_enemy_health
	enemy.feedback_definition = definition.hit_feedback
	enemy.cosmetic_feedback_enabled = feedback.enabled and feedback.definition.enabled
	enemy.status_feedback.connect(func(kind: String, at: Vector2) -> void: feedback.status_event(kind, at, enemy.radius))
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
	enemy.mass = definition.boss_mass if kind == "boss" else (ranged_definition.mass if kind == "ranged" else definition.enemy_mass)
	enemies.add_child(enemy)
	if is_instance_valid(bow) and is_instance_valid(bow.active_gravity_arrow):
		bow.active_gravity_arrow.gravity_field.attach_enemy(enemy)
	enemy._clamp_to_arena()
	return enemy

func deal_damage_packet(enemy: EnemyActor, packet: Dictionary, event: FeedbackEvent = null) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead: return
	# receive_damage emits synchronously, keeping one health event and one proc.
	var previous := _damage_feedback_packet
	# Victim-side elemental vulnerability is applied exactly once here. Keep
	# source precrit values untouched for chains, explosions and burn snapshots.
	var resolved := packet.duplicate()
	var elemental := float(packet.get("elemental_damage", 0.0))
	var bonus := elemental * (enemy.status.elemental_multiplier() - 1.0)
	resolved.elemental_damage = elemental + bonus
	resolved.damage = float(packet.damage) + bonus
	resolved.feedback_dot = event != null and event.is_dot()
	_damage_feedback_packet = resolved
	var before := enemy.health
	enemy.receive_damage(float(resolved.damage), bool(resolved.get("crit", false)))
	if event != null and before > enemy.health:
		event.actual_damage = before - enemy.health
		event.critical = bool(resolved.get("crit", false))
		event.element = str(resolved.get("element", ""))
		event.enemy_id = enemy.get_instance_id()
		enemy.cosmetic_feedback_enabled = feedback.enabled and feedback.definition.enabled
		if event.has_movement_reaction(): enemy.request_hit_reaction(event.source == FeedbackEvent.Source.DIRECT)
		feedback.present(event, enemy)
	_damage_feedback_packet = previous

func deal_element_damage(enemy: EnemyActor, amount: float, element: String, source: FeedbackEvent.Source = FeedbackEvent.Source.UNKNOWN) -> void:
	var event := FeedbackEvent.impact(source, enemy.global_position)
	deal_damage_packet(enemy, {"damage": amount, "base_damage": 0.0, "elemental_damage": amount, "element": element, "crit": false}, event)

func _on_enemy_damaged(amount: float, critical: bool, at: Vector2) -> void:
	# Sum actual health loss once. Display overkill proportionally by component.
	total_damage += amount
	var base_amount := amount
	var elemental_amount := 0.0
	var element := str(_damage_feedback_packet.get("element", ""))
	var nominal := float(_damage_feedback_packet.get("damage", 0.0))
	if nominal > 0.0:
		base_amount = amount * float(_damage_feedback_packet.get("base_damage", nominal)) / nominal
		elemental_amount = maxf(0.0, amount - base_amount)
	# Round one component, assign the remaining displayed hundredths to the other.
	var displayed_total := snappedf(amount, 0.01)
	base_amount = minf(displayed_total, snappedf(base_amount, 0.01))
	elemental_amount = maxf(0, displayed_total - base_amount) if elemental_amount > 0 else 0.0
	var feedback := definition.damage_feedback
	var base_popup: FloatingText
	var element_popup: FloatingText
	if base_amount > 0:
		base_popup = _damage_popup(base_amount, "base", "", critical, at + feedback.base_offset)
	if elemental_amount > 0:
		element_popup = _damage_popup(elemental_amount, "element", element, critical, at + feedback.element_offset)

	if base_popup != null and element_popup != null:
		_separate_popups(base_popup, element_popup)
		base_popup.paired_follower = weakref(element_popup)
		element_popup.paired_leader = weakref(base_popup)
		element_popup.pair_offset = element_popup.position - base_popup.position

func _damage_popup(amount: float, kind: String, element: String, critical: bool, at: Vector2) -> FloatingText:
	if effects.get_child_count() >= definition.effect_limit: return null
	var text := FloatingText.new()
	var feedback := definition.damage_feedback
	text.damage_kind = kind
	text.element_type = element
	text.critical = critical
	text.displayed_amount = amount
	text.position = at
	var caption := UpgradeDefinition.number(amount)
	var color := feedback.critical_color if critical else feedback.base_color
	text.font_size = feedback.critical_font_size if critical else feedback.base_font_size
	if kind == "element":
		var ability := stats.catalog.definition(element + "_bow")
		var prefix := element.substr(0, 1).to_upper()
		if ability != null and ability.element_skill != null:
			color = ability.element_skill.color
			if not ability.element_skill.popup_label.is_empty(): prefix = ability.element_skill.popup_label
		text.font_size = feedback.element_critical_font_size if critical else feedback.element_font_size
		caption = prefix + " " + caption
	if bool(_damage_feedback_packet.get("feedback_dot", false)): text.font_size = feedback.dot_font_size
	if critical: caption = "CRIT " + caption
	text.setup(caption, color)
	effects.add_child(text)
	text.limit_to_area(bounds.grow(-feedback.bounds_inset))
	return text

func _separate_popups(base: FloatingText, elemental: FloatingText) -> void:
	var base_rect := Rect2(base.position + base.label.position, base.label.get_combined_minimum_size())
	var element_rect := Rect2(elemental.position + elemental.label.position, elemental.label.get_combined_minimum_size())
	if not base_rect.intersects(element_rect): return
	elemental.position.y = base_rect.end.y + 4 - elemental.label.position.y
	elemental.limit_to_area(bounds.grow(-definition.damage_feedback.bounds_inset))
	element_rect = Rect2(elemental.position + elemental.label.position, elemental.label.get_combined_minimum_size())
	if base_rect.intersects(element_rect):
		base.position.y = element_rect.position.y - base_rect.size.y - 4 - base.label.position.y
		base.limit_to_area(bounds.grow(-definition.damage_feedback.bounds_inset))

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
	feedback.death(enemy)
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

func select_upgrade(key: String) -> void:
	apply_ranks(stats.catalog.apply_choice(ranks, key))

func apply_ranks(value: Dictionary) -> void:
	var previous := stats.active_element
	var previous_gravity := stats.gravity_mode()
	var previous_ranks := stats.ranks.duplicate()
	stats.apply_ranks(value)
	ranks = stats.ranks.duplicate()
	if previous_ranks != stats.ranks and is_instance_valid(bow): bow.remove_gravity()
	if previous != stats.active_element or previous_gravity != stats.gravity_mode():
		# Deterministic switch boundary: no stale projectiles, statuses or fields.
		for arrow in arrows.get_children():
			arrows.remove_child(arrow)
			arrow.queue_free()
		element_procs.clear(true)
		feedback.clear()
		for enemy in enemies.get_children():
			enemy.status.clear()
			enemy.clear_hit_reaction()
		if is_instance_valid(bow): bow.burst_remaining = 0
	hud_changed.emit()

func clear_enemies() -> void:
	feedback.clear()
	if is_instance_valid(bow): bow.remove_gravity()
	element_procs.clear(true)
	if is_instance_valid(bow): bow.burst_remaining = 0
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
	feedback.clear()
	bow.remove_gravity(true)
	element_procs.clear()
	for arrow in arrows.get_children(): arrow.queue_free()
	for enemy in enemies.get_children():
		enemy.status.clear()
		enemy.clear_hit_reaction()
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

func set_enemy_health_bars(enabled: bool) -> void:
	show_enemy_health = enabled
	for enemy: EnemyActor in enemies.get_children():
		enemy.show_health_bar = enabled
		enemy.queue_redraw()

func set_sound_enabled(value: bool) -> void:
	sound_enabled = value
	feedback.set_audio_enabled(value)

func _deal_gravity_damage(enemy: EnemyActor, amount: float, element: String) -> void:
	deal_element_damage(enemy, amount, element, FeedbackEvent.Source.GRAVITY)
