class_name CatArrow
extends Node2D

signal enemy_hit(arrow: CatArrow, enemy: EnemyActor)
var direction := Vector2.RIGHT
## Standalone projectile defaults are editable; equipped bows supply run stats.
@export var speed: float = 620.0
@export var max_range: float = 650.0
var traveled := 0.0
@export var width: float = 5.0
@export var max_hits: int = 1
var retention := 1.0
@export var damage_scale: float = 1.0
@export var decay: float = 0.8
var hit_ids: Dictionary = {}
var ignored_ids: Dictionary = {}
var secondary: bool = false
var split_used: bool = false
var impact_position := Vector2.ZERO
var impact_traveled := 0.0
var element_proc_used := false
var enemies: Node2D
var arena_bounds := Rect2()

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	var remaining := maxf(0.0, max_range - traveled)
	if remaining <= 0.0:
		queue_free()
		return
	var old := position
	var axis := direction.normalized()
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
			if hit_ids.size() == 1: retention = decay
			if hit_ids.size() >= max_hits:
				queue_free()
				return
	if traveled >= max_range or not arena_bounds.has_point(position): queue_free()
	rotation = axis.angle()

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
	return not ignored_ids.has(id) and not hit_ids.has(id) and hit_ids.size() < max_hits

func _draw() -> void:
	draw_line(Vector2(-18,0),Vector2(9,0),Color("fff1bd"),width,true)
	draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(4,-5),Vector2(4,5)]),Color("90f1d2"))
	draw_line(Vector2(-15,0),Vector2(-21,-5),Color("e8b463"),2,true)
	draw_line(Vector2(-15,0),Vector2(-21,5),Color("e8b463"),2,true)
