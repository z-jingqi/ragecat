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
		for i in clampi(config.arc_count,0,16):
			var angle = TAU * G.hashf(i,seed_value)
			var offset = Vector2.from_angle(angle) * (8 + 23 * (1-q)) * size_value
			if G.hashf(i+tick,seed_value) < 0.28: continue
			_arc(canvas,center+offset,center+offset*0.2,i+tick,stage,(0.3+0.7*q),size_value)
		G.blade(canvas,center,axis,6*size_value,3*size_value,G.color(VIOLET,stage,q),G.color(CYAN,stage,q),G.color(WHITE,stage,q))
	elif phase in ["form","hover","descent"]:
		var length_value:float = state.length
		var width_value:float = state.width * 0.7
		if phase == "descent":
			# Trail begins behind the rear tip, wholly in the -motion-axis half-space.
			var tail = center-axis*(length_value*0.5+size_value)
			var shoulder = tail-axis*4*size_value
			var tail_width = maxf(0.5,width_value*0.22)
			G.poly(canvas,[tail,shoulder-cross_axis*tail_width,tail-axis*(26+25*q)*size_value,shoulder+cross_axis*tail_width],G.color(VIOLET,stage,0.4))
			G.poly(canvas,[tail,shoulder-cross_axis*tail_width*0.45,tail-axis*(17+17*q)*size_value,shoulder+cross_axis*tail_width*0.45],G.color(CYAN,stage,0.5))
		if length_value >= 1:
			G.blade(canvas,center,axis,length_value,width_value+2*size_value,G.color(VIOLET,stage),G.color(BLUE,stage),G.color(CYAN,stage))
			G.blade(canvas,center,axis,length_value*0.96,width_value*0.65,G.color(BLUE,stage),G.color(CYAN,stage),G.color(WHITE,stage))
		for i in clampi(config.arc_count,0,16):
			if G.hashf(i+tick*11,seed_value) < 0.52: continue
			var along = (G.hashf(i+13,seed_value)-0.5)*length_value*0.8
			var side = -1.0 if i%2==0 else 1.0
			var a = center+axis*along
			var b = a+cross_axis*side*(4+G.hashf(i+30,seed_value)*8)*size_value-axis*5*size_value
			_arc(canvas,a,b,seed_value+i+tick,stage,0.75,size_value)
	elif phase == "impact":
		var reach:float = state.radius * (0.2+0.8*sqrt(q))
		var life = pow(1-q,1.4)
		if q < 0.3:
			G.blade(canvas,Vector2(0,-4*size_value),Vector2.UP,(22*(1-q/0.3)+2)*size_value,9*size_value,G.color(BLUE,stage,life),G.color(CYAN,stage,life),G.color(WHITE,stage,life))
		for i in clampi(config.arc_count,0,16):
			var angle = TAU*G.hashf(i+207,seed_value)
			var end = Vector2(cos(angle),sin(angle)*config.ground_squash)*reach*(0.35+0.65*G.hashf(i+56,seed_value))
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
	var age:float = state.age
	var size_value:float = stage.size
	var radius:float = state.radius
	var entry = 1.0 if dissolving else smoothstep(0.0,minf(0.16,state.duration),age)
	# Independent, staggered crawling discharges. No perimeter, shared nodes or fill.
	# Every lane drifts locally; only its short broken path changes on its own clock.
	for i in clampi(config.arc_count,0,16):
		var clock_value = age*(3.0+1.6*G.hashf(i+801,seed_value))+G.hashf(i+802,seed_value)
		var beat = floorf(clock_value)
		var local_time = fposmod(clock_value,1.0)
		var points = _crawl(i,beat,seed_value,radius,config.ground_squash)
		var alpha = fade*entry*(1.0-smoothstep(0.52,0.96,local_time))
		# Dissolve thins the active lanes without restarting their animation clock.
		if G.hashf(i+833,seed_value)>fade: continue
		var head = clampf(local_time*9.0,0.05,4.0)
		for j in 4:
			if head<=j: break
			var end:Vector2 = points[j].lerp(points[j+1],minf(1.0,head-j))
			var segment_alpha = alpha*(0.58 if head-j>2.0 else 1.0)
			G.line(canvas,points[j],end,G.color(VIOLET,stage,segment_alpha*0.55),maxf(1,2*size_value))
			G.line(canvas,points[j],end,G.color(CYAN,stage,segment_alpha))
			if j==2 and G.hashf(i+beat*19,seed_value)>0.35:
				var fork:Vector2 = points[j]+(points[j+1]-points[j]).rotated(-1.2 if i%2 else 1.1)*0.65
				fork=Vector2(fork.x,fork.y/config.ground_squash).limit_length(radius*0.98)
				fork.y*=config.ground_squash
				G.line(canvas,points[j],fork,G.color(BLUE,stage,alpha*0.72))
			if head-j<=1.0:
				G.pixel(canvas,end,G.color(WHITE,stage,alpha),size_value)
		# Small residual fragments remain in the local wake, never a connected web.
		if local_time>0.45:
			G.line(canvas,points[1],points[1].lerp(points[2],0.5),G.color(BLUE,stage,fade*entry*0.2*(1-local_time)))
	for i in clampi(config.detail_count,0,24):
		var clock_value = age*(1.4+G.hashf(i+410,seed_value))+G.hashf(i+411,seed_value)
		var pulse = fposmod(clock_value,1.0)
		if pulse>0.28: continue
		var p = G.ground_site(i+81,config,size_value*0.88)
		var alpha = fade*entry*(1.0-pulse/0.28)*0.65
		G.pixel(canvas,p,G.color(CYAN,stage,alpha),size_value)
		if i%3==0:
			G.line(canvas,p,p+Vector2(1,-2)*size_value,G.color(BLUE,stage,alpha*0.7))

func _crawl(i:int,beat:float,seed_value:float,radius:float,squash:float)->Array[Vector2]:
	var angle = TAU*G.hashf(i+620,seed_value)
	var anchor = Vector2.from_angle(angle)*radius*sqrt(G.hashf(i+621,seed_value))*0.67
	# A slow bounded meander keeps each discharge recognizable between redraws.
	anchor+=Vector2(sin(beat*0.52+i*2.1),cos(beat*0.43+i*1.7))*radius*0.10
	var direction = TAU*G.hashf(i+622,seed_value)+sin(beat*0.71+i)*1.8
	var points:Array[Vector2] = [Vector2(anchor.x,anchor.y*squash)]
	var p = anchor
	for j in 4:
		direction+=(G.hashf(i*37+j+beat*13,seed_value)-0.5)*2.2
		p+=Vector2.from_angle(direction)*radius*(0.10+0.065*G.hashf(i*21+j+beat*7,seed_value))
		p=p.limit_length(radius*0.94)
		points.append(Vector2(p.x,p.y*squash))
	return points

func _sparks(canvas:Node2D,config:Resource,stage:Resource,radius:float,q:float,alpha:float,seed_value:float) -> void:
	for i in clampi(config.detail_count,0,24):
		var angle = TAU*G.hashf(i+71,seed_value)
		var p = Vector2(cos(angle),sin(angle)*0.65)*radius*(0.4+0.6*G.hashf(i+90,seed_value))
		p.y -= sin(q*PI)*12*stage.size
		G.line(canvas,p,p+Vector2.from_angle(angle)*3*stage.size,G.color(CYAN,stage,alpha))
