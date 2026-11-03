# Source-class adapter for mechanically translated Sprite Fusion Px.
# Uses the golden-tested native rasterizer instead of per-pixel JS dispatch.
# Original algorithms: MIT, Copyright (c) 2026 Hugo Duprez.
extends RefCounted
const NativePx = preload("res://scripts/core/sf_pixel_buffer.gd")
var _pixels
var _fire: bool = false
var _sf_f_w:
	get: return _pixels.w
var _sf_f_h:
	get: return _pixels.h
var _sf_f_ox:
	get: return _pixels.ox
var _sf_f_oy:
	get: return _pixels.oy
var _sf_f_data:
	get: return _pixels.data

func _init(frame, words: PackedInt64Array, fire_indexing: bool = false) -> void:
	# Avoid allocating a second screen-size array for every draw/Px constructor.
	_pixels = NativePx.new(1, 1)
	_pixels.w = int(frame.w)
	_pixels.h = int(frame.h)
	_pixels.ox = float(frame.ox)
	_pixels.oy = float(frame.oy)
	_pixels.data = words
	_fire = fire_indexing

func _sf_m_at(x, y) -> int:
	return _pixels.at(x, y)

func _sf_m_set(x, y, c) -> void:
	_pixels.put(x, y, int(c))

func _sf_m_blend(x, y, c, a) -> void:
	_pixels.blend(x, y, int(c), a)

func _sf_m_add(x, y, c, k) -> void:
	if _fire:
		_pixels.add_fire(x, y, int(c), k)
	else:
		_pixels.add(x, y, int(c), k)

func _sf_m_disc(cx, cy, r, c, a = 1.0) -> void:
	_pixels.disc(cx, cy, r, int(c), a)

func _sf_m_alphaDisc(cx, cy, r, c, a) -> void:
	_pixels.alpha_disc(cx, cy, r, int(c), a)

func _sf_m_ring(cx, cy, r, thick, c, alpha = 1.0) -> void:
	_pixels.ring(cx, cy, r, thick, int(c), alpha)

func _sf_m_line(x0, y0, x1, y1, c) -> void:
	_pixels.line(x0, y0, x1, y1, int(c))

func _sf_m_glow(cx, cy, r, c, k) -> void:
	_pixels.glow(cx, cy, r, int(c), k, _fire)
