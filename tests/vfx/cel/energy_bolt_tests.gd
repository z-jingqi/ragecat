extends SceneTree
## Flight contracts; native rendered comparison/video remain separate visual evidence.
const Config = preload("res://scripts/vfx/cel/energy_bolt_config.gd")
const Effect = preload("res://scripts/vfx/cel/energy_bolt.gd")
const Shape = preload("res://scripts/vfx/cel/energy_bolt_shape.gd")
const EffectScene = preload("res://scenes/vfx/cel/energy_bolt.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/energy_bolt_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/energy_bolt_lab.gd")
const SPECS := [
	["size",0.25,2.5],["head_height",24.0,200.0],["direction_degrees",-180.0,180.0],
	["reference_speed",80.0,1600.0],["tail_min",0.2,1.0],["tail_max",1.0,2.5],
	["response_seconds",0.025,0.5],["sample_distance",1.0,12.0],["teleport_distance",200.0,4000.0],
	["flow_speed",0.0,4.0],["flow_strength",0.0,2.0],["core_pulse_amplitude",0.0,0.12],
	["core_pulse_rate",0.2,8.0],["edge_shed_rate",0.0,24.0],["edge_lifetime",0.06,0.6],
	["edge_length",4.0,70.0],["edge_speed",50.0,600.0],
]
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func values(config: Resource) -> Dictionary:
	var result := {}
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property.name] = config.get(property.name)
	return result

func make_effect(config: Config = null) -> Node2D:
	var effect := EffectScene.instantiate()
	effect.configure(config)
	root.add_child(effect)
	return effect

func area(points: PackedVector2Array) -> float:
	var twice := 0.0
	for i in range(points.size()): twice += points[i].cross(points[(i+1)%points.size()])
	return absf(twice)*0.5

func bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for point in points: result = result.expand(point)
	return result

func geometry_problem(commands: Array, expected_count: int = 7) -> String:
	if expected_count >= 0 and commands.size() != expected_count: return "Expected %d hard-color contours, got %d" % [expected_count,commands.size()]
	if expected_count < 0 and (commands.size() < 3 or commands.size() > 36): return "Animated contour count is missing shell/core or exceeds bounded flow/shards"
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color"): return "Invalid command schema"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 2048: return "Unbounded / degenerate point count"
		for point in points:
			if not point.is_finite() or point.length() > 20000: return "Nonfinite / unbounded point"
		if area(points) < 0.0001: return "Zero-area plane %d" % index
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Non-triangulatable plane %d" % index
		var color: Color = command.color
		if color.a != 1.0: return "Cel palette must stay opaque"
		for channel in [color.r,color.g,color.b]:
			if not is_finite(channel) or channel < 0.0 or channel > 1.0: return "Invalid color"
	return ""

func self_intersection_problem(points: PackedVector2Array) -> String:
	# Only strict proper crossings count. Adjacent edges and shared vertices do not.
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i+1)%points.size()]
		for j in range(i+2,points.size()):
			if i == 0 and j == points.size()-1: continue
			var c := points[j]
			var d := points[(j+1)%points.size()]
			if maxf(a.x,b.x) < minf(c.x,d.x) or maxf(c.x,d.x) < minf(a.x,b.x): continue
			if maxf(a.y,b.y) < minf(c.y,d.y) or maxf(c.y,d.y) < minf(a.y,b.y): continue
			var ab := b-a
			var cd := d-c
			if ab.cross(c-a)*ab.cross(d-a) < -0.000001 and cd.cross(a-c)*cd.cross(b-c) < -0.000001:
				return "Crossing edges %d and %d" % [i,j]
	return ""

func check_no_crossings(effect: Node2D, context: String) -> void:
	var commands: Array = effect.build_commands(false)
	for index in range(commands.size()):
		var problem := self_intersection_problem(commands[index].points)
		check(problem.is_empty(),"%s plane %d: %s" % [context,index,problem])

func check_geometry(effect: Node2D, context: String) -> void:
	var commands: Array = effect.build_commands(false)
	var problem := geometry_problem(commands,7 if effect.config.detached_streaks else 3)
	check(problem.is_empty(),"%s: %s" % [context,problem])
	check(commands == effect.build_commands(false),"Deterministic baseline geometry: %s" % context)
	var animated: Array = effect.build_commands()
	check(geometry_problem(animated,-1).is_empty(),"Animated geometry remains safe: %s / %s" % [context,geometry_problem(animated,-1)])
	check(animated == effect.build_commands(),"Animated draw is deterministic and does not mutate state: %s" % context)

func test_config() -> void:
	var defaults := Config.new()
	for spec in SPECS:
		for input in [-100000.0,100000.0,NAN,INF,-INF]:
			var config := Config.new()
			config.set(spec[0],input)
			config.sanitize()
			var expected: float = clampf(input,spec[1],spec[2]) if is_finite(input) else defaults.get(spec[0])
			check(is_equal_approx(config.get(spec[0]),expected),"Finite config defense: %s / %s" % [spec[0],input])
	for input in [-100,99999]:
		var config := Config.new()
		config.history_limit = input
		config.sanitize()
		check(config.history_limit == clampi(input,64,512),"Bounded history config")
	for name in ["core_color","body_color","shade_color","flow_color","spark_color"]:
		var config := Config.new()
		config.set(name,Color(-5,4,0.3,0.2))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.3,1),"Opaque/clamped palette: %s" % name)
		config.set(name,Color(NAN,0,0,0))
		config.sanitize()
		check(config.get(name) == defaults.get(name),"Nonfinite palette fallback: %s" % name)
	var source := Config.new()
	source.size = 1.7
	var before := values(source)
	source.sanitize()
	check(before == values(source),"Sanitize is idempotent for valid settings")
	var a := make_effect(source)
	var b := make_effect(source)
	a.config.size = 0.5
	check(source.size == 1.7 and b.config.size == 1.7,"Configuration is deep-copied, never shared or written back")
	a.configure(null)
	check(values(a.config) == values(defaults),"Null configuration restores valid defaults")
	a.free()
	b.free()

func test_reference_shape() -> void:
	var effect := make_effect()
	var commands: Array = effect.build_reference_commands()
	check(geometry_problem(commands).is_empty(),"Traced reference contours are finite and triangulatable")
	check(Shape.SHADE.size() == 3 and Shape.BODY.size() == 3 and Shape.CORE.size() == 1,"One integrated head/tail, two tiny detached streaks, one continuous ivory core")
	check(Shape.SHADE[0].size() >= 45,"Measured asymmetric outline is not a generic ellipse or waterdrop")
	var outer := PackedVector2Array(Shape.SHADE[0])
	var core := PackedVector2Array(Shape.CORE[0])
	var box := bounds(outer)
	check(absf(box.position.x-180.0) < 18.0 and absf(box.end.x-1704.0) < 3.0,"Reference outer left tip and rounded right extent are retained")
	check(absf(box.position.y-263.0) < 3.0 and absf(box.end.y-605.0) < 3.0,"Reference top/bottom envelope retained")
	check(Geometry2D.is_point_in_polygon(Vector2(900,300),outer) and not Geometry2D.is_point_in_polygon(Vector2(900,325),outer),"Upper long rearward notch is retained")
	check(not Geometry2D.is_point_in_polygon(Vector2(800,514),outer) and Geometry2D.is_point_in_polygon(Vector2(800,530),outer),"Asymmetric lower rearward notch is retained")
	check(Geometry2D.is_point_in_polygon(Vector2(600,414),core) and Geometry2D.is_point_in_polygon(Vector2(1550,430),core),"Ivory core spans tapered tail into rounded head without separate orb")
	check(Geometry2D.is_point_in_polygon(Vector2(1200,350),core) and not Geometry2D.is_point_in_polygon(Vector2(1250,363),core),"Sharp upper ivory cut is retained")
	var unit: float = effect.config.head_height/Shape.REFERENCE_HEIGHT
	check(absf(bounds(commands[0].points).size.y-effect.config.head_height) < unit*3,"Configured head height is the reference scale, not an independent blob")
	var original: Array = commands.duplicate(true)
	effect.config.direction_degrees = 90
	commands = effect.build_reference_commands()
	var rotation_matches := true
	for i in range(commands.size()):
		for j in range(commands[i].points.size()):
			if not commands[i].points[j].is_equal_approx(original[i].points[j].rotated(PI*0.5)):
				rotation_matches = false
	check(rotation_matches,"Direction rotates the entire reference including the detached streaks")
	effect.reset_motion(Vector2.ZERO)
	var configured_head_point: Vector2 = effect._map_point(Vector2(1600,434))
	check(absf(configured_head_point.x) < 0.001 and configured_head_point.y > 40.0,"Omitted reset direction honors configured launch direction before motion arrives")
	effect.configure(effect.config)
	check_geometry(effect,"Reconfiguration while active")
	effect.config.detached_streaks = false
	check(effect.build_reference_commands().size() == 3,"Optional streaks do not remove body/core layers")
	effect.free()

func test_motion_response() -> void:
	var effect := make_effect()
	check(effect.build_commands(false).is_empty() and effect.build_commands().is_empty() and not effect.active,"Reusable scene starts dormant, with no automatic launch")
	var position := Vector2(350,220)
	effect.reset_motion(position)
	check(effect.actual_velocity == Vector2.ZERO and effect.actual_speed == 0.0,"Reset has no invented velocity")
	check(is_equal_approx(effect.tail_scale,effect.config.tail_min),"Reset begins with minimum tail")
	var reference: float = effect.config.reference_speed
	var dt := 1.0/60.0
	var prior: float = effect.tail_scale
	position += Vector2(reference*dt,0)
	effect.advance(position,dt)
	check(absf(effect.actual_speed-reference) < 0.01 and effect.actual_velocity.y == 0.0,"Actual displacement / delta, not a requested speed, drives the tail")
	check(effect.tail_scale > prior and effect.tail_scale < 1.0,"Acceleration smoothly approaches rather than instantly snapping to reference length")
	for i in range(179):
		position += Vector2(reference*dt,0)
		effect.advance(position,dt)
	check(absf(effect.tail_scale-1.0) < 0.0001,"Normal actual velocity converges to faithful 1x reference silhouette")
	check_geometry(effect,"Steady reference speed")
	for i in range(120):
		prior = effect.tail_scale
		position += Vector2(reference*2.0*dt,0)
		effect.advance(position,dt)
		check(effect.tail_scale+0.00001 >= prior and effect.tail_scale <= effect.config.tail_max+0.00001,"Acceleration is monotonic and clamped")
	check(absf(effect.tail_scale-effect.config.tail_max) < 0.0001,"Fast actual motion reaches the configured maximum tail")
	var fast_width: float = bounds(effect.build_commands(false)[0].points).size.x
	for i in range(120):
		prior = effect.tail_scale
		effect.advance(position,dt)
		check(effect.tail_scale <= prior+0.00001 and effect.tail_scale >= effect.config.tail_min-0.00001,"Deceleration is monotonic and clamped")
	check(effect.actual_speed == 0.0 and absf(effect.tail_scale-effect.config.tail_min) < 0.0001,"Stationary host produces zero measured speed and minimum tail")
	check(bounds(effect.build_commands(false)[0].points).size.x < fast_width*0.65,"Deceleration visibly shortens integrated silhouette, not just a hidden speed field")
	check(effect.speed_to_tail(NAN) == effect.config.tail_min and effect.speed_to_tail(-100) == effect.config.tail_min,"Invalid/negative speed mapping is safe")
	check(effect.speed_to_tail(1e20) == effect.config.tail_max,"Large finite speed is clamped")
	check_geometry(effect,"Stopped minimum tail")
	var snapshot: Dictionary = effect.motion_snapshot().duplicate(true)
	var old_position: Vector2 = effect.global_position
	for invalid_delta in [0.0,-0.1,NAN,INF,-INF]: effect.advance(position+Vector2(12,3),invalid_delta)
	for invalid_position in [Vector2(NAN,0),Vector2(0,INF)]: effect.advance(invalid_position,dt)
	check(effect.motion_snapshot() == snapshot and effect.global_position == old_position,"Invalid position or delta cannot corrupt state")
	effect.advance(position+Vector2(effect.config.teleport_distance+100,0),dt)
	check(effect.actual_speed == 0.0 and effect.motion_snapshot().history_count == 1,"Teleport resets rather than generating a map-length streak")
	check_geometry(effect,"Teleport reset")
	effect.stop()
	check(not effect.active and effect.build_commands(false).is_empty() and effect.build_commands().is_empty() and effect.motion_snapshot().history_count == 0 and effect.motion_snapshot().shard_count == 0,"Stop clears geometry, path and shards immediately")
	effect.advance(Vector2(40,90),dt)
	check(effect.active and effect.actual_speed == 0.0 and effect.global_position == Vector2(40,90),"Advance after stop restarts cleanly without old-position speed spike")
	effect.free()

func test_transformed_host() -> void:
	var host := Node2D.new()
	host.position = Vector2(200,100)
	host.rotation = 0.7
	host.scale = Vector2(1.8,1.3)
	root.add_child(host)
	var effect := EffectScene.instantiate()
	host.add_child(effect)
	var world_position := Vector2(450,310)
	effect.reset_motion(world_position,Vector2.UP)
	for frame in range(100):
		world_position += Vector2(0,-8)
		effect.advance(world_position,1.0/60.0)
	check(effect.global_position.is_equal_approx(world_position) and absf(effect.actual_speed-480) < 0.01,"World-position velocity remains correct under a transformed host")
	var reference_point := Vector2(1600,434)
	var rendered_world: Vector2 = effect.to_global(effect._map_point(reference_point))
	var expected_world: Vector2 = world_position+Vector2.UP*(160.0*effect.config.head_height/Shape.REFERENCE_HEIGHT*effect.config.size)
	check(rendered_world.distance_to(expected_world) < 0.01,"World path geometry is correctly converted through parent rotation/nonuniform scale")
	check_geometry(effect,"Transformed host")
	host.free()

func test_time_step_response() -> void:
	var effects := [make_effect(),make_effect(),make_effect()]
	var rates := [30,60,120]
	for index in range(effects.size()):
		var effect: Node2D = effects[index]
		effect.reset_motion(Vector2.ZERO)
		var dt: float = 1.0/rates[index]
		for frame in range(rates[index]/2): effect.advance(Vector2(effect.config.reference_speed*1.5*(frame+1)*dt,0),dt)
	check(absf(effects[0].tail_scale-effects[1].tail_scale) < 0.0001 and absf(effects[1].tail_scale-effects[2].tail_scale) < 0.0001,"Exponential response is stable at 30/60/120 Hz")
	for effect in effects: effect.free()

func test_turns_and_bounds() -> void:
	for radius in [280.0,120.0]:
		var effect := make_effect()
		var center := Vector2(700,500)
		effect.reset_motion(center+Vector2(radius,0),Vector2.DOWN)
		var dt := 1.0/60.0
		for frame in range(180):
			var angle: float = (frame+1)*effect.config.reference_speed/radius*dt
			effect.advance(center+Vector2(cos(angle),sin(angle))*radius,dt)
			if frame % 30 == 29: check_geometry(effect,"Recorded turn radius %.0f, frame %d" % [radius,frame])
		check(effect.motion_snapshot().history_count <= effect.config.history_limit,"Turning path history stays capped")
		var curve_mid: Vector2 = effect._path_point(80)
		var straight_mid: Vector2 = effect.global_position-effect.actual_velocity.normalized()*80
		check(curve_mid.distance_to(straight_mid) > 4,"Tail samples recorded curved path, not a rotated straight texture")
		effect.advance(effect.global_position-effect.actual_velocity.normalized()*10,dt)
		check_geometry(effect,"Abrupt reversal does not fold old tail through head")
		check_no_crossings(effect,"Reversal silhouette")
		effect.free()
	var extremes := [[0.25,24.0,0.2,2.5,0.025,64],[2.5,200.0,1.0,2.5,0.5,512]]
	for spec in extremes:
		var config := Config.new()
		config.size = spec[0]
		config.head_height = spec[1]
		config.tail_min = spec[2]
		config.tail_max = spec[3]
		config.response_seconds = spec[4]
		config.history_limit = spec[5]
		var effect := make_effect(config)
		effect.reset_motion(Vector2.ZERO)
		for frame in range(800): effect.advance(Vector2((frame+1)*12,0),1.0/60.0)
		check(effect.motion_snapshot().history_count <= config.history_limit,"Long flight is bounded at extreme history capacity")
		check_geometry(effect,"Extreme size/height/tail straight combination")
		var center := effect.global_position-Vector2(150,0)
		effect.reset_motion(center+Vector2(150,0),Vector2.DOWN)
		for frame in range(90):
			var angle := (frame+1)*0.06
			effect.advance(center+Vector2(cos(angle),sin(angle))*150,1.0/60.0)
			if frame % 30 == 29: check_geometry(effect,"Extreme size/height/tail curved combination frame %d" % frame)
		check_no_crossings(effect,"Extreme curved silhouette")
		effect.free()

func key(lab: Control, code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.echo = echo
	lab._unhandled_key_input(event)

func test_lab() -> void:
	var lab := LabScene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	check(lab.mode == 0 and lab.playing and not lab.teal,"Lab starts with approved-gold normal-speed reference")
	check(lab.effect.actual_speed > 0 and absf(lab.effect.tail_scale-1.0) < 0.001,"Reference display is warmed from real motion at configured speed")
	check(not lab.settings_panel.visible and lab.param_controls.size() == Lab.PARAMS.size(),"Live parameter panel is initially hidden and complete")
	check(lab.color_controls.size() == 5,"Five independent live cel colors including flow and shards")
	var elapsed: float = lab.elapsed
	key(lab,KEY_SPACE)
	lab._process(0.2)
	check(not lab.playing and lab.elapsed == elapsed,"Pause freezes the motion timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and absf(lab.elapsed-elapsed-1.0/60.0) < 0.00001,"Single-frame step stays paused and advances exactly one frame")
	key(lab,KEY_SPACE,true)
	check(not lab.playing,"Repeated key echoes cannot toggle playback")
	key(lab,KEY_SPACE)
	check(lab.playing,"Space resumes after single stepping")
	key(lab,KEY_S)
	check(lab.playback_speed == 0.25,"Slow motion is available")
	key(lab,KEY_S)
	check(lab.playback_speed == 1.0,"Normal speed is restorable")
	for code in [KEY_1,KEY_2,KEY_3,KEY_4]:
		key(lab,code)
		check(lab.mode == code-KEY_1 and lab.elapsed == 0.0,"Every motion-mode shortcut resets its own timeline")
		var initial_speed: float = lab.effect.actual_speed
		var initial_tail: float = lab.effect.tail_scale
		for frame in range(180): lab.step(1.0/60.0)
		check_geometry(lab.effect,"Lab motion mode %d" % lab.mode)
		if lab.mode == 1: check(lab.effect.actual_speed > initial_speed*5 and lab.effect.tail_scale > initial_tail*2,"Acceleration demo actually accelerates world motion and stretches the same silhouette")
		elif lab.mode == 2: check(lab.effect.actual_speed < initial_speed*0.2 and lab.effect.tail_scale < initial_tail*0.4,"Deceleration demo actually slows world motion and contracts the same silhouette")
		elif lab.mode == 3: check(absf(lab.effect.actual_velocity.y) > 100,"Turn demo moves through a curved world-space path")
		else: check(absf(lab.effect.actual_speed-initial_speed) < 0.01,"Reference mode remains constant actual speed")
	lab.set_parameter("head_height",120.0)
	check(lab.effect.config.head_height == 120.0 and lab.param_controls.head_height.value == 120.0,"API parameter update is reflected in effect and widget")
	lab.param_controls.response_seconds.value = 0.2
	check(is_equal_approx(lab.effect.config.response_seconds,0.2),"Live widget signal updates effect configuration")
	for pair in [["flow_speed",2.1],["flow_strength",0.6],["core_pulse_amplitude",0.075],["core_pulse_rate",3.2],["edge_shed_rate",14.0],["edge_lifetime",0.4],["edge_length",31.0],["edge_speed",260.0]]:
		lab.param_controls[pair[0]].value = pair[1]
		check(is_equal_approx(lab.effect.config.get(pair[0]),pair[1]),"Intrinsic energy widget signal: %s" % pair[0])
	for name in ["flow_color","spark_color"]:
		var old_other: Color = lab.effect.config.spark_color if name == "flow_color" else lab.effect.config.flow_color
		lab.set_color(name,Color(0.1,0.6,0.8,0.2))
		check(lab.effect.config.get(name) == Color(0.1,0.6,0.8,1),"Independent live energy palette: %s" % name)
		check((lab.effect.config.spark_color if name == "flow_color" else lab.effect.config.flow_color) == old_other,"Energy colors do not overwrite each other")
	var invalid_before: Dictionary = values(lab.effect.config)
	lab.set_parameter("missing_parameter",123)
	lab.set_color("missing_color",Color.RED)
	check(values(lab.effect.config) == invalid_before,"Unknown parameter/color names are ignored safely")
	lab.set_color("body_color",Color(0.2,0.4,0.8,0.3))
	check(lab.effect.config.body_color == Color(0.2,0.4,0.8,1.0),"Custom colors stay opaque and are sanitized")
	key(lab,KEY_C)
	check(lab.teal and lab.effect.config.body_color == Color("83efca") and lab.effect.config.flow_color == Color("8de7bd") and lab.effect.config.spark_color == Color("e2ffef"),"Teal variation updates the live independent effect")
	key(lab,KEY_C)
	check(not lab.teal and lab.effect.config.body_color == Config.new().body_color and lab.effect.config.flow_color == Config.new().flow_color and lab.effect.config.spark_color == Config.new().spark_color,"Approved gold can be restored exactly")
	key(lab,KEY_P)
	await process_frame
	var editor: LineEdit = lab.param_controls.head_height.get_line_edit()
	editor.grab_focus()
	check(lab.settings_panel.visible and editor.has_focus(),"Parameter editor receives focus when open")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes panel and releases keyboard focus")
	lab.toggle_parameters()
	await process_frame
	editor.grab_focus()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not editor.has_focus(),"Repeated direct panel close also releases focus")
	var children: int = lab.get_child_count()
	for repeat in range(20): lab.reset_defaults(); lab.set_mode(3); lab.step(0.05)
	check(lab.get_child_count() == children,"Repeated preview resets do not accumulate nodes")
	lab.reset_defaults()
	check(lab.mode == 0 and not lab.teal and lab.playback_speed == 1.0 and values(lab.effect.config) == values(Config.new()),"Reset restores reference motion, normal playback and all defaults")
	lab.free()

func commands_close(a: Array, b: Array, tolerance: float = 0.0001) -> bool:
	if a.size() != b.size(): return false
	for i in range(a.size()):
		if a[i].color != b[i].color or a[i].points.size() != b[i].points.size(): return false
		for j in range(a[i].points.size()):
			if a[i].points[j].distance_to(b[i].points[j]) > tolerance: return false
	return true

func test_intrinsic_energy() -> void:
	var config := Config.new()
	config.edge_shed_rate = 0.0
	var effect := make_effect(config)
	var fixed_position := Vector2(450,320)
	effect.reset_motion(fixed_position)
	effect.advance(fixed_position,0.08)
	var baseline: Array = effect.build_commands(false)
	var first: Array = effect.build_commands()
	var first_core: PackedVector2Array = effect._core_outline()
	var initial_tail: float = effect.tail_scale
	effect.advance(fixed_position,0.11)
	var second: Array = effect.build_commands()
	check(effect.global_position == fixed_position and effect.tail_scale == initial_tail and effect.actual_speed == 0.0,"Intrinsic energy test holds position, direction and tail scale fixed")
	check(commands_close(baseline,effect.build_commands(false)),"Intrinsic animation does not change the traced outer-shell baseline")
	check(not commands_close(first,second),"Internal flow/core visibly animate even when the host does not move")
	check(first_core != effect._core_outline(),"Core pressure motion is intrinsic, not only a translated overlay")
	check(absf(effect.energy_age-0.19) < 0.00001,"Intrinsic clock advances only through validated motion steps")
	check_geometry(effect,"Fixed-position intrinsic animation")
	# The near-white core remains one opaque plane; its pulse is gentle, not a flash.
	effect.config.flow_strength = 0.0
	var reference_core_area: float = area(PackedVector2Array(Shape.CORE[0]))
	var previous_core := PackedVector2Array()
	var previous_color := Color.WHITE
	var minimum_area := INF
	var maximum_area := 0.0
	var largest_point_step := 0.0
	var largest_color_step := 0.0
	var opaque_and_safe := true
	for frame in range(240):
		effect.advance(fixed_position,1.0/120.0)
		var core: PackedVector2Array = effect._core_outline()
		minimum_area = minf(minimum_area,area(core))
		maximum_area = maxf(maximum_area,area(core))
		var commands: Array = effect.build_commands()
		if commands.size() != 7 or not geometry_problem(commands).is_empty(): opaque_and_safe = false
		var tint: Color = commands[-1].color
		if not previous_core.is_empty():
			for i in range(core.size()): largest_point_step = maxf(largest_point_step,core[i].distance_to(previous_core[i]))
			largest_color_step = maxf(largest_color_step,maxf(absf(tint.r-previous_color.r),maxf(absf(tint.g-previous_color.g),absf(tint.b-previous_color.b))))
		previous_core = core
		previous_color = tint
	check(opaque_and_safe,"Pulse keeps one nontransparent, triangulatable core and the intact shell")
	check(minimum_area > reference_core_area*0.90 and maximum_area < reference_core_area*1.10,"Core breathes within a small area envelope instead of disappearing/strobing")
	check(largest_point_step < 4.0 and largest_color_step < 0.02,"Core geometry and luminance change smoothly at 120 Hz")
	# Off switches recover the exact static behavior, rather than merely hiding it.
	effect.config.core_pulse_amplitude = 0.0
	effect.config.flow_strength = 0.0
	effect.config.edge_shed_rate = 0.0
	effect.advance(fixed_position,0.1)
	check(commands_close(effect.build_commands(),effect.build_commands(false)),"All intrinsic-motion off switches recover the faithful static baseline")
	effect.config.flow_strength = 1.0
	effect.config.flow_speed = 0.0
	check(commands_close(effect.build_commands(),effect.build_commands(false)),"Zero flow speed disables flow independently")
	effect.free()

func test_rearward_flow() -> void:
	var config := Config.new()
	config.core_pulse_amplitude = 0.0
	config.edge_shed_rate = 0.0
	var effect := make_effect(config)
	effect.reset_motion(Vector2.ZERO)
	var stable_pairs := 0
	var rearward_pairs := 0
	var largest_forward_step := 0.0
	var geometries_safe := true
	var previous: Array = []
	for frame in range(300):
		effect.energy_age = frame/240.0
		var flow: Array = []
		effect._add_flow(flow,PackedVector2Array(Shape.CORE[0]))
		if flow.size() > 5: geometries_safe = false
		for command in flow:
			if not geometry_problem([command],1).is_empty(): geometries_safe = false
		if previous.size() == flow.size():
			for i in range(flow.size()):
				var shift: float = bounds(flow[i].points).end.x-bounds(previous[i].points).end.x
				# A cohort replacement jumps back to the leading edge; only compare
				# contiguous samples within a cohort, not the expected birth/death wrap.
				if absf(shift) < 15.0:
					stable_pairs += 1
					if shift < -0.0001: rearward_pairs += 1
					largest_forward_step = maxf(largest_forward_step,shift)
		previous = flow
	check(geometries_safe,"At most five finite tapered internal flow cohorts are emitted")
	check(stable_pairs > 500 and rearward_pairs >= stable_pairs*0.98,"Internal energy travels coherently head-to-tail rather than randomly jittering")
	check(largest_forward_step < 0.01,"A live flow cohort never moves forward between adjacent samples")
	var sample: Array = []
	effect.energy_age = 0.11
	effect._add_flow(sample,PackedVector2Array(Shape.CORE[0]))
	var repeated: Array = []
	effect._add_flow(repeated,PackedVector2Array(Shape.CORE[0]))
	check(sample == repeated,"Flow sampling is deterministic and does not consume global RNG/state")
	effect.free()

func test_world_shards() -> void:
	var effect := make_effect()
	var position := Vector2.ZERO
	effect.reset_motion(position)
	var dt := 1.0/120.0
	var max_shards := 0
	var lifetime_safe := true
	for frame in range(300):
		position += Vector2(effect.config.reference_speed*dt,0)
		effect.advance(position,dt)
		max_shards = maxi(max_shards,effect.motion_snapshot().shard_count)
		for shard: Dictionary in effect._shards:
			if shard.age < 0 or shard.age >= shard.life or shard.life > effect.config.edge_lifetime*1.221: lifetime_safe = false
	check(max_shards > 0 and max_shards <= 24 and lifetime_safe,"World shards emit, expire on their own lifetimes, and remain capped")
	# Retain the actual shard dictionary to track one individual in world space.
	var shard: Dictionary = effect._shards[-1]
	var old_origin: Vector2 = shard.origin
	var old_age: float = shard.age
	var old_world: Vector2 = shard.origin+shard.velocity*shard.age
	position += Vector2(effect.config.reference_speed*dt,0)
	effect.advance(position,dt)
	var new_world: Vector2 = shard.origin+shard.velocity*shard.age
	check(shard.origin == old_origin and absf(shard.age-old_age-dt) < 0.00001,"Emitted shard stays anchored to its world-space birth, not the projectile transform")
	check(new_world.distance_to(old_world+shard.velocity*dt) < 0.001,"Existing shard follows its own velocity after emission")
	check(shard.heading.dot(Vector2.RIGHT) < -0.9 and shard.velocity.x < effect.actual_speed,"Shard shape and relative motion trail rearward from flight direction")
	effect.config.edge_shed_rate = 0.0
	effect.advance(position,dt)
	check(effect.motion_snapshot().shard_count == 0,"Zero emission clears existing shards on the next validated update")
	effect.config.edge_shed_rate = 24.0
	effect.config.edge_lifetime = 0.6
	var bounded := true
	for frame in range(240):
		position += Vector2(12,0)
		effect.advance(position,1.0/60.0)
		if effect.motion_snapshot().shard_count > 24: bounded = false
	check(bounded,"Maximum emission rate and lifetime cannot create unbounded particles")
	effect.advance(position,2.0)
	for item: Dictionary in effect._shards:
		if item.age >= item.life: bounded = false
	check(bounded and effect.motion_snapshot().shard_count <= 24,"A long update drains expired shards and caps burst catch-up")
	effect.config.detached_streaks = false
	effect.advance(position,dt)
	check(effect.motion_snapshot().shard_count == 0,"Disabling detached streaks also stops/clears live shedding")
	effect.stop()
	check(effect.build_commands().is_empty() and effect.motion_snapshot().shard_count == 0,"Stop removes every intrinsic layer and particle")
	effect.reset_motion(Vector2.ZERO)
	check(effect.energy_age == 0 and effect.motion_snapshot().shard_count == 0,"Reset clears intrinsic clock, emission carry and prior particles")
	effect.free()

func test_energy_determinism() -> void:
	var effect := make_effect()
	var positions := PackedVector2Array()
	for frame in range(120): positions.append(Vector2(frame*9.0,sin(frame*0.025)*45))
	var recorded: Array = []
	effect.reset_motion(Vector2.ZERO)
	for position in positions:
		effect.advance(position,1.0/60.0)
		recorded.append(effect.build_commands())
	effect.reset_motion(Vector2.ZERO)
	var deterministic := true
	for i in range(positions.size()):
		effect.advance(positions[i],1.0/60.0)
		if recorded[i] != effect.build_commands(): deterministic = false
	check(deterministic,"Reset and replay reproduce core, flow and particle histories exactly")
	var config := Config.new()
	config.core_pulse_amplitude = 0.12
	config.flow_strength = 2.0
	config.flow_speed = 4.0
	config.edge_shed_rate = 24.0
	config.edge_lifetime = 0.6
	config.edge_length = 70.0
	config.edge_speed = 600.0
	effect.configure(config)
	effect.reset_motion(Vector2.ZERO)
	var safe := true
	for frame in range(180):
		effect.advance(Vector2((frame+1)*10,0),1.0/60.0)
		var problem := geometry_problem(effect.build_commands(),-1)
		if not problem.is_empty():
			print("ENERGY_EXTREME frame=%d: %s" % [frame,problem])
			safe = false
			break
	check(safe,"Maximum intrinsic motion controls retain valid opaque bounded geometry")
	effect.free()

func core_displacement(effect: Node2D, outline: PackedVector2Array, side: float = 0.0) -> float:
	var source: PackedVector2Array = PackedVector2Array(Shape.CORE[0]) if outline.size() == Shape.CORE[0].size() else effect._core_source()
	if source.size() != outline.size():
		check(false,"Animated boundary must correspond to its pre-deformation reference samples")
		return INF
	var displacement := 0.0
	for i in range(outline.size()):
		var reference: Vector2 = source[i]
		if side < 0 and reference.y >= 425.0: continue
		if side > 0 and reference.y < 425.0: continue
		displacement += outline[i].distance_to(reference)
	return displacement

func cut_peak(effect: Node2D, side: float) -> Vector2:
	var peak := Vector2(0,0)
	for x in range(435,1656,5):
		var amount: float = effect._flow_cut(x,side)
		if amount > peak.y: peak = Vector2(x,amount)
	return peak

func test_advected_core_boundary() -> void:
	var config := Config.new()
	config.core_pulse_amplitude = 0.0
	config.edge_shed_rate = 0.0
	var effect := make_effect(config)
	effect.reset_motion(Vector2.ZERO)
	effect.energy_age = 0.11
	var first: PackedVector2Array = effect._core_outline()
	check(first.size() == effect._core_source().size() and first.size() >= Shape.CORE[0].size(),"Moving boundary is sampled before deformation without discarding reference cuts")
	effect.energy_age = 0.19
	var second: PackedVector2Array = effect._core_outline()
	check(first != second and core_displacement(effect,first) > 1.0 and core_displacement(effect,second) > 1.0,"Flow alone changes the actual ivory/gold boundary while core pulse is disabled")
	check(core_displacement(effect,first,-1) > 0.1 and core_displacement(effect,first,1) > 0.1,"Both upper and lower ivory boundaries carry material-pressure cuts")
	# Strength controls geometry, not just the overlays' tint or emission count.
	effect.energy_age = 0.11
	effect.config.flow_strength = 0.5
	var weaker: PackedVector2Array = effect._core_outline()
	effect.config.flow_strength = 1.0
	var stronger: PackedVector2Array = effect._core_outline()
	check(core_displacement(effect,stronger) > core_displacement(effect,weaker)*1.25,"Flow strength visibly increases actual boundary displacement")
	effect.config.flow_speed = 0.65
	var slower: PackedVector2Array = effect._core_outline()
	effect.config.flow_speed = 2.8
	var faster: PackedVector2Array = effect._core_outline()
	check(slower != faster and core_displacement(effect,slower) > 0.1 and core_displacement(effect,faster) > 0.1,"Flow speed controls the actual boundary's advancing material phase")
	effect.config.flow_speed = config.flow_speed
	var previous_peaks := [Vector2.ZERO,Vector2.ZERO]
	var rearward_pairs := [0,0]
	var forward_pairs := [0,0]
	var independent_samples := 0
	var visible_samples := 0
	var core_uses_front := true
	for frame in range(240):
		effect.energy_age = frame/120.0+0.0013
		var peaks := [cut_peak(effect,-1),cut_peak(effect,1)]
		var outline: PackedVector2Array = effect._core_outline()
		var source: PackedVector2Array = effect._core_source()
		for i in range(outline.size()):
			var reference: Vector2 = source[i]
			var side := -1.0 if reference.y < 425.0 else 1.0
			var expected_cut: float = minf(absf(reference.y-425.0)*0.20,effect._flow_cut(reference.x,side))
			if absf(outline[i].y-(reference.y-side*expected_cut)) > 0.0001: core_uses_front = false
		if peaks[0].y > 1.0 and peaks[1].y > 1.0:
			visible_samples += 1
			if absf(peaks[0].x-peaks[1].x) > 75.0: independent_samples += 1
		for side_index in range(2):
			var peak: Vector2 = peaks[side_index]
			var previous: Vector2 = previous_peaks[side_index]
			if peak.y > 1.0 and previous.y > 1.0:
				var travel := peak.x-previous.x
				if travel < 0 and travel > -100.0: rearward_pairs[side_index] += 1
				elif travel > 0 and travel < 100.0: forward_pairs[side_index] += 1
		previous_peaks = peaks
	check(core_uses_front,"Advected cuts modify _core_outline vertices themselves, not only drawn overlay streaks")
	check(rearward_pairs[0] > 150 and rearward_pairs[1] > 150 and forward_pairs[0] == 0 and forward_pairs[1] == 0,"Both live boundary cuts move monotonically rearward between birth/death wraps")
	check(visible_samples > 150 and independent_samples > visible_samples*0.7,"Upper and lower boundary cuts have independent timing rather than mirrored/wavy motion")
	for disabled in ["flow_speed","flow_strength"]:
		effect.config.flow_speed = config.flow_speed
		effect.config.flow_strength = 1.0
		effect.config.set(disabled,0.0)
		var unchanged := true
		for frame in range(30):
			effect.energy_age = frame*0.077
			if core_displacement(effect,effect._core_outline()) > 0.001: unchanged = false
		check(unchanged and commands_close(effect.build_commands(),effect.build_commands(false)),"Zero %s restores the original boundary and static baseline with pulse disabled" % disabled)
	effect.free()

func test_strong_core_geometry() -> void:
	for shape in [[1.0,96.0],[0.25,24.0],[2.5,200.0]]:
		var config := Config.new()
		config.size = shape[0]
		config.head_height = shape[1]
		config.core_pulse_amplitude = 0.12
		config.core_pulse_rate = 8.0
		config.flow_strength = 2.0
		config.flow_speed = 4.0
		config.edge_shed_rate = 0.0
		var effect := make_effect(config)
		effect.reset_motion(Vector2.ZERO)
		var safe := true
		var reason := ""
		for frame in range(240):
			# Non-frame-aligned samples cover birth envelopes and independent cuts.
			effect.energy_age = frame/137.0+0.0013
			var core: PackedVector2Array = effect._core_outline()
			if Geometry2D.triangulate_polygon(core).is_empty(): reason = "core cannot triangulate"
			if frame % 30 == 0 and not self_intersection_problem(core).is_empty(): reason = "core self crossing"
			if reason.is_empty(): reason = geometry_problem(effect.build_commands(),-1)
			if not reason.is_empty():
				print("STRONG_CORE size=%s height=%s frame=%d: %s" % [shape[0],shape[1],frame,reason])
				safe = false
				break
		check(safe,"Maximum flow/pulse controls remain valid over irregular times at size=%s, height=%s" % [shape[0],shape[1]])
		effect.free()

func test_preview_timeline() -> void:
	var lab := LabScene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	check(Lab.CAPTURE_FRAMES == 1200,"Preview covers all five sections over 20 seconds at 60 fps")
	var previous_segment := -1
	var safe := true
	var seen_modes := {}
	for frame in range(Lab.CAPTURE_FRAMES):
		var segment := 0 if frame < 300 else (1 if frame < 540 else (2 if frame < 780 else (3 if frame < 1020 else 4)))
		if segment != previous_segment:
			previous_segment = segment
			lab.settings_panel.visible = segment == 4
			lab.set_palette(segment == 4,false)
			lab.set_mode(mini(segment,3))
			seen_modes[[lab.mode,lab.teal,lab.settings_panel.visible]] = true
		lab.step(1.0/60.0)
		var commands: Array = lab.effect.build_commands(false)
		var problem := geometry_problem(commands)
		if problem.is_empty(): problem = geometry_problem(lab.effect.build_commands(),-1)
		if not problem.is_empty():
			print("ENERGY_BOLT_PREVIEW frame=%d, mode=%d: %s" % [frame,lab.mode,problem])
			safe = false
			break
	check(safe,"Every exact 60 fps preview-timeline sample has finite, triangulatable contours")
	check(seen_modes.size() == 5,"Preview includes reference, acceleration, deceleration, turns and teal live controls")
	lab.free()

func run() -> void:
	test_config()
	test_reference_shape()
	test_motion_response()
	test_time_step_response()
	test_transformed_host()
	test_turns_and_bounds()
	await test_lab()
	test_intrinsic_energy()
	test_rearward_flow()
	test_world_shards()
	test_energy_determinism()
	test_advected_core_boundary()
	test_strong_core_geometry()
	test_preview_timeline()
	print("CEL_ENERGY_BOLT: %d checks, %d failures" % [checks,failures])
	quit(failures)
