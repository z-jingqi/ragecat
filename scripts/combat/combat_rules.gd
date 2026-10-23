class_name CombatRules
extends RefCounted
## One projectile, one crit result; each hit is one atomic health event. Derived effects consume
## elemental_precrit, never health removed (which may be capped by lethal hits).
## Stateless packet entry point for simulations. Secondary means another direct
## projectile, not a derived effect, and therefore has the same crit eligibility.
static func resolve_direct(stats: CombatStats, target_status: StatusEffects, base_damage: float, rng_roll: float, retention: float = 1.0, _secondary: bool = false) -> Dictionary:
	return _resolve_damage(stats, target_status, base_damage, rng_roll < stats.effective_crit_chance(), retention)

## The projectile caches its own first-impact decision. Piercing cannot reroll;
## fragments are fresh projectiles and never inherit their parent's decision.
static func resolve_projectile(stats: CombatStats, target_status: StatusEffects, arrow: BowArrow, rng: RandomNumberGenerator) -> Dictionary:
	return _resolve_damage(stats, target_status, stats.arrow_damage, arrow.resolve_critical(stats.effective_crit_chance(), rng), arrow.retention * arrow.damage_scale)

static func _resolve_damage(stats: CombatStats, target_status: StatusEffects, base_damage: float, crit: bool, retention: float) -> Dictionary:
	var coefficient := stats.burst_damage_multiplier * maxf(retention, 0.0)
	var base := maxf(0, base_damage + stats.damage_flat) * (1 + stats.damage_percent / 100.0) * coefficient
	var elemental := stats.element_damage * coefficient
	var ice_consumed := false
	if stats.active_element == "ice" and stats.element_skill_rank > 0 and stats.element_skill != null and target_status != null:
		ice_consumed = target_status.consume_ice()
	var shatter: float = stats.element_skill.shatter_multiplier if ice_consumed else 1.0
	var critical_multiplier := (stats.crit_multiplier if crit else 1.0) * shatter
	return {"damage": (base + elemental) * critical_multiplier,
		"base_damage": base * critical_multiplier, "elemental_damage": elemental * critical_multiplier,
		"base_precrit": base, "elemental_precrit": elemental,
		"element": stats.active_element, "crit": crit, "ice_consumed": ice_consumed}
