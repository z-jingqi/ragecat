extends Node2D
var commands: Array=[]
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

func ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	for y in range(-ceili(radii.y),ceili(radii.y)+1):
		var normalized := float(y)/maxf(1,radii.y)
		if absf(normalized)>1: continue
		var half_width := floorf(radii.x*sqrt(1-normalized*normalized))
		rect(Rect2(center+Vector2(-half_width,y),Vector2(half_width*2+1,1)),color)


func _draw() -> void:
	for c in build_commands(): draw_rect(c.rect,c.color)
func build_commands() -> Array: return commands
