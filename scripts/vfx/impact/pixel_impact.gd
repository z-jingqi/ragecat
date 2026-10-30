extends Node2D
## Original low-resolution pixel renderer. No imported VFX or gameplay dependency.
var behavior: RefCounted
var time := 0.0
var bright := false
const Demo = preload("res://scripts/vfx_lab/impact/pixel_impact_demo.gd")
var demo := Demo.new()
var show_demo := false
var _scaling_effect := false
var hit: Vector2:
	get: return behavior.config.hit_position if behavior != null else Vector2(215,79)
	set(value):
		if behavior != null: behavior.config.hit_position = value

var commands: Array = []
var offset := Vector2.ZERO

func build_commands() -> Array:
	commands = []
	offset = Vector2.ZERO
	if behavior == null: return commands
	var state: Dictionary = behavior.sample(time)
	var age: float = state.age
	if show_demo:
		demo.background(self)
		demo.target(self,state)
	_scaling_effect = true
	# Smoke is chunky palette clusters, not blurred circles.
	if age > 0.03 and age < behavior.config.smoke_seconds and behavior.config.smoke_amount > 0.0:
		for i in range(int(round(7*behavior.config.smoke_amount))):
			var p := hit + Vector2(-7 - i * 2 - age * (12+i*3), -age * 24 + sin(i*2.4)*10).rotated(behavior.direction.angle())
			var s := maxi(1, int((3 + age*5) * state.smoke))
			rect(Rect2(p.round(), Vector2(s*2,s)), Color("707c7d") if i%2==0 else Color("4a5c65"))
			rect(Rect2(p.round()+Vector2(s/2,-s/2),Vector2(s,s*2)),Color("707c7d") if i%2==0 else Color("4a5c65"))
	_scaling_effect = false
	if show_demo: demo.arrow(self,state)
	_scaling_effect = true
	# Directional burst: strong silhouette, 2-3 hot frames, then fragments.
	if state.flash > 0.0:
		var f: float = state.flash
		var radius := 7.0 + 13.0*f
		var points: Array[Vector2] = []
		for i in range(16):
			var a := i * TAU/16.0
			var r := radius if i%2==0 else radius*0.28
			points.append((hit + Vector2(cos(a)*r, sin(a)*r*0.8)).round())
		poly(points, Color("f8bd4d"))
		rect(Rect2(hit-Vector2(3,5),Vector2(6,10)),Color("fff5cf"))
		rect(Rect2(hit-Vector2(7,2),Vector2(14,4)),Color("fff5cf"))
	for i in range(behavior.config.spark_count):
		var spark: Dictionary = behavior.spark(i,age)
		if not spark.alive: continue
		var p: Vector2 = hit + spark.position
		var v: Vector2 = spark.velocity
		var tail: Vector2 = p-v.normalized()*lerpf(2,9,spark.life)
		var color := Color("ffedaf") if spark.life > 0.7 else (Color("f9b54a") if spark.life > 0.3 else Color("b86335"))
		line(tail.round(),p.round(),color,2 if i%4==0 else 1)
		if i%3==0: rect(Rect2(p.round(),Vector2(2,2)),Color("fff4ca"))

	_scaling_effect = false
	return commands

func _point(point: Vector2) -> Vector2:
	if not _scaling_effect or behavior.config.effect_scale == 1.0: return point
	return (hit + (point-hit)*behavior.config.effect_scale).round()

func _size(value: float) -> float:
	return value*behavior.config.effect_scale if _scaling_effect else value

func poly(points: Array, color: Color) -> void:
	var coordinates: Array = []
	for point in points:
		var p := _point(point)+offset
		coordinates.append([p.x,p.y])
	commands.append({"type":"polygon", "points":coordinates, "color":color.to_html()})

func rect(area: Rect2, color: Color) -> void:
	var p := _point(area.position)+offset
	commands.append({"type":"rect", "rect":[p.x,p.y,_size(area.size.x),_size(area.size.y)],"color":color.to_html()})

func line(start: Vector2, end: Vector2, color: Color, width: float = 1.0) -> void:
	var a := _point(start)+offset
	var b := _point(end)+offset
	commands.append({"type":"line", "points":[[a.x,a.y],[b.x,b.y]],"color":color.to_html(),"width":_size(width)})

func set_offset(translation: Vector2) -> void:
	offset = translation

func _draw() -> void:
	for command in build_commands():
		var color := Color.from_string(command.color,Color.WHITE)
		match command.type:
			"rect":
				var r: Array = command.rect
				draw_rect(Rect2(r[0],r[1],r[2],r[3]),color)
			"line":
				var p: Array = command.points
				draw_line(Vector2(p[0][0],p[0][1]),Vector2(p[1][0],p[1][1]),color,command.width)
			"polygon":
				var points := PackedVector2Array()
				for p in command.points: points.append(Vector2(p[0],p[1]))
				draw_colored_polygon(points,color)
