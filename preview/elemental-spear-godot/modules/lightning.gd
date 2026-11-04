extends RefCounted
## Original analytic pixel geometry. No stateful RNG, simulation or gameplay hooks.
const G = preload("geometry.gd")
const VIOLET = Color("5843a5")
const BLUE = Color("7775ed")
const CYAN = Color("73d9f0")
const WHITE = Color("e7fbff")

func render(canvas:Node2D, phase:String, state:Dictionary, config:Resource, stage:Resource) -> void:
	var q:float = state.q
	var age:float = state.age
	var size_value:float = stage.size
	var center:Vector2 = state.center
	var axis:Vector2 = state.axis
	var cross_axis = axis.orthogonal()
	var seed_value:float = state.seed
	var tick = floorf(age * 18.0)
	var fade:float = state.fade
	if stage.intensity <= 0 or fade <= 0: return
	if phase == "gather":
		for i in config.arc_count:
			var angle = TAU * G.hashf(i,seed_value)
			var offset = Vector2.from_angle(angle) * (8 + 23 * (1-q)) * size_value
			if G.hashf(i+tick,seed_value) < 0.28: continue
			_arc(canvas,center+offset,center+offset*0.2,i+tick,stage,(0.3+0.7*q),size_value)
		G.blade(canvas,center,axis,6*size_value,3*size_value,G.color(VIOLET,stage,q),G.color(CYAN,stage,q),G.color(WHITE,stage,q))
	elif phase in ["form","hover","descent"]:
		var length_value:float = state.length
		var width_value:float = state.width * 0.7
		if phase == "descent":
			var tail = center-axis*length_value*0.35
			G.poly(canvas,[tail-cross_axis*width_value,tail-axis*(26+25*q)*size_value,tail+cross_axis*width_value,center+axis*length_value*0.4],G.color(VIOLET,stage,0.4))
			G.poly(canvas,[tail-cross_axis*width_value*0.35,tail-axis*(17+17*q)*size_value,center+axis*length_value*0.4],G.color(CYAN,stage,0.5))
		if length_value >= 1:
			G.blade(canvas,center,axis,length_value,width_value+2*size_value,G.color(VIOLET,stage),G.color(BLUE,stage),G.color(CYAN,stage))
			G.blade(canvas,center,axis,length_value*0.96,width_value*0.65,G.color(BLUE,stage),G.color(CYAN,stage),G.color(WHITE,stage))
		for i in config.arc_count:
			if G.hashf(i+tick*11,seed_value) < 0.52: continue
			var along = (G.hashf(i+13,seed_value)-0.5)*length_value*0.8
			var side = -1.0 if i%2==0 else 1.0
			var a = center+axis*along
			var b = a+cross_axis*side*(4+G.hashf(i+30,seed_value)*8)*size_value-axis*5*size_value
			_arc(canvas,a,b,seed_value+i+tick,stage,0.75,size_value)
	elif phase == "impact":
		var reach:float = state.radius * (0.2+0.8*sqrt(q))
		var life = pow(1-q,1.4)
		G.ellipse(canvas,Vector2.ZERO,reach,config.ground_squash,G.color(BLUE,stage,0.7*life),false)
		if q < 0.3:
			G.blade(canvas,Vector2(0,-4*size_value),Vector2.UP,(22*(1-q/0.3)+2)*size_value,9*size_value,G.color(BLUE,stage,life),G.color(CYAN,stage,life),G.color(WHITE,stage,life))
		for i in config.arc_count:
			var angle = TAU*float(i)/maxi(1,config.arc_count)+0.3*G.hashf(i,seed_value)
			var end = Vector2(cos(angle),sin(angle)*config.ground_squash)*reach
			_arc(canvas,Vector2.ZERO,end,seed_value+i+tick,stage,life,size_value)
			_arc(canvas,end*0.6,end*0.75+Vector2(-sin(angle),cos(angle)*config.ground_squash)*reach*0.25,seed_value+i+91,stage,life*0.7,size_value)
		_sparks(canvas,config,stage,reach,q,life,seed_value)
	elif phase in ["field","dissolve"]:
		_field(canvas,state,config,stage,phase=="dissolve")

func _arc(canvas:Node2D,a:Vector2,b:Vector2,seed_value:float,stage:Resource,alpha:float,size_value:float) -> void:
	G.bolt(canvas,a,b,seed_value,G.color(VIOLET,stage,alpha*0.55),3*size_value,5*size_value)
	G.bolt(canvas,a,b,seed_value,G.color(CYAN,stage,alpha),1,5*size_value)
	if a.distance_to(b)>12*size_value:
		G.pixel(canvas,b,G.color(WHITE,stage,alpha),size_value)

func _field(canvas:Node2D,state:Dictionary,config:Resource,stage:Resource,dissolving:bool) -> void:
	var fade:float = state.fade
	var seed_value:float = state.seed
	var tick = floorf(state.age*12.0)
	var size_value:float = stage.size
	var entry = 1.0 if dissolving else smoothstep(0.0,minf(0.16,state.duration),state.age)
	G.ellipse(canvas,Vector2.ZERO,state.radius*0.86,config.ground_squash,G.color(VIOLET,stage,0.10*fade*entry))
	# Each site is fixed in space; only the active links and their jagged paths change.
	for i in config.arc_count:
		var a = _node(i,config,size_value)
		var b = _node((i+1)%maxi(1,config.arc_count),config,size_value)
		G.pixel(canvas,a,G.color(BLUE,stage,fade*entry*0.65),2*size_value)
		if G.hashf(i+tick*17,seed_value)>0.47+0.3*(1-fade):
			_arc(canvas,a,b,seed_value+i+tick,stage,fade*entry*0.82,size_value)
			G.pixel(canvas,a,G.color(WHITE,stage,fade*entry),size_value)
		if i%3==0 and G.hashf(i+tick*7,seed_value)>.45:
			var opposite=_node((i+maxi(1,config.arc_count/2))%maxi(1,config.arc_count),config,size_value)
			_arc(canvas,a,opposite,seed_value+i+tick+90,stage,fade*entry*.64,size_value)
	for i in config.detail_count:
		if G.hashf(i+tick*31,seed_value)<0.84: continue
		var p = G.ground_site(i+81,config,size_value)
		G.line(canvas,p,p+Vector2(1,-3)*size_value,G.color(CYAN,stage,fade*entry*0.65))

func _sparks(canvas:Node2D,config:Resource,stage:Resource,radius:float,q:float,alpha:float,seed_value:float) -> void:
	for i in config.detail_count:
		var angle = TAU*G.hashf(i+71,seed_value)
		var p = Vector2(cos(angle),sin(angle)*0.65)*radius*(0.4+0.6*G.hashf(i+90,seed_value))
		p.y -= sin(q*PI)*12*stage.size
		G.line(canvas,p,p+Vector2.from_angle(angle)*3*stage.size,G.color(CYAN,stage,alpha))

func _node(i:int,config:Resource,size_value:float)->Vector2:
	var a=TAU*float(i)/maxi(1,config.arc_count)+(G.hashf(i+13,config.seed_value)-.5)*.24
	var r=config.field_radius*size_value*(.68+.15*G.hashf(i+19,config.seed_value))
	return Vector2(cos(a)*r,sin(a)*r*config.ground_squash)
