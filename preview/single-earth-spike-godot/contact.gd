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
 if age<.24:
  var spread:float=minf(1.0,age/.055)
  for side in [-1,1]:
   var path:PackedVector2Array=[Vector2(side*w*.35,0),Vector2(side*(w*.55+4),1),Vector2(side*(w*.55+8),-1),Vector2(side*(w*.55+13),1)]
   Stone._line_growth(c,path,base,spread,alpha(p.shadow,(1.0-age/.24)*p.impact_strength))
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
  for i in 2:
   var side:float=-1 if i==0 else 1; var q:float=clampf(age/.18,0,1)
   var lift:float=sin(q*PI)*(2.6 if i==0 else 1.8)*p.impact_strength
   var pos:Vector2=base+Vector2(side*(w*.47+2+q*(3 if i==0 else 1)),-lift)
   var poly:PackedVector2Array=[Vector2(-3,-1),Vector2(1,-3 if i==0 else -2),Vector2(4,0),Vector2(2,2),Vector2(-3,1)]
   var angle:float=side*.16*(1-q)
   for j in poly.size(): poly[j]=pos+poly[j].rotated(angle)
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
