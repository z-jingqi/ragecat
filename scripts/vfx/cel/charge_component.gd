extends Node2D
## Small cel-only transport; no shared renderer, emission or composition dependency.
## Subclasses own their config and build_commands(). Nothing auto-launches.
signal finished
var age := -1.0
var playing := false
var stop_at := -1.0
var _configured := false

func play() -> void:
	age = 0.0
	stop_at = -1.0
	playing = true
	queue_redraw()

func stop(immediate: bool = false) -> void:
	if age < 0: return
	if immediate:
		age = -1.0
		stop_at = -1.0
		playing = false
		queue_redraw()
		finished.emit()
	elif stop_at < 0:
		stop_at = age
		playing = true

func seek(seconds: float, stopped_at: float = -1.0) -> void:
	age = seconds if is_finite(seconds) else -1.0
	stop_at = stopped_at if is_finite(stopped_at) and stopped_at >= 0 else -1.0
	playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	age += maxf(delta,0)
	if stop_at >= 0 and age >= stop_at+get("config").dissipate_seconds:
		age = -1.0
		playing = false
		stop_at = -1.0
		finished.emit()
	queue_redraw()

func envelope(time: float, stopped_at: float, duration: float) -> float:
	if not is_finite(time) or time < 0: return 0.0
	if not is_finite(stopped_at) or stopped_at < 0 or time < stopped_at: return 1.0
	return 1.0-smoothstep(0.0,duration,time-stopped_at)

func _draw() -> void:
	for command in call("build_commands"):
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.8,true)
