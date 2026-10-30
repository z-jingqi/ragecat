extends SceneTree
## Geometry/lifecycle contracts; an actual viewport motion review is a separate gate.
const Config = preload("res://scripts/vfx/cel/lightning_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/lightning.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/lightning_lab.tscn")
const StudyLab = preload("res://scripts/vfx_lab/cel/study_lab.gd")
const TOGGLES := ["show_leader","show_main","show_branches","show_contact","show_residual","show_sparks"]
var checks := 0
var failures := 0
var finish_count := 0

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
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = config.get(property.name)
	return result

func range_specs(config: Resource) -> Array:
	var result: Array = []
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.hint == PROPERTY_HINT_RANGE:
			var limits: PackedStringArray = property.hint_string.split(",")
			result.append([property.name,float(limits[0]),float(limits[1]),property.type])
	return result

func color_names(config: Resource) -> Array:
	var result: Array = []
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.type == TYPE_COLOR: result.append(property.name)
	return result

func layer_shapes(commands: Array, layer: String) -> Array:
	var shapes: Array = []
	for command in commands:
		if command.layer == layer: shapes.append(command.points)
	return shapes

func layer_points(commands: Array, layer: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for shape in layer_shapes(commands,layer): points.append_array(shape)
	return points

func bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var result := Rect2(points[0],Vector2.ZERO)
	for point in points: result = result.expand(point)
	return result

func polygon_area(points: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in range(points.size()): twice_area += points[i].cross(points[(i+1)%points.size()])
	return absf(twice_area)*0.5

func layer_area(commands: Array, layer: String) -> float:
	var area := 0.0
	for shape in layer_shapes(commands,layer): area += polygon_area(shape)
	return area

func geometry_problem(commands: Array) -> String:
	if commands.size() > 512: return "Unbounded active command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color") or not command.has("layer"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 256: return "Invalid vertex count"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d (%s)" % [index,command.layer]
		if polygon_area(points) < 0.000001: return "Degenerate polygon %d (%s)" % [index,command.layer]
		for point in points:
			if not point.is_finite() or point.length() > 12000: return "Nonfinite or unbounded vertex"
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return "Not a finite opaque cel color"
		if color.r < 0 or color.r > 1 or color.g < 0 or color.g > 1 or color.b < 0 or color.b > 1: return "Color outside normalized palette"
	return ""

func affine_residual(a: PackedVector2Array, b: PackedVector2Array) -> float:
	# Remove a general affine transform, not just translation/rotation/scale.
	# A static lightning logo that is merely stretched or sheared fails here.
	if a.size() < 4 or b.size() < 4: return -1.0
	if a.size() != b.size(): return INF
	var second := 1
	for i in range(2,a.size()):
		if a[i].distance_squared_to(a[0]) > a[second].distance_squared_to(a[0]): second = i
	var third := 1
	for i in range(2,a.size()):
		if absf((a[second]-a[0]).cross(a[i]-a[0])) > absf((a[second]-a[0]).cross(a[third]-a[0])): third = i
	var basis_a := Transform2D(a[second]-a[0],a[third]-a[0],a[0])
	if absf(basis_a.determinant()) < 0.0001: return -1.0
	var basis_b := Transform2D(b[second]-b[0],b[third]-b[0],b[0])
	var mapping := basis_b*basis_a.affine_inverse()
	var error := 0.0
	for i in range(a.size()): error = maxf(error,(mapping*a[i]).distance_to(b[i]))
	return error/maxf(a[second].distance_to(a[0]),1.0)

func transformed_matches(actual: Array, original: Array, size: float, angle: float) -> bool:
	if actual.size() != original.size(): return false
	for i in range(actual.size()):
		if actual[i].layer != original[i].layer or actual[i].points.size() != original[i].points.size(): return false
		for j in range(actual[i].points.size()):
			if not actual[i].points[j].is_equal_approx((original[i].points[j]*size).rotated(angle)): return false
	return true

func final_stroke_end(config: Resource) -> float:
	return config.leader_seconds+config.stroke_count*config.stroke_seconds+(config.stroke_count-1)*config.stroke_gap_seconds

func sample_cycle(effect: Node2D, samples: int = 41) -> Array:
	var result: Array = []
	for i in range(samples): result.append(effect.build_commands(effect.config.duration()*i/float(samples)))
	return result

func test_config() -> void:
	var defaults := Config.new()
	for spec in range_specs(defaults):
		var safe := true
		var inputs := [-99999.0,99999.0]
		if spec[3] == TYPE_FLOAT: inputs.append_array([NAN,INF,-INF])
		for input in inputs:
			var config := Config.new()
			config.set(spec[0],input)
			config.sanitize()
			var expected: float = clampf(input,spec[1],spec[2]) if is_finite(input) else defaults.get(spec[0])
			safe = safe and is_equal_approx(float(config.get(spec[0])),expected)
		check(safe,"Range and nonfinite defense: " + spec[0])
	for name in color_names(defaults):
		var config := Config.new()
		config.set(name,Color(NAN,0.2,0.3,0.5))
		config.sanitize()
		check(config.get(name) == defaults.get(name),"Invalid palette restores default: " + name)
		config.set(name,Color(-3,8,0.5,NAN))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.5,1),"Palette clamps and remains opaque: " + name)
	var duration: float = defaults.duration()
	check(is_finite(duration) and duration > final_stroke_end(defaults)+defaults.residual_seconds,"Duration includes the complete last residual and a clearing margin")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales every phase and clearing margin")

func test_phases_and_motion() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var config: Resource = effect.config
	var early: Array = effect.build_commands(config.leader_seconds*0.2)
	var later: Array = effect.build_commands(config.leader_seconds*0.8)
	var leader_early := layer_points(early,"leader_rim")
	var leader_later := layer_points(later,"leader_rim")
	check(not leader_early.is_empty() and not leader_later.is_empty(),"A thin leader is visible during descent")
	if not leader_early.is_empty() and not leader_later.is_empty():
		check(bounds(leader_later).end.y > bounds(leader_early).end.y+config.length*0.25,"Leader actively reveals downward toward the contact origin")
		check(absf(bounds(leader_later).position.y-bounds(leader_early).position.y) < config.length*0.03,"Leader reveal keeps its upper source fixed instead of translating the whole bolt")
	check(layer_shapes(early,"main_rim").is_empty() and layer_shapes(later,"contact_rim").is_empty(),"Descent precedes full stroke and contact flash")
	var at_strike: float = config.leader_seconds+config.stroke_seconds*0.35
	var strike: Array = effect.build_commands(at_strike)
	var next_strike: Array = effect.build_commands(at_strike+config.stroke_seconds+config.stroke_gap_seconds)
	check(not layer_shapes(strike,"main_rim").is_empty() and not layer_shapes(strike,"main_core").is_empty(),"Return stroke has solid rim and separate bright core")
	check(not layer_shapes(strike,"branch_rim").is_empty() and not layer_shapes(strike,"contact_rim").is_empty(),"Return stroke includes attached forks and grounded contact accents")
	check(affine_residual(layer_points(strike,"main_rim"),layer_points(next_strike,"main_rim")) > 0.0001,"Repeated strokes reroute their bends beyond any whole-shape affine transform")
	check(affine_residual(layer_points(strike,"branch_rim"),layer_points(next_strike,"branch_rim")) > 0.0001,"Fork composition genuinely reroutes between strokes")
	var gap: Array = effect.build_commands(config.leader_seconds+config.stroke_seconds+config.stroke_gap_seconds*0.5)
	check(layer_shapes(gap,"main_rim").is_empty(),"Inter-stroke gap is not an uninterrupted full bright bolt")
	check(not layer_shapes(gap,"residual_rim").is_empty(),"Inter-stroke gap retains broken charge rather than vanishing all detail")
	var tail_start := final_stroke_end(config)
	var tail_early: Array = effect.build_commands(tail_start+config.residual_seconds*0.2)
	var tail_late: Array = effect.build_commands(tail_start+config.residual_seconds*0.8)
	var fragments := layer_shapes(tail_early,"residual_rim")
	check(fragments.size() >= 2 and layer_shapes(tail_early,"main_rim").is_empty(),"Final tail is decomposed into multiple detached residuals")
	var short_fragments := not fragments.is_empty()
	for polygon in fragments: short_fragments = short_fragments and bounds(polygon).size.y < config.length*0.65
	check(short_fragments,"No residual polygon silently preserves the whole full-length bolt")
	check(layer_area(tail_late,"residual_rim") < layer_area(tail_early,"residual_rim")*0.7,"Residual charge loses area before the end, not just disappearing as a static image")
	check(effect.build_commands(config.duration()).is_empty(),"The tail fully clears at the declared duration")
	effect.free()

func on_or_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) < 0.000001: return true
	return false

func horizontal_width(polygon: PackedVector2Array, y: float) -> float:
	var intersections: Array[float] = []
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		if is_equal_approx(a.y,b.y): continue
		if y >= minf(a.y,b.y) and y < maxf(a.y,b.y):
			intersections.append(lerpf(a.x,b.x,(y-a.y)/(b.y-a.y)))
	if intersections.size() < 2: return 0.0
	intersections.sort()
	return intersections[-1]-intersections[0]

func test_fork_structure() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var config: Resource = effect.config
	for stroke in range(config.stroke_count):
		var time: float = config.leader_seconds+stroke*(config.stroke_seconds+config.stroke_gap_seconds)+config.stroke_seconds*0.35
		var commands: Array = effect.build_commands(time)
		var main := layer_shapes(commands,"main_rim")
		var forks := layer_shapes(commands,"branch_rim")
		var rooted: bool = not main.is_empty() and forks.size() >= config.branch_count
		var tapered := not forks.is_empty()
		for index in range(forks.size()):
			var fork: PackedVector2Array = forks[index]
			# Ribbons have a nonpointed root at the first/last vertex pair.
			var origin := (fork[0]+fork[-1])*0.5
			var attached := false
			for polygon in main: attached = attached or on_or_in_polygon(origin,polygon)
			for other in range(forks.size()):
				if other != index: attached = attached or on_or_in_polygon(origin,forks[other])
			rooted = rooted and attached
			var box := bounds(fork)
			var root_width := horizontal_width(fork,lerpf(box.position.y,box.end.y,0.1))
			var tip_width := horizontal_width(fork,lerpf(box.position.y,box.end.y,0.9))
			tapered = tapered and root_width > 0 and tip_width < root_width*0.6
		check(rooted,"Every primary/secondary fork is physically rooted on its parent in stroke %d" % stroke)
		check(tapered,"Forks taper toward pointed tips instead of remaining uniform hoses in stroke %d" % stroke)
	var contained := true
	for commands in sample_cycle(effect,61):
		for prefix in ["leader","main","branch","residual","spark"]:
			var rims := layer_shapes(commands,prefix+"_rim")
			for core in layer_shapes(commands,prefix+"_core"):
				var within_a_rim := false
				for rim in rims:
					var within := true
					for point in core: within = within and on_or_in_polygon(point,rim)
					within_a_rim = within_a_rim or within
				contained = contained and within_a_rim
	check(contained,"White cores stay contained within their colored electrical silhouettes through all phases")
	effect.free()

func test_parameters_and_determinism() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var baseline: Array = sample_cycle(effect)
	check(baseline == sample_cycle(effect),"Same seed and time reconstruct the exact complete cycle")
	seed(92731)
	var expected_rng := randi()
	seed(92731)
	sample_cycle(effect)
	check(randi() == expected_rng,"Rendering commands never consume the shared gameplay RNG")
	effect.config.seed_value += 1
	check(baseline != sample_cycle(effect),"Seed changes electrical routing and fragments")
	effect.configure(Config.new())
	var times := [effect.config.leader_seconds*0.6,effect.config.leader_seconds+effect.config.stroke_seconds*0.35,final_stroke_end(effect.config)+effect.config.residual_seconds*0.3]
	for time in times:
		effect.configure(Config.new())
		var original: Array = effect.build_commands(time)
		effect.config.size = 2
		check(transformed_matches(effect.build_commands(time),original,2,0),"Uniform size covers every layer at phase %.3f" % time)
		effect.configure(Config.new())
		effect.config.direction_degrees = 37
		check(transformed_matches(effect.build_commands(time),original,1,deg_to_rad(37)),"Direction rotates every layer around contact at phase %.3f" % time)
		effect.configure(Config.new())
		effect.config.duration_scale = 2
		check(original == effect.build_commands(time*2),"Duration scale preserves normalized geometry at phase %.3f" % time)
	for spec in range_specs(Config.new()):
		if spec[0] in ["size","direction_degrees","duration_scale"]: continue
		var config := Config.new()
		config.set(spec[0],spec[1])
		effect.configure(config)
		var minimum: Array = sample_cycle(effect)
		config.set(spec[0],spec[2])
		effect.configure(config)
		check(minimum != sample_cycle(effect),"Advertised parameter produces observable geometry/timing change: " + spec[0])
	for toggle in TOGGLES:
		var config := Config.new()
		for name in TOGGLES: config.set(name,name == toggle)
		effect.configure(config)
		var present := false
		for commands in sample_cycle(effect,61): present = present or not commands.is_empty()
		check(present,"Each composition layer works without its siblings: " + toggle)
	for toggle in TOGGLES: effect.config.set(toggle,false)
	var any_geometry := false
	for commands in sample_cycle(effect): any_geometry = any_geometry or not commands.is_empty()
	check(not any_geometry,"All composition layers may be disabled")
	var colored := Config.new()
	var custom := Color(0.17,0.46,0.63,1)
	for name in color_names(colored): colored.set(name,custom)
	effect.configure(colored)
	var matches := true
	for commands in sample_cycle(effect):
		for command in commands: matches = matches and command.color == custom
	check(matches,"All emitted colors come from the configurable palette")
	effect.configure(Config.new())
	effect.config.branch_count = 0
	var branches := false
	for commands in sample_cycle(effect): branches = branches or not layer_shapes(commands,"branch_rim").is_empty()
	check(not branches,"Zero branch count removes every fork without hiding the main strike")
	effect.free()

func test_lifecycle() -> void:
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 3,"Configure deep-copies before sanitization")
	effect.config.core_color = Color.RED
	check(source.core_color == Config.new().core_color,"Caller Resource retains its original palette")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores exact defaults")
	check(effect.get_child_count() == 0 and effect.build_commands().is_empty(),"Reusable component is dormant and has no actor or gameplay dependencies")
	for age in [-1.0,-0.001,effect.config.duration(),999.0,INF,NAN]:
		check(effect.build_commands(age).is_empty(),"No geometry at invalid or expired time %s" % age)
	effect.finished.connect(func(): finish_count += 1)
	effect.play()
	check(effect.playing and effect.age == 0,"Play starts an independent finite timeline")
	effect._process(0.1)
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative and nonfinite delta cannot poison the clock")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Completion emits once and clears all layers")
	effect.play()
	effect.seek(0.1)
	effect._process(10)
	check(not effect.playing and is_equal_approx(effect.age,0.1) and finish_count == 1,"Seek pauses automatic advancement without a finished signal")
	for invalid_age in [NAN,INF,-INF,-1.0]:
		effect.seek(invalid_age)
		check(effect.build_commands().is_empty(),"Invalid seek is safely dormant: %s" % invalid_age)
	for i in range(30): effect.play(); effect._process(effect.config.duration()+1)
	check(finish_count == 31 and effect.get_child_count() == 0,"Repeated play completes without accumulating nodes")
	effect.play()
	effect._process(0.2)
	effect.stop()
	effect.stop()
	effect._process(10)
	check(not effect.playing and effect.build_commands().is_empty() and finish_count == 31,"Repeated manual stop clears without spurious completion")
	effect.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8197
	for variant in range(18):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config):
				var candidate: float = spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2]))
				config.set(spec[0],int(round(candidate)) if spec[3] == TYPE_INT else candidate)
			config.seed_value = variant*4127-18000
		effect.configure(config)
		var problem := ""
		for frame in range(161):
			var age: float = effect.config.duration()*frame/160.0
			var commands: Array = effect.build_commands(age)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite opaque bounded triangulation for 161 poses in variant %d: %s" % [variant,problem])
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		config.intensity = 2
		config.stroke_count = 5
		config.branch_count = 7
		effect.configure(config)
		var boundaries := [0.0,config.leader_seconds,final_stroke_end(config),final_stroke_end(config)+config.residual_seconds,config.duration()/multiplier]
		for i in range(config.stroke_count):
			var beginning: float = config.leader_seconds+i*(config.stroke_seconds+config.stroke_gap_seconds)
			boundaries.append(beginning)
			boundaries.append(beginning+config.stroke_seconds)
		var problem := ""
		for boundary in boundaries:
			for epsilon in [0.0,0.001,0.00001,0.0000001,0.000000001,0.00000000001]:
				for side in [-1.0,1.0]:
					var age: float = (boundary+side*epsilon)*multiplier
					var current := geometry_problem(effect.build_commands(age))
					if not current.is_empty(): problem = "%s at %.17f" % [current,age]
		check(problem.is_empty(),"Dense phase-boundary geometry at time multiplier %.2f: %s" % [multiplier,problem])
	effect.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var elapsed := -0.35
	var previous_segment := -1
	var seen_segments := {}
	var problem := ""
	var resets := 0
	# This is the shared laboratory's fixed 60 Hz viewport-capture clock.
	for frame in range(StudyLab.CAPTURE_FRAMES):
		var segment := 0 if frame < 300 else (1 if frame < 540 else 2)
		if segment != previous_segment:
			previous_segment = segment
			elapsed = -0.35
			seen_segments[segment] = true
		if segment == 0 and elapsed >= effect.config.duration()+0.55:
			elapsed = -0.35
			resets += 1
		elapsed += (1.0 if segment == 0 else 0.5)/60.0
		var current := geometry_problem(effect.build_commands(elapsed))
		if not current.is_empty(): problem = "%s at capture frame %d" % [current,frame]
	check(problem.is_empty(),"Exact capture-frame geometry triangulates: " + problem)
	check(seen_segments.size() == 3 and resets >= 1,"Capture covers normal repeats, light slow and pure-effect slow passes")
	check(elapsed > effect.config.duration() and effect.build_commands(elapsed).is_empty(),"Last slow capture pass includes full residual clearance")
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
	lab.effect.set_process(false)
	var source_before := values(lab.effect.settings)
	check(lab.effect.config != lab.effect.settings,"Lab configuration is isolated from Inspector settings")
	lab.set_parameter("size",3.0)
	check(lab.effect.config.size == 3 and lab.status.text.contains("VIEW %.2f×" % lab.fit_scale),"Automatic fitting reports view scale without rewriting effect size")
	lab.reset_defaults()
	lab.step(0.5)
	var paused_age: float = lab.elapsed
	lab.toggle_play()
	lab._process(0.1)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age),"Pause freezes the timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age+1.0/60.0),"Frame step advances once and remains paused")
	key(lab,KEY_R)
	check(lab.playing and is_equal_approx(lab.elapsed,-0.35),"Replay recovers from interrupted playback")
	key(lab,KEY_S)
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter speed changes only the playback clock")
	key(lab,KEY_S)
	key(lab,KEY_B)
	key(lab,KEY_B,true)
	check(lab.light_background,"Background toggles once and ignores echoed input")
	key(lab,KEY_E)
	check(lab.effect_only and not lab._has_host(),"Effect-only preview hides all demonstration hosts")
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			control.value = control.max_value
			check(is_equal_approx(float(lab.effect.config.get(name)),control.max_value) and is_equal_approx(lab.elapsed,-0.35) and lab.playing,"Numeric controls update and replay: " + name)
		elif control is CheckBox:
			control.button_pressed = not control.button_pressed
			check(lab.effect.config.get(name) == control.button_pressed,"Boolean controls update: " + name)
	for name in lab.color_controls:
		var color := Color(0.17,0.46,0.63,1)
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color and is_equal_approx(lab.elapsed,-0.35),"Live palette updates and replays: " + name)
	check(values(lab.effect.settings) == source_before,"Live edits preserve the Inspector Resource")
	var before := values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	lab.set_color("unsupported",Color.RED)
	check(values(lab.effect.config) == before,"Unknown UI parameter names are ignored")
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and lab.playback_speed == 1 and not lab.light_background and not lab.effect_only,"Reset restores exact component and presentation defaults")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(lab.settings_panel.visible and editor.has_focus(),"Parameters panel supports numeric editing")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes interrupted editing and releases input focus")
	lab.toggle_parameters()
	await process_frame
	editor.grab_focus()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not editor.has_focus(),"Repeated panel close releases numeric input focus")
	var popup: PopupPanel = lab.color_controls["core_color"].get_popup()
	lab.toggle_parameters()
	popup.show()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not popup.visible,"Panel close explicitly dismisses a palette popup")
	lab.toggle_parameters()
	popup.show()
	lab._input(escape)
	check(not lab.settings_panel.visible and not popup.visible,"Escape dismisses a palette popup and its parent panel")
	var node_count: int = lab.get_child_count()
	for i in range(30):
		lab.reset_defaults()
		lab.step(0.4)
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == node_count and lab.playing and is_equal_approx(lab.elapsed,-0.35),"Repeated interrupted replay never accumulates nodes")
	lab.free()

func run() -> void:
	test_config()
	test_phases_and_motion()
	test_fork_structure()
	test_parameters_and_determinism()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_LIGHTNING: %d checks, %d failures" % [checks,failures])
	quit(failures)
