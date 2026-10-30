extends Node2D
## One connected, measured-reference silhouette. No charge, orb, collision or flight AI.
const Config = preload("res://scripts/vfx/cel/energy_bolt_config.gd")
const Shape = preload("res://scripts/vfx/cel/energy_bolt_shape.gd")
@export var settings: Config = Config.new()
var config: Config = Config.new()
var _configured := false

func _ready() -> void:
	if not _configured: configure(settings)

func configure(value: Config) -> void:
	config = value.duplicate(true) if value != null else Config.new()
	config.sanitize()
	_configured = true
	if active: _rebuild_curve()
	queue_redraw()

func build_reference_commands() -> Array:
	var commands: Array = []
	for layer in [[Shape.SHADE,config.shade_color],[Shape.BODY,config.body_color],[Shape.CORE,config.core_color]]:
		for i in range(layer[0].size()):
			if i > 0 and not config.detached_streaks: continue
			var points := PackedVector2Array()
			for point in layer[0][i]:
				points.append(((point-Shape.ORIGIN)*(config.head_height/Shape.REFERENCE_HEIGHT)*config.size).rotated(deg_to_rad(config.direction_degrees)))
			commands.append({"points":points,"color":layer[1]})
	return commands

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.7,true)

## Feed the actual world position AFTER the host has moved; velocity is measured here.
## The effect owns no movement integration and never reads a requested/target speed.
var actual_velocity := Vector2.ZERO
var actual_speed := 0.0
var tail_scale := 1.0
var active := false
var _head := Vector2.ZERO
var _direction := Vector2.RIGHT
var _history := PackedVector2Array()
var _curve := PackedVector2Array()
var _curve_distances := PackedFloat32Array()
var _total_distance := 0.0
var _width_guard := 1.0
var energy_age := 0.0
var _shed_clock := 0.0
var _shed_index := 0
var _shards: Array = []
var _core_samples := PackedVector2Array()

func reset_motion(world_position: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	if not world_position.is_finite(): return
	_head = world_position
	global_position = world_position
	_direction = direction.normalized() if direction.is_finite() and direction.length_squared() > 0.0001 else Vector2.RIGHT.rotated(deg_to_rad(config.direction_degrees))
	actual_velocity = Vector2.ZERO
	actual_speed = 0.0
	energy_age = 0.0
	_shed_clock = 0.0
	_shed_index = 0
	_shards.clear()
	tail_scale = config.tail_min
	_history = PackedVector2Array([_head])
	active = true
	_rebuild_curve()
	queue_redraw()

func stop() -> void:
	active = false
	_shards.clear()
	_history.clear()
	_curve.clear()
	_curve_distances.clear()
	actual_velocity = Vector2.ZERO
	actual_speed = 0.0
	queue_redraw()

func advance(world_position: Vector2, delta: float) -> void:
	if not world_position.is_finite() or not is_finite(delta) or delta <= 0.0: return
	if not active:
		reset_motion(world_position)
		return
	var displacement := world_position-_head
	var distance := displacement.length()
	# Teleports are not physical speed and must never leave a line across the map.
	if distance > maxf(config.teleport_distance,config.reference_speed*delta*4.0):
		reset_motion(world_position,_direction)
		return
	actual_velocity = displacement/delta
	actual_speed = actual_velocity.length()
	if distance > 0.0001:
		var heading := displacement/distance
		# A discontinuous reversal is a reset, not a zero-radius folded ribbon.
		if _direction.dot(heading) < 0.35: _history = PackedVector2Array([world_position])
		_direction = heading
	_head = world_position
	global_position = world_position
	var target := speed_to_tail(actual_speed)
	tail_scale = lerpf(tail_scale,target,1.0-exp(-delta/config.response_seconds))
	if _history.is_empty(): _history.append(_head)
	elif _head.distance_to(_history[0]) >= config.sample_distance:
		_history.insert(0,_head)
	while _history.size() > config.history_limit: _history.remove_at(_history.size()-1)
	_rebuild_curve()
	_advance_energy(delta)
	queue_redraw()

func speed_to_tail(speed: float) -> float:
	if not is_finite(speed): return config.tail_min
	var ratio := maxf(speed,0.0)/config.reference_speed
	# Exactly 1 at reference speed, with separate physically useful low/high clamps.
	return clampf(ratio,config.tail_min,config.tail_max)

func _rebuild_curve() -> void:
	_curve = PackedVector2Array([_head])
	_curve_distances = PackedFloat32Array([0.0])
	_total_distance = 0.0
	var max_distance := (Shape.ORIGIN.x-64.0)*config.head_height/Shape.REFERENCE_HEIGHT*config.size*config.tail_max+24.0
	var previous_heading := _direction
	var previous_distance := 0.0
	var max_curvature := 0.0
	var bend := 0.0
	for point in _history:
		var delta := _curve[-1]-point
		var distance := delta.length()
		if distance < 0.001: continue
		var heading := delta/distance
		var angle := absf(previous_heading.angle_to(heading))
		bend += angle
		if previous_distance > 0.0:
			max_curvature = maxf(max_curvature,angle/maxf((previous_distance+distance)*0.5,0.001))
		# Keep only the recent arc. Old loops must never wrap back across the head.
		if bend > 2.2 or _total_distance >= max_distance: break
		_curve.append(point)
		_total_distance += distance
		_curve_distances.append(_total_distance)
		previous_heading = heading
		previous_distance = distance
	# A single coherent width factor avoids longitudinal shearing at tight corners.
	_width_guard = minf(1.0,0.55/maxf(max_curvature*config.head_height*config.size*0.5,0.001))

func _path_point(distance: float) -> Vector2:
	if distance <= 0.0: return _head-_direction*distance
	if _curve.size() < 2: return _head-_direction*distance
	if distance >= _total_distance:
		var tangent := (_curve[-2]-_curve[-1]).normalized()
		return _curve[-1]-tangent*(distance-_total_distance)
	var lo := 0
	var hi := _curve_distances.size()-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if _curve_distances[mid] < distance: lo = mid
		else: hi = mid
	var t := (distance-_curve_distances[lo])/(_curve_distances[hi]-_curve_distances[lo])
	return _curve[lo].lerp(_curve[hi],t)

func _map_point(point: Vector2) -> Vector2:
	var unit := config.head_height/Shape.REFERENCE_HEIGHT*config.size
	var x := point.x
	if x < Shape.TAIL_JOIN_X: x = Shape.TAIL_JOIN_X+(x-Shape.TAIL_JOIN_X)*tail_scale
	var distance := (Shape.ORIGIN.x-x)*unit
	var half_window := maxf(5.0,config.head_height*config.size*0.18)
	var before := _path_point(distance-half_window)
	var after := _path_point(distance+half_window)
	var direction := (before-after).normalized()
	var normal := Vector2(-direction.y,direction.x)
	var world := _path_point(distance)+normal*(point.y-Shape.ORIGIN.y)*unit*_width_guard
	return to_local(world)

func build_commands(include_energy: bool = true) -> Array:
	var commands: Array = []
	if not active: return commands
	var moving_core := _core_outline() if include_energy else PackedVector2Array(Shape.CORE[0])
	var core_tint := config.core_color
	if include_energy and config.core_pulse_amplitude > 0:
		var light := 0.5+0.5*sin(energy_age*TAU*config.core_pulse_rate+0.6)
		core_tint = core_tint.lerp(Color.WHITE,light*config.core_pulse_amplitude*2.0)
	var layers := [[Shape.SHADE,config.shade_color],[Shape.BODY,config.body_color],[[moving_core],core_tint]]
	for layer in layers:
		for i in range(layer[0].size()):
			if i > 0 and (not config.detached_streaks or (include_energy and config.edge_shed_rate > 0)): continue
			_add_reference_plane(commands,PackedVector2Array(layer[0][i]),layer[1])
	if include_energy:
		_add_flow(commands,moving_core)
		_add_shards(commands)
	return commands

func _add_reference_plane(commands: Array, outline: PackedVector2Array, color: Color, minimum_area: float = 0.0) -> void:
	var points := PackedVector2Array()
	for j in range(outline.size()):
		var a := outline[j]
		var b := outline[(j+1)%outline.size()]
		var steps := maxi(1,int(ceil(a.distance_to(b)/24.0)))
		for k in range(steps): points.append(_map_point(a.lerp(b,k/float(steps))))
	if minimum_area > 0.0:
		var twice_area := 0.0
		for j in range(points.size()): twice_area += points[j].cross(points[(j+1)%points.size()])
		if absf(twice_area)*0.5 < minimum_area: return
	if points.size() >= 3: commands.append({"points":points,"color":color})

func _core_source() -> PackedVector2Array:
	if _core_samples.is_empty():
		var source := PackedVector2Array(Shape.CORE[0])
		for i in range(source.size()):
			var a := source[i]
			var b := source[(i+1)%source.size()]
			var count := maxi(1,int(ceil(a.distance_to(b)/8.0)))
			for j in range(count): _core_samples.append(a.lerp(b,j/float(count)))
	return _core_samples

func _core_outline() -> PackedVector2Array:
	if config.core_pulse_amplitude <= 0 and (config.flow_speed <= 0 or config.flow_strength <= 0):
		return PackedVector2Array(Shape.CORE[0])
	var points := PackedVector2Array()
	# Sample the material BEFORE deformation: long straight shortcuts across
	# animated re-entrant cuts can otherwise fold at extreme control settings.
	for point: Vector2 in _core_source():
		# Small asynchronous pressure beats travel rearward inside the unchanged shell.
		# The connected core never disappears and never strobes transparent.
		var phase := energy_age*TAU*config.core_pulse_rate+(1678.0-point.x)*0.006
		var beat := 0.56*sin(phase)+0.44*sin(phase*0.617+1.7)
		var weight := smoothstep(650.0,1450.0,point.x)
		var p := point
		p.y = 425.0+(p.y-425.0)*(1.0+config.core_pulse_amplitude*weight*beat)
		# Material-pressure fronts change the actual gold/ivory boundary, not just
		# particles laid over a frozen core. Both sides advect independently.
		var side := -1.0 if point.y < 425.0 else 1.0
		var cut := minf(absf(p.y-425.0)*0.20,_flow_cut(point.x,side))
		p.y -= side*cut
		points.append(p)
	return points

func _flow_cut(x: float, side: float) -> float:
	if config.flow_speed <= 0 or config.flow_strength <= 0: return 0.0
	var lane := 2 if side < 0 else 9
	var period := (0.83 if side < 0 else 1.07)/config.flow_speed
	var clock := energy_age+(0.23 if side < 0 else 0.61)
	var cycle := int(floor(clock/period))
	var u := fposmod(clock,period)/period
	var center := lerpf(1580.0,490.0,u)
	var length := 180.0+130.0*_hash(cycle+lane,16)
	var offset := (x-center)/length
	var pocket := maxf(0.0,1.0-absf(offset))
	# A narrow leading bite with a longer recovery, never a repeated sine edge.
	pocket = pow(pocket,1.6 if offset < 0 else 0.7)
	var envelope := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.8,1.0,u))
	return (15.0+14.0*_hash(cycle+lane,17))*pocket*envelope*config.flow_strength

func _span(outline: PackedVector2Array, x: float) -> Vector2:
	var hits: Array[float] = []
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		if x >= minf(a.x,b.x) and x < maxf(a.x,b.x):
			hits.append(lerpf(a.y,b.y,(x-a.x)/(b.x-a.x)))
	hits.sort()
	var span := Vector2(425,425)
	for i in range(0,hits.size()-1,2):
		if hits[i+1]-hits[i] > span.y-span.x: span = Vector2(hits[i],hits[i+1])
	return span

func _hash(index: int, salt: float = 0.0) -> float:
	return fposmod(sin(index*12.9898+salt*78.233)*43758.5453,1.0)

func _add_flow(commands: Array, core: PackedVector2Array) -> void:
	if config.flow_strength <= 0 or config.flow_speed <= 0: return
	# Independent cohorts, not a scrolled uniform wave or jittered static outline.
	for lane in range(5):
		var period := (0.63+lane*0.053)/config.flow_speed
		var clock := energy_age+lane*0.137
		var cycle := int(floor(clock/period))
		var age := fposmod(clock,period)
		var id := cycle*7+lane
		var life := period*(0.81+0.17*_hash(id,1))
		if age >= life: continue
		var u := age/life
		if u < 0.02: continue
		var right := lerpf(1650.0,470.0,pow(u,0.9))
		var length := (175.0+245.0*_hash(id,2))*sin(PI*pow(u,0.65))
		var left := maxf(435.0,right-length)
		if right-left < 3.0: continue
		var fraction: float = [0.22,0.70,0.43,0.82,0.14][lane]+(_hash(id,3)-0.5)*0.10
		var width := config.flow_strength*(0.075+0.035*_hash(id,4))
		var outline := PackedVector2Array()
		for side in [-1.0,1.0]:
			for j in range(13):
				var t := j/12.0 if side < 0 else 1.0-j/12.0
				if side > 0 and (j == 0 or j == 12): continue
				var x := lerpf(left,right,t)
				# A smooth conservative corridor keeps material flowing through sharp
				# core cuts instead of inheriting their abrupt vertical steps.
				var center_y := 416.0+9.0*clampf((x-430.0)/800.0,0.0,1.0)
				var half_width := 80.0*pow(clampf((x-430.0)/1000.0,0.0,1.0),1.4)*clampf((1680.0-x)/180.0,0.0,1.0)
				var span := _span(core,x)
				half_width = minf(half_width,maxf(0.1,minf(center_y-span.x,span.y-center_y)*0.88))
				var thickness := minf((right-left)/22.0,2.0*pow(t,0.8)*pow(1.0-t,0.45)*minf(width,0.17)*half_width*2.0)*smoothstep(0.0,0.14,u)
				var y: float = center_y+(fraction-0.5)*half_width*1.3+side*thickness
				outline.append(Vector2(x,y))
		var color := config.flow_color if lane < 3 else config.spark_color
		_add_reference_plane(commands,outline,color,0.002)

func _advance_energy(delta: float) -> void:
	energy_age += delta
	for i in range(_shards.size()-1,-1,-1):
		_shards[i].age += delta
		if _shards[i].age >= _shards[i].life: _shards.remove_at(i)
	if config.edge_shed_rate <= 0 or not config.detached_streaks:
		_shards.clear()
		return
	_shed_clock += delta*config.edge_shed_rate
	var births := 0
	while _shed_clock >= 1.0 and births < 12:
		_shed_clock -= 0.72+0.56*_hash(_shed_index,8)
		_emit_shard(_shed_index)
		_shed_index += 1
		births += 1
	_shed_clock = minf(_shed_clock,1.0)
	while _shards.size() > 24: _shards.pop_front()

func _emit_shard(index: int) -> void:
	var side := -1.0 if _hash(index,5) < 0.5 else 1.0
	var x := 1130.0+460.0*_hash(index,6)
	var span := _span(PackedVector2Array(Shape.SHADE[0]),x)
	var source := Vector2(x,span.x if side < 0 else span.y)
	var origin := to_global(_map_point(source))
	var normal := (to_global(_map_point(source+Vector2(0,1)))-origin).normalized()*side
	var heading := (to_global(_map_point(source+Vector2(2,0)))-origin).normalized()
	var unit := config.head_height/96.0*config.size
	var velocity := heading*(actual_speed*0.18-config.edge_speed*unit)+normal*(28.0+45.0*_hash(index,7))*unit
	_shards.append({"origin":origin,"velocity":velocity,"heading":-heading,"age":0.0,"life":config.edge_lifetime*(0.72+0.5*_hash(index,9)),"length":config.edge_length*unit*(0.6+0.65*_hash(index,10)),"width":unit*(1.3+2.3*_hash(index,11)),"color":config.spark_color if index%3 else config.body_color})

func _add_shards(commands: Array) -> void:
	if config.edge_shed_rate <= 0 or not config.detached_streaks: return
	for shard: Dictionary in _shards:
		var u: float = shard.age/shard.life
		var envelope := pow(sin(PI*u),0.7)
		if envelope < 0.04: continue
		var center: Vector2 = shard.origin+shard.velocity*shard.age
		var direction: Vector2 = shard.heading
		var normal := Vector2(-direction.y,direction.x)
		var length: float = shard.length*(0.45+0.55*envelope)
		var width: float = shard.width*envelope
		var points := PackedVector2Array([to_local(center+direction*length*0.7),to_local(center-direction*length*0.2+normal*width),to_local(center-direction*length*0.3),to_local(center-direction*length*0.2-normal*width)])
		commands.append({"points":points,"color":shard.color})

func motion_snapshot() -> Dictionary:
	return {"speed":actual_speed,"velocity":actual_velocity,"tail_scale":tail_scale,"history_count":_history.size(),"path_length":_total_distance,"active":active,"energy_age":energy_age,"shard_count":_shards.size()}
