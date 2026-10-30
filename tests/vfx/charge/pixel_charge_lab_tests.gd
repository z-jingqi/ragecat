extends SceneTree
## Sustained charge + explicit dissipation only. GPU visual QA is separate.
const Config = preload("res://scripts/vfx/charge/charge_config.gd")
const Behavior = preload("res://scripts/vfx/charge/charge_behavior.gd")
const Pixel = preload("res://scripts/vfx/charge/pixel_charge.gd")
const Lab = preload("res://scenes/vfx_lab/charge/charge_lab.tscn")
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
	check(behavior.sample(0).phase == "READY", "Idle before charge starts")
	check(behavior.sample(Behavior.START).phase == "GATHER", "Gather starts at boundary")
	check(behavior.sample(-10) == behavior.sample(0), "Negative time clamps")
	check(is_inf(behavior.duration()), "Sustained effect has no automatic expiry")
	for t in [1.4,10.0,10000.0]:
		var state: Dictionary = behavior.sample(t)
		check(state.phase == "SUSTAIN" and state.charge == 1 and state.opacity == 1 and state.active, "Full charge sustains indefinitely")
		for removed in ["release","swing","hit_age","impact","held"]:
			check(not state.has(removed), "No attack state remains")
	for stop in [Behavior.START,0.6,1.4,10000.0]:
		check(is_equal_approx(behavior.duration(stop),stop+0.7), "Explicit stop has bounded cleanup")
		check(behavior.sample(stop,stop).phase == "DISSIPATE", "Explicit stop begins dissipation")
		var previous := 1.0
		for step in range(31):
			var state: Dictionary = behavior.sample(stop+step*0.03,stop)
			check(state.opacity <= previous and state.opacity >= 0, "Dissipation is monotonic")
			previous = state.opacity
		check(not behavior.sample(behavior.duration(stop),stop).active, "Stopped effect fully expires")
	for invalid_stop in [-1.0,0.0,NAN,INF]:
		check(is_inf(behavior.duration(invalid_stop)), "Invalid stop cannot terminate charge")
	var original := Config.new()
	original.radius = 32
	behavior.configure(original)
	original.radius = 60
	check(behavior.config.radius == 32, "Configure isolates source Resource")
	behavior.config.radius = 40
	check(original.radius == 60, "Source Resource not mutated by runtime")
	var bad := Config.new()
	bad.charge_seconds = NAN; bad.radius = INF; bad.strength = -100
	bad.intensity = 999; bad.dissipate_seconds = -1; bad.particle_count = 999
	bad.wind_speed = INF; bad.rise_height = NAN; bad.inward_speed = -9
	bad.sanitize()
	check(bad.wind_speed == 1 and bad.rise_height == 42 and bad.inward_speed == 0.25, "Wind/rise/inward guards")
	check(bad.charge_seconds == 1.2 and bad.radius == 48, "Nonfinite fields restore safe defaults")
	check(bad.strength == 0.5 and bad.intensity == 1, "Strength and intensity bounded")
	check(bad.dissipate_seconds == 0.2 and bad.particle_count == 40, "Cleanup and allocation bounded")
	bad.charge_seconds = 999; bad.radius = -999; bad.strength = INF
	bad.intensity = NAN; bad.dissipate_seconds = INF; bad.particle_count = -1
	bad.sanitize()
	check(bad.charge_seconds == 2.5 and bad.radius == 24 and bad.particle_count == 0, "Opposite bounds clamped")
	check(bad.strength == 1 and bad.intensity == 1 and bad.dissipate_seconds == 0.45, "Other nonfinite fields restored")
	bad.wind_speed = 99; bad.rise_height = -99; bad.inward_speed = 99
	bad.sanitize()
	check(bad.wind_speed == 3 and bad.rise_height == 16 and bad.inward_speed == 3, "Wind/rise/inward extrema clamped")
	var motion := Config.new()
	behavior.configure(motion)
	var reference: Vector2 = behavior.particle(3,0.8)
	motion.inward_speed = 2
	behavior.configure(motion)
	check(behavior.particle(3,0.4).is_equal_approx(reference), "Inward speed scales particle clock")
	var pixel := Pixel.new()
	pixel.behavior = behavior
	pixel.show_demo = false
	for variant in range(5):
		var cfg := Config.new()
		if variant > 0:
			cfg.charge_seconds = [0.4,2.5,0.4,2.5][variant-1]
			cfg.radius = [24,64,64,24][variant-1]
			cfg.strength = [0.5,2.0,2.0,0.5][variant-1]
			cfg.intensity = [0.25,1.0,0.25,1.0][variant-1]
			cfg.dissipate_seconds = [0.2,1.0,1.0,0.2][variant-1]
			cfg.particle_count = [0,40,40,0][variant-1]
			cfg.wind_speed = [0.25,3.0,0.25,3.0][variant-1]
			cfg.rise_height = [16,60,60,16][variant-1]
			cfg.inward_speed = [0.25,3.0,3.0,0.25][variant-1]
		behavior.configure(cfg)
		check(behavior.sample(100).charge == cfg.intensity, "Intensity caps full charge independently")
		var stop: float = Behavior.START+cfg.charge_seconds+0.6
		pixel.stop_at = stop
		for frame in range(180):
			var t: float = behavior.duration(stop)*frame/179.0
			pixel.time = t
			var state: Dictionary = behavior.sample(t,stop)
			check(state == behavior.sample(t,stop), "Behavior deterministic")
			check(state.charge >= 0 and state.charge <= cfg.intensity, "Charge intensity bounded")
			var batch: Array = pixel.build_commands()
			check(batch == pixel.build_commands(), "Pixel stream deterministic")
			check(batch.size() < 2500, "Pixel workload bounded")
			for command in batch:
				check(command.type == "rect" and command.rect.position.is_finite() and command.rect.size.is_finite(), "Finite pixel rectangles only")
			for index in range(cfg.particle_count):
				check(behavior.particle(index,t) == behavior.particle(index,t), "Particle path deterministic")
		pixel.time = behavior.duration(stop)+1
		check(pixel.build_commands().is_empty(), "Dissipated pure effect leaves no pixels")
		pixel.stop_at = -1
	pixel.free()
	var lab := Lab.instantiate()
	root.add_child(lab)
	lab.set_process(false)
	lab.auto_demo = false
	check(lab.renderer.behavior == lab.behavior, "Renderer consumes shared behavior")
	lab.clock = 0.6
	key(lab,KEY_SPACE)
	lab._process(0.1)
	check(is_equal_approx(lab.clock,0.6), "Pause freezes clock")
	key(lab,KEY_RIGHT)
	check(is_equal_approx(lab.clock,0.6+1.0/60) and not lab.playing, "Single step advances once")
	lab.stop_charge()
	check(is_equal_approx(lab.stop_at,lab.clock), "Stop records current charge time")
	var first_stop: float = lab.stop_at
	lab.clock += 0.05; lab.stop_charge()
	check(lab.stop_at == first_stop, "Repeated stop does not prolong cleanup")
	key(lab,KEY_R)
	check(lab.clock == 0 and lab.playing and lab.stop_at == -1, "Replay clears stop and resumes")
	lab.stop_charge()
	check(lab.stop_at == -1, "Idle stop ignored")
	lab._process(100)
	check(lab.stop_at == -1 and lab.behavior.sample(lab.clock).phase == "SUSTAIN", "Manual mode never auto stops")
	lab.stop_charge()
	check(lab.stop_at == lab.clock, "Stop works after long sustain")
	lab.looping = false
	lab._process(10)
	check(not lab.playing and lab.clock == lab.behavior.duration(lab.stop_at), "Explicitly stopped nonloop terminates")
	lab.replay()
	key(lab,KEY_S); lab._process(0.4)
	check(is_equal_approx(lab.clock,0.1), "Quarter speed uses shared clock")
	key(lab,KEY_S)
	lab.auto_demo = true
	lab.replay()
	lab._process(lab.demo_stop_time()+0.1)
	check(lab.stop_at == lab.demo_stop_time(), "Auto demo explicitly requests stop at its own boundary")
	check(lab.behavior.sample(lab.clock,lab.stop_at).phase == "DISSIPATE", "Auto demo shows independent cleanup")
	lab._process(10)
	check(not lab.playing, "Auto demo nonloop terminates")
	lab.looping = true
	lab.replay()
	var demo_end: float = lab.behavior.duration(lab.demo_stop_time())
	lab._process(demo_end+0.1)
	check(is_equal_approx(lab.clock,0.1) and lab.stop_at == -1, "Auto demo loop clears explicit stop")
	key(lab,KEY_A)
	check(not lab.auto_demo and lab.clock == 0 and lab.stop_at == -1, "Manual toggle resets stale auto stop")
	lab._process(100)
	check(lab.stop_at == -1 and lab.playing, "Manual mode after auto demo remains sustained")
	var child_count: int = lab.get_child_count()
	for index in range(100):
		lab.replay(); lab.clock = 0.6; lab.stop_charge(); lab.apply_preset(index%4)
	check(lab.get_child_count() == child_count, "Repeated replay/stop/presets do not add nodes")
	lab.apply_preset(0)
	lab.clock = 0.7; lab.stop_charge()
	lab.fields["radius"].value = 31
	check(lab.settings.radius == 31 and lab.clock == 0 and lab.stop_at == -1 and lab.playing, "SpinBox signal updates, clears stop and replays")
	lab.set_parameter("radius",999)
	check(lab.settings.radius == 64 and lab.fields["radius"].value == 64, "Edit synchronizes bounded UI")
	lab.apply_preset(0)
	check(lab.settings.radius == 48 and lab.settings.charge_seconds == 1.2 and lab.settings.particle_count == 24, "Reset restores defaults")
	lab.auto_demo = false
	lab.clock = 10.0
	lab.fields["intensity"].value = 0.5
	check(lab.clock == 10.0 and lab.behavior.sample(lab.clock).charge == 0.5, "Intensity changes sustained charge live without restart")
	key(lab,KEY_P)
	check(lab.parameter_panel.visible, "Parameters opens")
	key(lab,KEY_ESCAPE)
	check(not lab.parameter_panel.visible, "Escape closes parameters")
	lab.free()
	print("PIXEL_CHARGE_LAB: %d checks, %d failures" % [checks,failures])
	quit(failures)
