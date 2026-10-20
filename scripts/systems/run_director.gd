class_name RunDirector
extends RefCounted

var elapsed := 0.0
var next_boss_at := 120.0
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
		spawn_clock = maxf(0.28,1.35-elapsed/330.0) * (3.0 if boss_alive else 1.0)
		result.spawn_mob = true
	return result

func boss_killed() -> void:
	boss_alive = false
	boss_count += 1
	next_boss_at = elapsed + 120.0
