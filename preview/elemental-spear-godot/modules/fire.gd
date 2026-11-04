extends RefCounted
const G=preload("geometry.gd")
const Lava=preload("fire_lava_surface.gd")
var lava=Lava.new()
func render(n:Node2D,phase:String,s:Dictionary,p:Resource,c:Resource) -> void:
	var dark=G.color(Color("631f20"),c); var red=G.color(Color("b63724"),c)
	var orange=G.color(Color("f97627"),c); var hot=G.color(Color("ffe5a0"),c)
	if phase=="gather":
		# Fast inward motion, never a rotating ring: sparse seeded directions
		# collapse into one dense core at the same midpoint used by both tips.
		var across=Vector2(s.axis.y,-s.axis.x)
		var collapse=pow(1-s.q,1.65)
		for i in mini(p.detail_count,12):
			var angle=G.hashf(i+103,p.seed_value)*TAU
			var direction=Vector2(cos(angle),sin(angle))
			var radius=(2+(23+12*G.hashf(i+137,p.seed_value))*collapse)*c.size
			var head=s.center+direction*radius
			var streak=(3+8*sin(s.q*PI))*(.65+.35*G.hashf(i+171,p.seed_value))*c.size
			G.line(n,head+direction*streak,head,G.color(Color("b63724"),c,.85),2*c.size)
			G.line(n,head+direction*streak*.6,head,orange)
			G.pixel(n,head,hot,c.size)
		var compression=smoothstep(.30,1.0,s.q)
		G.blade(n,s.center,s.axis,(11-4*compression)*c.size,(8-3*compression)*c.size,dark,red,orange)
		G.blade(n,s.center,s.axis,(7-2*compression)*c.size,(5-2*compression)*c.size,red,orange,hot)
		G.line(n,s.center-across*(2-compression)*c.size,s.center+across*(2-compression)*c.size,hot,c.size)
	elif phase in ["form","hover","descent"]:
		# Release most of the length early, then settle without extending the phase.
		var blade_length=s.length
		if phase=="form":
			var release=clampf((s.q-.035)/.78,0,1)
			blade_length=p.spear_length*c.size*(.08+.92*(1-pow(1-release,3)))
		if blade_length<0.8: return
		var across=Vector2(s.axis.y,-s.axis.x)
		if phase=="descent":
			for i in 5:
				var side=(i-2)*2.0*c.size; var base=s.center-s.axis*s.length*.52+across*side*.55
				var tail=(16+G.hashf(i,p.seed_value)*22)*smoothstep(0,.35,s.q)*c.size
				G.shard(n,base,-s.axis,tail,2.2*c.size,dark,red,orange)
			for i in p.detail_count:
				var q=fposmod(s.age*3+G.hashf(i),1.0)
				var at=s.center-s.axis*(s.length*.5+q*44*c.size)+across*(G.hashf(i+20)-.5)*9*c.size
				G.pixel(n,at,G.color(Color("ffab48"),c,1-q),1)
		G.blade(n,s.center,s.axis,blade_length,s.width+2,dark,red,orange)
		G.blade(n,s.center,s.axis,blade_length*.94,s.width*.6,red,orange,hot)
		# A single midpoint seam keeps both tips visibly part of the same spear.
		G.line(n,s.center-across*s.width*.4,s.center+across*s.width*.4,hot)
		if phase=="form":
			var squeeze=pow(1-s.q,2)
			G.blade(n,s.center,s.axis,(5+5*squeeze)*c.size,(2+5*squeeze)*c.size,red,orange,hot)
			# Two compact pale ridges travel with the emerging opposing tips.
			for side in [-1,1]:
				var tip=s.center+s.axis*blade_length*.47*side
				G.line(n,tip-s.axis*minf(8*c.size,blade_length*.22)*side,tip,hot,c.size)
		for i in (0 if phase=="form" else p.flame_count):
			var u=(i+.5)/maxf(1,p.flame_count)-.5
			var at=s.center+s.axis*s.length*u+across*(1 if i%2 else -1)*s.width*.35
			var height=(3+3*sin(s.age*9+i*2))*c.size*s.growth
			G.shard(n,at,(-s.axis+across*sin(i*3+s.age*5)*.22).normalized(),height,1.8*c.size,red,orange,hot)
	elif phase=="impact":
		var q=s.q; var expand=1-pow(1-q,3); var fade=pow(1-q,1.6)

		if q<.28:
			G.blade(n,Vector2(0,-3),Vector2.DOWN,(1-q/.28)*19*c.size,12*c.size,red,orange,hot)
		for i in p.detail_count:
			var a=G.hashf(i,p.seed_value)*TAU
			var reach=s.radius*(.5+.5*G.hashf(i+40))*expand
			var at=Vector2(cos(a)*reach,sin(a)*reach*p.ground_squash-18*sin(q*PI)*G.hashf(i+80)*c.size)
			var motion=Vector2(cos(a)*1.6,sin(a)*p.ground_squash-.45*cos(q*PI)).normalized()
			G.line(n,at-motion*(4+8*fade)*c.size,at,G.color(Color("f57828"),c,fade),2*c.size)
			G.shard(n,at,motion,(2+5*fade)*c.size,1.5*c.size,G.color(Color("8f2a22"),c,fade),G.color(Color("f57828"),c,fade),G.color(Color("ffe8ae"),c,fade))
	elif phase in ["field","dissolve"]:
		_ground(n,s,p,c,phase=="dissolve")
func _ground(n:Node2D,s:Dictionary,p:Resource,c:Resource,dying:bool) -> void:
	var growth=1.0 if dying else smoothstep(0,minf(.24,s.duration),s.age)
	var fade=s.fade; var r=s.radius*growth
	if r<1 or fade<=0: return
	var cool=1-fade if dying else 0.0
	var ash=Color("27252d"); var coal=Color("4d2426").lerp(ash,cool)
	var red=Color("a83b28").lerp(ash,cool); var orange=Color("ef732e").lerp(ash,cool)
	lava.render(n,s,p,c,growth,cool)

	for i in p.bubble_count:
		var at=G.ground_site(i,p,.78)*c.size*growth
		var local=fposmod(s.age*.66+G.hashf(i+10,p.seed_value),1.0)
		if local>.53: continue
		var rr=(2.0+G.hashf(i+16)*2)*c.size
		if local<.34:
			var rise=sin(local/.34*PI*.7)
			G.ellipse(n,at+Vector2(0,-rr*.45*rise),rr*rise,.72,G.color(red,c,fade))
			G.line(n,at+Vector2(-rr*.5,-rr*.8*rise),at+Vector2(rr*.2,-rr*.9*rise),G.color(orange,c,fade))
		else:
			var burst=(local-.34)/.19
			G.ellipse(n,at,rr*(1+burst),.4,G.color(orange,c,fade*(1-burst)),false)
			for j in 3:
				var at2=at+Vector2((j-1)*rr*burst*1.8,-sin(burst*PI)*(rr+2))
				G.pixel(n,at2,G.color(Color("ffd079"),c,fade*(1-burst)))
	for i in p.ground_flame_count:
		var at=G.ground_site(i+31,p,.75)*c.size*growth
		var pulse=maxf(0,sin(s.age*3.5+i*2.1))
		if pulse<.1: continue
		G.shard(n,at,Vector2(sin(s.age*3+i)*.18,-1).normalized(),(4+6*pulse)*c.size*fade,2*c.size,G.color(red,c,fade),G.color(orange,c,fade),G.color(Color("ffd58b"),c,fade))
	for i in mini(p.ground_ember_count,10):
		var q=fposmod(s.age*.48+G.hashf(i+50),1)
		var at=G.ground_site(i+73,p,.75)*c.size+Vector2(sin(q*4+i)*2,-q*21)*c.size
		G.pixel(n,at,G.color(Color("d36d3c"),c,(1-q)*fade*.75))
