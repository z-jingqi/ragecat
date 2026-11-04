extends RefCounted
# Original pixel geometry. Palette-separated surfaces and restrained halo layering
# follow the reference methods documented in REFERENCES.md; no sprite art is used.
static func point(pose:Dictionary,x:float,y:float)->Vector2:
	return (pose.tip+pose.axis*x+Vector2(-pose.axis.y,pose.axis.x)*y).round()
static func dot(c:CanvasItem,p:Vector2,color:Color,size:float=1.0)->void:
	if color.a<=0: return
	var s=maxf(1,roundf(size)); c.draw_rect(Rect2((p-Vector2(s,s)*0.5).round(),Vector2(s,s)),color)
static func line(c:CanvasItem,a:Vector2,b:Vector2,color:Color,width:float=1.0)->void:
	if color.a>0: c.draw_line(a.round(),b.round(),color,maxf(1,roundf(width)),false)
static func local_line(c:CanvasItem,p:Dictionary,a:Vector2,b:Vector2,color:Color,width:float=1.0)->void:
	line(c,point(p,a.x,a.y),point(p,b.x,b.y),color,width)
static func polygon(c:CanvasItem,p:Dictionary,xy:Array,color:Color)->void:
	if color.a<=0: return
	var v=PackedVector2Array()
	for a in xy: v.append(point(p,a.x,a.y))
	if v.size()>2: c.draw_colored_polygon(v,color)
static func glow(c:CanvasItem,at:Vector2,radius:float,color:Color,power:float)->void:
	# Softness is restricted to light, never the body/element silhouette.
	if power<=0: return
	for i in range(6,0,-1):
		var r=radius*float(i)/6.0
		c.draw_circle(at.round(),r,Color(color,clampf(power*.018*(7-i),0,.13)))
static func random01(n:int,seed_value:int=0)->float:
	var v=(n*1597334677+seed_value*3812015801+12345)&0x7fffffff
	v=((v^(v>>13))*1274126177)&0x7fffffff
	return float(v%100000)/100000.0
static func noise(t:float,seed_value:int=0)->float:
	var i=int(floor(t)); var u=t-floor(t); u=u*u*(3-2*u)
	return lerpf(random01(i,seed_value),random01(i+1,seed_value),u)*2-1
static func tinted(c:Color,a:Resource,alpha:float=1.0)->Color:
	return Color(c.r*a.tint.r,c.g*a.tint.g,c.b*a.tint.b,clampf(c.a*a.tint.a*alpha*minf(a.intensity,1.0),0,1))
