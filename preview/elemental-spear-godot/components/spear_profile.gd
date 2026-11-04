extends Resource
const Stage = preload("stage_profile.gd")
const PHASES = ["gather","form","hover","descent","impact","field","dissolve"]
@export_group("Spear silhouette / visual units")
@export_range(28,100,1) var spear_length: float = 70.0
@export_range(3,16,1) var spear_width: float = 8.0
@export_range(30,140,1) var fall_height: float = 94.0
@export_range(80,900,1) var fall_speed: float = 540.0
@export_range(-35,35,1) var angle_degrees: float = -12.0
@export_group("Ground appearance, not gameplay range")
@export_range(18,100,1) var field_radius: float = 57.0
@export_range(0.3,0.75,0.01) var ground_squash: float = 0.48
@export_range(0,24,1) var detail_count: int = 12
@export_range(0,16,1) var bubble_count: int = 0
@export_range(0,16,1) var flame_count: int = 7
@export_range(0,16,1) var ground_flame_count: int = 0
@export_range(0,16,1) var ground_ember_count: int = 0
@export_range(0,16,1) var arc_count: int = 8
@export_range(0,16,1) var crystal_count: int = 9
@export var seed_value: int = 41
@export_group("Independent phases")
@export var gather: Resource
@export var form: Resource
@export var hover: Resource
@export var descent: Resource
@export var impact: Resource
@export var field: Resource
@export var dissolve: Resource
func _init() -> void:
	var lengths = [0.12,0.24,0.16,1.0,0.32,2.4,0.5]
	for i in PHASES.size():
		var s = Stage.new(); s.duration = lengths[i]; set(PHASES[i],s)
func phase(name_value: String) -> Resource:
	return get(name_value) if name_value in PHASES else null
func sanitized() -> Resource:
	var c = duplicate(true)
	for key in ["spear_length","spear_width","fall_height","fall_speed","angle_degrees","field_radius","ground_squash"]:
		if not is_finite(c.get(key)): c.set(key,get_script().new().get(key))
	c.spear_length=clampf(c.spear_length,28,100); c.spear_width=clampf(c.spear_width,3,16)
	c.fall_height=clampf(c.fall_height,30,140); c.fall_speed=clampf(c.fall_speed,80,900)
	c.angle_degrees=clampf(c.angle_degrees,-35,35); c.field_radius=clampf(c.field_radius,18,100)
	c.ground_squash=clampf(c.ground_squash,0.3,0.75)
	for key in ["detail_count","bubble_count","flame_count","ground_flame_count","ground_ember_count","arc_count","crystal_count"]: c.set(key,clampi(c.get(key),0,24 if key=="detail_count" else 16))
	for key in PHASES:
		var s=c.get(key)
		if not s is Stage: s=Stage.new(); c.set(key,s)
		s.sanitize()
	return c
func phase_duration(name_value: String) -> float:
	var s = phase(name_value)
	if s == null or not s.enabled: return 0.0
	return fall_height / fall_speed * s.duration if name_value=="descent" else s.duration
func contact_time() -> float:
	return phase_duration("gather")+phase_duration("form")+phase_duration("hover")+phase_duration("descent")
func offsets() -> Dictionary:
	var result={}; var at=0.0
	for key in ["gather","form","hover","descent"]:
		result[key]=at; at+=phase_duration(key)
	result.impact=at; result.field=at; result.dissolve=at+phase_duration("field")
	return result
func total_duration() -> float:
	return contact_time()+maxf(phase_duration("impact"),phase_duration("field")+phase_duration("dissolve"))
