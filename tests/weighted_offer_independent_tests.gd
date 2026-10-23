extends SceneTree
## Independent synthetic contracts. Not a claim of human gameplay balance.
## -- --weighted-samples=5000 controls the counted Monte Carlo sample size.
var checks := 0
var failures := 0
var samples := 3000
const State = preload("res://scripts/upgrades/offer_run_state.gd")
const MID := {"elapsed":300.0, "campaign_duration":600.0, "phase":"campaign"}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--weighted-samples="): samples = maxi(1000, int(arg.get_slice("=", 1)))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("WEIGHTED INDEPENDENT: " + label)

func stats_for(ranks: Dictionary = {}, unlocked: bool = true) -> CombatStats:
	var s := CombatStats.new()
	s.catalog.all_unlocked = unlocked
	s.apply_ranks(ranks)
	s.hp = s.max_hp
	s.shields = s.shield_capacity
	return s

func state_for(seed_value: int = 12345):
	var state = State.new()
	state.reset(seed_value)
	return state

func offer(s: CombatStats, state, count: int = 3) -> Dictionary:
	return s.catalog.generate_offer(s, state, MID, count)

func full_ranks(catalog: UpgradeCatalog) -> Dictionary:
	var ranks := {"element_type":"fire", "enchant_rank":3, "element_skill_rank":3}
	for key: String in catalog.resources:
		if catalog.definition(key).element_id.is_empty(): ranks[key] = catalog.max_rank(key)
	return ranks

func check_cache_and_replay() -> void:
	var s := stats_for({"element_type":"fire", "enchant_rank":1})
	var state = state_for(9842)
	var first := offer(s, state)
	var saved: Dictionary = state.snapshot()
	s.hp = 1.0
	s.shields = 0
	s.catalog.all_unlocked = false
	for locale in ["en", "zh_CN", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in s.catalog.definitions: s.catalog.describe_choice(key, s.ranks)
		check(offer(s, state) == first, "Pending offer is immutable despite HP, unlock and locale changes")
		check(state.snapshot() == saved, "Repeated rendering/generation commits state exactly once")
	s.catalog.all_unlocked = true
	state.resolve_offer()
	var replay = state_for(999)
	replay.restore(saved)
	replay.resolve_offer()
	check(offer(s, state) == offer(s, replay), "Snapshot restoration replays exact next offer")
	var a = state_for(789)
	var b = state_for(789)
	for i in range(20):
		for j in range(13): randf()
		check(offer(s, a) == offer(s, b), "Dedicated offer RNG unaffected by global combat noise")
		a.resolve_offer()
		b.resolve_offer()
	var locked := stats_for({}, false)
	var gated = state_for(765)
	var old := offer(locked, gated)
	var eligible_before := locked.catalog.eligible(locked.ranks).size()
	locked.catalog.progression.persistence_enabled = false
	locked.catalog.progression.begin_run(false)
	locked.catalog.progression.metrics = {"kills":1000000, "survival":1000000, "bosses":1000000}
	locked.catalog.progression._evaluate()
	check(locked.catalog.eligible(locked.ranks).size() > eligible_before, "Actual achievement completion expands next-offer eligibility")
	check(offer(locked, gated) == old, "Achievement completion mid-modal does not reroll current offer")
	state.reset(9842)
	check(state.serial == 0 and state.pending.is_empty() and state.misses.is_empty() and state.recent.is_empty(), "New run clears every history field")

func check_pool_and_order() -> void:
	var s := stats_for()
	var maxed := full_ranks(s.catalog)
	s.apply_ranks(maxed)
	s.hp = s.max_hp
	s.shields = s.shield_capacity
	var result := offer(s, state_for())
	check(result.keys.size() == 3 and result.can_keep_build, "Entire permanent pool exhausted: all three switches plus separate Keep Build")
	for key: String in result.keys: check(key.ends_with("_enchant") and key != "fire_enchant", "Full build excludes capped ranks and active enchant")
	maxed.damage = 2
	s.apply_ranks(maxed)
	for seed_value in range(100):
		result = offer(s, state_for(seed_value))
		check(not result.can_keep_build, "A rank increase anywhere in pool forbids Keep Build, even if omitted")
		check(result.keys.has("damage"), "Diversity guard keeps sole legal non-switch option in offer")
	var unenchanted := full_ranks(s.catalog)
	unenchanted.erase("element_type")
	unenchanted.erase("enchant_rank")
	unenchanted.erase("element_skill_rank")
	s.apply_ranks(unenchanted)
	check(not offer(s, state_for()).can_keep_build, "First enchant is rank growth, not a switch-only escape")
	var normal := stats_for({"element_type":"ice", "enchant_rank":1})
	var reversed := stats_for({"enchant_rank":1, "element_type":"ice"})
	var ids: Array = reversed.catalog.resources.keys()
	ids.reverse()
	var reordered := {}
	for key: String in ids: reordered[key] = reversed.catalog.resources[key]
	reversed.catalog.resources = reordered
	for seed_value in range(40):
		check(offer(normal, state_for(seed_value)) == offer(reversed, state_for(seed_value)), "Resource and rank dictionary order do not affect replay")
	var locked := stats_for({}, false)
	for seed_value in range(120):
		result = offer(locked, state_for(seed_value))
		var seen := {}
		check(result.keys.size() == mini(3, locked.catalog.eligible(locked.ranks).size()), "Correct offer cardinality")
		for key: String in result.keys:
			check(not seen.has(key) and locked.catalog.is_unlocked(key) and locked.catalog.eligible(locked.ranks).has(key), "No duplicate, locked or wrong-element card")
			seen[key] = true

func check_monte_carlo() -> void:
	# Reset history per draw: estimates neutral independent draws, not an adaptive run.
	var s := stats_for({"element_type":"fire", "enchant_rank":1})
	var counts := {}
	var all_basic := 0
	for i in range(samples):
		var result := offer(s, state_for(450001 + i))
		var seen := {}
		var basics := true
		for key: String in result.keys:
			counts[key] = int(counts.get(key, 0)) + 1
			seen[key] = true
			if not s.catalog.definition(key).element_id.is_empty(): basics = false
		check(seen.size() == 3, "Weighted sample has three distinct cards")
		if basics: all_basic += 1
	check(int(counts.get("fire_bow", 0)) < int(counts.get("damage", 0)), "Neutral exclusive per-item inclusion remains below common damage")
	check(int(counts.get("fire_bow", 0)) > samples * 0.025, "Exclusive remains meaningfully positive, not silently forbidden")
	check(all_basic > samples * 0.15, "No compulsory enchant/exclusive category")
	print("WEIGHTED MC neutral fire enchant Lv1, independent histories: N=%d inclusions=%s all_basic=%d" % [samples, JSON.stringify(counts), all_basic])

func check_conditional_and_frequency() -> void:
	var s := stats_for()
	var ranks := full_ranks(s.catalog)
	s.apply_ranks(ranks)
	s.hp = 1
	s.shields = s.shield_capacity
	for count in [1, 2, 3]:
		for seed_value in range(80):
			var result := offer(s, state_for(seed_value), count)
			check(result.keys.size() == count and result.keys.has("heal"), "Conditional guard preserves sole heal alternative at count " + str(count))
			check(result.can_keep_build, "Utility alternative does not pretend to be permanent growth")
	var definitions: Array[UpgradeDefinition] = [s.catalog.definition("damage"), s.catalog.definition("crit_damage")]
	var pair := stats_for()
	pair.catalog = UpgradeCatalog.new(definitions)
	pair.catalog.all_unlocked = true
	var evaluator = load("res://scripts/upgrades/upgrade_offer_engine.gd")
	var state = state_for()
	var rows: Dictionary = evaluator.evaluate(pair.catalog, pair, state, MID).rows
	var expected: float = rows.damage.raw / (rows.damage.raw + rows.crit_damage.raw)
	var hits := 0
	for i in range(samples):
		var result := offer(pair, state_for(i + 833100), 1)
		if result.keys[0] == "damage": hits += 1
	var sigma := sqrt(samples * expected * (1.0 - expected))
	check(absf(hits - samples * expected) < 6.0 * sigma + 5, "Two-card frequency matches weighted ratio within conservative six-sigma tolerance")
	var all := offer(pair, state_for(), 3)
	check(all.keys.size() == 2 and all.keys.has("damage") and all.keys.has("crit_damage"), "Pool smaller than three returns every legal candidate")
	print("WEIGHTED MC controlled two-card count1: N=%d damage=%d expected_probability=%.5f" % [samples, hits, expected])
	for element in ["fire", "lightning", "ice", "dark"]:
		var adaptive := stats_for({"element_type":element, "enchant_rank":2, "element_skill_rank":1})
		var history = state_for(87251)
		var counts := {}
		var drought := 0
		var completed_gaps: Array[int] = []
		var longest := 0
		for i in range(samples):
			var result := offer(adaptive, history)
			for key: String in result.keys: counts[key] = int(counts.get(key, 0)) + 1
			if result.keys.has(element + "_bow"):
				completed_gaps.append(drought)
				drought = 0
			else:
				drought += 1
				longest = maxi(longest, drought)
			history.resolve_offer()
		completed_gaps.sort()
		var p95: int = completed_gaps[mini(completed_gaps.size() - 1, int(completed_gaps.size() * .95))] if not completed_gaps.is_empty() else -1
		check(not completed_gaps.is_empty(), "Adaptive synthetic context still offers active exclusive: " + element)
		print("WEIGHTED MC synthetic fixed %s enchant2 skill1 adaptive history: N=%d exclusive=%d longest_miss_streak=%d completed_gap_p95=%d trailing_censored_gap=%d inclusions=%s" % [element, samples, int(counts.get(element + "_bow", 0)), longest, p95, drought, JSON.stringify(counts)])

func check_weights_and_history() -> void:
	var engine = load("res://scripts/upgrades/upgrade_offer_engine.gd")
	var s := stats_for({"element_type":"fire", "enchant_rank":1})
	var state = state_for()
	var before: Dictionary = state.snapshot()
	var evaluation: Dictionary = engine.evaluate(s.catalog, s, state, MID)
	check(state.snapshot() == before, "Debug evaluation is strictly read-only")
	for key: String in s.catalog.resources:
		check(state.profile.base_weights.has(key) and state.profile.affinities.has(key), "Every permanent card has authored base and dynamic affinities: " + key)
	check(evaluation.rows.fire_bow.base == 40 and evaluation.rows.damage.base == 100, "Authored exclusive 40 is below common damage 100")
	var base_damage_weight: float = evaluation.rows.damage.raw
	s.apply_ranks({"element_type":"fire", "enchant_rank":1, "damage_flat":3})
	evaluation = engine.evaluate(s.catalog, s, state, MID)
	check(evaluation.rows.damage.raw > base_damage_weight, "Flat damage raises percent damage synergy")
	for element in ["fire", "dark"]:
		s.apply_ranks({"element_type":element, "enchant_rank":1})
		var inactive: Dictionary = engine.evaluate(s.catalog, s, state, MID)
		s.apply_ranks({"element_type":element, "enchant_rank":1, "element_skill_rank":1})
		var active: Dictionary = engine.evaluate(s.catalog, s, state, MID)
		check(active.rows.pierce.raw < inactive.rows.pierce.raw and active.rows.pierce.raw > 0, "Inactive pierce utility is reduced but positive in " + element)
		if element == "dark": check(active.features.direct_volley == 0, "Gravity patterns do not pretend to add direct arrows")
	s.apply_ranks({"crit_chance":2, "crit_damage":3, "shield":3})
	s.crit_chance = 0.58
	s.shields = 3
	var capped: Dictionary = engine.evaluate(s.catalog, s, state, MID)
	check(is_equal_approx(s.effective_crit_chance(), 0.60), "Critical evaluation uses authoritative total cap")
	check(is_equal_approx(float(capped.features.crit_saturation), 1.0), "Crit chance marginal gain is zero at actual cap")
	s.shields = 0
	var drained: Dictionary = engine.evaluate(s.catalog, s, state, MID)
	check(drained.features.effective_crit < capped.features.effective_crit and drained.features.crit_saturation < capped.features.crit_saturation, "Current shield charges, not capacity, determine critical affinity")
	check(drained.rows.crit_chance.raw > capped.rows.crit_chance.raw, "Crit chance weight respects actual marginal cap")
	state.misses["element_exclusive"] = 7
	s.apply_ranks({})
	offer(s, state)
	check(state.misses.element_exclusive == 7, "Exclusive pity freezes while ineligible")
	state.resolve_offer()
	s.apply_ranks({"element_type":"ice", "enchant_rank":1})
	var result := offer(s, state, 100)
	check(result.keys.has("ice_bow") and state.misses.element_exclusive == 0, "Offering another element exclusive resets shared pity without choosing it")
	state.resolve_offer()
	s.apply_ranks({"element_type":"dark", "enchant_rank":1})
	evaluation = engine.evaluate(s.catalog, s, state, MID)
	check(evaluation.rows.dark_bow.recent < 1.0, "Recent exclusive family downweight survives element switch")
	# Family adjustment is recomputed on the remaining candidate set each slot.
	var rows := {"damage":{"raw":100.0,"category":"upgrade"}}
	var previous_mass := 0.0
	for count in range(1, 5):
		rows["enchant_" + str(count)] = {"raw":36.0,"category":"enchant"}
		var weights: Dictionary = engine.adjusted_weights(rows, state.profile)
		var mass := 0.0
		for key: String in weights:
			if key.begins_with("enchant"):
				check(weights[key] > 0, "Every unlocked switch has positive mass")
				mass += weights[key]
		check(mass <= 36.001 and mass >= previous_mass - .001, "One through four enchants cannot flood a small common pool")
		previous_mass = mass
	result = offer(s, state)
	var remaining: Dictionary = result.breakdown.rows.duplicate(true)
	for draw: Dictionary in result.draws:
		check(draw.weights == engine.adjusted_weights(remaining, state.profile), "Each draw removes and renormalizes remaining families")
		remaining.erase(draw.chosen)
	# Adversarial authored tuning must never produce NaN, infinity or zero totals.
	for bad in [NAN, INF, -INF, -1.0, 1.0e308]:
		var broken = state_for()
		broken.profile = state.profile.duplicate(true)
		for key: String in s.catalog.resources: broken.profile.base_weights[key] = bad
		broken.profile.total_max = bad
		broken.profile.owned_rank_bias = bad
		broken.profile.heal_weight = bad
		broken.profile.refill_weight = bad
		s.hp = 1
		var bad_offer := offer(s, broken)
		for draw: Dictionary in bad_offer.draws:
			var total := 0.0
			for key: String in draw.weights:
				check(is_finite(float(draw.weights[key])) and draw.weights[key] > 0, "Malformed tuning sanitizes every sampled weight")
				total += float(draw.weights[key])
			check(is_finite(total) and total > 0, "Malformed tuning cannot overflow total sampling mass")

func find_keep(game: Node) -> Button:
	for node in game.overlay.find_children("*", "Button", true, false):
		if node.get_meta("action", "") == "keep_build": return node as Button
	return null

func check_main_keep_build() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	await process_frame
	game.progression.persistence_enabled = false
	var sequences: Array = []
	for repeat in range(2):
		game.start_run(false, 0)
		game.arena.process_mode = Node.PROCESS_MODE_DISABLED
		game.arena.bow.enabled = false
		check(game.arena.run_seed == 0 and game.arena.offer_state.serial == 0, "Explicit seed zero is injected before first draw and resets state")
		var sequence: Array = []
		for index in range(5):
			for noise in range(31 * repeat): game.arena.rng.randf()
			game.show_upgrades()
			sequence.append(game.arena.offer_state.pending.keys.duplicate())
			var snap: Dictionary = game.arena.offer_state.snapshot()
			game.arena.apply_ranks(game.arena.ranks)
			game.resume_run()
			game.show_upgrades()
			check(game.arena.offer_state.snapshot() == snap, "Stats catalog rebuild and modal reopen preserve cached state")
			game.choose_upgrade("continue")
		sequences.append(sequence)
	check(sequences[0] == sequences[1], "Actual main first-five offers replay from explicit seed despite combat RNG noise")
	game.start_run(false, 714)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	game.arena.stats.catalog.all_unlocked = true
	game.arena.apply_ranks(full_ranks(game.arena.stats.catalog))
	game.arena.stats.hp = game.arena.stats.max_hp
	game.arena.stats.shields = game.arena.stats.shield_capacity
	var stale := Callable()
	for use_pad in [false, true]:
		game.show_upgrades()
		await process_frame
		if stale.is_valid():
			var pending_before: Dictionary = game.arena.offer_state.snapshot()
			stale.call()
			check(game.current_mode == "upgrade" and game.arena.offer_state.snapshot() == pending_before, "Stale previous offer callback cannot resolve new offer")
		var keep := find_keep(game)
		check(keep != null, "Full build renders separate Keep Build action")
		if keep == null: break
		var count := 0
		for node in game.overlay.find_children("*", "Button", true, false):
			if node.has_meta("upgrade_key"): count += 1
		check(count == 3, "Keep Build does not replace any switch card")
		var before: Dictionary = game.arena.ranks.duplicate(true)
		var hp: float = game.arena.stats.hp
		var xp: float = game.arena.xp
		var serial: int = game.arena.offer_state.serial
		stale = keep.pressed.get_connections()[0].callable
		keep.grab_focus()
		var event: InputEvent
		if use_pad:
			var pad := InputEventJoypadButton.new()
			pad.button_index = JOY_BUTTON_A
			pad.device = 7
			pad.pressed = true
			event = pad
		else:
			var keyboard := InputEventKey.new()
			keyboard.keycode = KEY_ENTER
			keyboard.pressed = true
			event = keyboard
		root.push_input(event)
		event.set("pressed", false)
		root.push_input(event)
		await process_frame
		check(game.current_mode == "campaign" and not paused and game.overlay == null, "Raw input Keep Build resumes without comparison popup")
		check(game.arena.ranks == before and game.arena.stats.hp == hp and game.arena.xp == xp, "Keep Build preserves ranks, element, HP and queued XP")
		check(game.arena.offer_state.pending.is_empty() and game.arena.offer_state.serial == serial, "Keep Build resolves exactly once without reroll")
	# Queue two levels, deliberately invoke actual physics once per resolution.
	game.arena.xp = 1000
	var level_before: int = game.arena.level
	game.arena._physics_process(0.0)
	check(game.arena.level == level_before + 1 and game.current_mode == "upgrade", "Queued XP opens one level selection")
	var first_xp: float = game.arena.xp
	game.choose_upgrade("continue")
	check(game.arena.xp == first_xp, "Selection does not double-consume XP")
	game.arena._physics_process(0.0)
	check(game.arena.level == level_before + 2 and game.current_mode == "upgrade" and game.arena.xp < first_xp, "Next physics tick processes next queued level once")
	game.choose_upgrade("continue")
	game.queue_free()
	paused = false
	await process_frame
	await preload("res://tests/audio_teardown.gd").drain(self)

func run() -> void:
	check_cache_and_replay()
	check_pool_and_order()
	check_monte_carlo()
	check_weights_and_history()
	check_conditional_and_frequency()
	await check_main_keep_build()
	print("WEIGHTED INDEPENDENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
