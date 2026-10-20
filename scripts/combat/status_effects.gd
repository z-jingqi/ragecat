class_name StatusEffects
extends RefCounted
## Independent DOT clocks. Refreshing never resets the next tick; DOT never procs.
var tick_interval: float
var default_duration: float
var poison_remaining: float = 0.0
var bleed_remaining: float = 0.0
var poison_dps: float = 0.0
var bleed_dps: float = 0.0
var _poison_clock: float = 0.0
var _bleed_clock: float = 0.0

func _init(definition: CombatDefinition = null) -> void:
	configure(definition if definition != null else CombatDefinition.new())

func configure(definition: CombatDefinition) -> void:
	var config := definition.validated_copy()
	tick_interval = config.status_tick_interval
	default_duration = config.default_status_duration

func has_poison() -> bool:
	return poison_remaining > 0.0

func has_bleed() -> bool:
	return bleed_remaining > 0.0

func apply_poison(dps: float, duration: float = -1.0) -> void:
	if duration < 0.0: duration = default_duration
	if not is_finite(dps) or not is_finite(duration) or dps <= 0.0 or duration <= 0.0:
		return
	if not has_poison():
		_poison_clock = 0.0
		poison_dps = dps
	else:
		poison_dps = maxf(poison_dps, dps)
	poison_remaining = maxf(poison_remaining, duration)

func apply_bleed(dps: float, duration: float = -1.0) -> void:
	if duration < 0.0: duration = default_duration
	if not is_finite(dps) or not is_finite(duration) or dps <= 0.0 or duration <= 0.0:
		return
	if not has_bleed():
		_bleed_clock = 0.0
		bleed_dps = dps
	else:
		bleed_dps = maxf(bleed_dps, dps)
	bleed_remaining = maxf(bleed_remaining, duration)

func apply_arrow(stats: CombatStats) -> void:
	apply_poison(stats.poison_dps, stats.poison_duration)
	apply_bleed(stats.bleed_dps, stats.bleed_duration)

func tick(delta: float) -> float:
	if not is_finite(delta): return 0.0
	var damage: float = 0.0
	var elapsed: float = maxf(delta, 0.0)
	if has_poison():
		_poison_clock += minf(elapsed, poison_remaining)
		poison_remaining = maxf(0.0, poison_remaining - elapsed)
		var ticks := floorf((_poison_clock + 0.000001) / tick_interval)
		_poison_clock = maxf(0.0, _poison_clock - ticks * tick_interval)
		damage += poison_dps * ticks * tick_interval
	if has_bleed():
		_bleed_clock += minf(elapsed, bleed_remaining)
		bleed_remaining = maxf(0.0, bleed_remaining - elapsed)
		var ticks := floorf((_bleed_clock + 0.000001) / tick_interval)
		_bleed_clock = maxf(0.0, _bleed_clock - ticks * tick_interval)
		damage += bleed_dps * ticks * tick_interval
	return damage
