extends RefCounted
# Layered rooted tongues / shed heat adapted as an original arrow attachment from
# Sprite Fusion fire (MIT, Copyright (c) 2026 Hugo Duprez) and PixelFX fireball
# (MIT, Copyright (c) 2026 Patch and Hugo Duprez). See REFERENCES.md and licenses/.
const D=preload("drawing.gd")
const C=[Color("732322"),Color("b83223"),Color("ed5426"),Color("ff982d"),Color("ffce50"),Color("fff2b0")]
static func _mass(fx:CanvasItem,p:Dictionary,a:Resource,t:float,scale_factor:float,col:Color)->void:
	var points=[]
	for i in 18:
		var angle=float(i)*TAU/18
		var r=(1.0+.10*D.noise(t*7+i*.8,a.seed_value))*scale_factor*a.size
		points.append(Vector2(-3.5+cos(angle)*7.4*r,sin(angle)*6.2*r))
	D.polygon(fx,p,points,D.tinted(col,a))
static func back(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var t=fx.age; var s=a.size
	# All flame roots cluster at the broadhead. No flames along the shaft.
	for i in 3:
		var side=-1 if i%2==0 else 1
		var root=Vector2(-4.0,side*(2.0+i*.75)*s)
		var length=(7.5+2.4*D.noise(t*8+i,a.seed_value))*s
		_tongue(fx,p,root,length,2.5*s,side,t,i,a)
	_mass(fx,p,a,t,1.0,C[1])
	_mass(fx,p,a,t,.80,C[2])
	_mass(fx,p,a,t,.57,C[3])
	D.glow(fx,D.point(p,-3.5,0),13*s,D.tinted(C[3],a),.55*a.glow)
	# Sparse, very short-lived flecks shed only from the arrowhead.
	var rate=16.0*clampf(a.intensity,.2,1.6); var latest=int(t*rate)
	for j in 6:
		var id=latest-j; var birth=float(id)/rate
		if birth<0: continue
		var age=t-birth; var life=(.035+.035*D.random01(id,a.seed_value))*a.trail_length
		if life<=0 or age>=life: continue
		var u=age/life; var h=fx.pose_at(birth); var normal=Vector2(-h.axis.y,h.axis.x)
		var side=D.random01(id,19)*2-1
		var at=D.point(h,-4,side*4*s)+h.axis*h.speed*.25*age+normal*side*12*age
		D.dot(fx,at,D.tinted(C[4 if u<.35 else 2],a,1-u))
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
	# Small hot center at the head; rear shaft and feathers remain unobscured.
	_mass(fx,fx.pose,a,fx.age,.45,C[4])
	D.polygon(fx,fx.pose,[Vector2(-3,-2)*a.size,Vector2(1,0)*a.size,Vector2(-3,2)*a.size,Vector2(-5,0)*a.size],D.tinted(C[5],a))
