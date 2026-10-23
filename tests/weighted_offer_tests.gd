extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	var stats := CombatStats.new()
	stats.catalog.all_unlocked = true
	stats.apply_ranks({"element_type":"fire","enchant_rank":1})
	var state := OfferRunState.new()
	state.reset(123456)
	var context := {"elapsed":180.0,"campaign_duration":360.0,"phase":"campaign"}
	var before := state.snapshot()
	var breakdown := stats.catalog.offer_breakdown(stats,state,context)
	check(state.snapshot() == before,"pure preview does not consume state")
	check(breakdown.rows.size()==21,"full pool21")
	check(breakdown.rows.fire_bow.base==40,"exclusive40")
	var offer := stats.catalog.generate_offer(stats,state,context)
	check(offer.keys.size()==3,"threechoices")
	check(offer.keys[0]!=offer.keys[1] and offer.keys[0]!=offer.keys[2] and offer.keys[1]!=offer.keys[2],"distinct")
	var frozen := state.snapshot()
	stats.apply_ranks({"element_type":"dark","enchant_rank":3,"element_skill_rank":3})
	check(stats.catalog.generate_offer(stats,state,{})==offer,"rebuild cannot reroll pending")
	check(state.snapshot()==frozen,"cached call no pity/rng changes")
	var clone := OfferRunState.new()
	clone.restore(state.snapshot())
	state.resolve_offer(); clone.resolve_offer()
	for iteration in range(100):
		var a := stats.catalog.generate_offer(stats,state,context)
		var b := stats.catalog.generate_offer(stats,clone,context)
		check(a==b,"exactrestore")
		for key: String in a.keys: check(stats.catalog.eligible(stats.ranks,stats).has(key),"eligible")
		state.resolve_offer(); clone.resolve_offer()
	var dark := stats.catalog.offer_breakdown(stats,state,context)
	check(dark.rows.pierce.utility < .36,"dark pierce inactive lowweight")
	check(dark.rows.crit_damage.utility == .85,"dark directcrit still viable")
	stats.apply_ranks({"crit_chance":3,"shield":3})
	stats.shields=3
	var crit := stats.catalog.offer_breakdown(stats,state,context)
	check(is_equal_approx(crit.features.effective_crit,stats.effective_crit_chance()/stats.combat_definition.total_crit_chance_cap),"authoritative crit accessor")
	var full := {}
	for key: String in stats.catalog.resources:
		if stats.catalog.definition(key).element_id.is_empty(): full[key]=3
	full.element_type="fire";full.enchant_rank=3;full.element_skill_rank=3
	stats.apply_ranks(full);stats.hp=stats.max_hp;stats.shields=stats.shield_capacity
	state.resolve_offer()
	var end := stats.catalog.generate_offer(stats,state,context)
	check(end.keys.size()==3 and end.can_keep_build,"three pivots plus keep escape")
	for key: String in end.keys: check(key.ends_with("_enchant") and key!="fire_enchant","onlyalternativeenchants")
	full.crit_damage=2
	stats.apply_ranks(full)
	for count in [1,2,3]:
		for seed_value in range(100):
			state.reset(seed_value)
			var guarded := stats.catalog.generate_offer(stats,state,context,count)
			check(guarded.keys.size()==count,"requested cardinality")
			check(guarded.keys.has("crit_damage"),"non-switch escape must occur among sampled cards")
			check(not guarded.can_keep_build,"rankup anywhere forbids free keep")
	full.crit_damage=3
	full.erase("element_type");full.erase("enchant_rank");full.erase("element_skill_rank")
	stats.apply_ranks(full);state.resolve_offer()
	check(not stats.catalog.generate_offer(stats,state,context).can_keep_build,"firstenchant is actual progression")
	# Statistical smoke: independent initial-offer distribution. Full exhaustive suite is separate.
	stats.apply_ranks({"element_type":"fire","enchant_rank":1});stats.hp=stats.max_hp;stats.shields=0
	var selected := 0
	for iteration in range(10000):
		state.reset(iteration+301)
		if stats.catalog.generate_offer(stats,state,context).keys.has("fire_bow"): selected+=1
	check(selected>600 and selected<1300,"exclusive lowteens rather thanabsent")
	print("WEIGHTED OFFERS: %d checks, %d failures; initial exclusive %d/10000" % [checks,failures,selected])
	quit(1 if failures else 0)
