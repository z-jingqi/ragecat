extends RefCounted
# Facet/ridge/underside method adapted from Sprite Fusion ice (MIT, Copyright
# (c) 2026 Hugo Duprez). Wake separation and shed glints follow PixelFX ice-lance
# (MIT, Copyright (c) 2026 Patch and Hugo Duprez). Original arrow-sized geometry.
const D=preload("drawing.gd")
const C=[Color("263451"),Color("385c91"),Color("65a8cc"),Color("9ce1ea"),Color("e7fbef")]
static func crystal(fx:CanvasItem,p:Dictionary,root:Vector2,tip:Vector2,width:float,a:Resource)->void:
	var axis=(tip-root).normalized(); var normal=Vector2(-axis.y,axis.x)*width
	var ridge=root-axis*.6
	D.polygon(fx,p,[tip,root+normal,ridge,root-normal],D.tinted(C[0],a))
	D.polygon(fx,p,[tip,root+normal*.8,ridge],D.tinted(C[2],a))
	D.polygon(fx,p,[tip,ridge,root-normal*.8],D.tinted(C[1],a))
	D.local_line(fx,p,tip,ridge,D.tinted(C[4],a))
static func back(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var t=fx.age; var s=a.size; var l=fx.profile.length
	# Three small asymmetrical crystals cling to the shaft, not a replacement lance.
	for i in 3:
		var x=-12.0-i*(l-16)/3; var side=-1 if i%2==0 else 1
		var root=Vector2(x,side*fx.profile.width)
		var tip=root+Vector2(-(4.4+i*.6)*s,side*(5.5-i*.55)*s)
		crystal(fx,p,root,tip,(2.0-i*.16)*s,a)
	D.glow(fx,D.point(p,-9,0),14*s,D.tinted(C[2],a),.22*a.glow*a.intensity)
	if a.trail_length>0 and p.speed>8:
		var previous=D.point(p,-l+5,0)
		for i in range(1,12):
			var age=float(i)*.018*a.trail_length; var h=fx.pose_at(maxf(0,t-age))
			var at=D.point(h,-l+5,0); var alpha=(1-float(i)/12)*.20
			D.line(fx,previous,at,D.tinted(C[2],a,alpha),3*s)
			D.line(fx,previous,at,D.tinted(C[3],a,alpha*.7))
			previous=at
	# Thin cold vapour lives in world space; pale particles do not rotate with the arrow.
	var rate=22.0*clampf(a.intensity,.25,1.5); var latest=int(t*rate)
	for j in 18:
		var id=latest-j; var birth=float(id)/rate
		if birth<0: continue
		var age=t-birth; var life=(.20+.18*D.random01(id,a.seed_value))*a.trail_length
		if life<=0 or age>=life: continue
		var u=age/life; var h=fx.pose_at(birth); var normal=Vector2(-h.axis.y,h.axis.x)
		var side=D.random01(id,23)*2-1
		var at=D.point(h,-8-D.random01(id,31)*(l-8),side*2*s)+h.axis*h.speed*.12*age+normal*side*7*age+Vector2(0,4)*age
		if id%3==0:
			var r=(1+u*2.8)*s
			fx.draw_circle(at.round(),r,D.tinted(C[2],a,.09*(1-u)))
			fx.draw_circle((at-normal*.5).round(),r*.58,D.tinted(C[3],a,.12*(1-u)))
		else:
			var axis=Vector2.from_angle(id*.91+age*9)
			D.line(fx,at-axis*1.1*s,at+axis*1.1*s,D.tinted(C[2 if u>.45 else 3],a,1-u*.8))
			if u<.48: D.dot(fx,at+axis*1.1*s,D.tinted(C[4],a))
static func front(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var l=fx.profile.length; var w=fx.profile.width
	D.local_line(fx,p,Vector2(-7,-3*w),Vector2(0,0),D.tinted(C[3],a))
	D.local_line(fx,p,Vector2(-7,3*w),Vector2(0,0),D.tinted(C[1],a,.8))
	D.dot(fx,D.point(p,0,0),D.tinted(C[4],a))
	for i in range(int(l-16)):
		D.dot(fx,D.point(p,-9-i,-w),D.tinted(C[3 if i%5 else 4],a,.92))
	D.local_line(fx,p,Vector2(-l+10,w),Vector2(-10,w),D.tinted(C[1],a,.75))
	D.local_line(fx,p,Vector2(-l+1,-2*w),Vector2(-l+7,-w),D.tinted(C[3],a,.9))
	var phase=fposmod(fx.age,1.25)/1.25
	if phase<.22:
		var x=-8-phase*3.4*(l-12); var at=D.point(p,x,-w)
		D.dot(fx,at,D.tinted(C[4],a)); D.dot(fx,at+Vector2(0,-1),D.tinted(C[3],a,.7))
		D.glow(fx,at,4*a.size,D.tinted(C[3],a),.3*a.glow)
