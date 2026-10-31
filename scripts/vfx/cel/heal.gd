extends Node2D
## Original smooth cel geometry: flowing leaves / unfolding glyphs and ascension.
## The origin is the visual source at the feet; there is no gameplay attachment.
signal finished
const Config = preload("res://scripts/vfx/cel/heal_config.gd")
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
	age = seconds if is_finite(seconds) and seconds >= 0 else -1.0
	playing = false
	queue_redraw()

func _process(delta: float) -> void:
	if not playing or not is_finite(delta): return
	age = minf(age+maxf(delta,0),config.duration())
	queue_redraw()
	if age >= config.duration():
		playing = false
		finished.emit()

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points,command.color)
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.55,true)

func _add(commands: Array, points: PackedVector2Array, color: Color, layer: String, source: int) -> void:
	if points.size() < 3: return
	var area := 0.0
	for i in range(points.size()): area += points[i].cross(points[(i+1)%points.size()])
	# Only genuinely subpixel births/deaths are omitted, not invalid silhouettes.
	if absf(area) < 0.005: return
	var transformed := PackedVector2Array()
	for point in points: transformed.append((point*config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color,"layer":layer,"source_id":source})

func _phase(t: float, start: float, span: float) -> float:
	return clampf((t-start)/maxf(span,0.001),0,1)

func _envelope(t: float, start: float, grow: float, end: float, retract: float) -> float:
	return smoothstep(0,1,_phase(t,start,grow))*(1.0-smoothstep(0,1,_phase(t,end,retract)))

func _palette() -> Array[Color]:
	if config.mode == Config.Mode.HEAL:
		return [config.heal_shadow_color,config.heal_body_color,config.heal_highlight_color,config.heal_glyph_color]
	return [config.level_shadow_color,config.level_body_color,config.level_highlight_color,config.level_glyph_color]

func _release_time() -> float:
	return config.gather_seconds+config.bloom_seconds+config.sustain_seconds

func _random(source: int) -> float:
	var rng := RandomNumberGenerator.new()
	# Mask first: the full signed int range remains safe without seed overflow.
	rng.seed = (config.seed_value & 0x7fffffff)+source*137
	return rng.randf()

func _foot_arcs(commands: Array, t: float, colors: Array[Color]) -> void:
	if not config.show_arcs: return
	var live := _envelope(t,0.0,config.gather_seconds,_release_time()-config.sustain_seconds*0.3,config.release_seconds*0.75)
	if live < 0.002: return
	var radius := config.spread*(0.60+0.40*smoothstep(0,1,_phase(t,0,config.gather_seconds)))
	var phase := t*config.flow_speed*0.70
	for i in range(4):
		var start := i*TAU/4.0+0.12+phase
		var arc := 0.85+0.17*sin(t*2.0+i)
		var points := PackedVector2Array()
		var inner := PackedVector2Array()
		for j in range(25):
			var u := j/24.0
			var angle := start+u*arc
			var width := (5.0+2.5*sqrt(config.intensity))*sin(PI*u)*live
			points.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.19)-Vector2(cos(angle)*width,sin(angle)*width*0.28))
			if j > 0 and j < 24: inner.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.19)+Vector2(cos(angle)*width,sin(angle)*width*0.28))
		for j in range(inner.size()-1,-1,-1): points.append(inner[j])
		_add(commands,points,colors[2] if i%2 == 0 else colors[1],"arcs",i)

func _ribbon_center(u: float, index: int, t: float) -> Vector2:
	var level := config.mode == Config.Mode.LEVEL_UP
	var flow := sin(t*config.flow_speed*2.6+index*1.8+u*3.4)
	if level:
		var side := -1.0 if index == 0 else 1.0
		return Vector2(side*config.spread*(0.28+0.52*sin(u*PI*0.86)+0.10*config.curl*sin(u*TAU))+flow*config.spread*0.025*sin(PI*u),-config.height*0.62*u)
	var h: float = [0.98,0.72,0.57][index]
	var side: float = [1.0,-1.0,1.0][index]
	var root: float = [-0.08,-0.13,0.14][index]
	var x := config.spread*(root+side*(0.24*u+0.43*config.curl*sin(u*TAU-0.20)*sin(PI*u)))
	x += config.spread*0.06*flow*sin(PI*u)
	return Vector2(x,-config.height*h*u)

func _ribbon_band(commands: Array, t: float, index: int, start: float, end: float, width: float, left: float, right: float, color: Color, layer: String) -> void:
	if end-start < 0.003 or width < 0.035: return
	var points := PackedVector2Array()
	var opposite := PackedVector2Array()
	# Strictly monotone Y and horizontal cross sections make even maximum curl
	# simple polygons. All source color planes share these exact cross sections.
	for j in range(35):
		var fraction := j/34.0
		var u := lerpf(start,end,fraction)
		var center := _ribbon_center(u,index,t)
		var taper := pow(maxf(sin(PI*fraction),0),0.85)
		var section := width*taper*(0.75+0.25*sin(PI*u))
		points.append(center+Vector2(left*section,0))
		if j > 0 and j < 34: opposite.append(center+Vector2(right*section,0))
	for j in range(opposite.size()-1,-1,-1): points.append(opposite[j])
	_add(commands,points,color,layer,100+index)

func _ribbons(commands: Array, t: float, colors: Array[Color]) -> void:
	var count := 2 if config.mode == Config.Mode.LEVEL_UP else 3
	for i in range(count):
		var delay := config.gather_seconds*0.30+i*config.bloom_seconds*0.10
		var head := smoothstep(0,1,_phase(t,delay,config.bloom_seconds*1.15))
		var tail := smoothstep(0,1,_phase(t,_release_time()-config.release_seconds*0.12+i*0.025,config.release_seconds*0.88))
		var width := config.ribbon_width*sqrt(config.intensity)*(1.0-0.78*tail)
		if config.mode == Config.Mode.HEAL and i > 0: width *= 0.83
		if config.show_ribbons:
			_ribbon_band(commands,t,i,tail,head,width,-1,1,colors[0],"ribbon_shadow")
			_ribbon_band(commands,t,i,tail,head,width,-0.72,0.85,colors[1],"ribbon_body")
		if config.show_highlights:
			_ribbon_band(commands,t,i,tail,head,width,-0.67,0.10+0.21*sin(t*config.flow_speed*2+i),colors[2],"ribbon_highlight")

func _diamond(commands: Array, at: Vector2, half: Vector2, color: Color, layer: String, source: int) -> void:
	_add(commands,PackedVector2Array([at+Vector2(0,-half.y),at+Vector2(half.x,0),at+Vector2(0,half.y),at+Vector2(-half.x,0)]),color,layer,source)

func _glyphs(commands: Array, t: float, colors: Array[Color]) -> void:
	for i in range(config.glyph_count):
		var delay := config.gather_seconds+config.bloom_seconds*(0.10+0.09*i)
		var die := _release_time()+config.release_seconds*(0.02+0.025*i)
		var local := _phase(t,delay,config.bloom_seconds*0.85)
		var life := _envelope(t,delay,config.bloom_seconds*0.40,die,config.release_seconds*0.65)
		if life < 0.002: continue
		var xratio: float = [-0.60,0.57,-0.05,-0.19,0.31,-0.81,0.83][i]
		var hratio: float = [0.69,0.49,0.91,0.35,0.20,0.43,0.79][i]
		var center := Vector2(config.spread*xratio,-config.height*hratio-config.height*0.085*local*config.rise_speed)
		center.x += (2*_random(330+i)-1)*config.spread*0.025
		var size := config.glyph_size*(0.77+0.23*_random(401+i))*sqrt(config.intensity)
		if config.show_streaks:
			var tail := (14+34*(1-local))*life
			_diamond(commands,center+Vector2(0,tail*0.70),Vector2(size*0.085*life,tail),colors[1],"streaks",200+i)
		if not config.show_glyphs: continue
		var w := size*0.27*life
		var arm_l := w+size*0.74*_envelope(t,delay+0.025,config.bloom_seconds*0.45,die,config.release_seconds*0.43)
		var arm_r := w+size*0.74*_envelope(t,delay+0.065,config.bloom_seconds*0.42,die+0.035,config.release_seconds*0.45)
		var arm_top := w+size*0.78*_envelope(t,delay,config.bloom_seconds*0.23,die+0.045,config.release_seconds*0.56)
		var arm_bottom := w+size*0.66*_envelope(t,delay+0.035,config.bloom_seconds*0.32,die,config.release_seconds*0.52)
		var points := PackedVector2Array([Vector2(-w,-arm_top),Vector2(w,-arm_top),Vector2(w,-w),Vector2(arm_r,-w),Vector2(arm_r,w),Vector2(w,w),Vector2(w,arm_bottom),Vector2(-w,arm_bottom),Vector2(-w,w),Vector2(-arm_l,w),Vector2(-arm_l,-w),Vector2(-w,-w)])
		for j in range(points.size()): points[j] += center
		_add(commands,points,colors[3],"glyphs",200+i)

func _chevrons(commands: Array, t: float, colors: Array[Color]) -> void:
	if not config.show_chevrons: return
	for i in range(2):
		var delay := config.gather_seconds+config.bloom_seconds*(0.18+0.13*i)
		var unfold := smoothstep(0,1,_phase(t,delay,config.bloom_seconds*0.70))
		var withdraw := smoothstep(0,1,_phase(t,_release_time()+i*0.045,config.release_seconds*0.66))
		var live := unfold*(1-withdraw)
		if live < 0.003: continue
		var center := Vector2(0,-config.height*(0.43+i*0.20)-config.height*0.10*withdraw*config.rise_speed)
		var reach := config.spread*(0.54+0.13*i)*(0.08+0.92*unfold)*(1-withdraw*0.70)
		var drop := config.height*(0.12+0.025*i)*(0.75+0.25*unfold)
		var thick := config.glyph_size*1.0*sqrt(config.intensity)*live
		# Each wing unfolds about the same central apex; the highlighted face
		# shares the apex and wing ends, rather than rotating about its own center.
		var full := PackedVector2Array([Vector2(0,-thick),Vector2(reach,drop),Vector2(reach*0.70,drop-thick*0.08),Vector2(0,thick*0.35),Vector2(-reach*0.70,drop-thick*0.08),Vector2(-reach,drop)])
		for j in range(full.size()): full[j] += center
		_add(commands,full,colors[0],"chevron_shadow",400+i)
		for side in [-1.0,1.0]:
			var wing := PackedVector2Array([center+Vector2(0,-thick),center+Vector2(side*reach,drop),center+Vector2(0,thick*0.35)])
			_add(commands,wing,colors[1],"chevron_body",400+i)
			if config.show_highlights:
				var facet := PackedVector2Array([wing[0],wing[0].lerp(wing[1],0.74),wing[2].lerp(wing[1],0.36),wing[2]])
				_add(commands,facet,colors[2] if side < 0 else colors[1].lerp(colors[2],0.45),"chevron_highlight",400+i)

func _star(commands: Array, t: float, colors: Array[Color]) -> void:
	if not config.show_star: return
	var delay := config.gather_seconds+config.bloom_seconds*0.50
	var end := _release_time()+config.release_seconds*0.10
	var live := _envelope(t,delay,config.bloom_seconds*0.45,end,config.release_seconds*0.75)
	if live < 0.002: return
	var center := Vector2(0,-config.height*(0.91+0.075*_phase(t,delay,config.bloom_seconds+config.sustain_seconds)*config.rise_speed))
	var rays := PackedVector2Array()
	for i in range(4):
		var extension := _envelope(t,delay+i*0.023,config.bloom_seconds*(0.44+0.025*i),end+i*0.016,config.release_seconds*(0.62-i*0.035))
		var angle := -PI/2+i*PI/2
		var core := config.glyph_size*0.27*live
		var reach := core+config.glyph_size*(2.1 if i%2 == 0 else 1.75)*sqrt(config.intensity)*extension
		rays.append(center+Vector2.from_angle(angle)*reach)
		rays.append(center+Vector2.from_angle(angle+PI/4)*core)
	_add(commands,rays,colors[3],"star",500)

func _level_streaks(commands: Array, t: float, colors: Array[Color]) -> void:
	if not config.show_streaks: return
	for i in range(7):
		var delay := config.gather_seconds*0.50+i*config.bloom_seconds*0.045
		var live := _envelope(t,delay,config.bloom_seconds*0.75,_release_time()+config.release_seconds*0.03*i,config.release_seconds*0.65)
		if live < 0.003: continue
		var x := (i-3)*config.spread*0.24
		var h := config.height*(0.35+0.45*_random(600+i))
		var front := smoothstep(0,1,_phase(t,delay,config.bloom_seconds*1.4))
		var center := Vector2(x,-h*front*0.60-config.height*0.09*_phase(t,_release_time(),config.release_seconds)*config.rise_speed)
		_diamond(commands,center,Vector2((1.2+1.2*_random(650+i))*live,h*front*0.50*live),colors[2] if i%2 else colors[1],"streaks",600+i)

func _motes(commands: Array, t: float, colors: Array[Color]) -> void:
	if not config.show_motes: return
	for i in range(8):
		var delay := config.gather_seconds*0.55+i*config.bloom_seconds*0.065
		var live := _envelope(t,delay,config.bloom_seconds*0.65,_release_time()+config.release_seconds*0.02*i,config.release_seconds*0.65)
		if live < 0.003: continue
		var local := _phase(t,delay,config.bloom_seconds+config.sustain_seconds+config.release_seconds)
		var side := -1.0 if i%2 == 0 else 1.0
		var center := Vector2(side*config.spread*(0.45+0.60*_random(700+i)), -config.height*(0.12+0.69*_random(750+i)+0.12*local*config.rise_speed))
		var width := (2.8+2*_random(800+i))*live*sqrt(config.intensity)
		var half := Vector2(width,width*(1.6+0.5*sin(t*config.flow_speed*3+i)))
		_diamond(commands,center,half,colors[1] if i%3 else colors[3],"motes",700+i)

func build_commands(at_age: float = -INF) -> Array:
	var t := age if at_age == -INF else at_age
	var commands: Array = []
	if not is_finite(t) or t <= 0 or t >= config.duration(): return commands
	t /= config.duration_scale
	var colors := _palette()
	_foot_arcs(commands,t,colors)
	if config.mode == Config.Mode.LEVEL_UP: _level_streaks(commands,t,colors)
	_ribbons(commands,t,colors)
	if config.mode == Config.Mode.HEAL: _glyphs(commands,t,colors)
	else:
		_chevrons(commands,t,colors)
		_star(commands,t,colors)
	_motes(commands,t,colors)
	return commands
