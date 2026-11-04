extends SceneTree
const L=preload("../modules/lightning.gd")
const P=preload("../presets/lightning.tres")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void:
	var a=P.lightning.duplicate(true); a.lightning_mode=0; var full=true; var winding=true; var population=0
	for frame in 60:
		var events=L.arcs_at(float(frame)/60,34,1,a); population+=events.size()
		for event in events:
			var lo=INF; var hi=-INF; var crossings=0; var last_side=0
			for p in event.points:
				lo=minf(lo,p.x); hi=maxf(hi,p.x)
				var side=signf(p.y)
				if side!=0:
					if last_side!=0 and side!=last_side: crossings+=1
					last_side=side
			full=full and hi-lo>=32 and hi>=-1 and lo<=-33
			winding=winding and crossings>=3
	check(population>=120,"multiple full-length strands")
	check(full,"each independent strand reaches from head to tail")
	check(winding,"each independent strand winds repeatedly around the shaft")
	var events=L.arcs_at(.63,34,1,a)
	check(var_to_str(events)==var_to_str(L.arcs_at(.63,34,1,a)),"deterministic time and seed")
	check(events[0].points!=events[1].points,"independent strand phases and shapes")
	var b=a.duplicate(true); b.seed_value+=1
	check(events[0].points!=L.arcs_at(.63,34,1,b)[0].points,"seed changes helix geometry")
	var continuous=true; var depth_partition=true; var bounded=true; var winding_depth=true
	for length in [18.0,34.0,64.0]:
		for width in [.6,2.0]:
			for size in [.25,1.0,3.0]:
				b=a.duplicate(true); b.size=size
				for event in L.arcs_at(.63,length,width,b):
					check(event.points[0].x>=-1 and event.points[-1].x<=-length+1 and event.points[0].x-event.points[-1].x>=length-2,"each strand covers complete arrow at length "+str(length))
					var cross=0; var prev=0
					for z in event.depths:
						var side=signf(z)
						if side!=0:
							if prev!=0 and prev!=side: cross+=1
							prev=side
					winding_depth=winding_depth and cross>=3
					var last=event.points[0]; var front=0; var back=0
					for segment in event.segments:
						continuous=continuous and segment.from.is_equal_approx(last)
						last=segment.to
						if segment.front: front+=1
						else: back+=1
						for point in [segment.from,segment.to]:
							bounded=bounded and point.x>=-length+1-.001 and point.x<=-1+.001 and absf(point.y)<=7*size+width
					continuous=continuous and last.is_equal_approx(event.points[-1])
					depth_partition=depth_partition and front>0 and back>0
	check(continuous,"depth-split segments join without gaps and span complete strand")
	check(depth_partition and winding_depth,"each strand winds in front and behind shaft")
	check(bounded,"resource limits remain arrow-local without longitudinal tail")
	b=a.duplicate(true); b.arc_density=0
	check(L.arcs_at(.63,34,1,b).is_empty(),"density zero removes all strands")
	b.arc_density=1; b.intensity=0
	check(L.arcs_at(.63,34,1,b).is_empty(),"intensity zero removes all strands")
	b=a.duplicate(true); b.arc_density=.5
	var low=L.arcs_at(.63,34,1,b); b.arc_density=2
	check(low.size()==1 and L.arcs_at(.63,34,1,b).size()==4,"density controls strand count")
	b=a.duplicate(true); b.size=2
	var larger=L.arcs_at(.63,34,1,b); var r1=0.0; var r2=0.0
	for p in events[0].points: r1=maxf(r1,absf(p.y))
	for p in larger[0].points: r2=maxf(r2,absf(p.y))
	check(r2>r1*1.8 and events[0].points[0]==larger[0].points[0] and events[0].points[-1]==larger[0].points[-1],"amplitude grows radius with fixed endpoints")
	b=a.duplicate(true); b.trail_length=2
	check(var_to_str(events)==var_to_str(L.arcs_at(.63,34,1,b)),"trail length never adds wake")
	var changing=true
	for tick in range(1,30):
		var old=L.arcs_at(float(tick)/30-.001,34,1,a); var fresh=L.arcs_at(float(tick)/30+.001,34,1,a)
		for i in old.size(): changing=changing and old[i].points!=fresh[i].points
	check(changing,"every strand changes across 30Hz boundaries")
	var sharp_jumps=true
	for tick in range(1,30):
		# Two microseconds of smooth rotation cannot explain a quarter-pixel jump.
		var old=L.arcs_at(float(tick)/30-.000001,34,1,a); var fresh=L.arcs_at(float(tick)/30+.000001,34,1,a)
		for i in old.size():
			var jump=0.0
			for j in old[i].points.size(): jump=maxf(jump,old[i].points[j].distance_to(fresh[i].points[j]))
			sharp_jumps=sharp_jumps and jump>.25
	check(sharp_jumps,"30Hz discontinuous electrical re-strikes exceed continuous helix rotation")
	b=a.duplicate(true); b.lightning_mode=1
	check(var_to_str(L.arcs_at(.63,34,1,b))==var_to_str(L.Crackle.arcs_at(.63,34,1,b)),"previous micro-arc mode preserved")
	b.lightning_mode=99; check(b.sanitized().lightning_mode==2,"mode clamped safely")
	print("PASS" if failures==0 else "FAIL"," helical geometry: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
