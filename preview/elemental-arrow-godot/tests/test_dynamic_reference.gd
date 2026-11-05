extends SceneTree
# Component regression for the optional sustained pair / short peak geometry.
# Default transient lifecycle is covered by test/render_wandering_lightning.
const L=preload("../modules/lightning_reference.gd")
const P=preload("../presets/lightning.tres")
var count=0
var failures=0
func check(ok:bool,label:String)->void:
	count+=1
	if not ok: failures+=1; push_error(label)
func y_at(points:PackedVector2Array,x:float)->float:
	for i in range(points.size()-1):
		if x>=minf(points[i].x,points[i+1].x) and x<=maxf(points[i].x,points[i+1].x):
			return lerpf(points[i].y,points[i+1].y,inverse_lerp(points[i].x,points[i+1].x,x))
	return 0.0
func _initialize()->void:
	var a=P.lightning.duplicate(true); a.arc_wandering=false; a.arc_jitter=0; a.arc_forks=0
	for length in [64.0,96.0,256.0]:
		var big_changes=0; var sum_mean=0.0; var max_change=0.0
		for strike in range(1,25):
			var before=L.arcs_at((strike-.1)/12.0,length,1,a)
			var after=L.arcs_at((strike+.1)/12.0,length,1,a)
			var total=0.0; var points=0; var largest=0.0
			for strand in 2:
				for i in before[strand].points.size():
					var d=before[strand].points[i].distance_to(after[strand].points[i])
					total+=d; points+=1; largest=maxf(largest,d)
			var mean=total/points; sum_mean+=mean; max_change=maxf(max_change,largest)
			if mean>=length*.010 and largest>=length*.025: big_changes+=1
		check(big_changes>=18,"major carrier changes at game size without fine jitter, length "+str(length))
		print("Carrier metric length=",length," sizeable strikes=",big_changes,"/24 mean=",sum_mean/24," max=",max_change)
	# Fixed x samples reject vertex reparameterization on an unchanged curve.
	for length in [64.0,96.0,128.0,256.0]:
		var substantial=0; var mean_total=0.0
		for strike in range(1,25):
			var old=L.arcs_at((strike-.1)/12.0,length,1,a); var fresh=L.arcs_at((strike+.1)/12.0,length,1,a)
			var motion=0.0
			for strand in 2:
				for j in range(1,40):
					var x=lerpf(-length*.82,-length*.13,float(j)/40)
					motion+=absf(y_at(old[strand].points,x)-y_at(fresh[strand].points,x))
			motion/=78; mean_total+=motion
			if motion>=length*.006: substantial+=1
		check(substantial>=18,"fixed-x path displacement without micro jitter, length "+str(length))
		print("Fixed-x length=",length," changed=",substantial,"/24 mean=",mean_total/24)
	var topology=true; var bounds=true; var depth=true; var endpoints=true
	for variation in [0.0,1.0,2.0]:
		var b=a.duplicate(true); b.arc_variation=variation
		for strike in 100:
			var c=L.carrier_at(strike,96,1,b)
			for strand in 2:
				endpoints=endpoints and c.paths[strand][0].is_equal_approx(Vector2(-96*.82,0)) and c.paths[strand][-1].is_equal_approx(Vector2(-96*.13,0))
				for i in 13:
					bounds=bounds and c.paths[strand][i].is_finite() and absf(c.paths[strand][i].y)<=7.0
					if i>0: bounds=bounds and c.paths[strand][i].x>c.paths[strand][i-1].x
			for i in [4,8]:
				topology=topology and c.paths[0][i].is_equal_approx(c.paths[1][i])
				depth=depth and c.depths[0][i]==0 and c.depths[1][i]==0
			for lobe in 3:
				for k in range(1,4):
					var i=lobe*4+k; var sign_expected=-1 if lobe%2==0 else 1
					topology=topology and (c.paths[0][i].y-c.paths[1][i].y)*sign_expected>0
					depth=depth and c.depths[0][i]*sign_expected>0 and c.depths[1][i]*sign_expected<0
	check(topology,"shared ordered crossings retain three open lobes through variation limits")
	check(bounds,"moving carrier remains finite ordered and shaft-local")
	check(endpoints,"both endpoints stay attached to identical arrow-local positions")
	check(depth,"front and rear layer switches follow the moving crossings")
	var b=a.duplicate(true); b.arc_variation=0
	check(L.carrier_at(0,96,1,b)==L.carrier_at(99,96,1,b),"variation zero freezes major contour")
	b=a.duplicate(true); b.arc_path_rate=INF; b.arc_variation=NAN; b=b.sanitized()
	check(b.arc_path_rate==12 and b.arc_variation==1,"new controls sanitize nonfinite values")
	for rate in [3.0,12.0,20.0]:
		b=a.duplicate(true); b.arc_path_rate=rate
		var same=L.arcs_at(.2/rate,96,1,b)[0].carrier==L.arcs_at(.8/rate,96,1,b)[0].carrier
		var changed=L.arcs_at(.8/rate,96,1,b)[0].carrier!=L.arcs_at(1.2/rate,96,1,b)[0].carrier
		check(same and changed,"configured macro rate holds then replaces whole carrier "+str(rate))
	print("PASS" if failures==0 else "FAIL"," dynamic reference: ",count," assertions; failures=",failures)
	quit(0 if failures==0 else 1)
