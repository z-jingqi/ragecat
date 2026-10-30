extends Node2D
## Independent cel lightning. The contact stays anchored while each return stroke
## reroutes its bends and forks; its final path breaks into disconnected remnants.
signal finished
const Config = preload("res://scripts/vfx/cel/lightning_config.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()
var age := -1.0
var playing := false
var _configured := false

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	queue_redraw()

func play() -> void:
	age = 0.0
	playing = true
	queue_redraw()

func stop() -> void:
	age = -1.0
	playing = false
	queue_redraw()

func seek(seconds: float) -> void:
	age = seconds if is_finite(seconds) and seconds >= 0.0 else -1.0
	playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	age = minf(age+maxf(delta,0.0),config.duration())
	queue_redraw()
	if age >= config.duration():
		playing = false
		finished.emit()

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.65,true)

func _rng(offset: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value+offset
	return rng

func _main_path(stroke: int) -> PackedVector2Array:
	var rng := _rng(801+stroke*701)
	var points := PackedVector2Array()
	# Unequal descending steps, not a sine wave or moving rigid bolt. The fixed
	# contact and monotone Y also make every generated ribbon a simple polygon.
	var levels := [0.0,0.045,0.105,0.145,0.245,0.315,0.395,0.505,0.555,0.665,0.775,0.855,1.0]
	# Broad asymmetric course changes contain a few small hook-back accents.
	# Several adjacent segments continue the same direction; this is deliberately
	# not an alternating +/- pattern or an evenly spaced accordion.
	var courses := [
		[-0.82,-0.51,-0.62,-0.22,-0.14,0.68,0.42,-0.49,-0.70,0.17,0.80,0.48,0.0],
		[-0.43,-0.18,0.19,0.09,-0.61,-0.79,-0.24,0.65,0.81,0.05,-0.51,-0.29,0.0],
		[-0.94,-0.79,-0.32,-0.39,0.42,0.63,0.28,0.16,-0.69,-0.51,0.31,0.65,0.0]
	]
	var course: Array = courses[posmod(stroke,3)]
	for i in range(levels.size()):
		var u: float = levels[i]
		var x: float = (course[i]+rng.randf_range(-0.11,0.11))*config.zigzag
		# Different small offsets and interval lengths on each stroke preserve
		# unmistakable rerouting without turning the contour into fine noise.
		if i > 0 and i < levels.size()-1: u += rng.randf_range(-0.009,0.009)
		points.append(Vector2(x,-config.length*(1.0-u)))
	points[points.size()-1] = Vector2.ZERO
	return points

func _branch_path(path: PackedVector2Array, branch: int, stroke: int) -> PackedVector2Array:
	var rng := _rng(1903+stroke*701+branch*173)
	var root_index := 2+posmod(branch*2+stroke,8)
	var root := path[root_index]
	var side := -1.0 if (branch+stroke)%2 == 0 else 1.0
	var reach := config.branch_reach*rng.randf_range(0.65,1.2)
	var drop := minf(config.length*0.34,-root.y*0.85)*rng.randf_range(0.65,1.0)
	var points := PackedVector2Array([root])
	for j in range(1,7):
		var u := j/6.0
		var bend: float = [0.0,0.10,-0.13,0.13,-0.03,0.03,0.0][j]+rng.randf_range(-0.035,0.035)*sin(PI*u)
		points.append(root+Vector2(side*reach*(u+bend),drop*u))
	return points

func _clip(path: PackedVector2Array, start: float, end: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	if end-start < 0.001: return result
	var from := clampf(start,0,1)*(path.size()-1)
	var to := clampf(end,0,1)*(path.size()-1)
	var first := mini(int(floor(from)),path.size()-2)
	var last := mini(int(floor(to)),path.size()-2)
	result.append(path[first].lerp(path[first+1],from-first))
	for i in range(first+1,last+1): result.append(path[i])
	var final := path[last].lerp(path[last+1],to-last)
	if result[-1].distance_squared_to(final) > 0.0001: result.append(final)
	return result

func _polygon(commands: Array, points: PackedVector2Array, color: Color, layer: String) -> void:
	if points.size() < 3: return
	var area := 0.0
	for i in range(points.size()): area += points[i].cross(points[(i+1)%points.size()])
	if absf(area) < 0.005: return
	var transformed := PackedVector2Array()
	for point in points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color,"layer":layer})

func _ribbon(commands: Array, path: PackedVector2Array, width: float, color: Color, tag: String, phase: float = 0.0, pointed_start: bool = true) -> void:
	if path.size() < 2 or width < 0.045: return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in range(path.size()):
		var u := i/float(path.size()-1)
		var taper := pow(sin(PI*u),0.24) if pointed_start else pow(1.0-u,0.65)
		var half_width := width*0.5*taper*(0.88+0.16*sin(i*2.31+phase))
		if tag.begins_with("main"):
			# Fine upper feeder, then a broad hot lower body with unequal pinches.
			# Width changes along the path, not only with a whole-bolt pulse.
			half_width *= (0.22+1.03*smoothstep(0.08,0.62,u))*(1.0-0.18*smoothstep(0.78,1.0,u))
		if i == path.size()-1 or (i == 0 and pointed_start): half_width = 0.0
		left.append(path[i]+Vector2(-half_width,0))
		if half_width > 0.0001: right.append(path[i]+Vector2(half_width,0))
	for i in range(right.size()-1,-1,-1): left.append(right[i])
	# Two-point tiny remnants need a center cross section to form a tapered shard.
	if left.size() < 3:
		var mid := path[0].lerp(path[-1],0.45)
		left = PackedVector2Array([path[0],mid+Vector2(width*0.5,0),path[-1],mid-Vector2(width*0.5,0)])
	_polygon(commands,left,color,tag)

func _paired_ribbon(commands: Array, path: PackedVector2Array, width: float, tag: String, phase: float = 0.0, pointed_start: bool = true, residual: bool = false) -> void:
	_ribbon(commands,path,width,config.residual_color if residual else config.rim_color,tag+"_rim",phase,pointed_start)
	_ribbon(commands,path,width*0.54,config.core_color,tag+"_core",phase,pointed_start)

func _branches(commands: Array, path: PackedVector2Array, stroke: int, width: float, reveal: float = 1.0) -> void:
	for i in range(config.branch_count):
		var branch := _branch_path(path,i,stroke)
		var root_index := 2+posmod(i*2+stroke,8)
		var local_reveal := clampf((reveal-root_index/12.0)*5.0,0,1)
		if local_reveal <= 0.0: continue
		branch = _clip(branch,0,local_reveal)
		_paired_ribbon(commands,branch,width*(0.20+0.045*(i%3)),"branch",stroke+i,false)
		# One secondary fork per two main branches, always rooted on the primary.
		if i%2 == 0 and local_reveal > 0.65:
			var root := _branch_path(path,i,stroke)[3]
			var side := -1.0 if (i+stroke)%2 == 0 else 1.0
			var child := PackedVector2Array([root,root+Vector2(side*9,18),root+Vector2(side*4,32),root+Vector2(side*15,49)])
			_paired_ribbon(commands,_clip(child,0,(local_reveal-0.65)/0.35),width*0.11,"branch",i,false)

func _contact(commands: Array, local_age: float, strength: float, stroke: int) -> void:
	var u := clampf(local_age/config.stroke_seconds,0,1)
	var scale_factor := config.contact_size*sqrt(config.intensity)*(1.0-0.45*u)*strength
	if scale_factor < 0.01: return
	var rng := _rng(3023+stroke*123)
	# A broken, asymmetric contact crown; independent tips flex and retract.
	var crown := PackedVector2Array([Vector2(-96,1),Vector2(-43,-8),Vector2(-64,-23),Vector2(-28,-16),Vector2(-45,-51),Vector2(-16,-25),Vector2(-21,-69),Vector2(-2,-20),Vector2(19,-52),Vector2(13,-20),Vector2(51,-46),Vector2(32,-14),Vector2(79,-27),Vector2(51,-6),Vector2(101,2),Vector2(16,7),Vector2(-22,6)])
	for i in range(crown.size()):
		crown[i] *= scale_factor
		if crown[i].y < -10: crown[i].x += rng.randf_range(-7,7)*sin(PI*u)*scale_factor
	_polygon(commands,crown,config.rim_color,"contact_rim")
	var core := PackedVector2Array()
	for point in crown: core.append(point*Vector2(0.68,0.65))
	_polygon(commands,core,config.core_color,"contact_core")
	for side in [-1.0,1.0]:
		var reach := 73.0+39.0*u
		var trail := PackedVector2Array([Vector2(side*21,-3),Vector2(side*reach*0.45,-10),Vector2(side*reach*0.60,-4),Vector2(side*reach*0.79,-13),Vector2(side*reach,-1)])
		for i in range(trail.size()): trail[i] *= scale_factor
		# This ground arc isn't monotone Y: use two-point tapered strokes so each
		# polygon stays convex rather than constructing a crossing ribbon.
		for j in range(trail.size()-1):
			var axis: Vector2 = trail[j+1]-trail[j]
			var normal := Vector2(-axis.y,axis.x).normalized()*2.4*(1.0-j/5.0)*scale_factor
			_polygon(commands,PackedVector2Array([trail[j]-normal,trail[j]+normal,trail[j+1]+normal*0.6,trail[j+1]-normal*0.6]),config.core_color,"contact_core")

func _residual(commands: Array, path: PackedVector2Array, u: float, gap: bool = false) -> void:
	if u < 0.0 or u >= 1.0: return
	var width := config.bolt_width*sqrt(config.intensity)*(0.26 if gap else 0.48)*pow(1.0-u,1.15)
	for i in range(6):
		var delay := (i%3)*0.075
		var local := clampf((u-delay)/(1.0-delay),0,1)
		var start := i/6.0+0.020+local*0.045
		var end := (i+1)/6.0-0.012-local*0.075
		if end <= start: continue
		var fragment := _clip(path,start,end)
		for j in range(fragment.size()):
			# Different local corners recoil by different amounts: no uniform drift.
			fragment[j].x += sin((i*3+j)*1.7+u*3.1)*local*8.0
		_paired_ribbon(commands,fragment,width*(1.0-0.55*local),"residual",i+u,true,true)

func _sparks(commands: Array, after_contact: float) -> void:
	if after_contact < 0.0: return
	var rng := _rng(4013)
	for i in range(9):
		var delay := rng.randf_range(0,0.1)
		var life := config.strike_end()-config.leader_seconds+config.residual_seconds-rng.randf_range(0.04,0.14)
		var u := (after_contact-delay)/life
		var start := Vector2(rng.randf_range(-35,35),-config.length*rng.randf_range(0.08,0.84))
		var side := -1.0 if i%2 == 0 else 1.0
		var velocity := Vector2(side*rng.randf_range(20,95),rng.randf_range(-20,30))
		var span := rng.randf_range(6,16)
		if u <= 0.0 or u >= 1.0: continue
		var strength := sin(PI*u)*pow(1.0-u,0.4)
		var center := start+velocity*u*sqrt(config.intensity)
		var axis := Vector2(side*0.4,-1).normalized()
		var normal := Vector2(-axis.y,axis.x)
		var diamond := PackedVector2Array([center-axis*span*strength,center+normal*2.3*strength,center+axis*span*strength,center-normal*1.4*strength])
		_polygon(commands,diamond,config.rim_color,"spark_rim")
		for j in range(diamond.size()): diamond[j] = center+(diamond[j]-center)*0.52
		_polygon(commands,diamond,config.core_color,"spark_core")

func build_commands(at_age: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0 or at_age >= config.duration(): return commands
	var t := at_age/config.duration_scale
	var width := config.bolt_width*sqrt(config.intensity)
	if t < config.leader_seconds:
		if config.show_leader:
			var reveal := clampf(t/config.leader_seconds,0,1)
			var path := _main_path(0)
			_paired_ribbon(commands,_clip(path,0,reveal),width*0.13,"leader",0,true)
			if config.show_branches: _branches(commands,path,0,width*0.3,reveal)
		return commands
	var since := t-config.leader_seconds
	var interval := config.stroke_seconds+config.stroke_gap_seconds
	var stroke := mini(int(floor(since/interval)),config.stroke_count-1)
	var local := since-stroke*interval
	var path := _main_path(stroke)
	if t < config.strike_end() and local < config.stroke_seconds:
		var pulse := 0.82+0.18*sin(PI*local/config.stroke_seconds)
		if config.show_branches: _branches(commands,path,stroke,width*pulse)
		if config.show_main: _paired_ribbon(commands,path,width*pulse,"main",stroke+local*10)
		if config.show_contact: _contact(commands,local,1.0,stroke)
	elif config.show_residual:
		if t < config.strike_end():
			_residual(commands,path,(local-config.stroke_seconds)/config.stroke_gap_seconds,true)
		else:
			_residual(commands,path,(t-config.strike_end())/config.residual_seconds)
	if config.show_sparks: _sparks(commands,since)
	return commands
