class_name DisplaySettings
extends RefCounted
## Only cosmetic display preferences are persisted; no run/practice state.
const PATH := "user://display_settings.cfg"
var show_enemy_health: bool = true
func load_settings(path: String = PATH) -> void:
	show_enemy_health = true
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved: Variant = config.get_value("display", "enemy_health_bars", true)
	if saved is bool: show_enemy_health = saved
func save_settings(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "enemy_health_bars", show_enemy_health)
	return config.save(path)
