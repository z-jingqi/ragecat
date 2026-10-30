extends SceneTree
## CPU preview input uses the exact original renderer command stream.
## It is NOT a viewport screenshot; see README for rendering limitations.
const Behavior = preload("res://scripts/vfx_lab/impact_behavior.gd")
const PixelRenderer = preload("res://scripts/vfx_lab/pixel_impact.gd")
func _initialize() -> void:
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("Pass -- --output=/absolute/outside/repo/commands.json")
		quit(1)
		return
	var renderer := PixelRenderer.new()
	renderer.behavior = Behavior.new()
	renderer.show_demo = true
	var frames: Array = []
	for frame in range(240):
		renderer.time = (frame%120)/60.0 if frame < 120 else (frame%120)/120.0
		renderer.bright = frame >= 120
		frames.append({"time":renderer.time,"bright":renderer.bright,"commands":renderer.build_commands()})
	var file := FileAccess.open(output,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write preview commands")
		quit(1)
		return
	file.store_string(JSON.stringify({"size":[384,160],"fps":60,"frames":frames}))
	file.close()
	renderer.free()
	print("Exported 240 renderer-command frames (CPU preview input, not viewport captures)")
	quit()
