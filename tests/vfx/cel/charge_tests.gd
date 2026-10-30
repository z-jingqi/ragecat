extends SceneTree
## Independent cel charge contracts. Real viewport review is a separate check.
const Lines = preload("res://scripts/vfx/cel/gathering_lines.gd")
const Orb = preload("res://scripts/vfx/cel/pulsing_orb.gd")
const LinesConfig = preload("res://scripts/vfx/cel/gathering_lines_config.gd")
const OrbConfig = preload("res://scripts/vfx/cel/pulsing_orb_config.gd")
const LinesScene = preload("res://scenes/vfx/cel/gathering_lines.tscn")
const OrbScene = preload("res://scenes/vfx/cel/pulsing_orb.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/charge_lab.gd")
const LabScene = preload("res://scenes/vfx_lab/cel/charge_lab.tscn")
const COLORS := ["core_color","body_color","shade_color"]
var checks := 0
var failures := 0

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

func scaled_commands(actual: Array, baseline: Array, multiplier: float) -> bool:
	if actual.size() != baseline.size(): return false
	for i in range(actual.size()):
		if actual[i].color != baseline[i].color or actual[i].points.size() != baseline[i].points.size(): return false
		for j in range(actual[i].points.size()):
			if not actual[i].points[j].is_equal_approx(baseline[i].points[j]*multiplier): return false
	return true

func geometry_problem(commands: Array, limit: int) -> String:
	if commands.size() > limit: return "Unbounded command count"
	for i in range(commands.size()):
		var command: Dictionary = commands[i]
		if command.keys().size() != 2 or not command.has("points") or not command.has("color"): return "Unexpected command schema"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 256: return "Invalid contour size"
		for point in points:
			if not point.is_finite() or point.length() > 2200: return "Unbounded point"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable plane %d" % i
		var color: Color = command.color
		if color.a != 1.0: return "Cel planes must be opaque"
		for channel in [color.r,color.g,color.b]:
			if not is_finite(channel) or channel < 0 or channel > 1: return "Invalid color"
	return ""

func test_configs() -> void:
	for script in [LinesConfig,OrbConfig]:
		var defaults: Resource = script.new()
		for spec in script.SPECS:
			for input in [-1e6,1e6,NAN,INF,-INF]:
				var config: Resource = script.new()
				config.set(spec[0],input)
				config.sanitize()
				var valid := true
				for bound in script.SPECS:
					var value: float = config.get(bound[0])
					valid = valid and is_finite(value) and value >= bound[1] and value <= bound[2]
				check(valid,"All finite ranges after hostile input: %s=%s" % [spec[0],input])
				var snapshot := values(config)
				config.sanitize()
				check(snapshot == values(config),"Sanitize remains idempotent: " + spec[0])
		for name in COLORS:
			for color in [Color(NAN,0,0),Color(0,INF,0),Color(0,0,-INF)]:
				var config: Resource = script.new()
				config.set(name,color)
				config.sanitize()
				check(config.get(name) == defaults.get(name),"Invalid color returns default: " + name)
			var config: Resource = script.new()
			config.set(name,Color(-3,5,0.5,NAN))
			config.sanitize()
			check(config.get(name) == Color(0,1,0.5,1),"Palette is clamped and opaque: " + name)
	var lines := LinesConfig.new()
	lines.line_count = 1000000
	lines.seed = -23
	lines.spawn_radius_min = 300
	lines.spawn_radius_max = 20
	lines.end_radius = 200
	lines.length_min = 80
	lines.length_max = 4
	lines.width_min = 12
	lines.width_max = 0.5
	lines.lifetime_min = 1.5
	lines.lifetime_max = 0.08
	lines.sanitize()
	check(lines.line_count == 96 and lines.seed >= 0 and lines.seed < 1000000,"Count and seed are bounded")
	check(lines.spawn_radius_max >= lines.spawn_radius_min and lines.end_radius < lines.spawn_radius_min,"Every flight ends inward of spawn")
	check(lines.length_max >= lines.length_min and lines.width_max >= lines.width_min and lines.lifetime_max >= lines.lifetime_min,"All line min/max pairs stay ordered")

func test_lifecycle(scene: PackedScene, config_script: Script, label: String) -> void:
	var source: Resource = config_script.new()
	source.size = 0.75
	var effect: Node2D = scene.instantiate()
	effect.settings = source
	root.add_child(effect)
	effect.set_process(false)
	check(effect.config != source and values(effect.config) == values(source),label+" ready snapshots Inspector config")
	check(effect.get_child_count() == 0 and not effect.playing and effect.build_commands().is_empty(),label+" is dormant, self-contained and prop-free")
	effect.config.size = 1.25
	check(source.size == 0.75,label+" does not mutate caller config")
	source.size = 99
	effect.configure(source)
	check(source.size == 99 and effect.config.size == 2.5,label+" sanitizes only copied resource")
	effect.configure(null)
	check(values(effect.config) == values(config_script.new()),label+" null restores defaults")
	for invalid in [-1.0,NAN,INF]:
		effect.seek(invalid)
		check(effect.build_commands().is_empty(),label+" invalid seek is empty")
	var completion := [0]
	effect.finished.connect(func(): completion[0] += 1)
	effect.stop()
	effect.stop(true)
	check(completion[0] == 0,label+" dormant stop is silent")
	effect.play()
	effect._process(0.25)
	for delta in [-1.0,NAN,INF,-INF]: effect._process(delta)
	check(effect.playing and is_equal_approx(effect.age,0.25),label+" finite forward clock only")
	effect.stop()
	effect.stop()
	check(is_equal_approx(effect.stop_at,0.25) and effect.playing,label+" repeated stop retains one dissipation origin")
	effect._process(effect.config.dissipate_seconds*0.5)
	check(effect.playing and completion[0] == 0,label+" dissipates before completion")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and effect.build_commands().is_empty() and completion[0] == 1,label+" dissipates once without launch or leak")
	effect.play()
	effect._process(0.1)
	effect.stop(true)
	effect.stop(true)
	check(not effect.playing and effect.build_commands().is_empty() and completion[0] == 2,label+" immediate stop is idempotent")
	effect.play()
	effect.seek(0.4,0.3)
	effect._process(1)
	check(not effect.playing and is_equal_approx(effect.age,0.4) and completion[0] == 2,label+" seek pauses without signal")
	effect.play()
	check(effect.age == 0 and effect.stop_at == -1 and effect.playing,label+" replay clears stop state")
	for repeat in range(30): effect.play(); effect.stop(); effect._process(2)
	check(completion[0] == 32 and effect.get_child_count() == 0,label+" repeat playback has no accumulated nodes")
	effect.free()

func test_lines() -> void:
	var effect := Lines.new()
	effect.configure(LinesConfig.new())
	var baseline := effect.build_commands(0.31)
	check(not baseline.is_empty() and baseline.size() <= effect.config.line_count,"Lines emit bounded independent marks")
	seed(39279)
	var expected_rng := randi()
	seed(39279)
	effect.build_commands(12.5)
	check(randi() == expected_rng,"Event noise does not consume engine RNG")
	check(effect.build_commands(0.31) == baseline,"Random event evaluation order does not change geometry")
	var sectors := {}
	var compared := 0
	var inward := true
	var directions: Array[float] = []
	for frame in range(180):
		for index in range(effect.config.line_count):
			var a := effect.sample_line(index,frame/60.0)
			if not a.active: continue
			sectors[int(fposmod(a.direction.angle(),TAU)/TAU*16)] = true
			if frame == 0: directions.append(fposmod(a.direction.angle(),TAU))
			var b := effect.sample_line(index,frame/60.0+0.001)
			if not b.active or a.event != b.event: continue
			compared += 1
			inward = inward and a.direction.is_equal_approx(b.direction) and b.radius < a.radius and b.life > a.life
	check(compared > 1000 and inward,"Thousands of flight samples move only straight radially inward")
	check(sectors.size() == 16,"Irregular distribution reaches all 360 degrees, not an upper fan")
	directions.sort()
	var smallest := TAU
	var largest := 0.0
	for i in range(directions.size()):
		var gap := fposmod(directions[(i+1)%directions.size()]-directions[i],TAU)
		smallest = minf(smallest,gap)
		largest = maxf(largest,gap)
	check(directions.size() >= 8 and largest > smallest*4,"Angular gaps are irregular rather than evenly spaced clock spokes")
	for command in baseline:
		var points: PackedVector2Array = command.points
		check(points.size() == 4 and points[0].length() < points[2].length(),"Each short tapered shard points toward the center")
	var config := LinesConfig.new()
	config.size = 2
	effect.configure(config)
	check(scaled_commands(effect.build_commands(0.31),baseline,2),"Line size uniformly scales geometry")
	config = LinesConfig.new()
	config.speed = 2
	effect.configure(config)
	check(scaled_commands(effect.build_commands(0.155),baseline,1),"Speed scales time without changing flight path")
	for parameter in [["seed",98],["length_min",44.0],["length_max",110.0],["width_min",4.0],["width_max",12.0],["spawn_radius_min",280.0],["spawn_radius_max",500.0],["end_radius",90.0],["lifetime_min",0.4],["lifetime_max",0.9],["line_count",1],["density",0.2]]:
		config = LinesConfig.new()
		config.set(parameter[0],parameter[1])
		effect.configure(config)
		check(effect.build_commands(0.31) != baseline,"Independent line control affects geometry: " + parameter[0])
	var totals := []
	for density in [0.2,2.0]:
		config = LinesConfig.new()
		config.density = density
		effect.configure(config)
		var total := 0
		for frame in range(120): total += effect.build_commands(frame/60.0).size()
		totals.append(total)
	check(totals[1] > totals[0]*2,"Density increases occupancy instead of arranging even radial spokes")
	effect.configure(LinesConfig.new())
	for name in COLORS: effect.config.set(name,Color(0.2,0.4,0.6,1))
	for command in effect.build_commands(0.31): check(command.color == Color(0.2,0.4,0.6,1),"Line palette replacement uses only chosen solid colors")
	effect.free()

func test_orb() -> void:
	var effect := Orb.new()
	effect.configure(OrbConfig.new())
	var baseline := effect.build_commands(0.0)
	check(baseline.size() >= 3 and baseline.size() <= 16,"Orb is a bounded set of hard-color planes")
	check(geometry_problem(baseline,16).is_empty(),"Every authored orb contour triangulates")
	var amplitude: float = effect.config.pulse_amplitude
	var period: float = 1.0/effect.config.pulse_rate
	check(amplitude > 0 and amplitude <= 0.06 and period < 0.4,"Default pulse is small and quick")
	check(scaled_commands(effect.build_commands(period*0.25),baseline,1.0+amplitude),"Pulse peak scales all hand-shaped planes with no rotation")
	check(scaled_commands(effect.build_commands(period*0.75),baseline,1.0-amplitude),"Pulse trough contracts all planes with no rotation")
	check(scaled_commands(effect.build_commands(period),baseline,1),"One pulse returns to identical surface shapes")
	effect.config.pulse_amplitude = 0
	check(effect.build_commands(0.3) == baseline,"Zero amplitude produces a completely stable orb")
	effect.config.size = 2
	check(scaled_commands(effect.build_commands(0.3),baseline,2),"Orb size is independent of pulse")
	effect.configure(OrbConfig.new())
	effect.config.accent_strength = 0
	check(effect.build_commands(0).size() == 3,"Surface accents can be removed without deleting the three main color masses")
	for name in COLORS: effect.config.set(name,Color(0.1,0.5,0.7,1))
	for command in effect.build_commands(0): check(command.color == Color(0.1,0.5,0.7,1),"Orb palette is independently replaceable")
	effect.free()

func test_geometry() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4937
	for pair in [[Lines,LinesConfig,96],[Orb,OrbConfig,16]]:
		var effect: Node2D = pair[0].new()
		for variant in range(18):
			var config: Resource = pair[1].new()
			if variant > 0:
				for spec in pair[1].SPECS:
					config.set(spec[0],spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2])))
			effect.configure(config)
			var problem := ""
			for frame in range(90):
				var time := frame/30.0
				var commands: Array = effect.build_commands(time)
				problem = geometry_problem(commands,pair[2])
				if not problem.is_empty(): problem += " at %.6f" % time; break
				if commands != effect.build_commands(time): problem = "Nondeterministic sample"; break
			check(problem.is_empty(),"Finite deterministic opaque triangulation, variant %d: %s" % [variant,problem])
			for epsilon in [0.0,1e-2,1e-4,1e-6,1e-8,1e-10]:
				for side in [-1.0,1.0]:
					var time: float = 0.5+effect.config.dissipate_seconds+side*epsilon
					problem = geometry_problem(effect.build_commands(time,0.5),pair[2])
					check(problem.is_empty(),"Dissipation boundary remains triangulatable: " + problem)
			check(effect.build_commands(0.5+effect.config.dissipate_seconds+0.001,0.5).is_empty(),"All variants dissipate completely")
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
	lab.lines.set_process(false)
	lab.orb.set_process(false)
	var original_lines := values(lab.line_settings)
	var original_orb := values(lab.orb_settings)
	check(lab.lines_enabled and lab.orb_enabled and lab.lines.visible and lab.orb.visible,"Default composition combines only the two independent effects")
	key(lab,KEY_1)
	check(not lab.lines.visible and lab.orb.visible and not lab.lines_toggle.button_pressed,"Lines toggle leaves orb visible")
	key(lab,KEY_2)
	check(not lab.lines.visible and not lab.orb.visible,"Both components may be disabled")
	key(lab,KEY_1)
	check(lab.lines.visible and not lab.orb.visible,"Lines alone work without an orb dependency")
	key(lab,KEY_2)
	key(lab,KEY_SPACE)
	lab._process(0.5)
	check(lab.clock == 0 and not lab.playing,"Pause holds both clocks")
	key(lab,KEY_RIGHT)
	check(is_equal_approx(lab.clock,1.0/60) and not lab.playing,"Frame step advances one frame while paused")
	key(lab,KEY_R)
	key(lab,KEY_S)
	lab._process(0.4)
	check(is_equal_approx(lab.clock,0.1) and lab.playing,"Quarter speed scales shared preview time")
	key(lab,KEY_S)
	key(lab,KEY_D)
	var stop: float = lab.stop_at
	lab._process(0.05)
	key(lab,KEY_D)
	check(lab.stop_at == stop,"Repeated dissipate does not restart its fade")
	lab._process(2)
	check(lab.finished() and not lab.playing and lab.lines.build_commands().is_empty() and lab.orb.build_commands().is_empty(),"Lab finishes cleanly without a launch")
	key(lab,KEY_SPACE)
	check(lab.playing and lab.clock == 0 and lab.stop_at == -1,"Play after completion starts a fresh charge")
	key(lab,KEY_C)
	check(lab.teal and lab.lines.config.body_color == lab.orb.config.body_color and lab.lines.config.body_color != LinesConfig.new().body_color,"Color variation updates both palettes")
	key(lab,KEY_C,true)
	check(lab.teal,"Repeated key events are ignored")
	for component in ["lines","orb"]:
		for name in lab.param_controls[component]:
			lab.reset_defaults()
			var control: SpinBox = lab.param_controls[component][name]
			control.value = control.max_value
			check(lab.clock == 0 and lab.playing and is_equal_approx(control.value,float(lab._effect(component).config.get(name))),"Parameter UI sanitizes, syncs and replays: %s.%s" % [component,name])
		for name in COLORS:
			lab.reset_defaults()
			var color := Color(0.19,0.51,0.68,1)
			lab.color_controls[component][name].color_changed.emit(color)
			check(lab._effect(component).config.get(name) == color and lab.clock == 0,"Independent palette UI: %s.%s" % [component,name])
			var other: String = "orb" if component == "lines" else "lines"
			check(lab._effect(other).config.get(name) != color,"Changing one component palette preserves its sibling")
	check(values(lab.line_settings) == original_lines and values(lab.orb_settings) == original_orb,"UI edits preserve both Inspector resources")
	var before := values(lab.lines.config)
	lab.set_parameter("lines","unknown",4)
	lab.set_parameter("unknown","size",4)
	lab.set_color("unknown","body_color",Color.RED)
	lab.set_enabled("unknown",false)
	check(before == values(lab.lines.config),"Unsupported UI requests are no-ops")
	lab.reset_defaults()
	check(values(lab.lines.config) == values(LinesConfig.new()) and values(lab.orb.config) == values(OrbConfig.new()) and lab.lines_enabled and lab.orb_enabled and lab.speed == 1 and not lab.teal,"Reset restores exact defaults and composition")
	key(lab,KEY_P)
	await process_frame
	var editor: LineEdit = lab.param_controls.lines.size.get_line_edit()
	editor.grab_focus()
	check(lab.settings_panel.visible and editor.has_focus(),"Live panel can focus numeric editing")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes panel and releases keyboard focus")
	lab.toggle_parameters()
	await process_frame
	editor.grab_focus()
	lab.toggle_parameters()
	check(not editor.has_focus() and not lab.settings_panel.visible,"Direct repeated close also releases focus")
	var count: int = lab.get_child_count()
	for repeat in range(30): lab.reset_defaults(); lab.dissipate(); lab._process(1)
	check(lab.get_child_count() == count,"Repeated preview cycles do not accumulate nodes")
	lab.free()

func test_capture() -> void:
	var lines := Lines.new()
	var orb := Orb.new()
	lines.configure(LinesConfig.new())
	orb.configure(OrbConfig.new())
	var passes := {}
	var safe := true
	for frame in range(Lab.CAPTURE_FRAMES):
		var sample: Dictionary = Lab.capture_sample(frame)
		passes[[sample.lines,sample.orb,sample.teal,sample.panel]] = true
		for pair in [[lines,96],[orb,16]]:
			var problem := geometry_problem(pair[0].build_commands(sample.time,sample.stop_at),pair[1])
			if not problem.is_empty():
				print("CHARGE_CAPTURE frame=%d: %s" % [frame,problem])
				safe = false
				break
		if not safe: break
	check(safe,"Every exact capture frame has safe effect geometry")
	check(passes.size() == 5,"Capture includes composite, lines, orb, teal variation and live panel")
	var last := Lab.capture_sample(Lab.CAPTURE_FRAMES-1)
	check(lines.build_commands(last.time,last.stop_at).is_empty() and orb.build_commands(last.time,last.stop_at).is_empty(),"Capture ends after a complete dissipate, with no auto-release")
	lines.free()
	orb.free()

func run() -> void:
	test_configs()
	test_lifecycle(LinesScene,LinesConfig,"Gathering Lines")
	test_lifecycle(OrbScene,OrbConfig,"Pulsing Orb")
	test_lines()
	test_orb()
	test_geometry()
	await test_lab()
	test_capture()
	print("CEL_CHARGE: %d checks, %d failures" % [checks,failures])
	quit(failures)
