extends SceneTree
## Independent localization, resource provenance, glyph and actual-layout contracts.
## Run under an isolated HOME/XDG_DATA_HOME; no user's settings are touched.
var checks := 0
var failures := 0
var translations: Dictionary = {}
var keys: Array = []

func _initialize() -> void:
	if "--verify-locale-fixture" in OS.get_cmdline_user_args():
		var saved := DisplaySettings.new()
		saved.load_settings()
		var valid := saved.language == "zh_CN" and not saved.sound_enabled and not saved.show_enemy_health and saved.resolved_language("en_US") == "zh_CN"
		print("INDEPENDENT SECOND PROCESS PREFERENCES: ", valid)
		quit(0 if valid else 1)
	else: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle(frames: int = 8) -> void:
	for i in range(frames): await process_frame
func tokens(value: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("%%|%[-+0-9.]*[sdf]|\\{[A-Za-z_]+\\}")
	var result: Array[String] = []
	for found in regex.search_all(value):
		if found.get_string() != "%%": result.append(found.get_string())
	return result
func no_raw(value: String, where: String) -> void:
	for key in keys:
		if value.contains(str(key)):
			check(false, where + " exposes raw key " + str(key))
	check(not value.contains("{percent_values}") and not value.contains("{values}"), where + " resolves resource tokens")

func translation_contracts() -> void:
	for locale in ["en", "zh_CN"]:
		var source := load("res://resources/localization/" + locale + ".po") as Translation
		check(source != null, locale + " loads production translation")
		translations[locale] = source
	var en: Translation = translations.en
	var zh: Translation = translations.zh_CN
	keys = Array(en.get_message_list())
	check(keys.size() >= 150, "systematic catalog, not four isolated labels")
	check(keys.size() == zh.get_message_count(), "translation key count parity")
	var font := load("res://resources/fonts/ragecat-ui-subset.otf") as FontFile
	font.allow_system_fallback = false
	var seen := {}
	for key in keys:
		var english := String(en.get_message(key))
		var chinese := String(zh.get_message(key))
		check(not english.is_empty() and not chinese.is_empty(), str(key) + " nonempty in both locales")
		check(tokens(english) == tokens(chinese), str(key) + " identical ordered formatting tokens")
		for text_value in [english, chinese]:
			for character in text_value:
				var cp: int = character.unicode_at(0)
				if cp <= 32 or seen.has(cp): continue
				seen[cp] = true
				check(font.has_char(cp), "bundled font has U+%04X %s without system fallback" % [cp, character])
	for locale in ["en", "zh_CN"]:
		TranslationServer.set_locale(locale)
		var catalog := UpgradeCatalog.new()
		catalog.all_unlocked = true # Full-catalog combat fixture; progression is tested separately.
		for id in catalog.resources:
			var definition: UpgradeDefinition = catalog.definition(id)
			no_raw(definition.display_name + definition.description + definition.tag, locale + ":" + id)
			for rank in range(1, catalog.max_rank(id) + 1):
				no_raw(catalog.describe_rank(id, rank), locale + ":" + id + ":" + str(rank))
				for element in ["fire", "lightning", "ice", "dark"]:
					no_raw(catalog.describe_build_rank(id, rank, {"element_type": element, "enchant_rank": 3, "element_skill_rank": 3}), locale + " build " + id)
		var names := ["Blazing Arrow", "Lightning Arrow", "Frost Arrow", "Shadow Arrow"] if locale == "en" else ["爆燃箭", "闪电箭", "寒冰箭", "暗影箭"]
		var ids := ["fire_bow", "lightning_bow", "ice_bow", "dark_bow"]
		for i in range(4): check(catalog.definition(ids[i]).display_name == names[i], locale + " exact " + ids[i])
		# Mutate only the catalog's independent resource copy: text must follow balance data.
		catalog.definition("damage_flat").values[3] = 123.25
		check(catalog.describe_rank("damage_flat", 3).contains("123.25"), locale + " rank text derives from resource values")
		var fire := catalog.definition("fire_bow").element_skill
		fire.burn_duration = 7.25
		fire.damage_by_rank[3] = 0.7775
		check(catalog.describe_rank("fire_bow", 3).contains("7.25") and catalog.describe_rank("fire_bow", 3).contains("77.75"), locale + " skill duration and coefficient derive from resource")
	TranslationServer.set_locale("en")
	check(GameLocale.text("DESC_FIRE").contains("fragments") and GameLocale.text("DESC_FIRE").contains("first-hit blast"), "fire text includes fragment explosions")
	check((GameLocale.text("DESC_LIGHTNING").contains("Every direct hit") or GameLocale.text("DESC_LIGHTNING").contains("Each direct hit")) and GameLocale.text("DESC_LIGHTNING").contains("fragment"), "lightning text includes every direct hit and fragments")
	check(GameLocale.text("DESC_ICE").contains("All direct arrows"), "ice text includes all direct arrows")
	check(GameLocale.text("DESC_DARK").contains("Unlimited") and GameLocale.text("DESC_PIERCE_DARK").contains("Inactive"), "dark unlimited hits and inactive pierce")
	for pair in [["STATUS_BURN", "Burn"], ["STATUS_SHOCK", "Shock"], ["STATUS_FROSTBITE", "Frostbite"], ["STATUS_GRAVITY", "Gravity"]]:
		check(GameLocale.text(pair[0]) == pair[1], "exact English passive " + pair[0])

func settings_contracts() -> void:
	var path := "user://independent-locale-settings.cfg"
	DirAccess.remove_absolute(path)
	var settings := DisplaySettings.new()
	settings.load_settings(path)
	for locale in ["zh", "zh-CN", "zh_TW", "zh_HK", "ZH-hans-CN"]:
		check(settings.resolved_language(locale) == "zh_CN", "system Chinese variant " + locale)
	for locale in ["en_US", "fr_FR", "ja_JP", "", "de-DE"]:
		check(settings.resolved_language(locale) == "en", "unsupported system fallback " + locale)
	var config := ConfigFile.new()
	config.set_value("future", "keep", "sentinel")
	config.save(path)
	settings.language = "zh_CN"
	settings.sound_enabled = false
	settings.show_enemy_health = false
	check(settings.save_settings(path) == OK, "save combined preferences")
	var reloaded := DisplaySettings.new()
	reloaded.load_settings(path)
	check(reloaded.language == "zh_CN" and not reloaded.sound_enabled and not reloaded.show_enemy_health, "locale sound HP survive reload together")
	check(reloaded.resolved_language("en_US") == "zh_CN", "explicit preference overrides system")
	config.load(path)
	check(config.get_value("future", "keep") == "sentinel", "save merges unrelated configuration")
	config.set_value("display", "language", "unsupported")
	config.save(path)
	reloaded.load_settings(path)
	check(reloaded.resolved_language("fr_FR") == "en", "unsupported saved language safely falls back")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("invalid config [")
	file.close()
	reloaded.load_settings(path)
	check(reloaded.resolved_language("en_US") == "en", "corrupt saved config safely falls back")
	DirAccess.remove_absolute(path)

func fit_contracts() -> void:
	var holder := Control.new()
	root.add_child(holder)
	var label := Label.new()
	label.size = Vector2(240, 50)
	holder.add_child(label)
	TextFit.attach(label, 24, 14, 55)
	label.text = "Long English localization text with full details and no lost mechanics. ".repeat(8)
	TextFit.refit(label)
	await settle()
	check(label.get_theme_font_size("font_size") >= 14, "synthetic body obeys readable floor")
	check(label.get_theme_font_size("font_size") < 24, "long text invokes bounded dynamic shrink")
	var measured := label.get_theme_font("font").get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, label.size.x, label.get_theme_font_size("font_size"))
	check(label.size.y + 1 >= measured.y, "body grows actual rectangle to full measured text")
	var font_size := label.get_theme_font_size("font_size")
	var height := label.size.y
	await settle(20)
	check(label.get_theme_font_size("font_size") == font_size and is_equal_approx(label.size.y, height), "deferred resize converges without infinite feedback")
	label.text = "Short"
	label.size.x = 480
	TextFit.refit(label)
	await settle()
	check(label.get_theme_font_size("font_size") == 24, "font recovers after shorter text and wider width")
	var button := Button.new()
	button.size = Vector2(240, 48)
	button.text = "A very long translated action button ".repeat(8)
	holder.add_child(button)
	TextFit.attach(button, 22, 16, 60)
	await settle()
	check(button.get_theme_font_size("font_size") >= 16, "synthetic action obeys readable floor")
	check(button.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING, "important action text never silently truncates")
	label.text = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".repeat(15)
	label.size.x = 90
	TextFit.refit(label)
	await settle()
	var native_height := label.get_line_count() * label.get_line_height()
	check(label.size.y + 2 >= native_height, "unbroken token smart-wrap actual native lines fit full height")
	check(label.get_line_count() > 1, "long unbroken token wraps rather than disappearing")
	label.text = "W".repeat(20)
	label.size.x = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x / 2.0 + 3.0
	var fitter: TextFit = label.get_meta("text_fit")
	fitter.preferred_height = 200
	TextFit.refit(label)
	await settle()
	check(label.get_theme_font_size("font_size") == 24, "smart-wrap two-line unbroken token retains maximum font with ample height")
	for kind in ["check", "option"]:
		var icon_button: Button = CheckButton.new() if kind == "check" else OptionButton.new()
		icon_button.size = Vector2(180, 48)
		icon_button.text = "Longest translated setting label with all essential details ".repeat(3)
		holder.add_child(icon_button)
		TextFit.attach(icon_button, 20, 16, 60)
		await settle()
		var style := icon_button.get_theme_stylebox("normal")
		var icon := icon_button.get_theme_icon("checked" if kind == "check" else "arrow")
		var usable := icon_button.size.x - style.get_minimum_size().x - icon.get_width() - icon_button.get_theme_constant("h_separation")
		var needed := icon_button.get_theme_font("font").get_multiline_string_size(icon_button.text, HORIZONTAL_ALIGNMENT_LEFT, usable, icon_button.get_theme_font_size("font_size"), -1, TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE)
		check(icon_button.size.y + 2 >= needed.y + style.get_minimum_size().y, kind + " button actual height reserves icon and smart-wrap text")
		icon_button.free()
	var float_small := FloatingText.new()
	var float_large := FloatingText.new()
	float_small.setup("1", Color.WHITE)
	float_large.setup("999999.99", Color.WHITE)
	check(float_small.label.get_theme_font_size("font_size") == float_large.label.get_theme_font_size("font_size"), "damage floats never shrink for digit count")
	float_small.free()
	float_large.free()
	holder.free()

func scan_ui(node: Node, context: String) -> void:
	if node is Control: check(node.tooltip_text.is_empty(), context + " has no hover-only help " + str(node.name))
	if node is Label or node is Button:
		var control := node as Control
		var value := str(control.get("text"))
		no_raw(value, context + " " + str(node.name))
		if not value.is_empty() and control.is_visible_in_tree():
			var floor_size := 16 if node is Button else 14
			check(control.get_theme_font_size("font_size") >= floor_size, context + " readable control " + value.left(35))
			check(control.size.x <= 1280, context + " control width within minimum viewport " + value.left(30))
			if node is Label and node.autowrap_mode != TextServer.AUTOWRAP_OFF:
				var font := control.get_theme_font("font")
				var measured := font.get_multiline_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, control.size.x, control.get_theme_font_size("font_size"))
				check(control.size.y + 2 >= measured.y, context + " actual label height includes full text " + value.left(30))
	for child in node.get_children(): scan_ui(child, context)

func runtime_snapshot(game: Node) -> Dictionary:
	var arena: RageArena = game.arena
	return {"arena": arena.get_instance_id(), "player": arena.player.get_instance_id(),
		"hp": arena.stats.hp, "xp": arena.xp, "ranks": arena.ranks.duplicate(true),
		"enemies": arena.enemies.get_children().map(func(n: Node) -> int: return n.get_instance_id()),
		"arrows": arena.arrows.get_children().map(func(n: Node) -> int: return n.get_instance_id()),
		"rng": arena.rng.state, "cooldown": arena.player.dash_cooldown,
		"attack_clock": arena.bow.attack_clock, "paused": paused, "ai": arena.lab_ai,
		"boss_settings": arena.boss_settings.duplicate(true), "scale": game.lab_scale,
		"controls": game.ui.find_children("*", "Control", true, false).map(func(n: Node) -> int: return n.get_instance_id()),
		"offers": game.ui.find_children("*", "Button", true, false).map(func(n: Node) -> String: return str(n.get_meta("upgrade_key", "")))}

func production_ui_contracts() -> void:
	# Isolated fixture persisted before main enters its ready handler, so no audio
	# settings or simulation settings are changed merely to silence assertions.
	var fixture := DisplaySettings.new()
	fixture.language = "en"
	fixture.sound_enabled = false
	fixture.show_enemy_health = false
	fixture.save_settings()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	for locale in ["en", "zh_CN"]:
		game.set_language(locale)
		await settle()
		scan_ui(game.ui, locale + " actual main menu")
	await menu_navigation_contracts(game)
	check(not ProjectSettings.get_setting("display/window/size/resizable", true) and root.min_size == Vector2i(64, 64), "fixed preset window permits small-screen fallback")
	var source: Translation = translations.zh_CN
	var original_intro := source.get_message("MENU_INTRO")
	var synthetic_intro := "这是完整保留的长文本。".repeat(120)
	source.add_message("MENU_INTRO", synthetic_intro)
	game.refresh_language()
	await settle()
	var long_found := false
	for control in game.ui.find_children("*", "Label", true, false):
		if control.get_meta("translation_key", "") == "MENU_INTRO":
			long_found = control.text == synthetic_intro
			check(control.get_theme_font_size("font_size") >= 14, "synthetic translated menu body retains readable floor")
	check(long_found, "synthetic translation refresh preserves entire long text")
	source.add_message("MENU_INTRO", original_intro)
	game.refresh_language()
	game.start_run(true)
	var arena: RageArena = game.arena
	arena.process_mode = Node.PROCESS_MODE_DISABLED
	arena.apply_ranks({"element_type": "ice", "enchant_rank": 3, "element_skill_rank": 3, "burst": 3, "split": 3, "pierce": 3})
	game.lab.set_ranks(arena.ranks)
	arena.stats.hp -= 3
	arena.xp = 17
	arena.player.dash_cooldown = 1.25
	arena.bow.attack_clock = 0.23
	arena.spawn_enemy("dummy")
	var arrow := BowArrow.new()
	arena.arrows.add_child(arrow)
	game.practice_option("enemy_ai", false)
	game.practice_option("boss_speed", 123.0)
	await settle()
	for locale in ["en", "zh_CN"]:
		var before := runtime_snapshot(game)
		var lab_id: int = game.lab.get_instance_id()
		game.set_language(locale)
		await settle()
		check(runtime_snapshot(game) == before, locale + " language switch preserves live gameplay and RNG")
		check(game.lab.get_instance_id() == lab_id, locale + " practice panel not rebuilt")
		scan_ui(game.ui, locale + " actual practice HUD and controls")
		for id in game.lab._rank_controls:
			var spin: SpinBox = game.lab._rank_controls[id]
			check(spin.tooltip_text.is_empty(), locale + " practice rank has no hover help " + id)
	for element in ["fire", "lightning", "ice", "dark"]:
		for locale in ["en", "zh_CN"]:
			game.set_language(locale)
			var popup := arena._damage_popup(12345.67, "element", element, true, Vector2(400, 400))
			check(popup.label.text.contains(GameLocale.text("POPUP_" + element.to_upper())), locale + " damage popup element prefix " + element)
			check(popup.label.text == GameLocale.text("FEEDBACK_CRIT", [GameLocale.text("POPUP_" + element.to_upper()) + " 12345.67"]), locale + " critical popup translation " + element)
			popup.free()
	await rank_adjustment_focus_contracts(game)
	await full_detail_popup_contracts(game)
	game.show_pause()
	await settle()
	for locale in ["en", "zh_CN"]:
		var before := runtime_snapshot(game)
		var overlay_id: int = game.overlay.get_instance_id()
		# Emit a real language button signal; it must survive its own callback.
		var found := false
		for control in game.ui.find_children("*", "Button", true, false):
			if control.get_meta("language_choice", "") == locale:
				control.pressed.emit()
				found = true
				check(is_instance_valid(control) and not control.is_queued_for_deletion(), "language button lives through pressed callback")
				break
		check(found, "production language action exists in pause")
		await settle()
		check(game.overlay.get_instance_id() == overlay_id, "pause overlay not rebuilt on locale switch")
		check(runtime_snapshot(game) == before, "paused gameplay state remains exactly unchanged")
		scan_ui(game.overlay, locale + " actual pause")
	var settings := DisplaySettings.new()
	settings.load_settings()
	check(settings.language == "zh_CN" and not settings.sound_enabled and not settings.show_enemy_health, "actual UI save retains sound and HP preferences")
	game.resume_run()
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	game.show_upgrades()
	await settle()
	for locale in ["en", "zh_CN"]:
		var before := runtime_snapshot(game)
		var ids_before: Array = game.overlay.get_children().map(func(n: Node) -> int: return n.get_instance_id())
		game.set_language(locale)
		await settle()
		check(runtime_snapshot(game) == before, "upgrade translation does not reroll RNG or mutate state")
		check(ids_before == game.overlay.get_children().map(func(n: Node) -> int: return n.get_instance_id()), "upgrade UI retained")
		scan_ui(game.overlay, locale + " actual upgrade cards")
	await picker_confirm_contracts(game)
	# Render all maximum skill cards through the production button factory, not
	# merely the random three initially offered by the picker.
	var card_holder := VBoxContainer.new()
	card_holder.size = Vector2(800, 700)
	root.add_child(card_holder)
	for locale in ["en", "zh_CN"]:
		game.set_language(locale)
		for element in ["fire", "lightning", "ice", "dark"]:
			game.arena.apply_ranks({"element_type": element, "enchant_rank": 3, "element_skill_rank": 2})
			var card: Button = game.button(game.upgrade_card_text(element + "_bow"), func() -> void: pass)
			card.custom_minimum_size.x = 800
			card_holder.add_child(card)
			await settle()
			check(card.get_theme_font_size("font_size") >= 16, locale + " max skill card font floor " + element)
			var style := card.get_theme_stylebox("normal")
			var measured := card.get_theme_font("font").get_multiline_string_size(card.text, HORIZONTAL_ALIGNMENT_LEFT, card.size.x - style.get_minimum_size().x, card.get_theme_font_size("font_size"))
			check(card.size.y + 2 >= measured.y + style.get_minimum_size().y, locale + " max skill card full text fits actual bounds " + element)
			card.free()
	card_holder.free()
	game.resume_run()
	game.show_death()
	await settle()
	for locale in ["en", "zh_CN"]:
		game.set_language(locale)
		await settle()
		scan_ui(game.overlay, locale + " actual death menu")
	var child_output: Array = []
	var child_status := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "tests/localization_independent_tests.gd", "--", "--verify-locale-fixture"], child_output, true)
	check(child_status == 0 and str(child_output).contains("PREFERENCES: true"), "explicit language and other settings survive a fresh Godot process")
	game.free()
	paused = false
	await settle()

func dispatch_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func dispatch_pad(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func menu_navigation_contracts(game: Node) -> void:
	await settle()
	var initial := root.gui_get_focus_owner()
	check(is_instance_valid(initial), "main menu establishes initial focus without mouse")
	dispatch_key(KEY_DOWN)
	await settle()
	check(root.gui_get_focus_owner() != initial, "keyboard Down moves main-menu focus")
	var keyboard_focus := root.gui_get_focus_owner()
	dispatch_pad(JOY_BUTTON_DPAD_DOWN)
	await settle()
	check(root.gui_get_focus_owner() != keyboard_focus, "D-pad Down moves main-menu focus")
	for target_locale in ["en", "zh_CN"]:
		for control in game.ui.find_children("*", "Button", true, false):
			if control.get_meta("language_choice", "") == target_locale:
				control.grab_focus()
				if target_locale == "en": dispatch_key(KEY_ENTER)
				else: dispatch_pad(JOY_BUTTON_A)
				break
		await settle()
		check(game.display_settings.language == target_locale, "keyboard/gamepad confirmation activates focused language action " + target_locale)
		check(game.current_mode == "menu", "language confirmation does not trigger unrelated menu action")

func picker_confirm_contracts(game: Node) -> void:
	for controller in [false, true]:
		game.start_run(false)
		game.catalog.all_unlocked = true # Full-catalog UI fixture.
		game.arena.process_mode = Node.PROCESS_MODE_DISABLED
		game.show_upgrades()
		await settle()
		var cards: Array[Button] = []
		for control in game.overlay.find_children("*", "Button", true, false):
			if control.has_meta("upgrade_key"): cards.append(control)
		check(cards.size() == 3, "controller picker has three selectable upgrades")
		if cards.size() < 2: continue
		cards[0].grab_focus()
		if controller: dispatch_pad(JOY_BUTTON_DPAD_DOWN)
		else: dispatch_key(KEY_DOWN)
		await settle()
		check(cards[1].has_focus(), "keyboard/gamepad direction moves to next real upgrade card")
		var key: String = cards[1].get_meta("upgrade_key")
		var expected: Dictionary = game.catalog.apply_choice(game.arena.ranks, key)
		if controller: dispatch_pad(JOY_BUTTON_A)
		else: dispatch_key(KEY_ENTER)
		await settle()
		check(game.current_mode == "campaign" and game.overlay == null, "keyboard/gamepad confirm selects card once and resumes")
		check(game.arena.ranks == expected, "focused card confirmation applies exactly requested upgrade")

func detail_gameplay_snapshot(game: Node) -> Dictionary:
	var result := runtime_snapshot(game)
	result.erase("controls")
	result.erase("offers")
	result["mode"] = game.current_mode
	result["lab_ranks"] = game.lab._ranks.duplicate(true)
	return result

func rank_adjustment_focus_contracts(game: Node) -> void:
	game.arena.apply_ranks({"element_type": "ice", "enchant_rank": 3, "element_skill_rank": 1})
	game.lab.set_ranks(game.arena.ranks)
	game.enter_practice_navigation()
	await settle()
	var rank_control: SpinBox = game.lab._rank_controls["ice_bow"]
	var row := rank_control.get_parent()
	var source_label := row.get_child(0) as Label
	for step in [[KEY_RIGHT, 2], [KEY_RIGHT, 3], [KEY_RIGHT, 3], [KEY_LEFT, 2], [KEY_LEFT, 1], [KEY_LEFT, 0], [KEY_LEFT, 0]]:
		source_label.grab_focus()
		dispatch_key(step[0])
		await settle()
		var focused := root.gui_get_focus_owner()
		print("INDEPENDENT RANK FOCUS: expected=", step[1], " owner=", str(focused.get_path()) if is_instance_valid(focused) else "NONE")
		check(int(game.arena.ranks.get("element_skill_rank", 0)) == step[1], "Left/Right rank adjustment respects requested value and bounds " + str(step))
		check(is_instance_valid(focused) and (focused == source_label or row.is_ancestor_of(focused)), "rank adjustment keeps focus on same item including min/max boundary")
		dispatch_key(KEY_ENTER)
		await settle()
		check(is_instance_valid(game.lab._details_popup) and game.lab._details_key == "ice_bow", "Confirm immediately after rank adjustment opens same upgrade details")
		game.lab._close_upgrade_details()
		await settle()
	var focused_before := root.gui_get_focus_owner()
	dispatch_key(KEY_DOWN)
	await settle()
	check(is_instance_valid(root.gui_get_focus_owner()) and root.gui_get_focus_owner() != focused_before, "Down remains navigable after rank boundary adjustments")
	dispatch_key(KEY_UP)
	await settle()
	check(is_instance_valid(root.gui_get_focus_owner()), "Up retains usable focus after rank adjustment")
	game.return_from_practice_navigation()
	await settle()

func full_detail_popup_contracts(game: Node) -> void:
	var lab: PracticePanel = game.lab
	game.arena.apply_ranks({"element_type": "ice", "enchant_rank": 3, "element_skill_rank": 3})
	lab.set_ranks(game.arena.ranks)
	game.enter_practice_navigation()
	await settle()
	var source_label := lab._rank_controls["ice_bow"].get_parent().get_child(0) as Label
	var signal_counts := {"ranks": 0, "command": 0, "option": 0}
	lab.ranks_changed.connect(func(_value: Dictionary) -> void: signal_counts.ranks += 1)
	lab.command.connect(func(_value: String) -> void: signal_counts.command += 1)
	lab.option_changed.connect(func(_key: String, _value: Variant) -> void: signal_counts.option += 1)
	var original_messages := {}
	for locale in ["en", "zh_CN"]:
		var translation: Translation = translations[locale]
		original_messages[locale] = translation.get_message("DESC_ICE")
		translation.add_message("DESC_ICE", String(original_messages[locale]) + "\n" + "Full mechanics detail remains available. ".repeat(160) + "\nEND_DETAIL_SENTINEL")
	for locale in ["en", "zh_CN"]:
		game.set_language(locale)
		await settle()
		var before := detail_gameplay_snapshot(game)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		source_label.grab_focus()
		check(source_label.has_focus(), locale + " upgrade detail source keyboard focus")
		var confirm: InputEvent = InputEventKey.new() if locale == "en" else InputEventJoypadButton.new()
		if confirm is InputEventKey:
			confirm.keycode = KEY_ENTER
			confirm.physical_keycode = KEY_ENTER
		else: confirm.button_index = JOY_BUTTON_A
		confirm.pressed = true
		check(confirm.is_action_pressed("ui_accept"), locale + " keyboard or gamepad confirm maps to ui_accept")
		root.push_input(confirm, true)
		confirm.pressed = false
		root.push_input(confirm, true)
		await settle()
		var popup: Control = lab._details_popup
		check(is_instance_valid(popup) and popup.visible, locale + " focused keyboard/gamepad confirm opens persistent details")
		if not is_instance_valid(popup): continue
		check(detail_gameplay_snapshot(game) == before, locale + " opening detail does not mutate source action or run")
		check(signal_counts == {"ranks": 0, "command": 0, "option": 0}, "detail click emits no gameplay configuration signals")
		check(popup.size.x <= 1280 and popup.size.y <= 800, locale + " actual detail popup bounded to supported canvas")
		var scroll := popup.find_child("DescriptionScroll", true, false) as ScrollContainer
		var body: Label = lab._details_body
		check(body.text.ends_with("END_DETAIL_SENTINEL"), locale + " full detail retains final sentinel")
		check(body.get_theme_font_size("font_size") >= 14 and lab._details_title.get_theme_font_size("font_size") >= 16, locale + " detail body and heading retain readable floors")
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y, locale + " actual detail contains working scroll range")
		var down: InputEvent = InputEventKey.new() if locale == "en" else InputEventJoypadButton.new()
		if down is InputEventKey:
			down.keycode = KEY_DOWN
			down.physical_keycode = KEY_DOWN
		else: down.button_index = JOY_BUTTON_DPAD_DOWN
		down.pressed = true
		root.push_input(down, true)
		down.pressed = false
		root.push_input(down, true)
		await settle()
		check(scroll.scroll_vertical > 0, locale + " keyboard/D-pad semantic input scrolls full details")
		check(detail_gameplay_snapshot(game) == before, "detail direction does not alter underlying rank or game")
		var scroll_before := scroll.scroll_vertical
		for tick in range(100): lab._scroll_details_by(0.1)
		check(absi(scroll.scroll_vertical - scroll_before - 10) <= 1, "high-FPS fractional analog motion accumulates into visible scroll")
		scroll.scroll_vertical += 111
		scroll_before = scroll.scroll_vertical
		for tick in range(100): lab._scroll_details_by(0.1)
		check(absi(scroll.scroll_vertical - scroll_before - 10) <= 1, "fractional analog scrolling remains relative after mouse/integer jump")
		scroll.scroll_vertical = int(ceilf(scroll.get_v_scroll_bar().max_value))
		await settle()
		check(scroll.scroll_vertical > 0, locale + " detail scrollbar actually advances")
		check(body.get_global_rect().end.y <= scroll.get_global_rect().end.y + 2, locale + " final sentinel lies within viewport at scroll end")
		check(body.get_global_rect().end.y >= scroll.get_global_rect().position.y, locale + " final sentinel is not scrolled past viewport")
		var popup_id := popup.get_instance_id()
		var body_id := body.get_instance_id()
		var target_locale := "zh_CN" if locale == "en" else "en"
		game.set_language(target_locale)
		await settle()
		check(lab._details_popup.get_instance_id() == popup_id and lab._details_body.get_instance_id() == body_id, "open detail locale refresh retains popup and body identity")
		check(lab._details_body.text == str(source_label.get_meta("details_text")) and lab._details_title.text == source_label.text, "open detail locale refresh matches actual current source")
		check(detail_gameplay_snapshot(game) == before, "open detail locale refresh preserves run and build")
		var close := popup.find_child("CloseDetails", true, false) as Button
		check(close.get_theme_font_size("font_size") >= 16, "detail Close action readable")
		close.pressed.emit()
		await settle()
		check(not is_instance_valid(lab._details_popup) and not is_instance_valid(popup), "visible Close cleans popup and references")
		check(source_label.has_focus(), "detail Close restores original source focus")
		check(detail_gameplay_snapshot(game) == before, "Close does not pause, resume or mutate practice")
		# Reopen through the same production source action, then dispatch Escape to
		# the actual popup viewport. Native mouse wheel routing is verified by GUI.
		source_label._gui_input(click)
		await settle()
		popup = lab._details_popup
		check(is_instance_valid(popup), "detail cleanly reopens")
		lab._close_upgrade_details()
		lab.show_upgrade_details("ice_bow")
		await settle()
		popup = lab._details_popup
		check(is_instance_valid(popup) and popup.visible, "same-frame close/reopen retains replacement detail")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		await settle()
		check(not is_instance_valid(lab._details_popup), "actual Escape input closes detail")
		check(source_label.has_focus(), "Escape restores original source focus")
		lab.show_upgrade_details("ice_bow")
		await settle()
		var cancel := InputEventJoypadButton.new()
		cancel.button_index = JOY_BUTTON_B
		cancel.pressed = true
		check(cancel.is_action_pressed("ui_cancel"), "gamepad Back maps to cancel")
		root.push_input(cancel, true)
		cancel.pressed = false
		root.push_input(cancel, true)
		await settle()
		check(not is_instance_valid(lab._details_popup) and source_label.has_focus(), "gamepad Back closes details and restores source focus")
		check(detail_gameplay_snapshot(game) == before, "Escape does not also toggle game pause or alter build")
		lab._close_upgrade_details()
	for locale in ["en", "zh_CN"]:
		var translation: Translation = translations[locale]
		translation.add_message("DESC_ICE", original_messages[locale])
	game.refresh_language()
	game.return_from_practice_navigation()
	await settle()

func larger_supported_layout_contracts() -> void:
	# Main registers runtime input actions in _ready; remove the prior fixture's
	# registrations before instantiating a second main scene in this process.
	for action in ["move_left", "move_right", "move_up", "move_down", "dash"]:
		if InputMap.has_action(action): InputMap.erase_action(action)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await settle()
	check(not ProjectSettings.get_setting("display/window/size/resizable", true) and root.min_size == Vector2i(64, 64), "larger fixture begins with adaptive production window policy")
	# The headless DisplayServer reports a 64px screen and clamps size requests.
	# Force only the test window minimum, not production canvas/stretch settings.
	# This validates a larger backing window's layout, not native DPI rendering.
	root.min_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await settle()
	check(root.size == Vector2i(1920, 1080), "larger backing window is actually 1920x1080")
	check(root.content_scale_size == Vector2i(1280, 800), "larger window preserves production logical canvas")
	check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS, "larger window preserves canvas_items stretch")
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP, "larger window preserves aspect ratio")
	check(root.get_visible_rect().size.is_equal_approx(Vector2(1280, 800)), "larger viewport remains 1280x800 logical pixels")
	var stretch := root.get_stretch_transform()
	check(is_equal_approx(stretch.x.x, 1.35) and is_equal_approx(stretch.y.y, 1.35), "1920x1080 scales logical content upward uniformly by1.35")
	for locale in ["en", "zh_CN"]:
		game.set_language(locale)
		await settle()
		check(game.overlay.size.is_equal_approx(Vector2(1280, 800)), locale + " larger actual menu retains logical bounds")
		scan_ui(game.ui, locale + " 1920x1080 actual menu")
	game.start_run(false)
	game.catalog.all_unlocked = true # Full-catalog UI fixture.
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	var normal_bounds: Rect2 = game.arena.bounds
	game.show_upgrades()
	await settle()
	for locale in ["en", "zh_CN"]:
		var before := runtime_snapshot(game)
		game.set_language(locale)
		await settle()
		var cards := 0
		for control in game.overlay.find_children("*", "Button", true, false):
			if control.has_meta("upgrade_key"): cards += 1
		check(cards == 3, locale + " larger production picker has all three real cards")
		check(runtime_snapshot(game) == before, locale + " larger picker locale change preserves offers and game")
		check(game.arena.bounds == normal_bounds, locale + " larger backing window never expands combat arena")
		scan_ui(game.overlay, locale + " 1920x1080 actual three-card picker")
	game.resume_run()
	game.start_run(true)
	game.arena.process_mode = Node.PROCESS_MODE_DISABLED
	var practice_bounds: Rect2 = game.arena.bounds
	game.arena.apply_ranks({"element_type": "ice", "enchant_rank": 3, "element_skill_rank": 3, "burst": 3, "split": 3})
	game.lab.set_ranks(game.arena.ranks)
	for locale in ["en", "zh_CN"]:
		var before := runtime_snapshot(game)
		game.set_language(locale)
		await settle()
		check(runtime_snapshot(game) == before, locale + " larger practice locale change preserves controls and game")
		check(game.arena.bounds == practice_bounds, locale + " larger practice retains fixed arena")
		check(Rect2(Vector2.ZERO, Vector2(1280, 800)).encloses(game.lab.get_global_rect()), locale + " larger practice panel stays inside logical canvas")
		scan_ui(game.ui, locale + " 1920x1080 actual practice max-rank content")
		var sizes: Array = []
		for control in game.ui.find_children("*", "Control", true, false):
			if control is Label or control is Button: sizes.append(control.get_theme_font_size("font_size"))
		await settle(20)
		var stable_sizes: Array = []
		for control in game.ui.find_children("*", "Control", true, false):
			if control is Label or control is Button: stable_sizes.append(control.get_theme_font_size("font_size"))
		check(sizes == stable_sizes, locale + " larger practice fitted fonts converge")
	game.free()
	paused = false
	root.min_size = Vector2i(1280, 800)
	root.size = Vector2i(1280, 800)
	await settle()

func run() -> void:
	root.size = Vector2i(1280, 800)
	translation_contracts()
	settings_contracts()
	await fit_contracts()
	await production_ui_contracts()
	await larger_supported_layout_contracts()
	print("LOCALIZATION INDEPENDENT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
