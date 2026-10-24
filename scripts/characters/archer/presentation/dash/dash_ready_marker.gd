class_name ArcherDashReadyMarker
extends Node2D
## Two small strokes below the feet, driven only by the actual remaining cooldown.
var actor: PlayerActor
var settings: ArcherDashFeedbackDefinition
var readiness := 1.0
func update_state() -> void:
	visible = is_instance_valid(actor) and settings != null and settings.enabled and settings.marker_enabled
	if not visible: return
	position = settings.marker_offset
	var duration := actor.stats.dash_cooldown_duration if actor.stats != null else 0.0
	readiness = clampf(1.0 - actor.dash_cooldown / maxf(duration, 0.001), 0.0, 1.0)
	queue_redraw()
func _draw() -> void:
	if settings == null: return
	var size := maxf(0.1, settings.marker_size)
	var width := maxf(0.1, settings.marker_stroke_width)
	# A double slash communicates dash without text, numbers or a circular meter.
	for center in [-0.28, 0.28]:
		var start := Vector2(center - 0.17, 0.25) * size
		var end := Vector2(center + 0.17, -0.25) * size
		draw_line(start, end, settings.marker_background, width, true)
		if readiness > 0.0:
			draw_line(start, start.lerp(end, readiness), settings.marker_ready, width, true)
