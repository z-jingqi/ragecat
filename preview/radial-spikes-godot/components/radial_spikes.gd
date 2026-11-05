class_name RadialSpikes
extends Node2D
signal finished
const Profile=preload("spike_profile.gd")
const SpikeCanvas=preload("spike_canvas.gd")
const Earth=preload("../modules/earth.gd")
var profile:Resource=Profile.new()
var spikes:Array[Dictionary]=[]
var canvases:Array[Node2D]=[]
var age:float=0
var seed_value:int=17
var running:bool=false
var _emitted:bool=false
func _init()->void: y_sort_enabled=true
func configure(value:Resource)->void:
	profile=value.clean() if value is Profile else Profile.new()
	if not spikes.is_empty(): _build(); _update()
func play(origin:Vector2,seed_number:int=17)->void:
	position=origin if origin.is_finite() else Vector2.ZERO
	seed_value=seed_number; age=0; running=true; _emitted=false
	_build(); _update()
func _build()->void:
	_destroy_canvases(); spikes.clear()
	var rng:RandomNumberGenerator=RandomNumberGenerator.new(); rng.seed=seed_value
	var renderer:Script=Earth
	var module_name:String=["earth", "ice", "lightning"][profile.element]
	var module_path:String=get_script().resource_path.get_base_dir().path_join("../modules/"+module_name+".gd").simplify_path()
	if ResourceLoader.exists(module_path): renderer=load(module_path)
	for layer in profile.layers:
		var radius:float=profile.inner_radius if profile.layers==1 else lerpf(profile.inner_radius,profile.radius,float(layer)/(profile.layers-1))
		var count:int=clampi(roundi(TAU*radius/32*profile.density),4,82)
		var turn:float=rng.randf_range(0,TAU)
		for i in count:
			var theta:float=turn+TAU*(i+rng.randf_range(-.24,.24)*profile.irregularity)/count
			var radial:float=radius+rng.randf_range(-3.5,3.5)*profile.irregularity
			var anchor:Vector2=Vector2(cos(theta)*radial,sin(theta)*radial*profile.ground_squash)
			var item:Dictionary={"pos":anchor,"height":rng.randf_range(22,32)*profile.spike_size*(1+layer*.055),"width":rng.randf_range(9,13)*profile.spike_size,"lean":cos(theta)*.18+rng.randf_range(-.09,.09),"variant":rng.randf(),"seed":rng.randi(),"layer":layer,"spawn":.10+layer*profile.layer_stride()+rng.randf_range(0,profile.stagger_window())}
			spikes.append(item)
			var canvas:Node2D=SpikeCanvas.new(); canvas.position=anchor; canvas.spike=item.duplicate(); canvas.spike.pos=Vector2.ZERO; canvas.renderer=renderer; canvas.profile=profile; add_child(canvas); canvases.append(canvas)
func seek(seconds:float)->void:
	if not is_finite(seconds): return
	age=maxf(0,seconds)
	if not spikes.is_empty(): running=true
	if age<profile.lifetime(): _emitted=false
	_update()
func advance(delta:float)->void:
	if not running or not is_finite(delta) or delta<=0: return
	age+=delta; _update()
	if age>=profile.lifetime():
		running=false
		if not _emitted:
			_emitted=true; finished.emit()
func _update()->void:
	for i in canvases.size():
		canvases[i].age=age-spikes[i].spawn
		canvases[i].visible=running
		canvases[i].queue_redraw()
	queue_redraw()
func clear()->void:
	running=false; age=0; spikes.clear(); _destroy_canvases(); queue_redraw()
func _destroy_canvases()->void:
	for canvas in canvases: remove_child(canvas); canvas.free()
	canvases.clear()
func active_layers()->Array[int]:
	var result:Array[int]=[]
	if not running: return result
	for spike in spikes:
		if age>=spike.spawn and age<spike.spawn+profile.rise_time+profile.hold_time+profile.fade_time and not result.has(spike.layer): result.append(spike.layer)
	return result
