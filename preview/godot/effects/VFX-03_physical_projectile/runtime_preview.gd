extends Node2D
const Flight := preload("physical_effect.gd")
const Impact := preload("../VFX-04_hit_impact/impact.gd")
var flights: Array[Dictionary] = []
var impacts: Array[Node2D] = []
var elapsed := 0.0
var next_launch := 0.2
func _ready() -> void:
	get_window().size = Vector2i(1280,720)
	get_window().content_scale_size = Vector2i(1280,720)
	label("RAGECAT / PHYSICAL ARROW + CONTACT",Vector2(48,35),28,Color("f5c56b"))
	label("Pure visual adapters · real path samples · caller-controlled lifetime · detached tail decay",Vector2(48,80),19,Color("b7c5c8"))
	label("FORWARD / 520 world units per second",Vector2(130,195),20,Color("c1d7d5"))
	label("DIAGONAL / 520 world units per second",Vector2(130,380),20,Color("c1d7d5"))
	label("No glow, energy core, collision or damage callback. Arrow remains alive until its owner stops it.",Vector2(48,620),19,Color("b7c5c8"))
	label("Impact inherits incoming direction. Existing particles stay small and expire on the simulation clock.",Vector2(48,654),18,Color("8eaaaa"))
func label(text: String, point: Vector2, size: int, tint: Color) -> void:
	var node := Label.new(); node.text=text; node.position=point
	node.add_theme_font_size_override("font_size",size); node.add_theme_color_override("font_color",tint); add_child(node)
func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= next_launch:
		next_launch += 2.4
		for i in range(2):
			var start := Vector2(160,290 if i==0 else 440)
			var target := Vector2(1060,290 if i==0 else 540)
			var fx := Flight.new(); add_child(fx)
			var velocity := start.direction_to(target)*520
			fx.play(start,velocity,{"body_scale":1.2,"lifetime":.1,"trail_width":2.0,"length_max":30.0})
			flights.append({"fx":fx,"point":start,"velocity":velocity,"target":target,"stopped":false})
	for i in range(flights.size()-1,-1,-1):
		var item := flights[i]
		if not item.stopped:
			item.point = item.point.move_toward(item.target,delta*520)
			item.fx.sample(delta,item.point,item.velocity)
			if item.point == item.target:
				item.stopped = true; item.fx.stop()
				var impact := Impact.new(); impact.auto_tick=false; add_child(impact)
				impact.play(item.point,Vector2(item.velocity.x,-item.velocity.y),{"size":.9,"coreSize":5,"shardCount":4,"shardLength":7,"duration":.2})
				impacts.append(impact)
		else: item.fx.advance(delta)
		if item.fx.done: item.fx.queue_free(); flights.remove_at(i)
	for i in range(impacts.size()-1,-1,-1):
		impacts[i].tick(delta)
		if not impacts[i].active: impacts[i].queue_free(); impacts.remove_at(i)
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,1280,720),Color("10202a"))
	for x in range(0,1280,32): draw_line(Vector2(x,125),Vector2(x,590),Color("172b34"))
	for y in range(125,590,32): draw_line(Vector2(0,y),Vector2(1280,y),Color("172b34"))
	for p in [Vector2(1075,290),Vector2(1075,542)]:
		draw_circle(p,16,Color("a66f68")); draw_circle(p,10,Color("764e51"))
