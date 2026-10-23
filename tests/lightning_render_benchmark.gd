extends SceneTree
## Manual rendered benchmark: run without --headless on the target GPU.
## Prints timings only; no generated image, log, or report is committed.
## 4 chains is representative, 70 exercises saturated visual-only budgets.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	for count in [4, 70]:
		for i in range(count):
			var flash := ElementFlash.new()
			flash.kind = "chain"
			var start := Vector2(100 + (i % 7) * 110, 150 + (i / 7) * 48)
			flash.points = PackedVector2Array([start, start + Vector2(80,-25),start + Vector2(140,20),start + Vector2(210,-20),start + Vector2(280,15)])
			stage.add_child(flash)
			flash.set_process(false)
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in range(180):
			for flash in stage.get_children():
				flash.remaining = flash.duration * (1.0 - float(frame % 15) / 15.0)
				flash.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var now := Time.get_ticks_usec()
			if frame > 30: samples.append((now - previous) / 1000.0)
			previous = now
		samples.sort()
		print("RENDER %d chains median %.2f ms P95 %.2f ms" % [count, samples[samples.size()/2], samples[int(samples.size()*.95)]])
		for child in stage.get_children(): child.free()
	quit()
