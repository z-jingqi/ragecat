extends Node2D
## Ground/contact anchored, reusable one-shot. No actor, camera, damage or props.
## All layers are deterministic analytic motion, never a translated concept image.
signal finished
const Config = preload("res://scripts/vfx/cel/heavy_impact_config.gd")
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

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.8,true)

func _polygon(commands: Array, points: PackedVector2Array, color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color})

func _lobe(commands: Array, center: Vector2, radii: Vector2, phase: float, color: Color, tilt: float = 0.0) -> void:
	if minf(radii.x,radii.y) < 0.25: return
	var points := PackedVector2Array()
	# Positive polar radius guarantees a simple silhouette. Moving harmonic phases
	# make the boundary roll, instead of carrying a frozen cloud stamp outward.
	for i in range(44):
		var angle := TAU*i/44.0
		var radius := 1.0+0.075*cos(angle*5.0+phase)+0.075*cos(angle*3.0-phase*0.7)+0.025*cos(angle*8.0+phase*0.4)
		points.append(center+(Vector2.from_angle(angle)*radii*radius).rotated(tilt))
	_polygon(commands,points,color)

func _wave_arc(commands: Array, radius: float, thickness: float, start: float, end: float, color: Color) -> void:
	if thickness < 0.2: return
	thickness = minf(thickness,radius*0.72)
	var points := PackedVector2Array()
	for i in range(33):
		var u := i/32.0
		var angle := lerpf(start,end,u)
		points.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.15))
	for i in range(31,0,-1):
		var u := i/32.0
		var angle := lerpf(start,end,u)
		# Two unequal bites on the inside, while the outer pressure front stays clean.
		var torn := 1.0 if u < 0.34 else (0.52 if u < 0.51 else 0.86)
		var inside := radius-thickness*pow(sin(PI*u),0.6)*torn
		points.append(Vector2(cos(angle)*inside,sin(angle)*inside*0.15))
	_polygon(commands,points,color)

func _blade(commands: Array, tip: Vector2, axis: Vector2, length: float, width: float, color: Color) -> void:
	if length < 0.25 or width < 0.15: return
	var side := Vector2(-axis.y,axis.x)
	_polygon(commands,PackedVector2Array([tip,tip-axis*length*0.75+side*width,tip-axis*length,tip-axis*length*0.56-side*width*0.45]),color)

func _dust(commands: Array, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value+137
	var light_commands: Array = []
	for i in range(config.dust_count):
		var side := -1.0 if i%2 == 0 else 1.0
		var lane := floorf(i/2.0)/maxf(1.0,ceilf(config.dust_count/2.0)-1.0)
		var delay := rng.randf_range(0.015,0.11)
		var life := config.dust_seconds*rng.randf_range(0.78,1.0)
		var reach := (75.0+pow(lane,1.2)*170.0+rng.randf_range(-11,11))*config.dust_spread
		# Unequal, connected side plumes rather than a mirrored arch of separated balls.
		var peak := 0.58 if side < 0.0 else 0.35
		var rise := (15.0+80.0*exp(-pow((lane-peak)*3.2,2))+rng.randf_range(-18,14))*sqrt(config.intensity)*(1.28 if side < 0.0 else 0.67)
		var width := rng.randf_range(36,53)*(1.16-0.17*lane)
		var height := rng.randf_range(28,45)*(1.12-0.22*lane)
		if side < 0.0:
			var hero_billow := exp(-pow((lane-0.56)*3.2,2))
			width *= 1.0+0.2*hero_billow
			height *= 1.0+0.36*hero_billow
		var phase := rng.randf_range(-PI,PI)
		var tilt := side*rng.randf_range(0.12,0.65)
		var u := (t-delay)/life
		if u < 0.0 or u >= 1.0: continue
		var travel := 1.0-pow(1.0-u,3.0)
		var grow := smoothstep(0.0,0.17,u)
		var erode := 1.0-smoothstep(0.68,1.0,u)
		var scale_factor := grow*erode*(0.55+0.58*travel)*sqrt(config.intensity)
		if scale_factor < 0.012: continue
		var center := Vector2(side*(15.0+reach*travel),-5.0-rise*travel+15.0*u*u)
		var radii := Vector2(width,height)*scale_factor
		# Keep every rotated billow above the local ground, including its polar lobes.
		var lower_extent := Vector2(radii.x*sin(tilt),radii.y*cos(tilt)).length()*1.18
		center.y = minf(center.y,-lower_extent-0.5)
		var roll := phase+u*2.6*side
		# Just three short, low wakes. Connecting every cloud to the origin would
		# fill the negative space and turn rolling dust into a solid earth mound.
		var tail := Vector2(center.x*lerpf(0.55,0.95,smoothstep(0.72,1.0,u)),0.0)
		var wake_scale := 1.0-smoothstep(0.28,0.70,u)
		if i in [0,3,8] and radii.y > 0.5 and absf(center.x-tail.x) > 3.0 and wake_scale > 0.03:
			var wake := PackedVector2Array([tail,center+Vector2(-side*radii.x*0.25,radii.y*0.1),center+Vector2(side*radii.x*0.6,radii.y*0.30),Vector2(side*(absf(center.x)+radii.x*0.4),0.0)])
			# Retract the ground connection into the billow before late peeling;
			# otherwise surviving wakes resemble rigid pillars under airborne dust.
			for j in range(wake.size()): wake[j] = center+(wake[j]-center)*wake_scale
			_polygon(commands,wake,config.dust_shade_color)
		_lobe(commands,center,radii,roll,config.dust_shade_color,tilt)
		# Composite ALL dark wakes first, then the rolling light masses. Alternating
		# long light/dark wedges per billow would read as a sliced radial hand-fan.
		_lobe(light_commands,center+Vector2(side*radii.x*0.12,-radii.y*0.25),radii*Vector2(0.84,0.72),roll+0.45,config.dust_color,tilt-0.15*side)
		# A small late peel separates from the parent billow and shrinks away.
		if u > 0.68 and i%3 == 1:
			var peel := smoothstep(0.68,0.9,u)
			_lobe(light_commands,center+Vector2(side*radii.x*(0.8+peel),-radii.y*(0.1+peel)),radii*Vector2(0.30,0.24)*peel,roll+1.3,config.dust_color,tilt)
	commands.append_array(light_commands)

func _chips(commands: Array, t: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value+503
	for i in range(config.chip_count):
		var side := -1.0 if i%2 == 0 else 1.0
		var velocity := Vector2(side*rng.randf_range(120,290),-rng.randf_range(150,310))*sqrt(config.intensity)
		var life := rng.randf_range(0.52,1.05)
		var radius := rng.randf_range(3.8,9.0)
		var spin := rng.randf_range(-3.5,3.5)
		var phase := rng.randf_range(-PI,PI)
		if t >= life: continue
		var u := t/life
		var center := Vector2(side*8,-8)+velocity*t+Vector2(0,0.5*config.chip_gravity*t*t)
		if center.y > 4.0: continue
		var shrink := 1.0-smoothstep(0.65,1.0,u)
		if shrink < 0.025: continue
		var shape := PackedVector2Array([Vector2(-0.7,-0.45),Vector2(0.25,-1.4),Vector2(0.88,-0.15),Vector2(0.4,0.8),Vector2(-0.65,0.55)])
		var angle := phase+spin*t
		for j in range(shape.size()): shape[j] = center+(shape[j]*radius*shrink).rotated(angle)
		_polygon(commands,shape,config.chip_color)
		_polygon(commands,PackedVector2Array([shape[0],shape[1],shape[2],center]),config.dust_color)

func _flash(commands: Array, t: float) -> void:
	var end := config.flash_seconds*3.5
	if t >= end: return
	var pop := 0.35+0.65*smoothstep(0.0,0.025,t)
	var collapse := 1.0-smoothstep(config.flash_seconds,end,t)
	var sx := pop*(0.72+0.28*collapse)*config.intensity
	var sy := pop*collapse*sqrt(config.intensity)
	if sy < 0.015: return
	# Deliberately unequal crown points; the tall bent spear is the concept's hero.
	var shape := PackedVector2Array([Vector2(-155,1),Vector2(-87,-13),Vector2(-116,-44),Vector2(-63,-30),Vector2(-89,-102),Vector2(-43,-51),Vector2(-46,-142),Vector2(-18,-71),Vector2(-7,-42),Vector2(7,-105),Vector2(36,-207),Vector2(24,-97),Vector2(36,-123),Vector2(17,-54),Vector2(52,-102),Vector2(38,-37),Vector2(99,-91),Vector2(68,-27),Vector2(125,-44),Vector2(86,-10),Vector2(158,3),Vector2(37,10),Vector2(-38,8)])
	for i in range(shape.size()): shape[i] *= Vector2(sx,sy)
	_polygon(commands,shape,config.wave_color)
	var core := PackedVector2Array([Vector2(-113,0),Vector2(-48,-13),Vector2(-72,-45),Vector2(-35,-24),Vector2(-44,-82),Vector2(-13,-36),Vector2(-9,-69),Vector2(0,-39),Vector2(26,-161),Vector2(16,-55),Vector2(31,-81),Vector2(18,-26),Vector2(65,-62),Vector2(42,-17),Vector2(91,-23),Vector2(60,-4),Vector2(114,2),Vector2(20,6),Vector2(-20,5)])
	for i in range(core.size()): core[i] *= Vector2(sx,sy)
	_polygon(commands,core,config.core_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value+907
	var angles := [-2.68,-2.24,-0.57]
	for i in range(angles.size()):
		var axis := Vector2.from_angle(angles[i]+rng.randf_range(-0.10,0.10))
		var life: float = end*[0.70,1.0,0.62][i]
		if t >= life: continue
		var remaining := 1.0-t/life
		var motion := 1.0-remaining*remaining
		var length: float = [109.0,29.0,68.0][i]*remaining*config.intensity
		_blade(commands,axis*(30+motion*(130+i*23))*sqrt(config.intensity),axis,length,[6.0,2.0,4.0][i]*remaining,config.wave_color if i != 1 else config.core_color)

func build_commands(at_age: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0 or at_age >= config.duration(): return commands
	var t := at_age/config.duration_scale
	if config.show_dust: _dust(commands,t)
	if config.show_chips: _chips(commands,t)
	if config.show_shockwave and t >= 0.015 and t < config.shockwave_seconds+0.015:
		var u := (t-0.015)/config.shockwave_seconds
		var radius := lerpf(28.0,config.shockwave_radius,1.0-pow(1.0-u,2.8))
		var thickness := 78.0*pow(1.0-u,1.05)*sqrt(config.intensity)
		# Only the two lateral pressure fronts survive; the broad intentional gaps
		# prevent the ground slam from reading as a perfect orbit or magic circle.
		_wave_arc(commands,radius,thickness,2.52,3.88,config.wave_color)
		_wave_arc(commands,radius*0.94,thickness*0.82,-0.60,0.71,config.wave_color)
		_wave_arc(commands,radius*0.99,thickness*0.25,2.73,3.30,config.core_color)
	if config.show_flash: _flash(commands,t)
	return commands
