extends RefCounted
# Layered rooted tongues / shed heat adapted as an original arrow attachment from
# Sprite Fusion fire (MIT, Copyright (c) 2026 Hugo Duprez) and PixelFX fireball
# (MIT, Copyright (c) 2026 Patch and Hugo Duprez). See REFERENCES.md and licenses/.
const D=preload("drawing.gd")
const C=[Color("732322"),Color("b83223"),Color("ed5426"),Color("ff982d"),Color("ffce50"),Color("fff2b0")]
static func back(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var t=fx.age; var s=a.size; var power=a.intensity
	var stretch=clampf(p.speed/180.0,.35,1.6)
	for i in 4:
		var x=-7.0-i*5.0; var side=-1 if i%2==0 else 1
		var y=side*(1.6+0.4*i)*fx.profile.width
		var length=(13.0+5*D.noise(t*8+i,a.seed_value)+i*1.1)*s*stretch
		_tongue(fx,p,Vector2(x,y),length,(2.4+0.5*D.noise(t*6+i,3))*s,side,t,i,a)
	D.glow(fx,D.point(p,-12,0),15*s,D.tinted(C[3],a),.44*a.glow*power)
	D.glow(fx,D.point(p,-29,0),14*s,D.tinted(C[2],a),.23*a.glow*power)
	# Birth-space particles keep a curved wake behind the real moving arrow.
	var rate=38.0*clampf(power,.2,1.6); var latest=int(floor(t*rate))
	for j in 24:
		var birth_id=latest-j; var birth=float(birth_id)/rate
		if birth<0: continue
		var age=t-birth; var r=D.random01(birth_id,a.seed_value)
		var life=(.15+r*.22)*a.trail_length
		if life<=0 or age>=life: continue
		var u=age/life; var h=fx.pose_at(birth); var normal=Vector2(-h.axis.y,h.axis.x)
		var offset=-8.0-D.random01(birth_id,6)*22
		var side=D.random01(birth_id,19)*2-1
		var root=D.point(h,offset,side*2*s)
		var at=root+h.axis*h.speed*.16*age+normal*side*(6+10*r)*age+Vector2(0,-12)*age
		var col=D.tinted(C[clampi(int(5-u*5),0,5)],a,1-u*.75)
		if j%3==0:
			D.line(fx,at,at-h.axis*(2+2*(1-u))*s,col)
		else: D.dot(fx,at,col,maxf(1,(1-u)*2*s))
		if u<.6: D.glow(fx,at,3*s,D.tinted(C[3],a),.16*(1-u)*a.glow)
static func _tongue(c:CanvasItem,p:Dictionary,root:Vector2,length:float,width:float,side:float,t:float,id:int,a:Resource)->void:
	# Four hard palette shapes on a noisy taper, brightness kept inside a dark rim.
	for layer in 4:
		var ratio=[1.0,.78,.53,.27][layer]
		var reach=length*[1.0,.85,.62,.35][layer]
		var top=[]; var bottom=[]
		for k in 7:
			var u=float(k)/6; var wiggle=D.noise(u*3.5+t*9,id*17+a.seed_value)*u*2.3
			var center=root+Vector2(-reach*u,side*(u*1.5+wiggle))
			var half=width*ratio*pow(1-u,.65)*(0.6+0.4*sin(u*PI))
			top.append(center+Vector2(0,-half)); bottom.push_front(center+Vector2(0,half))
		top.append_array(bottom); D.polygon(c,p,top,D.tinted(C[[1,2,3,4][layer]],a))
static func front(fx:Node2D,a:Resource)->void:
	var p=fx.pose
	D.local_line(fx,p,Vector2(-7,-2*fx.profile.width),Vector2(0,0),D.tinted(C[4],a,.85))
	D.dot(fx,D.point(p,0,0),D.tinted(C[5],a))
	for i in 3:
		var x=-10-i*6
		if D.noise(fx.age*12+i,21)>.1: D.dot(fx,D.point(p,x,-fx.profile.width),D.tinted(C[4],a,.8))
