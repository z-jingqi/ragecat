extends Node2D
const Profile=preload("spear_profile.gd")
const Layer=preload("stage_layer.gd")
var profile:Resource
var age:float=0
var cleared:bool=true
var layers:Dictionary={}
var overrides:Dictionary={}
func _ensure_layers() -> void:
	if not layers.is_empty(): return
	for key in ["field","dissolve","gather","form","hover","descent","impact"]:
		var layer=Layer.new(); layer.name=key.capitalize(); add_child(layer); layers[key]=layer
func play(origin:Vector2,settings:Resource=null) -> void:
	_ensure_layers()
	if not origin.is_finite(): clear(); return
	profile=(settings if settings is Profile else Profile.new()).sanitized()
	position=origin; age=0; cleared=false
	for key in Profile.PHASES:
		layers[key].play(Vector2.ZERO,profile,key); layers[key].set_enabled(overrides.get(key,true))
	seek(0)
func seek(seconds:float) -> void:
	if cleared or not is_finite(seconds): return
	age=maxf(0,seconds); var starts=profile.offsets()
	for key in Profile.PHASES: layers[key].seek(age-starts[key])
func advance(delta:float) -> void:
	if is_finite(delta) and delta>0: seek(age+delta)
func set_stage_enabled(key:String,value:bool) -> void:
	if key not in Profile.PHASES: return
	overrides[key]=value
	if layers.has(key): layers[key].set_enabled(value)
func stop() -> void: clear()
func clear() -> void:
	cleared=true
	for layer in layers.values(): layer.clear()
func is_finished() -> bool:
	return cleared or profile==null or age>=profile.total_duration()
