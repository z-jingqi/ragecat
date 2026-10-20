class_name CombatRules
extends RefCounted
## Pure calculation: caller damages target, applies arrow statuses, then spread/heal.
static func resolve_direct(stats: CombatStats, target_status: StatusEffects, base_damage: float, rng_roll: float, retention: float = 1.0, secondary: bool = false) -> Dictionary:
	var pre_poison: bool = target_status.has_poison()
	var pre_bleed: bool = target_status.has_bleed()
	var chance: float = stats.crit_chance
	if pre_poison and stats.poison_crit > 0.0:
		chance += stats.poison_crit
	if stats.shields > 0:
		chance += stats.shield_crit_per_charge * stats.shields
	var crit: bool = not secondary and rng_roll < clampf(chance, 0.0, 1.0)
	var damage: float = maxf(0.0, base_damage + stats.damage_flat) * (1.0 + stats.damage_percent / 100.0) * stats.burst_damage_multiplier * maxf(retention, 0.0)
	if crit:
		damage *= stats.crit_multiplier
	return {"damage": damage, "crit": crit, "pre_poison": pre_poison, "pre_bleed": pre_bleed,
		"spread": not secondary and pre_poison and stats.spread_radius > 0.0,
		"sustain": stats.bleed_regen if pre_bleed and not secondary else 0.0}
