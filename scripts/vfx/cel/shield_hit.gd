extends Node2D
## Reusable one-shot, starting at contact (age 0). No arrow, shield or background.
## play() advances automatically; seek(seconds) is deterministic/manual and stops playback.
signal finished
const Config = preload("res://scripts/vfx/cel/shield_hit_config.gd")
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
	if not playing: return
	age = minf(age + maxf(delta,0.0), config.duration())
	queue_redraw()
	if age >= config.duration():
		playing = false
		finished.emit()

func _draw() -> void:
	for command in build_commands():
		draw_colored_polygon(command.points, command.color)
		# Same-color coverage edge: smooth Compatibility-renderer silhouettes, not ink.
		var edge: PackedVector2Array = command.points.duplicate()
		edge.append(edge[0])
		draw_polyline(edge,command.color,1.0,true)

func _polygon(commands: Array, points: PackedVector2Array, color: Color) -> void:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append((point * config.size).rotated(deg_to_rad(config.direction_degrees)))
	commands.append({"points":transformed,"color":color})

func _blade(commands: Array, tip: Vector2, axis: Vector2, length: float, width: float, color: Color) -> void:
	if length < 0.1 or width < 0.05: return
	var side := Vector2(-axis.y,axis.x)
	_polygon(commands,PackedVector2Array([tip,tip-axis*length*0.66+side*width,tip-axis*length,tip-axis*length*0.55-side*width*0.38]),color)

func build_commands(at_age: float = -INF) -> Array:
	var commands: Array = []
	if at_age == -INF: at_age = age
	if not is_finite(at_age) or at_age < 0.0 or at_age >= config.duration(): return commands
	var t := at_age / config.duration_scale
	# A partial pressure crescent, never a full circular explosion/ring.
	if config.show_arc and t >= 0.025 and t < 0.22:
		var u := (t-0.025)/0.195
		var radius := 19.0 + 62.0 * (1.0-pow(1.0-u,2))
		var thickness := 7.0 * pow(1.0-u,1.4)
		var arc := PackedVector2Array()
		for i in range(25):
			var v := i/24.0
			var angle := lerpf(-1.19,1.13,v)
			arc.append(Vector2(-28,0)+Vector2(-cos(angle)*0.6,sin(angle))*radius)
		for i in range(23,0,-1):
			var v := i/24.0
			var angle := lerpf(-1.19,1.13,v)
			var r := radius-thickness*sin(PI*v)
			arc.append(Vector2(-28,0)+Vector2(-cos(angle)*0.6,sin(angle))*r)
		# Float32 inner/outer contours collapse at the endpoint; omit invisible slivers.
		if thickness >= 0.05: _polygon(commands,arc,config.arc_color)
	# Seeded asymmetric launch pattern, no per-frame random values or pixel snapping.
	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value
	var angles := [-50.0,17.0,141.0,-135.0,59.0,-100.0,172.0,157.0,-126.0,119.0,-79.0,85.0]
	for i in range(config.spark_count):
		var axis := Vector2.from_angle(deg_to_rad(angles[i]*config.scatter+rng.randf_range(-6,6)))
		var life := config.spark_seconds * rng.randf_range(0.7,1.0)
		var reach := rng.randf_range(140,196) * config.travel * (1.5 if i < 2 else 1.0)
		var length := rng.randf_range(64,96) * config.spark_length * (1.45 if i < 2 else (1.0 if i == 2 else 0.57))
		var width := rng.randf_range(5.0,9.0) * (1.0 if i < 3 else 0.55)
		if t >= life: continue
		var u := t/life
		var distance := 34.0+reach*(1.0-pow(1.0-u,2.6))
		var tip := axis*distance+Vector2(0,24.0*u*u)
		var taper := pow(1.0-u,0.75)
		_blade(commands,tip,axis,length*taper,width*taper,config.body_color if i%3 != 2 else config.shade_color)
		if i < 3:
			_blade(commands,tip-axis*2.0,axis,length*taper*0.58,width*taper*0.35,config.core_color)
	# Hero silhouette: a handful of intentional unequal rays, not a noisy starburst.
	var core_end := config.flash_seconds * 2.4
	if t < core_end:
		var pop := 0.62+0.38*minf(t/0.016,1.0)
		var shrink := 1.0 if t < config.flash_seconds else pow(1.0-(t-config.flash_seconds)/(core_end-config.flash_seconds),0.7)
		var s := pop*shrink
		var points := PackedVector2Array([Vector2(28,0),Vector2(8,9),Vector2(-9,57),Vector2(-18,15),Vector2(-66,39),Vector2(-30,5),Vector2(-104,-13),Vector2(-28,-17),Vector2(-41,-73),Vector2(-6,-21),Vector2(14,-43),Vector2(12,-12)])
		for i in range(points.size()): points[i] *= s
		_polygon(commands,points,config.body_color)
		var shade := PackedVector2Array([Vector2(-66,39),Vector2(-18,15),Vector2(-9,57),Vector2(-11,10),Vector2(-30,5)])
		for i in range(shade.size()): shade[i] *= s
		_polygon(commands,shade,config.shade_color)
		var core := PackedVector2Array([Vector2(20,-1),Vector2(1,7),Vector2(-8,34),Vector2(-12,8),Vector2(-49,26),Vector2(-22,0),Vector2(-78,-10),Vector2(-18,-11),Vector2(-32,-55),Vector2(-3,-13),Vector2(9,-28),Vector2(7,-7)])
		for i in range(core.size()): core[i] *= s
		_polygon(commands,core,config.core_color)
	return commands
