extends SceneTree
## Stable upgrade IDs, portable glyph coverage, and narrow practice preset labels.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func run() -> void:
	TranslationServer.set_locale("zh_CN")
	var font := load("res://resources/fonts/ragecat-ui-subset.otf") as FontFile
	# Disable installed-system fallback: the shipped asset must contain every glyph.
	font.allow_system_fallback = false
	for glyph in "爆燃箭闪电寒冰暗影火雷附魔灼伤感冻引力冻结":
		check(font.has_char(glyph.unicode_at(0)), "Bundled font covers " + glyph)
	var catalog := UpgradeCatalog.new()
	catalog.all_unlocked = true # Full-catalog combat fixture; progression is tested separately.
	var names := {"fire": "爆燃箭", "lightning": "闪电箭", "ice": "寒冰箭", "dark": "暗影箭"}
	var enchants := {"fire": "火附魔", "lightning": "雷附魔", "ice": "冰附魔", "dark": "暗附魔"}
	for element: String in names:
		check(catalog.definition(element + "_bow").display_name == names[element], "Skill label " + element)
		check(catalog.definition(element + "_enchant").display_name == enchants[element], "Enchant label " + element)
		check(font.get_string_size(names[element], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 96, "Short skill label fits practice row")
	var panel := PracticePanel.new()
	root.add_child(panel)
	panel.setup(catalog)
	for label: String in ["爆燃箭", "闪电箭", "寒冰箭", "暗影箭"]:
		var found := false
		for node in panel.find_children("*", "Button", true, false):
			if node.text == label:
				found = true
				check(node.get_theme_font("font").has_char(label.unicode_at(0)), "Practice theme resolves Chinese glyph")
		check(found, "Practice preset names only the skill: " + label)
		check(font.get_multiline_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, 135, 16).x <= 135, "Preset label wraps inside readable half-width button")
	for key: String in ["fire_bow", "lightning_bow", "ice_bow", "dark_bow"]:
		panel.set_ranks({"element_type": key.trim_suffix("_bow"), "enchant_rank": 3, "element_skill_rank": 3})
		var rank: SpinBox = panel._rank_controls[key]
		var label := rank.get_parent().get_child(0) as Label
		for control in [label, rank]:
			check(control.tooltip_text.is_empty(), "No hover-only help")
			panel.show_upgrade_details(key)
			for frame in range(3): await process_frame
			var body: Label = panel._details_body
			check(body.text == str(control.get_meta("details_text")), "Details preserve complete mechanics")
			check(body.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Details wrap long lines")
			check(body.size.x <= 608, "Details bound their text column")
			var background := panel._details_popup.get_node("DetailsPanel").get_theme_stylebox("panel") as StyleBoxFlat
			check(background.bg_color.a == 1.0, "Details background is fully opaque")
			var box: Control = panel._details_popup.get_node("DetailsPanel")
			check(box.size == Vector2(640, 580), "Details keep bounded logical dimensions")
			check(body.get_theme_font_size("font_size") >= 14, "Details preserve readable font floor")
			check(body.text.length() > 0, "Complete text remains accessible in scroll view")
			panel._close_upgrade_details()
			await process_frame
	panel.free()
	print("CHINESE UI NAMES: %d checks, %d failures" % [checks, failures])
	await preload("res://tests/audio_teardown.gd").drain(self)
	quit(0 if failures == 0 else 1)
