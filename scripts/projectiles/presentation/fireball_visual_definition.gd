class_name FireballVisualDefinition
extends Resource
## Original gas-flame color source with 32 independently evolving geometric poses.
## Offline-rendered straight-alpha atlas; bounds include transparent padding.
## Only the EnemyBullet radius determines collisions, never the flame wake.
@export var texture: Texture2D = preload("res://assets/projectiles/fireball/evolving_fire_atlas.png")
@export var atlas_grid := Vector2i(8, 4)
@export_range(1, 120, 1) var frame_count := 32
@export_range(1, 120, 1) var frames_per_second := 32.0
@export var bounds_in_radii := Rect2(-3.1, -1.6, 4.8, 3.2)
@export_range(0, 1, 0.01) var surface_opacity := 1.0

func validated_copy() -> FireballVisualDefinition:
	# Atlas, layout and mapping are one contract. Never reinterpret an invalid
	# 8x4 atlas as a single frame or allow a zero divisor into the shader.
	var copy := duplicate(false) as FireballVisualDefinition
	var defaults := FireballVisualDefinition.new()
	var atlas_valid := copy.texture != null and copy.atlas_grid.x > 0 and copy.atlas_grid.y > 0
	if atlas_valid:
		var width := copy.texture.get_width()
		var height := copy.texture.get_height()
		atlas_valid = width > 0 and height > 0 and copy.atlas_grid.x <= width and copy.atlas_grid.y <= height
		if atlas_valid:
			atlas_valid = width % copy.atlas_grid.x == 0 and height % copy.atlas_grid.y == 0
			atlas_valid = atlas_valid and copy.frame_count >= 1 and copy.frame_count <= mini(120, copy.atlas_grid.x * copy.atlas_grid.y)
	if not atlas_valid:
		copy.texture = defaults.texture
		copy.atlas_grid = defaults.atlas_grid
		copy.frame_count = defaults.frame_count
		copy.bounds_in_radii = defaults.bounds_in_radii
	if not is_finite(copy.frames_per_second): copy.frames_per_second = defaults.frames_per_second
	copy.frames_per_second = clampf(copy.frames_per_second, 1.0, 120.0)
	if not is_finite(copy.surface_opacity): copy.surface_opacity = defaults.surface_opacity
	copy.surface_opacity = clampf(copy.surface_opacity, 0.0, 1.0)
	if not copy.bounds_in_radii.position.is_finite() or not copy.bounds_in_radii.size.is_finite() or copy.bounds_in_radii.size.x <= 0.0 or copy.bounds_in_radii.size.y <= 0.0:
		copy.bounds_in_radii = defaults.bounds_in_radii
	return copy
