extends RefCounted
## Small local ground reaction. No camera shake, glow or gameplay.
const Stone=preload("stone.gd")
static func alpha(color:Color,k:float)->Color: return Color(color,color.a*clampf(k,0,1))
static func fade(age:float,p)->float:
 var settled:float=p.rise_time+p.hold_time+p.break_time
 return 1.0-smoothstep(settled+p.residue_lifetime*.7,settled+p.residue_lifetime,age)
static func visible(age:float,p)->bool: return age>=0 and age<p.site_lifetime()
static func draw_before(c:Node2D,s:Dictionary,age:float,p)->void:
 if not visible(age,p) or p.impact_strength<=0: return
 var base:Vector2=s.get("pos",Vector2.ZERO); var w:float=s.get("width",27.0)
 var k:float=minf(1.0,age/maxf(.001,p.rise_time)); var a:float=fade(age,p)
 var shadow:PackedVector2Array=[Vector2(-w*.60,0),Vector2(-w*.35,-2),Vector2(w*.25,-1),Vector2(w*.61,1),Vector2(w*.40,3),Vector2(-w*.29,3)]
 for j in shadow.size(): shadow[j]+=base
 Stone._polygon(c,shadow,alpha(p.shadow,.52*k*a))
 # Ground fractures remain under the rubble rather than vanishing as a flash.
 var progress:float=clampf(age/maxf(.001,p.rise_time),0.0,1.0)
 for path in ground_paths(s):
  Stone._line_growth(c,path,base,progress,alpha(p.shadow,a*.70*p.impact_strength))
static func ground_paths(s:Dictionary)->Array[PackedVector2Array]:
 var result:Array[PackedVector2Array]=[]
 var w:float=s.get("width",27.0)
 for i in 5:
  var angle:float=float(i)*TAU/5.0+.25+(Stone._noise(s,620+i)-.5)*.3
  var direction:Vector2=Vector2(cos(angle),sin(angle)*.30)
  var tangent:Vector2=Vector2(-direction.y,direction.x)*.7
  var start:Vector2=direction*w*.32
  var length:float=8.0+Stone._noise(s,640+i)*9.0
  result.append(PackedVector2Array([start,start+direction*length*.45+tangent*1.7,start+direction*length*.75-tangent,start+direction*length]))
 return result
static func clod_polygon(index:int)->PackedVector2Array:
 # Unequal cut faces, never a rectangular particle tile.
 if index%2==0: return PackedVector2Array([Vector2(-3,0),Vector2(-2,-2),Vector2(1,-3),Vector2(4,-1),Vector2(2,1),Vector2(-1,1)])
 return PackedVector2Array([Vector2(-2,0),Vector2(-3,-2),Vector2(0,-4),Vector2(2,-2),Vector2(3,0),Vector2(0,1)])
static func clod_pose(s:Dictionary,index:int,age:float,p)->Dictionary:
 var side:float=-1.0 if index%2==0 else 1.0
 var n:float=Stone._noise(s,700+index)
 var duration:float=.18+n*.07
 var q:float=clampf(age/duration,0.0,1.0)
 var w:float=s.get("width",27.0)
 var x:float=side*(w*(.39+.10*float(index/2))+2+q*(3+n*5)*p.impact_strength)
 var lift:float=4*q*(1-q)*(3+n*4)*p.impact_strength
 return {"position":Vector2(x,-lift),"rotation":side*(.3+n*.4)*q}
static func chips(c:Node2D,s:Dictionary,p,elapsed:float,origin:Vector2,stage:int,strength:float=1.0,variant:int=0)->void:
 if elapsed<0 or elapsed>.23: return
 var life:float=.23; var count:int=int(round((6 if stage==0 else 4 if stage==1 else 2)*p.grit_density*strength))
 for i in count:
  var n:float=Stone._noise(s,400+stage*83+i*9+variant)
  var side:float=-1 if (i+variant)%2==0 else 1
  var vx:float=side*(24+n*44)*(1.4 if stage==1 else 1.0)
  var vy:float=-(26+n*40)*(1.1 if stage==0 else .65 if stage==2 else 1.0)
  var offset:Vector2=Vector2(side*(2+n*3),0)
  if stage==0: offset.x+=side*float(s.get("width",27.0))*.42
  var q:Vector2=origin+offset+Vector2(vx*elapsed,vy*elapsed+250*elapsed*elapsed)
  if q.y>origin.y+1: continue
  var col:Color=p.highlight if i%3!=1 else p.shadow
  var size:Vector2=Vector2(2,1) if i%3==0 else Vector2.ONE
  c.draw_rect(Rect2(q.round(),size),alpha(col,1-smoothstep(.15,life,elapsed)))
static func draw_after(c:Node2D,s:Dictionary,age:float,p)->void:
 if not visible(age,p): return
 var base:Vector2=s.get("pos",Vector2.ZERO); var w:float=s.get("width",27.0)
 var a:float=fade(age,p); var break_at:float=p.rise_time+p.hold_time
 if p.impact_strength>0:
  for i in 4:
   var pose:Dictionary=clod_pose(s,i,age,p)
   var pos:Vector2=base+pose.position+Vector2(0,1 if i>=2 else 0)
   var poly:PackedVector2Array=clod_polygon(i)
   for j in poly.size(): poly[j]=pos+poly[j].rotated(pose.rotation)
   Stone._polygon(c,poly,alpha(p.primary,a))
   c.draw_line(poly[0].round(),poly[1].round(),alpha(p.highlight,a*.85),1,false)
   c.draw_line(poly[3].round(),poly[4].round(),alpha(p.shadow,a*.8),1,false)
 chips(c,s,p,age,base,0,p.impact_strength)
 chips(c,s,p,age-break_at,base+Vector2(0,-float(s.get("height",42.0))*.30),1)
 if age>=break_at:
  var pieces:Array=Stone.fragments(s)
  for i in pieces.size():
   var pose:Dictionary=Stone.fragment_pose(s,pieces[i],i,1.0,p)
   var hit_time:float=break_at+float(pose.land)*p.break_time
   var hit_pose:Dictionary=Stone.fragment_pose(s,pieces[i],i,float(pose.land),p)
   var contact:Vector2=hit_pose.get("contact",Vector2(hit_pose.position.x,base.y))
   chips(c,s,p,age-hit_time,contact,2,1.0,i*7)
