extends Node2D
const Profile=preload("arrow_profile.gd")
const Body=preload("../modules/body.gd")
const ELEMENTS=["fire","lightning","ice"]
const HISTORY_SECONDS=0.7
var profile:Resource=Profile.new()
var pose:Dictionary={"tip":Vector2.ZERO,"axis":Vector2.RIGHT,"speed":0.0,"time":0.0}
var history:Array=[]
var age:float=0.0
var running:bool=false
var layer_enabled:Dictionary={"body":true,"air":true,"fire":true,"lightning":true,"ice":true}
var renderers:Dictionary={}
func _init()->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for key in ELEMENTS:
		var path="res://modules/"+key+".gd"
		if ResourceLoader.exists(path): renderers[key]=load(path)
func configure(settings:Resource)->void:
	profile=settings.sanitized() if settings is Profile else Profile.new()
	queue_redraw()
func play(tip:Vector2,velocity:Vector2,settings:Resource=null)->void:
	if settings!=null: configure(settings)
	age=0; running=true; history.clear()
	pose={"tip":Vector2.ZERO,"axis":Vector2.RIGHT,"speed":0.0,"time":0.0}
	_store_pose(tip,velocity); queue_redraw()
func advance(delta:float,tip:Vector2,velocity:Vector2)->void:
	if not running or not is_finite(delta) or delta<0: return
	age+=delta
	_store_pose(tip,velocity)
	queue_redraw()
func seek(seconds:float,trajectory:Callable)->void:
	# Deterministic host supplied trajectory. Does not resurrect clear/stop.
	if not running or not is_finite(seconds) or not trajectory.is_valid(): return
	age=maxf(0,seconds); history.clear()
	var start=maxf(0,age-HISTORY_SECONDS)
	var n=int(ceil((age-start)*120.0))
	for i in n+1:
		var at=lerpf(start,age,float(i)/maxi(1,n)); var state:Dictionary=trajectory.call(at)
		_store_pose(state.tip,state.velocity,at)
	queue_redraw()
func _store_pose(tip:Vector2,velocity:Vector2,at:float=-1)->void:
	if not tip.is_finite() or not velocity.is_finite(): return
	var t=age if at<0 else at
	# Teleports must not connect the new arrow to an unrelated old wake.
	if not history.is_empty() and tip.distance_to(pose.tip)>180: history.clear()
	var speed=velocity.length(); var axis=velocity/speed if speed>.001 else pose.axis
	pose={"tip":tip,"axis":axis,"speed":speed,"time":t}
	history.append(pose.duplicate())
	while history.size()>2 and (history[1].time<t-HISTORY_SECONDS or history.size()>160): history.pop_front()
func pose_at(at:float)->Dictionary:
	if history.is_empty(): return pose
	if at<=history[0].time: return history[0]
	for i in range(history.size()-1,0,-1):
		var a:Dictionary=history[i-1]; var b:Dictionary=history[i]
		if at>=a.time:
			var u=clampf((at-a.time)/maxf(.00001,b.time-a.time),0,1)
			return {"tip":a.tip.lerp(b.tip,u),"axis":Vector2.from_angle(lerp_angle(a.axis.angle(),b.axis.angle(),u)),"speed":lerpf(a.speed,b.speed,u),"time":at}
	return history[0]
func set_layer_enabled(key:String,enabled:bool)->void:
	if key in layer_enabled: layer_enabled[key]=enabled; queue_redraw()
func clear()->void:
	running=false; history.clear(); queue_redraw()
func stop()->void: clear()
func _draw()->void:
	if not running: return
	for key in ELEMENTS:
		var a=profile.get(key)
		if key in renderers and layer_enabled[key] and a.enabled and a.intensity>0 and a.tint.a>0: renderers[key].back(self,a)
	if profile.air_enabled and layer_enabled.air: Body.air(self,self)
	if profile.body_enabled and layer_enabled.body: Body.render(self,pose,age,profile)
	for key in ELEMENTS:
		var a=profile.get(key)
		if key in renderers and layer_enabled[key] and a.enabled and a.intensity>0 and a.tint.a>0: renderers[key].front(self,a)
