class_name ProgressionDefinition
extends Resource

@export var starter_upgrades: PackedStringArray
@export var achievements: Array[AchievementDefinition]
@export_range(1.0, 60.0, 1.0) var save_interval: float = 10.0
@export_range(1.0, 20.0, 0.5) var notification_duration: float = 4.0
@export_range(1, 8, 1) var rows_per_page: int = 4

func metric_cap(metric: String) -> int:
	var result := 0
	for item in achievements:
		if item.metric == metric: result = maxi(result, item.target)
	return result

func validated_copy() -> ProgressionDefinition:
	var copy := duplicate(true) as ProgressionDefinition
	copy.save_interval = clampf(copy.save_interval, 1.0, 60.0) if is_finite(copy.save_interval) else 10.0
	copy.notification_duration = clampf(copy.notification_duration, 1.0, 20.0) if is_finite(copy.notification_duration) else 4.0
	copy.rows_per_page = clampi(copy.rows_per_page, 1, 8)
	copy.achievements.clear()
	var seen: Array[String] = []
	for item in achievements:
		if item == null or item.achievement_id.is_empty() or seen.has(item.achievement_id) or item.metric not in ["kills", "survival", "bosses"]: continue
		seen.append(item.achievement_id)
		copy.achievements.append(item.validated_copy())
	return copy
