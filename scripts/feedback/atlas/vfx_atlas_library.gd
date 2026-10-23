class_name VfxAtlasLibrary
extends Resource
## Presentation budgets and tuning. Turning this off restores procedural fallback.
@export var enabled: bool = true
@export var clips: Array[VfxAtlasClip] = []
@export_range(1, 256, 1) var player_quad_budget: int = 48
@export_range(1, 256, 1) var boss_quad_budget: int = 48
@export_range(16, 256, 1) var ring_segments: int = 96
@export_range(8, 256, 1) var ring_texture_repeat_length: float = 180.0
@export_range(0.0, 4.0, 0.05) var charge_tail_length_factor: float = 2.4
@export_range(0.0, 2.0, 0.05) var charge_tail_width_factor: float = 1.4
@export_range(0.0, 1.0, 0.01) var charge_tail_opacity: float = 0.62
@export_range(0.0, 2.0, 0.05) var summon_size_factor: float = 1.8
@export_range(0.0, 240.0, 1.0) var rock_drop_height: float = 100.0
@export_range(0.0, 40.0, 1.0) var rock_target_offset: float = 9.0
@export_range(0.0, 1.0, 0.01) var dark_core_outline_opacity: float = 0.22
@export_range(0.0, 2.0, 0.05) var projectile_size_factor: float = 2.0

@export_range(0.0, 1.0, 0.01) var projectile_boundary_opacity: float = 0.6
@export_range(0.5, 3.0, 0.1) var projectile_boundary_width: float = 1.0

func find_clip(key: StringName) -> VfxAtlasClip:
	for clip in clips:
		if clip != null and clip.id == key and clip.valid(): return clip
	return null
