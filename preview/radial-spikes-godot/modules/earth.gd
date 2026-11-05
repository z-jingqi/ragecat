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
	var split_at:float=p.rise_time+p.hold_time
	var settled_at:float=split_at+p.fade_time
	var residue_age:float=maxf(0,age-settled_at)
	if age<0 or age>=settled_at+p.residue_lifetime: return
	var residue_alpha:float=1-smoothstep(p.residue_lifetime*.75,p.residue_lifetime,residue_age)
	if age>=settled_at and (p.residue_density<=0 or residue_alpha<=0): return
	var fade:float=clampf((age-p.rise_time-p.hold_time)/p.fade_time,0,1)
	var rise:float=clampf(age/p.rise_time,0,1)
	# Fast ease-out plus a small transient overshoot; the held shape is unchanged.
	var lift:float=1-pow(1-rise,3)+sin(rise*PI)*.14*p.impact_strength
	var a:float=residue_alpha
	var base:Vector2=s.pos
	var h:float=s.height*lift
	var w:float=s.width
	var v:float=s.variant
	var lean:float=s.lean
	var dark:Color=_color(p.shadow,a)
	var body:Color=_color(p.primary,a)
	var light:Color=_color(p.highlight,a)
	# A broken earth fissure, never a smooth glowing disk.
	var crack:Color=_color(p.shadow,a*p.ground_opacity*(1-.65*fade))
	_poly(c,[base+Vector2(-w*.9,0),base+Vector2(-w*.45,-3),base+Vector2(w*.5,-2),base+Vector2(w*.95,1),base+Vector2(w*.4,4),base+Vector2(-w*.4,3)],crack)
	for k in 3:
		var sign_x:float=-1 if k%2==0 else 1
		var start:Vector2=base+Vector2(sign_x*w*.6,k-1)
		var elbow:Vector2=start+Vector2(sign_x*(3+v*4),k-2)
		c.draw_line(start.round(),elbow.round(),crack,1)
		c.draw_line(elbow.round(),(elbow+Vector2(sign_x*3,2)).round(),crack,1)
	if age>=split_at:
		_draw_chunks(c,s,fade,residue_alpha,p)
	elif h>1:
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
	if fade>0 and fade<1:
		for k in int(round(3*p.debris_density)):
			var q:Vector2=base+Vector2((k-1)*w*.55*(1+fade),-1-fade*(2+v*3))
			c.draw_rect(Rect2(q.round(),Vector2(3,1)),_color(p.primary,a*.3*(1-fade)))

# Clip the original stone outline into thick strata. These are real separated
# polygons, not a fading or uniformly shrinking copy of the upright cone.
static func _clip_y(points:Array,edge:float,keep_below:bool)->Array:
	var result:Array=[]
	for i in points.size():
		var previous:Vector2=points[(i+points.size()-1)%points.size()]
		var current:Vector2=points[i]
		var inside:bool=current.y>=edge if keep_below else current.y<=edge
		var was_inside:bool=previous.y>=edge if keep_below else previous.y<=edge
		if inside!=was_inside:
			result.append(previous.lerp(current,(edge-previous.y)/(current.y-previous.y)))
		if inside: result.append(current)
	return result

static func _noise(seed_value:float,index:int)->float:
	return fposmod(sin(seed_value*.017+float(index)*17.713)*43758.5453,1.0)

static func _draw_chunks(c:Node2D,s:Dictionary,travel:float,alpha:float,p:Resource)->void:
	var h:float=s.height
	var w:float=s.width
	var lean:float=s.lean
	var v:float=s.variant
	var seed_value:float=float(s.get("seed",0))+v*131
	var direction:Vector2=s.get("direction",Vector2.RIGHT)
	if direction.length_squared()<.001: direction=Vector2.RIGHT
	direction=direction.normalized()
	var tangent:Vector2=Vector2(-direction.y,direction.x)
	var outline:Array=[Vector2(-w*.51,0),Vector2(-w*.42+lean*h*.48,-h*.48),Vector2((lean+.12*(v-.5))*h,-h),Vector2(w*.36+lean*h*.55,-h*.54),Vector2(w*.5,1),Vector2(w*.18,3)]
	# A brief pause at impact lets the rock settle, with no time integration or RNG.
	var t:float=clampf(travel/ .91,0,1)
	var outward:float=1-pow(1-t,2)
	var landing:float=smoothstep(.35,1,t)
	var retained:int=clampi(int(ceil(4*p.residue_density)),0,4)
	for k in 4:
		var top:float=-h+float(k)*h*.25
		var bottom:float=3 if k==3 else top+h*.25
		var fragment:Array=_clip_y(_clip_y(outline,top,true),bottom,false)
		if fragment.size()<3: continue
		var center:Vector2=Vector2.ZERO
		for point in fragment: center+=Vector2(point)
		center/=float(fragment.size())
		var random:float=_noise(seed_value,k)
		var scatter:Vector2=direction*(3+random*7)*p.impact_strength+tangent*((float(k)-1.5)*w*.34)
		var destination:Vector2=scatter*p.residue_size
		var q:Vector2=Vector2(s.pos)+Vector2(center.x,0).lerp(destination,outward)
		q.y+=center.y*(1-t*t)-sin(t*PI)*(2+random*3)*p.impact_strength
		var angle:float=lerpf(0,(-.7 if k%2==0 else .7)*( .8+random*.4),outward)
		var opacity:float=alpha
		if k>=retained: opacity*=1-smoothstep(.78,1,travel)
		if opacity<=0: continue
		var points:Array=[]
		for point in fragment:
			var local:Vector2=(Vector2(point)-center).rotated(angle)
			# A slab tips onto the floor: its vertical projection flattens, while
			# its width remains broad and its silhouette remains an angular stone.
			local.x*=lerpf(1,p.residue_size,landing)
			local.y*=lerpf(1,.32*p.residue_size,landing)
			points.append(q+local)
		_poly(c,points,_color(p.primary if k%2==0 else p.primary.darkened(.18),opacity))
		# Flat top and short dark underside make each settled stone read as volume.
		var face:Array=[]
		for point in points: face.append(Vector2(point).lerp(q,.55)+Vector2(-1,-1))
		_poly(c,face,_color(p.highlight,opacity*.8))
		c.draw_line(Vector2(points[0]).round(),Vector2(points[-1]).round(),_color(p.shadow,opacity),1)
