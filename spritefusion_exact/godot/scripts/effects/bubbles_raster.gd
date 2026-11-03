# Direct native versions of bubbles.ts's three environment raster functions.
# MIT License, Copyright (c) 2026 Hugo Duprez. No samples or passes omitted.
extends RefCounted
const M = preload("res://scripts/core/sf_math.gd")
const JS = preload("res://scripts/core/sf_js.gd")

static func surface(buf, light, top: float, x_min: float, x_max: float, t: float, hi: int, lit: int, rim: int, shade: int) -> void:
	var y0: float = top / 2.0
	var x0: float = maxf(buf.ox, floor(x_min / 2.0))
	var x1: float = minf(buf.ox + buf.w - 1.0, ceil(x_max / 2.0))
	var x: float = x0
	while x <= x1:
		var sy: float = M.js_round(y0 + (sin(x * 0.11 + t * 1.6) * 1.2 + sin(x * 0.043 - t * 0.9) * 1.6))
		var glint: bool = sin(x * 0.37 - t * 2.3) * sin(x * 0.13 + t * 1.1) > 0.55
		buf.put(x, sy, hi if glint else lit)
		buf.put(x, sy + 1.0, rim)
		for k in range(2, 7):
			if M.bayer(x, sy + k) < 0.5 - k * 0.07: buf.put(x, sy + k, shade)
		if (M.i32(x) & 3) == 0: light.glow(x, sy + 2.0, 7.0, lit, 0.2 if glint else 0.09)
		x += 1.0

static func caustics(light, top_world: float, x_min: float, x_max: float, t: float, ground_at: Callable, lit: int, rim: int) -> void:
	var gy: float = M.js_round(JS.invoke(ground_at, [(x_min + x_max) / 2.0]) / 2.0)
	var top: float = floor(top_world / 2.0)
	var x0: float = maxf(light.ox, floor(x_min / 2.0))
	var x1: float = minf(light.ox + light.w - 1.0, ceil(x_max / 2.0))
	var y0: float = maxf(light.oy, top)
	var y1: float = minf(light.oy + light.h - 1.0, gy + 6.0)
	var y: float = y0
	while y <= y1:
		var k: float = 1.0 if y >= gy - 1.0 else 0.18 + 0.32 * (1.0 - (y - top) / maxf(1.0, gy - top))
		var x: float = x0
		while x <= x1:
			var u: float = x * 0.16 + 1.9 * sin(y * 0.12 + t * 0.9)
			var v: float = y * 0.19 + 1.9 * sin(x * 0.1 - t * 0.7)
			var n1: float = sin(u) + sin(v)
			var n2: float = sin(x * 0.09 + y * 0.07 + 1.4 * sin(y * 0.15 - t * 0.6)) + sin(y * 0.11 - x * 0.05 + 1.4 * sin(x * 0.13 + t * 0.8))
			var f: float = (maxf(0.0, 1.0 - absf(n1) * 3.0) + 0.7 * maxf(0.0, 1.0 - absf(n2) * 3.0)) * k
			var d: float = M.bayer(x, y)
			if f > 1.05 or (f > 0.8 and d < (f - 0.8) / 0.25): light.add(x, y, lit, 0.3)
			elif f > 0.45 or (f > 0.3 and d < (f - 0.3) / 0.15): light.add(x, y, rim, 0.15)
			x += 1.0
		y += 1.0

static func tint(buf, top_world: float, x_min: float, x_max: float, ground_at: Callable, water: int) -> void:
	var top: float = floor(top_world / 2.0)
	var gy: float = ceil(JS.invoke(ground_at, [(x_min + x_max) / 2.0]) / 2.0) + 1.0
	var x0: float = maxf(buf.ox, floor(x_min / 2.0))
	var x1: float = minf(buf.ox + buf.w - 1.0, ceil(x_max / 2.0))
	var y: float = maxf(buf.oy, top)
	while y <= minf(buf.oy + buf.h - 1.0, gy):
		var x: float = x0
		while x <= x1:
			buf.blend(x, y, water, 0.2 + 0.12 * ((y - top) / maxf(1.0, gy - top)))
			x += 1.0
		y += 1.0
