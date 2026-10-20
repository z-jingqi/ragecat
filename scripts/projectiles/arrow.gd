class_name CatArrow
extends Node2D

signal enemy_hit(arrow: CatArrow, enemy: EnemyActor)
var direction := Vector2.RIGHT
var speed := 620.0
var max_range := 650.0
var traveled := 0.0
var width := 5.0
var max_hits := 1
var retention := 1.0
var damage_scale := 1.0
var decay := 0.8
var hit_ids: Dictionary = {}
var spread_used := false
var enemies: Node2D
var arena_bounds := Rect2()

func _physics_process(delta: float) -> void:
	var old := position
	position += direction * speed * delta
	traveled += speed * delta
	if enemies != null:
		var candidates: Array[EnemyActor] = []
		for node in enemies.get_children():
			var enemy := node as EnemyActor
			if enemy == null or enemy.health <= 0 or hit_ids.has(enemy.get_instance_id()): continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.position, old, position)
			if closest.distance_to(enemy.position) <= enemy.radius + width:
				candidates.append(enemy)
		candidates.sort_custom(func(a: EnemyActor,b: EnemyActor) -> bool: return old.distance_squared_to(a.position) < old.distance_squared_to(b.position))
		for enemy in candidates:
			if not can_hit(enemy.get_instance_id()): continue
			hit_ids[enemy.get_instance_id()] = true
			enemy_hit.emit(self,enemy)
			retention *= decay
			if hit_ids.size() >= max_hits:
				queue_free()
				return
	if traveled >= max_range or not arena_bounds.has_point(position): queue_free()
	rotation = direction.angle()

func can_hit(id: int) -> bool:
	return not hit_ids.has(id) and hit_ids.size() < max_hits

func _draw() -> void:
	draw_line(Vector2(-18,0),Vector2(9,0),Color("fff1bd"),width,true)
	draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(4,-5),Vector2(4,5)]),Color("90f1d2"))
	draw_line(Vector2(-15,0),Vector2(-21,-5),Color("e8b463"),2,true)
	draw_line(Vector2(-15,0),Vector2(-21,5),Color("e8b463"),2,true)
