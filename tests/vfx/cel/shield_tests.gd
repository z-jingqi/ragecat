extends SceneTree
## Independent shield geometry, event history and lifecycle contracts; native visual review is separate.
const Config = preload("res://scripts/vfx/cel/shield_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/shield.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/shield_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/shield_lab.gd")
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
	if commands.size() > 4096: return "Unbounded active command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color") or not command.has("layer"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 512: return "Invalid vertex count"
		if polygon_area(points) < 0.000001: return "Degenerate polygon"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d (%s)" % [index,command.layer]
		for point in points:
			if not point.is_finite() or point.length() > 12000: return "Nonfinite or unbounded vertex"
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return "Not a finite opaque cel color"
		if color.r < 0 or color.r > 1 or color.g < 0 or color.g > 1 or color.b < 0 or color.b > 1: return "Cel color outside normalized palette"
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

func bool_names(config: Resource) -> Array:
	var result: Array = []
	for property in config.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.type == TYPE_BOOL: result.append(property.name)
	return result

func polygon_area(points: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in range(points.size()): twice_area += points[i].cross(points[(i+1)%points.size()])
	return absf(twice_area)*0.5

func all_points(commands: Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for command in commands: points.append_array(command.points)
	return points

func total_area(commands: Array) -> float:
	var area := 0.0
	for command in commands: area += polygon_area(command.points)
	return area

func sample_cycle(effect: Node2D, samples: int = 41) -> Array:
	var result: Array = []
	for i in range(samples): result.append(effect.build_commands(effect.config.duration()*i/float(samples),-1))
	return result

func demo_hits(multiplier: float = 1.0) -> Array:
	return [{"time":0.72*multiplier,"angle":-35.0,"strength":1.0},{"time":1.20*multiplier,"angle":155.0,"strength":0.8}]

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
	check(is_finite(duration) and duration > 0,"Default shield has a positive complete finite lifetime")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Duration multiplier includes spawn, hold, break and clearance")

func test_events() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var input := demo_hits()
	check(effect.set_hit_events(input),"Host can submit an explicit local-angle hit timeline")
	var accepted: Array = effect.get_hit_events()
	check(accepted.size() == 2,"Accepted host timeline preserves both events")
	input[0].time = 99.0
	input.append({"time":0.1,"angle":0,"strength":1})
	check(effect.get_hit_events() == accepted,"Hit timeline is deep copied on input")
	var returned: Array = effect.get_hit_events()
	returned[0].angle = 99.0
	returned.clear()
	check(effect.get_hit_events() == accepted,"Hit snapshot accessor returns an independent deep copy")
	for bad in [[null],[3],[{}],[{"time":0.1,"angle":1}],[{"time":-0.1,"angle":0,"strength":1}],[{"time":NAN,"angle":0,"strength":1}],[{"time":INF,"angle":0,"strength":1}],[{"time":0.5,"angle":NAN,"strength":1}],[{"time":0.5,"angle":INF,"strength":1}],[{"time":0.5,"angle":0,"strength":0}],[{"time":0.5,"angle":0,"strength":-1}],[{"time":0.5,"angle":0,"strength":NAN}],[{"time":0.5,"angle":0,"strength":INF}],[{"time":"late","angle":0,"strength":1}]]:
		check(not effect.set_hit_events(bad) and effect.get_hit_events() == accepted,"Invalid event batch is rejected atomically: " + str(bad))
	check(not effect.set_hit_events([{"time":0.1,"angle":0,"strength":1},{"time":NAN,"angle":0,"strength":1}]) and effect.get_hit_events() == accepted,"Invalid later event cannot partially replace an accepted timeline")
	effect.configure(Config.new())
	check(effect.get_hit_events() == accepted,"Reconfiguring preserves the explicit host event snapshot")
	var overfull: Array = []
	for i in range(17): overfull.append({"time":float(i),"angle":0.0,"strength":1.0})
	check(not effect.set_hit_events(overfull) and effect.get_hit_events() == accepted,"Oversized explicit timeline is rejected without losing prior events")
	check(effect.set_hit_events([{"time":0.8,"angle":725.0,"strength":100.0}]),"Finite extreme hit angle and strength are normalized")
	var normalized: Array = effect.get_hit_events()
	check(normalized.size() == 1 and is_equal_approx(normalized[0].strength,2.0) and absf(normalized[0].angle) <= 180.0,"Hit strength caps and angle wraps into the local circle")
	check(effect.set_hit_events([{"time":0.8,"angle":5.0,"strength":2.0}]),"Equivalent normalized event accepted")
	var equivalent: Array = effect.build_commands(0.85,INF)
	effect.set_hit_events(normalized)
	check(effect.build_commands(0.85,INF) == equivalent,"Equivalent local hit angles reconstruct identical geometry")
	effect.clear_hits()
	check(effect.get_hit_events().is_empty(),"Explicit clear removes all hit events")
	check(not effect.hit(-35,1) and effect.get_hit_events().is_empty(),"Dormant component rejects live hits")
	effect.seek(1.0,-1,true)
	check(effect.hit(-35,1) and not effect.playing,"Live hit records the current actual age without resuming a paused seek")
	check(is_equal_approx(effect.get_hit_events()[0].time,1.0),"Live hit timestamp uses current real seconds")
	for bad in [[NAN,1.0],[INF,1.0],[0.0,NAN],[0.0,INF],[0.0,0.0],[0.0,-1.0]]:
		var before: Array = effect.get_hit_events()
		check(not effect.hit(bad[0],bad[1]) and effect.get_hit_events() == before,"Invalid live hit is a nonmutating rejection")
	for i in range(50): effect.hit(float(i)*11.0,1)
	check(effect.get_hit_events().size() == 16,"Repeated same-frame live hits evict to the bounded 16-event window")
	check(geometry_problem(effect.build_commands(1.1,INF)).is_empty(),"Maximum simultaneous live hits remain bounded and triangulatable")
	effect.seek(100.0,-1,true)
	check(effect.hit(-35,1) and effect.get_hit_events().size() == 1,"A later live hit prunes expired history before append")
	var snapshot: Array = effect.get_hit_events()
	for i in range(20): effect.build_commands(100.0+i*0.01,INF)
	check(effect.get_hit_events() == snapshot and effect.age == 100.0 and not effect.playing,"Pure command evaluation does not mutate history, age or playback")
	effect.break_shield()
	check(not effect.hit(20,1),"Broken shield rejects new live hit events")
	effect.play(true)
	check(effect.get_hit_events().is_empty(),"Replay starts a clean live-hit history")
	effect.set_hit_events(demo_hits())
	effect.stop()
	check(effect.get_hit_events().is_empty(),"Stop clears bounded hit history")
	check(effect.set_hit_events([]) and effect.get_hit_events().is_empty(),"Empty explicit timeline is a valid clear")
	effect.free()

func test_motion_and_parameters() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	effect.set_hit_events(demo_hits())
	var baseline: Array = sample_cycle(effect)
	check(baseline == sample_cycle(effect),"Shield geometry and host hit schedule are deterministic")
	seed(82731)
	var expected_rng := randi()
	seed(82731)
	sample_cycle(effect)
	check(randi() == expected_rng,"Shield rendering does not consume gameplay random state")
	effect.config.seed_value += 1
	check(baseline != sample_cycle(effect),"Seed changes source patches or fragment arrangement")
	effect.configure(Config.new())
	effect.clear_hits()
	var first: Array = effect.build_commands(0.6,INF)
	var second: Array = effect.build_commands(0.95,INF)
	check(not first.is_empty() and not second.is_empty(),"Held shield remains visible after spawn")
	check(affine_residual(all_points(first),all_points(second)) > 0.0001,"Held surface has intrinsic motion, not a static shield logo under a global transform")
	check(total_area(effect.build_commands(0.08,INF)) < total_area(effect.build_commands(0.4,INF)),"Spawn progressively establishes the perimeter instead of appearing fully formed")
	for phase in [0.08,0.30,0.55,0.75,0.90]:
		effect.configure(Config.new())
		effect.set_hit_events(demo_hits())
		var time: float = effect.config.duration()*phase
		var original: Array = effect.build_commands(time,-1)
		effect.config.size = 2
		check(transformed_matches(effect.build_commands(time,-1),original,2,0),"Size transforms shell, impacts and fragments at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.direction_degrees = 37
		check(transformed_matches(effect.build_commands(time,-1),original,1,deg_to_rad(37)),"Direction rotates complete shield and local-angle events at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.duration_scale = 2
		effect.set_hit_events(demo_hits(2))
		check(original == effect.build_commands(time*2,-1),"Scaled real-time hit timestamps preserve normalized geometry at phase %.2f" % phase)
	for spec in range_specs(Config.new()):
		if spec[0] in ["size","direction_degrees","duration_scale"]: continue
		var config := Config.new()
		config.set(spec[0],spec[1])
		effect.configure(config)
		effect.set_hit_events(demo_hits())
		var minimum: Array = sample_cycle(effect,61)
		config.set(spec[0],spec[2])
		effect.configure(config)
		check(minimum != sample_cycle(effect,61),"Advertised knob changes shape, timing or hit response: " + spec[0])
	var toggles := bool_names(Config.new())
	for toggle in toggles:
		if toggle == "show_fragments": continue # This gates the shell phase, not a standalone color layer.
		var config := Config.new()
		for name in toggles: config.set(name,name == toggle)
		effect.configure(config)
		effect.set_hit_events(demo_hits())
		var present := false
		for commands in sample_cycle(effect,61): present = present or not commands.is_empty()
		check(present,"Layer can be composed independently: " + toggle)
	for toggle in toggles: effect.config.set(toggle,false)
	var any_geometry := false
	for commands in sample_cycle(effect): any_geometry = any_geometry or not commands.is_empty()
	check(not any_geometry,"All shield layers can be disabled")
	var colored := Config.new()
	var custom := Color(0.17,0.46,0.63,1)
	for name in color_names(colored): colored.set(name,custom)
	effect.configure(colored)
	effect.set_hit_events(demo_hits())
	var matches := true
	for commands in sample_cycle(effect):
		for command in commands: matches = matches and command.color == custom
	check(matches,"Exposed palette owns every opaque cel color")
	effect.configure(Config.new())
	effect.clear_hits()
	for time in [10.0,3600.0,86400.0]:
		var commands: Array = effect.build_commands(time,INF)
		check(not commands.is_empty() and geometry_problem(commands).is_empty(),"Long-held shield remains bounded at %.0f seconds" % time)
		check(commands == effect.build_commands(time,INF),"Long-held shell is reproducible at %.0f seconds" % time)
	var unhit: Array = effect.build_commands(0.85,INF)
	effect.set_hit_events([{"time":1.0,"angle":-35.0,"strength":1.0}])
	check(effect.build_commands(0.85,INF) == unhit,"Future hit cannot affect earlier shell geometry")
	effect.set_hit_events([{"time":0.8,"angle":-35.0,"strength":1.0}])
	check(effect.build_commands(0.85,INF) != unhit,"Active impact visibly affects the shield")
	effect.clear_hits()
	var expired: Array = effect.build_commands(1.6,INF)
	effect.set_hit_events([{"time":0.8,"angle":-35.0,"strength":1.0}])
	check(effect.build_commands(1.6,INF) == expired,"Expired hit leaves no permanent distortion or sparkle residue")
	effect.free()
func shell_commands(commands: Array) -> Array:
	var result: Array = []
	for command in commands:
		if command.layer in ["rim","body","highlight","streak"]: result.append(command)
	return result

func point_inside_any(point: Vector2, polygons: Array, tolerance: float = 0.06) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
		for i in range(polygon.size()):
			if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) <= tolerance: return true
	return false

func attachment_problem(commands: Array) -> String:
	var source := {}
	var pivots := {}
	for command in commands:
		if command.layer not in ["rim","body","highlight"]: continue
		var piece: int = command.get("piece",-999)
		if piece == -999: return "Missing source piece identity"
		if command.has("pivot"):
			var pivot: Vector2 = command.pivot
			if not pivot.is_finite(): return "Nonfinite source pivot"
			if pivots.has(piece) and not pivot.is_equal_approx(pivots[piece]): return "Color layers have different source-piece pivots"
			pivots[piece] = pivot
		if command.layer == "rim":
			if not source.has(piece): source[piece] = []
			source[piece].append(command.points)
	for command in commands:
		if command.layer not in ["body","highlight"]: continue
		var piece: int = command.get("piece",-999)
		if not source.has(piece): return "Color layer has no supporting source rim"
		for point in command.points:
			if not point_inside_any(point,source[piece]): return "Color layer escaped its source rim"
	return ""

func nearest_vertex_distance(point: Vector2, points: PackedVector2Array) -> float:
	var distance := INF
	for source in points: distance = minf(distance,point.distance_to(source))
	return distance

func test_source_break_and_layers() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	for break_time in [0.0,0.04,0.19,0.8,2.5]:
		effect.clear_hits()
		if break_time >= 0.8: effect.set_hit_events([{"time":break_time-0.08,"angle":-35.0,"strength":1.0}])
		effect.seek(break_time,-1,true)
		var source: Array = shell_commands(effect.build_commands())
		var points := all_points(source)
		var colors := {}
		for command in source:
			var piece: int = command.get("piece",-999)
			if not colors.has(piece): colors[piece] = []
			colors[piece].append(command.color)
		effect.break_shield()
		check(source == shell_commands(effect.build_commands()),"Break snapshots exactly the visible shell, including partial spawn or active dent at %.2f" % break_time)
		var tiny_step: Array = shell_commands(effect.build_commands(break_time+0.00001))
		var distance := 0.0
		var corresponding := source.size() == tiny_step.size()
		if corresponding:
			for i in range(source.size()): corresponding = corresponding and source[i].layer == tiny_step[i].layer and source[i].piece == tiny_step[i].piece and source[i].points.size() == tiny_step[i].points.size()
		if corresponding:
			# Frozen source cells retain their ordered vertices; this exact mapping
			# is stricter and cheaper than an all-pairs nearest-neighbor search.
			for i in range(source.size()):
				for j in range(source[i].points.size()): distance = maxf(distance,source[i].points[j].distance_to(tiny_step[i].points[j]))
		else:
			for point in all_points(tiny_step): distance = maxf(distance,nearest_vertex_distance(point,points))
		check(distance < 0.15,"Break boundary is continuous and never invents a complete shield at %.2f" % break_time)
		var preserves_source := true
		for fraction in [0.0,0.02,0.20,0.50,0.80]:
			var commands: Array = effect.build_commands(break_time+fraction*effect.config.break_seconds)
			var problem := geometry_problem(commands)
			check(problem.is_empty(),"Early/held break geometry is valid at %.2f + %.2f: %s" % [break_time,fraction,problem])
			problem = attachment_problem(commands)
			check(problem.is_empty(),"Source colors stay attached through break at %.2f + %.2f: %s" % [break_time,fraction,problem])
			for command in shell_commands(commands):
				var piece: int = command.get("piece",-999)
				preserves_source = preserves_source and colors.has(piece) and command.color in colors.get(piece,[])
		check(preserves_source,"All curved shell fragments retain source identities and source palette at %.2f" % break_time)
		if break_time == 0: check(effect.build_commands(0.1).is_empty(),"Breaking before any shell exists cannot produce replacement fragments")
		check(effect.build_commands(effect.get_end_time()).is_empty(),"Source-bound fragments clear at the declared end time")
	for time in [0.12,0.65,0.84,1.4,1.95]:
		effect.configure(Config.new())
		effect.set_hit_events(demo_hits())
		effect.seek(time,-1,false)
		var complete: Array = effect.build_commands()
		for toggle in bool_names(Config.new()):
			var config := Config.new()
			config.set(toggle,false)
			effect.configure(config)
			var independent := true
			for command in effect.build_commands():
				if command not in complete: independent = false
			check(independent,"Hiding %s does not change other source geometry at %.2f" % [toggle,time])
		effect.configure(Config.new())
	effect.clear_hits()
	effect.seek(0.8,-1,true)
	effect.break_shield()
	check(affine_residual(all_points(effect.build_commands(0.82)),all_points(effect.build_commands(1.15))) > 0.0001,"Break separates source pieces rather than globally moving one shield logo")
	effect.free()

func test_lifecycle() -> void:
	var input := Config.new()
	input.size = 99
	var effect := EffectScene.instantiate()
	effect.configure(input)
	root.add_child(effect)
	effect.set_process(false)
	check(input.size == 99 and effect.config.size == 3,"Configuration is deep copied before sanitizing")
	effect.configure(null)
	check(values(effect.config) == values(Config.new()),"Null configuration restores defaults")
	check(not effect.playing and effect.build_commands().is_empty() and effect.get_child_count() == 0,"Shield starts dormant without actor, projectiles or child particle history")
	for invalid_age in [-1.0,INF,NAN]: check(effect.build_commands(invalid_age,-1).is_empty(),"Invalid explicit age renders nothing")
	check(effect.build_commands(0.5,NAN).is_empty(),"NaN explicit break is safely empty")
	check(effect.build_commands(0.5,-2).is_empty(),"Unsupported negative break override is safely empty")
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"Finite terminal age equals the configured complete cycle")
	effect.finished.connect(func(): finish_count += 1)
	effect.break_shield()
	check(effect.break_at < 0 and not effect.playing,"Dormant break is ignored")
	effect.play()
	effect._process(0.1)
	check(effect.playing and is_equal_approx(effect.age,0.1),"Play advances spawn from zero")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative or nonfinite delta cannot rewind or corrupt age")
	effect._process(effect.get_end_time()+1)
	effect._process(1)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Finite shield clears and emits completion exactly once")
	var completed_break: float = effect.break_at
	effect.break_shield()
	check(effect.break_at == completed_break and not effect.hit(0,1),"Completed shell cannot restart from break or hit")
	effect.play(true)
	check(effect.get_end_time() == INF and effect.break_at < 0,"Held play clears break and has no automatic end")
	effect._process(10)
	check(effect.playing and not effect.build_commands().is_empty() and finish_count == 1,"Held shell survives beyond the default finite lifetime")
	check(effect.hit(30,1),"Live held shell accepts a localized hit")
	effect.break_shield()
	var first_break: float = effect.break_at
	var end_time: float = effect.get_end_time()
	check(is_equal_approx(first_break,10) and is_finite(end_time),"Manual break records actual absolute time and establishes a finite tail")
	effect._process(0.1)
	effect.break_shield()
	check(effect.break_at == first_break and effect.get_end_time() == end_time,"Repeated break cannot refresh or extend the tail")
	effect._process(end_time+1)
	check(not effect.playing and finish_count == 2 and effect.build_commands().is_empty(),"Released held shield finishes exactly once")
	for early in [0.04,0.65]:
		effect.seek(early,-1,true)
		effect.break_shield()
		check(not effect.playing and effect.break_at == early,"Manual break preserves pause at %.2f" % early)
		var frozen_age: float = effect.age
		effect._process(1)
		check(effect.age == frozen_age,"Paused break remains manually controlled")
		check(effect.build_commands(effect.get_end_time(),early).is_empty(),"Early break empties by its declared end")
	effect.seek(effect.config.duration()-0.1,-1,false)
	var auto_end: float = effect.get_end_time()
	effect.break_shield()
	check(effect.get_end_time() == auto_end,"Late break cannot restart automatic dismantling")
	effect.seek(2.0,2.2,false)
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"Late explicit finite break is clamped to the automatic boundary")
	check(effect.build_commands(2.25,2.2) == effect.build_commands(2.25,-1),"Finite override cannot render a resurrected shell")
	effect.seek(0.5,0.3,true)
	check(effect.build_commands() == effect.build_commands(0.5,0.3),"Seek reconstructs explicit real-time break state")
	check(effect.build_commands(0.5,-1) != effect.build_commands(0.5,0.3),"Explicit -1 overrides node state with finite automatic break")
	effect.play()
	check(effect.age == 0 and effect.break_at < 0 and is_equal_approx(effect.get_end_time(),effect.config.duration()),"Replay clears previous break and hold state")
	effect.stop()
	effect.stop()
	check(not effect.playing and effect.build_commands().is_empty() and finish_count == 2,"Stop is silent, immediate and repeatable")
	effect.seek(NAN)
	check(effect.build_commands().is_empty(),"Invalid seek is dormant")
	for repeat in range(25): effect.play(); effect._process(effect.config.duration()+1)
	check(finish_count == 27 and effect.get_child_count() == 0,"Repeated completed cycles keep stable nodes and once-per-play completion")
	effect.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 78127
	for variant in range(18):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config): config.set(spec[0],spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2])))
			config.seed_value = variant*4793
		effect.configure(config)
		effect.set_hit_events(demo_hits(config.duration_scale))
		var problem := ""
		for frame in range(121):
			var age: float = effect.config.duration()*frame/120.0
			var commands: Array = effect.build_commands(age,-1)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age,-1): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite opaque bounded triangulation for 121 poses in variant %d: %s" % [variant,problem])
		check(effect.build_commands(effect.config.duration(),-1).is_empty(),"Every sanitized finite configuration ends empty")
		check(geometry_problem(effect.build_commands(3600,INF)).is_empty(),"Every sanitized variant has bounded late-held geometry")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		effect.configure(config)
		effect.set_hit_events(demo_hits(multiplier))
		var automatic: float = (config.spawn_seconds+config.hold_seconds)*multiplier
		for requested in [-1.0,0.0,0.03*multiplier,0.18*multiplier,2.2*multiplier]:
			var actual: float = automatic if requested < 0 else requested
			var terminal: float = actual+(config.break_seconds+0.04)*multiplier
			effect.seek(0.1,requested,requested >= 0)
			check(is_equal_approx(effect.get_end_time(),terminal),"End time uses actual break plus the scaled fragment tail")
			var boundaries := [0.0,config.spawn_seconds*multiplier,0.72*multiplier,1.20*multiplier,actual,actual+config.break_seconds*multiplier,terminal]
			var problem := ""
			for boundary in boundaries:
				for epsilon in [0.0,0.001,0.00001,0.0000001,0.000000001,0.00000000001]:
					for side in [-1.0,1.0]:
						var age: float = boundary+side*epsilon
						var current := geometry_problem(effect.build_commands(age,requested))
						if not current.is_empty(): problem = "%s at %.17f" % [current,age]
			check(problem.is_empty(),"Dense spawn/hit/break boundaries at scale %.2f and break %.2f: %s" % [multiplier,requested,problem])
			check(effect.build_commands(terminal,requested).is_empty(),"Every early/held break reaches complete clearance")
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
	# SpinBox defers LineEdit formatting while its containing panel is hidden.
	# Assert the actual visible editor, not the cached hidden minimum label.
	lab.toggle_parameters()
	await process_frame
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			var expected: float = lab.effect.config.get(name)
			check(is_equal_approx(control.value,expected) and is_equal_approx(float(control.get_line_edit().text),expected),"Numeric UI displays the exact configured default without step rounding: " + name)
	lab.toggle_parameters()
	check(not lab.held_shield and lab.broken_at < 0 and not lab.floor_host,"Whirlwind lab begins as finite generic emitter, not a gameplay hazard")
	key(lab,KEY_H)
	key(lab,KEY_H,true)
	check(lab.held_shield and lab.effect.get_end_time() == INF,"Hold toggle is reflected in component state and ignores echoes")
	lab.step(5)
	check(lab.elapsed > lab.effect.config.duration() and lab.effect.get_end_time() == INF,"Held preview survives beyond the finite cycle")
	key(lab,KEY_SPACE)
	var held_age: float = lab.elapsed
	lab._process(0.1)
	check(not lab.playing and lab.elapsed == held_age,"Pause holds a sustained barrier")
	key(lab,KEY_J)
	check(lab.manual_timeline and not lab.playing and lab.manual_hits.size() > 0,"Manual hit at paused held age records a bounded host snapshot without unpausing")
	key(lab,KEY_2)
	check(lab.manual_hits[-1].angle == 155.0,"Second contact control uses its declared local angle")
	key(lab,KEY_F)
	var first_break: float = lab.broken_at
	var first_end: float = lab.effect.get_end_time()
	check(not lab.playing and first_break == held_age and is_finite(first_end),"Manual break preserves pause and records the actual held age")
	key(lab,KEY_RIGHT)
	key(lab,KEY_F)
	check(lab.broken_at == first_break and lab.effect.get_end_time() == first_end,"Repeated break and frame stepping cannot extend the tail")
	lab.replay()
	check(lab.playing and lab.held_shield and lab.broken_at < 0 and is_equal_approx(lab.elapsed,-0.35),"Replay clears break but retains selected hold mode")
	lab.set_hold_shield(false)
	lab.step(lab.effect.config.duration()+0.1)
	var normal_end: float = lab.effect.get_end_time()
	lab.trigger_break()
	check(lab.broken_at < 0 and lab.effect.get_end_time() == normal_end,"Late finite break never resurrects or extends extinguishing shield")
	lab.reset_defaults()
	var full_fit: float = lab.fit_scale
	lab.set_hold_shield(true)
	lab.step(0.39)
	lab.trigger_break()
	lab._fit_effect()
	check(is_equal_approx(lab.fit_scale,full_fit),"Framing samples the full finite cycle rather than a previous early-break tail")
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
	lab.set_hold_shield(true)
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and not lab.held_shield and lab.broken_at < 0 and lab.playback_speed == 1 and not lab.effect_only,"Reset restores finite mode and exact defaults")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(),"Numeric editor takes focus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab._input(escape)
	check(not editor.has_focus() and not lab.settings_panel.visible,"Escape closes interrupted editing and breaks focus")
	lab.toggle_parameters()
	var popup: PopupPanel = lab.color_controls[color_names(lab.effect.config)[0]].get_popup()
	popup.show()
	lab.toggle_parameters()
	check(not popup.visible and not lab.settings_panel.visible,"Panel close also closes palette popup")
	var count: int = lab.get_child_count()
	for repeat in range(20):
		lab.set_hold_shield(true)
		lab.step(0.6)
		lab.trigger_break()
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == count and lab.playing and lab.broken_at < 0,"Repeated held/breakd/interrupted cycles do not accumulate nodes")
	lab.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var elapsed := -0.35
	var broken_at := -1.0
	var previous_segment := -1
	var seen := {}
	var problem := ""
	var light_pass_clear := false
	var seen_hit := false
	var seen_ripple := false
	for frame in range(Lab.SHIELD_CAPTURE_FRAMES):
		var segment: int = frame/360
		if segment != previous_segment:
			previous_segment = segment
			elapsed = -0.35
			broken_at = -1.0
			seen[segment] = true
		if segment == 0 and elapsed >= effect.config.duration()+0.55: elapsed = -0.35
		elapsed += (1.0 if segment == 0 else 0.5)/60.0
		if segment == 2 and elapsed >= 1.75 and broken_at < 0: broken_at = 1.75
		effect.seek(elapsed,broken_at,segment == 2)
		effect.set_hit_events([{"time":effect.config.spawn_seconds+effect.config.hold_seconds*0.25,"angle":-35.0,"strength":1.0},{"time":effect.config.spawn_seconds+effect.config.hold_seconds*0.57,"angle":155.0,"strength":0.85}])
		var commands: Array = effect.build_commands()
		var current := geometry_problem(commands)
		if not current.is_empty(): problem = "%s at frame %d" % [current,frame]
		for command in commands:
			seen_hit = seen_hit or command.layer == "hit"
			seen_ripple = seen_ripple or command.layer == "ripple"
		if segment == 1 and elapsed > effect.get_end_time() and commands.is_empty(): light_pass_clear = true
	check(Lab.SHIELD_CAPTURE_FRAMES == 1080 and seen.size() == 3,"Capture is the declared 18-second normal/light/held-break sequence")
	check(problem.is_empty(),"Every exact 1080-frame viewport capture pose triangulates: " + problem)
	check(seen_hit and seen_ripple,"Capture includes local contacts and traveling surface ripples")
	check(light_pass_clear,"Light-background slow pass reaches finite break clearance")
	effect.seek(elapsed,broken_at,true)
	check(broken_at == 1.75 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(),"Final capture pass includes manual held break and complete fragment clearance")
	effect.free()

func test_local_hit_and_flow() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	effect.clear_hits()
	var original: Array = effect.build_commands(0.85,INF)
	effect.set_hit_events([{"time":0.8,"angle":-35.0,"strength":1.0}])
	var impacted: Array = effect.build_commands(0.85,INF)
	var target := layer_points(impacted,"rim")
	var near_motion := 0.0
	var far_motion := 0.0
	var normal := Vector2.from_angle(deg_to_rad(-35))
	for point in layer_points(original,"rim"):
		var direction := Vector2(point.x,point.y/effect.config.aspect).normalized()
		var distance := nearest_vertex_distance(point,target)
		if direction.dot(normal) > 0.9: near_motion = maxf(near_motion,distance)
		if direction.dot(normal) < -0.5: far_motion = maxf(far_motion,distance)
	check(near_motion > 0.05,"A hit dents the shell locally, not just a detached flare")
	check(far_motion < 0.002,"The far side of the barrier is not globally squashed by a local impact")
	effect.clear_hits()
	effect.seek(0.0,-1,true)
	check(not effect.hit(90,1) and effect.get_hit_events().is_empty(),"Exact age-zero bottom contact is rejected because no shell exists yet")
	effect.set_hit_events([{"time":0.0,"angle":90.0,"strength":1.0}])
	var zero_hit: Array = effect.build_commands(0.05,INF)
	effect.clear_hits()
	check(zero_hit == effect.build_commands(0.05,INF),"Zero-age scripted bottom hit cannot create a flare on an absent shell")
	effect.seek(0.01,-1,true)
	check(not effect.hit(-90,1),"A live hit rejects a top arc that has not yet spawned")
	effect.set_hit_events([{"time":0.01,"angle":-90.0,"strength":1.0}])
	var too_early: Array = effect.build_commands(0.08,INF)
	effect.clear_hits()
	check(too_early == effect.build_commands(0.08,INF),"Invalid early scripted impact does not invent an unbuilt shell surface")
	var early := layer_points(effect.build_commands(0.08,INF),"rim")
	var minimum_radius := INF
	for point in early: minimum_radius = minf(minimum_radius,Vector2(point.x,point.y/effect.config.aspect).length())
	check(not early.is_empty() and minimum_radius > effect.config.radius*0.5,"Spawn closes angular arcs at the barrier radius, rather than scaling a whole small circle")
	effect.seek(1.0,0.7,true)
	effect.set_hit_events([{"time":0.8,"angle":-35.0,"strength":1.0}])
	var post_break: Array = effect.build_commands()
	effect.clear_hits()
	check(post_break == effect.build_commands(),"A scripted hit after break cannot affect destroyed shell fragments")
	effect.set_hit_events([{"time":0.65,"angle":-35.0,"strength":1.0}])
	var broken: Array = effect.build_commands(0.75,0.7)
	check(layer_points(broken,"hit").is_empty() and layer_points(broken,"ripple").is_empty(),"Active crown and surface waves end when the source barrier breaks")
	effect.clear_hits()
	effect.seek(0.8,-1,true)
	for turn in [1.0,2.0,3.0]:
		var boundary: float = TAU/1.7*turn
		var before := layer_points(effect.build_commands(boundary-0.00001,INF),"streak")
		var after := layer_points(effect.build_commands(boundary+0.00001,INF),"streak")
		var jump := 0.0
		for point in before: jump = maxf(jump,nearest_vertex_distance(point,after))
		check(jump < 0.15,"Secondary streak motion remains continuous through primary phase wrap %d" % turn)
	var frozen := Config.new()
	frozen.flow_speed = 0
	effect.configure(frozen)
	check(effect.build_commands(0.6,INF) == effect.build_commands(1.2,INF),"Zero flow speed freezes held shell geometry without freezing lifecycle")
	var strong := Config.new()
	strong.dent_depth = 22
	strong.intensity = 2
	strong.flow_speed = 0
	effect.configure(strong)
	effect.clear_hits()
	effect.seek(0.8,-1,true)
	effect.set_hit_events([{"time":0.8,"angle":0.0,"strength":2.0}])
	var impact_age: float = 0.8+strong.hit_seconds*0.12
	var impact: Array = effect.build_commands(impact_age,INF)
	var crown_base := Vector2(INF,INF)
	for command in impact:
		if command.layer == "hit" and command.points.size() == 3:
			var base: Vector2 = (command.points[0]+command.points[2])*0.5
			if absf(base.y) < 0.001: crown_base = base
	var expected_radius: float = strong.radius-strong.dent_depth*2.0*strong.intensity*sin(0.12*PI)*exp(-0.12*3.0)
	check(crown_base.is_finite() and absf(crown_base.x-expected_radius) < 0.005,"Central contact crown follows the locally dented surface, not the original undeformed ring")
	var contact_distance := INF
	for polygon in layer_shapes(impact,"rim"):
		for i in range(polygon.size()): contact_distance = minf(contact_distance,crown_base.distance_to(Geometry2D.get_closest_point_to_segment(crown_base,polygon[i],polygon[(i+1)%polygon.size()])))
	check(contact_distance < 0.5,"Visible contact root remains attached to the actual deformed shell geometry")
	effect.configure(Config.new())
	effect.clear_hits()
	var full_shell := layer_shapes(effect.build_commands(effect.config.spawn_seconds,INF),"rim")
	check(point_inside_any(Vector2(0,-(effect.config.radius-0.3)*effect.config.aspect),full_shell,0.05),"Completed paired spawn arcs close the overhead seam without a persistent missing slice")
	effect.free()

func run() -> void:
	test_config()
	test_events()
	test_motion_and_parameters()
	test_source_break_and_layers()
	test_local_hit_and_flow()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_SHIELD: %d checks, %d failures" % [checks,failures])
	quit(failures)
