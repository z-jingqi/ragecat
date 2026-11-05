extends SceneTree
const L=preload("../modules/lightning.gd")
const P=preload("../presets/lightning.tres")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void:
	var a=P.lightning.duplicate(true); a.lightning_mode=2; var paired=true; var opposite=true; var pitch=true
	for frame in 120:
		var events=L.arcs_at(float(frame)/60,34,1,a)
		paired=paired and events.size()==2
		if events.size()!=2: continue
		var first=events[0]; var second=events[1]
		pitch=pitch and first.points.size()==second.points.size()
		if first.points.size()!=second.points.size(): opposite=false; continue
		for i in first.points.size():
			opposite=opposite and is_equal_approx(first.points[i].x,second.points[i].x) and absf(first.points[i].y+second.points[i].y)<.0001 and absf(first.depths[i]+second.depths[i])<.0001
	check(paired,"exactly two strands throughout playback")
	check(pitch,"paired strands use equal pitch and sample counts")
	check(opposite,"paired geometry and depth remain exactly half a turn apart")
	check(a.lightning_mode==2,"explicit double mode remains index 2")
	var valid=true; var full=true; var continuous=true; var layered=true
	for length in [18.0,34.0,64.0]:
		for width in [.6,2.0]:
			for size in [.25,1.0,3.0]:
				var b=a.duplicate(true); b.size=size
				for event in L.arcs_at(.63,length,width,b):
					full=full and event.points[0].x>=-1 and event.points[-1].x<=-length+1
					var cursor=event.points[0]; var front=0; var back=0; var switches=0; var side=signf(event.depths[0])
					for z in event.depths:
						if signf(z)!=side: switches+=1; side=signf(z)
					for segment in event.segments:
						continuous=continuous and cursor.is_equal_approx(segment.from); cursor=segment.to
						if segment.front: front+=1
						else: back+=1
						for point in [segment.from,segment.to]: valid=valid and point.x>=-length+.999 and point.x<=-.999 and absf(point.y)<=7*size+width
					continuous=continuous and cursor.is_equal_approx(event.points[-1])
					layered=layered and switches>=3 and front>0 and back>0
	check(full,"both strands reach both arrow ends across resource limits")
	check(valid,"bounded radius and no longitudinal tail across resource limits")
	check(continuous,"depth segment splits join continuously")
	check(layered,"both strands repeatedly cross front and rear")
	var base=L.arcs_at(.63,34,1,a)
	check(var_to_str(base)==var_to_str(L.arcs_at(.63,34,1,a)),"deterministic same time and seed")
	var b=a.duplicate(true); b.seed_value+=1
	check(base[0].points!=L.arcs_at(.63,34,1,b)[0].points,"seed changes electric shape")
	b=a.duplicate(true); b.arc_density=.1
	var faint=L.arcs_at(.63,34,1,b); b.arc_density=2
	check(faint.size()==2 and L.arcs_at(.63,34,1,b).size()==2,"visibility never changes double strand count")
	check(faint[0].opacity<base[0].opacity and faint[1].opacity<base[1].opacity,"visibility dims both strands")
	b.arc_density=0; check(L.arcs_at(.63,34,1,b).is_empty(),"zero visibility removes pair")
	b.arc_density=1; b.intensity=0; check(L.arcs_at(.63,34,1,b).is_empty(),"zero intensity removes pair")
	b=a.duplicate(true); b.size=2
	var larger=L.arcs_at(.63,34,1,b); var radius1=0.0; var radius2=0.0
	for p in base[0].points: radius1=maxf(radius1,absf(p.y))
	for p in larger[0].points: radius2=maxf(radius2,absf(p.y))
	check(radius2>radius1*1.8,"amplitude increases paired radius")
	b=a.duplicate(true); b.trail_length=2
	check(var_to_str(base)==var_to_str(L.arcs_at(.63,34,1,b)),"trail parameter cannot add wake")
	var jumps=true
	for tick in range(1,30):
		var old=L.arcs_at(float(tick)/30-.000001,34,1,a); var fresh=L.arcs_at(float(tick)/30+.000001,34,1,a)
		for i in 2:
			var jump=0.0
			for j in old[i].points.size(): jump=maxf(jump,old[i].points[j].distance_to(fresh[i].points[j]))
			jumps=jumps and jump>.25
	check(jumps,"30Hz re-strikes independent of smooth carrier rotation")
	b=a.duplicate(true); b.lightning_mode=0
	check(var_to_str(L.arcs_at(.63,34,1,b))==var_to_str(L.Spiral.arcs_at(.63,34,1,b)),"original independent spiral restored exactly")
	b.lightning_mode=1
	check(var_to_str(L.arcs_at(.63,34,1,b))==var_to_str(L.Crackle.arcs_at(.63,34,1,b)),"micro-arcs restored exactly")
	print("PASS" if failures==0 else "FAIL"," double helix: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
