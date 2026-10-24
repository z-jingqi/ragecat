class_name HazardWarningVisual
extends Node2D
## Plain, exact-footprint safety cues; never consume atlas budgets or combat RNG.
var charge_start := Vector2.ZERO
var charge_end := Vector2.ZERO
var charge_width := 0.0
var charge_progress := 0.0

func set_charge(start: Vector2, end: Vector2, width: float, progress: float) -> void:
	charge_start=start
	charge_end=end
	charge_width=width
	charge_progress=progress
	queue_redraw()

func _draw() -> void:
	draw_charge_warning(self,charge_start,charge_end,charge_width,charge_progress)

static func draw_circle_warning(canvas: Node2D, radius: float, progress: float, cross: bool = true) -> void:
	var phase := clampf(progress, 0.0, 1.0)
	var edge := VfxAtlasRenderer.color_setting(&"warning_edge_color")
	var timer := VfxAtlasRenderer.color_setting(&"warning_timer_color")
	var width := clampf(VfxAtlasRenderer.setting(&"warning_line_width"), 0.5, 3.0)
	var alpha := clampf(VfxAtlasRenderer.setting(&"warning_fill_opacity"), 0.0, 0.2)
	canvas.draw_circle(Vector2.ZERO, radius, Color(timer, alpha))
	canvas.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, edge, width, true)
	canvas.draw_arc(Vector2.ZERO, maxf(0.0, radius - VfxAtlasRenderer.setting(&"warning_timer_inset")), -PI*.5, -PI*.5+TAU*phase, 64, timer, width, true)
	if cross:
		var size := minf(radius*.2, VfxAtlasRenderer.setting(&"warning_center_size"))
		canvas.draw_line(Vector2(-size,0),Vector2(size,0),edge,width,true)
		canvas.draw_line(Vector2(0,-size),Vector2(0,size),edge,width,true)

static func draw_charge_warning(canvas: Node2D, start: Vector2, end: Vector2, width: float, progress: float) -> void:
	var length := start.distance_to(end)
	if length <= 0.01 or width < 0.0: return
	var direction := (end-start)/length
	var normal := direction.orthogonal()
	var side := normal*width*.5
	var corners := PackedVector2Array([start+side,end+side,end-side,start-side])
	var edge := VfxAtlasRenderer.color_setting(&"warning_edge_color")
	var timer := VfxAtlasRenderer.color_setting(&"warning_timer_color")
	var stroke := clampf(VfxAtlasRenderer.setting(&"warning_line_width"),.5,3.0)
	if width > 0.0:
		canvas.draw_colored_polygon(corners, Color(timer,clampf(VfxAtlasRenderer.setting(&"warning_fill_opacity"),0,.2)))
		corners.append(corners[0])
		canvas.draw_polyline(corners,edge,stroke,true)
	else:
		# A zero-width sweep can still hit a finite-radius target.
		canvas.draw_line(start,end,edge,stroke,true)
	# Fixed chevrons show direction; the center line fills toward the locked end.
	var head := VfxAtlasRenderer.setting(&"warning_arrow_size")
	if width > 0.0: head = minf(width*.25,head)
	var count := clampi(int(length/maxf(32,VfxAtlasRenderer.setting(&"warning_arrow_spacing"))),1,12)
	for i in range(count):
		var point := start+direction*length*float(i+1)/float(count+1)
		canvas.draw_polyline(PackedVector2Array([point-direction*head+normal*head,point,point-direction*head-normal*head]),edge,stroke,true)
	canvas.draw_line(start,start.lerp(end,clampf(progress,0,1)),timer,stroke,true)
