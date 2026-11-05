extends "../components/slash_profile.gd"
## Visual-only attachment. Inherits the accepted slash dimensions and timing.
@export_enum("Fire", "Lightning", "Ice") var element := 0
@export var attachment_enabled := true
@export var debris_enabled := true
@export_range(0, 1.8, 0.05) var attachment_strength := 1.0
@export_range(0, 12, 1) var attachment_count := 6
@export_range(0, 16, 1) var debris_count := 8
@export_range(3, 25, 1) var edge_reach := 15.0
@export_range(0.06, 0.3, 0.01) var debris_lifetime := 0.18

func _init() -> void:
	# Match the approved design's long horizontal sweep and broad bright head.
	# Only new elemental instances change; original copper presets stay intact.
	thickness = 24.0
	direction_degrees = -18.0
	sweep_center_degrees = -60.0
	sweep_degrees = 220.0
	squash = 0.45
	apply_palette()

func sanitized():
	var copy = super.sanitized()
	copy.element = clampi(element, 0, 2)
	copy.attachment_count = clampi(attachment_count, 0, 12)
	copy.debris_count = clampi(debris_count, 0, 16)
	for key in ["attachment_strength", "edge_reach", "debris_lifetime"]:
		var bounds = {"attachment_strength": [0., 1.8, 1.], "edge_reach": [3., 25., 15.], "debris_lifetime": [.06, .3, .18]}[key]
		var value := float(get(key))
		copy.set(key, clampf(value, bounds[0], bounds[1]) if is_finite(value) else bounds[2])
	return copy

func apply_palette() -> void:
	var colors = [
		["fffaca", "ffe578", "ffb72d", "f96713", "c62c17", "791d22", "371526"],
		["f5ffff", "b9fcff", "4adfff", "159cfa", "2551d9", "1d3090", "10194e"],
		["f5ffff", "d9faff", "99e4fa", "4cb9d8", "247baf", "21567f", "15324c"]
	][clampi(element, 0, 2)]
	var keys = ["edge_color", "highlight_color", "body_color", "inner_color", "shade_color", "tail_color", "dark_color"]
	for i in keys.size(): set(keys[i], Color(colors[i]))
