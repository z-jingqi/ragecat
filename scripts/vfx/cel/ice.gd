extends Node2D
## Pure cel ice. Every flying chunk is a partition of the crystal that existed
## when fracture was requested, retaining that source's flat facet colors.
signal finished
const Config = preload("res://scripts/vfx/cel/ice_config.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()
var age := -1.0
var shatter_at := -1.0
var holding := false
var playing := false
var _configured := false

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	queue_redraw()

func play(hold_crystals: bool = false) -> void:
	age = 0.0
	shatter_at = -1.0
	holding = hold_crystals
	playing = true
	queue_redraw()

func shatter() -> void:
	if age < 0.0 or shatter_at >= 0.0 or age >= get_end_time(): return
	if not holding and age >= (config.growth_seconds+config.hold_seconds)*config.duration_scale: return
	shatter_at = age
	queue_redraw()

func stop() -> void:
	age = -1.0
	shatter_at = -1.0
	holding = false
	playing = false
	queue_redraw()

func seek(seconds: float, shattered_at: float = -1.0, hold_crystals: bool = false) -> void:
	age = seconds if is_finite(seconds) and seconds >= 0.0 else -1.0
	shatter_at = shattered_at if is_finite(shattered_at) and shattered_at >= 0.0 else -1.0
	holding = hold_crystals
	playing = false
	queue_redraw()

func _shatter_time(override: float = -INF) -> float:
	var automatic := config.growth_seconds+config.hold_seconds
	if override == INF: return INF
	if override != -INF:
		if not is_finite(override) or (override < 0.0 and override != -1.0): return NAN
		if override >= 0.0: return override/config.duration_scale if holding else minf(automatic,override/config.duration_scale)
		return automatic
	if shatter_at >= 0.0: return shatter_at/config.duration_scale if holding else minf(automatic,shatter_at/config.duration_scale)
	return INF if holding else automatic

func get_end_time() -> float:
	var start := _shatter_time()
	return INF if start == INF else (start+config.crack_seconds+config.shatter_seconds+0.04)*config.duration_scale

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	var end := get_end_time()
	age = minf(age+maxf(delta,0.0),end)
	queue_redraw()
	if age >= end:
		playing = false
		finished.emit()

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.55,true)

func _rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value+offset
	return rng

func _append(commands: Array, points: PackedVector2Array, color: Color, layer: String, crystal: int = -1, piece: int = -1) -> void:
	if points.size() < 3: return
	var twice_area := 0.0
	for i in range(points.size()): twice_area += points[i].cross(points[(i+1)%points.size()])
	if absf(twice_area) < 0.01: return
	var transformed := PackedVector2Array()
	for point in points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color,"layer":layer,"crystal":crystal,"piece":piece})

func _growth(index: int, t: float) -> float:
	var delay: float = [0.0,0.13,0.22,0.32,0.40,0.28,0.35][index]*config.growth_seconds
	return smoothstep(delay,config.growth_seconds,t)

func _crystal(index: int, t: float) -> Dictionary:
	var rng := _rng(911+index*137)
	var growth := _growth(index,t)
	var heights := [1.0,0.72,0.65,0.39,0.32,0.52,0.46]
	var angles := [4.0,-31.0,30.0,-56.0,56.0,-13.0,15.0]
	var roots := [0.0,-0.20,0.21,-0.37,0.38,-0.45,0.47]
	var h: float = config.height*heights[index]*growth*rng.randf_range(0.96,1.04)
	# Width matures later than height; stagger and changing facet proportions
	# create crystallization rather than one scaled cluster logo.
	var w: float = config.width*([1.0,0.87,0.79,0.56,0.51,0.60,0.57][index])*pow(growth,0.72)
	var angle := deg_to_rad(angles[index]*config.spread+rng.randf_range(-2.5,2.5))
	var root := Vector2(roots[index]*config.width*config.spread,0.0)
	var a := Vector2(-w*0.44,0)
	var b := Vector2(-w*0.48,-h*0.73)
	var c := Vector2(w*0.10,-h)
	var d := Vector2(w*0.48,-h*0.66)
	var e := Vector2(w*0.39,0)
	var f := Vector2(w*0.01,0)
	var ridge := Vector2(w*0.035,-h*0.71)
	var faces: Array = [
		{"points":PackedVector2Array([a,b,ridge,f]),"color":config.shadow_color,"tone":"shadow"},
		{"points":PackedVector2Array([b,c,ridge]),"color":config.body_color,"tone":"body"},
		{"points":PackedVector2Array([f,ridge,d,e]),"color":config.light_color,"tone":"light"},
		{"points":PackedVector2Array([ridge,c,d]),"color":config.ridge_color,"tone":"ridge"}
	]
	var seam := PackedVector2Array([Vector2(-w,-h*0.40),Vector2(-w*0.12,-h*0.48),Vector2(w*0.10,-h*0.39),Vector2(w,-h*0.45)])
	return {"height":h,"width":w,"angle":angle,"root":root,"faces":faces,"outline":PackedVector2Array([a,b,c,d,e]),"seam":seam,"growth":growth}

func _place(points: PackedVector2Array, crystal: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points: result.append(point.rotated(crystal.angle)+crystal.root)
	return result

func _piece_regions(crystal: Dictionary) -> Array:
	var w: float = crystal.width*2.0
	var h: float = crystal.height*1.2
	var seam: PackedVector2Array = crystal.seam
	var lower := seam.duplicate()
	lower.append(Vector2(w,h*0.1)); lower.append(Vector2(-w,h*0.1))
	var upper := PackedVector2Array([Vector2(-w,-h),Vector2(w,-h)])
	for i in range(seam.size()-1,-1,-1): upper.append(seam[i])
	return [lower,upper]

func _chunks(commands: Array, crystal: Dictionary, index: int, u: float) -> void:
	var regions := _piece_regions(crystal)
	for piece in range(2):
		var full_parts := Geometry2D.intersect_polygons(crystal.outline,regions[piece])
		if full_parts.is_empty(): continue
		var center := Vector2.ZERO
		for point in full_parts[0]: center += point
		center /= full_parts[0].size()
		var world_center: Vector2 = center.rotated(crystal.angle)+crystal.root
		var rng := _rng(3001+index*173+piece*997)
		var side := signf(world_center.x)
		if is_zero_approx(side): side = -1.0 if piece == 0 else 1.0
		var force := config.shatter_force*sqrt(config.intensity)
		var velocity := Vector2(side*rng.randf_range(38,90),-rng.randf_range(90,145)*(1.0 if piece == 1 else 0.68))*force
		var offset := velocity*u+Vector2(0,85.0*u*u*force)
		var rotation_angle := side*rng.randf_range(0.5,1.7)*u*config.spin
		var shrink := 1.0-smoothstep(0.58,1.0,u)
		for face in crystal.faces:
			for clipped in Geometry2D.intersect_polygons(face.points,regions[piece]):
				var moved := PackedVector2Array()
				for point in _place(clipped,crystal): moved.append(world_center+(point-world_center).rotated(rotation_angle)*shrink+offset)
				_append(commands,moved,face.color,"chunk_"+face.tone,index,piece)

func _cracks(commands: Array, crystal: Dictionary, index: int, u: float) -> void:
	# Advance from the real entry into this grown crystal, not the construction
	# region's off-silhouette endpoint. Even an early crack visibly progresses.
	for seam in Geometry2D.intersect_polyline_with_polygon(crystal.seam,crystal.outline):
		var reveal := clampf((u-index*0.035)/(1.0-index*0.035),0,1)*(seam.size()-1)
		for i in range(seam.size()-1):
			var portion := clampf(reveal-i,0,1)
			if portion <= 0.0: continue
			var a: Vector2 = seam[i]
			var b: Vector2 = seam[i].lerp(seam[i+1],portion)
			var axis := b-a
			if axis.length() < 0.01: continue
			var normal := Vector2(-axis.y,axis.x).normalized()*1.25
			var strip := PackedVector2Array([a-normal,a+normal,b+normal,b-normal])
			for part in Geometry2D.intersect_polygons(strip,crystal.outline): _append(commands,_place(part,crystal),config.crack_color,"crack",index)

func _glints(commands: Array, crystal: Dictionary, index: int, t: float) -> void:
	if crystal.growth < 0.75: return
	var h: float = crystal.height
	var w: float = crystal.width
	var phase := fposmod(t*config.glint_speed*0.72+index*0.23,1.0)
	var y := -h*phase
	var band := PackedVector2Array([Vector2(-w,y-0.16*w-2),Vector2(w,y+0.16*w-2),Vector2(w,y+0.16*w+2),Vector2(-w,y-0.16*w+2)])
	for face in crystal.faces:
		for part in Geometry2D.intersect_polygons(face.points,band): _append(commands,_place(part,crystal),config.ridge_color,"glint",index)
	if index > 3: return
	var pulse := pow(maxf(sin(t*config.glint_speed*6.0+index*1.9),0),3.0)
	var center: Vector2 = Vector2((0.65 if index%2 == 0 else -0.75)*w,-h*0.69).rotated(crystal.angle)+crystal.root
	var s := (4.0+index)*pulse
	_append(commands,PackedVector2Array([center+Vector2(0,-s*1.6),center+Vector2(s*0.45,0),center+Vector2(0,s*1.6),center+Vector2(-s*0.45,0)]),config.ridge_color,"glint",index)

func _frost(commands: Array, t: float, break_time: float) -> void:
	var growth := smoothstep(0.0,config.growth_seconds*0.7,minf(t,break_time-config.crack_seconds))
	var fade := 1.0 if t < break_time else 1.0-smoothstep(0.0,config.shatter_seconds*0.42,t-break_time)
	var scale_factor := growth*fade
	if scale_factor <= 0.0: return
	var rng := _rng(5003)
	var reach := (config.width+config.height*0.22)*config.spread
	for i in range(11):
		var side := -1.0 if i%2 == 0 else 1.0
		var root := Vector2(rng.randf_range(-0.35,0.35)*reach,3)
		var tip := Vector2(side*rng.randf_range(0.35,1.0)*reach,rng.randf_range(-9,6))
		var ridge := root.lerp(tip,0.55)+Vector2(0,-rng.randf_range(7,17))
		_append(commands,PackedVector2Array([root*scale_factor,tip*scale_factor,ridge*scale_factor]),config.body_color if i%3 else config.light_color,"frost")
		_append(commands,PackedVector2Array([root*scale_factor,tip*scale_factor,(root.lerp(tip,0.48)+Vector2(0,4))*scale_factor]),config.ridge_color,"frost")

func _shards(commands: Array, crystals: Array, u: float) -> void:
	if u <= 0.0 or u >= 1.0: return
	for i in range(crystals.size()):
		var crystal: Dictionary = crystals[i]
		if crystal.height < 2.0 or crystal.width < 0.2: continue
		var rng := _rng(7001+i*331)
		for shard in range(3):
			# Origins lie on the real grown source's ridge, never at a full-size
			# replacement when an immature crystal is interrupted.
			var center: Vector2 = Vector2(0,-crystal.height*rng.randf_range(0.15,0.75)).rotated(crystal.angle)+crystal.root
			var side := -1.0 if (i+shard)%2 == 0 else 1.0
			var velocity := Vector2(side*rng.randf_range(70,160),rng.randf_range(-165,-55))*config.shatter_force*sqrt(config.intensity)
			center += velocity*u+Vector2(0,115*u*u)
			var span: float = minf(crystal.height*0.13,rng.randf_range(7,16))*(1.0-smoothstep(0.5,1.0,u))*sin(PI*minf(u*3,0.5))
			var axis := Vector2(0,-1).rotated(side*u*3.3*config.spin+i)
			var normal := Vector2(-axis.y,axis.x)*span*0.18
			_append(commands,PackedVector2Array([center-axis*span,center+normal,center+axis*span,center-normal]),config.body_color,"shard",i,shard)
			_append(commands,PackedVector2Array([center,center+normal,center+axis*span]),config.ridge_color,"shard",i,shard)

func build_commands(at_age: float = -INF, shattered_at: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0: return commands
	var t := at_age/config.duration_scale
	var fracture := _shatter_time(shattered_at)
	if is_nan(fracture): return commands
	var break_time := fracture+config.crack_seconds
	if t >= break_time+config.shatter_seconds+0.04: return commands
	var source_time := minf(t,fracture)
	var crystals: Array = []
	for i in range(config.crystal_count): crystals.append(_crystal(i,source_time))
	if config.show_frost: _frost(commands,t,break_time)
	# Back to front ordering keeps the central prism behind the two side spears.
	for index in range(crystals.size()):
		var crystal: Dictionary = crystals[index]
		if crystal.height < 0.1 or crystal.width < 0.1: continue
		if t < break_time:
			if config.show_crystals:
				for face in crystal.faces: _append(commands,_place(face.points,crystal),face.color,"crystal_"+face.tone,index)
			if config.show_glints: _glints(commands,crystal,index,minf(t,fracture))
			if config.show_cracks and t >= fracture: _cracks(commands,crystal,index,(t-fracture)/config.crack_seconds)
		elif config.show_chunks:
			var u := (t-break_time)/config.shatter_seconds
			if u < 1.0: _chunks(commands,crystal,index,u)
	if config.show_shards and t >= break_time: _shards(commands,crystals,(t-break_time)/config.shatter_seconds)
	return commands
