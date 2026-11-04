extends Sprite2D
## Reusable display-only renderer. The host owns amount and time, with no automatic decay.
const Profile = preload("body_profile.gd")
const Paths = preload("body_paths.gd")
const BodyShader = preload("body_state.gdshader")
const Portrait = preload("../assets/xing_tian.png")
var profile: Resource
var amount: float = 0.0
var elapsed: float = 0.0
var active: bool = true
var _shader_material: ShaderMaterial

func _init() -> void:
	texture = Portrait
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = BodyShader
	_shader_material.set_shader_parameter("seam_map", Paths.texture())
	material = _shader_material
	configure(Profile.new())

func configure(settings: Resource) -> void:
	profile = settings.sanitized() if settings is Profile else Profile.new()
	for key in ["intensity","local_glow","flow_strength","breathing","dark_color","seam_color","hot_color","markings_enabled","flow_enabled"]:
		_shader_material.set_shader_parameter(key, profile.get(key))
	_sync()

func start(value: float = 0.0) -> void:
	active = true
	elapsed = 0.0
	amount = clampf(value,0.0,1.0) if is_finite(value) else 0.0
	_sync()

func set_amount(value: float) -> void:
	if not is_finite(value) or not active: return
	amount = clampf(value,0.0,1.0)
	_sync()

func advance(delta: float) -> void:
	if not active or not is_finite(delta) or delta < 0.0: return
	var next_time: float = elapsed + delta
	if not is_finite(next_time): return
	elapsed = next_time
	_sync()

func seek(seconds: float) -> void:
	if not active or not is_finite(seconds) or seconds < 0.0: return
	elapsed = seconds
	_sync()

func clear() -> void:
	active = false
	amount = 0.0
	elapsed = 0.0
	_sync()

func _sync() -> void:
	_shader_material.set_shader_parameter("amount", amount if active else 0.0)
	_shader_material.set_shader_parameter("breathing_phase", fposmod(elapsed, TAU/3.6)*3.6)
	var flow_phase: float = fposmod(elapsed, 1.0/profile.flow_speed)*profile.flow_speed if profile.flow_speed>0 else 0.0
	_shader_material.set_shader_parameter("flow_phase", flow_phase)
