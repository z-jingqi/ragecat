class_name HealthState
extends RefCounted
## Player health owns a shared stats resource. Immunity is set synchronously.
const HIT_IMMUNITY: float = 0.5
var stats: CombatStats
var invulnerability: float = 0.0

func _init(initial_stats: CombatStats = null) -> void:
	stats = initial_stats if initial_stats != null else CombatStats.new()

func receive_hit(amount: float) -> Dictionary:
	if amount <= 0.0 or stats.hp <= 0.0 or invulnerability > 0.0:
		return {"accepted": false, "shielded": false, "damage": 0.0, "dead": stats.hp <= 0.0}
	invulnerability = HIT_IMMUNITY
	if stats.shields > 0:
		stats.shields -= 1
		return {"accepted": true, "shielded": true, "damage": 0.0, "dead": false}
	var damage: float = minf(stats.hp, amount)
	stats.hp -= damage
	return {"accepted": true, "shielded": false, "damage": damage, "dead": stats.hp <= 0.0}

func heal(amount: float) -> float:
	if stats.hp <= 0.0:
		return 0.0
	var healed: float = minf(maxf(amount, 0.0), stats.max_hp - stats.hp)
	stats.hp += healed
	return healed

func tick(delta: float) -> void:
	var elapsed: float = maxf(delta, 0.0)
	invulnerability = maxf(0.0, invulnerability - elapsed)
	heal(stats.regen * elapsed)
