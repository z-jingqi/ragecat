class_name HitFeedbackDefinition
extends Resource
## Run-local validated snapshot. Movement reaction is intentionally separate from
## cosmetic enable/mute: hiding visuals must never alter combat outcomes.
@export_group("Movement reaction")
@export_range(0, 0.1, 0.001) var direct_pause: float = 0.05
@export_range(0, 0.1, 0.001) var derived_pause: float = 0.025
@export_range(0.1, 1, 0.01) var reaction_cooldown: float = 0.2
@export_range(0, 0.1, 0.001) var flash_duration: float = 0.05
@export_range(0, 1, 0.01) var flash_strength: float = 0.75
@export_range(0.02, 0.3, 0.001) var knockback_duration: float = 0.08
@export_range(0, 1000, 1) var knockback_distance_cap: float = 240.0
@export_range(0, 10000, 1) var knockback_speed_cap: float = 3000.0
@export var elements: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
@export_group("Cosmetics")
@export var enabled: bool = true
@export_range(1, 128, 1) var visual_limit: int = 48
@export_range(1, 32, 1) var death_limit: int = 12
@export_range(1, 16, 1) var particles: int = 5
@export_range(1, 20, 1) var critical_particles: int = 8
@export_range(0.02, 0.3, 0.01) var impact_duration: float = 0.10
@export_range(0.02, 0.3, 0.01) var death_duration: float = 0.15
@export_range(0.02, 0.5, 0.01) var accent_duration: float = 0.18
@export_range(1, 100, 1) var particle_travel: float = 22.0
@export var base_color := Color("ffe4b2")
@export var critical_color := Color("ffd064")
@export var ice_color := Color("bcefff")
@export var fire_color := Color("ff9958")
@export var lightning_color := Color("ffe38a")
@export var dark_color := Color("ba8bff")

func validated_copy() -> HitFeedbackDefinition:
	var copy := duplicate(true) as HitFeedbackDefinition
	var defaults := HitFeedbackDefinition.new()
	if copy.elements == null: copy.elements = ElementVisualDefinition.new()
	copy.elements = copy.elements.validated_copy()
	for property in get_property_list():
		if property.type == TYPE_FLOAT:
			var value: float = copy.get(property.name)
			copy.set(property.name, maxf(0.0, value) if is_finite(value) else defaults.get(property.name))
	copy.direct_pause = minf(copy.direct_pause, 0.1)
	copy.derived_pause = minf(copy.derived_pause, copy.direct_pause)
	# At most 25% sustained translation interruption, even hostile resources.
	copy.reaction_cooldown = maxf(0.1, maxf(copy.reaction_cooldown, copy.direct_pause * 4.0))
	copy.flash_duration = minf(copy.flash_duration, minf(0.06, copy.reaction_cooldown * 0.3))
	copy.flash_strength = clampf(copy.flash_strength, 0.0, 1.0)
	copy.knockback_duration = clampf(copy.knockback_duration, 0.02, 0.3)
	copy.knockback_distance_cap = minf(copy.knockback_distance_cap, 1000.0)
	copy.knockback_speed_cap = minf(copy.knockback_speed_cap, 10000.0)
	copy.visual_limit = clampi(copy.visual_limit, 1, 128)
	copy.death_limit = clampi(copy.death_limit, 1, mini(32, copy.visual_limit))
	copy.particles = clampi(copy.particles, 1, 16)
	copy.critical_particles = clampi(copy.critical_particles, 1, 20)
	copy.impact_duration = clampf(copy.impact_duration, 0.02, 0.3)
	copy.death_duration = clampf(copy.death_duration, 0.02, 0.3)
	copy.accent_duration = clampf(copy.accent_duration, 0.02, 0.5)
	copy.particle_travel = clampf(copy.particle_travel, 1.0, 100.0)
	return copy

func element_color(element: String) -> Color:
	match element:
		"fire": return fire_color
		"lightning": return lightning_color
		"ice": return ice_color
		"dark": return dark_color
	return base_color
