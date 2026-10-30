extends SceneTree
## Pure-cel slash contracts. A real rendered viewport is a separate visual check.
const Config = preload("res://scripts/vfx/cel/slash_config.gd")
const Effect = preload("res://scripts/vfx/cel/slash.gd")
const EffectScene = preload("res://scenes/vfx/cel/slash.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/slash_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/slash_lab.gd")
const SPECS := [
	["size",0.25,2.5],["length",160.0,1100.0],["thickness",6.0,220.0],
	["curvature",0.3,1.0],["arc_degrees",60.0,250.0],["direction_degrees",-180.0,180.0],
	["sweep_seconds",0.025,0.25],["peak_seconds",0.0,0.15],
	["disappear_seconds",0.05,0.4],["duration_scale",0.4,2.0],["extension",0.0,0.2],
]
var checks := 0
var failures := 0
var finish_count := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func values(config: Resource) -> Dictionary:
	var result := {}
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			result[property.name] = config.get(property.name)
	return result

func key(lab: Control, code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.echo = echo
	lab._unhandled_key_input(event)

func polygon_area(points: PackedVector2Array) -> float:
	var twice := 0.0
	for i in range(points.size()):
		twice += points[i].cross(points[(i+1)%points.size()])
	return absf(twice)*0.5

func geometry_problem(commands: Array) -> String:
	if commands.size() > 3: return "More than three solid planes / unwanted fragments"
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if command.keys().size() != 2 or not command.has("points") or not command.has("color"):
			return "Unexpected command schema"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 256: return "Unbounded or empty contour"
		for point in points:
			if not point.is_finite() or point.length() > 2000: return "Nonfinite / unbounded point"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Plane %d is not triangulatable" % index
		if polygon_area(points) <= 0: return "Zero-area plane"
		var color: Color = command.color
		if color.a != 1.0: return "Cel layers must shrink, not become translucent"
		for channel in [color.r,color.g,color.b]:
			if not is_finite(channel) or channel < 0 or channel > 1: return "Invalid color"
	return ""

func geometry_safe(effect: Node2D, at_age: float, context: String) -> bool:
	var commands: Array = effect.build_commands(at_age)
	var problem := geometry_problem(commands)
	if not problem.is_empty():
		print("INVALID_CEL_SLASH %s age=%.17f: %s" % [context,at_age,problem])
		return false
	if commands != effect.build_commands(at_age):
		print("NONDETERMINISTIC_CEL_SLASH %s age=%.17f" % [context,at_age])
		return false
	return true

func check_transform(actual: Array, expected: Array, transform: Transform2D) -> bool:
	if actual.size() != expected.size(): return false
	for i in range(expected.size()):
		if actual[i].color != expected[i].color or actual[i].points.size() != expected[i].points.size(): return false
		for j in range(expected[i].points.size()):
			if not actual[i].points[j].is_equal_approx(transform*expected[i].points[j]): return false
	return true

func test_config() -> void:
	var defaults := Config.new()
	for spec in SPECS:
		for input in [-100000.0,100000.0,NAN,INF,-INF]:
			var config := Config.new()
			config.set(spec[0],input)
			config.sanitize()
			var expected: float = clampf(input,spec[1],spec[2]) if is_finite(input) else defaults.get(spec[0])
			check(is_equal_approx(config.get(spec[0]),expected),"Finite range defense: %s input=%s" % [spec[0],input])
	var short_arc := Config.new()
	short_arc.length = 160
	short_arc.thickness = 220
	short_arc.sanitize()
	check(is_equal_approx(short_arc.thickness,56),"Thickness is also bounded relative to length")
	var before := values(short_arc)
	short_arc.sanitize()
	check(values(short_arc) == before,"Sanitize is idempotent")
	for name in ["core_color","body_color","shade_color"]:
		for invalid in [Color(NAN,0.2,0.3),Color(0.2,INF,0.3),Color(0.2,0.3,-INF)]:
			var config := Config.new()
			config.set(name,invalid)
			config.sanitize()
			check(config.get(name) == defaults.get(name),"Invalid palette channel restores default: " + name)
		var config := Config.new()
		config.set(name,Color(-3,8,0.5,NAN))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.5,1),"Color clamps and becomes opaque: " + name)
	check(is_equal_approx(defaults.duration(),0.295),"Default one-shot is 295 ms")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),0.59),"Duration multiplier scales every phase")
	defaults.peak_seconds = 0
	check(is_equal_approx(defaults.duration(),0.5),"Zero peak has no hidden holding frame")

func test_shape_controls(effect: Node2D) -> void:
	effect.configure(Config.new())
	var sample_age := 0.1
	var baseline: Array = effect.build_commands(sample_age).duplicate(true)
	check(baseline.size() == 3,"Default crescent uses exactly body, ivory edge and one warm shadow")
	if baseline.size() != 3: return
	check(baseline[0].color == effect.config.body_color and baseline[1].color == effect.config.core_color and baseline[2].color == effect.config.shade_color,"No additional outline or glow color")
	check(baseline == effect.build_commands(sample_age),"Same age yields identical geometry without random state")
	var fractional := false
	for point in baseline[0].points:
		if not point.is_equal_approx(point.round()): fractional = true
	check(fractional,"Geometry is continuous rather than pixel-snapped")
	var body: PackedVector2Array = baseline[0].points
	var front_index := int(body.size()*0.125)
	var tail_index := int(body.size()*0.40625)
	var front_width := body[front_index].distance_to(body[body.size()-front_index])
	var tail_width := body[tail_index].distance_to(body[body.size()-tail_index])
	check(front_width > tail_width*3,"Crescent has a broad front and a substantially tapered tail")
	for angle in [-180.0,-73.0,90.0,180.0]:
		effect.configure(Config.new())
		effect.config.direction_degrees = angle
		check(check_transform(effect.build_commands(sample_age),baseline,Transform2D(deg_to_rad(angle),Vector2.ZERO)),"Direction rotates all planes: %.0f" % angle)
	effect.configure(Config.new())
	effect.config.size = 2
	check(check_transform(effect.build_commands(sample_age),baseline,Transform2D(0,Vector2.ZERO).scaled(Vector2(2,2))),"Size scales every plane uniformly")
	effect.configure(Config.new())
	effect.config.reverse = true
	check(check_transform(effect.build_commands(sample_age),baseline,Transform2D(0,Vector2.ZERO).scaled(Vector2(-1,1))),"Reverse mirrors the full gesture, not just one layer")
	effect.config.direction_degrees = 37
	var transform := Transform2D(deg_to_rad(37),Vector2.ZERO)*Transform2D(0,Vector2.ZERO).scaled(Vector2(-1,1))
	check(check_transform(effect.build_commands(sample_age),baseline,transform),"Reverse happens before host-selected rotation")
	for spec in [["length",500.0],["thickness",70.0],["curvature",0.9],["arc_degrees",130.0],["extension",0.2],["sweep_seconds",0.2],["peak_seconds",0.12],["disappear_seconds",0.35]]:
		effect.configure(Config.new())
		effect.config.set(spec[0],spec[1])
		var age: float = 0.2 if spec[0] == "disappear_seconds" else sample_age
		var other := Effect.new()
		check(effect.build_commands(age) != other.build_commands(age),"Live shape / timing parameter affects geometry: " + spec[0])
		other.free()
	for scale_value in [0.4,2.0]:
		effect.configure(Config.new())
		effect.config.duration_scale = scale_value
		check(check_transform(effect.build_commands(sample_age*scale_value),baseline,Transform2D.IDENTITY),"Timing multiplier preserves normalized shape: %.1f" % scale_value)
	effect.configure(Config.new())
	var born: Array = effect.build_commands(0.0)
	var peak: Array = effect.build_commands(0.08)
	var dying: Array = effect.build_commands(0.25)
	check(polygon_area(born[0].points) < polygon_area(peak[0].points)*0.2,"Fast reveal extends a small first mark into the full arc")
	check(polygon_area(dying[0].points) < polygon_area(peak[0].points)*0.25,"Disappearance shrinks the solid geometry")
	for name in ["body_color","core_color","shade_color"]:
		effect.configure(Config.new())
		effect.config.set(name,Color(0.1,0.2,0.3,1))
		var changed: Array = effect.build_commands(sample_age)
		var index: int = ["body_color","core_color","shade_color"].find(name)
		check(changed[index].color == Color(0.1,0.2,0.3,1) and changed[index].points == baseline[index].points,"Palette changes the selected plane, not geometry: " + name)

func test_geometry(effect: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 769231
	for variant in range(37):
		var config := Config.new()
		if variant > 0:
			for spec in SPECS:
				var choice := rng.randi_range(0,4)
				config.set(spec[0],spec[1] if choice == 0 else (spec[2] if choice == 1 else rng.randf_range(spec[1],spec[2])))
			config.reverse = variant%2 == 0
		effect.configure(config)
		var safe := true
		for frame in range(121):
			if not geometry_safe(effect,effect.config.duration()*frame/120.0,"variant %d frame %d" % [variant,frame]):
				safe = false
				break
		check(safe,"Finite, bounded, triangulatable, opaque and deterministic timeline: variant %d" % variant)
		check(effect.build_commands(effect.config.duration()).is_empty(),"Every variant completes empty: %d" % variant)
	for scale_value in [0.4,1.0,2.0]:
		for small in [false,true]:
			var config := Config.new()
			config.duration_scale = scale_value
			if small:
				config.size = 0.25
				config.length = 1100
				config.thickness = 6
				config.curvature = 0.3
				config.arc_degrees = 60
				config.peak_seconds = 0
			effect.configure(config)
			var boundaries := [0.0,config.sweep_seconds,config.sweep_seconds+config.peak_seconds,config.duration()/scale_value]
			for cutoff in [0.16,1.0]:
				var decay := 1.0-pow(cutoff/(config.thickness*config.size),1.0/1.15)
				boundaries.append(config.sweep_seconds+config.peak_seconds+config.disappear_seconds*decay)
			var safe := true
			for boundary in boundaries:
				for epsilon in [0.0,1e-2,1e-3,1e-4,1e-5,1e-6,1e-7,1e-8,1e-9,1e-10,1e-12,1e-14]:
					for side in [-1.0,1.0]:
						if not geometry_safe(effect,(boundary+side*epsilon)*scale_value,"phase/cull boundary scale %.2f thin %s" % [scale_value,small]): safe = false
			check(safe,"Dense phase / culling boundaries remain valid: scale %.1f thin %s" % [scale_value,small])
	effect.configure(Config.new())
	var capture_safe := true
	var saw_angles := false
	var saw_light := false
	for frame in range(Lab.CAPTURE_FRAMES):
		var sample: Dictionary = Lab.capture_sample(frame)
		capture_safe = capture_safe and is_finite(sample.time) and sample.speed > 0
		saw_light = saw_light or sample.bright
		if sample.get("angles",false):
			saw_angles = true
			for angle in Lab.COMPARISON_ANGLES:
				effect.config.direction_degrees = angle
				if not geometry_safe(effect,sample.time-Lab.START,"capture frame %d angle %.0f" % [frame,angle]): capture_safe = false
		else:
			effect.config.direction_degrees = 0
			if not geometry_safe(effect,sample.time-Lab.START,"capture frame %d" % frame): capture_safe = false
	check(capture_safe and saw_light and saw_angles,"Exact capture timeline is valid, including light backdrop and four-angle pass")

func test_effect() -> void:
	var inspector_source := Config.new()
	inspector_source.size = 0.75
	inspector_source.direction_degrees = -37
	var inspector_effect := EffectScene.instantiate()
	inspector_effect.settings = inspector_source
	root.add_child(inspector_effect)
	inspector_effect.set_process(false)
	check(inspector_effect.config != inspector_source and values(inspector_effect.config) == values(inspector_source),"Ready respects and snapshots the Inspector settings resource")
	inspector_effect.config.size = 1.25
	check(inspector_source.size == 0.75,"Runtime edits do not modify Inspector settings")
	inspector_effect.free()
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 2.5,"Configure deep-copies before validation, including before ready")
	effect.config.body_color = Color.RED
	check(source.body_color == Config.new().body_color,"Runtime palette changes leave caller resource intact")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores defaults")
	check(effect.get_child_count() == 0 and not effect.playing and effect.build_commands().is_empty(),"Reusable scene starts dormant without props, pixel rendering or particles")
	for at_age in [-1.0,-0.001,effect.config.duration(),100.0,INF,NAN]:
		check(effect.build_commands(at_age).is_empty(),"No geometry outside valid lifetime: %s" % at_age)
	check(not effect.build_commands(0).is_empty(),"One-shot starts immediately, without a demo wind-up")
	test_shape_controls(effect)
	test_geometry(effect)
	effect.configure(Config.new())
	effect.finished.connect(func(): finish_count += 1)
	effect.play()
	check(effect.playing and effect.age == 0,"Play starts an immediate one-shot")
	effect._process(0.1)
	check(is_equal_approx(effect.age,0.1),"One-shot advances by delta")
	for delta in [-1.0,INF,-INF,NAN]: effect._process(delta)
	check(is_equal_approx(effect.age,0.1) and effect.playing,"Negative and invalid delta cannot corrupt age")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Completion emits exactly once and clears geometry")
	effect.play()
	effect.seek(0.1)
	effect._process(1)
	check(not effect.playing and is_equal_approx(effect.age,0.1) and finish_count == 1,"Seek pauses without emitting completion")
	for invalid in [NAN,INF,-INF]:
		effect.seek(invalid)
		check(effect.build_commands().is_empty() and not effect.playing,"Invalid seek is safely dormant")
	effect.play()
	effect._process(0.1)
	effect.play()
	check(effect.age == 0 and finish_count == 1,"Interrupted replay restarts without premature finished signal")
	for i in range(50): effect.play(); effect._process(1)
	check(finish_count == 51 and effect.get_child_count() == 0,"Repeated one-shots complete without accumulating child nodes")
	effect.free()

func viewport_bounds(effect: Node2D) -> Rect2:
	var first := true
	var result := Rect2()
	for command in effect.build_commands():
		for point in command.points:
			var visible_point: Vector2 = effect.transform*point
			if first:
				result = Rect2(visible_point,Vector2.ZERO)
				first = false
			else:
				result = result.expand(visible_point)
	return result

func test_preview_framing(lab: Control) -> void:
	lab.angle_comparison = false
	for panel_open in [false,true]:
		lab.settings_panel.visible = panel_open
		var frame := Rect2(80,222,780 if panel_open else 1120,360)
		for reversed in [false,true]:
			for angle in [0.0,90.0,180.0,-90.0]:
				lab.reset_defaults()
				lab.effect.config.direction_degrees = angle
				lab.effect.config.reverse = reversed
				lab._sync_controls()
				lab.clock = Lab.START+lab.effect.config.sweep_seconds+lab.effect.config.peak_seconds
				lab._update_art()
				var bounds := viewport_bounds(lab.effect)
				check(bounds.size.x > 0 and bounds.size.y > 0 and frame.grow(0.01).encloses(bounds),"Peak silhouette stays in preview frame: angle %.0f reverse %s panel %s" % [angle,reversed,panel_open])
		lab.reset_defaults()
		lab.set_parameter("direction_degrees",90.0)
		lab.clock = Lab.START+lab.effect.config.sweep_seconds+lab.effect.config.peak_seconds
		lab._update_art()
		var reference_bounds: Rect2 = lab.preview_bounds
		var original_transform: Transform2D = lab.effect.transform
		var original_bounds := viewport_bounds(lab.effect)
		lab.set_parameter("size",2.0)
		lab.clock = Lab.START+lab.effect.config.sweep_seconds+lab.effect.config.peak_seconds
		lab._update_art()
		var large_bounds := viewport_bounds(lab.effect)
		check(lab.preview_bounds.is_equal_approx(reference_bounds) and lab.effect.transform.is_equal_approx(original_transform),"Size changes do not trigger corrective auto-fit: panel %s" % panel_open)
		check(large_bounds.size.is_equal_approx(original_bounds.size*2),"Size ×2 doubles visible geometry rather than being cancelled by framing: panel %s" % panel_open)
		lab.set_parameter("size",1.0)
		lab.set_parameter("length",988.0)
		lab.clock = Lab.START+lab.effect.config.sweep_seconds+lab.effect.config.peak_seconds
		lab._update_art()
		var longer_bounds := viewport_bounds(lab.effect)
		check(lab.preview_bounds.is_equal_approx(reference_bounds) and lab.effect.transform.is_equal_approx(original_transform) and longer_bounds.size.length() > original_bounds.size.length()*1.2,"Length changes remain visibly larger without auto-fit compensation: panel %s" % panel_open)
	lab.reset_defaults()
	lab.settings_panel.hide()
	lab.angle_comparison = false
	lab.toggle_angles()
	lab.toggle_parameters()
	lab._update_art()
	check(lab.settings_panel.visible and not lab.angle_comparison and lab.effect.visible and not lab.comparison_effects[0].visible,"Opening parameters exits comparison and restores the single effect")
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(),"Framing test focuses a live numeric editor")
	lab.toggle_angles()
	lab._update_art()
	check(lab.angle_comparison and not lab.settings_panel.visible and not editor.has_focus() and not lab.effect.visible,"Opening angle comparison closes parameters and releases input focus")
	lab.toggle_angles()
	lab.toggle_parameters()
	await process_frame
	editor.grab_focus()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not editor.has_focus(),"Closing parameters directly also releases input focus")

func test_lab() -> void:
	var lab := LabScene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.effect.set_process(false)
	var source_before := values(lab.settings)
	check(lab.effect.config != lab.settings,"Lab isolates the Inspector resource")
	lab.clock = 0.6
	key(lab,KEY_SPACE)
	lab._process(0.1)
	check(is_equal_approx(lab.clock,0.6),"Pause holds the timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.clock,0.6+1.0/60.0),"Frame-step advances exactly one frame and stays paused")
	key(lab,KEY_R)
	check(lab.playing and lab.clock == 0,"Replay restarts timeline")
	key(lab,KEY_S)
	lab._process(0.4)
	check(is_equal_approx(lab.clock,0.1),"Quarter speed changes timeline progression")
	key(lab,KEY_S)
	key(lab,KEY_L)
	lab.clock = lab.duration()-0.01
	lab._process(0.1)
	check(not lab.playing and lab.clock == lab.duration(),"Non-loop playback stops at its endpoint")
	key(lab,KEY_RIGHT)
	check(lab.clock == lab.duration(),"Frame-step clamps at the endpoint")
	key(lab,KEY_L)
	lab.replay()
	lab._process(lab.duration()+0.1)
	check(is_equal_approx(lab.clock,0.1),"Loop retains residual time")
	key(lab,KEY_B)
	key(lab,KEY_B,true)
	check(lab.bright,"Backdrop toggles and ignores key-repeat events")
	key(lab,KEY_A)
	lab._update_art()
	var comparisons_valid: bool = lab.angle_comparison and not lab.effect.visible and lab.comparison_effects.size() == 4
	for i in range(lab.comparison_effects.size()):
		comparisons_valid = comparisons_valid and lab.comparison_effects[i].visible and lab.comparison_labels[i].visible
		comparisons_valid = comparisons_valid and is_equal_approx(lab.comparison_effects[i].age,lab.effect.age)
		comparisons_valid = comparisons_valid and is_equal_approx(lab.comparison_effects[i].config.direction_degrees,Lab.COMPARISON_ANGLES[i])
	check(comparisons_valid,"Four-angle view shares the timeline with independently rotated copies")
	key(lab,KEY_A)
	lab._update_art()
	check(not lab.angle_comparison and lab.effect.visible and not lab.comparison_effects[0].visible,"Returning from angle comparison restores the main view")
	key(lab,KEY_X)
	check(lab.effect.config.reverse and lab.reverse_toggle.button_pressed and lab.comparison_effects[0].config.reverse,"Reverse keyboard syncs the control and comparison copies")
	key(lab,KEY_X)
	key(lab,KEY_P)
	check(lab.settings_panel.visible,"Parameter shortcut opens the panel")
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes parameters and releases editing focus")
	for spec in lab.PARAMS:
		lab.reset_defaults()
		lab.param_controls[spec[0]].value = spec[3]
		check(is_equal_approx(float(lab.effect.config.get(spec[0])),spec[3]) and lab.clock == 0 and lab.playing,"Numeric UI updates and replays: " + spec[0])
	for name in lab.color_controls:
		var color := Color(0.14,0.37,0.62,1)
		lab.clock = 0.8
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color and lab.clock == 0 and lab.playing,"Palette UI updates and replays: " + name)
	lab.reverse_toggle.button_pressed = true
	var reverse_synced: bool = lab.effect.config.reverse
	for comparison in lab.comparison_effects: reverse_synced = reverse_synced and comparison.config.reverse
	check(reverse_synced,"Reverse control mirrors main effect and all comparison copies")
	check(values(lab.settings) == source_before,"All UI edits preserve the original Inspector resource")
	var before := values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	check(values(lab.effect.config) == before,"Unknown parameter names are ignored")
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and not lab.reverse_toggle.button_pressed,"Reset restores exact configuration and controls")
	var count: int = lab.get_child_count()
	for i in range(50): lab.reset_defaults(); lab._process(0.5)
	check(lab.get_child_count() == count,"Repeated lab replay does not accumulate UI/effect nodes")
	await test_preview_framing(lab)
	lab.free()

func run() -> void:
	test_config()
	test_effect()
	await test_lab()
	print("CEL_SLASH: %d checks, %d failures" % [checks,failures])
	quit(failures)
