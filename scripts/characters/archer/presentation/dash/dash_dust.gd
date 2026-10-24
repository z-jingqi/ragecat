class_name ArcherDashDust
extends Node2D
var settings: ArcherDashFeedbackDefinition
var direction := Vector2.RIGHT
var age := 0.0
func _process(delta: float) -> void:
	age += maxf(delta, 0.0)
	if settings == null or age >= maxf(0.001, settings.dust_lifetime): queue_free()
	queue_redraw()
func _draw() -> void:
	if settings == null: return
	var phase := clampf(age / maxf(settings.dust_lifetime, 0.001), 0.0, 1.0)
	var color := settings.dust_color
	color.a *= (1.0 - phase) * (1.0 - phase)
	for i in range(clampi(settings.dust_count, 0, 12)):
		# Stable layout, never consume combat or global RNG.
		var side := float(i % 3 - 1)
		var speed := settings.dust_speed * (0.7 + 0.13 * i)
		var offset := -direction * speed * age + direction.orthogonal() * side * (2.0 + age * 12.0)
		var radius := maxf(0.1, settings.dust_size * (0.75 + 0.12 * i) * (1.0 + phase))
		draw_set_transform(offset, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius, color)
	draw_set_transform(Vector2.ZERO)
