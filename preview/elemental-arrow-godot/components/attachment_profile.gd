extends Resource
# Each element owns its settings. Rendering does not mutate caller resources.
@export var enabled:bool=false
@export_range(0.25,3.0,0.05) var size:float=1.0
@export_range(0.0,2.0,0.05) var intensity:float=1.0
@export var tint:Color=Color.WHITE
@export_range(0.0,2.0,0.05) var trail_length:float=1.0
@export_range(0.0,2.0,0.05) var glow:float=1.0
@export_range(0.0,2.0,0.05) var arc_density:float=1.0 # Lightning only; other modules ignore it.
@export_enum("Spiral", "Crackle", "Double Helix", "Reference") var lightning_mode:int=3 # Lightning only.
@export_range(0.0,2.0,0.05) var arc_forks:float=1.0 # Reference mode only.
@export_range(0.0,2.0,0.05) var arc_jitter:float=1.0 # Reference mode only.
@export_range(5.0,60.0,1.0) var arc_rate:float=30.0 # Reference mode re-strikes per second.
@export_range(0.0,2.0,0.05) var arc_variation:float=1.0 # Reference main-path displacement.
@export_range(3.0,20.0,1.0) var arc_path_rate:float=12.0 # Fresh major shapes per second.
@export var seed_value:int=17
func sanitized()->Resource:
	var q=duplicate(true)
	for k in ["size","intensity","trail_length","glow","arc_density","arc_forks","arc_jitter","arc_variation"]:
		var v=float(q.get(k)); q.set(k,clampf(v,0.25 if k=="size" else 0.0,3.0 if k=="size" else 2.0) if is_finite(v) else 1.0)
	if not (is_finite(q.tint.r) and is_finite(q.tint.g) and is_finite(q.tint.b) and is_finite(q.tint.a)): q.tint=Color.WHITE
	q.arc_rate=clampf(q.arc_rate,5,60) if is_finite(q.arc_rate) else 30.0
	q.arc_path_rate=clampf(q.arc_path_rate,3,20) if is_finite(q.arc_path_rate) else 12.0
	q.tint=q.tint.clamp(); q.lightning_mode=clampi(q.lightning_mode,0,3); return q
