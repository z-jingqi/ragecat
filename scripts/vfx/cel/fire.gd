extends Node2D
## Independent continuous cel fire. Local origin is the broad attached base.
## The host owns placement and optional sustained duration; no actor or damage.
signal finished
const Config = preload("res://scripts/vfx/cel/fire_config.gd")
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
	if not holding and age >= (config.ignition_seconds+config.sustain_seconds)*config.duration_scale: return
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
	var automatic := config.ignition_seconds+config.sustain_seconds
	if override == INF: return INF
	if override != -INF:
		if not is_finite(override) or (override < 0.0 and override != -1.0): return NAN
		if override >= 0.0: return override/config.duration_scale if holding else minf(automatic,override/config.duration_scale)
		return automatic
	if release_at >= 0.0: return release_at/config.duration_scale if holding else minf(automatic,release_at/config.duration_scale)
	return INF if holding else automatic

func get_end_time() -> float:
	var start := _release_time()
	return INF if start == INF else (start+config.release_seconds+config.ember_seconds+0.04)*config.duration_scale

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	var end := get_end_time()
	age = minf(age+maxf(delta,0.0),end)
	queue_redraw()
	if age >= end:
		playing = false
		finished.emit()

func _envelope(t: float, released: float) -> float:
	if t < 0.0: return 0.0
	# Freeze ignition at an early release; it must never grow after being released.
	var growth := smoothstep(0.0,config.ignition_seconds,minf(t,released))
	if released == INF or t < released: return growth
	return growth*(1.0-smoothstep(released,released+config.release_seconds,t))

func _phase(i: int) -> float:
	return [0.8,2.5,4.4][i]+float(posmod(config.seed_value,997))*0.013

func _period(i: int) -> float:
	return [0.94,0.82,1.13][i]/maxf(config.flow_speed,0.001)

func _first_birth(i: int) -> float:
	return [0.62,0.78,0.50][i]/maxf(config.flow_speed,0.001)

func _tip_end(i: int, t: float) -> float:
	if config.flow_speed <= 0.0 or t < _first_birth(i): return 1.0
	var since := fposmod(t-_first_birth(i),_period(i))
	return lerpf(0.75,1.0,smoothstep(0.0,0.18/maxf(config.flow_speed,0.001),since))

func _profile(i: int, s: float, t: float, envelope: float, layer: int) -> Vector2:
	# Return (x, half-width); height is shared so every inner layer stays contained.
	var phase := _phase(i)
	var motion := t*config.flow_speed
	var width_scale := sqrt(envelope)*sqrt(config.intensity)
	var base_x: float = [-0.28,0.0,0.31][i]*config.base_width*sqrt(envelope)
	var curve: float = [18.0,46.0,-18.0][i]*config.curl*pow(s,2.7)*config.height/220.0
	var pulse := s*8.8-motion*7.2+phase
	var center := base_x*(1.0-0.10*s)+curve+sin(pulse)*s*config.base_width*0.052*sqrt(config.intensity)
	var width: float = config.base_width*[0.20,0.27,0.17][i]*pow(maxf(0.0,1.0-s),0.73)*width_scale
	width *= 0.92+0.16*sin(pulse)+0.065*sin(s*17.0-motion*10.3+phase)
	if config.flow_speed > 0.0:
		var cycle := fposmod(t-_first_birth(i),_period(i))/_period(i)
		var pinch := 0.35+0.51*cycle
		width *= 1.0-0.63*exp(-pow((s-pinch)/0.085,2.0))*smoothstep(0.42,0.95,cycle)
	if layer >= 1:
		center += width*0.13*sin(s*12.3-motion*8.7+phase+0.7)
		width *= 0.77*(0.94+0.06*sin(s*9.4-motion*6.3+phase))
	if layer >= 2:
		center += width*0.20*sin(s*10.7-motion*10.1+phase+1.3)
		width *= 0.46*(0.86+0.14*sin(s*15.1-motion*12.4+phase))
	return Vector2(center,width)

func _height(i: int, t: float, envelope: float) -> float:
	return config.height*[0.63,1.0,0.49][i]*envelope*sqrt(config.intensity)*(0.96+0.04*sin(t*config.flow_speed*4.6+_phase(i)))

func _polygon(commands: Array, points: PackedVector2Array, color: Color, layer: String) -> void:
	if points.size() < 3: return
	var area := 0.0
	for i in range(points.size()): area += points[i].cross(points[(i+1)%points.size()])
	if absf(area) < 0.01: return
	var transformed := PackedVector2Array()
	for point in points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color,"layer":layer})

func _tongue(commands: Array, i: int, t: float, envelope: float, layer: int, color: Color, tag: String, start: float = 0.0, end: float = -1.0, offset: Vector2 = Vector2.ZERO, shrink: float = 1.0) -> void:
	if envelope < 0.005 or shrink < 0.025: return
	if end < 0.0: end = _tip_end(i,t)*[1.0,0.94,0.81][layer]
	if end-start < 0.01: return
	var h := _height(i,t,envelope)
	if h < 0.4: return
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var anchor_s := (start+end)*0.5 if start > 0.0 else 0.0
	var anchor_profile := _profile(i,anchor_s,t,envelope,layer)
	var anchor := Vector2(anchor_profile.x,-h*anchor_s)
	for j in range(35):
		var u := j/34.0
		var s := lerpf(start,end,u)
		var profile := _profile(i,s,t,envelope,layer)
		var taper := smoothstep(0.0,0.18,u) if start > 0.0 else 1.0
		taper *= 1.0-smoothstep(0.81,1.0,u)
		var width := profile.y*taper*(1.2 if start > 0.0 else 1.0)
		var center := Vector2(profile.x,-h*s)
		left.append(anchor+(center-Vector2(width,0)-anchor)*shrink+offset)
		if j < 34 and (start <= 0.0 or j > 0): right.append(anchor+(center+Vector2(width,0)-anchor)*shrink+offset)
	for j in range(right.size()-1,-1,-1): left.append(right[j])
	_polygon(commands,left,color,tag)

func _base(commands: Array, t: float, envelope: float, layer: int, color: Color, tag: String) -> void:
	var width: float = config.base_width*sqrt(envelope)*[0.62,0.52,0.35][layer]*sqrt(config.intensity)
	var height: float = config.height*envelope*[0.075,0.057,0.038][layer]
	if width < 0.2 or height < 0.2: return
	var phase := t*config.flow_speed*8.0+_phase(1)
	var points := PackedVector2Array([Vector2(-width,0),Vector2(-width*0.57,-height*(0.5+0.13*sin(phase))),Vector2(-width*0.23,-height*0.9),Vector2(width*0.15,-height*(1.0+0.16*cos(phase))),Vector2(width*0.60,-height*0.45),Vector2(width,0),Vector2(width*0.31,height*0.14),Vector2(-width*0.28,height*0.08)])
	_polygon(commands,points,color,tag)

func _attached(commands: Array, t: float, released: float) -> void:
	var envelope := _envelope(t,released)
	if envelope < 0.005: return
	if config.show_body:
		_base(commands,t,envelope,0,config.rim_color,"rim")
		for i in range(3): _tongue(commands,i,t,envelope,0,config.rim_color,"rim")
		_base(commands,t,envelope,1,config.body_color,"body")
		for i in range(3): _tongue(commands,i,t,envelope,1,config.body_color,"body")
	if config.show_channels:
		_base(commands,t,envelope,2,config.channel_color,"channel")
		for i in range(3): _tongue(commands,i,t,envelope,2,config.channel_color,"channel")
	if config.show_core:
		# A small ivory pocket at the base, not a white pillar filling the flame.
		_core(commands,t,envelope)

func _core(commands: Array, t: float, envelope: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var height := config.height*0.22*envelope*sqrt(config.intensity)
	var phase := t*config.flow_speed*9.1+_phase(1)
	for j in range(29):
		var s := j/28.0
		var width := config.base_width*0.095*sqrt(envelope)*sqrt(config.intensity)*pow(1.0-s,0.92)*(0.93+0.07*sin(s*9.0-phase))
		var center := Vector2((8.0*s*s+3.5*sin(s*6.0-phase)*s)*config.curl*sqrt(envelope)*sqrt(config.intensity),-height*s)
		left.append(center-Vector2(width,0))
		if j < 28: right.append(center+Vector2(width*(0.86+0.1*s),0))
	for j in range(right.size()-1,-1,-1): left.append(right[j])
	_polygon(commands,left,config.core_color,"core")

func _detached(commands: Array, t: float, released: float) -> void:
	if not config.show_detached or config.flow_speed <= 0.0: return
	var life := config.ember_seconds*0.78
	for i in range(3):
		var period := _period(i)
		var first := _first_birth(i)
		var begin := maxi(0,int(ceil((t-life-first)/period)))
		var finish := int(floor((minf(t,released)-first)/period))
		# Only active births are inspected, even after hours of held sustain.
		for birth_index in range(begin,finish+1):
			var birth := first+birth_index*period
			var dt := t-birth
			if dt < 0.0 or dt >= life: continue
			var envelope := _envelope(birth,released)
			var u := dt/life
			var shrink := 1.0-smoothstep(0.16,1.0,u)
			var offset := Vector2((12.0+i*9.0)*config.curl*dt,-(80.0+30.0*i)*dt-65.0*dt*dt)*sqrt(config.intensity)
			# Continue deforming the pinched tip after separation; it is not a rigid
			# particle stamp. Different inner-layer phase speeds retain internal flow.
			var flow_time := birth+dt*0.72
			_tongue(commands,i,flow_time,envelope,0,config.rim_color,"detached_rim",0.75,1.0,offset,shrink)
			_tongue(commands,i,flow_time,envelope,1,config.body_color,"detached_body",0.77,0.97,offset,shrink)
			if config.show_channels: _tongue(commands,i,flow_time,envelope,2,config.channel_color,"detached_channel",0.79,0.94,offset,shrink)

func _embers(commands: Array, t: float, released: float) -> void:
	if not config.show_embers or config.ember_rate <= 0.0: return
	var begin := maxi(0,int(ceil((t-config.ember_seconds)*config.ember_rate)))
	var finish := int(floor(minf(t,released)*config.ember_rate))
	for birth_index in range(begin,finish+1):
		var birth := birth_index/config.ember_rate
		var dt := t-birth
		if dt < 0.0 or dt >= config.ember_seconds: continue
		var envelope := _envelope(birth,released)
		if envelope < 0.12: continue
		var rng := RandomNumberGenerator.new()
		rng.seed = config.seed_value+birth_index*104729+701
		var tongue := rng.randi_range(0,2)
		var s := rng.randf_range(0.45,0.88)
		var profile := _profile(tongue,s,birth,envelope,0)
		var source := Vector2(profile.x,-_height(tongue,birth,envelope)*s)
		var vx := rng.randf_range(-25.0,45.0)*config.curl
		var vy := rng.randf_range(90.0,175.0)*sqrt(config.intensity)
		var u := dt/config.ember_seconds
		var erosion := 1.0-smoothstep(0.35,1.0,u)
		var length := rng.randf_range(4.0,10.0)*erosion
		var width := rng.randf_range(1.3,2.6)*erosion
		if width < 0.10 or length < 0.20: continue
		var center := source+Vector2(vx*dt,-vy*dt-70.0*dt*dt)
		var axis := Vector2(vx,-vy-140.0*dt).normalized()
		var side := Vector2(-axis.y,axis.x)
		_polygon(commands,PackedVector2Array([center+axis*length,center-axis*length*0.10+side*width,center-axis*length*0.65,center-axis*length*0.05-side*width*0.55]),config.ember_color if birth_index%3 != 0 else config.rim_color,"ember")

func build_commands(at_age: float = -INF, released_at: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0: return commands
	var released := _release_time(released_at)
	if is_nan(released): return commands
	var t := at_age/config.duration_scale
	if t >= released+config.release_seconds+config.ember_seconds+0.04: return commands
	_attached(commands,t,released)
	_detached(commands,t,released)
	_embers(commands,t,released)
	return commands

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.7,true)
