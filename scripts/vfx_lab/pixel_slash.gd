extends Node2D
## Crisp, opaque palette bands rasterized on the lab's 384×160 pixel grid.
var behavior: RefCounted
var time := 0.0
var bright := false
var commands: Array = []
var offset := Vector2.ZERO
var pivot := Vector2(168, 82)

func build_commands() -> Array:
	commands = []
	offset = Vector2.ZERO
	if behavior == null: return commands
	var state: Dictionary = behavior.sample(time)
	var cfg = behavior.config
	var t: float = behavior.timeline(time)
	var scale: float = cfg.radius/75.0
	rect(Rect2(0,0,384,160),Color("c6c3b3") if bright else Color("131c25"))
	var grid := Color("b8b6a8") if bright else Color("1b2832")
	for x in range(0,384,16): line(Vector2(x,0),Vector2(x,160),grid)
	for y in range(0,160,16): line(Vector2(0,y),Vector2(384,y),grid)
	rect(Rect2(0,130,384,30),Color("a4a598") if bright else Color("0d141b"))
	line(Vector2(0,130),Vector2(384,130),Color("7c897e") if bright else Color("314149"))
	rect(Rect2(132,132,69,3),Color("718078") if bright else Color("090f16"))
	# A restrained practice swordsman anchors the arc without competing with it.
	var lean := roundf(state.lean)
	poly([Vector2(151,98),Vector2(166,98),Vector2(171,126),Vector2(163,129),Vector2(158,111),Vector2(149,129),Vector2(140,129)],Color("293b4b"))
	rect(Rect2(138,127,14,3),Color("101a25"))
	rect(Rect2(163,127,14,3),Color("101a25"))
	transform(Vector2(lean,0))
	poly([Vector2(145,73),Vector2(158,68),Vector2(171,79),Vector2(165,102),Vector2(147,101),Vector2(140,89)],Color("496475"))
	poly([Vector2(145,74),Vector2(155,73),Vector2(153,98),Vector2(146,96)],Color("78939a"))
	poly([Vector2(146,53),Vector2(151,48),Vector2(162,50),Vector2(166,60),Vector2(160,71),Vector2(149,68)],Color("99aaa8"))
	rect(Rect2(149,59,17,4),Color("1b2c3a"))
	rect(Rect2(160,60,4,1),Color("e4e8cd"))
	transform(Vector2.ZERO)
	# Three delayed, discretely colored blade ghosts. No alpha haze or blur.
	for i in range(cfg.ghost_count,0,-1):
		var past: float = time-i*cfg.ghost_spacing
		if past >= behavior.SWEEP and past <= behavior.follow_time() and t < behavior.FADE and i*cfg.ghost_spacing <= cfg.ghost_lifetime+0.000001:
			var a: float = behavior.sample(past).angle
			blade(a,Color("35535e") if not bright else Color("748e8b"),false)
	if state.trail > 0.0:
		var end: float = state.angle
		var start: float = behavior.sample(maxf(behavior.SWEEP,time-0.12)).angle
		if t >= behavior.FOLLOW:
			end = behavior.sample(behavior.follow_time()).angle
			start = lerpf(end-minf(3.05,deg_to_rad(cfg.arc_degrees)-0.1),end-0.12,1.0-state.trail)
		# Bright tapered crescent bands only; no dark contour underlay.
		crescent(start,end,75*scale,12*state.trail*cfg.width*scale,Color("62b6ba"))
		crescent(start+0.03,end,74*scale,6*state.trail*cfg.width*scale,Color("c0e8d7"))
		crescent(start+0.08,end,74*scale,2*state.trail*cfg.width*scale,Color("fff4d2"))
		# Sparse angular chips separate from the leading edge, then disappear.
		if t > 0.44:
			for i in range(5):
				var a: float = 0.1+i*0.28+deg_to_rad(cfg.arc_degrees)-3.7
				var r := 81+(t-0.44)*(25+i*14)
				var q: Vector2 = (pivot+behavior.blade_point(a,r*scale)).round()
				line(q,q+Vector2(3-i%2,1+i%2),Color("62b6ba"),1)
	blade(state.angle,Color("d5e1d4"),true)
	# Hand and short forearm sit in front of the hilt.
	line(Vector2(159+lean,79),pivot,Color("78939a"),5)
	rect(Rect2(pivot-Vector2(2,2),Vector2(4,4)),Color("c6b18c"))
	return commands

func blade(angle: float, color: Color, detailed: bool) -> void:
	var base: Vector2 = pivot+behavior.blade_point(angle,9*behavior.config.radius/75.0)
	var tip: Vector2 = pivot+behavior.blade_point(angle,72*behavior.config.radius/75.0)
	var side := Vector2(-sin(angle),cos(angle)).rotated(behavior.direction)*2.5
	poly([base+side,tip,base-side],color)
	if detailed:
		line((base+side).round(),tip.round(),Color("fff4d2"))
		line((base-side*2).round(),(base+side*2).round(),Color("c39b62"),2)
		line(pivot.round(),base.round(),Color("8b694b"),3)

func crescent(start: float, end: float, radius: float, width: float, color: Color) -> void:
	if end-start < 0.015 or width < 0.5: return
	var points: Array[Vector2] = []
	for i in range(25):
		var u := i/24.0
		points.append(pivot+behavior.blade_point(lerpf(start,end,u),radius))
	for i in range(24,-1,-1):
		var u := i/24.0
		var taper := maxf(0.04,sin(u*PI)*0.85+u*0.15)
		points.append(pivot+behavior.blade_point(lerpf(start,end,u),radius-width*taper))
	poly(points,color)

func poly(points: Array[Vector2], color: Color) -> void:
	var coordinates: Array = []
	for point in points: coordinates.append([point.x+offset.x, point.y+offset.y])
	commands.append({"type":"polygon", "points":coordinates, "color":color.to_html()})

func rect(area: Rect2, color: Color) -> void:
	commands.append({"type":"rect", "rect":[area.position.x+offset.x,area.position.y+offset.y,area.size.x,area.size.y],"color":color.to_html()})

func line(start: Vector2, end: Vector2, color: Color, width: float = 1.0) -> void:
	commands.append({"type":"line", "points":[[start.x+offset.x,start.y+offset.y],[end.x+offset.x,end.y+offset.y]],"color":color.to_html(),"width":width})

func transform(translation: Vector2) -> void:
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
