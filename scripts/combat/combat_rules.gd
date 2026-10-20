class_name CombatRules
extends RefCounted
## Pure calculation: caller damages target, applies arrow statuses, then spread/heal.
static func resolve_direct(stats: CombatStats, target_status: StatusEffects, base_damage: float, rng_roll: float, retention: float = 1.0) -> Dictionary:
	var pre_poison: bool = target_status.has_poison()
	var pre_bleed: bool = target_status.has_bleed()
	var chance: float = stats.crit_chance
	if pre_poison and stats.poison_crit > 0.0:
		chance = 1.0
	if stats.shields > 0:
		chance += 0.10 * stats.shields
	var crit: bool = rng_roll < clampf(chance, 0.0, 1.0)
	var damage: float = maxf(0.0, base_damage) * (1.0 + stats.damage_percent / 100.0) * maxf(retention, 0.0)
	if crit:
		damage *= stats.crit_multiplier
	return {"damage": damage, "crit": crit, "pre_poison": pre_poison, "pre_bleed": pre_bleed,
		"spread": pre_poison and stats.spread_radius > 0.0,
		"sustain": stats.bleed_regen if pre_bleed else 0.0}
