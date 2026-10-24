class_name ElementVisualDefinition
extends Resource
## Presentation-only settings. No gameplay code reads these values.
@export_group("Frost")
@export_range(1, 10, 1) var frost_visual_stack_scale: int = 3
@export_range(0.01, 1.0, 0.01) var freeze_growth_duration: float = 0.15
@export_range(0.01, 1.0, 0.01) var thaw_duration: float = 0.28
@export_range(0, 12, 0.5) var shell_padding: float = 6.0
@export_range(3, 16, 1) var crystal_sides: int = 6
@export_range(0, 1, 0.01) var ice_opacity: float = 0.32
@export_range(0, 1, 0.01) var frost_opacity: float = 0.22
@export var ice_color := Color("9aaeba")
@export_group("Lightning")
@export_range(0, 1, 0.01) var shock_filament_opacity: float = 0.55
@export_range(0, 12, 0.5) var shock_filament_speed: float = 5.0
@export_range(0, 12, 0.5) var shock_filament_padding: float = 3.0
@export_range(1, 32, 1) var lightning_visual_limit: int = 16
@export_range(0, 16, 1) var lightning_detail_limit: int = 4
@export_range(2, 16, 1) var bolt_segments: int = 12
@export_range(0, 30, 0.5) var bolt_jitter: float = 10.0
@export_range(0.5, 6, 0.5) var bolt_core_width: float = 1.2
@export_range(0.05, 1, 0.01) var chain_reveal_fraction: float = 0.4
@export_range(1, 20, 0.5) var bolt_endpoint_radius: float = 4.0
@export_range(0, 4, 1) var bolt_branches: int = 2
@export_range(4, 40, 1) var bolt_glow_width: float = 9.0
@export_range(1, 40, 1) var bolt_branch_length: float = 14.0
@export_range(1, 12, 1) var bolt_sparks: int = 3
@export var bolt_sheath_color := Color("6267ff")
@export var bolt_corona_color := Color("379fff")
@export_group("Fire")
@export_range(0, 1, 0.01) var fire_explosion_opacity: float = 0.94
@export_range(0, 1, 0.01) var fire_explosion_size_variation: float = 0.12
@export_range(0, 0.5, 0.01) var fire_explosion_timing_variation: float = 0.14
@export_range(0, 360, 1) var fire_explosion_rotation_degrees: float = 360.0
@export_range(0, 1, 0.01) var fire_burst_opacity: float = 0.84
@export_range(0, 1, 0.01) var fire_fallback_ember_opacity: float = 0.62
@export_range(1, 24, 1) var fire_sparks: int = 10
@export_range(0, 1, 0.01) var blast_fill_opacity: float = 0.18
@export_range(1, 12, 1) var burn_flames: int = 5
@export_range(1, 30, 0.5) var burn_height: float = 12.0
@export_range(0, 20, 0.5) var burn_flicker_speed: float = 9.0
@export var fire_core_color := Color("fff0a6")
@export_group("Ice break")
@export_range(0.02, 1, 0.01) var shatter_duration: float = 0.32
@export_range(0, 200, 1) var shard_travel: float = 35.0
@export_range(1, 20, 1) var shard_count: int = 8

func validated_copy() -> ElementVisualDefinition:
	var copy := duplicate(true) as ElementVisualDefinition
	var defaults := ElementVisualDefinition.new()
	for property in get_property_list():
		if property.type == TYPE_FLOAT:
			var value: float = copy.get(property.name)
			copy.set(property.name, maxf(0.0, value) if is_finite(value) else defaults.get(property.name))
	copy.frost_visual_stack_scale = clampi(copy.frost_visual_stack_scale, 1, 10)
	copy.freeze_growth_duration = maxf(0.01, copy.freeze_growth_duration)
	copy.thaw_duration = maxf(0.01, copy.thaw_duration)
	copy.crystal_sides = clampi(copy.crystal_sides, 3, 16)
	copy.bolt_segments = clampi(copy.bolt_segments, 2, 16)
	copy.lightning_visual_limit = clampi(copy.lightning_visual_limit, 1, 32)
	copy.lightning_detail_limit = clampi(copy.lightning_detail_limit, 0, copy.lightning_visual_limit)
	copy.bolt_branches = clampi(copy.bolt_branches, 0, 4)
	copy.bolt_sparks = clampi(copy.bolt_sparks, 1, 12)
	copy.bolt_glow_width = clampf(copy.bolt_glow_width, 4.0, 40.0)
	copy.fire_explosion_opacity = clampf(copy.fire_explosion_opacity, 0.0, 1.0)
	copy.fire_explosion_size_variation = clampf(copy.fire_explosion_size_variation, 0.0, 1.0)
	copy.fire_explosion_timing_variation = clampf(copy.fire_explosion_timing_variation, 0.0, 0.5)
	copy.fire_explosion_rotation_degrees = clampf(copy.fire_explosion_rotation_degrees, 0.0, 360.0)
	copy.fire_sparks = clampi(copy.fire_sparks, 1, 24)
	copy.burn_flames = clampi(copy.burn_flames, 1, 12)
	copy.shard_count = clampi(copy.shard_count, 1, 20)
	copy.chain_reveal_fraction = clampf(copy.chain_reveal_fraction, 0.05, 1.0)
	return copy
