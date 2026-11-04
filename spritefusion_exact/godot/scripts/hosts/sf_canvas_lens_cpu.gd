# Native procedural Canvas lens composition; bounded independent checks are in the docs.
# Sprite Fusion original drawLens algorithm: MIT, Copyright 2026 Hugo Duprez.
# Skia-derived stages retain their BSD-3-Clause notices in the helper files.
# No external browser, reference frame, prerecorded texture, or Python runtime.
extends RefCounted
const Plan = preload("res://scripts/hosts/sf_lens_plan.gd")
const Snapshot = preload("res://scripts/hosts/sf_canvas_snapshot.gd")
const Circle = preload("res://scripts/hosts/sf_canvas_clip.gd")
const RasterImage = preload("res://scripts/hosts/sf_canvas_image.gd")
# These source-based components are prepared independently and gated separately.
const Rectangle = preload("res://scripts/hosts/sf_canvas_rect.gd")
const Fills = preload("res://scripts/hosts/sf_canvas_fills_fma.gd")
var last_diagnostics: Dictionary = {}

static func mask_bounds(mask: PackedByteArray, width: int, height: int) -> Rect2i:
	assert(mask.size() == width * height)
	var left := width
	var top := height
	var right := 0
	var bottom := 0
	for y in range(height):
		for x in range(width):
			if mask[y * width + x] != 0:
				left = mini(left, x)
				right = maxi(right, x + 1)
				top = mini(top, y)
				bottom = maxi(bottom, y + 1)
	return Rect2i(left, top, right - left, bottom - top) if right > left and bottom > top else Rect2i()

func build(background: PackedByteArray, width: int, height: int, lens: Dictionary, apply_final_fills: bool = true) -> PackedByteArray:
	assert(background.size() == width * height * 4)
	for i in range(3, background.size(), 4):
		assert(background[i] == 255, "Current host scope requires an opaque scene")
	var output := background.duplicate()
	var plan := Plan.build_plan(lens)
	if plan.is_empty():
		last_diagnostics = {"active":false,"whole_lens_accepted":false}
		return output
	var snapshot := Snapshot.build(background, width, height, lens.x, lens.y, int(plan["size"]))
	var circle = Circle.new()
	circle.support_legacy_conic_chop = true
	var rectangle = Rectangle.new()
	var ring_count := 0
	var covered_pixels := 0
	for ring in plan.rings:
		if not ring.draw: continue
		var circular: PackedByteArray = circle.build_circle(width, height, lens.x, lens.y, ring.radius)
		assert(circular.size() == width * height, circle.last_error)
		var bounds := mask_bounds(circular, width, height)
		if not bounds.has_area(): continue
		var half: float = plan.half
		var extent: float = ring.crop
		var args: Array = [half - extent, half - extent, extent * 2.0, extent * 2.0, half - extent, half - extent, extent * 2.0, extent * 2.0]
		var edges: PackedByteArray = rectangle.build_image_edge(width, height, ring.canvas_transform, args, true, bounds)
		assert(edges.size() == width * height)
		var inverse := RasterImage.inverse_affine(ring.canvas_transform)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var pixel := y * width + x
				var coverage := RasterImage.combine_coverage(circular[pixel], edges[pixel])
				if coverage == 0: continue
				var mapped := RasterImage.map_affine_nonfma(inverse, float(x) + 0.5, float(y) + 0.5)
				var source := RasterImage.bilerp_clamp_lowp(snapshot.premultiplied_rgba, snapshot.width, snapshot.height, mapped[0], mapped[1])
				if coverage != 255:
					source = RasterImage.scale_coverage_lowp_x86(source, coverage)
				var offset := pixel * 4
				var destination := output.slice(offset, offset + 4)
				var blended := RasterImage.srcover_lowp(source, destination)
				for channel in range(4): output[offset + channel] = blended[channel]
				covered_pixels += 1
		ring_count += 1
	if apply_final_fills:
		output = Fills.new().apply_fills(output, width, height, lens)
	last_diagnostics = {"active":true,"rings_drawn":ring_count,"ring_covered_pixel_visits":covered_pixels,"snapshot_size":snapshot.width,"final_fills_applied":apply_final_fills,"sampler":"conditional x86 lowp, separate non-FMA mapping","circle_conics":"Chrome 155 legacy chop","whole_lens_accepted":false}
	return output
