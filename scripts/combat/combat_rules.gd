class_name CombatRules
extends RefCounted
## One packet, one crit roll, one atomic health event. Derived effects consume
## elemental_precrit, never health removed (which may be capped by lethal hits).
static func resolve_direct(stats: CombatStats, _target_status: StatusEffects, base_damage: float, rng_roll: float, retention: float = 1.0, secondary: bool = false) -> Dictionary:
	var chance := stats.crit_chance + stats.shield_crit_per_charge * stats.shields
	var crit := not secondary and rng_roll < clampf(chance, 0.0, 1.0)
	var coefficient := stats.burst_damage_multiplier * maxf(retention, 0.0)
	var base := maxf(0, base_damage + stats.damage_flat) * (1 + stats.damage_percent / 100.0) * coefficient
	var elemental := stats.element_damage * coefficient
	var critical_multiplier := stats.crit_multiplier if crit else 1.0
	return {"damage": (base + elemental) * critical_multiplier,
		"base_damage": base * critical_multiplier, "elemental_damage": elemental * critical_multiplier,
		"base_precrit": base, "elemental_precrit": elemental,
		"element": stats.active_element, "crit": crit}
