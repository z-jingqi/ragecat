class_name StatusEffects
extends RefCounted
## Independent DOT clocks. Refreshing never resets the next tick; DOT never procs.
const TICK_INTERVAL: float = 0.5
var poison_remaining: float = 0.0
var bleed_remaining: float = 0.0
var poison_dps: float = 0.0
var bleed_dps: float = 0.0
var _poison_clock: float = 0.0
var _bleed_clock: float = 0.0

func has_poison() -> bool:
	return poison_remaining > 0.0

func has_bleed() -> bool:
	return bleed_remaining > 0.0

func apply_poison(dps: float, duration: float = 4.0) -> void:
	if dps <= 0.0 or duration <= 0.0:
		return
	if not has_poison():
		_poison_clock = 0.0
		poison_dps = dps
	else:
		poison_dps = maxf(poison_dps, dps)
	poison_remaining = maxf(poison_remaining, duration)

func apply_bleed(dps: float, duration: float = 4.0) -> void:
	if dps <= 0.0 or duration <= 0.0:
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
	var damage: float = 0.0
	var elapsed: float = maxf(delta, 0.0)
	if has_poison():
		_poison_clock += minf(elapsed, poison_remaining)
		poison_remaining = maxf(0.0, poison_remaining - elapsed)
		while _poison_clock + 0.000001 >= TICK_INTERVAL:
			_poison_clock -= TICK_INTERVAL
			damage += poison_dps * TICK_INTERVAL
	if has_bleed():
		_bleed_clock += minf(elapsed, bleed_remaining)
		bleed_remaining = maxf(0.0, bleed_remaining - elapsed)
		while _bleed_clock + 0.000001 >= TICK_INTERVAL:
			_bleed_clock -= TICK_INTERVAL
			damage += bleed_dps * TICK_INTERVAL
	return damage
