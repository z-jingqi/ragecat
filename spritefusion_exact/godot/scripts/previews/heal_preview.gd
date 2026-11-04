# Native live heal/mana preview. Only actor pixels are embedded; effects remain procedural.
# Source actor is the canonical 16x32 differential-test fixture (RGBA8).
extends Node2D
const Frame = preload("res://scripts/core/sf_frame.gd")
const Canvas = preload("res://scripts/core/sf_canvas.gd")
const Heal = preload("res://scripts/effects/heal.gd")
const ACTOR_BASE64 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/711//+9df//vXX//711//+9df//vXX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP+9df//vXX//711//+9df//vXX//711/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/vXX//711//+9df//vXX//711//+9df8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/711//+9df//vXX//711//+9df//vXX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAP+9df//vXX//711//+9df//vXX//711/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD/vXX//711//+9df//vXX//711//+9df8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA/711//+9df//vXX//711//+9df//vXX/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE6l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABOpdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/wAAAAAAAAAAAAAAAAAAAAAAAAAATqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v8AAAAAAAAAAE6l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/AAAAAAAAAABOpdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/wAAAAAAAAAATqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v8AAAAAAAAAAE6l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/AAAAAAAAAABOpdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/wAAAAAAAAAAAAAAAAAAAAAAAAAATqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE6l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABOpdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAATqXW/06l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE6l1v9Opdb/TqXW/06l1v9Opdb/TqXW/06l1v9Opdb/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAzVHn/M1R5/zNUef8AAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAM1R5/zNUef8zVHn/AAAAAAAAAAAAAAAAAAAAADNUef8zVHn/M1R5/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
var actor_data := PackedInt64Array()
var frames: Array = []
var effects: Array = []
var canvases: Array = []
var tick := 0
var auto_loop := true

func _ready() -> void:
	# Keep both panels in a fixed logical viewport when the project or WM resizes.
	get_window().content_scale_size = Vector2i(1280, 400)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	get_window().size = Vector2i(1280, 400)
	RenderingServer.set_default_clear_color(Color(0.05, 0.055, 0.07, 1.0))
	var bytes := Marshalls.base64_to_raw(ACTOR_BASE64)
	for i in range(512): actor_data.append(bytes.decode_u32(i * 4))
	for i in range(2):
		frames.append(Frame.new(320, 200))
		var canvas = Canvas.new()
		canvas.position = Vector2(i * 640, 0)
		add_child(canvas)
		canvases.append(canvas)
	reset_effects()

func reset_effects() -> void:
	for effect in effects: effect.dispose()
	effects.clear()
	tick = 0
	var actor := {
		"feet": func(): return [320.0, 300.0],
		"silhouette": func(): return {"x":152.0,"y":118.0,"w":16.0,"h":32.0,"data":actor_data},
	}
	for kind in ["heal", "mana"]:
		effects.append(Heal.new().configure({"actor": actor, "kind": kind, "seed": 1}))
	render_frames()

func advance_frame() -> void:
	for effect in effects: effect.update(1.0 / 60.0)
	tick += 1
	render_frames()

func render_frames() -> void:
	for i in range(2):
		var frame = frames[i]
		frame.clear()
		effects[i].draw(frame, "back")
		# Actor and effect share one buffer: front sweeps must replace actor pixels.
		for y in range(32):
			for x in range(16):
				var pixel: int = actor_data[y * 16 + x]
				if (pixel >> 24) != 0: frame.color.put(152 + x, 118 + y, pixel)
		effects[i].draw(frame, "front")
		canvases[i].present(frame)

func _physics_process(_delta: float) -> void:
	if auto_loop and tick >= 210: reset_effects()
	else: advance_frame()

func _exit_tree() -> void:
	for effect in effects: effect.dispose()

# Diagnostic Image export only. This is NOT a captured GPU/viewport image.
func diagnostic_image() -> Image:
	var output := Image.create(640, 200, false, Image.FORMAT_RGBA8)
	for panel in range(2):
		var light: Image = frames[panel].light.to_image()
		var color: Image = frames[panel].color.to_image()
		for y in range(200):
			for x in range(320):
				var glow := light.get_pixel(x, y)
				var foreground := color.get_pixel(x, y)
				var background := Color(0.05, 0.055, 0.07, 1.0)
				background.r = minf(1.0, background.r + glow.r * glow.a)
				background.g = minf(1.0, background.g + glow.g * glow.a)
				background.b = minf(1.0, background.b + glow.b * glow.a)
				output.set_pixel(panel * 320 + x, y, background.blend(foreground))
	output.resize(1280, 400, Image.INTERPOLATE_NEAREST)
	return output
