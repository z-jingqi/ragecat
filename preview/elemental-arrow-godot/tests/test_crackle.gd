extends SceneTree
const L=preload("../modules/lightning.gd")
const P=preload("../presets/lightning.tres")
var count:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func signature(events:Array)->String:
	var points=[]
	for event in events: points.append([event.id,event.points,event.forks])
	return var_to_str(points)
func _initialize()->void:
	var a=P.lightning.duplicate(true); var population=0; var multi=0; var branches=0; var changed=0; var last=""; var valid=true; var short=true; var expired=true
	for frame in 180:
		var t=float(frame)/60; var events=L.arcs_at(t,34,1,a); population+=events.size()
		if events.size()>=2: multi+=1
		for event in events:
			valid=valid and event.age>=0 and event.age<event.life and event.life>=.065 and event.life<=.1101
			branches+=event.forks.size()
			var low=INF; var high=-INF
			for p in event.points:
				low=minf(low,p.x); high=maxf(high,p.x); valid=valid and p.x>=-30 and p.x<=-4 and absf(p.y)<=8.001
			short=short and high-low<15
			for later in L.arcs_at(t+.12,34,1,a):
				if later.id==event.id: expired=false
		var sig=signature(events)
		if frame>0 and sig!=last: changed+=1
		last=sig
	check(float(population)/180>=2,"default has multiple independent arcs on average")
	check(multi>100,"multiple arcs present in most samples")
	check(valid,"lifetimes and default local bounds")
	check(short,"each arc stays short rather than spanning the shaft")
	check(expired,"every event disappears within120ms")
	check(branches>50,"short attached forks occur throughout playback")
	check(changed>90,"geometry or event population changes independently of brightness")
	check(signature(L.arcs_at(.63,34,1,a))==signature(L.arcs_at(.63,34,1,a)),"same time and seed deterministic")
	var shared=0; var restruck=0
	for tick in range(1,60):
		var earlier=L.arcs_at(float(tick)/30-.002,34,1,a)
		var later=L.arcs_at(float(tick)/30+.002,34,1,a)
		for old in earlier:
			for fresh in later:
				if old.id==fresh.id:
					shared+=1
					if old.points!=fresh.points: restruck+=1
	check(shared>50 and restruck==shared,"surviving events re-strike geometry across30Hz boundaries")
	var b=a.duplicate(true); b.seed_value+=1
	check(signature(L.arcs_at(.63,34,1,a))!=signature(L.arcs_at(.63,34,1,b)),"seed changes roots and geometry")
	b=a.duplicate(true); b.arc_density=0; check(L.arcs_at(.63,34,1,b).is_empty(),"zero density hides arcs")
	var low_count=0; var high_count=0
	for frame in 120:
		b.arc_density=.5; low_count+=L.arcs_at(float(frame)/60,34,1,b).size()
		b.arc_density=2; high_count+=L.arcs_at(float(frame)/60,34,1,b).size()
	check(high_count>low_count*2,"density increases independent population")
	b=a.duplicate(true); b.trail_length=2
	check(signature(L.arcs_at(.63,34,1,a))==signature(L.arcs_at(.63,34,1,b)),"trail parameter cannot create a wake")
	b=a.duplicate(true); b.size=2
	var normal=L.arcs_at(.63,34,1,a); var larger=L.arcs_at(.63,34,1,b)
	check(not normal.is_empty() and is_equal_approx(larger[0].points[-1].y,normal[0].points[-1].y*2),"amplitude scales excursion")
	b.arc_density=INF; check(b.sanitized().arc_density==1,"nonfinite density sanitized")
	print("Crackle state metrics: mean_arcs=",float(population)/180," multi_frames=",multi," forks=",branches," geometry_changes=",changed)
	print("PASS" if failures==0 else "FAIL"," crackle state: ",count," assertions; failures=",failures); quit(0 if failures==0 else 1)
