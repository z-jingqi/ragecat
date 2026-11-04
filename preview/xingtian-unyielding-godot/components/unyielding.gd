extends Node2D
## Original design, informed by Sprite Fusion Power Up / Blood and Patch Rage.
## Recipes and retained MIT notices: ../THIRD_PARTY_NOTICES.md.
## Host commands the outcome. No health check, timer-based revival or gameplay rules.
const Profile=preload("unyielding_profile.gd")
const Canvas=preload("pixel_canvas.gd")
const SIZE=Vector2i(176,168)
const ANCHOR=Vector2(88,120)
var profile=Profile.new()
var elapsed:float=0.0
var active:bool=false
var outcome:String=""
var outcome_at:float=0.0
var layers:Dictionary={"ring":true,"shards":true,"aura":true,"blood":true,"revival":true}
var _image:Image
var _texture:ImageTexture
var _boundary:Array[Vector2]=[]

func enter(origin:Vector2=Vector2.ZERO,configuration:Resource=null) -> void:
	if not origin.is_finite(): clear(); return
	position=origin; profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	elapsed=0.0; outcome=""; outcome_at=0.0; active=true
	if _boundary.is_empty(): set_body_mask(null)
	_render()

func revive() -> bool:
	if not active or not outcome.is_empty(): return false
	outcome="revival"; outcome_at=elapsed; _render(); return true

func exhaust() -> bool:
	if not active or not outcome.is_empty(): return false
	outcome="exhaustion"; outcome_at=elapsed; _render(); return true

func seek(seconds:float) -> void:
	if not active: return
	elapsed=maxf(0.0,seconds) if is_finite(seconds) else 0.0
	_render()

func advance(delta:float) -> void:
	if active and is_finite(delta) and delta>0.0: seek(elapsed+delta)

func clear() -> void:
	active=false; outcome=""; elapsed=0.0; _render()

func stop() -> void:
	clear()

func set_layer_enabled(layer:String,enabled:bool) -> void:
	if layers.has(layer): layers[layer]=enabled; _render()

func get_phase() -> String:
	if not active: return "idle"
	if not outcome.is_empty() and elapsed>=outcome_at:
		var duration:float=profile.revival_time if outcome=="revival" else profile.exhaustion_time
		return outcome if elapsed-outcome_at<duration else "finished"
	return "entry" if elapsed<profile.contraction_time+0.28 else "holding"

func get_frame() -> Image:
	if _image==null: _render()
	return _image.duplicate()

func set_body_mask(mask:Image,offset:Vector2=Vector2(-16,-44)) -> void:
	# Supply the actor alpha silhouette in local art pixels. Only a bounded 64x72
	# patch around the anchor is retained. Caller pixels are never recolored.
	_boundary.clear()
	var body=mask
	if body==null or body.is_empty():
		body=Image.create(32,48,false,Image.FORMAT_RGBA8)
		for r in [Rect2i(8,28,6,16),Rect2i(19,28,6,16),Rect2i(6,12,20,19),Rect2i(2,15,5,15),Rect2i(26,15,5,15),Rect2i(10,3,12,10)]: body.fill_rect(r,Color.WHITE)
		offset=Vector2(-16,-44)
	if not offset.is_finite(): offset=Vector2(-16,-44)
	for y in range(mini(72,body.get_height())):
		for x in range(mini(64,body.get_width())):
			if body.get_pixel(x,y).a<0.1: continue
			var edge:bool=false
			for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var q:Vector2i=Vector2i(x,y)+d
				if q.x<0 or q.y<0 or q.x>=body.get_width() or q.y>=body.get_height() or body.get_pixelv(q).a<0.1: edge=true; break
			if edge:
				var at:=Vector2(x,y)+offset
				if at.x>=-32 and at.x<=32 and at.y>=-72 and at.y<=3: _boundary.append(at)
	_render()

func _render() -> void:
	var p=Canvas.new(SIZE,ANCHOR)
	var phase:=get_phase()
	if active and phase!="finished":
		var fade:float=1.0
		if not outcome.is_empty() and elapsed>=outcome_at:
			var d:float=profile.revival_time if outcome=="revival" else profile.exhaustion_time
			fade=1.0-smoothstep(0.0,d,elapsed-outcome_at)
		if layers.ring: _ring(p,fade)
		if layers.shards: _shards(p,fade)
		if layers.blood and profile.blood_enabled: _blood(p,fade)
		if layers.aura: _aura(p,fade)
		if layers.revival and phase=="revival": _revival(p,elapsed-outcome_at)
	_image=p.image
	if _texture==null: _texture=ImageTexture.create_from_image(_image)
	else: _texture.update(_image)
	queue_redraw()

func _ring(p,fade:float) -> void:
	var q:float=clampf(elapsed/profile.contraction_time,0.0,1.0)
	var radius:float=profile.radius*(1.25-0.53*(1.0-pow(1.0-q,3.0)))
	var burst:float=1.0-smoothstep(profile.contraction_time,profile.contraction_time+0.25,elapsed)
	var low:float=0.22*(1.0-profile.aura_opacity/2.0)
	for i in range(15):
		var a:float=float(i)/15.0*TAU
		var end:float=a+TAU/15.0*(0.68+Canvas.noise(i,profile.shape_seed)*0.14)
		p.arc(radius,profile.perspective,a,end,profile.red,fade*maxf(burst*0.85,low),0.5)
		if burst>0.4 and i%3==0: p.arc(radius-1.0,profile.perspective,a,a+0.09,profile.red_tip,burst*fade*0.55)

func _shards(p,fade:float) -> void:
	var start:float=profile.contraction_time*0.6
	for i in range(profile.shard_count):
		var r:float=Canvas.noise(i+50,profile.shape_seed)
		var age:float=elapsed-start-r*0.065
		var life:float=0.26+r*0.20
		if age<0.0 or age>=life: continue
		var q:float=age/life
		var angle:float=TAU*float(i)/maxi(1,profile.shard_count)+r*0.15
		var radius:float=profile.radius*(0.65+q*(0.4+r*0.25))
		var point:Vector2=p.point_on_ground(angle,radius,profile.perspective)
		point.y-=sin(q*PI)*(4.0+r*7.0)
		var direction:=Vector2(cos(angle),sin(angle)*0.3-0.4)
		p.line(point-direction*(2.0+2.0*(1.0-q)),point,profile.red,fade*(1.0-q))
		p.pixel(point,profile.red_tip,fade*(1.0-q)*0.7)

func _blood(p,fade:float) -> void:
	# A small ground-directed spatter, no wound blob, mist cloud or persistent gore.
	for i in range(profile.blood_count):
		var r:float=Canvas.noise(i+171,profile.shape_seed)
		var delay:float=profile.contraction_time*0.45+r*0.055
		var age:float=elapsed-delay
		var flight:float=0.22+r*0.17
		if age<0.0 or age>1.8: continue
		var a:float=TAU*Canvas.noise(i+199,profile.shape_seed)
		var q:float=minf(1.0,age/flight)
		var end:Vector2=p.point_on_ground(a,profile.radius*(0.45+r*0.6),profile.perspective)
		var point:Vector2=end*q
		point.y-=sin(q*PI)*(4.0+r*5.0)
		var alpha:float=fade*(1.0-smoothstep(0.55,1.8,age))
		var color:Color=profile.blood.lerp(profile.dark,smoothstep(0.2,1.1,age))
		p.pixel(point,color,alpha*0.8)
		if q>=1.0: p.pixel(point+Vector2.RIGHT,color,alpha*0.5)
		elif i%3==0: p.pixel(point+Vector2.UP,profile.red_tip,alpha*0.35)

func _aura(p,fade:float) -> void:
	var ramp:float=smoothstep(0.04,profile.contraction_time+0.1,elapsed)*fade
	var alpha:float=profile.aura_opacity*ramp
	if alpha<0.005: return
	# Sparse low-opacity rim follows the supplied boundary; the host draws the body above it.
	for i in range(_boundary.size()):
		var at:Vector2=_boundary[i]
		if at.y>-6.0 or i%2==0: continue
		var wave:float=0.5+0.5*sin(elapsed*3.6+at.x*0.24-at.y*0.1)
		var side:float=-1.0 if at.x<0.0 else 1.0
		var outward:=Vector2(side*(1.0+floor(wave*2.0)),-1.0)
		p.pixel(at+outward,profile.red,alpha*(0.55+wave*0.4))
		p.pixel(at+outward+Vector2(side,-1),profile.dark,alpha*0.45)
	for i in range(7):
		var r:float=Canvas.noise(i+300,profile.shape_seed)
		var q:float=fposmod(elapsed*0.6+r,1.0)
		var side:float=-1.0 if i%2==0 else 1.0
		var point:=Vector2(side*(15.0+r*5.0)+sin(q*TAU+i)*1.0,-7.0-q*(26.0+r*12.0))
		var k:float=sin(q*PI)*alpha*0.65
		p.line(point+Vector2(0,2),point,profile.red,k)

func _revival(p,age:float) -> void:
	var duration:float=profile.revival_time
	for i in range(profile.rising_count):
		var r:float=Canvas.noise(i+410,profile.shape_seed)
		var delay:float=r*duration*0.20
		var q:float=(age-delay)/(duration-delay)
		if q<0.0 or q>=1.0: continue
		var side:float=-1.0 if i%2==0 else 1.0
		var x:float=side*(14.0+r*18.0)*sqrt(1.0-q)
		var y:float=-3.0-q*(42.0+r*12.0)
		var point:=Vector2(x,y)
		var k:float=sin(q*PI)*0.85
		p.line(point+Vector2(side*(1.0-q)*2.0,3.0+4.0*(1.0-q)),point,profile.copper,k)
		p.pixel(point,profile.copper_tip,k*0.7)
	# A small restrained copper ground echo, never a heal cross or holy beam.
	var q:float=age/duration
	if q<0.6:
		for i in range(8):
			var a:float=TAU*float(i)/8.0
			p.arc(profile.radius*(0.72-0.3*q),profile.perspective,a,a+0.28,profile.copper,(1.0-q/0.6)*0.32)

func _draw() -> void:
	if _texture!=null: draw_texture(_texture,-ANCHOR)
