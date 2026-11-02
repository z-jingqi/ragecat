extends Node2D
## Godot-only thin player. Shared mask is generated from src/shared/ImpactKernel.hlsl.
## contact is canvas XY; incoming is mathematical XY (+Y up), not a surface normal.
const MASK = preload("res://effects/VFX-04_hit_impact/impact.gdshader")
var settings: Dictionary = {}
var active := false
var paused := false
var auto_tick := true
var playback_rate := 1.0
var age := -1.0
var direction := 0.0
var _has_replay := false
var _rect: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	_ensure_visual()

static func finite_clamp(value: Variant, low: float, high: float, fallback: float) -> float:
	var v := float(value)
	return fallback if not is_finite(v) else clampf(v, low, high)

static func sanitized(source: Dictionary) -> Dictionary:
	var s := source.duplicate(true)
	s.size = finite_clamp(s.get("size", 1.0), 0.35, 2.0, 1.0)
	s.coreSize = finite_clamp(s.get("coreSize", 6.0), 2.0, 12.0, 6.0)
	s.shardCount = int(finite_clamp(s.get("shardCount", 5), 0.0, 8.0, 5.0))
	s.shardLength = finite_clamp(s.get("shardLength", 8.0), 2.0, 20.0, 8.0)
	s.spreadDegrees = finite_clamp(s.get("spreadDegrees", 125.0), 15.0, 170.0, 125.0)
	s.speed = finite_clamp(s.get("speed", 78.0), 15.0, 180.0, 78.0)
	s.duration = finite_clamp(s.get("duration", 0.2), 0.08, 0.5, 0.2)
	s.seed = int(finite_clamp(s.get("seed", 23), -2147483648.0, 2147483647.0, 23.0)) & 4095
	s.shockAccent = bool(s.get("shockAccent", false))
	s.directionDegrees = finite_clamp(s.get("directionDegrees", 25.0), -36000.0, 36000.0, 0.0)
	for key in ["coreHex", "bodyHex", "edgeHex"]:
		var fallback: String = {"coreHex":"#fff5cf", "bodyHex":"#eec464", "edgeHex":"#a66a38"}[key]
		var c := Color.from_string(str(s.get(key, fallback)), Color(fallback))
		c.a = 1.0
		s[key] = "#" + c.to_html(false)
	return s

static func extent_pixels(s: Dictionary) -> float:
	return ceilf(s.size * (s.coreSize * 2.0 + s.speed * s.duration + s.shardLength * 1.2 + 4.0))

func _ensure_visual() -> void:
	if is_instance_valid(_rect):
		return
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_material = ShaderMaterial.new()
	_material.shader = MASK
	_rect.material = _material
	add_child(_rect)
	_rect.hide()

func play(contact: Vector2, incoming: Vector2, preset: Dictionary) -> void:
	_ensure_visual()
	if not contact.is_finite():
		clear()
		return
	settings = sanitized(preset)
	# Display-only quantization. The caller's contact is never modified.
	position = contact.round()
	direction = incoming.angle() if incoming.is_finite() and incoming.length_squared() > 0.000001 else 0.0
	_has_replay = true
	_begin()

func _begin() -> void:
	var e := extent_pixels(settings)
	_rect.position = Vector2(-e, -e)
	_rect.size = Vector2.ONE * e * 2.0
	var values := {
		"duration": settings.duration, "size": settings.size, "core_size": settings.coreSize,
		"shard_count": float(settings.shardCount), "shard_length": settings.shardLength,
		"spread": deg_to_rad(settings.spreadDegrees), "speed": settings.speed,
		"seed": float(settings.seed), "shock": 1.0 if settings.shockAccent else 0.0,
		"direction": direction, "extent": e,
		"core_color": Color(settings.coreHex), "body_color": Color(settings.bodyHex),
		"edge_color": Color(settings.edgeHex)}
	for key in values:
		_material.set_shader_parameter("u_" + key, values[key])
	age = 0.0
	active = true
	paused = false
	_rect.show()
	_apply_age()

func replay() -> void:
	if _has_replay:
		_begin()

func clear() -> void:
	age = -1.0
	active = false
	paused = false
	if is_instance_valid(_rect):
		_rect.hide()

func tick(delta_seconds: float) -> void:
	if not active or paused or not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return
	age = minf(settings.duration, age + delta_seconds * finite_clamp(playback_rate, 0.0, 4.0, 1.0))
	if age >= settings.duration - 0.0000001:
		age = settings.duration
		active = false
		_rect.hide()
	_apply_age()

func seek(seconds: float) -> void:
	if not _has_replay or not is_finite(seconds):
		return
	age = clampf(seconds, 0.0, settings.duration)
	active = age < settings.duration
	_rect.visible = active
	_apply_age()

func _apply_age() -> void:
	_material.set_shader_parameter("u_age", age)

func _process(delta: float) -> void:
	if auto_tick:
		tick(delta)

func _exit_tree() -> void:
	clear()
