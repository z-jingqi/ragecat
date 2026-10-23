extends SceneTree
## All files are isolated from the real player profile, even outside run_all.sh.
var failures := 0
var checks := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile := AchievementProfile.new()
	profile.save_path = "user://achievement_profile_contract_%d.json" % OS.get_process_id()
	var catalog := UpgradeCatalog.new()
	catalog.progression = profile
	check(catalog.eligible({}).size() == profile.definition.starter_upgrades.size(), "Fresh offers match starter pool")
	var covered: Dictionary = {}
	for key in profile.definition.starter_upgrades: covered[key] = true
	for item in profile.definition.achievements:
		check(item.target > 0 and item.metric in profile.metrics, "Every achievement has reachable recognized metric")
		for reward in item.rewards:
			check(catalog.definition(reward) != null and not covered.has(reward), "Each catalog reward belongs to exactly one group")
			covered[reward] = true
	check(covered.size() == catalog.resources.size(), "Every upgrade has an unlock path")
	var notifications: Array[String] = []
	profile.unlocked.connect(func(key: String) -> void: notifications.append(key))
	profile.begin_run(true)
	profile.observe_time(100000.0, 100000.0)
	for index in range(500): profile.record_kill(true)
	profile.end_run()
	check(profile.completed.is_empty() and int(profile.metrics.kills) == 0, "Practice never records events")
	check(not FileAccess.file_exists(profile.save_path), "Practice cannot create a profile")
	profile.begin_run(false)
	for index in range(60): profile.record_kill(false)
	check(profile.is_unlocked("fire_enchant") and profile.is_unlocked("fire_bow"), "Natural kill goals unlock fire and shared mastery")
	check(not profile.is_unlocked("lightning_enchant"), "Mastery does not bypass locked elemental branch")
	check(not catalog.eligible({}).has("dark_bow"), "Unlocked family still requires corresponding enchant")
	var ranks := catalog.apply_choice({}, "fire_enchant")
	ranks = catalog.apply_choice(ranks, "fire_bow")
	check(int(ranks.element_skill_rank) == 1, "Shared mastery grants eligibility, not free ranks")
	for index in range(60): profile.record_kill(false)
	ranks = catalog.apply_choice(ranks, "lightning_enchant")
	check(int(ranks.element_skill_rank) == 1 and ranks.element_type == "lightning", "New branch preserves earned shared skill rank")
	var stats := CombatStats.new()
	stats.catalog.progression = profile
	stats.apply_ranks(ranks)
	check(stats.catalog.progression == profile and stats.element_skill_rank == 1, "Stat rebuild retains profile and effective shared rank")
	profile.observe_time(999999.0, 10.0)
	profile.record_kill(true)
	for index in range(500): profile.record_kill(true)
	profile.end_run()
	var total_notifications := notifications.size()
	check(profile.completed.size() == profile.definition.achievements.size(), "All goals complete through ordinary metrics")
	profile.begin_run(false)
	profile.observe_time(999999.0, 10.0)
	profile.record_kill(true)
	profile.end_run()
	check(notifications.size() == total_notifications, "Completion notifications are idempotent")
	for metric: String in profile.metrics:
		check(int(profile.metrics[metric]) <= profile.definition.metric_cap(metric), "Counters are bounded")
	var loaded := AchievementProfile.new()
	loaded.save_path = profile.save_path
	loaded.load_profile()
	var expected_completed := profile.completed.duplicate()
	var actual_completed := loaded.completed.duplicate()
	expected_completed.sort()
	actual_completed.sort()
	check(actual_completed == expected_completed and loaded.metrics == profile.metrics, "Profile round trip")
	var file := FileAccess.open(profile.save_path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	loaded.load_profile()
	check(not loaded.completed.is_empty(), "Corrupt primary recovers prior valid backup without parser errors")
	file = FileAccess.open(profile.save_path, FileAccess.WRITE)
	file.store_string('{"version":999}')
	file.close()
	loaded.load_profile()
	loaded.begin_run(false)
	for index in range(20): loaded.record_kill(false)
	check(FileAccess.get_file_as_string(profile.save_path) == '{"version":999}', "Newer schema is never overwritten")
	var malformed := ProgressionDefinition.new()
	malformed.save_interval = NAN
	malformed.rows_per_page = 0
	var invalid := AchievementDefinition.new()
	invalid.achievement_id = "bad"
	invalid.metric = "unknown"
	invalid.target = -100
	malformed.achievements.append(invalid)
	profile.definition = malformed
	check(profile.definition.achievements.is_empty() and is_finite(profile.definition.save_interval) and profile.definition.rows_per_page > 0, "Malformed definitions are safely bounded")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile.save_path + suffix): DirAccess.remove_absolute(profile.save_path + suffix)
	print("ACHIEVEMENT PROFILE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
