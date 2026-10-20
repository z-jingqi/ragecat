extends SceneTree
## Resource-backed upgrade contracts and real main-menu/upgrade-card callbacks.
## Run: godot --headless --path . --script tests/upgrade_catalog_tests.gd

const EXPECTED_VALUES := {
	"vitality": [0.0, 20.0, 40.0, 60.0],
	"damage": [0.0, 20.0, 40.0, 60.0],
	"attack_speed": [0.0, 0.15, 0.30, 0.45],
	"crit_chance": [0.0, 0.08, 0.16, 0.24],
	"crit_damage": [0.0, 0.4, 0.8, 1.2],
	"move_speed": [0.0, 0.12, 0.24, 0.36],
	"pickup_radius": [0.0, 45.0, 90.0, 135.0],
	"regen": [0.0, 0.5, 1.0, 1.5],
	"shield": [0.0, 1.0, 2.0, 3.0],
	"poison": [0.0, 3.0, 6.0, 9.0],
	"bleed": [0.0, 4.0, 8.0, 12.0],
	"poison_crit": [0.0, 0.35, 0.70, 1.0],
	"spread": [0.0, 55.0, 80.0, 110.0],
	"pierce": [0.0, 1.0, 2.0, 3.0],
	"burst": [0.0, 1.0, 2.0, 3.0],
	"spread_arrow": [0.0, 2.0, 4.0, 6.0],
	"bleed_regen": [0.0, 0.5, 1.0, 1.5],
	"split": [0.0, 0.30, 0.45, 0.60],
	"knockback": [0.0, 0.25, 0.50, 0.75],
	"long_draw": [0.0, 0.10, 0.20, 0.30],
}
const BOW_EXCLUSIVES := ["burst", "spread_arrow", "long_draw"]
const PREREQUISITES := {"poison_crit": "poison", "spread": "poison", "bleed_regen": "bleed"}
const STAT_PROPERTIES := [
	"max_hp", "shield_capacity", "damage_percent", "attack_speed", "crit_chance",
	"crit_multiplier", "move_speed", "pickup_radius", "regen", "poison_dps",
	"bleed_dps", "poison_crit", "spread_radius", "pierce_max_hits", "pierce_retention",
	"burst_count", "spread_arrow_count", "bleed_regen", "bleed_regen_buff",
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

func ranks_at(rank: int) -> Dictionary:
	var result: Dictionary = {}
	for key: String in EXPECTED_VALUES:
		result[key] = rank
	return result

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
			check_number(float(actual), float(expected[property]), label + " " + property)

func check_catalog_resources() -> void:
	check(catalog.definitions.size() == 20, "Catalog contains exactly the approved 20 upgrades")
	check(UpgradeCatalog.UPGRADES.size() == 20, "Catalog loads 20 independent resources")
	var resource_files: Array[String] = []
	for filename: String in DirAccess.get_files_at("res://resources/upgrades"):
		if filename.ends_with(".tres"):
			resource_files.append(filename.get_basename())
	check(resource_files.size() == 20, "Upgrade resource directory contains exactly 20 upgrade resources")
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
				var parts := preview.split(" -> ")
				check(parts.size() == 2, "%s rank %d preview shows current and next" % [key, rank])
				if parts.size() == 2:
					check(not parts[0].is_empty() and not parts[1].is_empty() and parts[0] != parts[1], "%s rank %d preview expresses a real change" % [key, rank])
		check(catalog.describe_change(key, 3) == "MAX RANK", "Rank-three preview is capped: " + key)
		check(catalog.describe_change(key, 99) == "MAX RANK", "Over-cap preview remains capped: " + key)
		check_number(catalog.value(key, -5), float(EXPECTED_VALUES[key][0]), "Negative rank value clamps: " + key)
		check_number(catalog.value(key, 99), float(EXPECTED_VALUES[key][3]), "Over-cap value clamps: " + key)
	check(exclusive_count == 3, "Exactly three resources are tagged BOW EXCLUSIVE")
	check(catalog.describe_change("spread_arrow", 0) == "1 arrows per burst -> 3 arrows per burst", "Fan preview preserves actual total arrow counts")
	check(catalog.describe_change("pierce", 1) == "2 hits / 75% retained -> 3 hits / 85% retained", "Pierce preview preserves hit count and retention")
	check(catalog.describe_change("not_an_upgrade", 0).is_empty(), "Unknown upgrade has no misleading preview")
	check_number(catalog.value("not_an_upgrade", 3), 0.0, "Unknown upgrade has no stat contribution")
	for key: String in ["split", "knockback", "long_draw", "poison_crit"]:
		if not catalog.definitions.has(key):
			continue
		for rank in range(3):
			var parts := catalog.describe_change(key, rank).split(" -> ")
			if parts.size() != 2:
				continue
			for offset in range(2):
				var percent := int(round(float(EXPECTED_VALUES[key][rank + offset]) * 100.0))
				if key == "split" and rank + offset == 0:
					check(parts[offset] == "no fragments", "Split preview distinguishes no fragments before rank one")
				elif key == "poison_crit":
					check(("+%d pp" % percent) in parts[offset] and "poisoned" in parts[offset], "Toxic Precision preview shows additive %d percentage points against poisoned targets" % percent)
				else:
					check(str(percent) in parts[offset] and "%" in parts[offset], "%s preview side %d shows numeric %d percent at rank %d" % [key, offset, percent, rank])

func check_eligibility() -> void:
	var base := catalog.eligible({})
	check(base.size() == 17, "Fresh bow run has 17 eligible upgrades and excludes three combos")
	for key: String in EXPECTED_VALUES:
		check(base.has(key) == not PREREQUISITES.has(key), "Fresh-run prerequisite eligibility: " + key)
	for key: String in PREREQUISITES:
		var prereq: String = PREREQUISITES[key]
		var ranks: Dictionary = {prereq: 1}
		check(catalog.eligible(ranks).has(key), "Owned prerequisite unlocks " + key)
		for rank in range(1, 3):
			ranks[key] = rank
			check(catalog.eligible(ranks).has(key), "%s remains eligible after rank %d" % [key, rank])
		ranks[key] = 3
		check(not catalog.eligible(ranks).has(key), "Maxed combo excluded: " + key)
	check(catalog.eligible(ranks_at(3)).is_empty(), "No maxed upgrade offered when all 20 are rank three")
	check(catalog.eligible(ranks_at(99)).is_empty(), "No over-cap upgrade is offered")
	for key: String in EXPECTED_VALUES:
		var isolated := ranks_at(3)
		isolated[key] = 2
		var eligible := catalog.eligible(isolated)
		check(eligible.size() == 1 and eligible[0] == key, "Each rank-two upgrade independently remains eligible: " + key)

func check_stats() -> void:
	var cat := load("res://resources/cat.tres") as CharacterDefinition
	check(cat != null and cat.bow != null, "Real character and bow resources load")
	if cat == null or cat.bow == null:
		return
	var stats := cat.create_stats()
	var baseline := snapshot(stats)
	stats.hp = 43.0
	for rank in range(1, 4):
		var requested := ranks_at(rank)
		stats.apply_ranks(requested)
		check_number(stats.hp, 43.0, "Recompute does not heal current HP at rank " + str(rank))
		check(stats.shields == 0, "Recompute does not refill shields at rank " + str(rank))
		check_number(stats.arrow_range, cat.bow.projectile_range * (1.0 + 0.10 * rank), "Long Draw range at rank " + str(rank))
		check_number(stats.arrow_speed, cat.bow.projectile_speed * (1.0 + 0.10 * rank), "Long Draw speed at rank " + str(rank))
		check_number(stats.knockback, cat.bow.knockback * (1.0 + 0.25 * rank), "Knockback scales immutable bow baseline at rank " + str(rank))
		if stats.get("split_damage") != null:
			check_number(float(stats.get("split_damage")), float(EXPECTED_VALUES.split[rank]), "Split child damage ratio at rank " + str(rank))
		check_number(stats.poison_crit, float(EXPECTED_VALUES.poison_crit[rank]), "Toxic Precision bonus at rank " + str(rank))
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
		"max_hp": 160.0, "shield_capacity": 3, "damage_percent": 60.0,
		"attack_speed": 1.45, "crit_chance": 0.29, "crit_multiplier": 3.2,
		"move_speed": 312.8, "pickup_radius": 210.0, "regen": 1.5,
		"poison_dps": 9.0, "bleed_dps": 12.0, "poison_crit": 1.0,
		"spread_radius": 110.0, "pierce_max_hits": 4, "pierce_retention": 0.95,
		"burst_count": 4, "spread_arrow_count": 7, "bleed_regen": 1.5,
		"bleed_regen_buff": 1.5, "split_damage": 0.6,
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

func check_poison_critical_chance() -> void:
	var stats := CombatStats.new()
	var poisoned := StatusEffects.new()
	poisoned.apply_poison(3.0, 4.0)
	for rank in range(1, 4):
		stats.apply_ranks({"poison": 1, "poison_crit": rank})
		var fresh := StatusEffects.new()
		check(not CombatRules.resolve_direct(stats, fresh, 10.0, 0.06).crit, "Toxic Precision rank %d cannot benefit the same hit that first poisons" % rank)
		check(not fresh.has_poison(), "Direct resolver stays pure at Toxic Precision rank " + str(rank))
		var chance := minf(1.0, 0.05 + float(EXPECTED_VALUES.poison_crit[rank]))
		check(CombatRules.resolve_direct(stats, poisoned, 10.0, chance - 0.001).crit, "Poison bonus adds percentage points at rank " + str(rank))
		if rank < 3:
			check(not CombatRules.resolve_direct(stats, poisoned, 10.0, chance + 0.001).crit, "Poison bonus is not prematurely guaranteed at rank " + str(rank))
		else:
			check(CombatRules.resolve_direct(stats, poisoned, 10.0, 0.999999).crit, "Rank-three Toxic Precision guarantees pre-poisoned critical hits")
	stats.apply_ranks({"poison_crit": 1, "crit_chance": 3, "shield": 2})
	stats.shields = 2
	check(CombatRules.resolve_direct(stats, poisoned, 10.0, 0.839).crit, "Poison bonus adds to ordinary critical chance and current shields")
	check(not CombatRules.resolve_direct(stats, poisoned, 10.0, 0.841).crit, "Combined critical chance is 84 percent rather than guaranteed")

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
	if game.current_mode == "upgrade":
		game.resume_run()
	game.arena.apply_ranks(ranks)
	game.arena.stats.hp = game.arena.stats.max_hp
	game.arena.stats.shields = game.arena.stats.shield_capacity
	game.show_upgrades()

func check_offer(game: Node, expected_count: int, label: String) -> Array[Button]:
	check(game.current_mode == "upgrade" and paused, label + ": actual upgrade screen pauses simulation")
	var cards := find_buttons(game.overlay)
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
		var rank := int(game.arena.ranks.get(key, 0))
		check(rank < 3, label + ": excludes maxed " + key)
		if PREREQUISITES.has(key):
			check(int(game.arena.ranks.get(PREREQUISITES[key], 0)) > 0, label + ": prerequisite satisfied for " + key)
		check("[%d/3]" % (rank + 1) in card.text, label + ": rank-three cap shown on " + key)
		check(catalog.describe_change(key, rank) in card.text, label + ": current-to-next numbers displayed on " + key)
		check(str(catalog.definitions[key].tag) in card.text, label + ": visible category tag on " + key)
		check(("BOW EXCLUSIVE" in card.text) == BOW_EXCLUSIVES.has(key), label + ": exclusive label scoped correctly on " + key)
	return cards

func check_main_ui() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	var start: Button = null
	for item: Button in find_buttons(game.ui):
		if item.text == "START ENDLESS":
			start = item
	check(start != null, "Real main menu contains START ENDLESS")
	if start == null:
		game.queue_free()
		await process_frame
		return
	start.pressed.emit()
	check(game.current_mode == "endless" and game.arena != null, "Real start button enters bow-only endless run")
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.arena.bow.enabled = false
	# Fixed seeds exercise the actual shuffle without random pass/fail behavior.
	for iteration in range(24):
		seed(1200 + iteration)
		var ranks: Dictionary = {} if iteration < 12 else {"damage": 3, "shield": 3, "split": 3}
		prepare_upgrade(game, ranks)
		check_offer(game, 3, "Seeded offer " + str(iteration))
		game.resume_run()
		await process_frame
	# Force exactly three legitimate candidates, then press every upgrade's actual
	# card once at each rank. This exercises callback binding, stat recomputation,
	# exclusivity display, all three rank transitions, and safe overlay teardown.
	for key: String in EXPECTED_VALUES:
		if not catalog.definitions.has(key):
			continue
		for rank in range(3):
			var ranks := ranks_at(3)
			ranks[key] = rank
			var fillers := 0
			for filler: String in ["vitality", "damage", "attack_speed"]:
				if filler != key and fillers < 2:
					ranks[filler] = 0
					fillers += 1
			prepare_upgrade(game, ranks)
			var cards := check_offer(game, 3, "%s real card rank %d" % [key, rank])
			var selected: Button = null
			for card: Button in cards:
				if key_for_card(card) == key:
					selected = card
			check(selected != null, "Required actual card exists: %s rank %d" % [key, rank])
			if selected == null:
				game.resume_run()
				await process_frame
				continue
			selected.pressed.emit()
			check(int(game.arena.ranks.get(key, 0)) == rank + 1, "Pressed actual card increments correct upgrade: %s rank %d" % [key, rank])
			for other: String in EXPECTED_VALUES:
				if other != key:
					check(int(game.arena.ranks.get(other, 0)) == int(ranks[other]), "Card %s leaves %s unchanged" % [key, other])
			check(game.current_mode == "endless" and not paused and game.overlay == null, "Pressed card safely resumes endless and retires overlay: " + key)
			var expected := (load("res://resources/cat.tres") as CharacterDefinition).create_stats()
			var after := ranks.duplicate()
			after[key] = rank + 1
			expected.apply_ranks(after)
			compare_snapshot(game.arena.stats, snapshot(expected), "Actual selected upgrade recomputes build: " + key)
			if key == "shield":
				check(game.arena.stats.shields == rank + 1, "Real shield card refills new capacity")
			await process_frame
	prepare_upgrade(game, ranks_at(3))
	var final_buttons := find_buttons(game.overlay)
	check(final_buttons.size() == 1 and final_buttons[0].text == "KEEP FIGHTING", "Mastered healthy build offers only KEEP FIGHTING, never an unrelated weapon")
	if final_buttons.size() == 1 and final_buttons[0].text == "KEEP FIGHTING":
		final_buttons[0].pressed.emit()
		check(game.current_mode == "endless" and not paused, "Mastered-build continue button resumes endless")
		check(game.arena.ranks == ranks_at(3), "Continue does not create or over-rank an upgrade")
	game.queue_free()
	paused = false
	await process_frame

func run() -> void:
	catalog = UpgradeCatalog.new()
	check_catalog_resources()
	check_eligibility()
	check_stats()
	check_poison_critical_chance()
	await check_main_ui()
	print("UPGRADE CATALOG: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
