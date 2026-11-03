extends Node2D
## Visual-only radial frost pulse. Combat, simulation and disposal belong to caller.
## Origin/radius use the parent's coordinates. No automatic clock or damage events.
const SHADER := preload("frost_ring.gdshader")
const DEFAULTS := {
	"duration": 0.18, "pixel_size": 2.0, "thickness": 4.0,
	"expansion_ratio": 0.40, "hold_ratio": 0.10, "facets": 18,
	"shards": 12, "seed": 29, "highlight": Color("e5fbff"),
	"body": Color("83d5e7"), "shade": Color("397eaa")
}
var age := 0.0
var duration := 0.18
var radius := 0.0
var art_pixel_size := 2.0
var done := true
var paused := false
var config: Dictionary = {}
var material_instance: ShaderMaterial
var surface: ColorRect
var _has_replay := false

static func _number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is float or value is int): return fallback
	return clampf(float(value), low, high) if is_finite(float(value)) else fallback

static func sanitized(options: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate()
	var limits := {
		"duration": Vector2(0.05, 2.0), "pixel_size": Vector2(0.5, 8.0),
		"thickness": Vector2(1.0, 8.0), "expansion_ratio": Vector2(0.15, 0.65),
		"hold_ratio": Vector2(0.0, 0.20), "facets": Vector2(8, 32),
		"shards": Vector2(0, 24), "seed": Vector2(0, 65535)
	}
	for key in limits:
		out[key] = _number(options.get(key, out[key]), out[key], limits[key].x, limits[key].y)
	for key in ["facets", "shards", "seed"]: out[key] = int(out[key])
	for key in ["highlight", "body", "shade"]:
		var value = options.get(key, out[key])
		var color: Color = Color.from_string(value, out[key]) if value is String else (value if value is Color else out[key])
		if not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b)):
			color = out[key]
		out[key] = Color(clampf(color.r, 0, 1), clampf(color.g, 0, 1), clampf(color.b, 0, 1), 1.0)
	return out

func _ensure_surface() -> void:
	if is_instance_valid(surface): return
	surface = ColorRect.new()
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	material_instance = ShaderMaterial.new()
	material_instance.shader = SHADER
	surface.material = material_instance
	add_child(surface)

func play(origin: Vector2, actual_radius: float, options: Dictionary = {}) -> void:
	reset()
	# Reject unsupported bounds instead of silently changing the caller's radius.
	if not origin.is_finite() or not is_finite(actual_radius) or actual_radius <= 0.0 or actual_radius > 4096.0: return
	_ensure_surface()
	config = sanitized(options)
	position = origin
	radius = actual_radius
	duration = config.duration
	art_pixel_size = minf(config.pixel_size, radius / 8.0)
	var reach: float = radius / art_pixel_size
	var extent := ceilf(reach) + 1.0
	surface.position = Vector2.ONE * -extent * art_pixel_size
	surface.size = Vector2.ONE * extent * 2.0 * art_pixel_size
	var parameters := {
		"age": 0.0, "duration": duration, "extent": extent, "reach": reach,
		"thickness": minf(config.thickness, maxf(0.5, reach * 0.18)),
		"expansion_ratio": config.expansion_ratio, "hold_ratio": config.hold_ratio,
		"facets": config.facets, "shards": config.shards, "seed": float(config.seed),
		"highlight_color": config.highlight, "body_color": config.body, "shade_color": config.shade
	}
	for key in parameters: material_instance.set_shader_parameter(key, parameters[key])
	_has_replay = true
	done = false
	visible = true

func advance(delta: float) -> void:
	if done or paused or not is_finite(delta) or delta <= 0.0: return
	seek(minf(duration, age + delta))

func seek(seconds: float) -> void:
	if not _has_replay or not is_finite(seconds): return
	age = clampf(seconds, 0.0, duration)
	done = age >= duration
	visible = not done
	material_instance.set_shader_parameter("age", age)

func replay() -> void:
	if not _has_replay: return
	paused = false
	seek(0.0)

func stop() -> void:
	done = true
	visible = false
	paused = false

func reset() -> void:
	stop()
	age = 0.0
	radius = 0.0
	_has_replay = false
	config.clear()
	if material_instance != null: material_instance.set_shader_parameter("age", -1.0)
