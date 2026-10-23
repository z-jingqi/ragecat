class_name RunDirector
extends RefCounted
## One simulation-time clock. Missed spawn opportunities are discarded, not queued.
var definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
var elapsed := 0.0
var next_boss_at: float = definition.boss_interval
var boss_alive := false
var boss_count := 0
var spawn_clock := 0.0
var relief_remaining := 0.0
var pulse_clock := 0.0
var endless := false

func configure(settings: ArenaDefinition) -> void:
	definition = (settings if settings != null else ArenaDefinition.new()).validated_copy()
	elapsed = 0.0
	next_boss_at = definition.boss_interval
	boss_alive = false
	boss_count = 0
	spawn_clock = 0.0
	relief_remaining = 0.0
	pulse_clock = 0.0
	endless = false

func tick(delta: float) -> Dictionary:
	var result := {"spawn_mob": false, "spawn_boss": false}
	if not is_finite(delta) or delta <= 0.0: return result
	elapsed += delta
	if relief_remaining > 0.0:
		relief_remaining = maxf(0.0, relief_remaining - delta)
		if relief_remaining == 0.0: pulse_clock = 0.0
	elif not boss_alive: pulse_clock += delta
	if not boss_alive and elapsed >= next_boss_at:
		boss_alive = true
		result.spawn_boss = true
	spawn_clock -= delta
	if spawn_clock <= 0.0:
		spawn_clock = spawn_interval_now()
		result.spawn_mob = true
	return result

func base_spawn_interval() -> float:
	return definition.minimum_spawn_interval + (definition.spawn_interval - definition.minimum_spawn_interval) * exp(-elapsed / definition.spawn_ramp_time)

func spawn_interval_now() -> float:
	var interval := base_spawn_interval()
	if boss_alive: return interval * definition.boss_spawn_multiplier
	var rate := 1.0
	if relief_remaining > 0.0 and definition.relief_duration > 0.0:
		var progress := 1.0 - relief_remaining / definition.relief_duration
		rate = lerpf(definition.relief_initial_rate, 1.0, smoothstep(0.0, 1.0, progress))
	else:
		var fade := clampf((elapsed - definition.pressure_intro) / definition.pressure_fade_time, 0.0, 1.0)
		rate = 1.0 - definition.pressure_amplitude * fade * cos(TAU * pulse_clock / definition.pressure_period)
	return maxf(definition.minimum_spawn_interval, interval / rate)

func ranged_admission_limit() -> int:
	if elapsed < definition.ranged_intro_time: return 0
	var limit := mini(definition.ranged_limit, 1 + int((elapsed - definition.ranged_intro_time) / definition.ranged_cap_period))
	if boss_alive or relief_remaining > 0.0: limit = mini(limit, definition.boss_ranged_limit)
	return limit

func health_pressure() -> float:
	if not endless: return 1.0
	var progress := maxf(0.0, elapsed - definition.endless_pressure_start) / definition.endless_pressure_period
	# Clamp before pow to keep arbitrarily long simulations finite.
	progress = minf(progress, definition.endless_health_multiplier_cap)
	return minf(definition.endless_health_multiplier_cap, 1.0 + pow(progress, definition.endless_pressure_exponent))

func mob_health_multiplier() -> float:
	return (1.0 + minf(elapsed / definition.difficulty_period, definition.difficulty_bonus_cap)) * health_pressure()

func boss_health_multiplier() -> float:
	return minf(definition.boss_health_multiplier_cap, 1.0 + boss_count * definition.boss_health_increment) * health_pressure()

func boss_spawn_failed() -> void:
	# Leave the due timestamp intact: one safe spawn is retried, never a backlog.
	boss_alive = false

func boss_killed() -> void:
	if not boss_alive: return
	boss_alive = false
	boss_count += 1
	next_boss_at = elapsed + definition.boss_interval
	relief_remaining = definition.relief_duration
	pulse_clock = 0.0
	spawn_clock = spawn_interval_now()
