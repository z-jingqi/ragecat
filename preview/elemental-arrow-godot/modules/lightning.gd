extends RefCounted
# Original shaft-local helix. Jagged midpoint segments and thin bright cores adapt
# Sprite Fusion lightning / PixelFX zigzag methods, with preserved MIT notices.
# Previous micro-arcs remain byte-identical in lightning_crackle.gd.
const D=preload("drawing.gd")
const Crackle=preload("lightning_crackle.gd")
const DARK=Color("3e3978")
const BLUE=Color("597fe6")
const CYAN=Color("70dafa")
const WHITE=Color("e7fcff")
static func arc(from:Vector2,to:Vector2,seed_value:int,jag:float=1.0)->PackedVector2Array:
	return Crackle.arc(from,to,seed_value,jag)
static func arcs_at(time:float,length:float,width:float,a:Resource)->Array:
	if a.lightning_mode==1: return Crackle.arcs_at(time,length,width,a)
	var result=[]
	if a.arc_density<=0 or a.intensity<=0: return result
	var slots=ceili(2*a.arc_density)
	var tick=int(floor(time*30))
	for strand in slots:
		var seed_value=a.seed_value+strand*2017
		var turns=1.65+.35*D.random01(strand,seed_value+3)
		var phase=time*(5.5+.7*D.random01(strand,seed_value+7))+strand*2.55+D.random01(strand,seed_value+11)*.45
		var radius=(3.9+.7*D.random01(strand,seed_value+13))*a.size+width*.25
		var steps=ceili(turns*8)
		var points=PackedVector2Array(); var depths=PackedFloat32Array()
		for i in steps+1:
			var u=float(i)/steps
			var theta=phase+u*turns*TAU
			var envelope=clampf(minf(u,1-u)*8,0,1)
			var jitter=(D.random01(i+tick*137,seed_value+19)*2-1)*.85*a.size*envelope
			var y=(sin(theta)*radius+jitter)*envelope
			var p=Vector2(lerpf(-1,-length+1,u),y)
			if i>0:
				# Random displaced midpoint adds a small electric kink, not a smooth rope.
				var middle=(points[-1]+p)*.5
				middle.y+=(D.random01(i+tick*151,seed_value+23)*2-1)*.8*a.size*envelope
				points.append(middle); depths.append((depths[-1]+cos(theta))*.5)
			points.append(p); depths.append(cos(theta))
		var segments=[]
		for i in range(points.size()-1):
			var z0=depths[i]; var z1=depths[i+1]
			if z0*z1<0:
				var crossing=points[i].lerp(points[i+1],absf(z0)/(absf(z0)+absf(z1)))
				segments.append({"from":points[i],"to":crossing,"front":z0>=0,"hot":i%3!=1})
				segments.append({"from":crossing,"to":points[i+1],"front":z1>=0,"hot":i%3!=1})
			else: segments.append({"from":points[i],"to":points[i+1],"front":z0+z1>=0,"hot":i%3!=1})
		var density_weight=minf(1.0,2*a.arc_density-strand)
		var flicker=.78+.22*D.random01(tick,seed_value+29)
		result.append({"id":strand,"points":points,"depths":depths,"segments":segments,"forks":[],"opacity":density_weight*flicker})
	return result
static func draw_side(fx:Node2D,a:Resource,front_side:bool)->void:
	var events=arcs_at(fx.age,fx.profile.length,fx.profile.width,a)
	# Rear halves render before the arrow body; front halves cover it afterward.
	for event in events:
		for segment in event.segments:
			if segment.front!=front_side: continue
			D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(DARK,a,.42*event.opacity),2)
	for event in events:
		for segment in event.segments:
			if segment.front!=front_side: continue
			var color=(WHITE if segment.hot else CYAN) if front_side else BLUE
			D.local_line(fx,fx.pose,segment.from,segment.to,D.tinted(color,a,event.opacity*(1.0 if front_side else .7)),1)
		if front_side and a.glow>0:
			for i in range(3,event.points.size()-3,10):
				if event.depths[i]>0:
					var p=event.points[i]
					D.glow(fx,D.point(fx.pose,p.x,p.y),2.5*a.size,D.tinted(BLUE,a),.08*a.glow*event.opacity)
static func back(fx:Node2D,a:Resource)->void:
	if a.lightning_mode==1: Crackle.back(fx,a)
	else: draw_side(fx,a,false)
static func front(fx:Node2D,a:Resource)->void:
	if a.lightning_mode==1: Crackle.front(fx,a)
	else: draw_side(fx,a,true)
