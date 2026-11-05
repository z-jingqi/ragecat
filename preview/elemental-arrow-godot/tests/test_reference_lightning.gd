extends SceneTree
const L=preload("../modules/lightning.gd")
const P=preload("../presets/lightning.tres")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void:
	var a=P.lightning.duplicate(true)
	var forks=0; var asymmetric=false; var gated=false; var feather_clear=true
	for frame in 60:
		var events=L.arcs_at(float(frame)/60,34,1,a)
		for event in events:
			forks+=event.forks.size()
			for p in event.points: feather_clear=feather_clear and p.x>=-28.0
			for segment in event.segments: gated=gated or segment.get("energy",1.0)<.1
		if events.size()==2 and events[0].points.size()==events[1].points.size():
			for i in events[0].points.size(): asymmetric=asymmetric or absf(events[0].points[i].y+events[1].points[i].y)>.5
	check(forks>0,"few attached forklets accompany the main strands")
	check(asymmetric,"double strands have independent irregularity rather than mirror symmetry")
	check(gated,"electric segments intermittently break instead of continuous wire")
	check(feather_clear,"lightning begins past feathers and never becomes a tail")
	check(a.lightning_mode==3,"reference is the current default mode")
	var twig_roots=true; var live_roots=true; var valid=true; var roots=true; var pair=true; var bounded_forks=true; var layers=true
	for length in [18.0,34.0,64.0,96.0,128.0,256.0]:
		for size in [.25,1.0,3.0]:
			var b=a.duplicate(true); b.size=size
			for frame in 60:
				var events=L.arcs_at(float(frame)/60,length,2,b); pair=pair and events.size()==2
				for event in events:
					var front=0; var rear=0
					for segment in event.segments:
						if segment.front: front+=1
						else: rear+=1
						for point in [segment.from,segment.to]: valid=valid and point.is_finite() and point.x>=-length*.82-.001 and point.x<=-length*.13+.001 and absf(point.y)<=length*.085*size+1
					layers=layers and front>0 and rear>0
					bounded_forks=bounded_forks and event.forks.size()<=3
					for fork in event.forks:
						roots=roots and fork.points[0].is_equal_approx(event.points[fork.root_index])
						var attached=false
						for segment in event.segments:
							if segment.energy>0 and (segment.from.is_equal_approx(fork.points[0]) or segment.to.is_equal_approx(fork.points[0])): attached=true
						live_roots=live_roots and attached
						for point in fork.points: valid=valid and point.is_finite() and point.x>=-length*.82-.001 and point.x<=-length*.13+.001 and absf(point.y)<=length*.16*size+1
						bounded_forks=bounded_forks and fork.points[0].distance_to(fork.points[-1])<=length*.08*size
						if not fork.twig.is_empty():
							twig_roots=twig_roots and fork.twig[0].is_equal_approx(fork.points[1]) and fork.twig[0].distance_to(fork.twig[1])<=length*.03*size
							for point in fork.twig: valid=valid and point.x>=-length*.82-.001 and point.x<=-length*.13+.001 and absf(point.y)<=length*.16*size+1
	check(pair,"exactly two main strands across sizes and times")
	check(valid,"main paths and forks stay finite and shaft-local at parameter limits")
	check(roots,"all forklets remain rooted on a main strand")
	check(live_roots,"every fork is attached to a currently visible trunk segment")
	check(twig_roots,"secondary Y tips remain short and rooted on their primary fork")
	check(bounded_forks,"at most six bounded forklets, no particle spray")
	check(layers,"both main strands wrap in front of and behind the body")
	var base=L.arcs_at(.63,34,1,a)
	check(var_to_str(base)==var_to_str(L.arcs_at(.63,34,1,a)),"same pose time and seed are deterministic")
	var b=a.duplicate(true); b.seed_value+=1
	check(base[0].points!=L.arcs_at(.63,34,1,b)[0].points,"seed changes original lightning geometry")
	b=a.duplicate(true); b.arc_density=.2
	var faint=L.arcs_at(.63,34,1,b); b.arc_density=2
	check(faint.size()==2 and L.arcs_at(.63,34,1,b).size()==2 and faint[0].opacity<base[0].opacity,"visibility dims the pair without changing strand count")
	b.arc_density=0; check(L.arcs_at(.63,34,1,b).is_empty(),"zero visibility is empty")
	b.arc_density=1; b.intensity=0; check(L.arcs_at(.63,34,1,b).is_empty(),"zero intensity is empty")
	b=a.duplicate(true); b.arc_forks=0
	var no_forks=true
	for frame in 60:
		for event in L.arcs_at(float(frame)/60,34,1,b): no_forks=no_forks and event.forks.is_empty()
	for time in [1707.466667,1707.4733333333,5000.0,17000.0]:
		for event in L.arcs_at(time,34,1,b): no_forks=no_forks and event.forks.is_empty()
	check(no_forks,"fork density zero removes forklets including zero-RNG long-run cases")
	b=a.duplicate(true); b.trail_length=2
	check(var_to_str(base)==var_to_str(L.arcs_at(.63,34,1,b)),"trail parameter cannot add a wake")
	b=a.duplicate(true); b.size=2
	var large=L.arcs_at(.63,34,1,b); var small_radius=0.0; var big_radius=0.0
	for point in base[0].points: small_radius=maxf(small_radius,absf(point.y))
	for point in large[0].points: big_radius=maxf(big_radius,absf(point.y))
	check(big_radius>small_radius*1.8,"amplitude visibly controls attached radius")
	b=a.duplicate(true); b.arc_jitter=0
	check(base[0].points!=L.arcs_at(.63,34,1,b)[0].points,"jaggedness is configurable")
	var jumps=true
	for rate in [5.0,30.0,60.0]:
		b=a.duplicate(true); b.arc_rate=rate
		for tick in range(1,12):
			var old=L.arcs_at(float(tick)/rate-.000001,34,1,b); var fresh=L.arcs_at(float(tick)/rate+.000001,34,1,b)
			var jump=0.0
			for i in old[0].points.size(): jump=maxf(jump,old[0].points[i].distance_to(fresh[0].points[i]))
			jumps=jumps and jump>.25
	check(jumps,"5/30/60 Hz re-strike settings change geometry discontinuously")
	b=a.duplicate(true); b.arc_rate=NAN; b.arc_forks=INF; b.arc_jitter=-4; b.lightning_mode=99; b=b.sanitized()
	check(b.arc_rate==30 and b.arc_forks==1 and b.arc_jitter==0 and b.lightning_mode==3,"new parameters sanitize nonfinite and out-of-range values")
	b=a.duplicate(true); b.lightning_mode=2
	check(var_to_str(L.arcs_at(.63,34,1,b))==var_to_str(L.Double.arcs_at(.63,34,1,b)),"strict double mode remains unchanged")
	print("PASS" if failures==0 else "FAIL"," reference lightning: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
