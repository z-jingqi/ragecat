extends SceneTree
const L=preload("../modules/lightning_reference.gd")
const P=preload("../presets/lightning.tres")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func y_at(points:PackedVector2Array,x:float)->float:
	for i in range(points.size()-1):
		if x>=points[i].x and x<=points[i+1].x: return lerpf(points[i].y,points[i+1].y,inverse_lerp(points[i].x,points[i+1].x,x))
	return 0.0
func _initialize()->void:
	var a=P.lightning.duplicate(true); var blank=0; var local=0; var peak=0; var counts={}
	for frame in 720:
		var events=L.arcs_at(float(frame)/60,96,1,a); counts[events.size()]=true
		if events.is_empty(): blank+=1; continue
		var full=0
		for event in events:
			var lo=INF; var hi=-INF
			for p in event.points: lo=minf(lo,p.x); hi=maxf(hi,p.x)
			if hi-lo>96*.55: full+=1
		if full>=2: peak+=1
		else: local+=1
	check(blank>=40,"real empty intervals exist across continuous cycles")
	check(local>=300,"most frames have local transient arcs, not a permanent full pair")
	check(peak>0 and peak<90,"design-like full pair is only a short occasional peak")
	check(counts.size()>=3,"event count changes over time")
	print("Lifecycle frames blank=",blank," local=",local," peak=",peak," counts=",counts.keys())
	check(a.arc_wandering,"transient lifecycle is the preset default")
	var valid=true; var roots=true; var lifetimes=true; var types={}; var mixed=false
	for seed_i in [17,29,99]:
		for length in [18.0,64.0,96.0,128.0,256.0]:
			var b=a.duplicate(true); b.seed_value=seed_i
			for frame in 180:
				var t=float(frame)/60; var events=L.arcs_at(t,length,1,b)
				mixed=mixed or events.size()>2
				for event in events:
					lifetimes=lifetimes and t>=event.birth and t<event.birth+event.life and event.opacity>=0 and event.opacity<=1
					if event.kind=="local": types[event.topology]=true
					for p in event.points: valid=valid and p.is_finite() and p.x>=-length*.82-.001 and p.x<=-length*.13+.001 and absf(p.y)<=length*.12+1
					for fork in event.forks:
						var live=false
						for segment in event.segments:
							if segment.energy>0 and (segment.from.is_equal_approx(fork.points[0]) or segment.to.is_equal_approx(fork.points[0])): live=true
						roots=roots and live
	check(valid,"all transient paths remain finite and attached across lengths and seeds")
	check(roots,"fork roots attach only to a visible segment in their live event")
	check(lifetimes,"every event has a real birth and expiry and bounded opacity")
	check(types.size()==3 and mixed,"multiple local topologies and independent overlaps occur")
	var b=a.duplicate(true); b.arc_jitter=0; b.arc_forks=0; b.glow=0
	var observed=0; var propagated=0; var deformed=0; var reshaped=0
	for frame in 240:
		var t=float(frame)/60
		for event in L.arcs_at(t,96,1,b):
			if event.kind!="local" or t-event.birth>1.0/60: continue
			var first=L.Wandering.local_arc(event.birth+event.life*.24,event,96,1,b)
			var second=L.Wandering.local_arc(event.birth+event.life*.72,event,96,1,b)
			observed+=1
			if absf(first.points[0].x-second.points[0].x)>.5 and first.points[0]!=second.points[0]: propagated+=1
			var lo=maxf(first.points[0].x,second.points[0].x); var hi=minf(first.points[-1].x,second.points[-1].x); var d=0.0
			for j in range(1,10):
				var x=lerpf(lo,hi,float(j)/10); d+=absf(y_at(first.points,x)-y_at(second.points,x))
			if hi>lo and d/9>.35: deformed+=1
			var intrinsic=0.0
			for i in first.points.size(): intrinsic+=absf(first.points[i].y-second.points[i].y)
			if intrinsic/first.points.size()>.15: reshaped+=1
	check(observed>15 and propagated>observed*.7,"same event moves its interval during life")
	check(deformed>observed*.7,"same event genuinely changes its local path without fine jitter or light")
	check(reshaped>observed*.7,"matching local-parameter bends change beyond interval translation")
	print("Tracked events=",observed," propagated=",propagated," fixed-x changed=",deformed," intrinsic reshape=",reshaped)
	b=a.duplicate(true); b.arc_activity=0; check(L.arcs_at(.45,96,1,b).is_empty(),"activity zero removes discharge events")
	b=a.duplicate(true); b.intensity=0; check(L.arcs_at(.45,96,1,b).is_empty(),"zero intensity removes all transient geometry")
	b=a.duplicate(true); b.arc_density=0; check(L.arcs_at(.45,96,1,b).is_empty(),"zero visibility removes all transient geometry")
	check(var_to_str(L.arcs_at(.45,96,1,a))==var_to_str(L.arcs_at(.45,96,1,a)),"same time and seed are deterministic")
	b=a.duplicate(true); b.arc_lifetime=NAN; b.arc_flow_rate=INF; b.arc_activity=-1; b=b.sanitized()
	check(b.arc_lifetime==.14 and b.arc_flow_rate==1 and b.arc_activity==0,"new lifecycle controls sanitize")
	b=a.duplicate(true); b.arc_wandering=false
	check(L.arcs_at(.45,96,1,b).size()==2,"prior sustained pair remains available explicitly")
	var expired=true; var parameter_bounds=true
	for lifetime in [.06,.30]:
		for rate in [.5,2.0]:
			for activity in [.2,2.0]:
				b=a.duplicate(true); b.arc_lifetime=lifetime; b.arc_flow_rate=rate; b.arc_activity=activity
				for frame in 180:
					var t=float(frame)/30
					for event in L.arcs_at(t,64,1,b):
						for point in event.points: parameter_bounds=parameter_bounds and point.is_finite() and point.x>=-64*.82-.001 and point.x<=-64*.13+.001 and absf(point.y)<10
						for later in L.arcs_at(event.birth+event.life+.00001,64,1,b): expired=expired and later.id!=event.id
	check(expired,"expired event IDs and their forks never persist into later states")
	check(parameter_bounds,"lifetime, flow and activity extremes keep local paths bounded")
	print("PASS" if failures==0 else "FAIL"," wandering lightning: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
