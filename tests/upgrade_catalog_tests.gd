extends SceneTree
## Resource-backed upgrade contracts and real main-menu/upgrade-card callbacks.
## Run: godot --headless --path . --script tests/upgrade_catalog_tests.gd

const EXPECTED_VALUES := {
	"vitality": [0.0, 20.0, 40.0, 60.0],
	"damage": [0.0, 20.0, 40.0, 60.0],
	"damage_flat": [0.0, 5.0, 10.0, 15.0],
	"attack_speed": [0.0, 0.15, 0.30, 0.45],
	"crit_chance": [0.0, 0.08, 0.16, 0.24],
	"crit_damage": [0.0, 0.4, 0.8, 1.2],
	"move_speed": [0.0, 0.12, 0.24, 0.36],
	"pickup_radius": [0.0, 45.0, 90.0, 135.0],
	"regen": [0.0, 0.5, 1.0, 1.5],
	"shield": [0.0, 1.0, 2.0, 3.0],
	"pierce": [0.0, 1.0, 2.0, 3.0],
	"burst": [0.0, 1.0, 2.0, 3.0],
	"spread_arrow": [0.0, 2.0, 4.0, 6.0],
	"split": [0.0, 0.30, 0.45, 0.60],
	"knockback": [0.0, 0.25, 0.50, 0.75],
	"long_draw": [0.0, 0.10, 0.20, 0.30],
	"fire_enchant": [0.0, 5.0, 10.0, 15.0],
	"lightning_enchant": [0.0, 5.0, 10.0, 15.0],
	"ice_enchant": [0.0, 5.0, 10.0, 15.0],
	"dark_enchant": [0.0, 5.0, 10.0, 15.0],
	"fire_bow": [0.0, 1.0, 2.0, 3.0],
	"lightning_bow": [0.0, 1.0, 2.0, 3.0],
	"ice_bow": [0.0, 1.0, 2.0, 3.0],
	"dark_bow": [0.0, 1.0, 2.0, 3.0],
}
const ELEMENTS := ["fire", "lightning", "ice", "dark"]
const BOW_EXCLUSIVES := ["burst", "spread_arrow", "long_draw"]
const PREREQUISITES := {"fire_bow":"fire_enchant", "lightning_bow":"lightning_enchant", "ice_bow":"ice_enchant", "dark_bow":"dark_enchant"}
const STAT_PROPERTIES := [
	"damage_flat", "burst_damage_multiplier", "max_hp", "shield_capacity", "damage_percent", "attack_speed", "crit_chance",
	"crit_multiplier", "move_speed", "pickup_radius", "regen", "base_damage",
	"element_damage", "active_element", "element_skill_rank", "pierce_max_hits", "pierce_retention",
	"burst_count", "spread_arrow_count", "element_capacity",
	"split_damage", "arrow_damage", "arrow_rate", "arrow_speed", "arrow_range",
	"arrow_width", "knockback",
]

var checks := 0
var failures := 0
var catalog: UpgradeCatalog

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func check_number(actual: float, expected: float, label: String) -> void:
	check(is_equal_approx(actual, expected), "%s (got %.6f, expected %.6f)" % [label, actual, expected])

func ranks_at(rank: int, element: String = "fire") -> Dictionary:
	var result: Dictionary = {}
	for key: String in EXPECTED_VALUES:
		if catalog.definition(key).element_id.is_empty(): result[key] = rank
	if rank > 0:
		result.element_type = element
		result.enchant_rank = rank
		result.element_skill_rank = rank
	return catalog.normalize_ranks(result)

func candidate_ranks(key: String, rank: int) -> Dictionary:
	var item := catalog.definition(key)
	var result := ranks_at(3, item.element_id if not item.element_id.is_empty() else "fire")
	if item.is_enchantment:
		result.enchant_rank = rank
	elif not item.element_id.is_empty():
		result.element_skill_rank = rank
	else:
		result[key] = rank
	return catalog.normalize_ranks(result)

func snapshot(stats: CombatStats) -> Dictionary:
	var result: Dictionary = {}
	for property: String in STAT_PROPERTIES:
		result[property] = stats.get(property)
	return result

func compare_snapshot(stats: CombatStats, expected: Dictionary, label: String) -> void:
	for property: String in expected:
		var actual: Variant = stats.get(property)
		check(actual != null, label + " exposes " + property)
		if actual != null and expected[property] != null:
			if actual is String:
				check(actual == expected[property], label + " " + property)
			else:
				check_number(float(actual), float(expected[property]), label + " " + property)

func check_catalog_resources() -> void:
	check(catalog.definitions.size() == 24, "Catalog contains exactly the approved 24 upgrades")
	check(UpgradeCatalog.UPGRADES.size() == 24, "Catalog loads 24 independent resources")
	var resource_files: Array[String] = []
	for filename: String in DirAccess.get_files_at("res://resources/upgrades"):
		if filename.ends_with(".tres"):
			resource_files.append(filename.get_basename())
	check(resource_files.size() == 24, "Upgrade resource directory contains exactly 24 upgrade resources")
	var exclusive_count := 0
	var seen_resource_ids: Array[String] = []
	for resource: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		check(not seen_resource_ids.has(resource.upgrade_id), "Unique resource id: " + resource.upgrade_id)
		seen_resource_ids.append(resource.upgrade_id)
		check(EXPECTED_VALUES.has(resource.upgrade_id), "No unrelated weapon or unapproved resource: " + resource.upgrade_id)
	for key: String in EXPECTED_VALUES:
		check(resource_files.has(key), "Independent resource exists for " + key)
		check(catalog.definitions.has(key), "Actual catalog contains " + key)
		if not catalog.definitions.has(key):
			continue
		var resource := load("res://resources/upgrades/" + key + ".tres") as UpgradeDefinition
		check(resource != null, "Upgrade resource loads: " + key)
		if resource == null:
			continue
		var definition: Dictionary = catalog.definitions[key]
		check(resource.upgrade_id == key, "Resource id matches filename: " + key)
		check(not resource.display_name.is_empty() and not resource.description.is_empty(), "Upgrade has a name and description: " + key)
		check(definition.name == resource.display_name and definition.description == resource.description, "Catalog text comes from resource: " + key)
		check(resource.values.size() == 4 and definition.values.size() == 4, "Every upgrade has base plus three ranks: " + key)
		check(resource.prerequisite == str(PREREQUISITES.get(key, "")), "Prerequisite remains scoped: " + key)
		check(str(definition.get("requires", "")) == resource.prerequisite, "Catalog preserves prerequisite: " + key)
		check(str(definition.tag) == resource.tag and not resource.tag.is_empty(), "Catalog preserves visible tag: " + key)
		var exclusive := resource.tag == "BOW EXCLUSIVE"
		check(exclusive == BOW_EXCLUSIVES.has(key), "Only approved bow-exclusive upgrades receive that tag: " + key)
		if exclusive:
			exclusive_count += 1
		elif resource.element_skill != null:
			check(resource.tag == "ELEMENT BOW SKILL" and not resource.element_id.is_empty(), "Element ability has its separate skill category: " + key)
		else:
			check("BOW" not in resource.tag, "General upgrades do not retain a misleading bow tag: " + key)
		for rank in range(4):
			check_number(catalog.value(key, rank), float(EXPECTED_VALUES[key][rank]), "%s rank %d approved value" % [key, rank])
			if rank < resource.values.size():
				check_number(resource.values[rank], float(EXPECTED_VALUES[key][rank]), "%s rank %d resource value" % [key, rank])
			if rank > 0 and rank < resource.values.size():
				check(resource.values[rank] > resource.values[rank - 1], "%s rank %d has a meaningful increase" % [key, rank])
			if rank < 3:
				var preview: String = catalog.describe_change(key, rank)
				check(not preview.is_empty() and " -> " not in preview, "%s rank %d selected benefit only" % [key, rank])
				check(preview == catalog.describe_rank(key, rank + 1), "%s selected rank matches runtime description" % key)
		check(catalog.describe_change(key, 3) == "MAX RANK", "Rank-three preview is capped: " + key)
		check(catalog.describe_change(key, 99) == "MAX RANK", "Over-cap preview remains capped: " + key)
		check_number(catalog.value(key, -5), float(EXPECTED_VALUES[key][0]), "Negative rank value clamps: " + key)
		check_number(catalog.value(key, 99), float(EXPECTED_VALUES[key][3]), "Over-cap value clamps: " + key)
	check(exclusive_count == 3, "Exactly three resources are tagged BOW EXCLUSIVE")
	check(catalog.describe_change("spread_arrow", 0) == "3 arrows per burst / side arrows: 55% damage", "Fan preview preserves actual total arrow counts")
	check(catalog.describe_change("pierce", 1) == "3 hits / 85% retained", "Pierce preview preserves hit count and retention")
	check(catalog.describe_change("not_an_upgrade", 0).is_empty(), "Unknown upgrade has no misleading preview")
	check_number(catalog.value("not_an_upgrade", 3), 0.0, "Unknown upgrade has no stat contribution")
	for key: String in ["split", "knockback", "long_draw"]:
		if not catalog.definitions.has(key):
			continue
		for rank in range(1, 4):
			var selected := catalog.describe_rank(key, rank)
			var percent := int(round(float(EXPECTED_VALUES[key][rank]) * 100.0))
			check(str(percent) in selected and "%" in selected, "%s rank %d selected percent" % [key, rank])

func check_eligibility() -> void:
	var base := catalog.eligible({})
	check(base.size() == 20, "Fresh bow run offers 16 general upgrades plus 4 enchantments")
	for key: String in EXPECTED_VALUES:
		check(base.has(key) == not PREREQUISITES.has(key), "Fresh-run prerequisite eligibility: " + key)
	for element: String in ELEMENTS:
		var ranks := {"element_type":element, "enchant_rank":1, "element_skill_rank":0}
		for other: String in ELEMENTS:
			check(catalog.eligible(ranks).has(other + "_bow") == (other == element), "Only matching equipped element unlocks bow ability")
			check(catalog.eligible(ranks).has(other + "_enchant"), "All enchantment types remain available before active cap")
		for rank in range(1, 3):
			ranks.element_skill_rank = rank
			check(catalog.eligible(ranks).has(element + "_bow"), "Matching skill remains eligible below cap")
		var maxed := ranks_at(3, element)
		var available := catalog.eligible(maxed)
		check(available.size() == 3 and not available.has(element + "_enchant"), "Maxed active type is excluded while other three remain switchable")
		check(not available.has(element + "_bow"), "Maxed shared skill is excluded")
		for other: String in ELEMENTS:
			if other == element: continue
			var before := maxed.duplicate(true)
			var switched := catalog.apply_choice(maxed, other + "_enchant")
			check(switched.element_type == other and switched.enchant_rank == 3 and switched.element_skill_rank == 3, "Type switch preserves shared enchantment and skill investments")
			check(maxed == before, "Type choice never mutates caller state")
			check(catalog.rank_for(switched, element + "_enchant") == 0 and catalog.rank_for(switched, other + "_enchant") == 3, "Rank view maps only to newly active element")
			check("Switch type; keep enchant Lv3 / skill Lv3" in catalog.describe_choice(other + "_enchant", maxed), "Switch card truthfully describes preserved ranks")
	check(catalog.eligible(ranks_at(99)).size() == 3, "Over-cap values normalize without removing type switches")
	for key: String in EXPECTED_VALUES:
		var isolated := candidate_ranks(key, 2)
		var eligible := catalog.eligible(isolated)
		check(eligible.size() == 4 and eligible.has(key), "Rank-two upgrade remains alongside three elemental switches: " + key)
		var chosen := catalog.apply_choice(isolated, key)
		check(catalog.rank_for(chosen, key) == 3, "Choice increments correct shared or general rank: " + key)
		check(not catalog.eligible(chosen).has(key), "Selected rank-three option leaves candidate pool: " + key)
	check(catalog.apply_choice({}, "fire_bow").is_empty(), "Unowned element cannot acquire a skill directly")
	check(catalog.normalize_ranks({"poison":3, "bleed":3, "element_type":"unknown", "enchant_rank":3}).is_empty(), "Removed upgrades and invalid element do not persist as hidden ranks")

func check_stats() -> void:
	var archer := load("res://resources/characters/archer.tres") as CharacterDefinition
	check(archer != null and archer.bow != null, "Real character and bow resources load")
	if archer == null or archer.bow == null:
		return
	var stats := archer.create_stats()
	stats.catalog.all_unlocked = true # Full-catalog combat fixture.
	var baseline := snapshot(stats)
	stats.hp = 43.0
	for rank in range(1, 4):
		var requested := ranks_at(rank)
		stats.apply_ranks(requested)
		check_number(stats.hp, 43.0, "Recompute does not heal current HP at rank " + str(rank))
		check(stats.shields == 0, "Recompute does not refill shields at rank " + str(rank))
		check_number(stats.arrow_range, archer.bow.projectile_range * (1.0 + 0.10 * rank), "Long Draw range at rank " + str(rank))
		check_number(stats.arrow_speed, archer.bow.projectile_speed * (1.0 + 0.10 * rank), "Long Draw speed at rank " + str(rank))
		check_number(stats.knockback, archer.bow.knockback * (1.0 + 0.25 * rank), "Knockback scales immutable bow baseline at rank " + str(rank))
		if stats.get("split_damage") != null:
			check_number(float(stats.get("split_damage")), float(EXPECTED_VALUES.split[rank]), "Split child damage ratio at rank " + str(rank))
		check_number(stats.element_damage, 5.0 * rank * (1.0 + 0.2 * rank), "Shared enchantment rank receives total damage scaling")
		check(stats.active_element == "fire" and stats.element_skill_rank == rank, "Full build has exactly one active element and shared skill rank")
		var upgraded := snapshot(stats)
		for repetition in range(3):
			stats.apply_ranks(requested)
			compare_snapshot(stats, upgraded, "Idempotent rank %d pass %d" % [rank, repetition])
		requested["long_draw"] = 0
		check(int(stats.ranks.get("long_draw", 0)) == rank, "Caller dictionary mutation cannot alter stored ranks")
		stats.apply_ranks({})
		compare_snapshot(stats, baseline, "All stats reset after rank " + str(rank))
		check_number(stats.hp, 43.0, "Reset preserves living current HP")
	stats.apply_ranks(ranks_at(3))
	var expected_max := {
		"damage_flat": 15.0, "burst_damage_multiplier": 0.38, "max_hp": 160.0, "shield_capacity": 3, "damage_percent": 60.0,
		"attack_speed": 1.45, "crit_chance": 0.29, "crit_multiplier": 3.2,
		"move_speed": 312.8, "pickup_radius": 210.0, "regen": 1.5,
		"base_damage": 48.0, "element_damage": 24.0, "element_skill_rank": 3,
		"pierce_max_hits": 4, "pierce_retention": 0.95,
		"burst_count": 4, "spread_arrow_count": 7, "element_capacity": 1,
		"split_damage": 0.6, "active_element": "fire",
		"arrow_damage": 15.0, "arrow_rate": 1.8, "arrow_width": 7.0,
	}
	compare_snapshot(stats, expected_max, "Approved full build")
	stats.hp = stats.max_hp
	stats.shields = 3
	stats.apply_ranks({"vitality": 1, "shield": 1})
	check_number(stats.hp, 120.0, "Rank reduction clamps HP to reduced maximum")
	check(stats.shields == 1, "Rank reduction clamps shields to reduced capacity")
	stats.hp = 0.0
	stats.apply_ranks(ranks_at(3))
	check(stats.hp == 0.0, "Applying upgrades cannot resurrect a dead player")
	# Test both no-character and character-with-no-bow fallbacks, including switching
	# away from a different weapon resource after an upgraded build was applied.
	for without_character: bool in [true, false]:
		var fallback := CombatStats.new()
		fallback.catalog.all_unlocked = true # Full-catalog combat fixture.
		if not without_character:
			fallback.character = CharacterDefinition.new()
		fallback.apply_ranks({})
		var fallback_baseline := snapshot(fallback)
		var custom_character := CharacterDefinition.new()
		custom_character.bow = BowDefinition.new()
		custom_character.bow.damage = 27.0
		custom_character.bow.rate = 2.7
		custom_character.bow.projectile_speed = 900.0
		custom_character.bow.projectile_range = 700.0
		custom_character.bow.projectile_width = 9.0
		custom_character.bow.knockback = 80.0
		fallback.character = custom_character
		fallback.apply_ranks({"long_draw": 3, "knockback": 3})
		check_number(fallback.arrow_range, 910.0, "Custom bow range supplies upgrade baseline")
		check_number(fallback.arrow_speed, 1170.0, "Custom bow speed supplies upgrade baseline")
		check_number(fallback.knockback, 140.0, "Custom bow knockback supplies upgrade baseline")
		fallback.character = null if without_character else CharacterDefinition.new()
		fallback.apply_ranks({})
		compare_snapshot(fallback, fallback_baseline, "Fallback resets stale custom bow; character-null=" + str(without_character))
		fallback.apply_ranks({"long_draw": 3, "knockback": 3, "split": 3})
		check_number(fallback.arrow_range, 676.0, "Fallback Long Draw range")
		check_number(fallback.arrow_speed, 845.0, "Fallback Long Draw speed")
		check_number(fallback.knockback, 78.75, "Fallback knockback")
		var fallback_upgraded := snapshot(fallback)
		fallback.apply_ranks({"long_draw": 3, "knockback": 3, "split": 3})
		compare_snapshot(fallback, fallback_upgraded, "Fallback upgrades are idempotent")
		fallback.apply_ranks({})
		compare_snapshot(fallback, fallback_baseline, "Fallback upgrades reset cleanly")

func check_element_critical_chance() -> void:
	var stats := CombatStats.new()
	stats.catalog.all_unlocked = true # Full-catalog combat fixture.
	for element: String in ELEMENTS:
		for rank in range(1, 4):
			stats.apply_ranks({"element_type":element, "enchant_rank":rank, "element_skill_rank":rank})
			var fresh := StatusEffects.new()
			check(not CombatRules.resolve_direct(stats, fresh, 10.0, 0.06).crit, "Element never adds an implicit critical bonus: " + element)
			check(CombatRules.resolve_direct(stats, fresh, 10.0, 0.04).crit, "Element retains ordinary critical chance: " + element)
			check(fresh.frost_stacks == 0 and fresh.chill_remaining == 0, "Direct damage resolver never applies control by itself")
	stats.apply_ranks({"element_type":"ice", "enchant_rank":3, "element_skill_rank":3, "crit_chance":3, "shield":2})
	stats.shields = 2
	var frozen := StatusEffects.new()
	for i in range(3): frozen.apply_ice(stats.element_skill, 3)
	check(CombatRules.resolve_direct(stats, frozen, 10.0, 0.349).crit, "Ordinary critical chance and two current shields add to 35 percent")
	check(not CombatRules.resolve_direct(stats, frozen, 10.0, 0.351).crit, "Frozen state does not provide a removed combo critical bonus")
	check(CombatRules.resolve_direct(stats, frozen, 10.0, 0.0, 1.0, true).crit, "Secondary fragments independently use ordinary critical chance")

func find_buttons(node: Node) -> Array[Button]:
	var result: Array[Button] = []
	if node is Button:
		result.append(node as Button)
	for child: Node in node.get_children():
		result.append_array(find_buttons(child))
	return result

func key_for_card(card: Button) -> String:
	for key: String in catalog.definitions:
		if card.text.begins_with(str(catalog.definitions[key].name) + " "):
			return key
	return ""

func prepare_upgrade(game: Node, ranks: Dictionary) -> void:
	game.arena.offer_state.resolve_offer() # This helper starts a new independent card scenario.
	if game.current_mode == "upgrade":
		game.resume_run()
	game.arena.apply_ranks(ranks)
	game.arena.stats.hp = game.arena.stats.max_hp
	game.arena.stats.shields = game.arena.stats.shield_capacity
	game.show_upgrades()

func check_offer(game: Node, expected_count: int, label: String) -> Array[Button]:
	check(game.current_mode == "upgrade" and paused, label + ": actual upgrade screen pauses simulation")
	var cards: Array[Button] = []
	for control in find_buttons(game.overlay):
		if control.has_meta("upgrade_key"): cards.append(control)
	check(cards.size() == expected_count, label + ": expected option count")
	var seen: Array[String] = []
	var eligible: Array[String] = catalog.eligible(game.arena.ranks, game.arena.stats)
	for card: Button in cards:
		var key := key_for_card(card)
		check(not key.is_empty() and EXPECTED_VALUES.has(key), label + ": card belongs to approved bow-run catalog")
		if key.is_empty():
			continue
		check(not seen.has(key), label + ": distinct option " + key)
		seen.append(key)
		check(eligible.has(key), label + ": only eligible option " + key)
		var rank := catalog.rank_for(game.arena.ranks, key)
		check(rank < 3, label + ": excludes maxed " + key)
		if PREREQUISITES.has(key):
			check(catalog.rank_for(game.arena.ranks, PREREQUISITES[key]) > 0, label + ": prerequisite satisfied for " + key)
		check("[%d/3]" % catalog.choice_rank(game.arena.ranks, key) in card.text, label + ": rank-three cap shown on " + key)
		check(catalog.describe_choice(key, game.arena.ranks) in card.text, label + ": selected rank benefits displayed on " + key)
		check(not ("[" + str(catalog.definitions[key].tag) + "]") in card.text, label + ": no redundant category badge on " + key)
		check(catalog.definition(key).display_name in card.text, label + ": upgrade identity remains visible on " + key)
	return cards

func check_main_ui() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	TranslationServer.set_locale("en")
	GameLocale.refresh_tree(game)
	var start: Button = null
	for item: Button in find_buttons(game.ui):
		if item.text == GameLocale.text("MENU_START"):
			start = item
	check(start != null, "Real main menu contains Start Run")
	if start == null:
		game.queue_free()
		await process_frame
		return
	start.pressed.emit()
	game.catalog.all_unlocked = true # Explicit full-catalog card contract.
	game.arena.offer_state.profile = uniform_card_fixture()
	check(game.current_mode == "campaign" and game.arena != null, "Real start button enters bow-only endless run")
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	# Fixed seeds exercise the actual shuffle without random pass/fail behavior.
	for iteration in range(24):
		game.arena.offer_state.reset(1200 + iteration)
		var ranks: Dictionary = {} if iteration < 12 else {"damage": 3, "shield": 3, "split": 3}
		prepare_upgrade(game, ranks)
		check_offer(game, 3, "Seeded offer " + str(iteration))
		game.resume_run()
		await process_frame
	# Type switching remains available. Seeded bounded shuffles exercise each
	# real card at each rank without suppressing legitimate switch candidates.
	for key: String in EXPECTED_VALUES:
		for rank in range(3):
			var ranks := candidate_ranks(key, rank)
			var selected: Button = null
			for attempt in range(32):
				game.arena.offer_state.reset(5200 + attempt)
				prepare_upgrade(game, ranks)
				var cards := check_offer(game, 3, "%s real card rank %d" % [key, rank])
				for card: Button in cards:
					if key_for_card(card) == key: selected = card
				if selected != null: break
				game.resume_run()
				await process_frame
			check(selected != null, "Required actual card exists: %s rank %d" % [key, rank])
			if selected == null:
				game.resume_run()
				await process_frame
				continue
			var after := catalog.apply_choice(ranks, key)
			selected.pressed.emit()
			check(catalog.rank_for(game.arena.ranks, key) == rank + 1, "Pressed actual card increments correct upgrade: %s rank %d" % [key, rank])
			check(game.arena.ranks == after, "Card changes only its intended canonical investment: " + key)
			check(game.current_mode == "campaign" and not paused and game.overlay == null, "Pressed card safely resumes endless and retires overlay: " + key)
			var expected := (load("res://resources/characters/archer.tres") as CharacterDefinition).create_stats()
			expected.apply_ranks(after)
			compare_snapshot(game.arena.stats, snapshot(expected), "Actual selected upgrade recomputes build: " + key)
			if key == "shield":
				check(game.arena.stats.shields == rank + 1, "Real shield card refills new capacity")
			await process_frame
	prepare_upgrade(game, ranks_at(3))
	var final_buttons := check_offer(game, 3, "Fully invested elemental build")
	var keep_controls := find_buttons(game.overlay).filter(func(control: Button) -> bool: return control.get_meta("action", "") == "keep_build")
	check(keep_controls.size() == 1, "Full-investment type switches retain a separate keep-build escape")
	for card: Button in final_buttons:
		var key := key_for_card(card)
		check(key.ends_with("_enchant") and key != "fire_enchant", "Full build offers other types rather than dead-end KEEP FIGHTING")
	game.resume_run()
	# Preserve the no-candidates fallback for an intentionally restricted custom
	# catalog, which unlike the default catalog has no permanent type switches.
	var restricted := (load("res://resources/characters/archer.tres") as CharacterDefinition).duplicate(true) as CharacterDefinition
	restricted.upgrades.clear()
	for definition: UpgradeDefinition in UpgradeCatalog.UPGRADES:
		if definition.element_id.is_empty(): restricted.upgrades.append(definition)
	game.character_definition = restricted
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	prepare_upgrade(game, ranks_at(3))
	var mastered := find_buttons(game.overlay)
	check(mastered.size() == 1 and mastered[0].text == "KEEP FIGHTING", "Fully mastered restricted general catalog retains continue fallback")
	if mastered.size() == 1 and mastered[0].text == "KEEP FIGHTING":
		var before: Dictionary = game.arena.ranks.duplicate()
		mastered[0].pressed.emit()
		check(game.current_mode == "campaign" and not paused, "Mastered-build continue button resumes endless")
		check(game.arena.ranks == before, "Continue does not create or over-rank an upgrade")
	game.queue_free()
	paused = false
	await process_frame

func run() -> void:
	catalog = UpgradeCatalog.new()
	catalog.all_unlocked = true # Full-catalog combat fixture; progression is tested separately.
	check_catalog_resources()
	check_eligibility()
	check_stats()
	check_element_critical_chance()
	await check_main_ui()
	print("UPGRADE CATALOG: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)

## Exhaustive UI/card plumbing uses an explicit uniform policy. Production dynamic
## probabilities, history and mode utility are exercised in dedicated offer suites.
func uniform_card_fixture() -> OfferWeightProfile:
	var policy := OfferWeightProfile.new()
	for key in EXPECTED_VALUES: policy.base_weights[key] = 1.0
	policy.owned_rank_bias = 1.0
	policy.catchup_per_miss = 0.0
	policy.exclusive_catchup_per_miss = 0.0
	policy.recent_once = 1.0
	policy.recent_twice = 1.0
	policy.enchant_mass_ratio = 100.0
	policy.consumable_mass_ratio = 100.0
	policy.heal_weight = 1.0
	policy.refill_weight = 1.0
	policy.heal_deficit_bonus = 0.0
	policy.refill_deficit_bonus = 0.0
	return policy
