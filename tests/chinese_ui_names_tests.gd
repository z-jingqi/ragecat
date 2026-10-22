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
	var font := load("res://resources/fonts/ragecat-ui-subset.otf") as FontFile
	# Disable installed-system fallback: the shipped asset must contain every glyph.
	font.allow_system_fallback = false
	for glyph in "爆燃箭闪电寒冰暗影火雷附魔灼伤感冻引力冻结":
		check(font.has_char(glyph.unicode_at(0)), "Bundled font covers " + glyph)
	var catalog := UpgradeCatalog.new()
	var names := {"fire": "爆燃箭", "lightning": "闪电箭", "ice": "寒冰箭", "dark": "暗影箭"}
	var enchants := {"fire": "火附魔", "lightning": "雷附魔", "ice": "冰附魔", "dark": "暗附魔"}
	for element: String in names:
		check(catalog.definition(element + "_bow").display_name == names[element], "Skill label " + element)
		check(catalog.definition(element + "_enchant").display_name == enchants[element], "Enchant label " + element)
		check(font.get_string_size(names[element], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 96, "Short skill label fits practice row")
	var panel := PracticePanel.new()
	root.add_child(panel)
	panel.setup(catalog)
	for label: String in ["爆燃箭 · 灼伤", "闪电箭 · 感电", "寒冰箭 · 冻伤", "暗影箭 · 引力"]:
		var found := false
		for node in panel.find_children("*", "Button", true, false):
			if node.text == label:
				found = true
				check(node.get_theme_font("font").has_char(label.unicode_at(0)), "Practice theme resolves Chinese glyph")
		check(found, "Practice names skill and passive: " + label)
		check(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= 125, "Preset label fits half-width button")
	for key: String in ["fire_bow", "lightning_bow", "ice_bow", "dark_bow"]:
		panel.set_ranks({"element_type": key.trim_suffix("_bow"), "enchant_rank": 3, "element_skill_rank": 3})
		var rank: SpinBox = panel._rank_controls[key]
		var label := rank.get_parent().get_child(0) as Label
		for control in [label, rank]:
			var tooltip := control._make_custom_tooltip(control.tooltip_text) as PanelContainer
			check(tooltip != null, "Upgrade control has measured tooltip panel")
			var body := tooltip.get_child(0) as Label
			check(body.text == control.tooltip_text, "Tooltip preserves complete mechanics")
			check(body.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Tooltip wraps long lines")
			check(body.custom_minimum_size.x == 320, "Tooltip bounds its text column")
			var background := tooltip.get_theme_stylebox("panel") as StyleBoxFlat
			check(background.bg_color.a == 1.0, "Tooltip background is fully opaque")
			# Exercise the popup/container's real first layout, not just constants.
			var popup := PopupPanel.new()
			root.add_child(popup)
			popup.add_child(tooltip)
			popup.size = Vector2i(tooltip.get_combined_minimum_size())
			for frame in range(3): await process_frame
			var panel_rect := tooltip.get_rect()
			var body_rect := body.get_rect()
			check(panel_rect.size.x >= body_rect.end.x + 12, "Opaque panel covers text width and padding")
			check(panel_rect.size.y >= body_rect.end.y + 10, "Opaque panel covers text height and padding")
			var measured := body.get_theme_font("font").get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, body.size.x, 14)
			check(body.size.y >= measured.y, "First layout reserves complete wrapped text height")
			popup.free()
	panel.free()
	print("CHINESE UI NAMES: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
