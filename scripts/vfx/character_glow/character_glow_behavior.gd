extends "res://scripts/vfx/shared/component_lifecycle.gd"
const Config=preload("res://scripts/vfx/character_glow/character_glow_config.gd")
func _init() -> void: config=Config.new()
