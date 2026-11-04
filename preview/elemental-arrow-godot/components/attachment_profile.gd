extends Resource
# Each element owns its settings. Rendering does not mutate caller resources.
@export var enabled:bool=false
@export_range(0.25,3.0,0.05) var size:float=1.0
@export_range(0.0,2.0,0.05) var intensity:float=1.0
@export var tint:Color=Color.WHITE
@export_range(0.0,2.0,0.05) var trail_length:float=1.0
@export_range(0.0,2.0,0.05) var glow:float=1.0
@export_range(0.0,2.0,0.05) var arc_density:float=1.0 # Lightning only; other modules ignore it.
@export var seed_value:int=17
func sanitized()->Resource:
	var q=duplicate(true)
	for k in ["size","intensity","trail_length","glow","arc_density"]:
		var v=float(q.get(k)); q.set(k,clampf(v,0.25 if k=="size" else 0.0,3.0 if k=="size" else 2.0) if is_finite(v) else 1.0)
	if not (is_finite(q.tint.r) and is_finite(q.tint.g) and is_finite(q.tint.b) and is_finite(q.tint.a)): q.tint=Color.WHITE
	q.tint=q.tint.clamp(); return q
