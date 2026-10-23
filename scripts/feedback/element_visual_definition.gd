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
@export var ice_color := Color("bcefff")
@export_group("Lightning")
@export_range(2, 16, 1) var bolt_segments: int = 7
@export_range(0, 30, 0.5) var bolt_jitter: float = 9.0
@export_range(1, 12, 0.5) var bolt_outline_width: float = 5.0
@export_range(0.5, 6, 0.5) var bolt_core_width: float = 1.6
@export_range(0.05, 1, 0.01) var chain_reveal_fraction: float = 0.4
@export_range(1, 20, 0.5) var bolt_endpoint_radius: float = 4.0
@export_group("Fire")
@export_range(1, 24, 1) var fire_sparks: int = 10
@export_range(0, 1, 0.01) var blast_fill_opacity: float = 0.18
@export_range(1, 12, 1) var burn_flames: int = 5
@export_range(1, 30, 0.5) var burn_height: float = 12.0
@export_range(0, 20, 0.5) var burn_flicker_speed: float = 9.0
@export var fire_core_color := Color("fff0a6")
@export_group("Vortex")
@export_range(1, 8, 1) var vortex_arms: int = 3
@export_range(8, 64, 1) var vortex_segments: int = 28
@export_range(1, 24, 1) var vortex_streaks: int = 12
@export_range(0, 10, 0.1) var vortex_rotation_speed: float = 2.6
@export_range(0.01, 4, 0.01) var vortex_inward_speed: float = 0.55
@export_range(0, 1, 0.01) var vortex_outer_opacity: float = 0.10
@export_range(0, 1, 0.01) var vortex_core_opacity: float = 0.24
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
	copy.fire_sparks = clampi(copy.fire_sparks, 1, 24)
	copy.burn_flames = clampi(copy.burn_flames, 1, 12)
	copy.vortex_arms = clampi(copy.vortex_arms, 1, 8)
	copy.vortex_segments = clampi(copy.vortex_segments, 8, 64)
	copy.vortex_streaks = clampi(copy.vortex_streaks, 1, 24)
	copy.shard_count = clampi(copy.shard_count, 1, 20)
	copy.chain_reveal_fraction = clampf(copy.chain_reveal_fraction, 0.05, 1.0)
	return copy
