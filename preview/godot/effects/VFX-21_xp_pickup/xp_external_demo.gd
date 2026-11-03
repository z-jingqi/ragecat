extends Node2D
## Demo driver is deliberately separate from the passive cosmetic component.
const Effect = preload("res://effects/VFX-21_xp_pickup/xp_external.gd")
var effect: Node2D
var detail: Node2D
var time := 0.0
var host_position := Vector2.ZERO
var texture: Texture2D
var phase: Label
var paused := false
func label_at(text: String, at: Vector2, size := 14) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	add_child(label)
	return label
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("20282d"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--xp-texture="):
			var image := Image.load_from_file(arg.trim_prefix("--xp-texture="))
			if image != null:
				texture = ImageTexture.create_from_image(image)
	label_at("XP / EXTERNAL AUTHORITY", Vector2(24, 18), 21)
	label_at("Game owns the crystal. Ragecat adds only the trail and collect glint.", Vector2(24, 51), 13)
	label_at("ACTUAL 1x", Vector2(24, 92), 12)
	label_at("DETAIL 3x / NEAREST", Vector2(24, 190), 12)
	label_at("Pause: SPACE    Replay: R    Texture: existing xp-crystal.png (16 x 16)", Vector2(24, 329), 12)
	phase = label_at("", Vector2(24, 300), 13)
	effect = Effect.new()
	effect.z_index = -1
	effect.position = Vector2(70, 140)
	add_child(effect)
	detail = Effect.new()
	detail.z_index = -1
	detail.position = Vector2(70, 256)
	detail.scale = Vector2(3, 3)
	add_child(detail)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		paused = not paused
		effect.set_paused(paused)
		detail.set_paused(paused)
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		time = 0.0
		effect.clear()
		detail.clear()
		paused = false
func _process(dt: float) -> void:
	if paused:
		return
	time += dt
	if time >= 4.0:
		time = 0.0
		effect.clear()
		detail.clear()
	effect.tick(dt)
	detail.tick(dt)
	if time < 1.0:
		host_position = Vector2(8, 0)
		phase.text = "IDLE: no replacement crystal, no autonomous bob, no expiry"
	elif time < 2.1:
		var u := (time - 1.0) / 1.1
		host_position = Vector2(8 + 135 * u, -sin(u * PI) * 10)
		phase.text = "MOVE: exact externally supplied positions / short green pixel trail"
	else:
		host_position = Vector2(143, 0)
		phase.text = "COLLECT: explicit four-way glint / 0.14 seconds / one-shot"
	if time < 2.1:
		effect.sample_position(host_position)
		detail.sample_position(host_position)
	elif not effect.collected:
		effect.collect(host_position)
		detail.collect(host_position)
	queue_redraw()
func _draw() -> void:
	if texture != null and time < 2.1:
		draw_texture_rect(texture, Rect2(Vector2(70, 140) + host_position.round() - Vector2(8, 8), Vector2(16, 16)), false)
		draw_texture_rect(texture, Rect2(Vector2(70, 256) + host_position.round() * 3 - Vector2(24, 24), Vector2(48, 48)), false)
