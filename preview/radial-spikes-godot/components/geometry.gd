extends RefCounted
## Shared visual footprint. All construction happens in unsquashed ground space.
## Call with a cleaned profile. Contours are closed, ground-projected polylines.
const ARC_STEPS:int=128
const EDGE_INSET:float=.16
static func project(point:Vector2,profile:Resource)->Vector2:
	return Vector2(point.x,point.y*profile.ground_squash)
static func lane_angles(profile:Resource)->PackedFloat32Array:
	if not profile.lane_directions.is_empty(): return profile.lane_directions.duplicate()
	var result:PackedFloat32Array=[]
	for lane in profile.lane_count:
		result.append(profile.direction_degrees+(0.0 if profile.lane_count==1 else lerpf(-profile.lane_spread*.5,profile.lane_spread*.5,float(lane)/(profile.lane_count-1))))
	return result
static func outlines(profile:Resource)->Array[PackedVector2Array]:
	var result:Array[PackedVector2Array]=[]
	if profile.shape==2:
		for angle in lane_angles(profile):
			var forward:Vector2=Vector2.from_angle(deg_to_rad(angle))
			var side:Vector2=forward.orthogonal()*profile.lane_width*.5
			var end:Vector2=forward*profile.lane_length
			result.append(PackedVector2Array([project(-side,profile),project(end-side,profile),project(end+side,profile),project(side,profile),project(-side,profile)]))
		return result
	var full:bool=profile.shape==0 or profile.sector_angle>=360.0
	var sweep:float=TAU if full else deg_to_rad(profile.sector_angle)
	var start:float=0.0 if full else deg_to_rad(profile.direction_degrees)-sweep*.5
	var steps:int=maxi(2,ceili(ARC_STEPS*sweep/TAU))
	var line:PackedVector2Array=[]
	if not full: line.append(Vector2.ZERO)
	for i in range(steps+1):
		line.append(project(Vector2.from_angle(start+sweep*float(i)/steps)*profile.radius,profile))
	line.append(line[0]); result.append(line)
	return result
static func sample(profile:Resource,seed_value:int)->Array[Dictionary]:
	var sites:Array[Dictionary]=[]
	for layer in profile.layers:
		# Independent streams keep each band's jitter stable when other counts change.
		var rng:RandomNumberGenerator=RandomNumberGenerator.new()
		rng.seed=seed_value+layer*104729
		var fraction:float=0.0 if profile.layers==1 else float(layer)/(profile.layers-1)
		if profile.shape==2:
			var length:float=profile.lane_length
			var start:float=minf(profile.inner_radius,length if profile.layers==1 else length*.5)
			var distance:float=lerpf(start,length,fraction)
			var count:int=clampi(roundi(profile.lane_width/12.0*profile.density),2,11)
			var angles:PackedFloat32Array=lane_angles(profile)
			for lane in angles.size():
				var forward:Vector2=Vector2.from_angle(deg_to_rad(angles[lane]))
				var side:Vector2=forward.orthogonal()
				for i in count:
					var along:float=clampf(distance+rng.randf_range(-3.5,3.5)*profile.irregularity,EDGE_INSET,length-EDGE_INSET)
					var across:float=((i+.5+rng.randf_range(-.24,.24)*profile.irregularity)/count-.5)*profile.lane_width
					var point:Vector2=forward*along+side*across
					sites.append(_site(profile,rng,point,forward,layer,lane*count+i,lane))
		else:
			var start:float=minf(profile.inner_radius,profile.radius if profile.layers==1 else profile.radius*.5)
			var radius:float=lerpf(start,profile.radius,fraction)
			var full:bool=profile.shape==0 or profile.sector_angle>=360.0
			var sweep:float=TAU if full else deg_to_rad(profile.sector_angle)
			var count:int=clampi(roundi(sweep*radius/32.0*profile.density),4 if full else 2,82)
			var turn:float=rng.randf_range(0,TAU) if full else deg_to_rad(profile.direction_degrees)-sweep*.5
			for i in count:
				var theta:float=turn+sweep*(i+.5+rng.randf_range(-.24,.24)*profile.irregularity)/count
				var radial:float=clampf(radius+rng.randf_range(-3.5,3.5)*profile.irregularity,0,profile.radius-EDGE_INSET)
				var forward:Vector2=Vector2.from_angle(theta)
				sites.append(_site(profile,rng,forward*radial,forward,layer,i,-1))
	return sites
static func _site(profile:Resource,rng:RandomNumberGenerator,point:Vector2,forward:Vector2,layer:int,index:int,lane:int)->Dictionary:
	var strength:float=1.0 if (index+layer)%4==0 else rng.randf_range(.35,.6)
	return {"pos":project(point,profile),"direction":project(forward,profile).normalized(),"strength":strength,
		"height":rng.randf_range(22,32)*profile.spike_size*(1+layer*.055)*(.88+.24*strength),
		"width":rng.randf_range(9,13)*profile.spike_size,"lean":forward.x*.18+rng.randf_range(-.09,.09),
		"variant":rng.randf(),"seed":rng.randi(),"layer":layer,"lane":lane,
		"spawn":profile.onset_delay+layer*profile.layer_stride()+rng.randf_range(0,profile.stagger_window())}
