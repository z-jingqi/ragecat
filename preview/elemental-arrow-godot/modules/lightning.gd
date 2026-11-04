extends RefCounted
# Midpoint displacement and bright-core/dark-sheath strokes adapted from
# Sprite Fusion lightning (MIT, Copyright (c) 2026 Hugo Duprez). Short re-struck
# surface paths follow PixelFX electrified (MIT, Copyright (c) 2026 Patch and
# Hugo Duprez). Original arrow roots, branch schedule and history-based wake.
const D=preload("drawing.gd")
const DARK=Color("3e3978")
const BLUE=Color("597fe6")
const CYAN=Color("70dafa")
const WHITE=Color("e7fcff")
static func arc(from:Vector2,to:Vector2,seed_value:int,jag:float=1.0)->PackedVector2Array:
	var points=PackedVector2Array([from,to]); var off=from.distance_to(to)*.15*jag
	for depth in 3:
		var out=PackedVector2Array([points[0]])
		for i in range(points.size()-1):
			var a=points[i]; var b=points[i+1]; var v=(b-a).normalized()
			var n=Vector2(-v.y,v.x); var d=(D.random01(i+depth*73,seed_value)*2-1)*off
			out.append((a+b)*.5+n*d); out.append(b)
		points=out; off*=.5
	return points
static func stroke(fx:CanvasItem,points:PackedVector2Array,a:Resource,k:float=1.0,white:bool=true)->void:
	for i in range(points.size()-1):
		D.line(fx,points[i],points[i+1],D.tinted(DARK,a,.72*k),3*a.size)
		D.line(fx,points[i],points[i+1],D.tinted(CYAN if white else BLUE,a,k))
		if white and i%3!=0: D.line(fx,points[i],points[i+1],D.tinted(WHITE,a,k*.95))
		if i%3==0: D.glow(fx,points[i],5*a.size,D.tinted(BLUE,a),.22*a.glow*k)
static func back(fx:Node2D,a:Resource)->void:
	var t=fx.age; var p=fx.pose; var frame=int(t*20); var l=fx.profile.length; var s=a.size
	for i in 2:
		var side=-1 if i==0 else 1
		var from=D.point(p,-4-i*2,side*1.4*fx.profile.width)
		var end=D.point(p,-l+6+i*3,side*(2.7+1.5*D.random01(frame,i+8))*s)
		var points=arc(from,end,a.seed_value+frame*41+i*503,.92)
		stroke(fx,points,a,1.0 if i==0 else .62,i==0)
		if frame%5<3:
			var root=points[4]; var branch_end=D.point(p,-l+2-i*4,side*(6+3*D.random01(frame,3))*s)
			stroke(fx,arc(root,branch_end,frame+13,.9),a,.65,false)
	# Short discontinuous wake, rooted at the fletching's historic world poses.
	if a.trail_length>0 and p.speed>8:
		var points=PackedVector2Array()
		for i in 6:
			var dt=float(i)*.018*a.trail_length
			var h=fx.pose_at(maxf(0,t-dt)); var side=(D.random01(frame*19+i,a.seed_value)-.5)*4*s
			points.append(D.point(h,-l+2-i*.7,side))
		stroke(fx,points,a,.58,false)
		for i in range(points.size()-1):
			if (frame+i)%3==0: D.line(fx,points[i],points[i+1],D.tinted(CYAN,a,.85))
	D.glow(fx,D.point(p,-7,0),11*s,D.tinted(BLUE,a),.38*a.glow*a.intensity)
	var latest=int(t*27)
	for j in 12:
		var id=latest-j; var birth=float(id)/27
		if birth<0: continue
		var age=t-birth; var life=(.10+D.random01(id,2)*.14)*a.trail_length
		if life<=0 or age>=life: continue
		var u=age/life; var h=fx.pose_at(birth); var normal=Vector2(-h.axis.y,h.axis.x)
		var side=-1 if id%2 else 1; var root=D.point(h,-8-D.random01(id,4)*(l-10),side*2*s)
		var at=root+h.axis*h.speed*.08*age+normal*side*(10+17*D.random01(id,5))*age*s
		D.dot(fx,at,D.tinted(WHITE if u<.28 else CYAN if u<.6 else BLUE,a,1-u))
static func front(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var frame=int(fx.age*20)
	D.local_line(fx,p,Vector2(-6,-2*fx.profile.width),Vector2(0,0),D.tinted(CYAN,a,.9))
	D.dot(fx,D.point(p,0,0),D.tinted(WHITE,a))
	# A compact cross-body jolt rather than a full silhouette or screen flash.
	if frame%9<2:
		var x=-10-D.random01(frame,a.seed_value)*12
		var points=arc(D.point(p,x,-3*a.size),D.point(p,x-3,3*a.size),frame+23,.6)
		stroke(fx,points,a,.8)
