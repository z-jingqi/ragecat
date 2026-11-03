extends SceneTree
const Warning = preload("res://effects/VFX-17_boss_warning/hostile_warning.gd")
var warnings: Array[Node2D] = []
var clock := 0.0
var label: Label
func _initialize() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	RenderingServer.set_default_clear_color(Color("102b37"))
	call_deferred("start")
func start() -> void:
	label = Label.new()
	label.position = Vector2(50, 35)
	label.add_theme_font_size_override("font_size", 24)
	root.add_child(label)
	for data in [["circle", Vector2.ZERO, Vector2(190, 250), 62.0], ["capsule", Vector2(400, 250), Vector2(660, 250), 23.0], ["line", Vector2(100, 490), Vector2(556, 490), 7.0], ["capsule", Vector2(800, 490), Vector2(800, 490), 23.0]]:
		var w := Warning.new()
		root.add_child(w)
		w.play(data[0], data[1], data[2], data[3])
		warnings.append(w)
	for data in [[Vector2(95, 340), "HEAVY / radius 62"], [Vector2(390, 340), "ELITE / 260 x radius 23"], [Vector2(95, 545), "RANGED / 456 x radius 7"], [Vector2(700, 545), "ZERO LENGTH / radius 23"]]:
		var text := Label.new()
		text.position = data[0]
		text.text = data[1]
		root.add_child(text)
func _process(dt: float) -> bool:
	clock += dt
	if not is_instance_valid(label): return false
	var p := clampf(clock / 4.0, 0, 1)
	if clock > 4 and clock < 6: p = 0.5
	label.text = "HOSTILE / caller-clocked / %.0f%%" % (p * 100)
	if clock > 4 and clock < 6: label.text += " / PAUSED (fixed 50%)"
	for w in warnings:
		if clock >= 8: w.stop()
		else: w.seek(p)
	if clock >= 8: label.text = "STOP / all warnings cleared immediately"
	if clock >= 10: quit()
	return false
