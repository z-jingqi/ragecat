extends SceneTree
class LaunchStep extends Node:
	var task: SceneTree
	func _physics_process(_delta: float) -> void:
		set_physics_process(false)
		task.call("launch_before_occupancy")
var arena: RageArena
var source: Spitter
var shot: EnemyBullet
var raw_origin := Vector2.ZERO
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE LAUNCH FAIL: " + label)
func advance() -> void:
	await physics_frame
	await process_frame
func launch_before_occupancy() -> void:
	source.position += Vector2(12, 0)
	raw_origin = source.position + Vector2(2, 1)
	arena._spawn_enemy_bullet(raw_origin, Vector2.LEFT, source.definition, null, source)
	shot = arena.enemy_bullets.get_child(0)
func emit() -> EnemyBullet:
	arena._spawn_enemy_bullet(source.position, Vector2.RIGHT, source.definition, null, source)
	return arena.enemy_bullets.get_child(arena.enemy_bullets.get_child_count() - 1)
func run() -> void:
	arena = RageArena.new()
	arena.practice = true
	arena.lab_ai = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.bow.enabled = false
	source = arena.spawn_enemy("ranged", Vector2(500, 400)) as Spitter
	arena.spawn_enemy("mob", Vector2(530, 400))
	var cooldown := source.shot_cooldown
	var step := LaunchStep.new()
	step.task = self
	step.process_physics_priority = -9
	root.add_child(step)
	await advance()
	check(shot.position.is_equal_approx(source.position + Vector2(2, 1)) and shot.position != raw_origin, "real native blocking corrects new muzzle to final source in same frame")
	check(shot.direction == Vector2.LEFT and shot.traveled == 0.0 and shot.definition.bullet_range == source.definition.bullet_range and source.shot_cooldown == cooldown, "locked aim, complete range start and attack cooldown unchanged")
	var finalized := shot.position
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(shot.position == finalized, "consumed pending launch cannot apply correction twice")
	var flying := emit()
	flying.traveled = 1.0
	var original := flying.position
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(flying.position == original and flying.traveled == 1.0, "already flying bullet never moves")
	var stale := emit()
	original = stale.position
	arena._pending_enemy_launches[-1].frame = Engine.get_physics_frames() - 1
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(stale.position == original, "prior-frame zero-travel bullet never moves")
	var queued := emit()
	original = queued.position
	queued.queue_free()
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(queued.position == original, "queued projectile is ignored safely")
	var orphan := emit()
	original = orphan.position
	source.is_dead = true
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(orphan.position == original, "dead source leaves launch snapshot unchanged")
	source.is_dead = false
	var freed := emit()
	original = freed.position
	source.free()
	arena.finalize_enemy_launch_origins()
	check(freed.position == original, "freed source weak reference is safe")
	arena.clear_enemies()
	source = arena.spawn_enemy("ranged", Vector2(40, 400)) as Spitter
	arena._spawn_enemy_bullet(Vector2(7, 400), Vector2.RIGHT, source.definition, null, source)
	shot = arena.enemy_bullets.get_child(0)
	source.position -= Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(shot.position == Vector2(7, 400), "illegal shifted muzzle keeps original wall-legal origin")
	var queued_source_shot := emit()
	original = queued_source_shot.position
	source.queue_free()
	source.position += Vector2(10, 0)
	arena.finalize_enemy_launch_origins()
	check(queued_source_shot.position == original, "queued source cannot shift a new launch")
	arena.clear_enemies()
	source = arena.spawn_enemy("ranged", Vector2(700, 400)) as Spitter
	var newborn := emit()
	arena.finalize_enemy_launch_origins()
	check(newborn.position == source.position and newborn.traveled == 0.0, "new source retains valid unmoved launch origin")
	step.free()
	arena.free()
	print("NATIVE LAUNCH: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
