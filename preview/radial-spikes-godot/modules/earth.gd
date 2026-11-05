extends RefCounted
## Original procedural chipped stone. Stateless: arbitrary-time seek is repeatable.
static func palette()->Dictionary:
	return {"primary":Color("a97b51"),"highlight":Color("e1b477"),"shadow":Color("4a3940")}
static func label()->String: return "EARTH"
static func _poly(c:Node2D,points:Array,col:Color)->void:
	var out:PackedVector2Array=[]
	for point in points: out.append(Vector2(point).round())
	c.draw_colored_polygon(out,col)
static func _color(col:Color,alpha:float)->Color: return Color(col,alpha*col.a)
static func draw_spike(c:Node2D,s:Dictionary,age:float,p:Resource)->void:
	if age<0 or age>=p.rise_time+p.hold_time+p.fade_time: return
	var fade:float=clampf((age-p.rise_time-p.hold_time)/p.fade_time,0,1)
	var lift:float=1-pow(1-clampf(age/p.rise_time,0,1),3)
	var a:float=1-smoothstep(0,1,fade)
	var base:Vector2=s.pos
	var h:float=s.height*lift*(1-.38*fade*fade)
	var w:float=s.width
	var v:float=s.variant
	var lean:float=s.lean
	var dark:Color=_color(p.shadow,a)
	var body:Color=_color(p.primary,a)
	var light:Color=_color(p.highlight,a)
	# A broken earth fissure, never a smooth glowing disk.
	var crack:Color=_color(p.shadow,a*p.ground_opacity)
	_poly(c,[base+Vector2(-w*.9,0),base+Vector2(-w*.45,-3),base+Vector2(w*.5,-2),base+Vector2(w*.95,1),base+Vector2(w*.4,4),base+Vector2(-w*.4,3)],crack)
	for k in 3:
		var sign_x:float=-1 if k%2==0 else 1
		var start:Vector2=base+Vector2(sign_x*w*.6,k-1)
		var elbow:Vector2=start+Vector2(sign_x*(3+v*4),k-2)
		c.draw_line(start.round(),elbow.round(),crack,1)
		c.draw_line(elbow.round(),(elbow+Vector2(sign_x*3,2)).round(),crack,1)
	if h>1:
		var tip:Vector2=base+Vector2((lean+.12*(v-.5))*h,-h)
		var shoulder:Vector2=base+Vector2(w*.36+lean*h*.55,-h*.54)
		var left:Vector2=base+Vector2(-w*.51,0)
		var right:Vector2=base+Vector2(w*.5,1)
		var ridge:Vector2=base+Vector2(-w*.08+lean*h*.55,-h*.45)
		_poly(c,[left,base+Vector2(-w*.42+lean*h*.48,-h*.48),tip,shoulder,right,base+Vector2(w*.18,3)],dark)
		_poly(c,[left,base+Vector2(-w*.42+lean*h*.48,-h*.48),tip,ridge,base+Vector2(w*.08,1)],body)
		_poly(c,[tip,shoulder,right,base+Vector2(w*.08,1),ridge],_color(p.primary.darkened(.30),a))
		_poly(c,[tip,base+Vector2(-w*.42+lean*h*.48,-h*.48),ridge],light)
		# Short stepped seams make broad stone strata rather than glass planes.
		for band in 2:
			var t:float=.28+band*.27
			var at:Vector2=base+Vector2(lean*h*t,-h*t)
			c.draw_line((at+Vector2(-w*.29,1)).round(),(at+Vector2(w*.05,-1)).round(),dark,1)
			c.draw_line((at+Vector2(w*.05,0)).round(),(at+Vector2(w*.25,-2)).round(),_color(p.highlight.darkened(.2),a*.8),1)
		# Low angular side chunk breaks a repeated triangle silhouette.
		if v>.30:
			var side:float=-1 if v<.65 else 1
			_poly(c,[base+Vector2(side*w*.26,1),base+Vector2(side*w*.72,-h*.34),base+Vector2(side*w*.9,0),base+Vector2(side*w*.6,3)],body)
			c.draw_line((base+Vector2(side*w*.26,1)).round(),(base+Vector2(side*w*.72,-h*.34)).round(),light,1)
	# Settling grit follows a short ballistic arc then disappears.
	var burst:float=age/.46
	if burst<1:
		for k in int(round(4*p.debris_density)):
			var angle:float=float(k)*2.399+v*TAU
			var travel:float=(5+fmod(v*17+k*7,9))*burst
			var q:Vector2=base+Vector2(cos(angle)*travel,sin(angle)*travel*.4-13*sin(burst*PI))
			var size:int=2 if k%3==0 else 1
			c.draw_rect(Rect2(q.round(),Vector2(size,size)),_color(p.highlight if k%2==0 else p.primary,(1-burst)*a))
	# Late dry dust stays restrained and local to the base.
	if fade>0:
		for k in int(round(3*p.debris_density)):
			var q:Vector2=base+Vector2((k-1)*w*.55*(1+fade),-1-fade*(2+v*3))
			c.draw_rect(Rect2(q.round(),Vector2(3,1)),_color(p.primary,a*.3))
