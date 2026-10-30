extends SceneTree
const Behavior = preload("res://scripts/vfx/slash/slash_behavior.gd")
const Pixel = preload("res://scripts/vfx/slash/pixel_slash.gd")
const Lab = preload("res://scenes/vfx_lab/slash/slash_lab.tscn")
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
	check(behavior.sample(0).phase == "READY", "Ready before anticipation")
	check(behavior.sample(Behavior.WINDUP).phase == "ANTICIPATION", "Windup boundary")
	check(behavior.sample(Behavior.SWEEP).phase == "SWEEP", "Sweep boundary")
	check(behavior.sample(Behavior.FOLLOW).phase == "AFTERIMAGE / FADE", "Follow-through boundary")
	check(behavior.sample(Behavior.SWEEP-0.001).trail == 0, "No premature trail")
	check(behavior.sample(Behavior.SWEEP).trail == 1, "Trail starts with sweep")
	check(behavior.sample(Behavior.FADE).trail == 0, "Trail fully expires")
	check(is_equal_approx(behavior.sample(0).angle,behavior.sample(Behavior.DURATION).angle), "Loop pose settles")
	check(behavior.sample(-1) == behavior.sample(0), "Negative time clamps")
	check(behavior.sample(100) == behavior.sample(Behavior.DURATION), "Late time clamps")
	for i in range(100):
		var t := i/60.0
		check(behavior.sample(t) == behavior.sample(t), "Timeline deterministic")
	var angle: float = behavior.sample(0.4).angle
	var reference_point: Vector2 = behavior.blade_point(angle,75)
	behavior.direction = PI/2
	check(behavior.blade_point(angle,75).is_equal_approx(reference_point.rotated(PI/2)), "Direction rotates entire ellipse")
	behavior.direction = 0
	var pixel := Pixel.new()
	pixel.behavior = behavior
	pixel.time = Behavior.FOLLOW - 0.03
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
	for frame in range(240):
		pixel.time = frame/120.0
		for command in pixel.build_commands():
			check(command.color != "203d4dff", "No dark slash outline at frame %s" % frame)
			if command.type != "polygon": continue
			var vertices := PackedVector2Array()
			for point in command.points: vertices.append(Vector2(point[0],point[1]))
			check(not Geometry2D.triangulate_polygon(vertices).is_empty(), "Polygon triangulates at frame %s" % frame)
	# Extremes exercise finite/range defense and triangulation, not only presets.
	for variant in range(4):
		var cfg = behavior.config
		cfg.direction_degrees = [-180,180,-45,130][variant]
		cfg.arc_degrees = [30,290,30,290][variant]
		cfg.radius = [24,75,75,24][variant]
		cfg.aspect = [0.3,1.0,1.0,0.3][variant]
		cfg.width = [0.25,2.0,2.0,0.25][variant]
		cfg.sweep_seconds = [0.08,0.5,0.5,0.08][variant]
		cfg.ghost_count = 6; cfg.ghost_spacing = 0.015; cfg.ghost_lifetime = 0.3
		for frame in range(120):
			pixel.time = frame/60.0
			var batch: Array = pixel.build_commands()
			check(batch.size() < 100, "Bounded parameter command count")
			check(batch == pixel.build_commands(), "Parameter replay deterministic")
			for command in batch:
				if command.type != "polygon": continue
				var vertices := PackedVector2Array()
				for p in command.points: vertices.append(Vector2(p[0],p[1]))
				check(not Geometry2D.triangulate_polygon(vertices).is_empty(), "Extreme polygon valid")
	var cfg = behavior.config
	cfg.radius = INF; cfg.width = -100; cfg.ghost_count = 999
	cfg.sweep_seconds = NAN; cfg.direction_degrees = 9999
	cfg.sanitize()
	check(cfg.radius == 75 and cfg.width == 0.25 and cfg.ghost_count == 6, "Invalid allocation/shape inputs clamped")
	check(cfg.sweep_seconds == 0.17 and cfg.direction_degrees == 180, "Nonfinite timing and direction guarded")
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
	lab.set_parameter("radius",30)
	check(lab.settings.radius == 30 and lab.clock == 0 and lab.playing, "Parameter edits replay")
	lab.apply_preset(2)
	check(lab.settings.aspect == 0.35 and lab.behavior.config == lab.settings, "Preset shares config")
	lab.apply_preset(0)
	check(lab.settings.radius == 75 and lab.settings.aspect == 0.67 and lab.settings.sweep_seconds == 0.17, "Reset restores accepted defaults")
	key(lab,KEY_P)
	check(lab.parameter_panel.visible, "Parameters keyboard opens")
	key(lab,KEY_ESCAPE)
	check(not lab.parameter_panel.visible, "Parameters Escape closes")
	for i in range(100): lab.apply_preset(i%4)
	check(lab.get_child_count() == child_count, "Preset changes do not accumulate UI nodes")
	lab.free()
	print("PIXEL_SLASH_LAB: %d checks, %d failures" % [checks, failures])
	quit(failures)
