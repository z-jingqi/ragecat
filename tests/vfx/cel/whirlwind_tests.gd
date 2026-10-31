extends SceneTree
## Analytic and lifecycle contracts; real-motion visual review remains separate.
const Config = preload("res://scripts/vfx/cel/whirlwind_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/whirlwind.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/whirlwind_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/whirlwind_lab.gd")
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
	if commands.size() > 512: return "Unbounded active command count: %d" % commands.size()
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
	check(is_finite(duration) and duration > 0,"Default finite whirlwind cycle has a positive lifetime")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales spin-up, sustain and complete tail")

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

func test_motion_and_parameters() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var baseline: Array = sample_cycle(effect)
	check(baseline == sample_cycle(effect),"Seed and exact times reconstruct the complete wind cycle")
	seed(92731)
	var expected_rng := randi()
	seed(92731)
	sample_cycle(effect)
	check(randi() == expected_rng,"Rendering does not consume shared gameplay RNG")
	effect.config.seed_value += 1
	check(baseline != sample_cycle(effect),"Seed changes intrinsic ribbon arrangement and release")
	effect.configure(Config.new())
	var first: Array = effect.build_commands(0.65,INF)
	var second: Array = effect.build_commands(0.87,INF)
	check(not first.is_empty() and not second.is_empty(),"Sustained vortex is visible in both sampled phases")
	check(affine_residual(all_points(first),all_points(second)) > 0.0001,"Sustained motion is not a rigid or affine-transformed static wind logo")
	var observed_layers := {}
	for command in first: observed_layers[command.layer] = true
	var changing_layers := 0
	for layer in observed_layers:
		if affine_residual(layer_points(first,layer),layer_points(second,layer)) > 0.0001: changing_layers += 1
	check(changing_layers >= 2,"At least two independent wind layers evolve internally")
	var spinup: float = effect.config.spinup_seconds*effect.config.duration_scale
	check(total_area(effect.build_commands(spinup*0.15,INF)) < total_area(effect.build_commands(spinup,INF)),"Spin-up gathers from a smaller visible envelope into full ribbons")
	for phase in [0.08,0.30,0.55,0.75,0.90]:
		effect.configure(Config.new())
		var time: float = effect.config.duration()*phase
		var original: Array = effect.build_commands(time,-1)
		effect.config.size = 2
		check(transformed_matches(effect.build_commands(time,-1),original,2,0),"Size transforms every visible layer at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.direction_degrees = 37
		check(transformed_matches(effect.build_commands(time,-1),original,1,deg_to_rad(37)),"Angle rotates all ribbons and detached fragments at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.duration_scale = 2
		check(original == effect.build_commands(time*2,-1),"Time multiplier preserves normalized geometry at phase %.2f" % phase)
	for spec in range_specs(Config.new()):
		if spec[0] in ["size","direction_degrees","duration_scale"]: continue
		var config := Config.new()
		config.set(spec[0],spec[1])
		effect.configure(config)
		var minimum: Array = sample_cycle(effect)
		config.set(spec[0],spec[2])
		effect.configure(config)
		check(minimum != sample_cycle(effect),"Advertised knob observably changes geometry or timing: " + spec[0])
	var toggles := bool_names(Config.new())
	for toggle in toggles:
		var config := Config.new()
		for name in toggles: config.set(name,name == toggle)
		effect.configure(config)
		var present := false
		for commands in sample_cycle(effect,61): present = present or not commands.is_empty()
		check(present,"Composition layer works independently: " + toggle)
	for toggle in toggles: effect.config.set(toggle,false)
	var any_geometry := false
	for commands in sample_cycle(effect): any_geometry = any_geometry or not commands.is_empty()
	check(not any_geometry,"All wind layers can be disabled")
	var colored := Config.new()
	var custom := Color(0.17,0.46,0.63,1)
	for name in color_names(colored): colored.set(name,custom)
	effect.configure(colored)
	var matches := true
	for commands in sample_cycle(effect):
		for command in commands: matches = matches and command.color == custom
	check(matches,"Exposed palette owns every flat cel color")
	effect.configure(Config.new())
	for time in [10.0,3600.0,86400.0]:
		var commands: Array = effect.build_commands(time,INF)
		check(not commands.is_empty() and geometry_problem(commands).is_empty(),"Long-held wind remains finite and bounded at %.0f seconds" % time)
		check(commands == effect.build_commands(time,INF),"Late held flow is reproducible at %.0f seconds" % time)
	# Fractional secondary frequencies must wrap their own phase. Multiplying a
	# primary wrapped angle by 1.1/1.15 creates a visible jump every primary turn.
	for turn in [1.0,2.0,3.0]:
		var wrap_time: float = turn/effect.config.spin_speed
		for layer in ["ground","sliver"]:
			var before := layer_points(effect.build_commands(wrap_time-0.00001,INF),layer)
			var after := layer_points(effect.build_commands(wrap_time+0.00001,INF),layer)
			var displacement := 0.0
			for point in before: displacement = maxf(displacement,nearest_vertex_distance(point,after))
			for point in after: displacement = maxf(displacement,nearest_vertex_distance(point,before))
			check(not before.is_empty() and not after.is_empty() and displacement < 0.1,"Secondary %s flow remains continuous across primary phase wrap %.0f" % [layer,turn])
	effect.free()

func source_palette(commands: Array) -> Dictionary:
	var result := {}
	for command in commands:
		var id: int = command.get("ribbon_id",-999)
		if not result.has(id): result[id] = []
		if command.color not in result[id]: result[id].append(command.color)
	return result

func nearest_vertex_distance(point: Vector2, points: PackedVector2Array) -> float:
	var distance := INF
	for vertex in points: distance = minf(distance,point.distance_to(vertex))
	return distance

func inside_or_on(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		if point.distance_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) <= 0.005: return true
	return false

func highlight_problem(commands: Array) -> String:
	var support := {}
	for command in commands:
		if command.layer == "ribbon_front":
			var key := "%s/%s" % [command.get("ribbon_id",-999),command.get("piece",-999)]
			if not support.has(key): support[key] = []
			support[key].append(command.points)
	for command in commands:
		if command.layer != "highlight": continue
		var key := "%s/%s" % [command.get("ribbon_id",-999),command.get("piece",-999)]
		if not support.has(key): return "Highlight has no matching source ribbon piece: " + key
		# Vertices plus edge midpoints catch detached or crossing color strips,
		# including the per-layer-centroid release regression found in review.
		var points: PackedVector2Array = command.points
		for i in range(points.size()):
			for point in [points[i],(points[i]+points[(i+1)%points.size()])*0.5]:
				var inside := false
				for polygon in support[key]: inside = inside or inside_or_on(point,polygon)
				if not inside: return "Highlight escapes source ribbon piece: " + key
	return ""

func piece_pivot_problem(commands: Array) -> String:
	var pivots := {}
	for command in commands:
		if command.layer not in ["ribbon_front","ribbon_back","highlight"]: continue
		var key := "%s/%s" % [command.get("ribbon_id",-999),command.get("piece",-999)]
		var pivot: Vector2 = command.get("pivot",Vector2(INF,INF))
		if not pivot.is_finite(): return "Missing semantic ribbon-half release pivot"
		if pivots.has(key) and not pivot.is_equal_approx(pivots[key]): return "Geometry-only subdivision acquired its own release pivot: " + key
		pivots[key] = pivot
	return ""

func test_layer_attachment() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	for release_time in [0.04,0.20,0.70,2.5]:
		effect.seek(release_time,-1,true)
		var problem := highlight_problem(effect.build_commands())
		check(problem.is_empty(),"Cel highlight remains inside its advecting source at %.2f: %s" % [release_time,problem])
		problem = piece_pivot_problem(effect.build_commands())
		check(problem.is_empty(),"Constructed cells share semantic ribbon-half pivots at %.2f: %s" % [release_time,problem])
		effect.release()
		for fraction in [0.02,0.20,0.50,0.80]:
			var commands: Array = effect.build_commands(release_time+fraction*effect.config.release_seconds)
			problem = highlight_problem(commands)
			check(problem.is_empty(),"Source and highlight share release deformation at %.2f + %.2f tail: %s" % [release_time,fraction,problem])
			problem = piece_pivot_problem(commands)
			check(problem.is_empty(),"Constructed cells keep a shared semantic release pivot at %.2f + %.2f tail: %s" % [release_time,fraction,problem])
	effect.configure(Config.new())
	for time in [0.12,0.65,1.10,1.70]:
		var complete: Array = effect.build_commands(time,-1)
		for property in ["show_ribbons","show_highlights","show_slivers","show_ground"]:
			var config := Config.new()
			config.set(property,false)
			effect.configure(config)
			var subset: Array = effect.build_commands(time,-1)
			var independent := true
			for command in subset:
				if command not in complete: independent = false
			check(independent,"Disabling %s cannot alter unrelated source geometry at %.2f" % [property,time])
		effect.configure(Config.new())
	effect.free()

func test_source_bound_release() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	for release_time in [0.0,0.04,0.20,0.70,2.5]:
		effect.seek(release_time,-1,true)
		var source: Array = effect.build_commands()
		var points := all_points(source)
		var palette := source_palette(source)
		effect.release()
		check(source == effect.build_commands(),"Release starts from exactly the visible source, including partial spin-up at %.2f" % release_time)
		var tiny_step: Array = effect.build_commands(release_time+0.00001)
		var max_distance := 0.0
		for point in all_points(tiny_step): max_distance = maxf(max_distance,nearest_vertex_distance(point,points))
		check(max_distance < 0.1,"Release boundary moves continuously without a new full-size vortex at %.2f" % release_time)
		var preserves_source := true
		var valid_geometry := true
		for fraction in [0.02,0.20,0.50,0.80,1.0]:
			var commands: Array = effect.build_commands(release_time+fraction*effect.config.release_seconds)
			valid_geometry = valid_geometry and geometry_problem(commands).is_empty()
			for command in commands:
				var id: int = command.get("ribbon_id",-999)
				preserves_source = preserves_source and id != -999 and palette.has(id) and command.color in palette.get(id,[])
		check(preserves_source,"Released curls retain only source ribbon identities and colors at %.2f" % release_time)
		check(valid_geometry,"Entire early/held release tail remains finite and triangulatable at %.2f" % release_time)
		if release_time == 0:
			check(effect.build_commands(0.10).is_empty(),"Release before any wind exists cannot spawn replacement ribbons")
		effect.seek(release_time,-1,true)
	var stationary := Config.new()
	stationary.spin_speed = 0
	stationary.rise_speed = 0
	effect.configure(stationary)
	check(effect.build_commands(0.65,INF) == effect.build_commands(0.95,INF),"Zero orbital and rising speeds freeze sustained intrinsic geometry")
	effect.configure(Config.new())
	effect.seek(0.7,-1,true)
	effect.release()
	var early: Array = effect.build_commands(0.75)
	var late: Array = effect.build_commands(1.05)
	check(affine_residual(all_points(early),all_points(late)) > 0.0001,"Release changes individual ribbons rather than moving the entire vortex rigidly")
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
	check(effect.playing and is_equal_approx(effect.age,0.1),"Spin-up advances after play")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative/nonfinite delta cannot rewind or corrupt spin-up")
	effect._process(effect.get_end_time()+1)
	effect._process(1)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Finite cycle clears and emits completion once")
	var completed_release: float = effect.release_at
	effect.release()
	check(effect.release_at == completed_release and not effect.playing,"Release after completion does not restart the tail")
	effect.play(true)
	check(effect.get_end_time() == INF and effect.release_at < 0,"Held play resets release and has no automatic terminal age")
	effect._process(10)
	check(effect.playing and not effect.build_commands().is_empty() and finish_count == 1,"Held whirlwind stays active beyond the finite default duration")
	effect.release()
	var first_release: float = effect.release_at
	var end_time: float = effect.get_end_time()
	check(is_equal_approx(first_release,10) and is_finite(end_time) and end_time > first_release,"Release records actual absolute time and establishes a finite tail")
	effect._process(0.1)
	effect.release()
	check(effect.release_at == first_release and effect.get_end_time() == end_time,"Repeated release cannot refresh or extend the tail")
	effect._process(end_time+1)
	check(not effect.playing and finish_count == 2 and effect.build_commands().is_empty(),"Released held whirlwind finishes exactly once")
	for early in [0.04,0.65]:
		effect.seek(early,-1,true)
		var before: Array = effect.build_commands().duplicate(true)
		effect.release()
		check(not effect.playing and effect.release_at == early,"Release preserves pause while recording spin-up/sustain time %.2f" % early)
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
	check(effect.build_commands(1.9,1.8) == effect.build_commands(1.9,-1),"Finite late override cannot render a restarted vortex")
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
			if commands != effect.build_commands(age,-1): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite opaque bounded triangulation for 121 poses in variant %d: %s" % [variant,problem])
		check(effect.build_commands(effect.config.duration(),-1).is_empty(),"Every sanitized finite configuration clears at its duration")
		check(geometry_problem(effect.build_commands(3600,INF)).is_empty(),"Every sanitized variant has bounded long-held flow")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		effect.configure(config)
		var automatic: float = (config.spinup_seconds+config.sustain_seconds)*multiplier
		for requested in [-1.0,0.0,0.03*multiplier,0.13*multiplier,1.8*multiplier]:
			var actual: float = automatic if requested < 0 else requested
			var terminal: float = actual+(config.release_seconds+0.04)*multiplier
			effect.seek(0.1,requested,requested >= 0)
			check(is_equal_approx(effect.get_end_time(),terminal),"End time uses actual release plus scaled ribbon tail")
			var boundaries := [0.0,config.spinup_seconds*multiplier,actual,actual+config.release_seconds*multiplier,terminal]
			var problem := ""
			for boundary in boundaries:
				for epsilon in [0.0,0.001,0.00001,0.0000001,0.000000001,0.00000000001]:
					for side in [-1.0,1.0]:
						var age: float = boundary+side*epsilon
						var current := geometry_problem(effect.build_commands(age,requested))
						if not current.is_empty(): problem = "%s at %.17f" % [current,age]
			check(problem.is_empty(),"Dense spin-up/release boundary validation at scale %.2f and release %.2f: %s" % [multiplier,requested,problem])
			check(effect.build_commands(terminal,requested).is_empty(),"Every early or held release ends fully empty")
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
	check(not lab.held_sustain and lab.released_at < 0 and not lab.floor_host,"Whirlwind lab begins as finite generic emitter, not a gameplay hazard")
	key(lab,KEY_H)
	key(lab,KEY_H,true)
	check(lab.held_sustain and lab.effect.get_end_time() == INF,"Hold toggle is reflected in component state and ignores echoes")
	lab.step(5)
	check(lab.elapsed > lab.effect.config.duration() and lab.effect.get_end_time() == INF,"Held preview survives beyond the finite cycle")
	key(lab,KEY_SPACE)
	var held_age: float = lab.elapsed
	lab._process(0.1)
	check(not lab.playing and lab.elapsed == held_age,"Pause holds a sustained vortex")
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
	check(lab.released_at < 0 and lab.effect.get_end_time() == normal_end,"Late finite release never resurrects or extends extinguishing whirlwind")
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
	var popup: PopupPanel = lab.color_controls[color_names(lab.effect.config)[0]].get_popup()
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
	var light_pass_clear := false
	for frame in range(Lab.WHIRLWIND_CAPTURE_FRAMES):
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
		if segment == 1 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(): light_pass_clear = true
	check(Lab.WHIRLWIND_CAPTURE_FRAMES == 1080 and seen.size() == 3,"Capture is the declared 18-second normal/light/held-release sequence")
	check(problem.is_empty(),"Every exact 1080-frame viewport capture pose triangulates: " + problem)
	check(light_pass_clear,"Light-background slow pass reaches full finite release clearance")
	effect.seek(elapsed,released_at,true)
	check(released_at == 1.5 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(),"Final capture pass includes held release and complete last-ribbon clearance")
	effect.free()

func run() -> void:
	test_config()
	test_motion_and_parameters()
	test_source_bound_release()
	test_layer_attachment()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_WHIRLWIND: %d checks, %d failures" % [checks,failures])
	quit(failures)
