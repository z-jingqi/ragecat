extends Node2D
## Pure pixel charge layers; optional practice context is injected by the lab.
var demo: RefCounted
var behavior: RefCounted
var time := 0.0
var stop_at := -1.0
var effect_origin := Vector2(192,99)
var bright := false
var show_demo := false
var commands: Array = []
const GOLD := Color("e7a94c")
const TEAL := Color("55c3c0")
const ICE := Color("b0eee0")
const WHITE := Color("fff3d3")

func rect(box: Rect2, color: Color) -> void:
	commands.append({"type":"rect","rect":Rect2(box.position.round(),box.size.round()),"color":color})
func dot(point: Vector2, size: float, color: Color) -> void:
	rect(Rect2(point-Vector2.ONE*floorf(size/2),Vector2.ONE*size),color)
func line(a: Vector2,b: Vector2,color: Color,width: float = 1) -> void:
	var steps := maxi(1,ceili(a.distance_to(b)))
	for i in range(steps+1): dot(a.lerp(b,float(i)/steps),width,color)
func poly(points: Array, color: Color) -> void:
	var low := 10000.0; var high := -10000.0
	for p in points: low = minf(low,p.y); high = maxf(high,p.y)
	for y in range(floori(low),ceili(high)+1):
		var cuts: Array[float] = []
		var scan := y+0.5
		for i in range(points.size()):
			var a: Vector2 = points[i]; var b: Vector2 = points[(i+1)%points.size()]
			if (a.y<=scan and b.y>scan) or (b.y<=scan and a.y>scan): cuts.append(a.x+(scan-a.y)*(b.x-a.x)/(b.y-a.y))
		cuts.sort()
		for i in range(0,cuts.size()-1,2):
			var left := ceili(cuts[i]); var right := floori(cuts[i+1])
			if right>=left: rect(Rect2(left,y,right-left+1,1),color)
func wind(state: Dictionary, front: bool) -> void:
	var cfg = behavior.config
	var q: float = state.charge
	var opacity: float = state.opacity
	var dispersing: bool = state.phase=="DISSIPATE"
	var t := minf(time,stop_at) if dispersing else time
	var drift := (1-opacity) if dispersing else 0.0
	var phase: float = (t*(0.8+q*1.6)+q*q*2)*cfg.wind_speed
	for layer in range(3):
		var radius: float = cfg.radius*(1.08-layer*0.16)*(1-q*0.22)*(1+drift*0.4)
		var center := effect_origin+Vector2(0,25-layer*cfg.rise_height/2-drift*14)
		var base: float = phase+layer*2.2
		for twin in range(2):
			var begin := base+twin*PI
			for i in range(27):
				var u := i/26.0
				var a := begin+u*1.9
				if (sin(a)>0)!=front: continue
				if dispersing and (i+layer*3)%7 > opacity*7: continue
				var p := center+Vector2(cos(a)*radius,sin(a)*radius*0.28-u*7)
				var taper := sin(u*PI)
				var width := maxf(1,(1+q*2)*cfg.strength*taper*opacity)
				dot(p,ceilf(width),TEAL if front else Color("347482"))
				if front and u>0.25 and u<0.83 and q>0.4: dot(p-Vector2(0,1),1,ICE)

func build_commands() -> Array:
	commands=[]
	if behavior == null: return commands
	var state: Dictionary = behavior.sample(time,stop_at)
	var cfg = behavior.config
	var q: float = state.charge
	if show_demo and demo != null: demo.background(self)
	if state.active: wind(state,false)
	if show_demo and demo != null: demo.draw(self,state)
	if not state.active: return commands
	var dispersing: bool = state.phase=="DISSIPATE"
	var opacity: float = state.opacity
	var center := effect_origin-Vector2(0,2)
	for i in range(cfg.particle_count):
		if float(i)/maxi(1,cfg.particle_count)>opacity: continue
		var p: Vector2 = behavior.particle(i,minf(time,stop_at) if dispersing else time)
		p *= (0.95-q*0.52) if not dispersing else (0.43+(1-opacity)*0.8)
		p.y *= 0.7
		dot(center+p,1+i%2,TEAL if i%3 else ICE)
		if q>0.6 and not dispersing:
			line(center+p,center+p+p.normalized()*2,Color("347482"))
	# Tiny held focus, not a projectile or explosion. The character remains dominant.
	if opacity>0.15:
		var size := ceilf((2+q*2)*opacity)
		dot(center,size+2,TEAL)
		dot(center,size,ICE)
		if q>0.85: dot(center,1,WHITE)
	wind(state,true)
	return commands

func _draw() -> void:
	for command in build_commands(): draw_rect(command.rect,command.color)
