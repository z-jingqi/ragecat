extends Node2D
## Independent cel barrier. The center is local origin. No actor or collision.
signal finished
const Config = preload("res://scripts/vfx/cel/shield_config.gd")
const MAX_HITS := 16
@export var settings: Config = Config.new()
var config: Config = Config.new()
var age := -1.0
var break_at := -1.0
var holding := false
var playing := false
var _configured := false
var _hits: Array = []

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	queue_redraw()

func play(hold_shield: bool = false) -> void:
	age = 0.0
	break_at = -1.0
	holding = hold_shield
	playing = true
	_hits.clear()
	queue_redraw()

func stop() -> void:
	age = -1.0
	break_at = -1.0
	holding = false
	playing = false
	_hits.clear()
	queue_redraw()

func seek(seconds: float, broken_at: float = -1.0, hold_shield: bool = false) -> void:
	age = seconds if is_finite(seconds) and seconds >= 0.0 else -1.0
	break_at = broken_at if is_finite(broken_at) and broken_at >= 0.0 else -1.0
	holding = hold_shield
	playing = false
	queue_redraw()

func set_hit_events(events: Array) -> bool:
	if events.size() > MAX_HITS: return false
	var checked: Array = []
	for event in events:
		if not event is Dictionary: return false
		for key in ["time","angle","strength"]:
			if not event.has(key) or not (event[key] is float or event[key] is int) or not is_finite(float(event[key])): return false
		if event.time < 0.0 or event.strength <= 0.0: return false
		checked.append({"time":float(event.time),"angle":wrapf(float(event.angle),-180.0,180.0),"strength":clampf(float(event.strength),0.1,2.0)})
	checked.sort_custom(func(a: Dictionary,b: Dictionary): return a.time < b.time)
	_hits = checked
	queue_redraw()
	return true

func get_hit_events() -> Array:
	return _hits.duplicate(true)

func clear_hits() -> void:
	_hits.clear()
	queue_redraw()

func hit(angle_degrees: float = -35.0, strength: float = 1.0) -> bool:
	if age < 0.0 or not is_finite(angle_degrees) or not is_finite(strength) or strength <= 0.0: return false
	var t := age/config.duration_scale
	if t >= _break_time() or not _grown_angle(deg_to_rad(angle_degrees),t): return false
	var active: Array = []
	for event in _hits:
		if age-event.time < config.hit_seconds*config.duration_scale: active.append(event)
	active.sort_custom(func(a: Dictionary,b: Dictionary): return a.time < b.time)
	if active.size() >= MAX_HITS: active.pop_front()
	active.append({"time":age,"angle":wrapf(angle_degrees,-180,180),"strength":clampf(strength,0.1,2.0)})
	active.sort_custom(func(a: Dictionary,b: Dictionary): return a.time < b.time)
	_hits = active
	queue_redraw()
	return true

func break_shield() -> void:
	if age < 0.0 or break_at >= 0.0 or age >= get_end_time(): return
	if not holding and age >= (config.spawn_seconds+config.hold_seconds)*config.duration_scale: return
	break_at = age
	queue_redraw()

func _break_time(override: float = -INF) -> float:
	var automatic := config.spawn_seconds+config.hold_seconds
	if override == INF: return INF
	if override != -INF:
		if not is_finite(override) or (override < 0.0 and override != -1.0): return NAN
		if override >= 0.0: return override/config.duration_scale if holding else minf(automatic,override/config.duration_scale)
		return automatic
	if break_at >= 0.0: return break_at/config.duration_scale if holding else minf(automatic,break_at/config.duration_scale)
	return INF if holding else automatic

func get_end_time() -> float:
	var start := _break_time()
	return INF if start == INF else (start+config.break_seconds+0.04)*config.duration_scale

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	var end := get_end_time()
	age = minf(age+maxf(delta,0),end)
	queue_redraw()
	if age >= end:
		playing = false
		finished.emit()

func _phase(t: float, rate: float = 1.0) -> float:
	var speed := config.flow_speed*rate
	return 0.0 if speed <= 0 else fposmod(t,TAU/speed)*speed

func _grown_angle(theta: float, t: float) -> bool:
	var growth := smoothstep(0.0,config.spawn_seconds,t)
	if growth <= 0.01: return false
	if growth >= 1.0: return true
	return absf(wrapf(theta-PI*0.5,-PI,PI)) < PI*growth-0.02

func _piece_bounds(piece: int) -> Vector2:
	var step := TAU/config.piece_count
	var seed_phase := float(posmod(config.seed_value,997))*0.019
	var lo := -PI+step*piece+step*0.13*sin(piece*2.37+seed_phase)
	var hi := -PI+step*(piece+1)+step*0.13*sin((piece+1)*2.37+seed_phase)
	if piece == 0: lo = -PI
	if piece == config.piece_count-1: hi = PI
	return Vector2(lo,hi)

func _valid_hit(event: Dictionary, t: float, broken: float) -> bool:
	var birth: float = event.time/config.duration_scale
	return birth <= t and birth < broken and _grown_angle(deg_to_rad(event.angle),birth)

func _radius_at(theta: float, t: float, broken: float) -> float:
	var radius: float = config.radius
	for event in _hits:
		if not _valid_hit(event,t,broken): continue
		var q: float = (t-event.time/config.duration_scale)/config.hit_seconds
		if q < 0 or q >= 1: continue
		var distance := absf(wrapf(theta-deg_to_rad(event.angle),-PI,PI))
		var pulse := sin(q*PI)*exp(-q*3.0)
		radius -= config.dent_depth*event.strength*config.intensity*pulse*exp(-pow(distance/0.23,2.0))
	return maxf(config.radius*0.68,radius)

func _point(theta: float, radial: float) -> Vector2:
	return Vector2(cos(theta)*radial,sin(theta)*radial*config.aspect)

func _rim_depth(theta: float, t: float) -> float:
	var phase := _phase(t,2.1)
	var sides := pow(absf(cos(theta+0.10*sin(phase))),1.8)
	# Unequal travelling inner-edge lobes create pointed broad side crescents,
	# not two constant-width bars painted on a static circle.
	var feather := 0.76+0.19*sin(theta*3.0-phase)+0.13*sin(theta*7.0+_phase(t,1.3))
	var asymmetry := 0.91+0.09*sin(theta+0.7)
	return minf(config.radius*0.40,config.rim_width*(0.09+0.91*sides)*feather*asymmetry*sqrt(config.intensity))

func _area(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(1,points.size()-1): area += (points[i]-points[0]).cross(points[i+1]-points[0])
	return absf(area)*0.5

func _append(commands: Array, points: PackedVector2Array, color: Color, layer: String, piece: int = -1, edges: Array = []) -> void:
	var clean := PackedVector2Array()
	for point in points:
		if clean.is_empty() or clean[-1].distance_squared_to(point) > 0.00000001: clean.append(point)
	if clean.size() > 1 and clean[0].distance_squared_to(clean[-1]) <= 0.00000001: clean.resize(clean.size()-1)
	if clean.size() < 3 or _area(clean) < 0.08: return
	commands.append({"points":clean,"color":color,"layer":layer,"piece":piece,"edges":edges})

func _band_cell(commands: Array, a: float, b: float, outer_a: float, outer_b: float, inner_a: float, inner_b: float, color: Color, layer: String, piece: int) -> void:
	var oa := _point(a,outer_a)
	var ob := _point(b,outer_b)
	var ia := _point(a,inner_a)
	var ib := _point(b,inner_b)
	_append(commands,PackedVector2Array([oa,ob,ib,ia]),color,layer,piece,[PackedVector2Array([oa,ob]),PackedVector2Array([ia,ib])])

func _shell(commands: Array, t: float, broken: float) -> void:
	var growth := smoothstep(0.0,config.spawn_seconds,t)
	if growth <= 0.001: return
	var phase := _phase(t,1.7)
	var streak_phase := _phase(t,1.7*0.75)
	for piece in range(config.piece_count):
		var bounds := _piece_bounds(piece)
		var steps := maxi(3,int(ceil((bounds.y-bounds.x)*38.0)))
		for j in range(steps):
			var a := lerpf(bounds.x,bounds.y,float(j)/steps)
			var b := lerpf(bounds.x,bounds.y,float(j+1)/steps)
			# Trim against the two growing angular fronts, without scaling the disk.
			var middle := (a+b)*0.5
			var wrapped := wrapf(middle-PI*0.5,-PI,PI)
			if absf(wrapped) > PI*growth+(b-a)*0.5: continue
			var center_branch := middle-wrapped
			a = maxf(a,center_branch-PI*growth)
			b = minf(b,center_branch+PI*growth)
			if b-a < 0.0001: continue
			var ra := _radius_at(a,t,broken)
			var rb := _radius_at(b,t,broken)
			var da := _rim_depth(a,t)
			var db := _rim_depth(b,t)
			var front_a := smoothstep(0,0.13,maxf(0,PI*growth-absf(wrapf(a-PI*0.5,-PI,PI))))
			var front_b := smoothstep(0,0.13,maxf(0,PI*growth-absf(wrapf(b-PI*0.5,-PI,PI))))
			front_a = lerpf(front_a,1.0,smoothstep(0.93,1.0,growth))
			front_b = lerpf(front_b,1.0,smoothstep(0.93,1.0,growth))
			da *= front_a
			db *= front_b
			if config.show_shell:
				_band_cell(commands,a,b,ra,rb,ra-da,rb-db,config.rim_color,"rim",piece)
				_band_cell(commands,a,b,ra,rb,ra-da*(0.65+0.18*sin(a*5.0+phase)),rb-db*(0.65+0.18*sin(b*5.0+phase)),config.body_color,"body",piece)
			if config.show_highlights:
				var ha := pow(maxf(0,sin(a*2.0-phase+0.6)),1.4)*0.95
				var hb := pow(maxf(0,sin(b*2.0-phase+0.6)),1.4)*0.95
				_band_cell(commands,a,b,ra-da*0.08,rb-db*0.08,ra-da*(0.08+ha*0.62),rb-db*(0.08+hb*0.62),config.highlight_color,"highlight",piece)
			if config.show_streaks:
				var sa := pow(maxf(0,sin(a*2.0+streak_phase+1.0)),5.0)
				var sb := pow(maxf(0,sin(b*2.0+streak_phase+1.0)),5.0)
				var r_a := ra-da*0.70-4.0-config.radius*0.035*sa
				var r_b := rb-db*0.70-4.0-config.radius*0.035*sb
				_band_cell(commands,a,b,r_a,r_b,r_a-config.rim_width*0.38*sa*front_a,r_b-config.rim_width*0.38*sb*front_b,config.rim_color,"streak",piece)

func _break_points(points: PackedVector2Array, piece: int, dt: float, source_t: float, broken: float) -> PackedVector2Array:
	var q := clampf(dt/config.break_seconds,0,1)
	if q <= 0: return points.duplicate()
	var bounds := _piece_bounds(piece)
	var theta := (bounds.x+bounds.y)*0.5
	var pivot := _point(theta,_radius_at(theta,source_t,broken)-_rim_depth(theta,source_t)*0.4)
	var normal := Vector2(cos(theta),sin(theta))
	var speed := (32.0+10.0*sin(piece*1.91+float(posmod(config.seed_value,997))))*config.break_force*sqrt(config.intensity)
	var drift: Vector2 = normal*speed*q+Vector2(0,-16*q+20*q*q)
	var rotation_angle := sin(piece*2.3+0.7)*0.85*q*config.spin
	var shrink := 1.0-smoothstep(0.2,1.0,q)
	var transformed := PackedVector2Array()
	for point in points:
		var relative := point-pivot
		var flex := Vector2(relative.y*0.13*q*sin(theta),relative.x*0.10*q*cos(theta))
		transformed.append(pivot+(relative+flex).rotated(rotation_angle)*shrink+drift)
	return transformed

func _impact(commands: Array, event: Dictionary, t: float, index: int, broken: float) -> void:
	var dt: float = t-event.time/config.duration_scale
	var q := dt/config.hit_seconds
	if q < 0 or q >= 1: return
	var theta := deg_to_rad(event.angle)
	var normal := Vector2(cos(theta),sin(theta))
	var tangent := Vector2(-normal.y,normal.x)
	var center := _point(theta,_radius_at(theta,t,broken))
	if config.show_hits:
		var pop := (1.0-smoothstep(0.08,0.43,q))*smoothstep(0.0,0.025,q)
		for i in range(5):
			var lateral: float = (i-2)*6.0*config.hit_size*event.strength
			var length: float = [20.0,36.0,50.0,29.0,18.0][i]*pop*config.hit_size*sqrt(config.intensity)*event.strength
			var base: Vector2 = center+tangent*lateral
			_append(commands,PackedVector2Array([base-tangent*4*pop,base+normal*length+tangent*(i-2)*2*pop,base+tangent*4*pop]),config.hit_color if i%2 == 0 else config.spark_color,"hit",-1)
		for i in range(6):
			var a := theta+(i-2.5)*0.23
			var drift: Vector2 = Vector2(cos(a),sin(a))*(22+8*i)*q*config.hit_size*event.strength
			var p: Vector2 = center+drift
			var s: float = (1.0-q)*3.2*config.hit_size*event.strength
			_append(commands,PackedVector2Array([p-normal*s*1.8,p+tangent*s*0.6,p+normal*s*1.8,p-tangent*s*0.6]),config.spark_color,"hit",-1)
	if config.show_ripples:
		for ring in range(2):
			var u := q*config.ripple_speed-ring*0.16
			if u <= 0 or u >= 1: continue
			var spread := u*1.9
			var c := normal*config.radius*0.90*cos(spread)
			var axes := Vector2(sin(spread)*config.radius*0.94,sin(spread)*config.radius*0.40)
			var thickness := 0.025*(1-u)*sqrt(event.strength)
			for j in range(64):
				var a := TAU*j/64.0
				var b := TAU*(j+1)/64.0
				# Only the front hemisphere arc is visible; no back-side full halo.
				if 0.435*cos(spread)+0.9*sin(spread)*sin((a+b)*0.5) < 0: continue
				var va := tangent*cos(a)*axes.x-normal*sin(a)*axes.y
				var vb := tangent*cos(b)*axes.x-normal*sin(b)*axes.y
				var pa := c+va
				var pb := c+vb
				var ia := c+va*(1.0-thickness)
				var ib := c+vb*(1.0-thickness)
				pa.y *= config.aspect
				pb.y *= config.aspect
				ia.y *= config.aspect
				ib.y *= config.aspect
				_append(commands,PackedVector2Array([pa,pb,ib,ia]),config.highlight_color if ring == 0 else config.body_color,"ripple",-1,[PackedVector2Array([pa,pb]),PackedVector2Array([ia,ib])])

func _chips(commands: Array, t: float, broken: float) -> void:
	if not config.show_chips or broken == INF or t < broken: return
	var q := (t-broken)/config.break_seconds
	if q < 0 or q >= 1: return
	for i in range(config.piece_count):
		var theta := (_piece_bounds(i).x+_piece_bounds(i).y)*0.5
		if not _grown_angle(theta,broken): continue
		var source := _point(theta,_radius_at(theta,broken,broken)-_rim_depth(theta,broken)*0.4)
		var outward := Vector2(cos(theta),sin(theta))
		var center := source+outward*(42+3*i)*q*config.break_force+Vector2(0,18*q*q)
		var s := 4.5*sin(PI*q)*(1-q)*sqrt(config.intensity)
		var n := outward.rotated(q*(i-3)*0.7*config.spin)
		var p := Vector2(-n.y,n.x)
		_append(commands,PackedVector2Array([center+n*s*1.5,center+p*s*0.7,center-n*s*1.5,center-p*s*0.7]),config.body_color if i%2 == 0 else config.highlight_color,"chip",i)

func build_commands(at_age: float = -INF, broken_at: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0: return commands
	var broken := _break_time(broken_at)
	if is_nan(broken): return commands
	var t := at_age/config.duration_scale
	if not is_finite(t) or t >= broken+config.break_seconds: return commands
	var raw: Array = []
	if t < broken or config.show_fragments: _shell(raw,minf(t,broken),broken)
	if t >= broken:
		var shrink := 1.0-smoothstep(0.2,1.0,(t-broken)/config.break_seconds)
		if shrink > 0.004:
			for command in raw:
				command.points = _break_points(command.points,command.piece,t-broken,broken,broken)
				var edges: Array = []
				for edge in command.edges: edges.append(_break_points(edge,command.piece,t-broken,broken,broken))
				command.edges = edges
				if _area(command.points) >= 0.08: commands.append(command)
	else: commands.append_array(raw)
	if t < broken:
		for i in range(_hits.size()):
			if _valid_hit(_hits[i],t,broken): _impact(commands,_hits[i],t,i,broken)
	_chips(commands,t,broken)
	var output: Array = []
	for command in commands:
		var transformed := PackedVector2Array()
		for point in command.points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
		command.points = transformed
		var edges: Array = []
		for edge in command.edges:
			var line := PackedVector2Array()
			for point in edge: line.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
			edges.append(line)
		command.edges = edges
		output.append(command)
	return output

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		if not command.edges.is_empty():
			for edge in command.edges: draw_polyline(edge,command.color,0.55,true)
		else:
			var edge: PackedVector2Array = command.points.duplicate()
			edge.append(edge[0])
			draw_polyline(edge,command.color,0.55,true)
