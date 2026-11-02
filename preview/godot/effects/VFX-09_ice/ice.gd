extends Node2D
## Independent one-shot crystalline ice line. Canvas coordinates, +Y down.
const MASK = preload("res://effects/VFX-09_ice/ice.gdshader")
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
	var specs := {"count":[1,7,5],"spacing":[5,16,12],"height":[12,48,34],"width":[2,8,5],"grow":[0.06,0.3,0.14],"hold":[0,1,0.28],"shatter":[0.15,0.7,0.38],"stagger":[0,0.12,0.055],"speed":[10,70,42],"angle":[-30,30,0],"seed":[0,4095,19],"irregularity":[0,1,0.75]}
	for key in specs:
		s[key] = finite_clamp(s.get(key,specs[key][2]), specs[key][0],specs[key][1],specs[key][2])
	s.count = int(s.count)
	s.seed = int(s.seed)
	for key in ["lightHex","bodyHex","shadeHex","darkHex"]:
		var fallback: String = {"lightHex":"#e7ffff","bodyHex":"#82d9f0","shadeHex":"#4086ba","darkHex":"#254e87"}[key]
		var c := Color.from_string(str(s.get(key,fallback)),Color(fallback))
		c.a = 1.0
		s[key] = "#" + c.to_html(false)
	s.duration = s.grow + s.hold + s.shatter + float(s.count-1)*s.stagger
	return s

static func extent_pixels(s: Dictionary) -> float:
	return ceilf(float(s.count-1)*s.spacing*0.5 + s.height + s.speed*s.shatter + 130.0*s.shatter*s.shatter + 8.0)

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
	var values := {"extent":e,"count":settings.count,"spacing":settings.spacing,"height":settings.height,"width":settings.width,"grow":settings.grow,"hold":settings.hold,"shatter":settings.shatter,"stagger":settings.stagger,"speed":settings.speed,"angle":deg_to_rad(settings.angle),"seed":float(settings.seed),"irregularity":settings.irregularity,"light":Color(settings.lightHex),"body":Color(settings.bodyHex),"shade":Color(settings.shadeHex),"dark":Color(settings.darkHex)}
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
