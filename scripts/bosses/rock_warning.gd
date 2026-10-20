class_name RockWarning
extends Node2D

signal impact(center: Vector2, impact_radius: float)

# Guard values avoid degenerate geometry and division by zero; tune behavior below.
const MIN_RADIUS: float = 0.01
const MIN_DRAW_DURATION: float = 0.01

@export_group("Rock Hazard")
@export_range(0.01, 200.0, 0.5, "or_greater") var radius: float = 31.0:
	set(value):
		radius = maxf(MIN_RADIUS, _nonnegative(value))
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var warning_duration: float = 1.25:
	set(value):
		warning_duration = _nonnegative(value)
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var aftermath_duration: float = 0.28:
	set(value):
		aftermath_duration = _nonnegative(value)
var elapsed: float = 0.0
var ai_enabled: bool = true
var impacted: bool = false

static func _nonnegative(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0

func _physics_process(delta: float) -> void:
	if not ai_enabled:
		return
	elapsed += delta
	if elapsed >= warning_duration and not impacted:
		impacted = true
		impact.emit(global_position, radius)
	if elapsed > warning_duration + aftermath_duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var progress: float = clampf(elapsed / maxf(warning_duration, MIN_DRAW_DURATION), 0.0, 1.0)
	if not impacted:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.32, 0.18, 0.17 + progress * 0.12))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color('#ffb46d'), 2.5)
		draw_arc(Vector2.ZERO, maxf(0.0, radius - 5), -PI / 2, -PI / 2 + TAU * progress, 40, Color('#ff634e'), 3)
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color('#ffc395'), 2)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color('#ffc395'), 2)
		var rock_y: float = -100.0 * (1.0 - progress) - 9.0
		draw_colored_polygon(PackedVector2Array([Vector2(-10, rock_y), Vector2(-6, rock_y - 15), Vector2(8, rock_y - 18), Vector2(15, rock_y - 5), Vector2(5, rock_y + 6)]), Color('#71849c'))
	else:
		var fade: float = clampf(1.0 - (elapsed - warning_duration) / maxf(aftermath_duration, MIN_DRAW_DURATION), 0.0, 1.0)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.75, 0.42, fade * 0.65))
		for i: int in range(7):
			var direction: Vector2 = Vector2.from_angle(float(i) * TAU / 7.0)
			draw_circle(direction * radius * (1.3 - fade * 0.6), 4.0 * fade, Color('#a6b2c0'))
