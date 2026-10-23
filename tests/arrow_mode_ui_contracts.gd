extends SceneTree
## Mode-dependent display and retained upgrade investment, without changing pools.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	var stats := CombatStats.new(preload("res://resources/characters/archer.tres"))
	stats.catalog.all_unlocked = true # Full-catalog combat fixture.
	var panel := PracticePanel.new()
	root.add_child(panel)
	panel.setup(stats.catalog)
	for pierce in range(4):
		for element: String in ["dark", "fire", "lightning", "ice"]:
			for skill in range(4):
				stats.apply_ranks({"element_type": element, "enchant_rank": 3, "element_skill_rank": skill, "pierce": pierce})
				panel.set_ranks(stats.ranks)
				var inactive := skill > 0 and element in ["dark", "fire"]
				check(stats.catalog.rank_for(stats.ranks, "pierce") == pierce, "rank retained on every mode transition")
				check(stats.pierce_max_hits == pierce + 1, "raw finite budget preserved for ordinary mode")
				var label := panel._rank_controls.pierce.get_parent().get_child(0) as Label
				check(("inactive" in label.text) == inactive, "practice visible inactive marker matches mode")
				check(("Inactive" in str(label.get_meta("details_text", ""))) == inactive, "practice detail text matches mode even at rank zero")
				var description := stats.catalog.describe_choice("pierce", stats.ranks)
				check(("Inactive" in description) == inactive, "card description matches mode")
				if pierce < 3: check(stats.catalog.eligible(stats.ranks).has("pierce"), "inactive upgrade retains offer policy")
				if inactive:
					check("rank kept" in description, "inactive card explains retained investment")
					check(("unlimited" if element == "dark" else "none") in stats.effective_pierce_text(), "effective HUD mode")
				else: check(("%d hits" % (pierce + 1)) in stats.effective_pierce_text(), "ordinary HUD restored")
	panel.free()
	var arrow := BowArrow.new()
	arrow.unlimited_direct_hits = true
	arrow.max_hits = 1
	for id in range(1000): arrow.hit_ids[id] = true
	check(arrow.can_hit(1001), "unlimited strategy is not a large finite budget")
	check(not arrow.can_hit(999), "unlimited strategy still deduplicates")
	arrow.ignored_ids[1002] = true
	check(not arrow.can_hit(1002), "unlimited strategy honors ignored IDs")
	arrow.retired = true
	check(not arrow.can_hit(1003), "retired arrows cannot hit")
	arrow.free()
	print("ARROW MODE UI CONTRACTS: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
