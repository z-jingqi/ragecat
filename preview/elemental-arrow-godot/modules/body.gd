extends RefCounted
const D=preload("drawing.gd")
const Reference=preload("body_reference.gd")
static func render(c:CanvasItem,p:Dictionary,t:float,q:Resource)->void:
	if q.body_style==1: Reference.render(c,p,t,q); return
	var l=q.length; var w=q.width; var tint=q.body_tint
	var outline=Color("17212a")*tint; var wood=Color("9b6b3e")*tint; var lit=Color("d4af75")*tint
	D.local_line(c,p,Vector2(-l,1*w),Vector2(-7,1*w),outline,2*w)
	D.local_line(c,p,Vector2(-l,0),Vector2(-6,0),wood,w)
	D.local_line(c,p,Vector2(-l+8,-w),Vector2(-8,-w),lit,w)
	# Two clipped feather vanes, with one-pixel barb shading. This is original geometry.
	var flutter=D.noise(floor(t*14)*.7,7)*.65
	for side in [-1,1]:
		var y=side*(3.3+flutter)*w
		D.polygon(c,p,[Vector2(-l+1,side*w),Vector2(-l-1,y),Vector2(-l+6,y*.82),Vector2(-l+11,side*w)],outline)
		D.polygon(c,p,[Vector2(-l+1,side*w),Vector2(-l,y*.78),Vector2(-l+5,y*.74),Vector2(-l+9,side*w)],(Color("e4d5b5") if side<0 else q.feather_color)*tint)
		for i in 3: D.local_line(c,p,Vector2(-l+2+i*2,side*w),Vector2(-l+i*2,y*.72),Color("f9edcd")*tint if side<0 else q.feather_color.lightened(.2)*tint,w)
	D.local_line(c,p,Vector2(-l-2,0),Vector2(-l+1,0),outline,w)
	# Needle point with stepped broadhead, steel ridge and cool underside.
	D.polygon(c,p,[Vector2(1,0),Vector2(-8,-4*w),Vector2(-7,-w),Vector2(-11,-w),Vector2(-11,2*w),Vector2(-7,2*w),Vector2(-8,4*w)],outline)
	D.polygon(c,p,[Vector2(0,0),Vector2(-7,-3*w),Vector2(-6,0)],Color("c6dce1")*tint)
	D.polygon(c,p,[Vector2(0,0),Vector2(-6,0),Vector2(-7,3*w)],Color("697e91")*tint)
	D.local_line(c,p,Vector2(-6,0),Vector2(0,0),Color("f4f3dc")*tint,w)
	for x in [-11,-9]: D.local_line(c,p,Vector2(x,-w),Vector2(x,2*w),Color("574034")*tint,w)
	if fposmod(t,.95)<.11: D.dot(c,D.point(p,-3,-w),Color("fff6dc")*tint)
static func air(c:CanvasItem,fx:Node2D)->void:
	if fx.pose.speed<8: return
	var t=fx.age
	for i in 5:
		var ph=fposmod(t*2.6+i*.193,1.0); var elapsed=ph*.28
		var p=fx.pose_at(t-elapsed)
		var x=-8.0-i*4.0-elapsed*32; var y=(4.0+ph*2)*(1 if i%2 else -1)
		var a=D.point(p,x,y); var b=a-p.axis*(4+ph*7)
		D.line(c,a,b,Color(.53,.66,.72,(1-ph)*.32))
