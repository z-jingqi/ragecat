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
@export_range(0.0, 240.0, 1.0) var rock_drop_height: float = 145.0
@export_range(0.0, 40.0, 1.0) var rock_target_offset: float = 5.0
@export_range(0.0, 2.0, 0.05) var projectile_size_factor: float = 2.0

@export_range(0.0, 1.0, 0.01) var projectile_boundary_opacity: float = 0.6

func find_clip(key: StringName) -> VfxAtlasClip:
	for clip in clips:
		if clip != null and clip.id == key and clip.valid(): return clip
	return null

@export_group("Rock Presentation")
@export_range(0.1, 0.9, 0.01) var rock_fall_start: float = 0.48
@export_range(1.0, 4.0, 0.05) var rock_fall_exponent: float = 2.15
@export_range(0.0, 1.0, 0.01) var rock_warning_opacity: float = 0.72
@export_range(0.01, 0.3, 0.01) var rock_warning_edge_softness: float = 0.14
@export_range(0.0, 1.0, 0.01) var rock_dust_opacity: float = 0.28
@export_range(0, 16, 1) var rock_warning_mote_count: int = 5
@export var rock_warning_color: Color = Color(0.43, 0.40, 0.34, 1.0)

@export_group("Dark Material")
@export_range(0.0, 1.0, 0.01) var dark_surface_opacity: float = 0.34
@export_range(1.0, 40.0, 0.5) var dark_surface_scale: float = 7.0
@export_range(0.0, 1.0, 0.01) var dark_surface_warp: float = 0.16
@export_range(0.1, 4.0, 0.1) var dark_core_density: float = 1.9
@export_range(0.01, 0.3, 0.01) var dark_edge_softness: float = 0.08
@export_range(0.0, 1.0, 0.01) var dark_stream_opacity: float = 0.42
@export_range(0.1, 4.0, 0.05) var dark_stream_width: float = 1.05
@export_range(1.0, 50.0, 0.5) var dark_stream_length: float = 18.0
@export_range(0.0, 1.0, 0.01) var dark_stream_bend: float = 0.32
@export var dark_stream_color: Color = Color(0.42, 0.36, 0.50, 1)
@export var dark_material_color: Color = Color(0.19, 0.16, 0.24, 1)
@export_group("Frost Material")
@export_range(1.0, 64.0, 1.0) var frost_grain_scale: float = 28.0
@export_range(0.01, 0.3, 0.01) var frost_edge_softness: float = 0.08
@export_range(0.0, 1.0, 0.01) var frost_tint_strength: float = 0.55
@export_range(0.0, 1.0, 0.01) var frost_edge_strength: float = 0.20
@export_group("Fire Presentation")
@export_range(0.0, 0.9, 0.01) var skyfire_fall_start: float = 0.28
@export_range(1.0, 4.0, 0.05) var skyfire_fall_exponent: float = 2.15
@export_range(0.0, 300.0, 1.0) var skyfire_drop_height: float = 150.0
@export_range(0.05, 1.0, 0.01) var skyfire_mass_radius_ratio: float = 0.30
@export_range(0.0, 1.0, 0.01) var skyfire_warning_opacity: float = 0.70
@export_range(0.0, 1.0, 0.01) var skyfire_ground_opacity: float = 0.64
@export_range(0.01, 0.3, 0.01) var skyfire_warning_edge_softness: float = 0.10
@export_range(0.0, 1.0, 0.01) var skyfire_low_flame_opacity: float = 0.72
@export_range(0.0, 1.0, 0.01) var skyfire_impact_opacity: float = 0.72
@export_range(0.0, 1.0, 0.01) var fire_ring_surface_opacity: float = 0.78
@export_range(0.0, 1.0, 0.01) var fire_ring_texture_opacity: float = 0.86
@export_group("Arcane Presentation")
@export var summon_stream_color: Color = Color(0.50, 0.39, 0.67, 1)
@export_range(0.0, 1.0, 0.01) var summon_stream_opacity: float = 0.62
@export_range(0.1, 4.0, 0.1) var summon_stream_width: float = 1.4
@export_range(0.0, 4.0, 0.1) var projectile_tail_factor: float = 1.8
@export_range(0.0, 1.0, 0.01) var projectile_tail_opacity: float = 0.3
@export_range(0.1, 6.0, 0.1) var projectile_tail_width: float = 2.0
@export_group("Charge Presentation")
@export_range(0.0, 1.0, 0.01) var charge_warning_opacity: float = 0.55
@export var charge_warning_color: Color = Color(0.53, 0.44, 0.34, 1)

@export_range(0.05, 2.0, 0.01) var charge_dust_cycle: float = 0.45

@export_group("Dark Density")
@export_range(0.0, 2.0, 0.01) var dark_outer_density: float = 0.65
@export var dark_fold_color: Color = Color(0.42, 0.36, 0.52, 1)
