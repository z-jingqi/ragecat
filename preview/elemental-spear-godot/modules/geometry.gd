extends RefCounted
static func hashf(i: float, seed_value: float=41.0) -> float:
	return fposmod(sin(i*127.1+seed_value*311.7)*43758.5453,1.0)
static func color(c: Color, s: Resource, alpha: float=1.0) -> Color:
	return Color(clampf(c.r*s.tint.r*s.intensity,0,1),clampf(c.g*s.tint.g*s.intensity,0,1),clampf(c.b*s.tint.b*s.intensity,0,1),clampf(c.a*s.tint.a*alpha,0,1))
static func poly(n:Node2D, pts:Array, c:Color) -> void:
	var p=PackedVector2Array()
	for v in pts:
		var point=Vector2(v).round()
		if p.is_empty() or p[-1]!=point: p.append(point)
	if p.size()>1 and p[0]==p[-1]: p.remove_at(p.size()-1)
	var area=0.0
	for i in p.size(): area+=p[i].cross(p[(i+1)%p.size()])
	if p.size()>2 and absf(area)>=1: n.draw_colored_polygon(p,c)
static func line(n:Node2D,a:Vector2,b:Vector2,c:Color,width:float=1) -> void:
	n.draw_line(a.round(),b.round(),c,maxf(1,width),false)
static func pixel(n:Node2D,p:Vector2,c:Color,size_value:float=1) -> void:
	n.draw_rect(Rect2(p.round(),Vector2.ONE*maxf(1,roundf(size_value))),c)
static func ellipse(n:Node2D,center:Vector2,r:float,squash:float,c:Color,filled:bool=true,width:float=1) -> void:
	var pts=PackedVector2Array()
	for j in 49:
		var a=TAU*float(j)/48.0; pts.append((center+Vector2(cos(a)*r,sin(a)*r*squash)).round())
	if filled: poly(n,Array(pts),c)
	else: n.draw_polyline(pts,c,maxf(1,width),false)
static func shard(n:Node2D,base:Vector2,axis:Vector2,length_value:float,width_value:float,dark:Color,bright:Color,hot:Color) -> void:
	var across=Vector2(axis.y,-axis.x); var tip=base+axis*length_value
	poly(n,[base-across*width_value,tip,base+across*width_value],dark)
	poly(n,[base-across*width_value,tip,base],bright)
	line(n,base,tip,hot)
static func blade(n:Node2D,center:Vector2,axis:Vector2,length_value:float,width_value:float,dark:Color,bright:Color,hot:Color) -> void:
	var across=Vector2(axis.y,-axis.x); var tip=axis*length_value*0.5
	poly(n,[center-tip,center-across*width_value*0.5,center+tip,center+across*width_value*0.5],dark)
	poly(n,[center-tip,center-across*width_value*0.5,center+tip,center],bright)
	line(n,center-tip,center+tip,hot)
static func ground_site(i:int,config:Resource,r:float=1) -> Vector2:
	var a=hashf(i,config.seed_value)*TAU; var d=sqrt(hashf(i+40,config.seed_value))*config.field_radius*r
	return Vector2(cos(a)*d,sin(a)*d*config.ground_squash)
static func bolt(n:Node2D,a:Vector2,b:Vector2,seed_value:float,c:Color,width_value:float=1.0,wiggle:float=3.0) -> void:
	var normal=(b-a).orthogonal().normalized(); var previous=a
	for j in range(1,7):
		var p=a.lerp(b,j/6.0)+normal*(hashf(j,seed_value)-0.5)*wiggle*(0 if j==6 else 1)
		line(n,previous,p,c,width_value); previous=p
