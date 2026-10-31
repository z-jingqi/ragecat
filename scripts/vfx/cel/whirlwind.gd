extends Node2D
## Independent advecting cel wind. Local origin is the narrow grounded foot.
## Ribbon geometry, not a rotated texture; no actor, collision, force or damage.
signal finished
const Config = preload("res://scripts/vfx/cel/whirlwind_config.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()
var age := -1.0
var release_at := -1.0
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

func play(hold_sustain: bool = false) -> void:
	age = 0.0
	release_at = -1.0
	holding = hold_sustain
	playing = true
	queue_redraw()

func release() -> void:
	if age < 0.0 or release_at >= 0.0 or age >= get_end_time(): return
	# An automatic release already in progress cannot be postponed by another call.
	if not holding and age >= (config.spinup_seconds+config.sustain_seconds)*config.duration_scale: return
	release_at = age
	# Keep paused seeks paused. A host can resume or seek the resulting timeline.
	queue_redraw()

func stop() -> void:
	age = -1.0
	release_at = -1.0
	holding = false
	playing = false
	queue_redraw()

func seek(seconds: float, released_at: float = -1.0, hold_sustain: bool = false) -> void:
	age = seconds if is_finite(seconds) and seconds >= 0.0 else -1.0
	release_at = released_at if is_finite(released_at) and released_at >= 0.0 else -1.0
	holding = hold_sustain
	playing = false
	queue_redraw()

func _release_time(override: float = -INF) -> float:
	var automatic := config.spinup_seconds+config.sustain_seconds
	if override == INF: return INF
	if override != -INF:
		if not is_finite(override) or (override < 0.0 and override != -1.0): return NAN
		if override >= 0.0: return override/config.duration_scale if holding else minf(automatic,override/config.duration_scale)
		return automatic
	if release_at >= 0.0: return release_at/config.duration_scale if holding else minf(automatic,release_at/config.duration_scale)
	return INF if holding else automatic

func get_end_time() -> float:
	var start := _release_time()
	return INF if start == INF else (start+config.release_seconds+0.04)*config.duration_scale

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	var end := get_end_time()
	age = minf(age+maxf(delta,0.0),end)
	queue_redraw()
	if age >= end:
		playing = false
		finished.emit()

func _phase(t: float, speed: float) -> float:
	# Bounded phases remain finite after arbitrarily long held playback.
	return 0.0 if speed <= 0.0 else fposmod(t,1.0/speed)*speed*TAU

func _scroll(t: float) -> float:
	return 0.0 if config.rise_speed <= 0.0 else fposmod(t,128.0/config.rise_speed)*config.rise_speed

func _seed_phase(id: int) -> float:
	return sin(float(posmod(id,128)*17+posmod(config.seed_value,997))*1.17)*0.24

func _center(id: int, u: float, scroll: float, phase: float) -> Vector2:
	var s := clampf((id+scroll+u)/float(config.ribbon_count),0.0,1.0)
	var theta := u*TAU+phase+_seed_phase(id)
	var radius := config.top_radius*(0.085+0.915*pow(s,0.88))*sqrt(config.intensity)
	var lean := sin(s*2.7+_seed_phase(id))*s*s*config.top_radius*0.11
	return Vector2(cos(theta)*radius+lean,-config.height*s+sin(theta)*radius*0.10+cos(theta)*radius*0.34)

func _width(id: int, u: float, scroll: float, phase: float, growth: float) -> float:
	var s := (id+scroll+u)/float(config.ribbon_count)
	var taper := pow(maxf(sin(u*PI),0.0),0.48)
	taper *= smoothstep(0.0,0.055,s)*(1.0-smoothstep(maxf(0.0,growth-0.06),growth,s))
	var pulse := 0.9+0.10*sin(u*9.0-phase*2.0+_seed_phase(id))
	# Limit strip thickness to pitch so extreme count/height values stay legible.
	var width := minf(config.ribbon_width,config.height/float(config.ribbon_count)*0.30)
	# A vertical cross-section must close at the projected side turn. Letting
	# full width reach that turn creates a square tape end instead of an air tip.
	var theta := u*TAU+phase+_seed_phase(id)
	var facing := pow(absf(sin(theta)),0.55)
	var projected_speed := absf(_x_derivative(id,u,scroll,phase))
	var side_taper := smoothstep(0.0,maxf(config.top_radius*TAU*0.24,20.0),projected_speed)
	return width*(0.45+0.55*maxf(s,0.0))*taper*pulse*facing*side_taper*sqrt(config.intensity)

func _clean_polygon(points: PackedVector2Array) -> PackedVector2Array:
	# Joined strip tips share one point, not two coincident boundary vertices.
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_squared_to(point) > 0.00000001: clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[-1]) <= 0.00000001: clean.resize(clean.size()-1)
	return clean

func _area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(1,points.size()-1): area += (points[i]-points[0]).cross(points[i+1]-points[0])
	return absf(area)*0.5

func _raw_append(commands: Array, points: PackedVector2Array, color: Color, layer: String, id: int, piece: int, pivot: Vector2 = Vector2(INF,INF)) -> bool:
	var clean := _clean_polygon(points)
	if clean.size() < 3 or _area(clean) < 0.005: return false
	if not pivot.is_finite():
		pivot = Vector2.ZERO
		for point in clean: pivot += point
		pivot /= clean.size()
	commands.append({"points":clean,"color":color,"layer":layer,"ribbon_id":id,"piece":piece,"pivot":pivot})
	return true

func _x_derivative(id: int, u: float, scroll: float, phase: float) -> float:
	var lo := maxf(0.0,u-0.0002)
	var hi := minf(1.0,u+0.0002)
	return (_center(id,hi,scroll,phase).x-_center(id,lo,scroll,phase).x)/maxf(hi-lo,0.00001)

func _strip(commands: Array, id: int, start: float, end: float, scroll: float, phase: float, growth: float, back: bool, piece: int, pivot: Vector2) -> void:
	if end-start < 0.0005: return
	# Each face is an x-monotone strip between two vertical boundaries. Unlike
	# normal offsets this cannot fold over itself at a tight projected bend.
	var centers := PackedVector2Array()
	var widths: Array[float] = []
	var direction := signf(_center(id,end,scroll,phase).x-_center(id,start,scroll,phase).x)
	var segments := maxi(2,int(ceil((end-start)*36.0)))
	for j in range(segments+1):
		var u := lerpf(start,end,float(j)/segments)
		var center := _center(id,u,scroll,phase)
		if not centers.is_empty() and (center.x-centers[-1].x)*direction <= 0.0001: continue
		centers.append(center)
		widths.append(_width(id,u,scroll,phase,growth))
	if centers.size() < 2: return
	for j in range(centers.size()-1):
		var top_a := centers[j]+Vector2(0,-widths[j])
		var top_b := centers[j+1]+Vector2(0,-widths[j+1])
		var bottom_a := centers[j]+Vector2(0,widths[j])
		var bottom_b := centers[j+1]+Vector2(0,widths[j+1])
		var hi_a := centers[j]+Vector2(0,-widths[j]*0.46)
		var hi_b := centers[j+1]+Vector2(0,-widths[j+1]*0.46)
		# Convex vertical-sided cells form a continuous face. No interior cell
		# edges are antialiased, so they do not turn into a tiled wireframe.
		if config.show_ribbons:
			if _raw_append(commands,PackedVector2Array([top_a,top_b,bottom_b,bottom_a]),config.back_color if back else config.front_color,"ribbon_back" if back else "ribbon_front",id,piece,pivot):
				commands[-1]["edges"] = [PackedVector2Array([top_a,top_b]),PackedVector2Array([bottom_a,bottom_b])]
		if config.show_highlights and not back:
			if _raw_append(commands,PackedVector2Array([top_a,top_b,hi_b,hi_a]),config.highlight_color,"highlight",id,piece,pivot):
				commands[-1]["edges"] = [PackedVector2Array([top_a,top_b]),PackedVector2Array([hi_a,hi_b])]

func _ribbons(commands: Array, t: float, growth: float) -> void:
	var scroll := _scroll(t)
	var phase := _phase(t,config.spin_speed)
	var rear: Array = []
	var front: Array = []
	# Only the currently visible strip births exist; work never grows with time.
	for id in range(int(floor(-scroll))-1,int(ceil(config.ribbon_count*growth-scroll))+1):
		var start := maxf(0.0,-id-scroll)
		var end := minf(1.0,config.ribbon_count*growth-id-scroll)
		if end <= start: continue
		var p := phase+_seed_phase(id)
		var cuts: Array[float] = [start]
		for k in range(-1,5):
			var cut := (k*PI-p)/TAU
			if cut > start+0.0001 and cut < end-0.0001: cuts.append(cut)
		# Find actual projected x extrema; changing radius shifts them away from
		# the front/back color boundaries. Bisect before constructing each face.
		var previous_u := start
		var previous_d := _x_derivative(id,start,scroll,phase)
		for sample in range(1,65):
			var u := lerpf(start,end,sample/64.0)
			var d := _x_derivative(id,u,scroll,phase)
			if previous_d*d < 0.0:
				var lo := previous_u
				var hi := u
				for iteration in range(18):
					var mid := (lo+hi)*0.5
					if _x_derivative(id,mid,scroll,phase)*previous_d > 0.0: lo = mid
					else: hi = mid
				var cut := (lo+hi)*0.5
				if cut > start+0.0001 and cut < end-0.0001: cuts.append(cut)
			previous_u = u
			previous_d = d
		cuts.append(end)
		cuts.sort()
		for j in range(cuts.size()-1):
			var back := sin((cuts[j]+cuts[j+1])*PI+p)<0.0
			# Geometry-only extrema do not create new flying pieces. All cells in
			# the same semantic front/back half share a release pivot and field.
			var half := int(floor(((cuts[j]+cuts[j+1])*PI+p)/PI))
			var half_start := maxf(start,(half*PI-p)/TAU)
			var half_end := minf(end,((half+1)*PI-p)/TAU)
			var pivot := _center(id,(half_start+half_end)*0.5,scroll,phase)
			_strip(rear if back else front,id,cuts[j],cuts[j+1],scroll,phase,growth,back,half,pivot)
	commands.append_array(rear)
	commands.append_array(front)

func _crescent(commands: Array, center: Vector2, radius: Vector2, angle: float, span: float, width: float, color: Color, layer: String, id: int) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for j in range(25):
		var u := j/24.0
		var theta := angle+(u-0.5)*span
		var w := width*pow(maxf(sin(u*PI),0),0.65)
		var point := center+Vector2(cos(theta)*radius.x,sin(theta)*radius.y)
		var normal := Vector2(cos(theta),sin(theta))
		outer.append(point+normal*w)
		if j > 0 and j < 24: inner.append(point-normal*w*0.45)
	for j in range(inner.size()-1,-1,-1): outer.append(inner[j])
	_raw_append(commands,outer,color,layer,id,0)

func _raw_commands(t: float) -> Array:
	var commands: Array = []
	var growth := smoothstep(0.0,config.spinup_seconds,t)
	if growth <= 0.001: return commands
	var phase := _phase(t,config.spin_speed)
	if config.show_ground:
		for i in range(3):
			_crescent(commands,Vector2(0,3),Vector2(42+i*9,4+i*1.8)*sqrt(growth)*sqrt(config.intensity),_phase(t,config.spin_speed*(1.0+i*0.1))+i*2.1,2.6,1.4*growth,config.front_color if i == 0 else config.sliver_color,"ground",-100-i)
	if config.show_ribbons or config.show_highlights: _ribbons(commands,t,growth)
	if config.show_slivers:
		for i in range(7):
			var s := fposmod(float(i)/7.0+_phase(t,config.rise_speed*0.15)/TAU,1.0)
			if s > growth or s < 0.04: continue
			var a := _phase(t,config.spin_speed*1.15)+i*2.399+_seed_phase(i)
			var radius := config.top_radius*(0.18+s*0.98)*sqrt(config.intensity)
			var center := Vector2(cos(a)*radius,-config.height*s+sin(a)*radius*0.16)
			var taper := smoothstep(0.04,0.13,s)*(1.0-smoothstep(0.82,1.0,s))
			_crescent(commands,center,Vector2(10+8*s,17+12*s),a+0.3,1.5,2.8*taper*sqrt(config.intensity),config.sliver_color,"sliver",-20-i)
	return commands

func _released_points(source: PackedVector2Array, id: int, t: float, center: Vector2) -> PackedVector2Array:
	var q := clampf(t/config.release_seconds,0,1)
	if q <= 0.0: return source.duplicate()
	var side := 1.0 if center.x >= 0.0 else -1.0
	var drift := Vector2(side*(28.0+absf(center.x)*0.8),-38.0-absf(center.y)*0.2)*config.release_spread*q
	var angle := side*(0.25+0.18*sin(float(id)))*q
	var shrink := 1.0-smoothstep(0.18,1.0,q)
	var points := PackedVector2Array()
	for point in source:
		var relative := point-center
		# Peel the upper end faster: this changes the curl itself, not just its pose.
		var shear := Vector2(side*relative.y*0.36*q,-side*relative.x*0.18*q)
		points.append(center+(relative+shear).rotated(angle)*shrink+drift)
	return points

func build_commands(at_age: float = -INF, released_at: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0: return commands
	var released := _release_time(released_at)
	if is_nan(released): return commands
	var t := at_age/config.duration_scale
	if not is_finite(t) or t >= released+config.release_seconds: return commands
	if t >= released and 1.0-smoothstep(0.18,1.0,(t-released)/config.release_seconds) < 0.003: return commands
	var raw := _raw_commands(minf(t,released))
	for command in raw:
		var points: PackedVector2Array = command.points
		if t >= released: points = _released_points(points,command.ribbon_id,t-released,command.pivot)
		points = _clean_polygon(points)
		# End a source cell before float precision collapses its shrinking area.
		if points.size() < 3: continue
		var furthest := 0.0
		var bounds := Rect2(points[0],Vector2.ZERO)
		for point in points:
			furthest = maxf(furthest,point.length_squared())
			bounds = bounds.expand(point)
		# Float32 canvas coordinates cannot retain a far-translated microscopic
		# curl. End only these subpixel cells; never test-and-drop triangulation.
		if _area(points) < maxf(0.03,furthest*0.000002) or maxf(bounds.size.x,bounds.size.y) < 0.6: continue
		var transformed := PackedVector2Array()
		for point in points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
		command.points = transformed
		if command.has("edges"):
			var edges: Array = []
			for edge in command.edges:
				var source_edge: PackedVector2Array = edge
				if t >= released: source_edge = _released_points(source_edge,command.ribbon_id,t-released,command.pivot)
				var transformed_edge := PackedVector2Array()
				for point in source_edge: transformed_edge.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
				edges.append(transformed_edge)
			command.edges = edges
		commands.append(command)
	return commands

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		if command.has("edges"):
			for edge in command.edges: draw_polyline(edge,command.color,0.55,true)
		else:
			var edge: PackedVector2Array = command.points.duplicate()
			edge.append(edge[0])
			draw_polyline(edge,command.color,0.55,true)
