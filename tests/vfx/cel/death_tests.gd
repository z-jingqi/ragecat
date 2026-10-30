extends SceneTree
## Source geometry contracts; native motion review is a separate acceptance gate.
const Config = preload("res://scripts/vfx/cel/death_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/death.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/death_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/death_lab.gd")
const Study = preload("res://scripts/vfx_lab/cel/study_lab.gd")
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

func rectangle(offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(-80,-160),Vector2(80,-160),Vector2(80,0),Vector2(-80,0)])
	for i in range(points.size()): points[i] += offset
	return points

func concave_source() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-90,0),Vector2(-90,-180),Vector2(-35,-180),Vector2(-35,-65),Vector2(35,-65),Vector2(35,-180),Vector2(90,-180),Vector2(90,0)])

func regular_polygon(count: int, center: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(count): points.append(center+Vector2.from_angle(TAU*i/count)*40)
	return points

func geometry_problem(commands: Array) -> String:
	if commands.size() > 2048: return "Unbounded command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 1024: return "Invalid vertex count"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d" % index
		for point in points:
			if not point.is_finite() or point.length() > 30000: return "Nonfinite or unbounded vertex"
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
		check(config.get(name) == defaults.get(name),"Invalid palette restores default: " + name)
		config.set(name,Color(-3,8,0.5,NAN))
		config.sanitize()
		check(config.get(name) == Color(0,1,0.5,1),"Palette clamps and remains opaque: " + name)
	var duration: float = defaults.duration()
	check(is_finite(duration) and duration > 0,"Default lifetime is positive and finite")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales the complete effect")

func test_source_validation() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	check(effect.source_count() == 0 and effect.build_commands(0.2).is_empty(),"Pure component contains no hardcoded source or character")
	var first := rectangle()
	var points: Array = [first]
	var colors: Array = [Color(0.17,0.31,0.49,1)]
	check(effect.set_source_polygons(points,colors),"Explicit opaque source is accepted")
	check(effect.source_count() == 1 and effect.source_error.is_empty(),"Successful source reports count and clears errors")
	var original: Dictionary = effect.get_source_snapshot()
	var baseline: Array = effect.build_commands(0.2).duplicate(true)
	var generation: int = effect.cache_generation
	first[0] += Vector2(500,500)
	points.append(rectangle(Vector2(800,0)))
	colors[0] = Color.RED
	check(effect.get_source_snapshot() == original and effect.build_commands(0.2) == baseline,"Accepted source deep-copies both caller arrays and packed vertices")
	var returned: Dictionary = effect.get_source_snapshot()
	var returned_points: PackedVector2Array = returned.polygons[0]
	returned_points[0] += Vector2(400,400)
	returned.polygons[0] = returned_points
	returned.colors[0] = Color.GREEN
	check(effect.get_source_snapshot() == original,"Returned polygon and color data is deeply isolated")
	returned.clear()
	check(effect.get_source_snapshot() == original,"Returned snapshot container is isolated")
	for i in range(20): effect.build_commands(i/30.0)
	check(effect.cache_generation == generation,"Sampling geometry does not rebuild source cache")
	var bowtie := PackedVector2Array([Vector2(0,0),Vector2(80,60),Vector2(0,80),Vector2(60,0)])
	var invalid_cases: Array = [
		[[],[],"Empty request uses explicit clear_source instead"],
		[[[Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN]],[],"Nonpacked contour"],
		[[PackedVector2Array()],[],"Empty contour"],
		[[PackedVector2Array([Vector2.ZERO,Vector2.ONE])],[],"Two-point contour"],
		[[bowtie],[],"Crossing polygon with nonzero signed area"],
		[[PackedVector2Array([Vector2(0,0),Vector2(50,0),Vector2(100,0),Vector2(100,100),Vector2(0,100)])],[],"Collinear interior edge vertex"],
		[[PackedVector2Array([Vector2(0,0),Vector2(100,0),Vector2(0,100),Vector2(100,0),Vector2(100,100)])],[],"Repeated interior vertex"],
		[[PackedVector2Array([Vector2(0,0),Vector2(NAN,10),Vector2(10,0)])],[],"NaN coordinate"],
		[[PackedVector2Array([Vector2(0,0),Vector2(10,INF),Vector2(10,0)])],[],"Infinite coordinate"],
		[[rectangle(Vector2(5000,0))],[],"Coordinate limit"],
		[[regular_polygon(129)],[],"Per-contour vertex limit"],
		[[rectangle(),bowtie],[],"Invalid later contour cannot partially replace source"],
		[[rectangle()],[Color.WHITE,Color.RED],"Mismatched colors"],
		[[rectangle()],["white"],"Noncolor value"],
		[[rectangle()],[Color(NAN,1,1,1)],"Nonfinite source color"],
		[[rectangle()],[Color(1,1,1,0.99)],"Nonopaque source color"],
		[[rectangle()],[Color(-0.01,1,1,1)],"Out-of-range source color"],
	]
	var too_many: Array = []
	for i in range(17): too_many.append(rectangle(Vector2(i*180-1500,0)))
	invalid_cases.append([too_many,[],"Contour count limit"])
	var too_large: Array = []
	for i in range(5): too_large.append(regular_polygon(128,Vector2(i*120,0)))
	invalid_cases.append([too_large,[],"Total vertex budget"])
	for spec in invalid_cases:
		var accepted: bool = effect.set_source_polygons(spec[0],spec[1])
		check(not accepted and not effect.source_error.is_empty(),"Invalid input rejected with reason: " + spec[2])
		check(effect.get_source_snapshot() == original and effect.cache_generation == generation and effect.source_count() == 1 and effect.build_commands(0.2) == baseline,"Rejected request is fully transactional: " + spec[2])
	var reversed := rectangle()
	reversed.reverse()
	for contour in [rectangle(),reversed,concave_source()]:
		check(effect.set_source_polygons([contour]),"Simple convex/concave contours support both winding orders")
		check(effect.source_error.is_empty(),"Valid source clears the previous rejection reason")
	var closed := regular_polygon(128)
	closed.append(closed[0])
	check(effect.set_source_polygons([closed]),"One optional closing duplicate is stripped before the 128-point budget")
	var at_limit: Array = []
	for i in range(16): at_limit.append(regular_polygon(32,Vector2((i%8)*120,(i/8)*120)))
	check(effect.set_source_polygons(at_limit) and effect.source_count() == 16,"Exactly 16 contours and 512 vertices are accepted")
	check(geometry_problem(effect.build_commands(0.2)).is_empty(),"Maximum-budget source remains renderable")
	var edge := PackedVector2Array([Vector2(4000,4000),Vector2(4096,4000),Vector2(4096,4096),Vector2(4000,4096)])
	check(effect.set_source_polygons([edge]),"Coordinate bound is inclusive at componentwise 4096")
	check(effect.set_source_polygons([rectangle(),rectangle(Vector2(250,0))]),"Separated filled contours are accepted")
	var source_before: Dictionary = effect.get_source_snapshot()
	effect.configure(Config.new())
	check(effect.get_source_snapshot() == source_before,"Configure retains submitted source geometry")
	effect.seek(0.2)
	effect.clear_source()
	check(effect.source_count() == 0 and effect.build_commands().is_empty(),"Clearing source immediately removes all source-derived geometry")
	effect.clear_source()
	check(effect.source_count() == 0,"Repeated clear is safe")
	effect.free()

func area_of(points: PackedVector2Array) -> float:
	var area := 0.0
	for i in range(points.size()): area += points[i].cross(points[(i+1)%points.size()])
	return absf(area)*0.5

func inside_or_on_boundary(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		var closest := Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])
		if point.distance_squared_to(closest) < 0.0001: return true
	return false

func test_source_motion() -> void:
	var effect := EffectScene.instantiate()
	var config := Config.new()
	config.show_flash = false
	config.show_edge = false
	config.show_shards = false
	config.show_wisps = false
	effect.configure(config)
	var source := concave_source()
	var color := Color(0.17,0.31,0.49,1)
	effect.set_source_polygons([source],[color])
	var start: Array = effect.build_commands(0)
	check(start.size() == 1 and start[0].points == source and start[0].color == color,"Source-only pose preserves submitted concave shape and explicit color")
	effect.config.source_color = Color.RED
	check(effect.build_commands(0)[0].color == color,"Explicit per-contour color is not replaced by fallback palette")
	var previous_area := area_of(source)
	var safe := true
	var reduced := false
	for frame in range(61):
		var age: float = effect.config.flash_seconds+effect.config.erosion_seconds*frame/60.0
		var remaining_area := 0.0
		for command in effect.build_commands(age):
			remaining_area += area_of(command.points)
			for point in command.points:
				if not inside_or_on_boundary(point,source): safe = false
		if remaining_area > previous_area+0.25: safe = false
		if remaining_area < area_of(source)*0.8 and remaining_area > 0: reduced = true
		previous_area = remaining_area
	check(safe and reduced and previous_area == 0,"Concave source erodes continuously inside its submitted silhouette and finishes empty")
	var offset := Vector2(510,-90)
	var shifted := rectangle(offset)
	effect.set_source_polygons([shifted])
	check(effect.build_commands(0)[0].points == shifted,"Offset source vertices are respected, not replaced or recentered onto a hidden actor")
	effect.configure(Config.new())
	effect.set_source_polygons([concave_source(),rectangle(Vector2(250,0))])
	var sources: Array = effect.get_source_snapshot().polygons
	var shard_origins_valid: bool = effect._shards.size() == effect.config.shard_count
	var direction: Vector2 = Vector2.from_angle(deg_to_rad(effect.config.shard_direction_degrees))
	var birth_valid := true
	for shard in effect._shards:
		var inside := false
		for polygon in sources:
			if Geometry2D.is_point_in_polygon(shard.origin,polygon): inside = true
		shard_origins_valid = shard_origins_valid and inside
		birth_valid = birth_valid and shard.birth >= effect.config.flash_seconds and shard.birth <= effect.config.flash_seconds+effect.config.erosion_seconds
		birth_valid = birth_valid and absf(effect._front(shard.origin.dot(effect._side),shard.birth)-shard.origin.dot(effect._axis)) < 0.01
		birth_valid = birth_valid and shard.velocity.dot(direction) > 0
	check(shard_origins_valid,"Every cached shard birth is sampled from submitted source area, including valid interior points")
	check(birth_valid,"Shards are born when the front reaches their source point and drift in the configured direction")
	var motions: Array = effect._shards.duplicate(true)
	effect.configure(effect.config)
	check(effect._shards == motions,"Rebuilding the same seed/config preserves deterministic source-correlated motion")
	# A band must preserve all contributing contours, not clear earlier contours.
	config = Config.new()
	config.erode_degrees = 0
	config.show_source = false
	config.show_flash = false
	config.show_shards = false
	config.show_wisps = false
	effect.configure(config)
	effect.set_source_polygons([rectangle(),rectangle(Vector2(0,-220))])
	var upper := false
	var lower := false
	for command in effect.build_commands(config.flash_seconds+config.erosion_seconds*0.5):
		var center := Vector2.ZERO
		for point in command.points: center += point
		center /= command.points.size()
		if center.y < -200: upper = true
		else: lower = true
	check(upper and lower,"Isolated luminous edge preserves both contours in a multi-part source")
	effect.free()

func test_effect() -> void:
	var source := Config.new()
	source.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(source)
	root.add_child(effect)
	effect.set_process(false)
	check(source.size == 99 and effect.config.size == 3,"Configure copies caller settings before sanitizing")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configure restores exact defaults")
	check(effect.get_child_count() == 0 and not effect.playing and effect.build_commands().is_empty(),"Pure scene starts dormant with no actor or props")
	effect.play()
	check(effect.build_commands().is_empty(),"Playing without a source never invents character geometry")
	effect.stop()
	effect.set_source_polygons([concave_source()])
	check(not effect.playing and effect.build_commands().is_empty(),"Accepting a source does not auto-play")
	for age in [-1.0,-0.001,effect.config.duration(),999.0,INF,NAN]:
		check(effect.build_commands(age).is_empty(),"No geometry outside lifetime: %s" % age)
	check(not effect.build_commands(0).is_empty(),"Source flashes immediately at death time zero")
	var baseline: Array = effect.build_commands(0.35).duplicate(true)
	check(baseline == effect.build_commands(0.35),"Same source, seed and age yield identical geometry")
	var config := Config.new()
	config.seed_value += 1
	effect.configure(config)
	check(baseline != effect.build_commands(0.35),"Seed changes front and shard motion")
	config = Config.new()
	config.direction_degrees = 90
	effect.configure(config)
	check(transformed_matches(effect.build_commands(0.35),baseline,1,PI/2),"Direction rotates every layer about source origin")
	config = Config.new()
	config.size = 2
	effect.configure(config)
	check(transformed_matches(effect.build_commands(0.35),baseline,2,0),"Size scales every source-derived layer")
	config = Config.new()
	config.duration_scale = 2
	effect.configure(config)
	check(baseline == effect.build_commands(0.7),"Duration scale preserves normalized geometry")
	var toggles := ["show_source","show_flash","show_edge","show_shards","show_wisps"]
	for toggle in toggles:
		config = Config.new()
		for name in toggles: config.set(name,name == toggle)
		effect.configure(config)
		var at_age: float = 0.01 if toggle == "show_flash" else 0.35
		check(not effect.build_commands(at_age).is_empty(),"Layer is independently available: " + toggle)
	for toggle in toggles: effect.config.set(toggle,false)
	check(effect.build_commands(0.35).is_empty(),"All visual layers may be disabled")
	effect.configure(Config.new())
	effect.finished.connect(func(): finish_count += 1)
	effect.play()
	effect._process(0.1)
	check(effect.playing and is_equal_approx(effect.age,0.1),"One-shot advances after play")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Invalid deltas cannot poison or rewind the clock")
	effect._process(10)
	effect._process(10)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Completion clears once and emits finished once")
	effect.play()
	effect.seek(0.1)
	effect._process(10)
	check(not effect.playing and is_equal_approx(effect.age,0.1) and finish_count == 1,"Seek stops automatic time without emitting finished")
	effect.seek(NAN)
	check(effect.build_commands().is_empty(),"Invalid seek is empty")
	for repeat in range(30): effect.play(); effect._process(effect.config.duration()+1)
	check(finish_count == 31 and effect.get_child_count() == 0,"Repeated playback completes without accumulating nodes")
	effect.play()
	effect.stop()
	effect.stop()
	effect._process(10)
	check(finish_count == 31 and not effect.playing and effect.build_commands().is_empty(),"Repeated stop clears without a false completion signal")
	effect.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 82117
	for variant in range(18):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config):
				config.set(spec[0],spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2])))
			config.seed_value = variant*4271
		effect.configure(config)
		effect.set_source_polygons([concave_source()] if variant%2 == 0 else Lab.humanoid_polygons())
		var problem := ""
		for frame in range(121):
			var age: float = effect.config.duration()*frame/120.0
			var commands: Array = effect.build_commands(age)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite opaque triangulation of 121 poses in variant %d: %s" % [variant,problem])
		check(effect.build_commands(effect.config.duration()).is_empty(),"Every legal configuration completes empty")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		effect.configure(config)
		effect.set_source_polygons(Lab.humanoid_polygons())
		var boundaries: Array = [0.0,config.flash_seconds,config.flash_seconds+config.erosion_seconds,config.duration()/multiplier]
		for shard in effect._shards: boundaries.append(shard.birth); boundaries.append(shard.birth+shard.life)
		var problem := ""
		for boundary in boundaries:
			for epsilon in [0.0,1e-4,1e-6,1e-8,1e-10]:
				for side in [-1.0,1.0]:
					var age: float = (boundary+side*epsilon)*multiplier
					var current := geometry_problem(effect.build_commands(age))
					if not current.is_empty(): problem = "%s at %.17f" % [current,age]
		check(problem.is_empty(),"Phase and source-correlated birth/death boundaries at scale %.2f: %s" % [multiplier,problem])
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
	check(not lab.floor_host and lab.source_mode == 0 and lab.effect.source_count() == 2,"Death demo owns a generic two-contour silhouette, not the ground-impact host")
	var humanoid: Dictionary = lab.effect.get_source_snapshot()
	key(lab,KEY_2)
	key(lab,KEY_1,true)
	check(lab.source_mode == 1 and lab.effect.source_count() == 1 and lab.effect.get_source_snapshot() != humanoid,"Source switch demonstrates reuse on a token and ignores key echoes")
	key(lab,KEY_1)
	check(lab.source_mode == 0 and lab.effect.get_source_snapshot() == humanoid,"Returning to silhouette restores exact submitted geometry")
	lab.step(0.5)
	var held: float = lab.elapsed
	key(lab,KEY_SPACE)
	lab._process(0.1)
	check(not lab.playing and is_equal_approx(lab.elapsed,held),"Pause holds death preview")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.elapsed,held+1.0/60),"Frame step advances once while paused")
	lab.replay()
	key(lab,KEY_S)
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter speed changes only preview time")
	key(lab,KEY_B)
	key(lab,KEY_E)
	check(lab.light_background and lab.effect_only,"Background and effect-only controls remain independent")
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			control.value = control.max_value
			check(is_equal_approx(float(lab.effect.config.get(name)),control.max_value) and is_equal_approx(lab.elapsed,-0.35),"Live numeric control sanitizes and replays: " + name)
		elif control is CheckBox:
			control.button_pressed = not control.button_pressed
			check(lab.effect.config.get(name) == control.button_pressed,"Live layer control: " + name)
	for name in lab.color_controls:
		var color := Color(0.18,0.47,0.64,1)
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color,"Live cel palette: " + name)
	check(values(lab.effect.settings) == source_before and lab.effect.get_source_snapshot() == humanoid,"UI edits preserve Inspector resource and source geometry")
	var before: Dictionary = values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	lab.set_color("unsupported",Color.RED)
	check(values(lab.effect.config) == before,"Unknown control names are no-ops")
	lab.set_source_mode(1)
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and lab.source_mode == 0 and lab.playback_speed == 1 and not lab.effect_only and not lab.light_background,"Reset restores exact settings, presentation and silhouette source")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(),"Live numeric editor receives focus")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes interrupted editing and releases focus")
	lab.toggle_parameters()
	var popup: PopupPanel = lab.color_controls["core_color"].get_popup()
	popup.show()
	lab.toggle_parameters()
	check(not popup.visible and not lab.settings_panel.visible,"Direct panel close also closes an open color popup")
	var count: int = lab.get_child_count()
	for repeat in range(20):
		lab.set_source_mode(repeat%2)
		lab.step(0.4)
		lab.toggle_play()
		lab.reset_defaults()
	check(lab.get_child_count() == count and lab.playing and lab.effect.source_count() == 2,"Repeated interrupted source swaps and replay keep stable nodes and source cache")
	lab.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	effect.set_source_polygons(Lab.humanoid_polygons())
	var elapsed := -0.35
	var previous_segment := -1
	var problem := ""
	for frame in range(Study.CAPTURE_FRAMES):
		if frame == 540: effect.set_source_polygons(Lab.token_polygons())
		var segment := 0 if frame < 300 else (1 if frame < 540 else 2)
		if segment != previous_segment: previous_segment = segment; elapsed = -0.35
		if segment == 0 and elapsed >= effect.config.duration()+0.55: elapsed = -0.35
		elapsed += (1.0 if segment == 0 else 0.5)/60.0
		var current := geometry_problem(effect.build_commands(elapsed))
		if not current.is_empty(): problem = "%s at frame %d" % [current,frame]
	check(problem.is_empty(),"Every exact 780-frame silhouette/token capture pose triangulates: " + problem)
	check(effect.source_count() == 1,"Final pure-effect capture pass demonstrates the independent token source")
	check(elapsed > effect.config.duration() and effect.build_commands(elapsed).is_empty(),"Final slow capture pass ends after all source and shards are gone")
	effect.free()

func run() -> void:
	test_config()
	test_source_validation()
	test_source_motion()
	test_effect()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_DEATH: %d checks, %d failures" % [checks,failures])
	quit(failures)
