class_name BurnEffect
extends RefCounted
## A single immutable DPS snapshot. Refresh extends life, never resets tick phase.
## Returns elapsed damage quanta; the arena owns health, accounting and feedback.
const EPSILON: float = 0.000001
var target: WeakRef
var remaining: float = 0.0
var dps: float = 0.0
var interval: float = 0.25
var accrued: float = 0.0
var color: Color

func _init(enemy: EnemyActor, source_elemental: float, skill: ElementSkillDefinition, rank: int) -> void:
	target = weakref(enemy)
	remaining = skill.burn_duration
	dps = maxf(0.0, source_elemental) * skill.parameter(skill.burn_dps_by_rank, rank)
	interval = maxf(0.001, skill.burn_tick_interval)
	color = skill.color

func refresh(duration: float) -> void:
	remaining = maxf(0.0, duration)

func tick(delta: float) -> PackedFloat64Array:
	var amounts := PackedFloat64Array()
	if not is_finite(delta) or delta <= 0.0 or remaining <= 0.0: return amounts
	var elapsed := minf(delta, remaining)
	remaining = maxf(0.0, remaining - elapsed)
	if remaining < EPSILON: remaining = 0.0
	accrued += elapsed
	while accrued + EPSILON >= interval:
		amounts.append(dps * interval)
		accrued = maxf(0.0, accrued - interval)
	# Preserve fractional final time, including non-multiple resource durations.
	if remaining <= 0.0 and accrued > EPSILON:
		amounts.append(dps * accrued)
		accrued = 0.0
	return amounts
