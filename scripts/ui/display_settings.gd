class_name DisplaySettings
extends RefCounted
## Only cosmetic display preferences are persisted; no run/practice state.
const PATH := "user://display_settings.cfg"
var show_enemy_health: bool = true
var sound_enabled: bool = true
func load_settings(path: String = PATH) -> void:
	show_enemy_health = true
	sound_enabled = true
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved: Variant = config.get_value("display", "enemy_health_bars", true)
	if saved is bool: show_enemy_health = saved
	var sound: Variant = config.get_value("audio", "enabled", true)
	if sound is bool: sound_enabled = sound
func save_settings(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("display", "enemy_health_bars", show_enemy_health)
	config.set_value("audio", "enabled", sound_enabled)
	return config.save(path)
