extends SceneTree
class FailingArena extends RageArena:
	var attempts := 0
	var injection_frame := -1
	var discarded: EnemyActor
	var discarded_proxy: StaticBody2D
	var killed_signals := 0
	var damaged_signals := 0
	func spawn_enemy(kind: String, at: Vector2 = Vector2(-1, -1), occupancy_slot: StaticBody2D = null) -> EnemyActor:
		if kind == "elite_hornling":
			attempts += 1
			if attempts == 2:
				injection_frame = Engine.get_physics_frames()
				return null
		var actor := super.spawn_enemy(kind, at, occupancy_slot)
		if kind == "elite_hornling" and actor != null:
			discarded = actor
			discarded_proxy = occupancy._entries[actor.get_instance_id()].proxy
			actor.killed.connect(func(_enemy: EnemyActor) -> void: killed_signals += 1)
			actor.damaged.connect(func(_amount: float, _crit: bool, _at: Vector2) -> void: damaged_signals += 1)
		return actor
class Audit extends Node:
	var task: SceneTree
	func _physics_process(_delta: float) -> void: task.call("audit_same_frame")
var arena: FailingArena
var audit: Audit
var hp := 0.0
var shields := 0
var checks := 0
var failures := 0
var completed := false
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("NATIVE PARTIAL SPAWN FAIL: " + label)
func run() -> void:
	arena = FailingArena.new()
	arena.practice = true
	arena.lab_ai = false
	arena.sound_enabled = false
	root.add_child(arena)
	arena.set_process(false)
	# Keep the real priority0 arena contact loop active for this transaction.
	arena.player.set_physics_process(false)
	arena.player.invulnerable = false
	arena.bow.enabled = false
	var boss := arena.spawn_enemy("beastcaller", Vector2(200, 200)) as Beastcaller
	boss.ai_enabled = false
	check(boss._start_summon(), "real three-slot warning reserves before injected failure")
	arena.player.position = boss.summon_positions[0]
	hp = arena.stats.hp
	shields = arena.stats.shields
	boss.ai_enabled = true
	audit = Audit.new()
	audit.task = self
	audit.process_physics_priority = 10
	root.add_child(audit)
func audit_same_frame() -> void:
	if completed or arena.injection_frame < 0: return
	completed = true
	check(Engine.get_physics_frames() == arena.injection_frame, "audit runs in failure frame before deferred destruction")
	check(arena.attempts == 2, "failure injected after exactly one successful creation")
	check(arena.enemies.get_child_count() == 1 and arena.occupancy._entries.size() == 1, "partial batch immediately leaves combat and native registries")
	check(arena._summon_reservations.is_empty() and arena.occupancy._reservations.is_empty(), "failed batch releases all capacity and reservations")
	check(is_instance_valid(arena.discarded) and arena.discarded.is_queued_for_deletion() and arena.discarded.get_parent() == null, "aborted actor is detached now and destroyed later")
	check(arena.discarded.is_dead and arena.discarded.health == 0.0 and not arena.discarded.ai_enabled, "stale actor references are inert without invoking death callbacks")
	check(arena.discarded_proxy.collision_layer == 0 and arena.discarded_proxy.collision_mask == 0, "aborted proxy cannot block later same-frame sweeps")
	check(arena.stats.hp == hp and arena.stats.shields == shields, "real contact loop caused no aborted-spawn damage")
	var arrow := BowArrow.new()
	arrow.enemies = arena.enemies
	arrow.position = arena.player.position - Vector2(50, 0)
	arrow.direction = Vector2.RIGHT
	arrow.speed = 1000.0
	arrow.max_range = 150.0
	arrow.arena_bounds = arena.bounds
	arena.arrows.add_child(arrow)
	arrow._physics_process(0.1) # Same-frame hurtbox query, not a fake physics clock.
	check(arrow.hit_ids.is_empty(), "same-frame projectile cannot target the aborted actor")
	arena.deal_damage_packet(arena.discarded, {"damage": 999999.0, "physical_damage": 999999.0, "elemental_damage": 0.0})
	check(arena.killed_signals == 0 and arena.damaged_signals == 0, "stale direct damage reference emits no damage or death signals")
	check(arena.kills == 0 and arena.xp == 0 and arena.pickups.is_empty(), "aborted batch grants no kill, XP or pickup rewards")
	check(int(arena.feedback.event_counts.get("kill", 0)) == 0, "aborted batch produces no death feedback")
	audit.set_physics_process(false)
	call_deferred("finish")
func finish() -> void:
	audit.free()
	arena.free()
	print("NATIVE PARTIAL SPAWN: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
