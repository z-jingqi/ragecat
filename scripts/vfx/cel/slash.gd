extends Node2D
## Pure one-shot crescent: no sword, actor, background, damage, particles or RNG.
## Local origin is the center of the sweep. play() is automatic; seek() is manual.
signal finished
const Config = preload("res://scripts/vfx/cel/slash_config.gd")
const SEGMENTS := 64
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
		# Same-color antialias coverage, not a dark/colored outline.
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,0.8,true)

func build_commands(at_age: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0 or at_age >= config.duration(): return commands
	var t := at_age/config.duration_scale
	var sweep := clampf(t/config.sweep_seconds,0,1)
	var reveal := 0.08+0.92*(1.0-pow(1.0-sweep,2.0))
	var peak := clampf((t-config.sweep_seconds)/maxf(config.peak_seconds,0.00001),0,1)
	var decay := clampf((t-config.sweep_seconds-config.peak_seconds)/config.disappear_seconds,0,1)
	var state := {
		"start":1.0-reveal,
		"end":1.0-0.56*pow(decay,0.8),
		"width":(0.58+0.42*reveal)*pow(1.0-decay,1.15),
		"reach":0.88+0.12*reveal+config.extension*peak,
		"turn":deg_to_rad(-8.0*decay),
	}
	# Do not submit float32-degenerate invisible slivers at the final boundary.
	if config.thickness*state.width*config.size < 0.16: return commands
	_add_band(commands,state,0,config.body_color)
	_add_band(commands,state,1,config.core_color)
	if config.thickness*state.width*config.size >= 1.0:
		_add_band(commands,state,2,config.shade_color)
	return commands

func _profile(v: float) -> float:
	# One broad leading shoulder followed by one long, continuous tapered tail.
	return 4.3*pow(maxf(v,0.0),0.72)*pow(maxf(1.0-v,0.0),1.65)

func _point(v: float, fraction: float, state: Dictionary) -> Vector2:
	var u := lerpf(state.start,state.end,v)
	var angle: float = deg_to_rad(125.0+config.arc_degrees*0.5-config.arc_degrees*u)+state.turn
	var radius: float = config.length*0.5*state.reach-config.thickness*state.width*_profile(v)*fraction
	var point := Vector2(cos(angle)*radius,sin(angle)*radius*config.curvature)
	if config.reverse: point.x = -point.x
	return (point*config.size).rotated(deg_to_rad(config.direction_degrees))

func _band_point(progress: float, inner: bool, mode: int, state: Dictionary) -> Vector2:
	var v := progress
	var fraction := 1.0 if inner else 0.0
	if mode == 1:
		fraction = lerpf(0.53,0.23,v) if inner else 0.0
	elif mode == 2:
		v = lerpf(0.18,0.91,progress)
		# A single inset warm-shadow plane, pointed at both ends, never fragments.
		fraction = 0.71+(0.23*sin(PI*progress) if inner else 0.0)
	return _point(v,fraction,state)

func _add_band(commands: Array, state: Dictionary, mode: int, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(SEGMENTS+1):
		points.append(_band_point(i/float(SEGMENTS),false,mode,state))
	for i in range(SEGMENTS-1,0,-1):
		points.append(_band_point(i/float(SEGMENTS),true,mode,state))
	commands.append({"points":points,"color":color})
