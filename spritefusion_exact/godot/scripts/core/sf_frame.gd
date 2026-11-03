# One mutable art-resolution frame. Pass color/light objects, not packed-array copies.
extends RefCounted
const PixelBuffer = preload("res://scripts/core/sf_pixel_buffer.gd")
var w: int
var h: int
var ox: float
var oy: float
var color
var light

func _init(width: int, height: int, origin_x: float = 0.0, origin_y: float = 0.0) -> void:
	w = width
	h = height
	ox = origin_x
	oy = origin_y
	color = PixelBuffer.new(w, h, ox, oy)
	light = PixelBuffer.new(w, h, ox, oy)

func clear() -> void:
	color.clear()
	light.clear()

func set_origin(x: float, y: float) -> void:
	ox = x
	oy = y
	color.ox = x
	color.oy = y
	light.ox = x
	light.oy = y

func as_source() -> Dictionary:
	# Godot 4 Packed arrays share indexed mutation, just as JS Uint32Array does.
	# JS compatibility runtime MUST coerce writes to uint32; PackedInt64Array does not.
	return {"w": w, "h": h, "ox": ox, "oy": oy, "color": color.data, "light": light.data}
