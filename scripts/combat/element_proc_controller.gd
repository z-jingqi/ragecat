class_name ElementProcController
extends Node2D
## Direct impacts dispatch skills; derived damage never returns through on_hit.
var arena: RageArena
var burns: Dictionary = {} # Instance ID -> one BurnEffect, with a weak target reference.
var proc_counts: Dictionary = {"fire": 0, "lightning": 0, "ice": 0, "dark": 0}
func clear(_preserve_cooldown: bool = false) -> void:
	burns.clear()
	queue_redraw()
	for child in get_children():
		remove_child(child)
		child.queue_free()
func on_hit(arrow: CatArrow, target: EnemyActor, packet: Dictionary, hit_position: Vector2) -> void:
	var first := not arrow.element_proc_used
	arrow.element_proc_used = true # A denied first impact can never queue a later proc.
	var skill := arena.stats.element_skill
	var rank := arena.stats.element_skill_rank
	if skill == null or rank <= 0: return
	# Direct fragments carry the same elemental eligibility as primary arrows.
	if arrow.secondary and skill.element_id not in ["fire", "lightning", "ice"]: return
	if skill.element_id == "ice":
		if not target.is_dead and not bool(packet.get("ice_consumed", false)):
			var frozen_before := target.status.is_frozen()
			var marked_before := target.status.has_ice_mark()
			target.status.apply_ice(skill, rank, target is BossActor)
			if not frozen_before and target.status.is_frozen(): arena.feedback.status_event("freeze", target.global_position, target.radius)
			if not marked_before and target.status.has_ice_mark(): arena.feedback.status_event("mark", target.global_position, target.radius)
			proc_counts.ice += 1
		return
	if not first and skill.element_id != "lightning": return
	var elemental: float = float(packet.elemental_precrit)
	match skill.element_id:
		"fire":
			_try_burn(target, elemental, skill, rank, "direct")
			_blast(target, hit_position, elemental, skill, rank)
		"lightning":
			_try_shock(target, skill, rank)
			_chain(target, target.position, elemental, skill, rank)
func _blast(primary: EnemyActor, at: Vector2, elemental: float, skill: ElementSkillDefinition, rank: int) -> void:
	var radius := skill.parameter(skill.radius_by_rank, rank)
	var amount := elemental * skill.parameter(skill.damage_by_rank, rank)
	for node in arena.enemies.get_children():
		var enemy := node as EnemyActor
		if enemy == null or enemy == primary or enemy.is_dead: continue
		if enemy.position.distance_squared_to(at) <= radius * radius:
			arena.deal_element_damage(enemy, amount, skill.element_id, FeedbackEvent.Source.BLAST)
			# Explosion scaling never changes the source arrow E used for burn.
			_try_burn(enemy, elemental, skill, rank, "blast")
	proc_counts.fire += 1
	arena.feedback.skill_event("fire")
	var flash := _flash(skill)
	if flash != null:
		flash.position = at
		flash.radius = radius
func _chain(primary: EnemyActor, at: Vector2, elemental: float, skill: ElementSkillDefinition, rank: int) -> void:
	var seen: Dictionary = {primary.get_instance_id(): true}
	var origin := at
	var points := PackedVector2Array([at])
	for hop in range(int(skill.parameter(skill.targets_by_rank, rank))):
		var nearest: EnemyActor
		var distance := skill.chain_range * skill.chain_range
		for node in arena.enemies.get_children():
			var enemy := node as EnemyActor
			if enemy == null or enemy.is_dead or seen.has(enemy.get_instance_id()): continue
			var candidate := enemy.position.distance_squared_to(origin)
			if candidate > distance: continue
			if nearest == null or candidate < distance or (is_equal_approx(candidate, distance) and enemy.get_instance_id() < nearest.get_instance_id()):
				nearest = enemy
				distance = candidate
		if nearest == null: break
		seen[nearest.get_instance_id()] = true
		origin = nearest.position
		points.append(origin)
		arena.deal_element_damage(nearest, elemental * skill.parameter(skill.damage_by_rank, rank), skill.element_id, FeedbackEvent.Source.CHAIN)
		_try_shock(nearest, skill, rank)
	proc_counts.lightning += 1
	if points.size() > 1: arena.feedback.skill_event("lightning")
	var flash := _flash(skill)
	if flash != null: flash.points = points
func _flash(skill: ElementSkillDefinition) -> ElementFlash:
	if get_child_count() >= arena.definition.effect_limit: return null
	var flash := ElementFlash.new()
	flash.color = skill.color
	flash.duration = skill.flash_duration
	flash.remaining = skill.flash_duration
	add_child(flash)
	return flash

func _try_burn(enemy: EnemyActor, source_elemental: float, skill: ElementSkillDefinition, rank: int, source_kind: String) -> void:
	# Only direct fire packets and their explicit blast packets can roll burn.
	# DOT calls the arena damage API, never this proc dispatch or on_hit.
	if source_kind not in ["direct", "blast"] or skill.element_id != "fire" or rank <= 0: return
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_queued_for_deletion(): return
	if source_elemental <= 0.0 or skill.burn_duration <= 0.0: return
	var chance := clampf(skill.parameter(skill.burn_chance_by_rank, rank), 0.0, 1.0)
	if chance <= 0.0 or arena.rng.randf() >= chance: return
	var id := enemy.get_instance_id()
	if burns.has(id) and (burns[id] as BurnEffect).remaining > 0.0:
		(burns[id] as BurnEffect).refresh(skill.burn_duration)
	else:
		burns[id] = BurnEffect.new(enemy, source_elemental, skill, rank)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if arena == null or arena.finished: return
	for id: int in burns.keys():
		var burn := burns.get(id) as BurnEffect
		if burn == null: continue
		var enemy := burn.target.get_ref() as EnemyActor
		if not _burn_target_alive(enemy):
			burns.erase(id)
			continue
		for amount: float in burn.tick(delta):
			if burns.get(id) != burn or not _burn_target_alive(enemy): break
			arena.deal_element_damage(enemy, amount, "fire", FeedbackEvent.Source.BURN)
		if burn.remaining <= 0.0 or not _burn_target_alive(enemy): burns.erase(id)
	queue_redraw()

func _burn_target_alive(enemy: EnemyActor) -> bool:
	return is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_queued_for_deletion() and enemy.get_parent() == arena.enemies

func _draw() -> void:
	for burn: BurnEffect in burns.values():
		var enemy := burn.target.get_ref() as EnemyActor
		if not _burn_target_alive(enemy) or burn.remaining <= 0.0: continue
		var glow := burn.color
		glow.a = 0.85
		var center := to_local(enemy.global_position)
		draw_arc(center, enemy.radius + 3.0, 0.0, TAU, 24, glow, 2.0, true)
		for i in range(3):
			var angle := float(i) * TAU / 3.0 + enemy.age * 0.6
			var base := center + Vector2.from_angle(angle) * (enemy.radius + 3.0)
			var height := 4.0 + 2.0 * sin(enemy.age * 7.0 + i)
			draw_polyline(PackedVector2Array([base + Vector2(-2,0), base + Vector2(0,-height), base + Vector2(2,0)]), glow, 1.4, true)

func _try_shock(enemy: EnemyActor, skill: ElementSkillDefinition, rank: int) -> void:
	# Roll after the triggering damage. Only later packets receive amplification.
	if not is_instance_valid(enemy) or enemy.is_dead or enemy.is_queued_for_deletion(): return
	if arena.rng.randf() < skill.parameter(skill.shock_chance_by_rank, rank):
		var fresh := enemy.status.shock_remaining <= 0.0
		enemy.status.apply_shock(skill, rank)
		if fresh: arena.feedback.status_event("shock", enemy.global_position, enemy.radius)
