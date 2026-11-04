extends RefCounted
# Short-lived crackle and random midpoint displacement adapted from Sprite Fusion
# lightning (MIT, Copyright (c) 2026 Hugo Duprez) and PixelFX electrified / zigzag
# (MIT, Copyright (c) 2026 Patch and Hugo Duprez). Original arrow-local schedule,
# bounded roots and explicit micro-forks. No images, masks, sparks or history wake.
const D=preload("drawing.gd")
const DARK=Color("3e3978")
const BLUE=Color("597fe6")
const CYAN=Color("70dafa")
const WHITE=Color("e7fcff")
static func arc(from:Vector2,to:Vector2,seed_value:int,jag:float=1.0)->PackedVector2Array:
	var points=PackedVector2Array([from,to]); var off=from.distance_to(to)*.42*jag
	for depth in 2:
		var out=PackedVector2Array([points[0]])
		for i in range(points.size()-1):
			var a=points[i]; var b=points[i+1]; var v=(b-a).normalized()
			var n=Vector2(-v.y,v.x); var d=(D.random01(i+depth*73,seed_value)*2-1)*off
			out.append((a+b)*.5+n*d); out.append(b)
		points=out; off*=.52
	return points
static func bounded(points:PackedVector2Array,length:float,root_x:float,size:float)->PackedVector2Array:
	for i in points.size():
		points[i].x=clampf(points[i].x,maxf(-length+4,root_x-7),minf(-4,root_x+7))
		points[i].y=clampf(points[i].y,-8*size,8*size)
	return points
static func arcs_at(time:float,length:float,width:float,a:Resource)->Array:
	var result=[]
	if a.arc_density<=0 or a.intensity<=0: return result
	var slots=ceili(6*a.arc_density)
	for slot in slots:
		# Independent phase and duration avoid a synchronized whole-arrow flash.
		var period=.18+.06*D.random01(slot,a.seed_value+3)
		var phase=period*D.random01(slot,a.seed_value+11)
		var cycle=int(floor((time+phase)/period)); var age=time+phase-cycle*period
		var event_seed=a.seed_value+slot*211+cycle*7919
		var life=.065+.045*D.random01(cycle,event_seed+5)
		if age>=life or D.random01(cycle,event_seed+17)>minf(1,6*a.arc_density-slot): continue
		var lane=fposmod((float(slot)+D.random01(cycle,event_seed+29)*.85)/slots,1.0)
		var root_x=lerpf(-8,-length+8,lane)
		var side=-1.0 if D.random01(cycle,event_seed+37)<.5 else 1.0
		var root=Vector2(root_x,side*.9*width)
		var end=Vector2(clampf(root_x+(D.random01(cycle,event_seed+43)*2-1)*6,-length+4,-4),side*(3.8+2.2*D.random01(cycle,event_seed+53))*a.size)
		# Endpoint population lasts 65–110ms; irregular bolt geometry re-strikes at 30 Hz.
		var shape_seed=event_seed+int(time*30)*503
		var points=bounded(arc(root,end,shape_seed),length,root_x,a.size)
		var forks=[]
		if D.random01(cycle,event_seed+61)<.55:
			var start=points[2]
			var fork_end=start+Vector2((D.random01(cycle,event_seed+71)*2-1)*3.5,side*(2+2*D.random01(cycle,event_seed+83))*a.size)
			forks.append(bounded(arc(start,fork_end,shape_seed+97,.7),length,root_x,a.size))
		result.append({"id":Vector2i(slot,cycle),"points":points,"forks":forks,"age":age,"life":life,"opacity":1.0-.40*age/life})
	return result
static func line_path(fx:Node2D,points:PackedVector2Array,color:Color,width:float)->void:
	for i in range(points.size()-1): D.local_line(fx,fx.pose,points[i],points[i+1],color,width)
static func back(fx:Node2D,a:Resource)->void:
	# All faint fringes render before all bright cores, so arcs cannot erase each other.
	for event in arcs_at(fx.age,fx.profile.length,fx.profile.width,a):
		line_path(fx,event.points,D.tinted(DARK,a,.45*event.opacity),2)
		for branch in event.forks: line_path(fx,branch,D.tinted(BLUE,a,.22*event.opacity),2)
		var at=event.points[0]
		D.glow(fx,D.point(fx.pose,at.x,at.y),3.5*a.size,D.tinted(BLUE,a),.16*a.glow*event.opacity)
static func front(fx:Node2D,a:Resource)->void:
	for event in arcs_at(fx.age,fx.profile.length,fx.profile.width,a):
		line_path(fx,event.points,D.tinted(CYAN,a,event.opacity),1)
		for i in range(event.points.size()-1):
			if i%2==0: D.local_line(fx,fx.pose,event.points[i],event.points[i+1],D.tinted(WHITE,a,event.opacity),1)
		for branch in event.forks: line_path(fx,branch,D.tinted(CYAN,a,.8*event.opacity),1)
