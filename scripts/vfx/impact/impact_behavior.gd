extends RefCounted
## Style-neutral, deterministic choreography. Coordinates are local to the hit.
## A future smooth/cel renderer consumes these samples, not a separate simulation.
const CONTACT := 0.48
const DURATION := 1.65
const Config = preload("res://scripts/vfx/impact/impact_config.gd")
var config := Config.new()
# Compatibility aliases for programmatic callers of the first prototype.
var strength: float:
	get: return config.strength
	set(value): config.strength = value
var direction: Vector2:
	get: return Vector2.from_angle(deg_to_rad(config.direction_degrees))
	set(value): config.direction_degrees = rad_to_deg(value.angle()) if value.is_finite() and not value.is_zero_approx() else 0.0

func configure(settings: Resource) -> void:
	config = settings.duplicate(true) if settings is Config else Config.new()
	config.sanitize()

func duration() -> float:
	config.sanitize()
	return maxf(DURATION,CONTACT + maxf(config.smoke_seconds,0.62*config.spark_lifetime)+0.1)

func sample(time: float) -> Dictionary:
	config.sanitize()
	var age := time - CONTACT
	return {
		"age": age,
		"flight": clampf((time - 0.16) / (CONTACT - 0.16), 0.0, 1.0),
		"flash": clampf(1.0 - age / config.flash_seconds, 0.0, 1.0) if age >= 0.0 else 0.0,
		"recoil": sin(clampf(age / config.recoil_seconds, 0.0, 1.0) * PI) * config.recoil_pixels * strength,
		"smoke": clampf(age / 0.12, 0.0, 1.0) * clampf(1.0 - age / config.smoke_seconds, 0.0, 1.0),
	}

func spark(index: int, age: float) -> Dictionary:
	config.sanitize()
	# Fixed hash-like sequence: stable across replay and independent of frame rate.
	var variation := fposmod(float(index) * 0.618034, 1.0)
	var half_spread := deg_to_rad(config.spark_spread_degrees)*0.5
	var angle := PI + lerpf(-half_spread, half_spread, variation)
	var velocity := Vector2.from_angle(angle) * (48.0 + fposmod(index * 37.0, 105.0)) * strength * config.spark_speed
	var lifetime := (0.24 + fposmod(index * 0.137, 0.38))*config.spark_lifetime
	var point := velocity * age + Vector2(0, 85.0 * age * age)
	return {"position": point.rotated(direction.angle()), "velocity": (velocity + Vector2(0, 170.0 * age)).rotated(direction.angle()), "alive": age >= 0.0 and age < lifetime, "life": clampf(1.0 - age / lifetime, 0.0, 1.0)}
