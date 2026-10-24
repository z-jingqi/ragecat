extends SceneTree
## Naming-only migration contracts. Run through run_all.sh for isolated user data.
## Headless font/layout measurements are not a rendered visual playtest.
var checks := 0
var failures := 0
const MOVED_SCRIPT_UIDS := {
	"scripts/characters/archer/archer.gd": "uid://c2ke5srsk5w0u",
	"scripts/bosses/mountainbreaker/mountainbreaker.gd": "uid://dhu00gjgyyua7",
	"scripts/bosses/mountainbreaker/rock_warning.gd": "uid://boqh47wvql1v2",
	"scripts/enemies/spitter/spitter.gd": "uid://jw1vaoimya2f",
	"scripts/enemies/spitter/spitter_definition.gd": "uid://d1s3y38q02801",
	"scripts/projectiles/bow_arrow.gd": "uid://bw5yxb6a4rt6h",
}
const ACTOR_SCENES := {
	"scenes/characters/archer/archer.tscn": "Archer",
	"scenes/bosses/mountainbreaker/mountainbreaker.tscn": "Mountainbreaker",
	"scenes/enemies/hornling/hornling.tscn": "Hornling",
	"scenes/enemies/spitter/spitter.tscn": "Spitter",
	"scenes/projectiles/bow_arrow.tscn": "BowArrow",
}
const ACHIEVEMENT_REWARDS := {
	"first_flame": ["fire_enchant"],
	"fire_mastery": ["fire_bow", "lightning_bow", "ice_bow", "dark_bow"],
	"storm_call": ["lightning_enchant"],
	"steady_bow": ["burst"],
	"cold_front": ["ice_enchant", "regen"],
	"winter_bow": ["spread_arrow"],
	"shadow_front": ["dark_enchant", "shield"],
	"boss_hunter": ["long_draw"],
}

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func settle() -> void:
	for _frame in range(8): await process_frame

func resource_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	check(directory != null, "Resource directory exists: " + path)
	if directory == null: return
	for file in directory.get_files():
		if file.get_extension() in ["tres", "tscn"]:
			check(ResourceLoader.load(path.path_join(file)) != null, "Shipped resource loads: " + path.path_join(file))
	for folder in directory.get_directories(): resource_tree(path.path_join(folder))

func resource_contracts() -> void:
	resource_tree("res://resources")
	resource_tree("res://scenes")
	for path: String in MOVED_SCRIPT_UIDS:
		var expected: String = MOVED_SCRIPT_UIDS[path]
		check(FileAccess.get_file_as_string("res://" + path + ".uid").strip_edges() == expected, "Moved script retains its original UID: " + path)
		check(ResourceLoader.get_resource_uid("res://" + path) == ResourceUID.text_to_id(expected), "Imported script resolves original UID: " + path)
	for path: String in ACTOR_SCENES:
		var scene := load("res://" + path) as PackedScene
		check(scene != null, "Named scene exists: " + path)
		if scene == null: continue
		var actor := scene.instantiate()
		var script := actor.get_script() as Script
		check(script != null and script.get_global_name() == ACTOR_SCENES[path], "Scene uses semantic actor class: " + path)
		if ACTOR_SCENES[path] in ["Mountainbreaker", "Hornling", "Spitter"]:
			check(actor is EnemyActor, "Named enemy keeps shared EnemyActor behavior: " + path)
		actor.free()
	var implemented := {"bosses/beastcaller/beastcaller": "Beastcaller", "bosses/wildfire/wildfire": "Wildfire", "enemies/swiftfang/swiftfang": "Swiftfang", "enemies/elite_hornling/elite_hornling": "EliteHornling"}
	for path: String in implemented:
		var actor_script := load("res://scripts/" + path + ".gd") as Script
		check(actor_script != null and actor_script.get_global_name() == implemented[path], "Implemented semantic actor class: " + path)
		var scene := load("res://scenes/" + path + ".tscn") as PackedScene
		check(scene != null, "Implemented semantic actor scene: " + path)

func compatibility_contracts() -> void:
	check(ProjectSettings.get_setting("application/config/name") == "Rage Cat", "Naming migration preserves game title and default user-data directory")
	check(not ProjectSettings.get_setting("application/config/use_custom_user_dir", false), "Naming migration does not redirect the existing user-data directory")
	check(DisplaySettings.PATH == "user://display_settings.cfg", "Existing display/audio/language settings filename is preserved")
	var profile := AchievementProfile.new()
	profile.persistence_enabled = false
	check(profile.save_path == "user://achievements.json" and AchievementProfile.VERSION == 1, "Existing achievement filename and schema version are preserved")
	check(profile.metrics.keys() == ["kills", "survival", "bosses"], "Existing achievement metric identifiers are preserved")
	check(profile.definition.achievements.size() == ACHIEVEMENT_REWARDS.size(), "Naming migration adds no gameplay achievements")
	for key: String in ACHIEVEMENT_REWARDS:
		var item := profile.achievement(key)
		check(item != null, "Existing achievement identifier resolves: " + key)
		if item != null:
			check(Array(item.rewards) == ACHIEVEMENT_REWARDS[key], "Existing achievement rewards stay compatible: " + key)
	var starter_ids := ["vitality", "damage", "damage_flat", "attack_speed", "move_speed", "pickup_radius", "crit_chance", "crit_damage", "knockback", "pierce"]
	check(Array(profile.definition.starter_upgrades) == starter_ids, "Existing starter upgrade identifiers are preserved")
	var character := load("res://resources/characters/archer.tres") as CharacterDefinition
	check(character.id == "archer" and character.display_name_key == "NAME_ARCHER", "Character identity is semantic and its display name uses a translation key")
	check(character.bow.id == "starter_bow" and character.bow.display_name_key == "NAME_BOW", "Existing weapon ID is preserved independently from localized display name")

func named_button(panel: PracticePanel, key: String) -> Button:
	for candidate in panel.find_children("*", "Button", true, false):
		if candidate.get_meta("translation_key", "") == key: return candidate as Button
	return null

func button_fit(button: Button, label: String) -> void:
	var font_size := button.get_theme_font_size("font_size")
	var padding := button.get_theme_stylebox("normal").get_minimum_size()
	var content_width := button.size.x - padding.x
	var measured := button.get_theme_font("font").get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, content_width, font_size, -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
	check(font_size >= TextFit.ACTION_MIN, label + " remains at a readable action font size")
	check(button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, label + " does not silently truncate")
	check(measured.x <= content_width + 1.0 and measured.y + padding.y <= button.size.y + 1.0, label + " full name fits its actual button rectangle")
	var panel_rect: Rect2 = (button.get_parent() as Control).get_global_rect()
	check(button.get_global_rect().position.x >= panel_rect.position.x - 1.0 and button.get_global_rect().end.x <= panel_rect.end.x + 1.0, label + " does not overflow its button grid horizontally")

func live_contracts() -> void:
	root.size = Vector2i(1280, 800)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	game.progression.persistence_enabled = false
	game.progression.save_path = "" # No player profile is read or written by this fixture.
	root.add_child(game)
	game.display_settings.sound_enabled = false
	game.start_run(true)
	game.enter_practice_navigation()
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	await settle()
	check(root.size == Vector2i(1280, 800), "Practice names tested at minimum supported viewport")
	check(game.arena.player is Archer, "Live arena loads Archer through its renamed scene")
	var first := game.arena.spawn_enemy("mob", Vector2(200, 250)) as EnemyActor
	var ranged := game.arena.spawn_enemy("ranged", Vector2(400, 250)) as EnemyActor
	var boss := game.arena.spawn_enemy("boss", Vector2(600, 250)) as EnemyActor
	var dummy := game.arena.spawn_enemy("dummy", Vector2(800, 250)) as EnemyActor
	check(first is Hornling, "Stable mob spawn identifier now instantiates Hornling")
	check(ranged is Spitter, "Stable ranged spawn identifier now instantiates Spitter")
	check(boss is Mountainbreaker, "Stable boss spawn identifier now instantiates Mountainbreaker")
	check(dummy is Hornling and dummy.is_dummy, "Dummy remains a shared-behavior training target")
	var before := [game.arena.player.get_instance_id(), first.get_instance_id(), ranged.get_instance_id(), boss.get_instance_id(), game.arena.stats.hp, game.arena.rng.state]
	var labels := {"NAME_HORNLING": ["Hornling", "土蝼"], "NAME_SPITTER": ["Spitter", "幼蛊雕"], "NAME_MOUNTAINBREAKER": ["Mountainbreaker", "穷奇"]}
	for index in range(2):
		var locale := "en" if index == 0 else "zh_CN"
		TranslationServer.set_locale(locale)
		game.lab.refresh_language()
		await settle()
		check(game.character_definition.display_name == (["Archer", "羿"][index]), locale + " character property returns the canonical localized name")
		check(game.character_definition.bow.display_name == (["Bow", "弓"][index]), locale + " bow property returns the localized name")
		for key: String in labels:
			var button := named_button(game.lab, key)
			check(button != null, locale + " actual practice button uses canonical key " + key)
			if button != null:
				check(button.text == labels[key][index], locale + " actual practice button displays exact name " + key)
				button_fit(button, locale + " " + key)
		check(before == [game.arena.player.get_instance_id(), first.get_instance_id(), ranged.get_instance_id(), boss.get_instance_id(), game.arena.stats.hp, game.arena.rng.state], locale + " name refresh preserves actors, health and combat RNG")
	game.queue_free()
	await settle()
	await create_timer(0.12).timeout # Drain short-lived audio resources before exit.

func run() -> void:
	resource_contracts()
	compatibility_contracts()
	await live_contracts()
	print("ENTITY MIGRATION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
