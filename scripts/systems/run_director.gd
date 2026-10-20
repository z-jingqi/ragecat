class_name RunDirector
extends RefCounted

var definition: ArenaDefinition = preload("res://resources/settings/arena.tres")
var elapsed := 0.0
var next_boss_at: float = definition.boss_interval

func configure(settings: ArenaDefinition) -> void:
	definition = settings.validated_copy()
	next_boss_at = definition.boss_interval
var boss_alive := false
var boss_count := 0
var spawn_clock := 0.0

func tick(delta: float) -> Dictionary:
	elapsed += delta
	spawn_clock -= delta
	var result := {"spawn_mob": false, "spawn_boss": false}
	if not boss_alive and elapsed >= next_boss_at:
		boss_alive = true
		result.spawn_boss = true
	if spawn_clock <= 0:
		spawn_clock = maxf(definition.minimum_spawn_interval, definition.spawn_interval-elapsed/definition.spawn_acceleration_period) * (definition.boss_spawn_multiplier if boss_alive else 1.0)
		result.spawn_mob = true
	return result

func boss_killed() -> void:
	boss_alive = false
	boss_count += 1
	next_boss_at = elapsed + definition.boss_interval
