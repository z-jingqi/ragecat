extends SceneTree
var checks: int = 0
var failures: int = 0
var shots: int = 0
var skill := ElementSkillDefinition.new()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)
func close(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001
func freeze(status: StatusEffects, rank: int = 1) -> void:
	for i in range(skill.frost_threshold): status.apply_ice(skill, rank)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var status := StatusEffects.new()
	var freeze_one: float = skill.parameter(skill.freeze_by_rank, 1)
	check(status.movement_multiplier() == 1.0, "clean status has normal speed")
	status.apply_ice(skill, 0)
	check(status.chill_remaining == 0 and status.frost_stacks == 0, "no skill gives no control")
	for rank: int in range(1, 4):
		status.clear()
		status.apply_ice(skill, rank)
		check(status.frost_stacks == 1 and close(status.chill_remaining, 2), "first legal hit chills and stacks")
		check(close(status.movement_multiplier(), 0.8), "small enemies slow 20 percent")
		status.tick(1.0)
		status.apply_ice(skill, rank)
		status.tick(1.9)
		check(status.frost_stacks == 2, "latest stack refreshes complete stack window")
		status.tick(0.1)
		check(status.frost_stacks == 0 and close(status.chill_remaining, 0), "whole frost stack expires at 2 seconds")
		freeze(status, rank)
		var duration: float = skill.freeze_by_rank[rank]
		check(status.is_frozen() and close(status.frozen_remaining, duration) and status.frost_stacks == 0, "three hits freeze for selected rank and consume stacks")
		check(status.movement_multiplier() == 0, "frozen motion stops")
		status.tick(duration * 0.5)
		var left: float = status.frozen_remaining
		status.apply_ice(skill, rank)
		check(close(status.frozen_remaining, left) and status.frost_stacks == 0, "hit during freeze does not extend it or stack")
		status.tick(duration * 0.5)
		check(not status.is_frozen() and close(status.immunity_remaining, 2.0), "full thaw begins 2 second immunity")
		status.apply_ice(skill, rank)
		check(status.frost_stacks == 0 and close(status.chill_remaining, 2), "immunity blocks stack but refreshes chill")
		status.tick(1.99)
		status.apply_ice(skill, rank)
		check(status.frost_stacks == 0, "immunity prevents premature new stack")
		status.tick(0.01)
		status.apply_ice(skill, rank)
		check(status.frost_stacks == 1, "stacking resumes at immunity expiry")
	status.clear()
	freeze(status)
	check(close(status.movement_time(5), 5.0 - freeze_one - (2.0 - freeze_one) * 0.2), "motion integrates freeze and chill expiry inside a long frame")
	status.tick(0.9)
	check(close(status.immunity_remaining, 2.0 - (0.9 - freeze_one)), "large delta consumes only time after thaw from immunity")
	status.tick(2.0 - (0.9 - freeze_one))
	check(status.immunity_remaining == 0, "large delta immunity expires exactly")
	status.clear()
	for i in range(100): status.apply_ice(skill, 3, true)
	check(close(status.movement_multiplier(), 0.9) and status.frost_stacks == 0 and status.has_ice_mark() and not status.is_frozen(), "boss receives 10 percent chill and mark, never freezes")
	status.tick(-1)
	status.tick(NAN)
	check(close(status.chill_remaining, 2), "invalid delta leaves status unchanged")
	status.clear()
	check(status.chill_remaining == 0 and status.immunity_remaining == 0 and status.frost_stacks == 0 and not status.is_frozen(), "clear removes all status state")
	var target := Node2D.new()
	root.add_child(target)
	target.position = Vector2(900, 300)
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	enemy.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.target = target
	enemy.position = Vector2(200, 300)
	enemy.speed = 100
	check(enemy.health_bar_visible(), "Ordinary health bar is shown by default at full HP")
	enemy.show_health_bar = false
	check(not enemy.health_bar_visible(), "Ordinary health bar honors the toggle")
	freeze(enemy.status)
	enemy._physics_process(0.2)
	check(enemy.position == Vector2(200, 300) and enemy.health == enemy.max_health, "freeze stops chase and adds no damage over time")
	enemy._physics_process(freeze_one - 0.2)
	check(enemy.position == Vector2(200, 300) and not enemy.status.is_frozen(), "exact thaw frame does not move early")
	enemy._physics_process(0.1)
	check(close(enemy.position.x, 208), "chilled movement resumes after thaw")
	enemy.status.clear()
	enemy.position.x = 200
	freeze(enemy.status)
	enemy._physics_process(freeze_one + 0.1)
	check(close(enemy.position.x, 208) and close(enemy.status.immunity_remaining, 1.9), "long frame moves only thawed fraction")
	enemy.status.clear()
	enemy.position.x = 200
	enemy.status.apply_ice(skill, 1)
	enemy._physics_process(3)
	check(close(enemy.position.x, 460), "long frame integrates 2 seconds slow and 1 normal")
	enemy.ai_enabled = false
	freeze(enemy.status)
	var position_before := enemy.position
	enemy._physics_process(3)
	check(enemy.position == position_before and not enemy.status.is_frozen() and enemy.status.immunity_remaining == 0, "disabled practice AI still advances ice clocks")
	enemy.ai_enabled = true
	enemy.status.clear()
	freeze(enemy.status)
	enemy.stun_remaining = 0.4
	enemy._physics_process(0.2)
	check(close(enemy.stun_remaining, 0.2) and close(enemy.status.frozen_remaining, freeze_one - 0.2), "stun and freeze clocks continue together")
	enemy.knockback(Vector2.RIGHT, 10000)
	check(close(enemy.position.x, enemy.arena_bounds.end.x - enemy.radius), "frozen knockback remains available and bounded")
	enemy.free()
	var ranged := RangedEnemy.new()
	root.add_child(ranged)
	ranged.process_mode = Node.PROCESS_MODE_DISABLED
	ranged.target = target
	ranged.show_health_bar = false
	check(not ranged.health_bar_visible(), "Ranged health bar honors the toggle")
	target.position = Vector2(500, 300)
	ranged.position = Vector2(900, 300)
	ranged._physics_process(0.1)
	check(ranged.position == Vector2(900, 300) and close(ranged.shot_cooldown, 1.9), "ranged idles at range while cooldown advances")
	ranged.position = Vector2(600, 300)
	ranged.shot_cooldown = 1.0
	freeze(ranged.status)
	ranged._physics_process(0.2)
	check(ranged.position == Vector2(600, 300) and close(ranged.shot_cooldown, 0.8), "frozen ranged preserves position and cooldown")
	ranged.shot_pending = true
	ranged.warning_remaining = 0.1
	ranged.locked_direction = Vector2.LEFT
	ranged.shot_requested.connect(func(_origin: Vector2, _direction: Vector2, _definition: RangedDefinition) -> void: shots += 1)
	ranged._physics_process(0.1)
	check(ranged.position == Vector2(600, 300) and shots == 1 and not ranged.shot_pending, "frozen warning expires and fires without moving")
	ranged._physics_process(freeze_one - 0.3)
	check(ranged.position == Vector2(600, 300), "ranged does not retreat before exact thaw")
	ranged._physics_process(0.1)
	check(close(ranged.position.x, 608.4), "ranged resumes slowed retreat instead of chasing")
	ranged.status.clear()
	ranged.position.x = ranged.arena_bounds.end.x - ranged.radius
	target.position = ranged.position - Vector2(40, 0)
	position_before = ranged.position
	ranged._physics_process(1.0)
	check(ranged.position == position_before, "ranged retreat stays bounded at wall")
	ranged.ai_enabled = false
	ranged.shot_pending = true
	ranged.warning_remaining = 0.4
	ranged.status.apply_ice(skill, 1)
	ranged._physics_process(2.0)
	check(close(ranged.warning_remaining, 0.4) and ranged.status.frost_stacks == 0, "practice AI-off pauses attacks but not ice expiration")
	ranged.free()
	var boss := BossActor.new()
	root.add_child(boss)
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	boss.target = target
	boss.show_health_bar = false
	check(boss.health_bar_visible(), "Boss health bar remains visible when ordinary bars are hidden")
	boss.position = Vector2(200, 300)
	target.position = Vector2(850, 300)
	boss.status.apply_ice(skill, 3, true)
	boss._start_charge_warning()
	var locked_end := boss.charge_end
	boss._physics_process(boss.warning_duration)
	check(boss.state == "charge" and boss.charge_end == locked_end, "boss ice preserves warning time and locked endpoint")
	boss._physics_process(0.1)
	check(close(boss.position.x, 268), "boss charge remains full 680 pixels per second under chill")
	check(close(boss.phase_time, boss.charge_timeout - 0.1), "boss charge timer unaffected")
	boss._physics_process(1.0)
	check(boss.position == locked_end and boss.state == "recovery", "boss charge distance unchanged")
	boss._start_rocks()
	check(boss.rocks.size() == boss.rock_count, "boss rock count unchanged under chill")
	for rock: RockWarning in boss.rocks:
		check(close(rock.warning_duration, maxf(boss.rock_min_warning_duration, boss.warning_duration + boss.rock_warning_offset)), "boss rock timing unaffected")
	boss.ai_enabled = false
	boss._physics_process(3)
	check(boss.status.chill_remaining == 0, "boss status expires with practice AI disabled")
	boss.free()
	target.free()
	await process_frame
	await run_timing_edges()
	print("ICE STATUS AND ENEMY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func run_timing_edges() -> void:
	var rng := RandomNumberGenerator.new()
	var seed_value: int = int(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else 7319
	rng.seed = seed_value
	for rank: int in range(1, 4):
		for frame_delta: float in [1.0 / 240.0, 1.0 / 60.0, 1.0 / 30.0, 0.1, 0.35, 0.9, 4.0]:
			var status := StatusEffects.new()
			freeze(status, rank)
			var elapsed: float = 0.0
			var movement: float = 0.0
			while elapsed < 3.0:
				var step: float = minf(frame_delta, 3.0 - elapsed)
				movement += status.movement_time(step)
				status.tick(step)
				elapsed += step
			var freeze_seconds: float = skill.freeze_by_rank[rank]
			var expected: float = 3.0 - freeze_seconds - (2.0 - freeze_seconds) * 0.2
			check(close(movement, expected), "frame partition keeps integrated movement invariant")
			check(not status.is_frozen() and status.immunity_remaining == 0 and status.chill_remaining == 0, "timers fully expire after 3 seconds at every frame rate")
	for trial in range(200):
		var status := StatusEffects.new()
		var rank: int = rng.randi_range(1, 3)
		freeze(status, rank)
		var elapsed: float = 0.0
		var movement: float = 0.0
		while elapsed < 3.0:
			var step: float = minf(rng.randf_range(0.0005, 0.75), 3.0 - elapsed)
			movement += status.movement_time(step)
			status.tick(step)
			elapsed += step
		var duration: float = skill.freeze_by_rank[rank]
		check(close(movement, 3.0 - duration - (2.0 - duration) * 0.2), "random timestep motion integration")
		check(status.immunity_remaining == 0 and status.frost_stacks == 0, "random timestep complete status lifecycle")
	var status := StatusEffects.new()
	for i in range(1000): status.apply_ice(skill, 1)
	check(close(status.frozen_remaining, skill.parameter(skill.freeze_by_rank, 1)) and status.frost_stacks == 0, "same-frame multihit never stacks during or extends freeze")
	status.tick(1000000)
	check(status.chill_remaining == 0 and status.immunity_remaining == 0 and not status.is_frozen(), "huge delta ends all existing timers")
	freeze(status, 99)
	check(close(status.frozen_remaining, skill.parameter(skill.freeze_by_rank, 3)), "out-of-range rank clamps safely")
	status.tick(INF)
	status.tick(NAN)
	check(close(status.frozen_remaining, skill.parameter(skill.freeze_by_rank, 3)), "nonfinite time ignored")
	status.clear()
	check(status.movement_time(0.5) == 0.5 and status.immunity_remaining == 0, "clearing frozen state leaves no stale immunity or slowdown")
	skill.chill_fraction = 0.35
	skill.chill_duration = 3.0
	skill.frost_threshold = 2
	skill.frost_window = 0.7
	skill.freeze_by_rank = PackedFloat32Array([0, 1.25])
	skill.thaw_immunity = 0.75
	status.apply_ice(skill, 3)
	check(status.frost_stacks == 1 and close(status.movement_multiplier(), 0.65), "custom resource values apply without hardcoded small-enemy slow")
	status.tick(0.7)
	check(status.frost_stacks == 0, "custom stack window expires")
	freeze(status, 3)
	check(close(status.frozen_remaining, 1.25), "custom threshold and short rank array are honored")
	status.tick(1.5)
	check(close(status.immunity_remaining, 0.5), "custom immunity starts at actual thaw within frame")
	status.clear()
	skill.chill_fraction = NAN
	skill.chill_duration = INF
	skill.frost_window = -1
	status.apply_ice(skill, 1)
	check(status.movement_multiplier() == 1 and status.chill_remaining == 0, "invalid authored chill values do not poison runtime state")
	status.tick(0.1)
	check(status.frost_stacks == 0, "invalid frost window cannot leave permanent stacks")
	var draw_target := EnemyActor.new()
	draw_target.position = Vector2(200, 200)
	draw_target.ai_enabled = false
	skill = ElementSkillDefinition.new()
	freeze(draw_target.status, 3)
	root.add_child(draw_target)
	for i in range(3): await process_frame
	check(draw_target.status.is_frozen(), "frozen crystal rendering survives live draw frames")
	draw_target.free()
	await process_frame
