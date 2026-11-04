extends RefCounted
## Original faceted geometry with analytical growth, frost and melt, not a sprite sheet.
const G = preload("geometry.gd")
const DEEP = Color("29506e")
const BLUE = Color("4d91b3")
const CYAN = Color("92d5df")
const WHITE = Color("e0f7f4")

func render(canvas:Node2D, phase:String, state:Dictionary, config:Resource, stage:Resource) -> void:
	var q:float = state.q
	var size_value:float = stage.size
	var axis:Vector2 = state.axis
	var center:Vector2 = state.center
	var cross_axis = axis.orthogonal()
	var seed_value:float = state.seed
	if stage.intensity<=0 or state.fade<=0: return
	if phase == "gather":
		for i in config.detail_count:
			var angle = G.hashf(i,seed_value)*TAU
			var p = center+Vector2.from_angle(angle)*(9+20*(1-q))*size_value
			var h = (2+G.hashf(i+9,seed_value)*3)*size_value
			G.blade(canvas,p,Vector2.from_angle(angle),h,2*size_value,G.color(BLUE,stage,q),G.color(CYAN,stage,q),G.color(WHITE,stage,q*0.7))
		G.blade(canvas,center,axis,7*size_value,4*size_value,G.color(DEEP,stage,q),G.color(CYAN,stage,q),G.color(WHITE,stage,q))
	elif phase in ["form","hover","descent"]:
		var length_value:float = state.length
		var width_value:float = state.width*1.12
		if length_value>=1:
			G.blade(canvas,center,axis,length_value,width_value,G.color(DEEP,stage),G.color(BLUE,stage),G.color(CYAN,stage))
			G.poly(canvas,[center-axis*length_value*0.5,center-cross_axis*width_value*0.42,center+axis*length_value*0.19,center],G.color(CYAN,stage))
			G.poly(canvas,[center+axis*length_value*0.5,center+cross_axis*width_value*0.34,center-axis*length_value*0.17,center],G.color(BLUE,stage))
			G.line(canvas,center-axis*length_value*0.49,center+axis*length_value*0.49,G.color(WHITE,stage))
			G.line(canvas,center-cross_axis*width_value*0.4,center+axis*length_value*0.18,G.color(WHITE,stage,0.65))
		for i in config.detail_count:
			var cycle = fposmod(state.age*1.3+G.hashf(i,seed_value),1.0)
			if phase=="descent":
				var p = center-axis*(length_value*0.52+cycle*32*size_value)+cross_axis*(G.hashf(i+20,seed_value)-0.5)*13*size_value
				G.blade(canvas,p,axis,3*size_value,2*size_value,G.color(BLUE,stage,1-cycle),G.color(CYAN,stage,1-cycle),G.color(WHITE,stage,0.65*(1-cycle)))
			elif cycle>0.91:
				var p = center+axis*(G.hashf(i+20,seed_value)-0.5)*length_value*0.8
				_glint(canvas,p,stage,(cycle-0.91)/0.09)
	elif phase == "impact":
		var growth = smoothstep(0.0,0.66,q)
		var life = 1-q
		_frost(canvas,config,stage,growth,life,seed_value)
		for i in config.crystal_count:
			var p = G.ground_site(i,config,size_value*0.85)
			var reach = p.length()/maxf(1,state.radius)
			var appear = smoothstep(reach*0.32,reach*0.32+0.32,q)
			_crystal(canvas,p,(7+8*G.hashf(i+90,seed_value))*size_value*appear,3*size_value,(G.hashf(i+100,seed_value)-0.5)*5*size_value,stage,life*0.8)
		for i in config.detail_count:
			var a = TAU*G.hashf(i+21,seed_value)
			var p = Vector2(cos(a),sin(a)*config.ground_squash)*state.radius*sqrt(q)*0.85
			p.y -= sin(q*PI)*(10+G.hashf(i+42,seed_value)*17)*size_value
			G.blade(canvas,p,Vector2.from_angle(a+q),4*size_value,2*size_value,G.color(BLUE,stage,life),G.color(CYAN,stage,life),G.color(WHITE,stage,life))
	elif phase in ["field","dissolve"]:
		_field(canvas,state,config,stage,phase=="dissolve")

func _crystal(canvas:Node2D,p:Vector2,height:float,width_value:float,lean:float,stage:Resource,alpha:float) -> void:
	if height<1: return
	var tip = p+Vector2(lean,-height)
	var ridge = p+Vector2(-width_value*0.18,-height*0.12)
	G.poly(canvas,[p+Vector2(-width_value,0),tip,p+Vector2(width_value,0)],G.color(DEEP,stage,alpha))
	G.poly(canvas,[p+Vector2(-width_value,0),tip,ridge],G.color(CYAN,stage,alpha))
	G.poly(canvas,[ridge,tip,p+Vector2(width_value*0.7,0)],G.color(BLUE,stage,alpha))
	G.line(canvas,ridge,tip,G.color(WHITE,stage,alpha*0.85))

func _frost(canvas:Node2D,config:Resource,stage:Resource,growth:float,alpha:float,seed_value:float) -> void:
	if growth <= 0 or alpha <= 0: return
	var r = config.field_radius*stage.size*growth
	var fringe:Array=[]
	for k in 18:
		var a=TAU*k/18.0
		var reach=r*(.63+.30*G.hashf(k+311,seed_value))
		fringe.append(Vector2(cos(a)*reach,sin(a)*reach*config.ground_squash))
	G.poly(canvas,fringe,G.color(BLUE,stage,alpha*0.13))
	# Frost cracks are stable branches, not a re-rolled electric web.
	for i in config.detail_count:
		var angle = G.hashf(i+50,seed_value)*TAU
		var end = Vector2(cos(angle),sin(angle)*config.ground_squash)*r*(0.6+0.4*G.hashf(i+12,seed_value))
		var mid = end*0.58+Vector2(3,-2)*stage.size
		G.line(canvas,Vector2.ZERO,mid,G.color(CYAN,stage,alpha*0.55))
		G.line(canvas,mid,end,G.color(CYAN,stage,alpha*0.45))
		G.line(canvas,mid,mid+end.rotated(0.7)*0.23,G.color(WHITE,stage,alpha*0.4))

func _field(canvas:Node2D,state:Dictionary,config:Resource,stage:Resource,dissolving:bool) -> void:
	var fade:float = state.fade
	var seed_value:float = state.seed
	var size_value:float = stage.size
	var entry = 1.0 if dissolving else smoothstep(0.0,minf(0.3,state.duration),state.age)
	_frost(canvas,config,stage,1.0,fade*entry*0.72,seed_value)
	# Back-to-front order for a readable low cluster silhouette.
	var sites:Array = []
	for i in config.crystal_count:
		sites.append({"p":G.ground_site(i,config,size_value*0.85),"i":i})
	sites.sort_custom(func(a,b): return a.p.y<b.p.y)
	for site in sites:
		var i:int = site.i
		var p:Vector2 = site.p
		var height = (6+9*G.hashf(i+90,seed_value))*size_value*entry*(0.15+0.85*fade)
		var width_value = (2+G.hashf(i+60,seed_value)*2)*size_value
		G.ellipse(canvas,p,width_value*2,0.32,G.color(CYAN,stage,fade*entry*0.15))
		_crystal(canvas,p+Vector2(-2,0)*size_value,height*0.6,width_value*0.7,-3*size_value,stage,fade*entry)
		_crystal(canvas,p,height,width_value,(G.hashf(i+100,seed_value)-0.5)*5*size_value,stage,fade*entry)
	for i in config.detail_count:
		var cycle = fposmod(state.age*0.7+G.hashf(i+18,seed_value),1.0)
		if cycle<0.94: continue
		var p = G.ground_site(i+120,config,size_value*0.95)
		_glint(canvas,p,stage,(cycle-0.94)/0.06,fade*entry)

func _glint(canvas:Node2D,p:Vector2,stage:Resource,q:float,alpha:float=1) -> void:
	var a = sin(q*PI)*alpha
	G.pixel(canvas,p,G.color(WHITE,stage,a))
	G.line(canvas,p-Vector2(2,0)*stage.size,p+Vector2(2,0)*stage.size,G.color(CYAN,stage,a*0.6))
	G.line(canvas,p-Vector2(0,2)*stage.size,p+Vector2(0,2)*stage.size,G.color(CYAN,stage,a*0.6))
