class_name RageArena
extends Node2D

signal hud_changed
signal level_ready
signal practice_restarted
signal run_ended
signal victory_reached
var run_phase := "campaign"
var progression: AchievementProfile
@export var character_definition: CharacterDefinition = preload("res://resources/characters/archer.tres")
@export var definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
@export var ranged_definition: SpitterDefinition = preload("res://resources/enemies/spitter.tres")
var practice := false
var show_enemy_health: bool = true
var sound_enabled: bool = true
var feedback := FeedbackController.new()
var bounds: Rect2 = definition.normal_bounds
var player: PlayerActor
var follow_camera: ArenaFollowCamera
## Ground-only screen-reading passes must precede every actor and HUD.
var ground_distortions := Node2D.new()
var enemies := Node2D.new()
var arrows := Node2D.new()
var enemy_bullets := Node2D.new()
var effects := Node2D.new()
var stats: CombatStats = character_definition.create_stats()
var ranks: Dictionary = {}
var director := RunDirector.new()
var rng := RandomNumberGenerator.new()
## Set before add_child/_ready for deterministic replay, including seed zero.
var run_seed_override: Variant = null
var run_seed: int = 0
var offer_state := OfferRunState.new()
var kills := 0
var level := 1
var xp := 0
var xp_needed: int = definition.initial_xp_needed
var pickups: Array[Vector2] = []
var bow: BowController
var lab_ai := false
var boss_mode := "alternate"
var practice_boss_identity: String = "mountainbreaker"
var practice_boss_phase: int = 1
# owner instance id -> {owner, positions}; capacity is reserved during telegraphs.
var _summon_reservations: Dictionary = {}
var boss_settings: Dictionary = {}
var hits := 0
var crits := 0
var element_procs := ElementProcController.new()
var total_damage := 0.0
var finished := false
var _damage_feedback_packet: Dictionary = {}
var _practice_restart_pending := false
var _terminal_rewards_open := false
var _terminal_reward_frame := -1

func _ready() -> void:
	if character_definition == null: character_definition = CharacterDefinition.new()
	if definition == null: definition = ArenaDefinition.new()
	if ranged_definition == null: ranged_definition = SpitterDefinition.new()
	stats = character_definition.create_stats()
	if progression == null and not practice:
		progression = AchievementProfile.new()
		progression.persistence_enabled = false
		progression.begin_run(false)
	stats.catalog.progression = progression
	stats.catalog.all_unlocked = practice
	definition = definition.validated_copy()
	ranged_definition = ranged_definition.validated_copy()
	director.configure(definition)
	# Arena and director share this run snapshot, never the authored resource.
	director.definition = definition
	xp_needed = definition.initial_xp_needed
	bounds = definition.practice_bounds if practice else definition.normal_bounds
	boss_settings = {"warning_duration":definition.boss_warning_duration,"charge_width":definition.boss_charge_width,"rock_radius":definition.boss_rock_radius}
	rng.randomize()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="): rng.seed=int(argument.trim_prefix("--seed="))
	if run_seed_override is int: rng.seed = run_seed_override
	run_seed = rng.seed
	# The offer state salts this seed into its own RNG. Never consume combat RNG
	# to select upgrades, and never reset this state when stats/UI are rebuilt.
	offer_state.reset(run_seed)
	add_child(ground_distortions)
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
	player = CombatSceneFactory.player(stats.character.actor_scene)
	player.setup(stats)
	player.arena_bounds = bounds
	player.position = bounds.get_center()
	player.invulnerable = practice
	player.z_index = 3
	player.hit_feedback.connect(_on_player_hit_feedback)
	player.died.connect(_on_death)
	add_child(player)
	follow_camera = ArenaFollowCamera.new()
	follow_camera.name = "ArenaFollowCamera"
	follow_camera.configure(player, bounds, definition.camera_zoom, definition.camera_edge_padding)
	add_child(follow_camera)
	bow = CombatSceneFactory.bow(stats.character.bow.controller_scene)
	bow.setup(player, stats, enemies, arrows, bounds)
	bow.arrow_hit.connect(_on_arrow_hit)
	bow.volley_launched.connect(feedback.launch)
	bow.gravity_damage_callback = _deal_gravity_damage
	player.add_child(bow)
	if player.has_method("bind_presentation_weapon"):
		player.bind_presentation_weapon(bow, self)
	queue_redraw()

func offer_context() -> Dictionary:
	# Authored estimate includes Boss fights; actual elapsed/phase remain authoritative.
	return {"elapsed": director.elapsed,
		"campaign_duration": definition.campaign_expected_duration,
		"phase": run_phase}

func _physics_process(delta: float) -> void:
	if finished or run_phase == "victory": return
	if not practice and xp >= xp_needed:
		award_level()
		return
	if not practice:
		var event := director.tick(delta)
		if progression != null: progression.observe_time(director.elapsed, delta)
		if event.spawn_boss:
			if spawn_enemy("boss") == null: director.boss_spawn_failed()
		if event.spawn_mob: spawn_enemy(_next_enemy_kind())
	for node in enemies.get_children():
		var enemy := node as EnemyActor
		if enemy is BossActor or enemy.health <= 0 or enemy.is_dummy or enemy.contact_damage_suppressed(): continue
		if enemy.position.distance_to(player.position) < enemy.radius + player.radius:
			player.receive_hit(definition.contact_damage * enemy.contact_damage_multiplier)
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

func _on_arrow_hit(arrow: BowArrow, enemy: EnemyActor) -> void:
	if finished or enemy.is_dead: return
	var impact := arrow.impact_position
	var outcome := CombatRules.resolve_projectile(stats, enemy.status, arrow, rng)
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
	if finished or run_phase == "victory": return null
	var is_boss_kind := kind in ["boss", "mountainbreaker", "beastcaller", "wildfire"]
	if not is_boss_kind and _live_enemy_count() + _reserved_summon_count() >= definition.enemy_limit: return null
	if at.x < 0.0:
		at = _safe_spawn_position()
		if not at.is_finite(): return null
	var enemy: EnemyActor
	var archetype: MeleeDefinition
	if is_boss_kind:
		var identity := kind
		if kind == "boss":
			identity = practice_boss_identity if practice else definition.boss_order[director.boss_count % definition.boss_order.size()]
		for existing in enemies.get_children():
			if existing is BossActor and existing.health > 0:
				if not practice or existing.boss_identity == identity: return existing
				_clear_boss_owned_attacks(existing)
				existing.free()
		var boss: BossActor
		match identity:
			"beastcaller": boss = Beastcaller.new()
			"wildfire": boss = Wildfire.new()
			_: boss = preload("res://scenes/bosses/mountainbreaker/mountainbreaker.tscn").instantiate() as Mountainbreaker
		boss.boss_definition = boss.boss_definition.snapshot()
		boss.choice_rng.seed = rng.randi()
		boss.attack_player.connect(player.receive_hit)
		boss.phase_transition_started.connect(func(_phase: int) -> void: feedback.phase_roar())
		boss.reserve_summons = _reserve_summons
		boss.commit_summons = _commit_summons
		boss.cancel_summons = _cancel_summons
		if boss is Mountainbreaker:
			boss.rock_rng.seed = rng.randi()
			boss.ability_mode = boss_mode
			for key: String in boss_settings: boss.set(key,boss_settings[key])
		if boss is Beastcaller:
			boss.shot_requested.connect(func(origin: Vector2, heading: Vector2, settings: SpitterDefinition) -> void: _spawn_enemy_bullet(origin, heading, settings, boss))
		enemy = boss
	elif kind == "ranged":
		var ranged := preload("res://scenes/enemies/spitter/spitter.tscn").instantiate() as Spitter
		ranged.definition = ranged_definition
		ranged.shot_requested.connect(_spawn_enemy_bullet)
		ranged.initial_shot_fraction = rng.randf_range(ranged_definition.initial_shot_min_fraction, ranged_definition.initial_shot_max_fraction)
		enemy = ranged
	else:
		match kind:
			"swiftfang":
				enemy = Swiftfang.new()
				archetype = definition.swiftfang_definition
			"elite_hornling":
				enemy = EliteHornling.new()
				archetype = definition.elite_hornling_definition
			_:
				enemy = preload("res://scenes/enemies/hornling/hornling.tscn").instantiate() as EnemyActor
				archetype = definition.hornling_definition
		(enemy as Hornling).archetype = archetype.validated_copy()
		enemy.is_dummy = kind == "dummy"
	enemy.show_health_bar = show_enemy_health
	enemy.feedback_definition = definition.hit_feedback
	enemy.cosmetic_feedback_enabled = feedback.enabled and feedback.definition.enabled
	enemy.status_feedback.connect(func(status_kind: String, position_at: Vector2) -> void: feedback.status_event(status_kind, position_at, enemy.radius))
	enemy.target = player
	enemy.arena_bounds = bounds
	enemy.ai_enabled = lab_ai if practice else true
	var difficulty := director.mob_health_multiplier()
	if is_boss_kind: enemy.max_health = definition.boss_health * director.boss_health_multiplier() * (enemy as BossActor).boss_definition.health_multiplier
	elif kind == "dummy": enemy.max_health = definition.dummy_health
	else:
		var health_scale := ranged_definition.health_multiplier if kind == "ranged" else archetype.health_multiplier
		enemy.max_health = definition.melee_health * difficulty * health_scale
	enemy.health = enemy.max_health
	enemy.position = at.clamp(bounds.position+Vector2.ONE*definition.spawn_inset,bounds.end-Vector2.ONE*definition.spawn_inset)
	enemy.killed.connect(_on_enemy_killed)
	enemy.damaged.connect(_on_enemy_damaged)
	enemy.damage_resolved.connect(_on_enemy_damage_resolved)
	enemy.mass = definition.boss_mass * (enemy as BossActor).boss_definition.mass_multiplier if is_boss_kind else (ranged_definition.mass if kind == "ranged" else archetype.mass)
	enemies.add_child(enemy)
	if archetype != null: enemy.mass = definition.enemy_mass * archetype.mass
	feedback.attach_enemy(enemy)
	if is_boss_kind:
		if practice: (enemy as BossActor).force_phase_for_practice(practice_boss_phase)
		else: director.boss_alive = true
	if is_instance_valid(bow) and is_instance_valid(bow.active_gravity_arrow): bow.active_gravity_arrow.gravity_field.attach_enemy(enemy)
	enemy._clamp_to_arena()
	return enemy

func set_practice_boss_phase(value: int) -> void:
	practice_boss_phase = clampi(value, 1, 2)
	for actor in enemies.get_children():
		if actor is BossActor:
			_clear_boss_owned_attacks(actor)
			actor.force_phase_for_practice(practice_boss_phase)

func _live_enemy_count() -> int:
	var count := 0
	for actor in enemies.get_children():
		if actor is EnemyActor and not actor.is_dead: count += 1
	return count

func _reserved_summon_count() -> int:
	var count := 0
	for batch: Dictionary in _summon_reservations.values(): count += batch.positions.size()
	return count

func _reserve_summons(positions: Array[Vector2], owner: BossActor) -> bool:
	if finished or run_phase == "victory" or not is_instance_valid(owner) or owner.is_dead or owner.is_queued_for_deletion() or owner.get_parent() != enemies: return false
	var owner_id := owner.get_instance_id()
	if _summon_reservations.has(owner_id): return false
	var live_elites := 0
	for actor in enemies.get_children():
		if actor is EliteHornling and not actor.is_dead and int(actor.get_meta("summoner_id", 0)) == owner_id: live_elites += 1
	if positions.is_empty() or live_elites + positions.size() > owner.boss_definition.elite_live_cap: return false
	if _live_enemy_count() + _reserved_summon_count() + positions.size() > definition.enemy_limit: return false
	var safe_bounds := bounds.grow(-definition.elite_hornling_definition.radius)
	for at in positions:
		if not at.is_finite() or not safe_bounds.has_point(at): return false
	_summon_reservations[owner_id] = {"owner": weakref(owner), "positions": positions.duplicate()}
	return true

func _commit_summons(owner: BossActor) -> void:
	if not is_instance_valid(owner): return
	var owner_id := owner.get_instance_id()
	var batch: Dictionary = _summon_reservations.get(owner_id, {})
	_summon_reservations.erase(owner_id)
	if batch.is_empty() or finished or run_phase == "victory" or owner.is_dead: return
	# Practice edits or external scripted spawns may change limits during a warning.
	# Revalidate atomically; never emit half a reserved ring or cluster.
	if not _reserve_summons(batch.positions, owner): return
	_summon_reservations.erase(owner_id)
	# All positions were reserved as a batch; ordinary spawning cannot consume them.
	for at: Vector2 in batch.positions:
		var elite := spawn_enemy("elite_hornling", at)
		if elite != null:
			elite.position = at
			elite.set_meta("summoner_id", owner_id)

func _cancel_summons(owner: BossActor) -> void:
	if is_instance_valid(owner): _summon_reservations.erase(owner.get_instance_id())

func _clear_boss_owned_attacks(owner: BossActor) -> void:
	_cancel_summons(owner)
	owner.cleanup_owned_hazards()
	for bullet in enemy_bullets.get_children():
		if int(bullet.get_meta("boss_owner_id", 0)) == owner.get_instance_id(): bullet.consume()

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
	if not is_instance_valid(enemy) or enemy.is_dead: return
	var event := FeedbackEvent.impact(source, enemy.global_position)
	deal_damage_packet(enemy, {"damage": amount, "base_damage": 0.0, "elemental_damage": amount, "element": element, "crit": false}, event)

func _on_enemy_damaged(health_lost: float, _critical: bool, _at: Vector2) -> void:
	# Combat statistics always measure actual health loss, never overkill.
	total_damage += health_lost

func _on_enemy_damage_resolved(resolved_damage: float, critical: bool, at: Vector2) -> void:
	# This signal only follows an accepted hit. Components already include all
	# source and victim modifiers; remaining health must not scale the feedback.
	var elemental_amount := float(_damage_feedback_packet.get("elemental_damage", 0.0))
	var base_amount := float(_damage_feedback_packet.get("base_damage", maxf(0.0, resolved_damage - elemental_amount)))
	var element := str(_damage_feedback_packet.get("element", ""))
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
	if not is_finite(amount) or amount <= 0.0: return null
	if effects.get_child_count() >= definition.effect_limit: return null
	var text := FloatingText.new()
	var feedback := definition.damage_feedback
	text.damage_kind = kind
	text.element_type = element
	text.critical = critical
	text.displayed_amount = amount
	text.position = at
	var caption := FloatingText.damage_caption(amount)
	var color := feedback.critical_color if critical else feedback.base_color
	text.font_size = feedback.critical_font_size if critical else feedback.base_font_size
	if kind == "element":
		color = feedback.element_color(element)
		text.font_size = feedback.element_critical_font_size if critical else feedback.element_font_size
	if bool(_damage_feedback_packet.get("feedback_dot", false)): text.font_size = feedback.dot_font_size
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
	if kind in ["block", "break"]:
		feedback.shield_break(player.global_position, player.radius)
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
	if not is_instance_valid(enemy) or enemy.is_dummy or enemy.get_meta("kill_credited", false): return
	if finished:
		# Only lethal damage already resolved before player death may finish its
		# synchronous killed signal. New damage after death cannot earn rewards.
		if not _terminal_rewards_open or Engine.get_process_frames() != _terminal_reward_frame or not enemy.get_meta("terminal_pending_kill", false) or not enemy.is_dead: return
	elif run_phase == "victory": return
	enemy.set_meta("kill_credited", true)
	if progression != null and not practice: progression.record_kill(enemy is BossActor)
	if not finished: feedback.death(enemy)
	kills += 1
	if enemy is BossActor:
		_clear_boss_owned_attacks(enemy)
		director.boss_killed()
		if not practice:
			for i in range(definition.boss_pickup_count): pickups.append(enemy.position+Vector2.from_angle(i*TAU/definition.boss_pickup_count)*definition.boss_pickup_ring)
	elif not practice: pickups.append(enemy.position)
	while pickups.size() > definition.pickup_limit:
		# Bound retained pickups without deleting experience: collect the oldest overflow.
		pickups.remove_at(0)
		xp += definition.pickup_value

	if finished:
		if progression != null and not practice: progression.flush()
		hud_changed.emit()
	if not finished and not practice and run_phase == "campaign" and director.boss_count >= definition.campaign_boss_count:
		run_phase = "victory"
		if progression != null: progression.flush()
		get_tree().paused = true
		victory_reached.emit()

func continue_endless() -> bool:
	if finished or practice or run_phase != "victory": return false
	run_phase = "endless"
	director.endless = true
	return true

func _safe_spawn_position() -> Vector2:
	for attempt in range(definition.spawn_position_attempts):
		var edge := rng.randi_range(0, 3)
		var at := Vector2(rng.randf_range(bounds.position.x + definition.spawn_inset, bounds.end.x - definition.spawn_inset), bounds.position.y + definition.spawn_edge_inset if edge == 0 else bounds.end.y - definition.spawn_edge_inset)
		if edge > 1:
			at = Vector2(bounds.position.x + definition.spawn_edge_inset if edge == 2 else bounds.end.x - definition.spawn_edge_inset, rng.randf_range(bounds.position.y + definition.spawn_inset, bounds.end.y - definition.spawn_inset))
		at = at.clamp(bounds.position + Vector2.ONE * definition.spawn_inset, bounds.end - Vector2.ONE * definition.spawn_inset)
		if practice or not is_instance_valid(player) or at.distance_to(player.position) >= definition.spawn_player_clearance: return at
	return Vector2(INF, INF)

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
	for actor in enemies.get_children():
		if actor is BossActor: _clear_boss_owned_attacks(actor)
	_summon_reservations.clear()
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
	if practice:
		finished = true
		_practice_restart_pending = true
		_summon_reservations.clear()
		for enemy in enemies.get_children():
			enemy.ai_enabled = false
			if enemy is BossActor: _clear_boss_owned_attacks(enemy)
		bow.enabled = false
		call_deferred("_restart_practice_after_death")
		return
	finished = true
	_terminal_reward_frame = Engine.get_process_frames()
	for enemy: EnemyActor in enemies.get_children():
		if enemy.health <= 0.0 and not enemy.is_dummy and not enemy.get_meta("kill_credited", false):
			enemy.set_meta("terminal_pending_kill", true)
			_terminal_rewards_open = true
	if _terminal_rewards_open:
		call_deferred("_finish_terminal_rewards")
	elif progression != null and not practice: progression.end_run()
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
		if enemy is BossActor: _clear_boss_owned_attacks(enemy)
		if enemy is Spitter: enemy.shot_pending = false
	hud_changed.emit()
	run_ended.emit()

func _restart_practice_after_death() -> void:
	# A lethal hit may still be emitting inside a projectile/enemy callback.
	# Reset only after it unwinds, and never resurrect an arena left for a new run.
	if not _practice_restart_pending or not practice or not is_inside_tree() or is_queued_for_deletion(): return
	_practice_restart_pending = false
	clear_enemies()
	stats.hp = stats.max_hp
	stats.shields = stats.shield_capacity
	player.health_state = HealthState.new(stats)
	player.position = bounds.get_center()
	player.dash_left = 0.0
	player.dash_cooldown = 0.0
	player.impact_left = 0.0
	player.impact_kind = ""
	player.healed_total = 0.0
	bow.attack_clock = 0.0
	bow.burst_clock = 0.0
	bow.burst_remaining = 0
	bow.gravity_gap_remaining = 0.0
	bow.gravity_gap_started_frame = -1
	bow.enabled = true
	for element in element_procs.proc_counts: element_procs.proc_counts[element] = 0
	hits = 0
	crits = 0
	total_damage = 0.0
	kills = 0
	level = 1
	xp = 0
	xp_needed = definition.initial_xp_needed
	director.configure(definition)
	director.definition = definition
	run_phase = "campaign"
	_terminal_rewards_open = false
	_terminal_reward_frame = -1
	finished = false
	hud_changed.emit()
	practice_restarted.emit()


func _finish_terminal_rewards() -> void:
	_terminal_rewards_open = false
	# Main may already have detached this arena and begun a new shared-profile
	# run. Never let an old deferred finalizer deactivate that new run.
	if not is_inside_tree() or is_queued_for_deletion(): return
	if progression != null and not practice: progression.end_run()


func _draw() -> void:
	# Decorative apron only: collisions, spawn bounds, projectiles and hazard
	# clipping keep using the unchanged simulation rectangle below.
	var apron := bounds.grow(definition.camera_edge_padding + 8.0)
	draw_rect(apron, Color("111b28"), true)
	for x in range(int(apron.position.x), int(apron.end.x), 48):
		draw_line(Vector2(x, apron.position.y), Vector2(x, apron.end.y), Color(0.16, 0.22, 0.28, 0.12), 1, true)
	for y in range(int(apron.position.y), int(apron.end.y), 48):
		draw_line(Vector2(apron.position.x, y), Vector2(apron.end.x, y), Color(0.16, 0.22, 0.28, 0.12), 1, true)
	draw_rect(bounds.grow(8),Color("323d54"),true)
	draw_rect(bounds,Color("172333"),true)
	for x in range(int(bounds.position.x),int(bounds.end.x),48):
		draw_line(Vector2(x,bounds.position.y),Vector2(x,bounds.end.y),Color(0.2,0.3,0.36,0.18),1,true)
	for y in range(int(bounds.position.y),int(bounds.end.y),48):
		draw_line(Vector2(bounds.position.x,y),Vector2(bounds.end.x,y),Color(0.2,0.3,0.36,0.18),1,true)
	draw_rect(bounds.grow(-5),Color("42516a"),false,2)
	for corner in [bounds.position+Vector2(20,20),bounds.end-Vector2(20,20),Vector2(bounds.end.x-20,bounds.position.y+20),Vector2(bounds.position.x+20,bounds.end.y-20)]:
		draw_circle(corner,6,Color("6d7297"))
	for pickup in pickups:
		draw_circle(pickup,8,Color(0.25,0.9,0.7,0.13))
		draw_colored_polygon(PackedVector2Array([pickup+Vector2(0,-5),pickup+Vector2(4,0),pickup+Vector2(0,5),pickup+Vector2(-4,0)]),Color("74f0ba"))

func _next_enemy_kind() -> String:
	var ranged_count := 0
	var swift_count := 0
	for enemy in enemies.get_children():
		if enemy.is_dead: continue
		if enemy is Spitter: ranged_count += 1
		if enemy is Swiftfang: swift_count += 1
	if director.elapsed >= definition.ranged_intro_time and ranged_count < director.ranged_admission_limit() and rng.randf() < definition.ranged_fraction: return "ranged"
	if director.elapsed >= definition.swiftfang_intro_time and swift_count < definition.swiftfang_limit and rng.randf() < definition.swiftfang_fraction: return "swiftfang"
	return "mob"

func _spawn_enemy_bullet(at: Vector2, direction: Vector2, settings: SpitterDefinition, owner: BossActor = null) -> void:
	if finished or run_phase == "victory" or enemy_bullets.get_child_count() >= definition.enemy_projectile_limit: return
	if owner != null and owner.is_dead: return
	var bullet := EnemyBullet.new()
	bullet.setup(at, direction, settings, player)
	bullet.arena_bounds = bounds
	if owner != null: bullet.set_meta("boss_owner_id", owner.get_instance_id())
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
