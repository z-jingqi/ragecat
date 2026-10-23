class_name UpgradeStatModifier
extends Resource
## Additive contributions to explicit stat channels. Ratio channels use fractions;
## damage_percent uses percentage points. Derived multiplication happens once in
## CombatStats, after summation. Negative scale expresses a cost, never an override.
@export_enum("health", "damage_flat", "damage_percent", "attack_speed", "crit_chance", "crit_multiplier", "move_ratio", "pickup_radius", "regen", "knockback_ratio", "knockback_flat", "gravity_pull_bonus", "range_ratio") var channel: String = "health"
## Empty reuses the containing upgrade's values, so existing tuning stays canonical.
@export var values: PackedFloat32Array = []
@export var scale: float = 1.0
const CHANNELS := ["health", "damage_flat", "damage_percent", "attack_speed", "crit_chance", "crit_multiplier", "move_ratio", "pickup_radius", "regen", "knockback_ratio", "knockback_flat", "gravity_pull_bonus", "range_ratio"]
const DESCRIPTION_KEYS := {"health":"DESC_VITALITY", "damage_flat":"DESC_DAMAGE_FLAT", "damage_percent":"DESC_DAMAGE", "attack_speed":"DESC_ATTACK_SPEED", "crit_chance":"DESC_CRIT_CHANCE", "crit_multiplier":"DESC_CRIT_DAMAGE", "move_ratio":"DESC_MOVE_SPEED", "pickup_radius":"DESC_PICKUP", "regen":"DESC_REGEN", "knockback_ratio":"DESC_KNOCKBACK", "knockback_flat":"DESC_KNOCKBACK_FLAT", "gravity_pull_bonus":"DESC_GRAVITY_PULL_BONUS", "range_ratio":"DESC_LONG_DRAW"}
const RATIO_CHANNELS := ["attack_speed", "crit_chance", "move_ratio", "knockback_ratio", "gravity_pull_bonus", "range_ratio"]

func value_at(rank: int, inherited_values: PackedFloat32Array) -> float:
	if rank <= 0 or not CHANNELS.has(channel): return 0.0
	var sequence := values if not values.is_empty() else inherited_values
	if sequence.is_empty(): return 0.0
	var value := float(sequence[clampi(rank, 0, sequence.size() - 1)]) * scale
	return value if is_finite(value) else 0.0

func describe(rank: int, inherited_values: PackedFloat32Array, gravity: GravityDefinition = null) -> String:
	if not DESCRIPTION_KEYS.has(channel): return ""
	var amount := value_at(rank, inherited_values)
	if gravity != null:
		match channel:
			"range_ratio": return (GameLocale.text("DESC_DARK_LONG") % UpgradeDefinition.number(amount * 100.0)).replace("+-", "-")
			"knockback_flat": return ""
			"knockback_ratio", "gravity_pull_bonus": return (GameLocale.text("DESC_DARK_KNOCKBACK") % [UpgradeDefinition.number(amount * gravity.pull_upgrade_scale * 100.0), UpgradeDefinition.number(gravity.pull_multiplier_cap)]).replace("+-", "-")
			"attack_speed": return (GameLocale.text("DESC_DARK_SPEED") % [UpgradeDefinition.number(amount * 100.0), UpgradeDefinition.number(gravity.minimum_gap)]).replace("+-", "-")
	if RATIO_CHANNELS.has(channel): amount *= 100.0
	# Templates may contain a literal '+'. A negative cost is rendered as '-'.
	return (GameLocale.text(DESCRIPTION_KEYS[channel]) % UpgradeDefinition.number(amount)).replace("+-", "-")

func validated_copy() -> UpgradeStatModifier:
	var copy := duplicate(true) as UpgradeStatModifier
	if not is_finite(copy.scale): copy.scale = 0.0
	for index in range(copy.values.size()):
		if not is_finite(copy.values[index]): copy.values[index] = 0.0
	return copy
