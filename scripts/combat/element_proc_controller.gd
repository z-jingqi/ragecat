class_name ElementProcController
extends Node2D
## Player-owned shared cooldown; arrows own their first-impact eligibility.
var arena: RageArena
var proc_counts: Dictionary = {"fire": 0, "lightning": 0, "ice": 0, "dark": 0}
func clear(_preserve_cooldown: bool = false) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
func on_hit(arrow: CatArrow, target: EnemyActor, packet: Dictionary, hit_position: Vector2) -> void:
	if arrow.secondary: return
	var first := not arrow.element_proc_used
	arrow.element_proc_used = true # A denied first impact can never queue a later proc.
	var skill := arena.stats.element_skill
	var rank := arena.stats.element_skill_rank
	if skill == null or rank <= 0: return
	if skill.element_id == "ice":
		if not target.is_dead:
			target.status.apply_ice(skill, rank, target is BossActor)
			proc_counts.ice += 1
		return
	if not first: return
	var elemental: float = float(packet.elemental_precrit)
	match skill.element_id:
		"fire": _blast(target, hit_position, elemental, skill, rank)
		"lightning": _chain(target, target.position, elemental, skill, rank)
func _blast(primary: EnemyActor, at: Vector2, elemental: float, skill: ElementSkillDefinition, rank: int) -> void:
	var radius := skill.parameter(skill.radius_by_rank, rank)
	var amount := elemental * skill.parameter(skill.damage_by_rank, rank)
	for node in arena.enemies.get_children():
		var enemy := node as EnemyActor
		if enemy == null or enemy == primary or enemy.is_dead: continue
		if enemy.position.distance_squared_to(at) <= radius * radius: arena.deal_element_damage(enemy, amount, skill.element_id)
	proc_counts.fire += 1
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
		arena.deal_element_damage(nearest, elemental * skill.parameter(skill.damage_by_rank, rank), skill.element_id)
	proc_counts.lightning += 1
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
