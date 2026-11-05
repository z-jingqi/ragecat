extends RefCounted
## Original procedural single-ring stone study. No morphing, scale or integration.
## All source vertices are immutable; breakup changes only pivot position/rotation.

static func _noise(s:Dictionary, index:int)->float:
	return fposmod(sin(float(s.get("seed",0))*.173+float(index)*17.713+float(s.get("variant",.5))*31.0)*43758.5453,1.0)

static func fragments(s:Dictionary)->Array[PackedVector2Array]:
	var h:float=s.get("height",31.0)
	var w:float=s.get("width",14.0)
	var lean:float=s.get("lean",0.0)
	var left:PackedVector2Array=[]
	var right:PackedVector2Array=[]
	var middle:PackedVector2Array=[]
	var levels:Array[float]=[0.0,.24,.49,.73,1.0]
	var widths:Array[float]=[.5,.48,.37,.23,0.0]
	for i in 5:
		var y:float=-h*levels[i]
		var x:float=lean*h*levels[i]
		left.append(Vector2(x-w*widths[i],y))
		right.append(Vector2(x+w*widths[i]*(.91+_noise(s,40+i)*.15),y))
		middle.append(Vector2(x+w*(_noise(s,20+i)-.5)*.16,y))
	var out:Array[PackedVector2Array]=[]
	for band in 3:
		# Matching split vertices partition each broad stratum without overlaps.
		var kink:Vector2=middle[band].lerp(middle[band+1],.52)+Vector2(w*.075,0)
		out.append(PackedVector2Array([left[band],middle[band],kink,middle[band+1],left[band+1]]))
		out.append(PackedVector2Array([middle[band],right[band],right[band+1],middle[band+1],kink]))
	out.append(PackedVector2Array([left[3],right[3],left[4]]))
	return out

static func _center(points:PackedVector2Array)->Vector2:
	var result:=Vector2.ZERO
	for point in points: result+=point
	return result/float(points.size())

static func fragment_points(s:Dictionary, fragment:PackedVector2Array, index:int, travel:float, p)->PackedVector2Array:
	var t:float=clampf(travel,0.0,1.0)
	var center:Vector2=_center(fragment)
	var random:float=_noise(s,index)
	var flight:float=.60+random*.20
	var u:float=minf(t/flight,1.0)
	var side:float=-1.0 if index%2==0 else 1.0
	var angle:float=side*(.45+random*1.25)*u
	var direction:Vector2=s.get("direction",Vector2.RIGHT)
	var scatter:float=p.scatter
	var offset:=Vector2(side*(5.0+random*9.0)+direction.x*6.0,direction.y*3.0)*scatter
	var final_angle:float=side*(.45+random*1.25)
	var bottom:float=-INF
	for point in fragment:
		bottom=maxf(bottom,(point-center).rotated(final_angle).y)
	var target_y:float=offset.y-bottom
	# Constant horizontal velocity, constant gravity. Exactly reaches ground at u=1.
	var initial_up:float=-(2.0+random*3.0)
	var y:float=center.y+initial_up*u+(target_y-center.y-initial_up)*u*u
	var x:float=center.x+offset.x*u
	if t>flight:
		# One small ballistic rebound. Then position AND rotation stay unchanged.
		var bounce:float=clampf((t-flight)/.15,0.0,1.0)
		y=target_y-(.65+random*.5)*4.0*bounce*(1.0-bounce)
	var pivot:Vector2=Vector2(s.get("pos",Vector2.ZERO))+Vector2(x,y)
	var result:PackedVector2Array=[]
	for point in fragment: result.append(pivot+(point-center).rotated(angle))
	return result

static func _above_ground(points:PackedVector2Array, ground:float)->PackedVector2Array:
	var out:PackedVector2Array=[]
	for i in points.size():
		var a:Vector2=points[(i+points.size()-1)%points.size()]
		var b:Vector2=points[i]
		var a_in:bool=a.y<=ground
		var b_in:bool=b.y<=ground
		if a_in!=b_in: out.append(a.lerp(b,(ground-a.y)/(b.y-a.y)))
		if b_in: out.append(b)
	return out

static func _alpha(color:Color, opacity:float)->Color:
	return Color(color,color.a*opacity)

static func _polygon(c:Node2D,points:PackedVector2Array,color:Color)->void:
	# Pixel snapping is a render operation, never part of the rigid transform API.
	var rounded:PackedVector2Array=[]
	for point in points:
		var q:Vector2=point.round()
		if rounded.is_empty() or rounded[-1]!=q: rounded.append(q)
	if rounded.size()>1 and rounded[0]==rounded[-1]: rounded.remove_at(rounded.size()-1)
	if rounded.size()<3 or Geometry2D.triangulate_polygon(rounded).is_empty(): return
	c.draw_colored_polygon(rounded,color)

static func draw_spike(c:Node2D,s:Dictionary,age:float,p)->void:
	var break_at:float=p.rise_time+p.hold_time
	var settled_at:float=break_at+p.break_time
	if age<0.0 or age>=settled_at+p.residue_lifetime: return
	var fade:float=1.0-smoothstep(settled_at+p.residue_lifetime*.8,settled_at+p.residue_lifetime,age)
	var chunks:Array[PackedVector2Array]=fragments(s)
	var base:Vector2=s.get("pos",Vector2.ZERO)
	var rise:float=clampf(age/maxf(.001,p.rise_time),0.0,1.0)
	var lift:float=float(s.get("height",31.0))*(1.0-rise)*(1.0-rise)
	var travel:float=clampf((age-break_at)/maxf(.001,p.break_time),0.0,1.0)
	var seams:float=smoothstep(break_at-.075,break_at-.012,age)
	for i in chunks.size():
		var points:PackedVector2Array=[]
		if age>=break_at: points=fragment_points(s,chunks[i],i,travel,p)
		else:
			for point in chunks[i]: points.append(base+point+Vector2(0,lift))
			points=_above_ground(points,base.y)
		if points.size()<3: continue
		var body:Color=p.primary if i%2==0 else p.primary.darkened(.20)
		_polygon(c,points,_alpha(body,fade))
		# A small fixed cut face belongs to each chunk, not a shrinking rubble proxy.
		var face:PackedVector2Array=[]
		var source:PackedVector2Array=chunks[i]
		var pivot:Vector2=_center(source)
		for j in 3: face.append(source[j].lerp(pivot,.22))
		if age>=break_at:
			# Transform face with the SAME pivot/rotation as the full fragment.
			var transformed:PackedVector2Array=fragment_points(s,source,i,travel,p)
			var center_world:Vector2=_center(transformed)
			var rotation:float=(transformed[1]-transformed[0]).angle()-(source[1]-source[0]).angle()
			for j in face.size(): face[j]=center_world+(face[j]-pivot).rotated(rotation)
		else:
			for j in face.size(): face[j]+=base+Vector2(0,lift)
			face=_above_ground(face,base.y)
		_polygon(c,face,_alpha(p.highlight,fade*.65))
		if seams>0.0:
			for j in points.size():
				c.draw_line(points[j].round(),points[(j+1)%points.size()].round(),_alpha(p.shadow,fade*seams),1.0,false)
	# Small dry chips accompany the eruption, not a large smoke cloud.
	var grit_t:float=age/.23
	if grit_t<1.0:
		for i in int(round(7.0*p.grit_density)):
			var side:float=-1.0 if i%2==0 else 1.0
			var random:float=_noise(s,100+i)
			var q:Vector2=base+Vector2(side*(3.0+(5.0+random*8.0)*grit_t),-(5.0+random*5.0)*4.0*grit_t*(1.0-grit_t))
			c.draw_rect(Rect2(q.round(),Vector2(1.0+float(i%2),1.0+float(i%2))),_alpha(p.primary,1.0-grit_t))
