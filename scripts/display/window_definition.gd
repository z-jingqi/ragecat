class_name WindowDefinition
extends Resource
## Window pixels only. Fullscreen keeps the monitor's native desktop mode.
@export var presets: Array[Vector2i] = [Vector2i(960, 600), Vector2i(1152, 720), Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1440, 900), Vector2i(1600, 900), Vector2i(1600, 1000), Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(2560, 1440)]
@export_range(0.5, 1.0) var initial_screen_fraction := 0.9
@export var decoration_margin := Vector2i(32, 64)
@export_range(5.0, 30.0) var confirmation_seconds := 15.0

## Native OS transitions may finish after the mode setter returns.
@export_range(0.05, 0.5) var window_settle_seconds := 0.15
@export_range(0.5, 5.0) var apply_timeout_seconds := 2.0
