extends SceneTree
const Geometry=preload("../components/geometry.gd")
const Profile=preload("../components/spike_profile.gd")
var checks:int=0
var failures:int=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: failures+=1; push_error(label)
func _initialize()->void: call_deferred("run")
func check_footprint(p:Resource)->void:
	var sites:Array[Dictionary]=Geometry.sample(p,17)
	var contours:Array[PackedVector2Array]=Geometry.outlines(p)
	var major:int=0
	for site in sites:
		var contained:bool=false
		for contour in contours:
			if Geometry2D.is_point_in_polygon(site.pos,contour): contained=true
		check(contained,"sample inside displayed footprint")
		check(is_equal_approx(site.direction.length(),1),"projected direction normalized")
		check(site.strength==1.0 or (site.strength>=.35 and site.strength<=.6),"major/minor strength contract")
		if site.strength==1.0: major+=1
		check(site.spawn>=p.onset_delay+site.layer*p.layer_stride() and site.spawn<=p.onset_delay+site.layer*p.layer_stride()+p.stagger_window(),"band onset and jitter")
	check(major>0 and major<sites.size(),"both major and minor sites")
	check(sites==Geometry.sample(p,17),"deterministic replay and ordering")
	check(sites!=Geometry.sample(p,18),"seed changes local details")
	for contour in contours: check(contour[0].is_equal_approx(contour[-1]),"contour closed")
func run()->void:
	var p:Resource=Profile.new()
	for shape in 3:
		p.shape=shape
		for layers in [1,3,6]:
			p.layers=layers
			for irregularity in [0.0,1.0]:
				p.irregularity=irregularity; check_footprint(p)
	p=Profile.new(); p.shape=1; p.sector_angle=100; p.direction_degrees=179
	check_footprint(p)
	for site in Geometry.sample(p,17):
		var flat:Vector2=Vector2(site.pos.x,site.pos.y/p.ground_squash)
		check(absf(wrapf(flat.angle()-deg_to_rad(179),-PI,PI))<=deg_to_rad(50),"sector wraps across 180 degrees")
	p.sector_angle=15; check_footprint(p)
	p.sector_angle=360
	var sector:Array[Dictionary]=Geometry.sample(p,17)
	p.shape=0
	check(Geometry.sample(p,17)==sector,"360 degree sector exactly equals circle")
	p=Profile.new(); p.shape=2
	check(Geometry.outlines(p).size()==3,"three rectangle contours")
	p.lane_directions=PackedFloat32Array([-130,-27,71]); p.lane_count=3
	check_footprint(p)
	for site in Geometry.sample(p,17):
		var expected:Vector2=Geometry.project(Vector2.from_angle(deg_to_rad(p.lane_directions[site.lane])),p).normalized()
		check(site.direction.is_equal_approx(expected),"custom absolute lane angle")
	for shape in [1,2]:
		p=Profile.new(); p.shape=shape; p.direction_degrees=23
		var before:Array[Dictionary]=Geometry.sample(p,61)
		p.direction_degrees+=180
		var after:Array[Dictionary]=Geometry.sample(p,61)
		check(before.size()==after.size(),"mirroring preserves count")
		for i in before.size():
			check(before[i].pos.is_equal_approx(-after[i].pos),"opposite direction mirrors anchors")
			check(before[i].direction.is_equal_approx(-after[i].direction),"opposite direction mirrors projected vectors")
	p=Profile.new(); p.shape=2; p.lane_count=7; p.lane_width=80; p.lane_length=20; p.inner_radius=60; p.layers=6; p.density=2
	check_footprint(p)
	check(Geometry.sample(p,17).size()<=492,"maximum lane site budget")
	# Clean profiles may have an inner radius equal to or beyond the footprint.
	# Multi-band casts must still travel outward even with jitter disabled.
	for shape in 3:
		p=Profile.new(); p.shape=shape; p.layers=6; p.irregularity=0
		p.radius=20; p.inner_radius=20; p.lane_length=20
		if shape==2: p.inner_radius=36
		var previous:float=-1.0
		var visited:Array[int]=[]
		for site in Geometry.sample(p,17):
			if visited.has(site.layer): continue
			visited.append(site.layer)
			var flat:Vector2=Vector2(site.pos.x,site.pos.y/p.ground_squash)
			var distance:float=flat.length()
			if shape==2:
				distance=flat.dot(Vector2.from_angle(deg_to_rad(Geometry.lane_angles(p)[0])))
			if site.layer>0: check(distance>previous+.1,"small footprint bands progress outward")
			previous=distance
		check_footprint(p)
	p=Profile.new(); p.shape=0; p.radius=180; p.layers=6; p.density=2
	check_footprint(p)
	print("PASS" if failures==0 else "FAIL"," shared geometry: ",checks," assertions, ",failures," failures")
	quit(0 if failures==0 else 1)
