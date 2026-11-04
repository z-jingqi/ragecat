# Original Sprite Fusion drawLens ring plan. MIT, Copyright 2026 Hugo Duprez.
# Function body is copied byte-for-byte from the already tested host adapter.
extends RefCounted
const JS = preload("res://scripts/core/sf_js.gd")
const Math = preload("res://scripts/core/sf_math.gd")

static func build_plan(lens: Dictionary) -> Dictionary:
	var rs: float = lens.rs
	var r_e: float = lens.rE
	var r_out: float = lens.rOut
	var twist: float = lens.twist
	if rs < 1.0 or r_out < rs + 4.0: return {}
	var size = ceil(r_out * 2.0) + 4.0
	var half = size / 2.0
	var radii: Array = []
	var tolerance = 2.5
	while true:
		radii.clear()
		var r = rs * 0.95
		radii.append(r)
		while r < r_out:
			var q = r_e / r
			var jump = q * q + 1.5 * twist * pow(q, 1.5)
			r = minf(r_out, r + maxf(0.75, minf(32.0, tolerance / jump)))
			radii.append(r)
		if radii.size() <= 110: break
		tolerance *= 1.5
	var rings: Array = []
	for i in range(radii.size() - 1, 0, -1):
		var r1 = radii[i]
		var rm = (radii[i - 1] + r1) / 2.0
		var fade = Math.smooth(r_out * 0.45, r_out, rm)
		var scale_factor = ((rm - (r_e * r_e) / rm) / rm) * (1.0 - fade) + fade
		var rotation = -twist * minf(1.6, pow(r_e / rm, 1.5)) * (1.0 - fade)
		var should_draw = not (absf(scale_factor - 1.0) < 0.003 and absf(rotation) < 0.002)
		if absf(scale_factor) < 0.02: scale_factor = -0.02 if scale_factor < 0.0 else 0.02
		var inverse = 1.0 / scale_factor
		var c = cos(rotation) * inverse
		var sn = sin(rotation) * inverse
		rings.append({"radius":r1,"scale":scale_factor,"rotation":rotation,"crop":minf(half,r1*absf(scale_factor)+1.0),"draw":should_draw,"canvas_transform":[c,sn,-sn,c,lens.x-(c-sn)*half,lens.y-(sn+c)*half]})
	return {
		"size":size,"half":half,"rings":rings,"tolerance":tolerance,
		"gloom_inner":float(JS.call_method(minf(0.85,0.55*lens.gloom),"toFixed",[3])),
		"gloom_middle":float(JS.call_method(minf(0.5,0.26*lens.gloom),"toFixed",[3])),
	}
