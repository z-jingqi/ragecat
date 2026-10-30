extends SceneTree
## Cel-track contracts; real viewport capture remains a separate visual check.
const Config = preload("res://scripts/vfx/cel/shield_hit_config.gd")
const Effect = preload("res://scripts/vfx/cel/shield_hit.gd")
const EffectScene = preload("res://scenes/vfx/cel/shield_hit.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/shield_hit_lab.tscn")
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

func valid_geometry(commands: Array) -> bool:
	if commands.size() > 24: return false
	for command in commands:
		if command.keys().size() != 2 or not command.has("points") or not command.has("color"): return false
		var points: PackedVector2Array = command.points
		if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty(): return false
		for point in points:
			if not point.is_finite() or point.length() > 2500: return false
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return false
	return true

func report_bad_polygons(effect: Node2D, age: float, context: String) -> bool:
	var commands: Array = effect.build_commands(age)
	var valid := valid_geometry(commands)
	if not valid:
		for i in range(commands.size()):
			if Geometry2D.triangulate_polygon(commands[i].points).is_empty():
				print("INVALID_POLYGON %s age=%.17f polygon=%d color=%s points=%s" % [context,age,i,commands[i].color,commands[i].points])
	return valid

func test_capture_and_boundaries(effect: Node2D) -> void:
	effect.configure(Config.new())
	var capture_valid := true
	for frame in range(600):
		var age: float
		if frame < 240: age = fposmod(frame/60.0,2.0)-0.48
		elif frame < 480: age = (frame-240)/120.0-0.48
		else: age = (frame-480)/120.0+0.25-0.48
		if not report_bad_polygons(effect,age,"capture frame %d" % frame): capture_valid = false
	check(capture_valid,"Exact 600-frame capture timeline polygons triangulate")
	for duration_scale in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = duration_scale
		effect.configure(config)
		var boundaries_valid := true
		for boundary in [0.0,0.025,config.flash_seconds,config.flash_seconds*2.4,0.22,config.duration()/duration_scale]:
			for epsilon in [0.0,1e-2,1e-3,1e-4,1e-5,1e-6,1e-7,1e-8,1e-9,1e-10,1e-12,1e-14,1e-15]:
				for side in [-1.0,1.0]:
					var age: float = (boundary+side*epsilon)*duration_scale
					if not report_bad_polygons(effect,age,"boundary %.17f scale %.2f" % [boundary,duration_scale]): boundaries_valid = false
		check(boundaries_valid,"Dense phase boundaries triangulate at duration scale %.2f" % duration_scale)

func test_config() -> void:
	var defaults := Config.new()
	var specs := [
		["size",0.25,3.0], ["direction_degrees",-180.0,180.0],
		["spark_length",0.25,2.0], ["scatter",0.25,1.5],
		["duration_scale",0.4,2.0], ["flash_seconds",0.025,0.12],
		["spark_seconds",0.18,0.8], ["travel",0.4,2.0],
	]
	for spec in specs:
		var safe := true
		for input in [-999.0,999.0,NAN,INF,-INF]:
			var config := Config.new()
			config.set(spec[0],input)
			config.sanitize()
			var expected: float = clampf(input,spec[1],spec[2]) if is_finite(input) else defaults.get(spec[0])
			safe = safe and is_equal_approx(config.get(spec[0]),expected)
		check(safe,"Range and nonfinite defense: " + spec[0])
	for count in [-1,99]:
		var config := Config.new()
		config.spark_count = count
		config.sanitize()
		check(config.spark_count == clampi(count,0,12),"Spark count stays bounded")
	for name in ["core_color","body_color","shade_color","arc_color"]:
		var config := Config.new()
		config.set(name,Color(NAN,0.2,0.3,0.5))
		config.sanitize()
		check(config.get(name) == defaults.get(name),"Invalid color restores default: " + name)
		config.set(name,Color(-3,8,0.5,NAN))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.5,1),"Color clamps and stays opaque: " + name)
	check(is_equal_approx(defaults.duration(),0.42),"Default effect completes in 420 ms")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),0.84),"Duration multiplier scales complete effect")

func test_effect() -> void:
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 3,"Configure deep-copies before validation")
	effect.config.body_color = Color.RED
	check(source.body_color == Config.new().body_color,"Runtime edits leave source resource intact")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores defaults")
	check(effect.get_child_count() == 0 and effect.build_commands().is_empty(),"Reusable scene starts dormant with no props or children")
	for age in [-1.0,-0.001,effect.config.duration(),100.0,INF,NAN]:
		check(effect.build_commands(age).is_empty(),"No geometry outside effect lifetime: %s" % age)
	check(not effect.build_commands(0).is_empty(),"Impact begins immediately at contact age zero")
	var baseline: Array = effect.build_commands(0.08).duplicate(true)
	check(baseline == effect.build_commands(0.08),"Same age and seed yield identical geometry")
	effect.config.seed_value += 1
	check(baseline != effect.build_commands(0.08),"Seed changes spark layout")
	effect.configure(Config.new())
	effect.config.direction_degrees = 90
	var rotated: Array = effect.build_commands(0.08)
	var rotation_matches := rotated.size() == baseline.size()
	for i in range(mini(rotated.size(),baseline.size())):
		for j in range(baseline[i].points.size()):
			rotation_matches = rotation_matches and rotated[i].points[j].is_equal_approx(baseline[i].points[j].rotated(PI/2))
	check(rotation_matches,"Direction rotates every effect polygon")
	effect.configure(Config.new())
	effect.config.size = 2
	var scaled: Array = effect.build_commands(0.08)
	var scale_matches := scaled.size() == baseline.size()
	for i in range(mini(scaled.size(),baseline.size())):
		for j in range(baseline[i].points.size()):
			scale_matches = scale_matches and scaled[i].points[j].is_equal_approx(baseline[i].points[j]*2)
	check(scale_matches,"Size scales every effect polygon")
	effect.configure(Config.new())
	effect.config.spark_count = 0
	effect.config.show_arc = false
	check(not effect.build_commands(0.01).is_empty(),"Core independently remains when accents are disabled")
	check(effect.build_commands(effect.config.flash_seconds*2.4).is_empty(),"Core ends exactly at its shrink boundary")
	effect.config.show_arc = true
	check(not effect.build_commands(0.15).is_empty(),"Pressure crescent is independently enabled")
	check(effect.build_commands(0.22).is_empty(),"Crescent ends at 220 ms")
	for variant in range(5):
		var config := Config.new()
		if variant > 0:
			config.size = [0.25,3.0,3.0,0.25][variant-1]
			config.direction_degrees = [-180,180,37,-92][variant-1]
			config.spark_count = 12
			config.spark_length = [0.25,2.0,0.25,2.0][variant-1]
			config.scatter = [0.25,1.5,1.5,0.25][variant-1]
			config.duration_scale = [0.4,2.0,0.4,2.0][variant-1]
			config.flash_seconds = [0.025,0.12,0.12,0.025][variant-1]
			config.spark_seconds = [0.18,0.8,0.8,0.18][variant-1]
			config.travel = [0.4,2.0,2.0,0.4][variant-1]
			config.seed_value = variant*4321
		effect.configure(config)
		var safe := true
		for frame in range(241):
			var age: float = effect.config.duration()*frame/240.0
			var commands: Array = effect.build_commands(age)
			if not valid_geometry(commands) or commands != effect.build_commands(age):
				print("Invalid cel geometry in variant %d at age %.9f" % [variant,age])
				safe = false
				break
		check(safe,"All 241 sampled frames finite, triangulatable, opaque, bounded and deterministic: variant %d" % variant)
		effect.seek(effect.config.duration())
		check(effect.build_commands().is_empty(),"Every variant finishes empty")
	test_capture_and_boundaries(effect)
	effect.configure(Config.new())
	effect.finished.connect(func(): finish_count += 1)
	effect.play()
	check(effect.playing and effect.age == 0,"Play starts immediate one-shot")
	effect._process(0.1)
	check(is_equal_approx(effect.age,0.1),"One-shot advances with delta")
	effect._process(-1)
	check(is_equal_approx(effect.age,0.1),"Negative delta cannot rewind one-shot")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Completion emits exactly once and clears geometry")
	effect.play()
	effect.seek(0.1)
	effect._process(1)
	check(not effect.playing and is_equal_approx(effect.age,0.1) and finish_count == 1,"Seek is manual and does not emit completion")
	effect.seek(NAN)
	check(effect.build_commands().is_empty(),"Invalid seek is safely dormant")
	for i in range(50): effect.play(); effect._process(1)
	check(finish_count == 51 and effect.get_child_count() == 0,"Repeated one-shots complete without adding props or nodes")
	effect.free()

func test_lab() -> void:
	var lab := LabScene.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.effect.set_process(false)
	var source_before := values(lab.settings)
	check(lab.effect.config != lab.settings,"Lab keeps Inspector resource isolated")
	lab.clock = 0.6
	key(lab,KEY_SPACE)
	lab._process(0.1)
	check(is_equal_approx(lab.clock,0.6),"Pause holds timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.clock,0.6+1.0/60.0),"Step advances one frame and stays paused")
	key(lab,KEY_R)
	check(lab.playing and lab.clock == 0,"Replay restarts timeline")
	key(lab,KEY_S)
	lab._process(0.4)
	check(is_equal_approx(lab.clock,0.1),"Quarter speed changes clock progression")
	key(lab,KEY_S)
	key(lab,KEY_L)
	lab.clock = lab.duration()-0.01
	lab._process(0.1)
	check(not lab.playing and lab.clock == lab.duration(),"Non-loop playback stops at duration")
	key(lab,KEY_RIGHT)
	check(lab.clock == lab.duration(),"Frame step clamps at end")
	key(lab,KEY_L)
	lab.replay()
	lab._process(lab.duration()+0.1)
	check(is_equal_approx(lab.clock,0.1),"Loop preserves residual time")
	key(lab,KEY_B)
	key(lab,KEY_B,true)
	check(lab.demo.bright,"Backdrop toggles and ignores repeated key events")
	key(lab,KEY_E)
	check(not lab.demo.show_props and not lab.demo_toggle.button_pressed,"Effect-only keyboard toggles demo and control together")
	key(lab,KEY_P)
	check(lab.settings_panel.visible,"Parameter shortcut opens panel")
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes parameters and releases field focus")
	for spec in lab.PARAMS:
		lab.param_controls[spec[0]].value = spec[3]
		check(is_equal_approx(float(lab.effect.config.get(spec[0])),spec[3]) and lab.clock == 0 and lab.playing,"Live numeric signal updates and replays: " + spec[0])
	for name in lab.color_controls:
		var value := Color(0.14,0.37,0.62,1)
		lab.clock = 0.8
		lab.color_controls[name].color_changed.emit(value)
		check(lab.effect.config.get(name) == value and lab.clock == 0 and lab.playing,"Live palette signal updates and replays: " + name)
	lab.arc_toggle.button_pressed = false
	check(not lab.effect.config.show_arc,"Arc control disables crescent")
	lab.demo_toggle.button_pressed = true
	check(lab.demo.show_props,"Demo checkbox restores props")
	check(values(lab.settings) == source_before,"All live edits leave Inspector resource unchanged")
	var before := values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	check(values(lab.effect.config) == before,"Unknown parameters ignored")
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and lab.demo.show_props,"Reset restores exact configuration and demo")
	var child_count: int = lab.get_child_count()
	for i in range(50): lab.reset_defaults(); lab._process(0.5)
	check(lab.get_child_count() == child_count and is_equal_approx(lab.effect.age,0.02),"Repeated lab replay has stable nodes and effect-relative age")
	lab.free()

func run() -> void:
	test_config()
	test_effect()
	await test_lab()
	print("CEL_SHIELD_HIT: %d checks, %d failures" % [checks,failures])
	quit(failures)
