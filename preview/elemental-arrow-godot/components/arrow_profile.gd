extends Resource
const Attachment=preload("attachment_profile.gd")
@export var body_enabled:bool=true
@export var air_enabled:bool=true
@export_range(18.0,256.0,1.0) var length:float=34.0
@export_range(0.6,2.0,0.05) var width:float=1.0
@export_enum("Classic", "Reference") var body_style:int=0
@export var body_tint:Color=Color.WHITE
@export var feather_color:Color=Color("a94345")
@export var fire:Resource
@export var lightning:Resource
@export var ice:Resource
func _init()->void:
	fire=Attachment.new(); lightning=Attachment.new(); ice=Attachment.new()
func sanitized()->Resource:
	var q=duplicate(true)
	q.length=clampf(q.length,18,256) if is_finite(q.length) else 34.0
	q.body_style=clampi(q.body_style,0,1)
	q.width=clampf(q.width,0.6,2.0) if is_finite(q.width) else 1.0
	for k in ["fire","lightning","ice"]:
		var a=q.get(k); q.set(k,a.sanitized() if a is Attachment else Attachment.new())
	for k in ["body_tint","feather_color"]:
		var c:Color=q.get(k)
		q.set(k,c.clamp() if is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and is_finite(c.a) else Color.WHITE)
	return q
