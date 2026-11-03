# Made by Sprite Fusion. MIT License. Copyright (c) 2026 Hugo Duprez.
# Direct native GDScript port of fog.ts. Scalar operations remain binary64;
# noise, edges, and breaths retain source Float32Array write coercions.
extends RefCounted
class_name SFExactFog
const M = preload("res://scripts/core/sf_math.gd")
const Px = preload("res://scripts/core/sf_px_source.gd")
const T0 = 0.3
const T1 = 0.52
const T2 = 0.74
const BW = 0.07
const FW = 256
const FH = 128
const PX = 2.0
var density: float
var wind: float
var layers: float
var tones: PackedInt64Array
var field: PackedFloat32Array
var x_min: float
var x_max: float
var bottom_y: float
var area_height: float
var t: float = 0.0
var stop_at: float = INF
var edges: PackedFloat32Array = PackedFloat32Array()
var breaths: PackedFloat32Array = PackedFloat32Array()

func configure(options = {}):
	var area = options.get("area", {"x": 0.0, "y": 470.0, "w": 1280.0, "h": 150.0})
	density = options.get("density", 1.0)
	wind = options.get("wind", 22.0)
	layers = maxf(1.0, minf(4.0, options.get("layers", 3.0)))
	tones = PackedInt64Array()
	for color in options.get("colors", ["#3b3f63", "#5a6185", "#8389a8"]): tones.append(M.hex(color))
	field = bake(options.get("seed", 1.0))
	x_min = area.x / PX
	x_max = (area.x + area.w) / PX
	bottom_y = (area.y + area.h) / PX
	area_height = area.h / PX
	t = 0.0
	stop_at = INF
	edges = PackedFloat32Array()
	breaths = PackedFloat32Array()
	return self

func update(dt: float) -> void:
	t += dt

func level() -> float:
	return clampf(1.0 - (t - stop_at) / 2.5, 0.0, 1.0)

func stop() -> void:
	if stop_at == INF: stop_at = t

func done() -> bool:
	return level() <= 0.0

func dispose() -> void:
	pass

func draw(frame, layer = "") -> void:
	var buffer
	if frame is Dictionary:
		buffer = Px.new(frame, frame.color)._pixels
	else:
		buffer = frame.color
	var i: float = 0.0
	while i < layers:
		if layer != ("back" if layers > 1.0 and i == layers - 1.0 else "front"):
			bank(buffer, 0.5 if layers == 1.0 else i / (layers - 1.0), i)
		i += 1.0

func bank(buf, depth: float, bank_index: float) -> void:
	var top: float = bottom_y - area_height * (1.0 - 0.62 * depth)
	var base: float = top + (bottom_y - top) * 0.8
	var bottom: float = bottom_y + area_height * (0.03 + 0.16 * depth)
	var sx: float = 0.3 + 0.25 * depth
	var sy: float = 1.5 + 0.8 * depth
	var drift: float = (t * wind * (0.4 + 0.8 * depth)) / PX
	var curl: float = t * (0.6 + 0.5 * depth)
	var alpha: float = (0.2 + 0.16 * depth) * density * level()
	var offset: float = bank_index * 97.3
	var y0: float = maxf(buf.oy, floor(top))
	var y1: float = minf(buf.oy + buf.h - 1.0, ceil(bottom))
	var x0: float = maxf(buf.ox, floor(x_min))
	var x1: float = minf(buf.ox + buf.w - 1.0, ceil(x_max))
	if alpha <= 0.01 or y0 > y1 or x0 > x1: return
	var crest: int = M.mix(tones[2], M.hex("#ffffff"), 0.14 + 0.12 * depth)
	var dense: float = 0.6 + 0.5 * density
	if edges.size() < x1 - x0 + 1.0:
		edges.resize(int(x1 - x0 + 1.0))
		breaths.resize(int(x1 - x0 + 1.0))
	var x: float = x0
	while x <= x1:
		edges[int(x - x0)] = M.smooth(x_min, x_min + 40.0, x) * (1.0 - M.smooth(x_max - 40.0, x_max, x))
		breaths[int(x - x0)] = 2.4 * sin(t * 0.35 + x * 0.013 + bank_index * 1.7)
		x += 1.0
	var y: float = y0
	while y <= y1:
		var p: float = M.smooth(top, base, y) * (1.0 - M.smooth(bottom - 3.0, bottom + 1.0, y))
		var p_up: float = M.smooth(top, base, y - 2.0) * (1.0 - M.smooth(bottom - 3.0, bottom + 1.0, y - 2.0))
		if p <= 0.02:
			y += 1.0
			continue
		var wu: float = 0.0
		x = x0
		while x <= x1:
			var edge: float = edges[int(x - x0)]
			if edge <= 0.02:
				x += 1.0
				continue
			if (M.i32(x - x0) & 1) == 0: wu = sample_field(x * 0.35 + curl * 9.0 + offset, y * 0.6 - curl * 3.0) - 0.5
			var breath: float = breaths[int(x - x0)]
			var u: float = x * sx - drift + wu * 30.0 + offset
			var f: float = thickness(p, sample_field(u, (y + breath) * sy + wu * 12.0), dense) * edge
			var b: float = M.bayer(x, y)
			var color_index: int = -1
			if f > T2 + BW or (f > T2 and (f - T2) / BW > b): color_index = 2
			elif f > T1 + BW or (f > T1 and (f - T1) / BW > b): color_index = 1
			elif f > T0 + BW or (f > T0 and (f - T0) / BW > b): color_index = 0
			if color_index < 0:
				x += 1.0
				continue
			if color_index >= 1 and thickness(p_up, sample_field(u, (y - 2.0 + breath) * sy + wu * 12.0), dense) * edge < (T2 if color_index == 2 else T1) - 0.03:
				buf.blend(x, y, crest, alpha * (0.95 + 0.15 * color_index))
				x += 1.0
				continue
			buf.blend(x, y, tones[color_index], alpha * (0.6 + 0.2 * color_index))
			x += 1.0
		y += 1.0

static func thickness(profile: float, noise_value: float, dense: float) -> float:
	return (profile * 0.72 + (clampf((noise_value - 0.5) * 2.6 + 0.5, 0.0, 1.0) - 0.5) * 0.95) * dense

static func grid_hash(a: float, b: float, cells: float, rows: float, seed_value: float) -> float:
	return M.hash(fmod(fmod(a, cells) + cells, cells) + fmod(fmod(b, rows) + rows, rows) * 1000.0, seed_value * 31.0 + cells)

static func bake(seed_value: float) -> PackedFloat32Array:
	var output: PackedFloat32Array = PackedFloat32Array()
	output.resize(FW * FH)
	output.fill(0.0)
	var amplitude: float = 0.5
	var total: float = 0.0
	for cells in [4.0, 8.0, 16.0, 32.0]:
		var cs: float = float(FW) / cells
		var rows: float = float(FH) / cs
		for y in range(FH):
			for x in range(FW):
				var gx: float = x / cs
				var gy: float = y / cs
				var ix: float = floor(gx)
				var iy: float = floor(gy)
				var u: float = gx - ix
				var v: float = gy - iy
				var su: float = u * u * (3.0 - 2.0 * u)
				var sv: float = v * v * (3.0 - 2.0 * v)
				var top: float = grid_hash(ix, iy, cells, rows, seed_value) + (grid_hash(ix + 1.0, iy, cells, rows, seed_value) - grid_hash(ix, iy, cells, rows, seed_value)) * su
				var bot: float = grid_hash(ix, iy + 1.0, cells, rows, seed_value) + (grid_hash(ix + 1.0, iy + 1.0, cells, rows, seed_value) - grid_hash(ix, iy + 1.0, cells, rows, seed_value)) * su
				output[y * FW + x] += (top + (bot - top) * sv) * amplitude
		total += amplitude
		amplitude *= 0.5
	for i in range(output.size()): output[i] = output[i] / total
	return output

func sample_field(u: float, v: float) -> float:
	var x: float = floor(u)
	var y: float = floor(v)
	var fx: float = u - x
	var fy: float = v - y
	var x0: int
	var y0: int
	# floor already produced integral binary64 values. In signed32 range,
	# int equals JS ToInt32; masking preserves the same periodic field index.
	# NaN, infinities and larger values retain the original helper semantics.
	if x >= -2147483648.0 and x <= 2147483647.0 and y >= -2147483648.0 and y <= 2147483647.0:
		x0 = int(x) & (FW - 1)
		y0 = int(y) & (FH - 1)
	else:
		x0 = M.i32(x) & (FW - 1)
		y0 = M.i32(y) & (FH - 1)
	var x1: int = (x0 + 1) & (FW - 1)
	var y1: int = (y0 + 1) & (FH - 1)
	var a: float = field[y0 * FW + x0]
	var b: float = field[y0 * FW + x1]
	var c: float = field[y1 * FW + x0]
	var d: float = field[y1 * FW + x1]
	return a + (b - a) * fx + (c - a + (a - b - c + d) * fx) * fy
