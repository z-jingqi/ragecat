extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var baseline := ArrowPresentation.active_trails
	for element in ["", "fire", "lightning", "ice", "dark"]:
		for i in range(8):
			var arrow := load("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow
			arrow.visual_element = element; arrow.direction = Vector2.RIGHT.rotated(i * TAU / 8.0); arrow.position = Vector2(500,500); arrow.arena_bounds = Rect2(0,0,2000,2000)
			root.add_child(arrow); arrow.set_physics_process(false)
			var visual := arrow.get_node("Presentation") as ArrowPresentation; visual.set_physics_process(false)
			check(is_equal_approx(arrow.rotation, arrow.direction.angle()),"First frame orientation")
			for tick in range(12):
				arrow._physics_process(1.0/60.0); visual._physics_process(1.0/60.0)
			check(visual.points.size() <= visual.definition.trail_point_limit,"Bounded points")
			check(visual.definition.tint(element).is_equal_approx(visual.definition.palette.element_color(element)) if element != "dark" else true,"Palette agreement")
			var traveled := arrow.traveled; var position_before := arrow.position; visual._physics_process(0.0)
			check(arrow.position == position_before and arrow.traveled == traveled,"Presentation never changes motion")
			arrow.position += Vector2(1000,0); visual._physics_process(1.0/60.0); check(visual.points.size() <= 1,"No teleport ribbons")
			arrow.retire(); await process_frame
	var paused_arrow := load("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow
	paused_arrow.position = Vector2(500,500);paused_arrow.arena_bounds = Rect2(0,0,2000,2000);root.add_child(paused_arrow)
	await physics_frame
	paused = true
	var paused_position := paused_arrow.position
	var paused_visual := paused_arrow.get_node("Presentation") as ArrowPresentation
	var paused_ages := paused_visual.ages.duplicate()
	await physics_frame
	await physics_frame
	check(paused_arrow.position == paused_position and paused_visual.ages == paused_ages,"Tree pause stops projectile and ribbon clocks together")
	paused = false
	paused_arrow.queue_free()
	await process_frame
	var held: Array[Node] = []
	for i in range(120):
		var arrow := load("res://scenes/projectiles/bow_arrow.tscn").instantiate() as BowArrow
		arrow.set_physics_process(false);root.add_child(arrow);arrow.set_physics_process(false)
		var visual := arrow.get_node("Presentation") as ArrowPresentation;visual.set_physics_process(false)
		held.append(arrow)
	check(ArrowPresentation.active_trails <= 96 + baseline,"Only visual trail budget is capped")
	check(held.size() == 120,"Trail budget never suppresses arrows")
	for arrow in held: arrow.queue_free()
	await process_frame
	check(ArrowPresentation.active_trails == baseline,"No lifetime budget leak")
	print("ARROW_PRESENTATION_TESTS failures=",failures)
	quit(failures)
