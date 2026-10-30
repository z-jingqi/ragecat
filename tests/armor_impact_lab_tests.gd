extends SceneTree
const Config = preload("res://scripts/vfx_lab/impact_config.gd")
const Behavior = preload("res://scripts/vfx_lab/impact_behavior.gd")
const Pixel = preload("res://scripts/vfx_lab/pixel_impact.gd")
const Lab = preload("res://scenes/vfx_lab/armor_impact_lab.tscn")
var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func key(lab: Control, code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	lab._unhandled_key_input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var behavior := Behavior.new()
	check(behavior.sample(0).flight == 0, "Flight starts at rest")
	check(behavior.sample(Behavior.CONTACT - 0.001).flash == 0, "No premature flash")
	check(behavior.sample(Behavior.CONTACT).flash == 1, "Contact starts full flash")
	check(behavior.sample(Behavior.CONTACT).flight == 1, "Flight reaches target at contact")
	check(behavior.sample(Behavior.CONTACT + 0.076).flash == 0, "Flash ends after 75 ms")
	check(is_zero_approx(behavior.sample(Behavior.DURATION).recoil), "Recoil settles")
	check(behavior.sample(Behavior.DURATION).smoke == 0, "Smoke expires")
	for i in range(19):
		check(not behavior.spark(i, -0.001).alive, "Spark hidden before impact")
		check(behavior.spark(i, 0).alive, "Spark begins at impact")
		check(not behavior.spark(i, Behavior.DURATION - Behavior.CONTACT).alive, "Spark expires before loop end")
		check(behavior.spark(i, 0.12) == behavior.spark(i, 0.12), "Spark samples are deterministic")
	var first: Dictionary = behavior.spark(3, 0.12)
	behavior.direction = Vector2.DOWN
	var rotated: Dictionary = behavior.spark(3, 0.12)
	check(rotated.position.is_equal_approx(first.position.rotated(PI / 2)), "Direction rotates shared trajectory")
	behavior.direction = Vector2.RIGHT
	behavior.strength = 2.0
	var stronger: Dictionary = behavior.spark(3, 0.12)
	check(is_equal_approx(stronger.position.x, first.position.x * 2), "Strength scales launch velocity")
	check(is_equal_approx(behavior.sample(Behavior.CONTACT + 0.12).recoil, 8), "Strength scales recoil")
	behavior.strength = 1.0
	var pixel := Pixel.new()
	pixel.behavior = behavior
	pixel.show_demo = true
	pixel.time = Behavior.CONTACT + 0.03
	var dark: Array = pixel.build_commands().duplicate(true)
	check(dark == pixel.build_commands(), "Renderer replay command stream stable")
	pixel.bright = true
	var bright: Array = pixel.build_commands()
	check(bright[0].color != dark[0].color, "Backdrop switches palette")
	check(bright.size() == dark.size(), "Backdrop preserves effect command count")
	for time in [0.0, 0.16, 0.48, 0.51, 0.7, 1.0, 1.65]:
		pixel.time = time
		var commands: Array = pixel.build_commands()
		check(not commands.is_empty() and commands.size() < 200, "Bounded commands across timeline")
	pixel.free()
	var lab := Lab.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	check(lab.renderer.behavior == lab.behavior, "Scene renderer consumes shared behavior")
	lab.clock = 0.6
	key(lab, KEY_SPACE)
	lab._process(0.1)
	check(is_equal_approx(lab.clock, 0.6), "Pause preserves clock")
	key(lab, KEY_RIGHT)
	check(is_equal_approx(lab.clock, 0.6 + 1.0/60.0), "Frame step advances exactly one frame")
	check(not lab.playing, "Frame step remains paused")
	key(lab, KEY_R)
	check(lab.clock == 0 and lab.playing, "Replay resets and resumes")
	key(lab, KEY_S)
	lab._process(0.4)
	check(is_equal_approx(lab.clock, 0.1), "Quarter speed applies to shared clock")
	key(lab, KEY_S)
	check(lab.speed == 1.0, "Speed toggle restores normal")
	key(lab, KEY_B)
	check(lab.renderer.bright, "Backdrop key applies")
	key(lab, KEY_B, true)
	check(lab.renderer.bright, "Keyboard repeat ignored")
	key(lab, KEY_L)
	lab.clock = Behavior.DURATION - 0.01
	lab._process(0.1)
	check(not lab.playing and lab.clock == Behavior.DURATION, "Non-loop playback stops at end")
	key(lab, KEY_RIGHT)
	check(lab.clock == Behavior.DURATION, "Step clamps at end")
	key(lab, KEY_L)
	lab.replay()
	lab._process(Behavior.DURATION + 0.1)
	check(is_equal_approx(lab.clock, 0.1), "Loop wraps with residual time")
	var child_count: int = lab.get_child_count()
	for i in range(100):
		lab.replay()
		lab._process(0.5)
	check(lab.get_child_count() == child_count, "Repeated replay does not accumulate nodes")
	check(is_equal_approx(lab.clock, 0.5), "Repeated replay stays deterministic")
	await test_parameters(lab)
	lab.free()
	print("ARMOR_IMPACT_LAB: %d checks, %d failures" % [checks, failures])
	quit(failures)

func config_values(config: Resource) -> Dictionary:
	var values: Dictionary = {}
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: values[property.name] = config.get(property.name)
	return values

func finite_commands(commands: Array) -> bool:
	if commands.size() > 220: return false
	for command in commands:
		if command.type == "rect":
			for coordinate in command.rect:
				if not is_finite(coordinate) or absf(coordinate) > 10000: return false
		else:
			for point in command.points:
				for coordinate in point:
					if not is_finite(coordinate) or absf(coordinate) > 10000: return false
		if command.has("width") and (not is_finite(command.width) or command.width <= 0): return false
	return true

func test_parameters(lab: Control) -> void:
	var defaults := Config.new()
	var specs := [
		["strength",0.25,2.0],["effect_scale",0.5,1.5],["direction_degrees",-180.0,180.0],
		["spark_spread_degrees",10.0,160.0],["spark_speed",0.25,1.5],["spark_lifetime",0.5,1.5],
		["flash_seconds",0.025,0.2],["smoke_amount",0.0,1.5],["smoke_seconds",0.3,1.2],
		["recoil_pixels",0.0,8.0],["recoil_seconds",0.1,0.5]]
	for spec in specs:
		for input in [-999.0,999.0,NAN,INF,-INF]:
			var config := Config.new()
			config.set(spec[0],input)
			config.sanitize()
			var expected: float = clampf(input,spec[1],spec[2]) if is_finite(input) else defaults.get(spec[0])
			check(is_equal_approx(config.get(spec[0]),expected), "Sanitize %s input %s" % [spec[0],input])
	for count in [-20,100]:
		var config := Config.new()
		config.spark_count = count
		config.sanitize()
		check(config.spark_count == clampi(count,0,40), "Spark count clamps")
	for position in [Vector2(NAN,2),Vector2(2,INF)]:
		var config := Config.new()
		config.hit_position = position
		config.sanitize()
		check(config.hit_position == defaults.hit_position, "Non-finite hit position resets")
	var source := Config.new()
	source.strength = 99
	var behavior := Behavior.new()
	behavior.configure(source)
	check(source.strength == 99 and behavior.config.strength == 2, "Configure clones before sanitizing")
	behavior.config.hit_position.x += 10
	check(source.hit_position == defaults.hit_position, "Runtime mutation leaves source Resource intact")
	behavior.configure(Resource.new())
	check(config_values(behavior.config) == config_values(defaults), "Wrong Resource safely falls back")
	var renderer := Pixel.new()
	renderer.behavior = behavior
	check(not renderer.show_demo, "Reusable renderer defaults to effect only")
	for time in [0.0,0.2,Behavior.CONTACT-0.001,behavior.duration()]:
		renderer.time = time
		check(renderer.build_commands().is_empty(), "Effect only has no persistent demo before/after")
	renderer.time = Behavior.CONTACT
	var effect: Array = renderer.build_commands().duplicate(true)
	var forbidden := ["131c25ff","c6c3b3ff","71868fff","b9945bff","574d42ff"]
	for command in effect: check(not command.color in forbidden, "Effect only excludes background target and arrow")
	behavior.config.hit_position += Vector2(10,-5)
	var shifted: Array = renderer.build_commands()
	check(shifted.size() == effect.size(), "Hit shift preserves command count")
	for i in range(effect.size()):
		var a: Dictionary = effect[i]
		var b: Dictionary = shifted[i]
		if a.type == "rect":
			check(is_equal_approx(b.rect[0]-a.rect[0],10) and is_equal_approx(b.rect[1]-a.rect[1],-5), "Hit shifts rectangle")
		else:
			for j in range(a.points.size()):
				check(Vector2(b.points[j][0]-a.points[j][0],b.points[j][1]-a.points[j][1]).is_equal_approx(Vector2(10,-5)), "Hit shifts vertex")
	behavior.configure(defaults)
	behavior.config.spark_count = 0
	behavior.config.smoke_amount = 0
	renderer.time = Behavior.CONTACT + 0.2
	check(renderer.build_commands().is_empty(), "Zero sparks and smoke suppress both layers")
	behavior.config.spark_count = 40
	check(not renderer.build_commands().is_empty(), "Spark count enables particles")
	behavior.config.spark_count = 0
	behavior.config.smoke_amount = 1
	check(not renderer.build_commands().is_empty(), "Smoke amount independently enables smoke")
	for extreme in [0,1]:
		for spec in specs: behavior.config.set(spec[0],spec[extreme+1])
		behavior.config.spark_count = 40 if extreme else 0
		for time in [0.0,0.2,0.48,0.51,0.6,0.9,1.2,1.68,behavior.duration()]:
			renderer.time = time
			check(finite_commands(renderer.build_commands()), "Extreme settings generate finite bounded commands")
	check(behavior.duration() > Behavior.DURATION, "Long smoke extends playback duration")
	renderer.time = behavior.duration()
	check(renderer.build_commands().is_empty(), "Extended duration lets all layers settle")
	behavior.configure(defaults)
	renderer.show_demo = true
	renderer.time = 0.32
	var right: Array = renderer.build_commands().filter(func(c): return c.color in ["b9945bff","edcf86ff","a2b8b8ff","e2e9ceff","657879ff"])
	behavior.direction = Vector2.DOWN
	var down: Array = renderer.build_commands().filter(func(c): return c.color in ["b9945bff","edcf86ff","a2b8b8ff","e2e9ceff","657879ff"])
	check(right.size() == 7 and down.size() == 7, "Arrow geometry includes shaft fletching head and trail")
	for i in range(right.size()):
		for j in range(right[i].points.size()):
			var p := Vector2(right[i].points[j][0],right[i].points[j][1])
			var q := Vector2(down[i].points[j][0],down[i].points[j][1])
			check(q.distance_to(behavior.config.hit_position+(p-behavior.config.hit_position).rotated(PI/2)) <= 1.5, "Entire arrow geometry follows direction")
	renderer.free()
	lab.reset_defaults()
	lab.renderer.time = 0.53
	var baseline: Array = lab.renderer.build_commands().duplicate(true)
	var inspector_before: Dictionary = config_values(lab.impact_settings)
	await process_frame
	var spread: SpinBox = lab.param_controls["spark_spread_degrees"]
	check(absf(spread.value - 131.78) < 0.005, "Default spread displays accurate hundredths")

	check(not lab.settings_panel.visible, "Panel starts hidden")
	key(lab,KEY_P)
	check(lab.settings_panel.visible, "P reveals parameters")
	await process_frame
	print("SPREAD DISPLAY: ", spread.get_line_edit().text)
	check(absf(spread.get_line_edit().text.to_float() - 131.78) < 0.005, "Default spread text is 131.78, not rounded to 130")
	key(lab,KEY_P)
	check(not lab.settings_panel.visible, "P hides parameters")
	lab.settings_panel.show()
	var editor: LineEdit = spread.get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(), "SpinBox editor can acquire keyboard focus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(), "Escape closes panel and releases editor focus")
	lab.settings_panel.show()
	var original_backdrop: bool = lab.renderer.bright
	for child in lab.get_children():
		if child is Button and child.text in ["Replay [R]", "Pause / Play [Space]", "Loop on/off [L]", "Slow ¼ / 1× [S]", "Backdrop [B]", "Reset defaults"]:
			editor.grab_focus()
			child.pressed.emit()
			check(not editor.has_focus(), "Standard button releases edit focus: " + child.text)
	lab.settings_panel.hide()
	lab.renderer.bright = original_backdrop
	lab.reset_defaults()
	for spec in lab.PARAMS:
		var control: SpinBox = lab.param_controls[spec[0]]
		control.value = spec[3]
		var actual: float = lab.behavior.config.hit_position.x if spec[0] == "hit_x" else (lab.behavior.config.hit_position.y if spec[0] == "hit_y" else lab.behavior.config.get(spec[0]))
		check(is_equal_approx(actual,spec[3]), "SpinBox value_changed updates %s" % spec[0])
		check(lab.clock == 0 and lab.playing, "Parameter edit replays")
	check(config_values(lab.impact_settings) == inspector_before, "Controls never mutate inspector Resource")
	lab.demo_toggle.button_pressed = false
	check(not lab.renderer.show_demo, "Demo toggle excludes target/arrow")
	lab.clock = 0.9
	lab.apply_preset()
	check(lab.behavior.config.spark_count == 30 and lab.behavior.config.direction_degrees == -30 and lab.behavior.config.strength == 1.5, "Heavy preset applies expected values")
	check(lab.clock == 0 and lab.playing, "Preset replays")
	lab.reset_defaults()
	lab.renderer.time = 0.53
	check(config_values(lab.behavior.config) == config_values(defaults), "Reset restores exact approved settings")
	check(lab.renderer.show_demo and lab.demo_toggle.button_pressed, "Reset restores demo")
	check(lab.renderer.build_commands() == baseline, "Reset restores exact approved draw command stream")
	var before: Dictionary = config_values(lab.behavior.config)
	lab.set_parameter("unsupported",999)
	check(config_values(lab.behavior.config) == before, "Unknown parameter ignored")
