class_name BowArrow
extends Node2D

signal enemy_hit(arrow: BowArrow, enemy: EnemyActor)
signal removed(arrow: BowArrow)
## The renderer must receive handoff changes even in the arrow spawn frame.
signal presentation_changed
var gravity_field: GravityField
var lifetime_remaining: float = INF
var retired := false
## Appearance snapshot; never consulted by damage or element proc resolution.
var visual_element: String = ""
## Optional, bounded cosmetic handoff. Collision and traveled distance stay logical.
var presentation_origin_offset := Vector2.ZERO:
	set(value):
		presentation_origin_offset = value
		presentation_changed.emit()
var presentation_blend_distance := 0.0:
	set(value):
		presentation_blend_distance = value
		presentation_changed.emit()
var presentation_spawn_frame := -1

func _ready() -> void:
	presentation_spawn_frame = Engine.get_physics_frames()
	# New projectiles can render before their first physics tick.
	rotation = direction.angle()
	presentation_changed.emit()


func retire(reset_grace: bool = false) -> void:
	if retired: return
	retired = true
	if is_instance_valid(gravity_field): gravity_field.deactivate(reset_grace)
	removed.emit(self)
	queue_free()

func _exit_tree() -> void:
	retire()
var direction := Vector2.RIGHT
## Standalone projectile defaults are editable; equipped bows supply run stats.
@export var speed: float = 620.0
@export var max_range: float = 650.0
var traveled := 0.0
@export var width: float = 5.0
@export var max_hits: int = 1
## Explicit mode, independent of the ordinary finite penetration budget.
var unlimited_direct_hits := false
var retention := 1.0
@export var damage_scale: float = 1.0
@export var decay: float = 0.8
var hit_ids: Dictionary = {}
var ignored_ids: Dictionary = {}
var secondary: bool = false
## Resolved lazily at the first valid direct impact, once for this projectile.
## Kept separate from damage_scale so projectile scaling never compounds crit damage.
var critical_resolved: bool = false
var critical_result: bool = false

var impact_position := Vector2.ZERO
var impact_traveled := 0.0
var element_proc_used := false
var enemies: Node2D
var arena_bounds := Rect2()

func resolve_critical(chance: float, rng: RandomNumberGenerator) -> bool:
	if not critical_resolved:
		critical_result = rng.randf() < chance
		critical_resolved = true
	return critical_result

func _physics_process(delta: float) -> void:
	if retired or is_queued_for_deletion(): return
	delta = minf(maxf(0.0, delta), lifetime_remaining)
	lifetime_remaining = maxf(0.0, lifetime_remaining - delta)
	var remaining := maxf(0.0, max_range - traveled)
	if remaining <= 0.0:
		retire()
		return
	var old := position
	var old_tip := gravity_field.global_position if is_instance_valid(gravity_field) else global_position
	var axis := direction.normalized()
	var boundary_distance := INF
	if gravity_field != null:
		if not arena_bounds.has_point(position):
			retire()
			return
		if axis.x > 0.0: boundary_distance = minf(boundary_distance, (arena_bounds.end.x - position.x) / axis.x)
		elif axis.x < 0.0: boundary_distance = minf(boundary_distance, (arena_bounds.position.x - position.x) / axis.x)
		if axis.y > 0.0: boundary_distance = minf(boundary_distance, (arena_bounds.end.y - position.y) / axis.y)
		elif axis.y < 0.0: boundary_distance = minf(boundary_distance, (arena_bounds.position.y - position.y) / axis.y)
		remaining = minf(remaining, maxf(0.0, boundary_distance))
		delta = minf(delta, remaining / maxf(0.01, speed))
	var step := minf(maxf(0.0, speed * delta), remaining)
	position = old + axis * step
	traveled += step
	if enemies != null:
		var candidates: Array[Dictionary] = []
		for node in enemies.get_children():
			var enemy := node as EnemyActor
			if enemy == null or enemy.health <= 0 or hit_ids.has(enemy.get_instance_id()) or ignored_ids.has(enemy.get_instance_id()): continue
			var entry := _contact_distance(enemy, old, axis, step)
			if entry >= 0.0:
				candidates.append({"enemy": enemy, "distance": entry})
		candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a.distance == b.distance:
				return a.enemy.get_instance_id() < b.enemy.get_instance_id()
			return a.distance < b.distance
		)
		for candidate: Dictionary in candidates:
			var enemy: EnemyActor = candidate.enemy
			if not is_instance_valid(enemy) or enemy.is_dead or enemy.health <= 0.0: continue
			if not can_hit(enemy.get_instance_id()): continue
			impact_position = old + axis * float(candidate.distance)
			impact_traveled = traveled - step + float(candidate.distance)
			hit_ids[enemy.get_instance_id()] = true
			enemy_hit.emit(self,enemy)
			# Only the first penetration reduces damage. All later hits retain
			# the same percentage rather than multiplying it repeatedly.
			if retired or is_queued_for_deletion(): return
			if hit_ids.size() == 1 and not unlimited_direct_hits: retention = decay
			if not unlimited_direct_hits and hit_ids.size() >= max_hits and gravity_field == null:
				retire()
				return
	rotation = axis.angle()
	if not presentation_origin_offset.is_zero_approx():
		if traveled >= presentation_blend_distance: presentation_origin_offset = Vector2.ZERO
		queue_redraw()
	if is_instance_valid(gravity_field): gravity_field.tick(delta, old_tip)
	if traveled >= max_range or not arena_bounds.has_point(position) or lifetime_remaining <= 0.0 or (gravity_field != null and step >= boundary_distance): retire()

func _contact_distance(enemy: EnemyActor, origin: Vector2, axis: Vector2, step: float) -> float:
	# Sweep the arrow's circular hit radius against the enemy circle. Range
	# limits the arrow center path; touching hitbox surfaces at its endpoint hit.
	var offset := enemy.position - origin
	var combined_radius := enemy.radius + width
	if offset.length_squared() <= combined_radius * combined_radius: return 0.0
	var along := offset.dot(axis)
	var across_squared := maxf(0.0, offset.length_squared() - along * along)
	if across_squared > combined_radius * combined_radius: return -1.0
	var entry := along - sqrt(maxf(0.0, combined_radius * combined_radius - across_squared))
	return entry if entry >= 0.0 and entry <= step else -1.0

func can_hit(id: int) -> bool:
	return not retired and not ignored_ids.has(id) and not hit_ids.has(id) and (unlimited_direct_hits or hit_ids.size() < max_hits)


