extends Resource
@export_group("Ground and timing")
@export_range(18, 44, 1) var radius: float = 32.0
@export_range(0.25, 0.65, 0.01) var perspective: float = 0.42
@export_range(0.15, 0.6, 0.01) var contraction_time: float = 0.28
@export_range(0.5, 1.6, 0.05) var revival_time: float = 1.05
@export_range(0.3, 1.5, 0.05) var exhaustion_time: float = 0.8
@export_group("Restrained war aura")
@export_range(0, 0.65, 0.01) var aura_opacity: float = 0.36
@export_range(0, 24, 1) var shard_count: int = 14
@export_range(0, 18, 1) var rising_count: int = 12
@export var shape_seed: int = 83
@export_group("Optional blood at lethal entry only")
@export var blood_enabled: bool = true
@export_range(0, 14, 1) var blood_count: int = 7
@export_group("Palette")
@export var dark: Color = Color("3d1826")
@export var red: Color = Color("943342")
@export var red_tip: Color = Color("bd594d")
@export var copper: Color = Color("ca814f")
@export var copper_tip: Color = Color("edb87b")
@export var blood: Color = Color("7c1f31")

func sanitized() -> Resource:
	var p=duplicate()
	for item in [["radius",32.0,18.0,44.0],["perspective",0.42,0.25,0.65],["contraction_time",0.28,0.15,0.6],["revival_time",1.05,0.5,1.6],["exhaustion_time",0.8,0.3,1.5],["aura_opacity",0.36,0.0,0.65]]:
		var v:float=p.get(item[0]); p.set(item[0],clampf(v,item[2],item[3]) if is_finite(v) else item[1])
	p.shard_count=clampi(shard_count,0,24); p.rising_count=clampi(rising_count,0,18)
	p.shape_seed=clampi(shape_seed,0,65535); p.blood_count=clampi(blood_count,0,14)
	for key in ["dark","red","red_tip","copper","copper_tip","blood"]:
		var c:Color=p.get(key)
		p.set(key,Color(safe(c.r),safe(c.g),safe(c.b),1.0))
	return p

static func safe(value:float) -> float:
	return clampf(value,0.0,1.0) if is_finite(value) else 0.2
