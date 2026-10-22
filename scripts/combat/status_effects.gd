class_name StatusEffects
extends RefCounted
## Ice control belongs to the bow's ice skill, never to elemental damage alone.
## All timers use game seconds and keep running when an actor cannot move.
const TIMER_EPSILON: float = 0.000001
var shock_remaining: float = 0.0
var shock_bonus: float = 0.0
var chill_remaining: float = 0.0
var frost_stacks: int = 0
var frost_remaining: float = 0.0
var frozen_remaining: float = 0.0
var ice_mark_remaining: float = 0.0
var immunity_remaining: float = 0.0
var _chill_fraction: float = 0.0
var _thaw_immunity: float = 0.0

func apply_ice(skill: ElementSkillDefinition, rank: int, boss: bool = false) -> void:
	if skill == null or rank <= 0:
		return
	_chill_fraction = clampf(_nonnegative(skill.boss_chill_fraction if boss else skill.chill_fraction), 0.0, 1.0)
	chill_remaining = _nonnegative(skill.chill_duration)
	# Bosses retain their attack timings and committed charge movement.
	if boss:
		if has_ice_mark(): return
		frost_stacks += 1
		frost_remaining = _nonnegative(skill.frost_window)
		if frost_stacks >= maxi(1, skill.boss_frost_threshold):
			frost_stacks = 0
			frost_remaining = 0.0
			ice_mark_remaining = _nonnegative(skill.boss_mark_duration)
		return
	# Hits may refresh chill, but cannot extend a freeze or build the next one
	# during the frozen interval or the immunity that starts after thawing.
	if is_frozen() or immunity_remaining > 0.0:
		return
	frost_stacks += 1
	frost_remaining = _nonnegative(skill.frost_window)
	if frost_stacks < maxi(1, skill.frost_threshold):
		return
	frost_stacks = 0
	frost_remaining = 0.0
	if skill.freeze_by_rank.is_empty():
		return
	frozen_remaining = _nonnegative(skill.freeze_by_rank[clampi(rank, 0, skill.freeze_by_rank.size() - 1)])
	_thaw_immunity = _nonnegative(skill.thaw_immunity)

func apply_shock(skill: ElementSkillDefinition, rank: int) -> void:
	if skill == null or rank <= 0: return
	if shock_remaining <= 0.0:
		shock_bonus = _nonnegative(skill.parameter(skill.shock_bonus_by_rank, rank))
	shock_remaining = _nonnegative(skill.shock_duration)

func elemental_multiplier() -> float:
	return 1.0 + shock_bonus if shock_remaining > 0.0 else 1.0

func has_ice_mark() -> bool:
	return ice_mark_remaining > 0.0

func consume_ice() -> bool:
	# Called once immediately before resolving a direct ice packet. No derived
	# effect enters this path; the packet records consumption for proc dispatch.
	if has_ice_mark():
		ice_mark_remaining = 0.0
		return true
	if is_frozen():
		frozen_remaining = 0.0
		immunity_remaining = _thaw_immunity
		return true
	return false

func tick(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	shock_remaining = _remaining(shock_remaining - delta)
	if shock_remaining <= 0.0: shock_bonus = 0.0
	ice_mark_remaining = _remaining(ice_mark_remaining - delta)
	chill_remaining = _remaining(chill_remaining - delta)
	frost_remaining = _remaining(frost_remaining - delta)
	if frost_remaining <= 0.0:
		frost_stacks = 0
	if is_frozen():
		var before_thaw: float = frozen_remaining
		frozen_remaining = _remaining(frozen_remaining - delta)
		if not is_frozen():
			# Large frames consume only the part after thaw from immunity.
			immunity_remaining = _remaining(_thaw_immunity - maxf(0.0, delta - before_thaw))
	else:
		immunity_remaining = _remaining(immunity_remaining - delta)

func is_frozen() -> bool:
	return frozen_remaining > 0.0

func movement_multiplier() -> float:
	if is_frozen():
		return 0.0
	return 1.0 - _chill_fraction if chill_remaining > 0.0 else 1.0

func movement_time(delta: float) -> float:
	# Integrate motion before tick(), so a thaw or chill expiry in a long frame
	# neither releases an actor early nor slows the whole frame after expiry.
	if not is_finite(delta) or delta <= 0.0:
		return 0.0
	var moving_time: float = maxf(0.0, delta - frozen_remaining)
	var chilled_time: float = clampf(chill_remaining - frozen_remaining, 0.0, moving_time)
	return moving_time - chilled_time * _chill_fraction

func clear() -> void:
	shock_remaining = 0.0
	shock_bonus = 0.0
	ice_mark_remaining = 0.0
	chill_remaining = 0.0
	frost_stacks = 0
	frost_remaining = 0.0
	frozen_remaining = 0.0
	immunity_remaining = 0.0
	_chill_fraction = 0.0
	_thaw_immunity = 0.0

static func _nonnegative(value: float) -> float:
	return maxf(0.0, value) if is_finite(value) else 0.0

static func _remaining(value: float) -> float:
	return value if value > TIMER_EPSILON else 0.0
