extends SceneTree
## Analytic and lifecycle contracts; real-motion visual review remains separate.
const Config = preload("res://scripts/vfx/cel/fire_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/fire.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/fire_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/fire_lab.gd")
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

func geometry_problem(commands: Array) -> String:
	if commands.size() > 256: return "Unbounded active command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color") or not command.has("layer"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 512: return "Invalid vertex count"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d (%s)" % [index,command.layer]
		for point in points:
			if not point.is_finite() or point.length() > 12000: return "Nonfinite or unbounded vertex"
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return "Not a finite opaque cel color"
	return ""

func layer_points(commands: Array, layer: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for command in commands:
		if command.layer == layer: points.append_array(command.points)
	return points

func layer_shapes(commands: Array, layer: String) -> Array:
	var result: Array = []
	for command in commands:
		if command.layer == layer: result.append(command.points)
	return result

func affine_residual(a: PackedVector2Array, b: PackedVector2Array) -> float:
	# A frozen logo under arbitrary translation/rotation/scale/shear has zero
	# residual. Three broad noncollinear anchors define the entire affine map.
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
	check(is_finite(duration) and duration > 0,"Default finite fire cycle has a positive lifetime")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales ignition, sustain and complete tail")

func test_motion() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var first: Array = effect.build_commands(0.45,INF)
	var second: Array = effect.build_commands(0.73,INF)
	check(first == effect.build_commands(0.45,INF),"Seed and exact time produce deterministic sustained fire")
	for layer in ["rim","body","channel","core"]:
		var a := layer_points(first,layer)
		var b := layer_points(second,layer)
		check(a.size() >= 4 and b.size() >= 4,"Sustained layer is present: " + layer)
		check(affine_residual(a,b) > 0.0001,"Layer boundary changes beyond a whole-logo affine transform: " + layer)
	var body_a: PackedVector2Array = layer_shapes(first,"body")[1]
	var body_b: PackedVector2Array = layer_shapes(second,"body")[1]
	var channel_a: PackedVector2Array = layer_shapes(first,"channel")[1]
	var channel_b: PackedVector2Array = layer_shapes(second,"channel")[1]
	var relative_change := 0.0
	for row in [5,10,15,20]:
		var ratio_a: float = channel_a[row].distance_to(channel_a[-1-row])/body_a[row].distance_to(body_a[-1-row])
		var ratio_b: float = channel_b[row].distance_to(channel_b[-1-row])/body_b[row].distance_to(body_b[-1-row])
		relative_change = maxf(relative_change,absf(ratio_a-ratio_b))
	check(relative_change > 0.0001,"Interior channel width moves independently relative to the enclosing body profile")
	var config := Config.new()
	config.seed_value += 1
	effect.configure(config)
	check(first != effect.build_commands(0.45,INF),"Seed changes intrinsic flame flow and shedding layout")
	config = Config.new()
	config.direction_degrees = 90
	effect.configure(config)
	check(transformed_matches(effect.build_commands(0.45,INF),first,1,PI/2),"Direction rotates all attached and detached layers")
	config = Config.new()
	config.size = 2
	effect.configure(config)
	check(transformed_matches(effect.build_commands(0.45,INF),first,2,0),"Size scales the complete fire without changing motion phase")
	config = Config.new()
	config.duration_scale = 2
	effect.configure(config)
	check(first == effect.build_commands(0.9,INF),"Duration scale preserves normalized sustained geometry")
	config = Config.new()
	config.flow_speed = 0
	effect.configure(config)
	for layer in ["rim","body","channel","core"]:
		check(layer_points(effect.build_commands(0.4,INF),layer) == layer_points(effect.build_commands(0.9,INF),layer),"Zero flow freezes intrinsic attached motion without a whole-effect clock leak: " + layer)
	var toggles := ["show_body","show_channels","show_core","show_detached","show_embers"]
	for toggle in toggles:
		config = Config.new()
		for name in toggles: config.set(name,name == toggle)
		effect.configure(config)
		var present := false
		for time in [0.4,0.7,1.0]:
			if not effect.build_commands(time,INF).is_empty(): present = true
		check(present,"Layer works without its siblings: " + toggle)
	for toggle in toggles: effect.config.set(toggle,false)
	check(effect.build_commands(0.7,INF).is_empty(),"All independent fire layers can be disabled")
	effect.configure(Config.new())
	for time in [10.0,3600.0,86400.0]:
		var commands: Array = effect.build_commands(time,INF)
		check(not commands.is_empty() and geometry_problem(commands).is_empty(),"Long-held fire uses bounded finite active geometry at %.0f seconds" % time)
		check(commands == effect.build_commands(time,INF),"Long-held phase remains deterministic at %.0f seconds" % time)
	effect.free()

func test_lifecycle() -> void:
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 3,"Configuration is copied before validation")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores exact defaults")
	check(not effect.playing and effect.build_commands().is_empty() and effect.get_child_count() == 0,"Component starts dormant, host-free and prop-free")
	for invalid_age in [-1.0,INF,NAN]: check(effect.build_commands(invalid_age,-1).is_empty(),"Invalid age has no geometry")
	check(effect.build_commands(0.5,NAN).is_empty(),"Invalid explicit release time does not poison geometry")
	check(effect.build_commands(0.5,-2).is_empty(),"Unsupported negative release override is empty")
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"Normal terminal age equals complete configured lifetime")
	effect.finished.connect(func(): finish_count += 1)
	effect.release()
	check(not effect.playing and effect.release_at < 0,"Dormant release is ignored")
	effect.play()
	effect._process(0.1)
	check(effect.playing and is_equal_approx(effect.age,0.1),"Ignition advances after play")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative/nonfinite delta cannot rewind or corrupt ignition")
	effect._process(effect.get_end_time()+1)
	effect._process(1)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Finite cycle clears and emits completion once")
	var completed_release: float = effect.release_at
	effect.release()
	check(effect.release_at == completed_release and not effect.playing,"Release after completion does not restart the tail")
	effect.play(true)
	check(effect.get_end_time() == INF and effect.release_at < 0,"Held play resets release and has no automatic terminal age")
	effect._process(10)
	check(effect.playing and not effect.build_commands().is_empty() and finish_count == 1,"Held fire stays active beyond the finite default duration")
	effect.release()
	var first_release: float = effect.release_at
	var end_time: float = effect.get_end_time()
	check(is_equal_approx(first_release,10) and is_finite(end_time) and end_time > first_release,"Release records actual absolute time and establishes a finite tail")
	effect._process(0.1)
	effect.release()
	check(effect.release_at == first_release and effect.get_end_time() == end_time,"Repeated release cannot refresh or extend the tail")
	effect._process(end_time+1)
	check(not effect.playing and finish_count == 2 and effect.build_commands().is_empty(),"Released held fire finishes exactly once")
	for early in [0.04,0.65]:
		effect.seek(early,-1,true)
		var before: Array = effect.build_commands().duplicate(true)
		effect.release()
		check(not effect.playing and effect.release_at == early,"Release preserves pause while recording ignition/sustain time %.2f" % early)
		check(before == effect.build_commands(),"Releasing does not jump the instantaneous envelope at %.2f" % early)
		var terminal: float = effect.get_end_time()
		check(effect.build_commands(terminal,early).is_empty(),"Early release clears by its reported terminal age")
		var frozen_age: float = effect.age
		effect._process(1)
		check(effect.age == frozen_age,"Released seek remains manually paused")
	effect.seek(effect.config.duration()-0.1,-1,false)
	var auto_end: float = effect.get_end_time()
	effect.release()
	check(effect.get_end_time() == auto_end,"Late release cannot restart automatic extinction")
	effect.seek(2.0,1.8,false)
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"A late explicit non-held seek release is clamped to automatic release")
	check(effect.build_commands(1.9,1.8) == effect.build_commands(1.9,-1),"Finite late override cannot render a restarted flame")
	effect.seek(0.5,0.3,true)
	check(effect.build_commands() == effect.build_commands(0.5,0.3),"Seek reconstructs explicit realtime release state")
	check(effect.build_commands(0.5,-1) != effect.build_commands(0.5,0.3),"Explicit -1 overrides node release with the finite automatic schedule")
	effect.play()
	check(effect.age == 0 and effect.release_at < 0 and is_equal_approx(effect.get_end_time(),effect.config.duration()),"Replay clears previous explicit release and held state")
	effect.stop()
	effect.stop()
	check(not effect.playing and effect.build_commands().is_empty() and finish_count == 2,"Immediate stop is repeatable and silently clears")
	effect.seek(NAN)
	check(effect.build_commands().is_empty(),"Invalid seek is dormant")
	for repeat in range(30): effect.play(); effect._process(effect.config.duration()+1)
	check(finish_count == 32 and effect.get_child_count() == 0,"Repeated complete cycles keep stable node count")
	effect.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 73127
	for variant in range(18):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config):
				config.set(spec[0],spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2])))
			config.seed_value = variant*4793
		effect.configure(config)
		var problem := ""
		for frame in range(121):
			var age: float = effect.config.duration()*frame/120.0
			var commands: Array = effect.build_commands(age,-1)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age,-1): problem = "Nondeterministic frame"; break
		check(problem.is_empty(),"Finite opaque triangulation for 121 poses in variant %d: %s" % [variant,problem])
		check(effect.build_commands(effect.config.duration(),-1).is_empty(),"Every finite legal configuration clears at its declared duration")
		check(geometry_problem(effect.build_commands(3600,INF)).is_empty(),"Every legal configuration has bounded held geometry")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		effect.configure(config)
		var auto_release: float = (config.ignition_seconds+config.sustain_seconds)*multiplier
		var releases := [-1.0,0.03*multiplier,0.65*multiplier,1.5*multiplier]
		for release_time in releases:
			var actual_release: float = auto_release if release_time < 0 else release_time
			var terminal: float = actual_release+(config.release_seconds+config.ember_seconds+0.04)*multiplier
			effect.seek(0.1,release_time,release_time >= 0)
			check(is_equal_approx(effect.get_end_time(),terminal),"Reported end uses realtime release plus scaled tail")
			var boundaries: Array = [0.0,config.ignition_seconds*multiplier,actual_release,actual_release+config.release_seconds*multiplier,terminal]
			for tongue in range(3):
				boundaries.append(effect._first_birth(tongue)*multiplier)
				boundaries.append((effect._first_birth(tongue)+effect._period(tongue))*multiplier)
			var problem := ""
			for boundary in boundaries:
				for epsilon in [0.0,1e-3,1e-5,1e-7,1e-9,1e-11]:
					for side in [-1.0,1.0]:
						var age: float = boundary+side*epsilon
						var current := geometry_problem(effect.build_commands(age,release_time))
						if not current.is_empty(): problem = "%s at %.17f" % [current,age]
			check(problem.is_empty(),"Ignition/release/detach boundaries at scale %.2f release %.2f: %s" % [multiplier,release_time,problem])
			check(effect.build_commands(terminal,release_time).is_empty(),"Early and normal release end fully empty")
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
	var source_before: Dictionary = values(lab.effect.settings)
	check(not lab.held_sustain and lab.released_at < 0 and not lab.floor_host,"Fire lab begins as finite generic emitter, not a gameplay burn")
	key(lab,KEY_H)
	key(lab,KEY_H,true)
	check(lab.held_sustain and lab.effect.get_end_time() == INF,"Hold toggle is reflected in component state and ignores echoes")
	lab.step(5)
	check(lab.elapsed > lab.effect.config.duration() and lab.effect.get_end_time() == INF,"Held preview survives beyond the finite cycle")
	key(lab,KEY_SPACE)
	var held_age: float = lab.elapsed
	lab._process(0.1)
	check(not lab.playing and lab.elapsed == held_age,"Pause holds a sustained flame")
	key(lab,KEY_F)
	var first_release: float = lab.released_at
	var first_end: float = lab.effect.get_end_time()
	check(not lab.playing and first_release == held_age and is_finite(first_end),"Manual release preserves pause and records the actual held age")
	key(lab,KEY_RIGHT)
	key(lab,KEY_F)
	check(lab.released_at == first_release and lab.effect.get_end_time() == first_end,"Repeated release and frame stepping cannot extend the tail")
	lab.replay()
	check(lab.playing and lab.held_sustain and lab.released_at < 0 and is_equal_approx(lab.elapsed,-0.35),"Replay clears release but retains selected hold mode")
	lab.set_hold_sustain(false)
	lab.step(lab.effect.config.duration()+0.1)
	var normal_end: float = lab.effect.get_end_time()
	lab.trigger_release()
	check(lab.released_at < 0 and lab.effect.get_end_time() == normal_end,"Late finite release never resurrects or extends extinguishing fire")
	lab.reset_defaults()
	var full_fit: float = lab.fit_scale
	lab.set_hold_sustain(true)
	lab.step(0.39)
	lab.trigger_release()
	lab._fit_effect()
	check(is_equal_approx(lab.fit_scale,full_fit),"Framing samples the full finite cycle rather than a previous early-release tail")
	lab.reset_defaults()
	key(lab,KEY_S)
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter playback scales only preview time")
	key(lab,KEY_B)
	key(lab,KEY_E)
	check(lab.light_background and lab.effect_only,"Background and source-guide controls are independent")
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			control.value = control.max_value
			check(is_equal_approx(float(lab.effect.config.get(name)),control.max_value) and is_equal_approx(lab.elapsed,-0.35),"Numeric UI sanitizes and replays: " + name)
		elif control is CheckBox:
			control.button_pressed = not control.button_pressed
			check(lab.effect.config.get(name) == control.button_pressed,"Layer UI updates independently: " + name)
	for name in lab.color_controls:
		var color := Color(0.21,0.43,0.67,1)
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color,"Palette UI updates: " + name)
	check(values(lab.effect.settings) == source_before,"UI never mutates Inspector resource")
	var before: Dictionary = values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	lab.set_color("unsupported",Color.RED)
	check(values(lab.effect.config) == before,"Unsupported UI names are no-ops")
	lab.set_hold_sustain(true)
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and not lab.held_sustain and lab.released_at < 0 and lab.playback_speed == 1 and not lab.effect_only,"Reset restores finite mode and exact defaults")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(),"Numeric editor takes focus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab._input(escape)
	check(not editor.has_focus() and not lab.settings_panel.visible,"Escape closes interrupted editing and releases focus")
	lab.toggle_parameters()
	var popup: PopupPanel = lab.color_controls["core_color"].get_popup()
	popup.show()
	lab.toggle_parameters()
	check(not popup.visible and not lab.settings_panel.visible,"Panel close also closes palette popup")
	var count: int = lab.get_child_count()
	for repeat in range(20):
		lab.set_hold_sustain(true)
		lab.step(0.6)
		lab.trigger_release()
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == count and lab.playing and lab.released_at < 0,"Repeated held/released/interrupted cycles do not accumulate nodes")
	lab.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var elapsed := -0.35
	var released_at := -1.0
	var previous_segment := -1
	var seen := {}
	var problem := ""
	for frame in range(Lab.FIRE_CAPTURE_FRAMES):
		var segment: int = frame/360
		if segment != previous_segment:
			previous_segment = segment
			elapsed = -0.35
			released_at = -1.0
			seen[segment] = true
		if segment == 0 and elapsed >= effect.config.duration()+0.55: elapsed = -0.35
		elapsed += (1.0 if segment == 0 else 0.5)/60.0
		if segment == 2 and elapsed >= 1.5 and released_at < 0: released_at = 1.5
		effect.seek(elapsed,released_at,segment == 2)
		var current := geometry_problem(effect.build_commands())
		if not current.is_empty(): problem = "%s at frame %d" % [current,frame]
	check(Lab.FIRE_CAPTURE_FRAMES == 1080 and seen.size() == 3,"Capture is the declared 18-second normal/light/held-release sequence")
	check(problem.is_empty(),"Every exact 1080-frame viewport capture pose triangulates: " + problem)
	effect.seek(elapsed,released_at,true)
	check(released_at == 1.5 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(),"Final capture pass includes held release and complete last-ember extinction")
	effect.free()

func run() -> void:
	test_config()
	test_motion()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_FIRE: %d checks, %d failures" % [checks,failures])
	quit(failures)
