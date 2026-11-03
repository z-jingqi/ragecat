extends Control

const GROUPS = [
	["group_one", ["explosion", "impact", "slash", "muzzle-flash", "blood", "movement", "fire", "lightning"]],
	["effects", ["ice", "poison", "energy", "shield", "black-hole", "holy-light", "heal", "power-up"]],
	["group_three", ["pickup", "sparkle", "rain", "snow", "fog", "embers", "fireflies", "falling-leaves", "bubbles"]],
]
var available: Array = []

func _ready():
	get_window().size = Vector2i(960, 600)
	get_window().content_scale_size = Vector2i(640, 400)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	RenderingServer.set_default_clear_color(Color("171b29"))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title = Label.new()
	title.text = "Sprite Fusion Exact · Ragecat"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	for group in GROUPS:
		for slug in group[1]:
			var path = ("res://scenes/effects/" if group[0] == "effects" else "res://previews/" + group[0] + "/") + slug + ".tscn"
			if ResourceLoader.exists(path): available.append({"slug": slug, "path": path})
	var subtitle = Label.new()
	subtitle.text = "%d of 25 effect families installed · native Godot scenes" % available.size()
	column.add_child(subtitle)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for entry in available:
		var button = Button.new()
		button.text = entry.slug.replace("-", " ").capitalize()
		button.custom_minimum_size.y = 36
		button.pressed.connect(open_effect.bind(entry.path))
		list.add_child(button)
	if list.get_child_count(): list.get_child(0).grab_focus()
	var footer = Label.new()
	footer.text = "Enter opens an effect. Esc returns here.\nEach scene shows its controls; reference artwork is not included."
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)

func open_effect(path: String):
	get_tree().change_scene_to_file(path)
