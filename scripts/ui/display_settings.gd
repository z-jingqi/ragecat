class_name DisplaySettings
extends RefCounted
## Cosmetic preferences only. Empty language means follow the first system locale.
const PATH := "user://display_settings.cfg"
var show_enemy_health: bool = true
var sound_enabled: bool = true
var language: String = ""
func load_settings(path: String = PATH) -> void:
	show_enemy_health = true
	sound_enabled = true
	language = ""
	var config := ConfigFile.new()
	if config.load(path) != OK: return
	var saved: Variant = config.get_value("display", "enemy_health_bars", true)
	if saved is bool: show_enemy_health = saved
	var sound: Variant = config.get_value("audio", "enabled", true)
	if sound is bool: sound_enabled = sound
	var choice: Variant = config.get_value("display", "language", "")
	if choice is String and choice in GameLocale.SUPPORTED: language = choice
func resolved_language(system: String = OS.get_locale()) -> String:
	return language if language in GameLocale.SUPPORTED else GameLocale.system_locale(system)
func save_settings(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	# Preserve unrelated settings written by other cosmetic features.
	config.load(path)
	config.set_value("display", "enemy_health_bars", show_enemy_health)
	config.set_value("audio", "enabled", sound_enabled)
	config.set_value("display", "language", language)
	return config.save(path)
