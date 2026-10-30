extends SceneTree
## Analytic contracts. Real normal-speed viewport review remains a separate gate.
const Config = preload("res://scripts/vfx/cel/heavy_impact_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/heavy_impact.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/heavy_impact_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/study_lab.gd")
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
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.type == TYPE_COLOR:
			result.append(property.name)
	return result

func geometry_problem(commands: Array) -> String:
	if commands.size() > 128: return "Unbounded command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 128: return "Invalid vertex count"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d" % index
		for point in points:
			if not point.is_finite() or point.length() > 6000: return "Nonfinite or unbounded vertex"
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return "Not a finite opaque cel color"
	return ""

func transformed_matches(actual: Array, original: Array, size: float, angle: float) -> bool:
	if actual.size() != original.size(): return false
	for i in range(actual.size()):
		if actual[i].points.size() != original[i].points.size(): return false
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
		check(config.get(name) == defaults.get(name),"Invalid color restores default: " + name)
		config.set(name,Color(-3,8,0.5,NAN))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.5,1),"Palette clamps and remains opaque: " + name)
	var duration: float = defaults.duration()
	check(duration > defaults.dust_seconds and duration > defaults.shockwave_seconds,"Lifetime covers the staggered dust and shockwave")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales complete effect")

func test_effect() -> void:
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 3,"Configure deep-copies before validation")
	effect.config.core_color = Color.RED
	check(source.core_color == Config.new().core_color,"Palette edits preserve caller resource")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores defaults")
	check(effect.get_child_count() == 0 and effect.build_commands().is_empty(),"Reusable scene is dormant, actor-free and prop-free")
	for age in [-1.0,-0.001,effect.config.duration(),999.0,INF,NAN]:
		check(effect.build_commands(age).is_empty(),"No geometry outside lifetime: %s" % age)
	check(not effect.build_commands(0).is_empty(),"Contact flash begins immediately without a built-in windup")
	var baseline: Array = effect.build_commands(0.12).duplicate(true)
	check(baseline == effect.build_commands(0.12),"Same age and seed yield identical geometry")
	effect.config.seed_value += 1
	check(baseline != effect.build_commands(0.12),"Seed changes dust and chip composition")
	effect.configure(Config.new())
	effect.config.direction_degrees = 90
	check(transformed_matches(effect.build_commands(0.12),baseline,1,PI/2),"Direction rotates every layer around contact origin")
	effect.configure(Config.new())
	effect.config.size = 2
	check(transformed_matches(effect.build_commands(0.12),baseline,2,0),"Size scales every layer equally")
	effect.configure(Config.new())
	effect.config.duration_scale = 2
	check(baseline == effect.build_commands(0.24),"Duration scaling preserves the exact normalized pose")
	var toggles := ["show_flash","show_shockwave","show_dust","show_chips"]
	for toggle in toggles:
		effect.configure(Config.new())
		for name in toggles: effect.config.set(name,name == toggle)
		if toggle != "show_chips": effect.config.chip_count = 0
		var at_age: float = 0.025 if toggle == "show_flash" else (0.12 if toggle == "show_shockwave" else 0.35)
		check(not effect.build_commands(at_age).is_empty(),"Layer works without its siblings: " + toggle)
		check(effect.build_commands(at_age) != effect.build_commands(at_age+0.025),"Layer has intrinsic time-dependent geometry: " + toggle)
	effect.configure(Config.new())
	for toggle in toggles: effect.config.set(toggle,false)
	effect.config.show_chips = true
	check(not effect.build_commands(0.12).is_empty(),"Chips are independently available")
	effect.config.chip_count = 0
	check(effect.build_commands(0.12).is_empty(),"All composition layers may be disabled")
	effect.configure(Config.new())
	effect.finished.connect(func(): finish_count += 1)
	effect.play()
	check(effect.playing and effect.age == 0,"Play starts an immediate one-shot")
	effect._process(0.1)
	check(is_equal_approx(effect.age,0.1),"One-shot advances with delta")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative and nonfinite delta cannot poison the clock")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Completion emits once and clears all layers")
	effect.play()
	effect.seek(0.1)
	effect._process(10)
	check(not effect.playing and is_equal_approx(effect.age,0.1) and finish_count == 1,"Seek is manual and does not emit completion")
	effect.seek(NAN)
	check(effect.build_commands().is_empty(),"Invalid seek is safely dormant")
	for i in range(50): effect.play(); effect._process(effect.config.duration()+1)
	check(finish_count == 51 and effect.get_child_count() == 0,"Repeated playback completes without accumulating nodes")
	effect.play()
	effect._process(0.3)
	effect.stop()
	effect.stop()
	effect._process(10)
	check(not effect.playing and effect.build_commands().is_empty() and finish_count == 51,"Repeated manual stop clears without a spurious finished signal")
	effect.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8197
	for variant in range(18):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config):
				config.set(spec[0],spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2])))
			config.seed_value = variant*4127
		effect.configure(config)
		var problem := ""
		for frame in range(181):
			var age: float = effect.config.duration()*frame/180.0
			var commands: Array = effect.build_commands(age)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite, opaque, bounded triangulation for 181 poses in variant %d: %s" % [variant,problem])
		effect.seek(effect.config.duration())
		check(effect.build_commands().is_empty(),"Every legal configuration clears at duration")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		config.intensity = 2
		effect.configure(config)
		var boundaries := [0.0,0.015,0.025,config.flash_seconds,config.flash_seconds*3.5,config.shockwave_seconds+0.015,config.dust_seconds,config.dust_seconds+0.13,1.08,config.duration()/multiplier]
		var problem := ""
		for boundary in boundaries:
			for epsilon in [0.0,1e-2,1e-3,1e-4,1e-5,1e-6,1e-7,1e-8,1e-9,1e-10,1e-12,1e-14]:
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
	# Mirror the host's fixed capture clock, including the normal-speed repeats.
	for frame in range(Lab.CAPTURE_FRAMES):
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
	check(elapsed > effect.config.duration() and effect.build_commands(elapsed).is_empty(),"Final slow capture pass includes complete dust dissipation")
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
	check(lab.effect.config != lab.effect.settings,"Lab runtime configuration is isolated from Inspector settings")
	check(lab._has_host() and lab.status.text.contains("GENERIC CONTACT HOST"),"Default direction has the honest generic contact host")
	for direction in [-180.0,-90.0,37.0,180.0]:
		lab.set_parameter("direction_degrees",direction)
		check(not lab._has_host() and lab.status.text.contains("EFFECT ONLY") and lab.pass_label.text == "PURE EFFECT","Rotated effect hides the misleading unrotated host: %.0f degrees" % direction)
	lab.set_parameter("direction_degrees",0.0)
	check(lab._has_host(),"Returning to zero direction restores the contact host")
	lab.set_parameter("size",3.0)
	check(lab.status.text.contains("VIEW %.2f×" % lab.fit_scale),"Status exposes automatic view scale separately from configured size")
	check(lab.effect.config.size == 3.0,"Automatic fitting does not rewrite the configured size")
	lab.reset_defaults()
	lab.replay()
	lab.step(0.5)
	var paused_age: float = lab.elapsed
	lab.toggle_play()
	lab._process(0.1)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age),"Pause holds the timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age+1.0/60.0),"Frame step advances once and stays paused")
	lab.replay()
	check(lab.playing and is_equal_approx(lab.elapsed,-0.35),"Replay recovers from paused mid-effect")
	lab.toggle_speed()
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter speed changes playback clock only")
	lab.toggle_speed()
	key(lab,KEY_B)
	key(lab,KEY_B,true)
	check(lab.light_background,"Background toggles once and ignores echoed keys")
	key(lab,KEY_E)
	check(lab.effect_only and not lab._has_host(),"Effect-only preview removes the generic host")
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
	check(values(lab.effect.settings) == source_before,"All parameter edits preserve Inspector resource")
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
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes interrupted editing and releases focus")
	lab.toggle_parameters()
	await process_frame
	editor.grab_focus()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not editor.has_focus(),"Closing the panel repeatedly also releases focus")
	var popup: PopupPanel = lab.color_controls["core_color"].get_popup()
	lab.toggle_parameters()
	popup.show()
	check(popup.visible,"Palette popup can be opened independently for the close contract")
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not popup.visible,"Direct panel close explicitly closes a palette popup")
	lab.toggle_parameters()
	popup.show()
	lab._input(escape)
	check(not lab.settings_panel.visible and not popup.visible,"Escape also closes a palette popup with the panel")
	var node_count: int = lab.get_child_count()
	for i in range(30):
		lab.reset_defaults()
		lab.step(0.4)
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == node_count and lab.playing and is_equal_approx(lab.elapsed,-0.35),"Repeated interrupted replay does not accumulate nodes")
	lab.free()

func run() -> void:
	test_config()
	test_effect()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_HEAVY_IMPACT: %d checks, %d failures" % [checks,failures])
	quit(failures)
