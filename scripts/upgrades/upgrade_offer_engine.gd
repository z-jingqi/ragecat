class_name UpgradeOfferEngine
extends RefCounted
## Read-only scoring and transactional generation are deliberately separate.
const EXCLUSIVE_FAMILY := "element_exclusive"

static func _finite(value: Variant, fallback: float = 0.0) -> float:
	if not (value is float or value is int): return fallback
	var number := float(value)
	return clampf(number, -1000000.0, 1000000.0) if is_finite(number) else fallback

static func _unit(value: float) -> float:
	return clampf(value, 0.0, 1.0) if is_finite(value) else 0.0

static func _growth(catalog, stats: CombatStats, key: String) -> float:
	var maximum: float = catalog.value(key, catalog.max_rank(key))
	return _unit(catalog.value(key, catalog.rank_for(stats.ranks, key)) / maximum) if maximum > 0 else 0.0

static func _family(catalog, key: String) -> String:
	var item: UpgradeDefinition = catalog.definition(key)
	return EXCLUSIVE_FAMILY if item != null and not item.element_id.is_empty() and not item.is_enchantment else key

## Normalize live attributes against all authored positive modifier capacity,
## independent of upgrade IDs. Costs never inflate the reference capacity.
static func _modifier_scales(catalog) -> Dictionary:
	var scales := {}
	for key: String in catalog.resources:
		var item: UpgradeDefinition = catalog.definition(key)
		for modifier: UpgradeStatModifier in item.stat_modifiers:
			if modifier == null: continue
			var amount := maxf(0.0, modifier.value_at(item.rank_limit(), item.values))
			scales[modifier.channel] = float(scales.get(modifier.channel, 0.0)) + amount
	return scales

static func _next_crit_delta(catalog, stats: CombatStats) -> float:
	var largest := 0.0
	for key: String in catalog.resources:
		var item: UpgradeDefinition = catalog.definition(key)
		var rank: int = catalog.rank_for(stats.ranks, key)
		if rank >= item.rank_limit(): continue
		var delta := 0.0
		for modifier: UpgradeStatModifier in item.stat_modifiers:
			if modifier != null and modifier.channel == "crit_chance":
				delta += modifier.value_at(rank + 1, item.values) - modifier.value_at(rank, item.values)
		largest = maxf(largest, delta)
	return largest

static func signals(catalog, stats: CombatStats) -> Dictionary:
	var gravity := stats.gravity_mode()
	var character := stats.character if stats.character != null else CharacterDefinition.new()
	var crit_cap := maxf(0.0, stats.combat_definition.total_crit_chance_cap)
	var effective := stats.effective_crit_chance()
	var scales := _modifier_scales(catalog)
	var next_delta := _next_crit_delta(catalog, stats)
	var saturation := 1.0 - _unit((crit_cap - effective) / next_delta) if next_delta > 0.0 else 1.0
	var f := {"flat":0.0, "percent":0.0, "rate":0.0, "crit_damage":0.0, "regen":0.0, "health_growth":0.0, "split":_growth(catalog,stats,"split"), "effective_crit":_unit(effective / crit_cap) if crit_cap > 0 else 0.0, "crit_saturation":saturation, "gravity":1.0 if gravity else 0.0, "inactive_pierce":1.0 if gravity or stats.fire_mode() else 0.0, "health_deficit":_unit(1.0 - stats.hp / stats.max_hp) if stats.max_hp > 0 else 0.0}
	# Use authoritative live additive stats, normalized by the authored upgrade scale.
	var stat_sources := {"flat":[stats.damage_flat,0.0,"damage_flat"], "percent":[stats.damage_percent,stats.combat_definition.base_damage_percent,"damage_percent"], "rate":[stats.attack_speed,stats.combat_definition.base_attack_speed,"attack_speed"], "crit_damage":[stats.crit_multiplier,stats.combat_definition.base_crit_multiplier,"crit_multiplier"], "regen":[stats.regen,stats.combat_definition.base_regen,"regen"], "health_growth":[stats.max_hp,character.base_health,"health"]}
	for feature: String in stat_sources:
		var source: Array = stat_sources[feature]
		var scale := float(scales.get(source[2], 0.0))
		f[feature] = _unit((float(source[0])-float(source[1]))/scale) if scale > 0 else 0.0
	var volley := maxf(_growth(catalog,stats,"burst"), maxf(_growth(catalog,stats,"spread_arrow"), f.split))
	f["volley"] = volley
	f["direct_volley"] = 0.0 if gravity else volley
	f["element"] = _growth(catalog, stats, catalog.element_enchantment_id(stats.active_element))
	# In gravity mode these cards convert into DPS/radii, not extra arrows.
	f["pattern_damage"] = f.element if gravity else maxf(f.flat, f.percent)
	f["range_damage"] = f.element if gravity else maxf(f.flat, f.percent)
	f["control_fit"] = 1.0 if gravity else volley
	f["shield_crit_fit"] = f.crit_damage if stats.shield_crit_per_charge > 0 and stats.combat_definition.shield_crit_bonus_cap > 0 else 0.0
	f["move_shortfall"] = _unit(1.0 - stats.move_speed / maxf(1.0, character.base_move_speed * (1.0 + float(scales.get("move_ratio", 0.0)))))
	f["pickup_shortfall"] = _unit(1.0 - stats.pickup_radius / maxf(1.0, character.base_pickup_radius + float(scales.get("pickup_radius", 0.0))))
	f["range_shortfall"] = _unit(1.0 - stats.arrow_range / maxf(1.0, character.bow.projectile_range * (1.0 + float(scales.get("range_ratio", 0.0))))) if character.bow != null else 0.0
	for element: String in catalog.element_ids():
		f["active_" + element] = 1.0 if stats.active_element == element else 0.0
	f["lightning"] = f.get("active_lightning", 0.0)
	f["fire_fit"] = maxf(_growth(catalog,stats,"burst"),_growth(catalog,stats,"spread_arrow"))
	f["lightning_fit"] = maxf(_growth(catalog,stats,"pierce"),f.split)
	f["ice_fit"] = f.effective_crit
	f["dark_fit"] = volley
	return f

static func _rule_sum(rules: Dictionary, features: Dictionary) -> float:
	var result := 0.0
	for feature: String in rules:
		result += _finite(rules[feature]) * _finite(features.get(feature,0.0))
	return result

static func evaluate(catalog, stats: CombatStats, state: OfferRunState, context: Dictionary = {}) -> Dictionary:
	var p: OfferWeightProfile = state.profile
	if p == null: p = preload("res://resources/settings/offer_weights.tres")
	var features := signals(catalog, stats)
	var candidates: Array[String] = catalog.eligible(stats.ranks,stats)
	candidates.sort()
	var progress := _unit(_finite(context.get("elapsed",0.0)) / maxf(1.0,_finite(context.get("campaign_duration",1.0),1.0)))
	var opening := 1.0 - _unit(progress / maxf(.001,_finite(p.phase_opening_fraction,.2)))
	var late := _unit((progress - _finite(p.phase_late_fraction,.8)) / maxf(.001,1.0-_finite(p.phase_late_fraction,.8)))
	if str(context.get("phase","campaign")) == "endless": opening = 0.0; late = 1.0
	var rows := {}
	var can_keep := true
	for key: String in candidates:
		var item: UpgradeDefinition = catalog.definition(key)
		if not item.is_enchantment or item.element_id == stats.active_element or int(stats.ranks.get("enchant_rank",0)) <= 0: can_keep = false
		var family := _family(catalog,key)
		var base := maxf(.001,_finite(p.base_weights.get(key,75.0),75.0))
		var affinity := clampf(1.0 + _rule_sum(p.affinities.get(key,{}),features),maxf(.01,_finite(p.affinity_min,.85)),maxf(.01,_finite(p.affinity_max,1.4)))
		var utility := maxf(.01,1.0 + _rule_sum(p.utility_rules.get(key,{}),features))
		var phase := 1.0 + (_finite(p.opening_bias.get(key,1.0),1.0)-1.0)*opening + (_finite(p.late_bias.get(key,1.0),1.0)-1.0)*late
		var rank_bias := maxf(.01,_finite(p.owned_rank_bias,1.1)) if catalog.rank_for(stats.ranks,key)>0 else 1.0
		var misses := clampi(int(state.misses.get(family,0)),0,maxi(0,p.catchup_miss_cap))
		var catchup := 1.0 + misses * maxf(0.0,_finite(p.exclusive_catchup_per_miss if family == EXCLUSIVE_FAMILY else p.catchup_per_miss))
		var recent := 1.0
		if not state.recent.is_empty() and state.recent[-1].has(family):
			recent = maxf(.01,_finite(p.recent_once,.85))
			if state.recent.size()>1 and state.recent[-2].has(family): recent = maxf(.01,_finite(p.recent_twice,.75))
		var raw := base * clampf(affinity*utility*phase*rank_bias*catchup*recent,maxf(.001,_finite(p.total_min,.25)),maxf(.001,_finite(p.total_max,2.4)))
		rows[key] = {"base":base,"affinity":affinity,"utility":utility,"phase":phase,"rank":rank_bias,"catchup":catchup,"recent":recent,"raw":raw,"family":family,"category":"enchant" if item.is_enchantment else "upgrade", "switch":item.is_enchantment and not stats.active_element.is_empty() and item.element_id != stats.active_element}
	if stats.hp < stats.max_hp:
		rows["heal"] = {"raw":maxf(.001,_finite(p.heal_weight,20.0))*(1.0+features.health_deficit*maxf(0.0,_finite(p.heal_deficit_bonus,1.0))),"category":"consumable","family":"heal"}
	if stats.shields < stats.shield_capacity:
		var deficit := _unit(1.0-float(stats.shields)/maxi(1,stats.shield_capacity))
		rows["refill"] = {"raw":maxf(.001,_finite(p.refill_weight,16.0))*(1.0+deficit*maxf(0.0,_finite(p.refill_deficit_bonus,.5))),"category":"consumable","family":"refill"}
	return {"rows":rows,"features":features,"eligible":candidates,"can_keep_build":can_keep}

static func adjusted_weights(rows: Dictionary, p: OfferWeightProfile) -> Dictionary:
	var result := {}
	var enchant_mass := 0.0
	var other_mass := 0.0
	var consumable_mass := 0.0
	var largest_enchant := 0.0
	for key: String in rows:
		var weight := maxf(.001,_finite(rows[key].raw,.001))
		result[key] = weight
		match str(rows[key].category):
			"enchant": enchant_mass += weight; largest_enchant = maxf(largest_enchant,weight)
			"consumable": consumable_mass += weight
			_: other_mass += weight
	var enchant_scale := 1.0
	if enchant_mass > 0 and other_mass > 0: enchant_scale = minf(1.0,maxf(largest_enchant,maxf(.001,_finite(p.enchant_mass_ratio,.22))*other_mass)/enchant_mass)
	var upgrade_mass := other_mass + enchant_mass * enchant_scale
	var consumable_scale := 1.0
	if consumable_mass > 0 and upgrade_mass > 0: consumable_scale = minf(1.0,maxf(.001,_finite(p.consumable_mass_ratio,.2))*upgrade_mass/consumable_mass)
	for key: String in rows:
		if rows[key].category == "enchant": result[key] *= enchant_scale
		elif rows[key].category == "consumable": result[key] *= consumable_scale
	return result

static func generate(catalog, stats: CombatStats, state: OfferRunState, context: Dictionary = {}, count: int = 3) -> Dictionary:
	if not state.pending.is_empty(): return state.pending.duplicate(true)
	var evaluated := evaluate(catalog,stats,state,context)
	var rows: Dictionary = evaluated.rows
	var remaining := rows.duplicate(true)
	var keys: Array[String] = []
	var draws: Array = []
	var switches := 0
	var profile := state.profile if state.profile != null else preload("res://resources/settings/offer_weights.tres")
	for slot in range(mini(maxi(0,count),remaining.size())):
		var allowed := remaining.duplicate()
		var switch_limit := mini(maxi(0,profile.max_switches_with_alternative),maxi(0,count-1))
		if switches >= switch_limit:
			var has_alternative := false
			for candidate: String in remaining:
				if not remaining[candidate].get("switch",false): has_alternative = true
			if has_alternative:
				for candidate: String in remaining:
					if remaining[candidate].get("switch",false): allowed.erase(candidate)
		var weights := adjusted_weights(allowed,profile)
		var ordered := weights.keys()
		ordered.sort()
		var total := 0.0
		for key: String in ordered: total += float(weights[key])
		var roll := state.rng.randf() * total
		var chosen: String = ordered[-1]
		for key: String in ordered:
			roll -= float(weights[key])
			if roll < 0.0: chosen = key; break
		keys.append(chosen)
		if rows[chosen].get("switch",false): switches += 1
		draws.append({"weights":weights,"chosen":chosen})
		remaining.erase(chosen)
	var eligible_families := {}
	var offered_families: Array[String] = []
	for key: String in evaluated.eligible: eligible_families[_family(catalog,key)] = true
	for key: String in keys:
		if rows[key].category != "consumable" and not offered_families.has(rows[key].family): offered_families.append(rows[key].family)
	for family: String in eligible_families:
		state.misses[family] = 0 if offered_families.has(family) else mini(1000000,int(state.misses.get(family,0))+1)
	state.recent.append(offered_families)
	if state.recent.size()>2: state.recent.pop_front()
	state.serial += 1
	state.pending = {"keys":keys,"can_keep_build":evaluated.can_keep_build,"serial":state.serial,"breakdown":evaluated,"draws":draws}
	return state.pending.duplicate(true)
