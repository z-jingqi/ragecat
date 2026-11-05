extends RefCounted
## Original dry-rock study: one continuous surface, then seven immutable rigid pieces.
## Geometry lives in local rock space. Animation never scales or deforms it.

static func _noise(s:Dictionary, index:int)->float:
	return fposmod(sin(float(s.get("seed",17))*.173+float(index)*17.713+float(s.get("variant",.5))*31.0)*43758.5453,1.0)

static func _point(s:Dictionary,x:float,y:float)->Vector2:
	var h:float=s.get("height",42.0)
	return Vector2(x*float(s.get("width",27.0))-y*h*float(s.get("lean",.1)),y*h)

static func outline(s:Dictionary)->PackedVector2Array:
	# Uneven contour ledges, not repeated bands. Tip is intentionally off-center.
	var n:float=(_noise(s,91)-.5)*.035
	var source:Array[Vector2]=[Vector2(-.50,0),Vector2(-.46,-.19),Vector2(-.38,-.39),Vector2(-.40,-.44),Vector2(-.20+n,-.76),Vector2(.015,-1),Vector2(.18,-.79),Vector2(.21,-.64),Vector2(.35,-.57),Vector2(.38,-.30),Vector2(.49,0),Vector2(-.02,0)]
	var result:PackedVector2Array=[]
	for q in source: result.append(_point(s,q.x,q.y))
	return result

static func _network(s:Dictionary)->Dictionary:
	var o:PackedVector2Array=outline(s)
	var a:Vector2=_point(s,-.12,-.35)
	var b:Vector2=_point(s,.015,-.69)
	var d:Vector2=_point(s,.18,-.19)
	# Every shared edge is literally reused (including its kink), preventing holes.
	return {"o":o,"a":a,"b":b,"d":d,"ab":a.lerp(b,.58)+_point(s,-.035,0),"bd":b.lerp(d,.44)+_point(s,.045,0),"da":d.lerp(a,.61)+_point(s,0,-.035),"e0":a.lerp(o[0],.58)+_point(s,.025,-.02),"e2":a.lerp(o[2],.52)+_point(s,.035,-.015),"e4":b.lerp(o[4],.55)+_point(s,-.02,.015),"e6":b.lerp(o[6],.48)+_point(s,.01,-.025),"e8":d.lerp(o[8],.55)+_point(s,-.025,-.02),"e10":d.lerp(o[10],.53)+_point(s,.025,-.015)}

static func fragments(s:Dictionary)->Array[PackedVector2Array]:
	var g:Dictionary=_network(s)
	var o:PackedVector2Array=g.o
	return [PackedVector2Array([o[0],o[1],o[2],g.e2,g.a,g.e0]),PackedVector2Array([o[2],o[3],o[4],g.e4,g.b,g.ab,g.a,g.e2]),PackedVector2Array([o[4],o[5],o[6],g.e6,g.b,g.e4]),PackedVector2Array([o[6],o[7],o[8],g.e8,g.d,g.bd,g.b,g.e6]),PackedVector2Array([o[8],o[9],o[10],g.e10,g.d,g.e8]),PackedVector2Array([o[10],o[11],o[0],g.e0,g.a,g.da,g.d,g.e10]),PackedVector2Array([g.a,g.ab,g.b,g.bd,g.d,g.da])]

static func crack_paths(s:Dictionary)->Array[PackedVector2Array]:
	var g:Dictionary=_network(s)
	var o:PackedVector2Array=g.o
	return [PackedVector2Array([g.a,g.ab,g.b]),PackedVector2Array([g.b,g.bd,g.d]),PackedVector2Array([g.d,g.da,g.a]),PackedVector2Array([g.a,g.e0,o[0]]),PackedVector2Array([g.a,g.e2,o[2]]),PackedVector2Array([g.b,g.e4,o[4]]),PackedVector2Array([g.b,g.e6,o[6]]),PackedVector2Array([g.d,g.e8,o[8]]),PackedVector2Array([g.d,g.e10,o[10]])]

static func _center(points:PackedVector2Array)->Vector2:
	var result:=Vector2.ZERO
	for point in points: result+=point
	return result/float(points.size())

static func _setting(p,key:String,fallback:float)->float:
	var value=p.get(key)
	return fallback if value==null else float(value)

static func shake_offset(s:Dictionary,age:float,p)->Vector2:
	var at:float=p.rise_time+p.hold_time
	var duration:float=maxf(.001,_setting(p,"shake_time",.09))
	var t:float=(age-at+duration)/duration
	if t<0.0 or t>1.35: return Vector2.ZERO
	var envelope:float=sin(clampf(t/1.35,0.0,1.0)*PI)
	var amount:float=_setting(p,"shake_amount",1.05)
	return Vector2(sin(t*TAU*2.7),sin(t*TAU*3.3)*.25)*amount*envelope

static func _rest_angle(fragment:PackedVector2Array,index:int)->float:
	# Choose an actual rigid orientation with a broad base, never squash the hull.
	var best_angle:float=0.0
	var best_score:float=INF
	for step in 48:
		var angle:float=-PI+TAU*float(step)/48.0
		var low:float=INF
		var high:float=-INF
		for q in fragment:
			var y:float=q.rotated(angle).y
			low=minf(low,y);high=maxf(high,y)
		var score:float=high-low+absf(angle)*.12
		if score<best_score:
			best_score=score;best_angle=angle
	return best_angle+sin(float(index)*2.7)*.045

static func depth_vector(p)->Vector2:
	# Fixed local-space thickness: it rotates with the piece, never camera-billboards.
	var depth:float=clampf(_setting(p,"depth",2.5),.8,4.0)
	return Vector2(depth,-depth*.45)

static func _support(fragment:PackedVector2Array,center:Vector2,angle:float,depth:Vector2)->Vector2:
	var contact:=Vector2(0,-INF)
	for q in fragment:
		for shift in [Vector2.ZERO,depth]:
			var point:Vector2=(q-center+shift).rotated(angle)
			if point.y>contact.y: contact=point
	return contact

static func fragment_pose(s:Dictionary,fragment:PackedVector2Array,index:int,travel:float,p)->Dictionary:
	var t:float=clampf(travel,0.0,1.0)
	var center:Vector2=_center(fragment)
	var random:float=_noise(s,index)
	var depth:Vector2=depth_vector(p)
	var delays:Array[float]=[.21,.67,.0,.39,.85,.57,.29]
	var delay:float=delays[index%7]*minf(.24,_setting(p,"stagger",.055)/maxf(.001,p.break_time))
	# Independent contact times, rather than a synchronized implosion.
	var lands:Array[float]=[.57,.80,.95,.71,.64,.50,.88]
	var land:float=lands[index%7]
	var u:float=clampf((t-delay)/(land-delay),0.0,1.0)
	var final_angle:float=_rest_angle(fragment,index)
	var angle:float=final_angle*u
	# Three irregular overlapping piles close to the source, not a row of bricks.
	var landing_x:Array[float]=[-19.0,-12.0,18.0,12.0,-15.0,-2.0,3.0]
	var destination_x:float=landing_x[index%7]*(float(s.get("width",27.0))/27.0)+(_noise(s,300+index)-.5)*2.0
	var x:float=lerpf(center.x,center.x+(destination_x-center.x)*p.scatter,u)
	var initial_support:Vector2=_support(fragment,center,0.0,depth)
	var clearance:float=maxf(0.0,-center.y-initial_support.y)
	# Support-aware ballistic fall prevents a rotating corner touching early.
	var height:float=clearance*(1.0-u*u)+(1.0+random*2.5)*4.0*u*(1.0-u)
	var rebound_duration:float=minf(.10,1.0-land)
	var rebound:float=clampf((t-land)/maxf(.001,rebound_duration),0.0,1.0)
	if t>=land:
		height=(.35+random*.75)*4.0*rebound*(1.0-rebound)
		angle=final_angle+sin(rebound*PI)*(.045 if index%2==0 else -.045)
		x+=sin(rebound*PI*.5)*(.6 if index%2==0 else -.6)
	var support:Vector2=_support(fragment,center,angle,depth)
	var shake:Vector2=shake_offset(s,p.rise_time+p.hold_time+t*p.break_time,p)*(1.0-smoothstep(delay,delay+.12,t))
	var base:Vector2=s.get("pos",Vector2.ZERO)
	# Shake is horizontal at contact, so it can never push a piece through the floor.
	var position:Vector2=base+Vector2(x+shake.x,-support.y-height+minf(0.0,shake.y))
	return {"center":center,"position":position,"rotation":angle,"land":land,"delay":delay,"settled":land+rebound_duration,"contact":Vector2(position.x+support.x,base.y),"contact_y":base.y,"ground":base.y,"depth_vector":depth}

static func _transform(points:PackedVector2Array,pose:Dictionary)->PackedVector2Array:
	var result:PackedVector2Array=[]
	for point in points: result.append(pose.position+(point-pose.center).rotated(pose.rotation))
	return result

static func fragment_points(s:Dictionary,fragment:PackedVector2Array,index:int,travel:float,p)->PackedVector2Array:
	return _transform(fragment,fragment_pose(s,fragment,index,travel,p))

static func _above_ground(points:PackedVector2Array,ground:float)->PackedVector2Array:
	var out:PackedVector2Array=[]
	for i in points.size():
		var a:Vector2=points[(i+points.size()-1)%points.size()]
		var b:Vector2=points[i]
		if (a.y<=ground)!=(b.y<=ground): out.append(a.lerp(b,(ground-a.y)/(b.y-a.y)))
		if b.y<=ground: out.append(b)
	return out

static func _alpha(color:Color,opacity:float)->Color: return Color(color,color.a*opacity)

static func _polygon(c:Node2D,points:PackedVector2Array,color:Color)->void:
	var rounded:PackedVector2Array=[]
	for point in points:
		var q:Vector2=point.round()
		if rounded.is_empty() or rounded[-1]!=q: rounded.append(q)
	if rounded.size()>1 and rounded[0]==rounded[-1]: rounded.remove_at(rounded.size()-1)
	if rounded.size()<3 or Geometry2D.triangulate_polygon(rounded).is_empty(): return
	c.draw_colored_polygon(rounded,color)

static func _faces(s:Dictionary)->Array[PackedVector2Array]:
	var o:PackedVector2Array=outline(s)
	var ridge:Vector2=_point(s,-.045,-.49)
	# Three continuous facets. Their boundaries are independent of the fracture mesh.
	return [PackedVector2Array([o[0],o[1],o[2],o[3],o[4],o[5],ridge,o[11]]),PackedVector2Array([o[5],o[6],o[7],o[8],o[9],o[10],_point(s,.22,-.08),_point(s,.11,-.55)]),PackedVector2Array([o[11],ridge,o[5],_point(s,.11,-.55),_point(s,.22,-.08),o[10]])]

static func _solid_sides(c:Node2D,points:PackedVector2Array,pose:Dictionary,depth:Vector2,p,opacity:float,ground:float)->void:
	var rear:PackedVector2Array=[]
	for q in points: rear.append(q+depth)
	_polygon(c,_above_ground(_transform(rear,pose),ground),_alpha(p.shadow,opacity))
	for j in points.size():
		var a:Vector2=points[j]
		var b:Vector2=points[(j+1)%points.size()]
		# Side planes keep their material normals and thickness throughout the tumble.
		var edge:Vector2=(b-a).normalized()
		var color:Color=p.primary.lerp(p.shadow,.35+.35*absf(edge.x))
		var side:=PackedVector2Array([a,b,b+depth,a+depth])
		_polygon(c,_above_ground(_transform(side,pose),ground),_alpha(color,opacity))

static func _line_growth(c:Node2D,path:PackedVector2Array,offset:Vector2,progress:float,color:Color)->void:
	var budget:float=0.0
	for i in range(1,path.size()): budget+=path[i-1].distance_to(path[i])
	budget*=clampf(progress,0.0,1.0)
	for i in range(1,path.size()):
		var length:float=path[i-1].distance_to(path[i])
		if budget<=0: break
		c.draw_line((path[i-1]+offset).round(),(path[i-1].lerp(path[i],minf(1.0,budget/maxf(length,.001)))+offset).round(),color,1.0,false)
		budget-=length

static func draw_spike(c:Node2D,s:Dictionary,age:float,p)->void:
	var break_at:float=p.rise_time+p.hold_time
	var settled_at:float=break_at+p.break_time
	if age<0.0 or age>=settled_at+p.residue_lifetime: return
	var fade:float=1.0-smoothstep(settled_at+p.residue_lifetime*.7,settled_at+p.residue_lifetime,age)
	var base:Vector2=s.get("pos",Vector2.ZERO)
	var faces:Array[PackedVector2Array]=_faces(s)
	var colors:Array[Color]=[p.primary.lerp(p.highlight,.55),p.primary.lerp(p.shadow,.62),p.primary]
	if age<break_at:
		# A complete rock translates up through the soil; it is never stretched.
		var rise:float=clampf(age/maxf(.001,p.rise_time),0,1)
		var lift:float=float(s.get("height",42.0))*(1.0-rise)
		var offset:Vector2=base+Vector2(0,lift)+shake_offset(s,age,p)
		var pose:Dictionary={"center":Vector2.ZERO,"position":offset,"rotation":0.0}
		_solid_sides(c,outline(s),pose,depth_vector(p),p,1.0,base.y)
		_polygon(c,_above_ground(_transform(outline(s),pose),base.y),p.primary)
		for j in faces.size(): _polygon(c,_above_ground(_transform(faces[j],pose),base.y),colors[j])
		var crack_duration:float=minf(p.hold_time,_setting(p,"crack_time",.13))
		var progress:float=clampf((age-break_at+crack_duration)/maxf(.001,crack_duration),0,1)
		var paths:Array[PackedVector2Array]=crack_paths(s)
		for j in paths.size():
			var delay:float=.03*float(j) if j<3 else .13+.045*float(j-3)
			_line_growth(c,paths[j],offset,(progress-delay)/(1.0-delay),_alpha(p.shadow,.9))
	else:
		var chunks:Array[PackedVector2Array]=fragments(s)
		var travel:float=clampf((age-break_at)/maxf(.001,p.break_time),0,1)
		for i in chunks.size():
			var pose:Dictionary=fragment_pose(s,chunks[i],i,travel,p)
			var points:PackedVector2Array=_transform(chunks[i],pose)
			_solid_sides(c,chunks[i],pose,depth_vector(p),p,fade,base.y)
			_polygon(c,points,_alpha(p.primary,fade))
			# Inherit the same continuous pre-break facets, never alternating chunk colors.
			for j in faces.size():
				for piece in Geometry2D.intersect_polygons(chunks[i],faces[j]): _polygon(c,_transform(piece,pose),_alpha(colors[j],fade))
			for j in points.size(): c.draw_line(points[j].round(),points[(j+1)%points.size()].round(),_alpha(p.shadow,fade*.62),1,false)
