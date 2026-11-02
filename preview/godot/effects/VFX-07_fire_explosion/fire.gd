extends Node2D
## Independent one-shot fire burst. Canvas coordinates, +Y down.
const MASK = preload("res://effects/VFX-07_fire_explosion/fire.gdshader")
var settings: Dictionary = {}
var active := false
var paused := false
var auto_tick := true
var playback_rate := 1.0
var age := -1.0
var _has_replay := false
var _rect: ColorRect
var _material: ShaderMaterial

func _ready() -> void:
	_ensure_visual()

static func finite_clamp(value: Variant, low: float, high: float, fallback: float) -> float:
	var v := float(value) if value is int or value is float else fallback
	return fallback if not is_finite(v) else clampf(v, low, high)

static func sanitized(source: Dictionary) -> Dictionary:
	var s := source.duplicate(true)
	s.radius = finite_clamp(s.get("radius",18.0), 6.0, 30.0,18.0)
	s.duration = finite_clamp(s.get("duration",0.60),0.18,0.85,0.60)
	s.rise = finite_clamp(s.get("rise",22.0),0.0,45.0,22.0)
	s.lobes = int(finite_clamp(s.get("lobes",7),3.0,10.0,7.0))
	s.embers = int(finite_clamp(s.get("embers",10),0.0,16.0,10.0))
	s.spread = finite_clamp(s.get("spread",1.0),0.5,1.5,1.0)
	s.emberLength = finite_clamp(s.get("emberLength",4.5),1.0,7.0,4.5)
	s.smoke = finite_clamp(s.get("smoke",0.65),0.0,1.0,0.65)
	s.seed = int(finite_clamp(s.get("seed",37),0.0,4095.0,37.0))
	for key in ["coreHex", "bodyHex", "flameHex", "edgeHex", "smokeHex", "smokeLightHex", "ashHex"]:
		var fallback: String = {"coreHex":"#fff2ac", "bodyHex":"#ffb33c", "flameHex":"#f26329", "edgeHex":"#a72e25","smokeHex":"#615862","smokeLightHex":"#8a7370","ashHex":"#3c3440"}[key]
		var c := Color.from_string(str(s.get(key, fallback)), Color(fallback))
		c.a = 1.0
		s[key] = "#" + c.to_html(false)
	return s

static func extent_pixels(s: Dictionary) -> float:
	return ceilf(s.radius * (2.0 * s.spread + 1.0) + s.rise + 8.0)

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

func play(contact: Vector2, preset: Dictionary) -> void:
	_ensure_visual()
	if not contact.is_finite():
		clear()
		return
	settings = sanitized(preset)
	# Display-only quantization. The caller's contact is never modified.
	position = contact.round()
	_has_replay = true
	_begin()

func _begin() -> void:
	var e := extent_pixels(settings)
	_rect.position = Vector2(-e, -e)
	_rect.size = Vector2.ONE * e * 2.0
	var values := {
		"duration":settings.duration,"radius":settings.radius,"rise":settings.rise,
		"lobes":settings.lobes,"embers":settings.embers,"spread":settings.spread,
		"seed":float(settings.seed),"extent":e,"ember_length":settings.emberLength,"smoke":settings.smoke,
		"smoke_color":Color(settings.smokeHex),"smoke_light":Color(settings.smokeLightHex),"ash_color":Color(settings.ashHex),
		"core_color":Color(settings.coreHex),"body_color":Color(settings.bodyHex),
		"flame_color":Color(settings.flameHex),"edge_color":Color(settings.edgeHex)}
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
