extends RefCounted
# Original deterministic discharge events. No permanent full-shaft carrier is
# used by local arcs: each owns moving endpoints, bends, topology and lifetime.
const D=preload("drawing.gd")
static func schedule_at(time:float,a:Resource)->Array:
	var events=[]
	if a.arc_activity<=0: return events
	var clock=time*a.arc_flow_rate; var cycle=int(floor(clock/1.2)); var seed_i=a.seed_value
	for c in range(maxi(0,cycle-1),cycle+1):
		for slot in 10:
			var id=c*100+slot*3
			if D.random01(id,seed_i+211)>minf(1,a.arc_activity*.94): continue
			var copies=2 if D.random01(id,seed_i+223)<.32*a.arc_activity else 1
			for copy in copies:
				var key=id+copy
				var birth=(c*1.2+.065+float(slot)/9.0*(.56+.30*D.random01(c,seed_i+225))+(D.random01(key,seed_i+227)-.5)*.070+copy*.021)/a.arc_flow_rate
				var life=a.arc_lifetime*(.65+.70*D.random01(key,seed_i+229))/a.arc_flow_rate
				if time<birth or time>=birth+life: continue
				var direction=1.0 if D.random01(c,seed_i+233)>.35 else -1.0
				var center=.08+.84*float(slot)/9
				if direction<0: center=1-center
				if copy==1: center=1-center; direction=-direction
				center=clampf(center+(D.random01(key,seed_i+235)-.5)*.12,.03,.97)
				if D.random01(key,seed_i+237)<.20: direction=-direction
				events.append({"id":key,"kind":"local","birth":birth,"life":life,"center":center,"direction":direction,"topology":int(D.random01(key,seed_i+239)*3),"side":-1.0 if (slot+copy)%2==0 else 1.0})
		# The design image describes a brief dense discharge, not the idle state.
		if D.random01(c,seed_i+251)<minf(.90,.65*a.arc_activity):
			var birth=(c*1.2+.57+.18*D.random01(c,seed_i+257))/a.arc_flow_rate
			var life=minf(.095,a.arc_lifetime*.5)/a.arc_flow_rate
			if time>=birth and time<birth+life: events.append({"id":c*100+90,"kind":"peak","birth":birth,"life":life})
	return events
static func life_opacity(time:float,event:Dictionary)->float:
	var n=(time-event.birth)/event.life
	return smoothstep(0,.13,n)*(1.0-smoothstep(.64,1,n))
static func local_arc(time:float,event:Dictionary,length:float,width:float,a:Resource)->Dictionary:
	var n=(time-event.birth)/event.life; var id=event.id; var seed_i=a.seed_value
	var key=id*53+int(floor((time-event.birth)*a.arc_path_rate))*701
	var span=(.18+.18*D.random01(id,seed_i+263))*(.35+.65*sin(n*PI))
	var center=event.center+event.direction*(n-.5)*.16
	var lo=clampf(center-span*.5,0,1); var hi=clampf(center+span*.5,0,1)
	var bends=4+int(D.random01(id,seed_i+269)*4)
	var radius=(length*.045*a.size+width*.08)*(.8+.4*D.random01(id,seed_i+271))
	var points=PackedVector2Array(); var depths=PackedFloat32Array()
	for i in bends+1:
		var f=float(i)/bends; var u=lerpf(lo,hi,f)
		if i>0 and i<bends: u+=(hi-lo)/bends*.32*(D.random01(i+key,seed_i+277)*2-1)*minf(1,a.arc_variation)
		var carrier=sin(f*PI) if event.topology==0 else sin(f*TAU)*.8 if event.topology==1 else sin(f*PI)*(.3+.7*sin(f*PI*3))
		var reshape=(D.random01(i+key,seed_i+281)*2-1)*.55*a.arc_variation*sin(f*PI)
		var detail=(D.random01(i+int(time*a.arc_rate)*151,seed_i+283)*2-1)*.4*a.arc_jitter*sin(f*PI)
		var y=(carrier+reshape)*radius*event.side+detail*minf(1.25,length/96.0)*a.size
		points.append(Vector2(lerpf(-length*.82,-length*.13,u),y))
		depths.append(event.side*cos(f*PI))
	var segments=[]
	for i in range(points.size()-1):
		var z0=depths[i]; var z1=depths[i+1]
		var energy=0.0 if i>0 and i<points.size()-2 and D.random01(i+key,seed_i+293)<.05 else 1.0
		var base={"energy":energy,"hot":i>0 and i<points.size()-2,"knot":false,"glow_point":i%2==0}
		if z0*z1<0:
			var at=points[i].lerp(points[i+1],absf(z0)/(absf(z0)+absf(z1)))
			var rear=base.duplicate(); rear.merge({"from":points[i],"to":at,"front":z0>=0}); segments.append(rear)
			var front=base.duplicate(); front.merge({"from":at,"to":points[i+1],"front":z1>=0}); segments.append(front)
		else: base.merge({"from":points[i],"to":points[i+1],"front":z0+z1>=0}); segments.append(base)
	var forks=[]
	if a.arc_forks>0 and n>.18 and n<.84 and D.random01(id,seed_i+307)<minf(.85,a.arc_forks*.42):
		var index=clampi(1+int(D.random01(key,seed_i+311)*(bends-2)),1,bends-1); var root=points[index]
		var live=false
		for segment in segments:
			if segment.energy>0 and (segment.from.is_equal_approx(root) or segment.to.is_equal_approx(root)): live=true
		if live:
			var end=root+Vector2(event.direction*length*.025,event.side*length*.035)*a.size
			end.x=clampf(end.x,-length*.82,-length*.13)
			var mid=root.lerp(end,.5)+Vector2(-event.direction*length*.012*a.size,0); mid.x=clampf(mid.x,-length*.82,-length*.13)
			forks.append({"points":PackedVector2Array([root,mid,end]),"twig":PackedVector2Array(),"front":depths[index]>=0,"root_index":index})
	return {"id":id,"kind":"local","birth":event.birth,"life":event.life,"topology":event.topology,"direction":event.direction,"center":event.center,"side":event.side,"carrier":points,"points":points,"depths":depths,"segments":segments,"forks":forks,"opacity":minf(1,a.arc_density)*life_opacity(time,event)}
