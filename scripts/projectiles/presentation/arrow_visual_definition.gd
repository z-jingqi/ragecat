class_name ArrowVisualDefinition
extends Resource
## Cosmetic only. None of these values participate in projectile collision.
@export var base_texture: Texture2D
@export var accent_texture: Texture2D
@export var palette: DamageFeedbackDefinition
@export var sprite_rect := Rect2(-23.0, -6.0, 40.0, 12.0)
@export_range(0, 1, 0.01) var accent_opacity := 0.65
@export var dark_tint := Color("655083")
@export_range(0, 1, 0.01) var dark_palette_mix := 0.3
@export_range(0, 80, 1) var trail_max_length := 30.0
@export_range(0.01, 0.2, 0.005) var trail_duration := 0.05
@export_range(0.1, 4, 0.1) var trail_width := 1.3
@export_range(0, 1, 0.01) var trail_opacity := 0.32
@export_range(0, 1, 0.01) var fragment_trail_scale := 0.65
@export_range(0, 1, 0.01) var gravity_trail_scale := 0.4
@export_range(2, 12, 1) var trail_point_limit := 6
@export_range(1, 1000, 1) var trail_visual_limit := 96
@export var tail_position := Vector2(-20, 0)

func validated_copy() -> ArrowVisualDefinition:
	# Snapshot numeric presentation settings without copying texture/palette data.
	var copy := duplicate(false) as ArrowVisualDefinition
	var defaults := ArrowVisualDefinition.new()
	for key in ["accent_opacity", "dark_palette_mix", "trail_max_length", "trail_duration", "trail_width", "trail_opacity", "fragment_trail_scale", "gravity_trail_scale"]:
		if not is_finite(float(copy.get(key))): copy.set(key, defaults.get(key))
	for key in ["accent_opacity", "dark_palette_mix", "trail_opacity", "fragment_trail_scale", "gravity_trail_scale"]:
		copy.set(key, clampf(float(copy.get(key)), 0.0, 1.0))
	copy.trail_max_length = clampf(copy.trail_max_length, 0.0, 80.0)
	copy.trail_duration = clampf(copy.trail_duration, 0.01, 0.2)
	copy.trail_width = clampf(copy.trail_width, 0.1, 4.0)
	copy.trail_point_limit = clampi(copy.trail_point_limit, 2, 12)
	copy.trail_visual_limit = clampi(copy.trail_visual_limit, 1, 1000)
	if not copy.sprite_rect.position.is_finite() or not copy.sprite_rect.size.is_finite() or copy.sprite_rect.size.x <= 0.0 or copy.sprite_rect.size.y <= 0.0:
		copy.sprite_rect = defaults.sprite_rect
	if not copy.tail_position.is_finite(): copy.tail_position = defaults.tail_position
	if not is_finite(copy.dark_tint.r) or not is_finite(copy.dark_tint.g) or not is_finite(copy.dark_tint.b) or not is_finite(copy.dark_tint.a):
		copy.dark_tint = defaults.dark_tint
	if copy.base_texture == null: copy.base_texture = preload("res://assets/projectiles/bow/arrow_base.png")
	# A missing accent or palette is already supported by _draw()/tint().
	return copy

func tint(element: String) -> Color:
	if palette == null: return Color.WHITE
	if element == "dark": return dark_tint.lerp(palette.dark_color, dark_palette_mix)
	return palette.element_color(element)
