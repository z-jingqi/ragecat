extends SceneTree
var checks := 0
var failed := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failed += 1
		push_error(label)
func run() -> void:
	var script = load("res://effects/VFX-01_slash/slash_effect.gd")
	check(script != null, "reusable slash component exists")
	if script == null: quit(1); return
	var first = script.new()
	root.add_child(first)
	first.play(Vector2(300,200),Vector2.DOWN,115.0,0.85,{"curvature":1.0,"pixel_size":2.0})
	check(first.position == Vector2(300,200),"origin belongs to node, not screen coordinates")
	check(is_equal_approx(first.duration,.18),"approved 180ms duration")
	check(first.material_instance.get_shader_parameter("reach_px") == 57.5,"art pixels preserve 115-world-unit range")
	check(is_equal_approx(first.material_instance.get_shader_parameter("direction_radians"),-PI/2),"Godot down maps to canonical negative Y")
	check(is_equal_approx(first.material_instance.get_shader_parameter("sweep_radians"),1.7),"exact half angle produces exact cone")
	check(first.material_instance.get_shader_parameter("curvature") == 1.0,"circular game geometry supported")
	check(first.get_child_count() == 1,"no lab host, backgrounds, input or damage nodes")
	first.advance(.06)
	check(is_equal_approx(first.age,.06) and first.visible,"manual simulation clock")
	var second = script.new()
	root.add_child(second)
	second.play(Vector2.ZERO,Vector2.LEFT,160,1.25)
	check(second.material_instance != first.material_instance,"each active cut owns material parameters")
	second.advance(.09)
	check(is_equal_approx(first.age,.06),"overlap cannot advance first instance")
	first.advance(.12)
	check(first.done and not first.visible,"exact end hides all pixels")
	first.play(Vector2.ZERO,Vector2.ZERO,115,.85)
	check(not first.done and first.age == 0,"play resets reusable instance")
	check(first.material_instance.get_shader_parameter("direction_radians") == 0.0,"zero direction has safe right fallback")
	check(first.get_child_count() == 1,"replay cannot duplicate surfaces")
	first.advance(-2.0)
	check(first.age == 0.0,"negative delta cannot rewind")
	first.advance(8.0)
	check(first.done and first.age == first.duration,"large delta expires safely")
	first.play(Vector2.ZERO,Vector2.RIGHT,115,.85)
	first.stop()
	check(first.done and not first.visible,"explicit cancellation clears")
	first.free(); second.free()
	print("SLASH RUNTIME: %d checks, %d failed" % [checks,failed])
	quit(1 if failed else 0)
