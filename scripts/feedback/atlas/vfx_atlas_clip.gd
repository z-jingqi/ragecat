class_name VfxAtlasClip
extends Resource
## A baked visual, never a gameplay timer or hit shape. Frames contain straight RGBA.
@export var id: StringName
@export var texture: Texture2D
@export_range(1, 16, 1) var columns: int = 4
@export_range(1, 16, 1) var rows: int = 4
@export_range(1, 256, 1) var frames: int = 16
@export_range(1, 120, 1) var fps: float = 24.0
@export var loop: bool = false
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0
@export_range(0.1, 4.0, 0.05) var size_multiplier: float = 1.0

func valid() -> bool:
	return texture != null and columns > 0 and rows > 0 and frames > 0 and frames <= columns * rows and is_finite(fps) and fps > 0 and texture.get_width() > 0 and texture.get_height() > 0

func frame_at(time: float, normalized: bool = false) -> int:
	if not is_finite(time) or time < 0.0: return 0
	if normalized: return mini(maxi(0, frames - 1), floori(clampf(time, 0.0, 1.0) * frames))
	var frame := floori(time * maxf(1.0, fps))
	return posmod(frame, maxi(1, frames)) if loop else clampi(frame, 0, maxi(0, frames - 1))

func source_rect(time: float, normalized: bool = false) -> Rect2:
	if not valid(): return Rect2()
	var cell := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var index := frame_at(time, normalized)
	return Rect2(Vector2(index % columns, index / columns) * cell, cell)
