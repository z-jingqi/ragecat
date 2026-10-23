class_name AchievementDefinition
extends Resource

@export var achievement_id: String
@export_enum("kills", "survival", "bosses") var metric: String = "kills"
@export_range(1, 100000, 1) var target: int = 1
@export var reward_label_key: String
@export var rewards: PackedStringArray

func validated_copy() -> AchievementDefinition:
	var copy := duplicate(true) as AchievementDefinition
	copy.target = clampi(copy.target, 1, 100000)
	return copy
