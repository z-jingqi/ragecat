extends Node2D
## Independent filled-polygon dissolve; there is deliberately no default actor.
## Source vertices/colors are copied, never moved or removed from the caller.
## No texture capture, holes, combat ownership, collision, camera or hidden host.
signal finished
const Config = preload("res://scripts/vfx/cel/death_config.gd")
const MAX_CONTOURS := 16
const MAX_POINTS := 512
const MAX_CONTOUR_POINTS := 128
@export var settings: Config = Config.new()
var config: Config = Config.new()
var age := -1.0
var playing := false
var source_error := ""
var cache_generation := 0
var _configured := false
var _source: Array = []
var _colors: Array = []
var _triangles: Array = []
var _total_area := 0.0
var _bounds := Rect2()
var _axis := Vector2.RIGHT
var _side := Vector2.DOWN
var _umin := 0.0
var _umax := 0.0
var _vmin := 0.0
var _vmax := 0.0
var _margin := 32.0
var _knots: Array = []
var _shards: Array = []

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	_rebuild_motion_cache()
	queue_redraw()

func source_count() -> int:
	return _source.size()

func get_source_snapshot() -> Dictionary:
	return {"polygons":_source.duplicate(true),"colors":_colors.duplicate(true)}

func clear_source() -> void:
	_source.clear()
	_colors.clear()
	_triangles.clear()
	_knots.clear()
	_shards.clear()
	_total_area = 0.0
	_bounds = Rect2()
	source_error = ""
	cache_generation += 1
	queue_redraw()

func _reject(message: String) -> bool:
	source_error = message
	return false

func _orientation(a: Vector2, b: Vector2, c: Vector2) -> float:
	return (b-a).cross(c-a)

func _between(a: Vector2, b: Vector2, p: Vector2) -> bool:
	return p.x >= minf(a.x,b.x) and p.x <= maxf(a.x,b.x) and p.y >= minf(a.y,b.y) and p.y <= maxf(a.y,b.y)

func _segments_touch(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var o1 := _orientation(a,b,c)
	var o2 := _orientation(a,b,d)
	var o3 := _orientation(c,d,a)
	var o4 := _orientation(c,d,b)
	if o1*o2 < 0.0 and o3*o4 < 0.0: return true
	return (is_zero_approx(o1) and _between(a,b,c)) or (is_zero_approx(o2) and _between(a,b,d)) or (is_zero_approx(o3) and _between(c,d,a)) or (is_zero_approx(o4) and _between(c,d,b))

func set_source_polygons(polygons: Array, colors: Array = []) -> bool:
	# Validate the complete request before mutating any previously accepted source.
	if polygons.is_empty() or polygons.size() > MAX_CONTOURS: return _reject("Supply 1–16 filled simple polygon contours; clear_source() empties explicitly.")
	if not colors.is_empty() and colors.size() != polygons.size(): return _reject("Colors must be empty or match the contour count.")
	for color in colors:
		if not color is Color: return _reject("Every source color must be a Color.")
		if not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b) or not is_finite(color.a): return _reject("Source colors must be finite.")
		if color.r < 0 or color.r > 1 or color.g < 0 or color.g > 1 or color.b < 0 or color.b > 1 or color.a != 1: return _reject("Source colors must be opaque and within 0–1.")
	var next_source: Array = []
	var next_triangles: Array = []
	var next_area := 0.0
	var count := 0
	var next_bounds := Rect2()
	var first := true
	for input in polygons:
		if not input is PackedVector2Array: return _reject("Each contour must be a PackedVector2Array.")
		var points: PackedVector2Array = input.duplicate()
		if points.size() > 1 and points[0] == points[-1]: points.resize(points.size()-1)
		count += points.size()
		if points.size() < 3 or points.size() > MAX_CONTOUR_POINTS or count > MAX_POINTS: return _reject("Use 3–128 vertices per contour and at most 512 total.")
		for i in range(points.size()):
			if not points[i].is_finite() or absf(points[i].x) > 4096 or absf(points[i].y) > 4096: return _reject("Coordinates must be finite and each component within ±4096.")
			for j in range(i):
				if points[i] == points[j]: return _reject("Interior repeated vertices and self-touching contours are unsupported.")
			if first:
				next_bounds = Rect2(points[i],Vector2.ZERO)
				first = false
			else: next_bounds = next_bounds.expand(points[i])
		for i in range(points.size()):
			if is_zero_approx(_orientation(points[(i+points.size()-1)%points.size()],points[i],points[(i+1)%points.size()])): return _reject("Remove collinear or zero-length contour edges.")
			for j in range(i+2,points.size()):
				if i == 0 and j == points.size()-1: continue
				if _segments_touch(points[i],points[(i+1)%points.size()],points[j],points[(j+1)%points.size()]): return _reject("Contours must be simple: no crossing, overlapping or touching edges.")
		var indices := Geometry2D.triangulate_polygon(points)
		if indices.size() != (points.size()-2)*3: return _reject("Source contour has degenerate geometry; holes are not supported.")
		for i in range(0,indices.size(),3):
			var a := points[indices[i]]
			var b := points[indices[i+1]]
			var c := points[indices[i+2]]
			var area := absf((b-a).cross(c-a))*0.5
			next_area += area
			next_triangles.append({"a":a,"b":b,"c":c,"area_end":next_area})
		next_source.append(points)
	if next_area <= 0.0: return _reject("Source must enclose nonzero area.")
	_source = next_source
	_colors = colors.duplicate(true)
	_triangles = next_triangles
	_total_area = next_area
	_bounds = next_bounds
	source_error = ""
	_rebuild_motion_cache()
	queue_redraw()
	return true

func play() -> void:
	age = 0.0
	playing = true
	queue_redraw()

func seek(seconds: float) -> void:
	age = seconds if is_finite(seconds) else -1.0
	playing = false
	queue_redraw()

func stop() -> void:
	age = -1.0
	playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	age = minf(age+maxf(delta,0.0),config.duration())
	queue_redraw()
	if age >= config.duration():
		playing = false
		finished.emit()

func _sample_source(rng: RandomNumberGenerator) -> Vector2:
	var selection := rng.randf()*_total_area
	var triangle: Dictionary = _triangles[-1]
	for candidate in _triangles:
		if selection <= candidate.area_end:
			triangle = candidate
			break
	var u := sqrt(rng.randf())
	var v := rng.randf()
	return triangle.a*(1.0-u)+triangle.b*u*(1.0-v)+triangle.c*u*v

func _rebuild_motion_cache() -> void:
	cache_generation += 1
	_knots.clear()
	_shards.clear()
	if _source.is_empty(): return
	_axis = Vector2.from_angle(deg_to_rad(config.erode_degrees))
	_side = Vector2(-_axis.y,_axis.x)
	_umin = INF
	_umax = -INF
	_vmin = INF
	_vmax = -INF
	for polygon in _source:
		for point in polygon:
			_umin = minf(_umin,point.dot(_axis))
			_umax = maxf(_umax,point.dot(_axis))
			_vmin = minf(_vmin,point.dot(_side))
			_vmax = maxf(_vmax,point.dot(_side))
	_margin = 28.0+config.edge_roughness*15.0+config.edge_width
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value
	var knot_count := clampi(int((_vmax-_vmin)/7.0)+3,8,48)
	for i in range(knot_count):
		var v := lerpf(_vmin-_margin,_vmax+_margin,i/float(knot_count-1))
		_knots.append({"v":v,"offset":rng.randf_range(-5.5,5.5),"phase":rng.randf_range(-PI,PI)})
	for i in range(config.shard_count):
		var origin := _sample_source(rng)
		var lo := config.flash_seconds
		var hi := config.flash_seconds+config.erosion_seconds
		for iteration in range(24):
			var mid := (lo+hi)*0.5
			if _front(origin.dot(_side),mid) > origin.dot(_axis): lo = mid
			else: hi = mid
		var large := i%7 == 0
		var width := rng.randf_range(5.0,9.0)*(1.9 if large else 1.0)*config.shard_size
		var length := rng.randf_range(10.0,19.0)*(1.7 if large else (0.48 if i%5 == 1 else 1.0))*config.shard_size
		var direction := Vector2.from_angle(deg_to_rad(config.shard_direction_degrees)+rng.randf_range(-0.22,0.22)*config.shard_spread)
		var velocity := direction*config.shard_speed*rng.randf_range(0.68,1.35)*sqrt(config.intensity)
		_shards.append({"origin":origin,"birth":(lo+hi)*0.5,"life":config.shard_seconds*rng.randf_range(0.64,1.0),"width":width,"length":length,"velocity":velocity,"spin":rng.randf_range(-1.7,1.7),"phase":rng.randf_range(-PI,PI),"large":large,"index":i})

func _front(v: float, t: float) -> float:
	var progress := clampf((t-config.flash_seconds)/config.erosion_seconds,0.0,1.0)
	var base := lerpf(_umax+_margin,_umin-_margin,progress)
	var index := clampi(int((v-(_vmin-_margin))/((_vmax-_vmin)+_margin*2.0)*(_knots.size()-1)),0,_knots.size()-2)
	var a: Dictionary = _knots[index]
	var b: Dictionary = _knots[index+1]
	var blend := clampf((v-a.v)/(b.v-a.v),0.0,1.0)
	var jag_a: float = a.offset+sin(t*10.0+a.phase)*1.8
	var jag_b: float = b.offset+sin(t*10.0+b.phase)*1.8
	return base+lerpf(jag_a,jag_b,blend)*config.edge_roughness

func _mask(t: float, inset: float) -> PackedVector2Array:
	var points := PackedVector2Array([_axis*(_umin-_margin*3.0)+_side*(_vmin-_margin)])
	for knot in _knots:
		points.append(_axis*(_front(knot.v,t)-inset)+_side*knot.v)
	points.append(_axis*(_umin-_margin*3.0)+_side*(_vmax+_margin))
	return points

func _band(t: float, outer_inset: float, inner_inset: float) -> PackedVector2Array:
	# One simple ribbon with two noncrossing copies of the same jagged front.
	var points := PackedVector2Array()
	for knot in _knots: points.append(_axis*(_front(knot.v,t)-outer_inset)+_side*knot.v)
	for i in range(_knots.size()-1,-1,-1):
		var knot: Dictionary = _knots[i]
		points.append(_axis*(_front(knot.v,t)-inner_inset)+_side*knot.v)
	return points

func _polygon(commands: Array, points: PackedVector2Array, color: Color) -> void:
	# Clipper can emit duplicated/collinear vertices and subpixel remnants at an
	# exact crossing. Normalize those representations, not invalid input geometry.
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or point.distance_squared_to(clean[-1]) > 0.00000001: clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[-1]) < 0.00000001: clean.resize(clean.size()-1)
	var index := clean.size()-1
	while index >= 0 and clean.size() >= 3:
		var previous := clean[(index+clean.size()-1)%clean.size()]
		var current := clean[index]
		var following := clean[(index+1)%clean.size()]
		if absf((current-previous).cross(following-current)) < 0.000001 and (current-previous).dot(following-current) >= 0.0: clean.remove_at(index)
		index -= 1
	if clean.size() < 3: return
	var area := 0.0
	for i in range(clean.size()): area += clean[i].cross(clean[(i+1)%clean.size()])
	if absf(area) < 0.002: return # Less than one-thousandth of a local square pixel.
	var transformed := PackedVector2Array()
	for point in clean: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color})

func _clipped(commands: Array, polygon: PackedVector2Array, mask: PackedVector2Array, color: Color) -> void:
	for part in Geometry2D.intersect_polygons(polygon,mask): _polygon(commands,part,color)

func _draw_shards(commands: Array, t: float) -> void:
	for shard in _shards:
		var dt: float = t-shard.birth
		if dt < 0.0 or dt >= shard.life: continue
		var u: float = dt/shard.life
		var grow := 0.65+0.35*smoothstep(0.0,0.06,dt)
		var erosion := 1.0-smoothstep(0.32,1.0,u)
		var scale_factor := grow*erosion
		if scale_factor < 0.025: continue
		var velocity: Vector2 = shard.velocity
		var normal := Vector2(-velocity.y,velocity.x).normalized()
		# A slight accelerating drift and independent bend/roll keep the energy alive.
		var center: Vector2 = shard.origin+velocity*dt*(0.75+0.20*u)+normal*sin(dt*8.0+shard.phase)*dt*13.0*config.shard_spread
		var axis := velocity.normalized().rotated(shard.spin*dt)
		var side := Vector2(-axis.y,axis.x)
		var width: float = shard.width*scale_factor
		var length: float = shard.length*scale_factor
		var shape := PackedVector2Array([center+axis*length,center+axis*length*0.18+side*width,center-axis*length*0.28+side*width*0.48,center-axis*length*0.78,center-axis*length*0.22-side*width*0.74,center+axis*length*0.24-side*width*0.43])
		_polygon(commands,shape,config.core_color if shard.index%3 == 0 else config.shard_color)
		if shard.large:
			_polygon(commands,PackedVector2Array([shape[1],shape[2],shape[3],center-axis*length*0.12]),config.edge_color)

func _draw_wisps(commands: Array, t: float) -> void:
	var end := config.flash_seconds+config.erosion_seconds+0.20
	if t >= end: return
	var u := t/end
	var envelope := smoothstep(0.0,0.05,t)*(1.0-smoothstep(0.45,1.0,u))
	if envelope < 0.02: return
	var center := Vector2(_bounds.get_center().x,_bounds.end.y+1.0)
	for i in range(3):
		var direction := -1.0 if i == 0 else 1.0
		var distance := (20.0+i*16.0)*(1.0-pow(1.0-u,2.0))
		var origin := center+Vector2(direction*distance,0)
		var length := (24.0+i*11.0)*envelope
		var height := (7.0+i*1.5)*envelope
		_polygon(commands,PackedVector2Array([origin+Vector2(-direction*length,0),origin+Vector2(-direction*length*0.2,-height*0.25),origin+Vector2(direction*length*0.55,-height*1.6),origin+Vector2(direction*length*0.32,-height*0.30),origin+Vector2(direction*length,0),origin]),config.ash_color)

func build_commands(at_age: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if _source.is_empty() or not is_finite(at_age) or at_age < 0.0 or at_age >= config.duration(): return commands
	var t := at_age/config.duration_scale
	if config.show_wisps: _draw_wisps(commands,t)
	if t < config.flash_seconds:
		if config.show_flash or config.show_source:
			for i in range(_source.size()):
				var color: Color = config.core_color if config.show_flash else (config.source_color if _colors.is_empty() else _colors[i])
				_polygon(commands,_source[i],color)
	elif t < config.flash_seconds+config.erosion_seconds:
		var inner := _mask(t,config.edge_width)
		var edge_band := _band(t,0.0,config.edge_width)
		var hot_band := _band(t,config.edge_width*0.20,config.edge_width)
		for i in range(_source.size()):
			if config.show_source:
				_clipped(commands,_source[i],inner,config.source_color if _colors.is_empty() else _colors[i])
			if config.show_edge:
				_clipped(commands,_source[i],edge_band,config.edge_color)
				_clipped(commands,_source[i],hot_band,config.core_color)
	if config.show_shards: _draw_shards(commands,t)
	return commands

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.7,true)
