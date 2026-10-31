extends SceneTree
## Geometry/lifecycle contracts; an actual viewport motion review is a separate gate.
const Config = preload("res://scripts/vfx/cel/heal_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/heal.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/heal_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/heal_lab.gd")
var checks := 0
var failures := 0
var finish_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

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

func layer_shapes(commands: Array, layer: String) -> Array:
	var shapes: Array = []
	for command in commands:
		if command.layer == layer: shapes.append(command.points)
	return shapes

func layer_points(commands: Array, layer: String) -> PackedVector2Array:
	var points := PackedVector2Array()
	for shape in layer_shapes(commands,layer): points.append_array(shape)
	return points

func bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty(): return Rect2()
	var result := Rect2(points[0],Vector2.ZERO)
	for point in points: result = result.expand(point)
	return result

func polygon_area(points: PackedVector2Array) -> float:
	var twice_area := 0.0
	for i in range(points.size()): twice_area += points[i].cross(points[(i+1)%points.size()])
	return absf(twice_area)*0.5

func layer_area(commands: Array, layer: String) -> float:
	var area := 0.0
	for shape in layer_shapes(commands,layer): area += polygon_area(shape)
	return area

func geometry_problem(commands: Array) -> String:
	if commands.size() > 4096: return "Unbounded active command count: %d" % commands.size()
	for index in range(commands.size()):
		var command: Dictionary = commands[index]
		if not command.has("points") or not command.has("color") or not command.has("layer"): return "Missing command fields"
		var points: PackedVector2Array = command.points
		if points.size() < 3 or points.size() > 256: return "Invalid vertex count"
		if Geometry2D.triangulate_polygon(points).is_empty(): return "Nontriangulatable polygon %d (%s)" % [index,command.layer]
		if polygon_area(points) < 0.000001: return "Degenerate polygon %d (%s)" % [index,command.layer]
		for point in points:
			if not point.is_finite() or point.length() > 12000: return "Nonfinite or unbounded vertex"
		var color: Color = command.color
		if color.a != 1.0 or not is_finite(color.r) or not is_finite(color.g) or not is_finite(color.b): return "Not a finite opaque cel color"
		if color.r < 0 or color.r > 1 or color.g < 0 or color.g > 1 or color.b < 0 or color.b > 1: return "Color outside normalized palette"
	return ""

func affine_residual(a: PackedVector2Array, b: PackedVector2Array) -> float:
	# Remove a general affine transform, not just translation/rotation/scale.
	# A static effect logo that is merely stretched or sheared fails here.
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

func sample_cycle(effect: Node2D, samples: int = 41) -> Array:
	var result: Array = []
	for i in range(samples): result.append(effect.build_commands(effect.config.duration()*i/float(samples)))
	return result

func configured(mode: int) -> Resource:
	var config := Config.new()
	config.mode = mode
	return config

func source_groups(commands: Array, layer: String) -> Dictionary:
	var result := {}
	for command in commands:
		if command.layer != layer: continue
		var source: Variant = command.get("source_id","")
		if not result.has(source): result[source] = PackedVector2Array()
		var points: PackedVector2Array = result[source]
		points.append_array(command.points)
		result[source] = points
	return result

func has_intrinsic_motion(effect: Node2D, layer: String) -> bool:
	var prior := {}
	for frame in range(1,81):
		var groups := source_groups(effect.build_commands(effect.config.duration()*frame/81.0),layer)
		for source in groups:
			if prior.has(source) and prior[source].size() == groups[source].size():
				var residual := affine_residual(prior[source],groups[source])
				if is_finite(residual) and residual > 0.002: return true
		prior = groups
	return false

func inside_or_near(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		if Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()]).distance_to(point) < 0.06: return true
	return false

func attachment_problem(commands: Array) -> String:
	# Index by semantic source, then bounding box, instead of checking every
	# highlight vertex against every ribbon cell in an unrelated piece.
	var parents := {}
	for command in commands:
		if not command.has("source_id"): return "Command has no semantic source identity"
		if command.layer not in ["ribbon_shadow","ribbon_body","chevron_shadow","chevron_body"]: continue
		var source: Variant = command.source_id
		if not parents.has(source): parents[source] = []
		parents[source].append({"points":command.points,"bounds":bounds(command.points).grow(0.07)})
	for command in commands:
		if command.layer not in ["ribbon_highlight","chevron_highlight"]: continue
		if not parents.has(command.source_id): return "Highlight outlives its source body: " + str(command.source_id)
		var probes: PackedVector2Array = command.points.duplicate()
		for i in range(command.points.size()): probes.append((command.points[i]+command.points[(i+1)%command.points.size()])*0.5)
		for point in probes:
			var contained := false
			for parent in parents[command.source_id]:
				if parent.bounds.has_point(point) and inside_or_near(point,parent.points): contained = true; break
			if not contained: return "Highlight detaches from source %s at %s" % [command.source_id,point]
	return ""

func test_intrinsic_motion_and_attachment() -> void:
	var effect := EffectScene.instantiate()
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		effect.configure(configured(mode))
		check(has_intrinsic_motion(effect,"ribbon_body"),"Mode %d ribbons change their own contour rather than translating/scaling a static logo" % mode)
		check(has_intrinsic_motion(effect,"arcs"),"Mode %d broken foot arcs evolve intrinsically" % mode)
		var problem := ""
		var visible_layers := {}
		for frame in range(1,121):
			var commands: Array = effect.build_commands(effect.config.duration()*frame/121.0)
			var current := attachment_problem(commands)
			if not current.is_empty(): problem = "%s at mode %d phase %.4f" % [current,mode,frame/121.0]; break
			for command in commands: visible_layers[command.layer] = true
		check(problem.is_empty(),"All ribbon/chevron highlights stay within their own semantic source at dense phases: " + problem)
		for layer in ["arcs","ribbon_shadow","ribbon_body","ribbon_highlight","streaks","motes"]:
			check(visible_layers.has(layer),"Full mode %d contains its composable %s layer" % [mode,layer])
		effect.configure(configured(Config.Mode.HEAL))
	check(has_intrinsic_motion(effect,"glyphs"),"Heal plus arms unfold/retract relative to their stems, not a globally scaled plus image")
	effect.configure(configured(Config.Mode.LEVEL_UP))
	check(has_intrinsic_motion(effect,"chevron_body"),"Level-up chevron wings reshape independently, not just move upward")
	check(has_intrinsic_motion(effect,"star"),"Level-up crest star changes its own points during the flare")
	effect.free()

func glyph_arm_ratios(commands: Array, source: int) -> Vector2:
	for command in commands:
		if command.layer != "glyphs" or command.source_id != source: continue
		var p: PackedVector2Array = command.points
		if p.size() != 12: return Vector2(-1,-1)
		var center_x: float = (p[0].x+p[1].x)*0.5
		var half_stem: float = (p[1].x-p[0].x)*0.5
		return Vector2((center_x-p[9].x)/half_stem,(p[3].x-center_x)/half_stem)
	return Vector2(-1,-1)

func test_motif_phases() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(configured(Config.Mode.HEAL))
	var early := glyph_arm_ratios(effect.build_commands(0.34),200)
	var open := glyph_arm_ratios(effect.build_commands(0.9),200)
	var late := glyph_arm_ratios(effect.build_commands(1.82),200)
	check(early.x > 0 and open.x > early.x+1 and open.y > early.y+1,"Plus glyph unfolds both side arms out of a slender vertical birth")
	check(late.x > 0 and late.x < open.x-1 and late.y < open.y-1,"Plus side arms retract into the stem before the complete glyph clears")
	var staggered := glyph_arm_ratios(effect.build_commands(0.4),200)
	check(staggered.x > staggered.y+0.1,"Left/right plus arms have offset timing rather than one global glyph scale")
	var glyphs := source_groups(effect.build_commands(0.9),"glyphs")
	check(glyphs.size() == 5,"Default heal carries the concept's five independently identified plus glyphs")
	effect.config.glyph_count = 7
	check(source_groups(effect.build_commands(1.1),"glyphs").size() == 7,"Maximum glyph count produces seven independent glyphs without replacing ribbons")
	effect.configure(configured(Config.Mode.LEVEL_UP))
	var first := source_groups(effect.build_commands(0.38),"chevron_shadow")
	var second := source_groups(effect.build_commands(0.48),"chevron_shadow")
	check(first.size() == 1 and first.has(400) and second.size() == 2 and second.has(401),"The two level-up chevrons open in separate phases")
	check(layer_shapes(effect.build_commands(0.48),"star").is_empty() and not layer_shapes(effect.build_commands(0.62),"star").is_empty(),"Crest star follows the two opening chevrons instead of appearing as a static combined icon")
	var stars := layer_shapes(effect.build_commands(0.8),"star")
	check(stars.size() == 1 and stars[0].size() == 8,"Crest is a four-ray, eight-vertex star")
	check(source_groups(effect.build_commands(1.8),"chevron_shadow").size() == 2 and not layer_shapes(effect.build_commands(1.8),"star").is_empty(),"Chevrons and crest remain source-related through their independent release phases")
	check(effect.build_commands(2.14).is_empty(),"Both motifs fully clear instead of leaving a final icon")
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		for seed in [-9223372036854775807,9223372036854775807,0,-1]:
			var config := configured(mode)
			config.seed_value = seed
			effect.configure(config)
			var commands: Array = effect.build_commands(0.9)
			check(geometry_problem(commands).is_empty() and commands == effect.build_commands(0.9),"Full signed-range seed is bounded and deterministic in mode %d" % mode)
	effect.free()

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
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		var config := configured(mode)
		config.sanitize()
		check(config.mode == mode,"Both declared modes survive sanitization")
	for invalid in [-1,2,999999]:
		var config := Config.new()
		config.mode = invalid
		config.sanitize()
		check(config.mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP],"Unsupported mode is sanitized to an available family")
	var duration: float = defaults.duration()
	check(is_equal_approx(duration,2.14),"Default finite timeline is 2.14 seconds including complete clearance")
	check(duration > defaults.gather_seconds+defaults.bloom_seconds+defaults.sustain_seconds+defaults.release_seconds,"Lifetime includes a positive post-release clearing margin")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Time multiplier scales all phases and clearance")

func test_parameters() -> void:
	var effect := EffectScene.instantiate()
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		effect.configure(configured(mode))
		for time in [0.12,0.42,0.78,1.2,1.7,2.03]:
			var original: Array = effect.build_commands(time)
			check(original == effect.build_commands(time),"Sampling is deterministic at mode %d age %.2f" % [mode,time])
			var config := configured(mode)
			config.size = 2.25
			config.direction_degrees = 37
			effect.configure(config)
			check(transformed_matches(effect.build_commands(time),original,2.25,deg_to_rad(37)),"Size/direction transform every layer exactly at mode %d age %.2f" % [mode,time])
			config = configured(mode)
			config.duration_scale = 2
			effect.configure(config)
			check(effect.build_commands(time*2) == original,"Time scale preserves normalized geometry at mode %d age %.2f" % [mode,time])
			effect.configure(configured(mode))
		var baseline: Array = sample_cycle(effect)
		var snapshot: Array = effect.build_commands(0.9)
		var original_snapshot: Array = snapshot.duplicate(true)
		snapshot[0].points[0] += Vector2(999,999)
		snapshot[0].color = Color.RED
		check(effect.build_commands(0.9) == original_snapshot,"Returned command snapshots do not alias internal geometry in mode %d" % mode)
		seed(91821)
		var expected_random := randf()
		seed(91821)
		effect.build_commands(0.9)
		check(randf() == expected_random,"Effect sampling leaves the host's global random stream untouched in mode %d" % mode)
		var seeded := configured(mode)
		seeded.seed_value = -58321
		effect.configure(seeded)
		check(sample_cycle(effect) != baseline,"Seed visibly changes arrangement in mode %d" % mode)
		effect.configure(seeded)
		check(sample_cycle(effect) == sample_cycle(effect),"Seeded output replays deterministically in mode %d" % mode)
	for spec in range_specs(Config.new()):
		if spec[0] in ["size","direction_degrees","duration_scale"]: continue
		var changed := false
		for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
			var config := configured(mode)
			config.set(spec[0],spec[1])
			effect.configure(config)
			var minimum: Array = sample_cycle(effect)
			config.set(spec[0],spec[2])
			effect.configure(config)
			changed = changed or minimum != sample_cycle(effect)
		check(changed,"Advertised parameter produces observable geometry/timing change: " + spec[0])
	var heal := configured(Config.Mode.HEAL)
	heal.glyph_count = 0
	effect.configure(heal)
	var any_glyph := false
	var remaining := false
	for commands in sample_cycle(effect):
		any_glyph = any_glyph or not layer_shapes(commands,"glyphs").is_empty()
		remaining = remaining or not commands.is_empty()
	check(not any_glyph and remaining,"Zero heal glyph count leaves ribbons, arcs and flow intact")
	effect.free()

func test_layers_and_palettes() -> void:
	var effect := EffectScene.instantiate()
	var toggles := bool_names(Config.new())
	var exclusive := {"show_glyphs":Config.Mode.HEAL,"show_chevrons":Config.Mode.LEVEL_UP,"show_star":Config.Mode.LEVEL_UP}
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		for toggle in toggles:
			var config := configured(mode)
			for name in toggles: config.set(name,name == toggle)
			effect.configure(config)
			var present := false
			for commands in sample_cycle(effect): present = present or not commands.is_empty()
			var expected: bool = not exclusive.has(toggle) or exclusive[toggle] == mode
			check(present == expected,"Independent layer %s has correct mode visibility in mode %d" % [toggle,mode])
		var affected := {"show_arcs":["arcs"],"show_ribbons":["ribbon_shadow","ribbon_body"],"show_highlights":["ribbon_highlight","chevron_highlight"],"show_glyphs":["glyphs"],"show_chevrons":["chevron_shadow","chevron_body","chevron_highlight"],"show_star":["star"],"show_streaks":["streaks"],"show_motes":["motes"]}
		effect.configure(configured(mode))
		var complete: Array = sample_cycle(effect)
		for toggle in toggles:
			var without := configured(mode)
			without.set(toggle,false)
			effect.configure(without)
			var actual: Array = sample_cycle(effect)
			var isolated := true
			for frame in range(complete.size()):
				var expected: Array = []
				for command in complete[frame]:
					if not command.layer in affected[toggle]: expected.append(command)
				isolated = isolated and actual[frame] == expected
			check(isolated,"Disabling %s preserves all unrelated source geometry in mode %d" % [toggle,mode])
		var disabled := configured(mode)
		for toggle in toggles: disabled.set(toggle,false)
		effect.configure(disabled)
		var any_geometry := false
		for commands in sample_cycle(effect): any_geometry = any_geometry or not commands.is_empty()
		check(not any_geometry,"All layers can be disabled in mode %d" % mode)
		var config := configured(mode)
		var custom := Color(0.17,0.46,0.63,1)
		for name in color_names(config): config.set(name,custom)
		effect.configure(config)
		var matches := true
		for commands in sample_cycle(effect):
			for command in commands: matches = matches and command.color == custom
		check(matches,"Every emitted color derives from the opaque configurable palette in mode %d" % mode)
		var active_prefix: String = "heal_" if mode == Config.Mode.HEAL else "level_"
		effect.configure(configured(mode))
		var baseline: Array = sample_cycle(effect)
		for name in color_names(Config.new()):
			config = configured(mode)
			config.set(name,custom)
			effect.configure(config)
			check((sample_cycle(effect) != baseline) == name.begins_with(active_prefix),"Palette %s applies only to its intended mode %d" % [name,mode])
		effect.configure(configured(mode))
		var foreign := false
		for commands in sample_cycle(effect):
			for command in commands:
				if mode == Config.Mode.HEAL: foreign = foreign or command.layer.begins_with("chevron") or command.layer == "star"
				else: foreign = foreign or command.layer == "glyphs"
		check(not foreign,"Modes have genuinely distinct motifs, not a recolored shared icon")
	effect.free()

func test_lifecycle() -> void:
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		var source := configured(mode)
		source.size = 99
		var effect := EffectScene.instantiate()
		effect.configure(source)
		root.add_child(effect)
		effect.set_process(false)
		check(source.size == 99 and effect.config.size == 3 and effect.config.mode == mode,"Configure before ready deep-copies and sanitizes without replacing caller mode")
		effect.config.heal_glyph_color = Color.RED
		check(source.heal_glyph_color == Config.new().heal_glyph_color,"Caller Resource palette survives deep-copy edits")
		effect.configure(null)
		check(values(effect.config) == values(Config.new()),"Null configuration restores exact defaults")
		effect.configure(configured(mode))
		check(effect.get_child_count() == 0 and effect.build_commands().is_empty(),"Reusable effect starts dormant without actor/gameplay dependencies")
		for age in [-1.0,-0.001,effect.config.duration(),999.0,INF,NAN]:
			check(effect.build_commands(age).is_empty(),"Invalid or expired sample safely clears in mode %d age %s" % [mode,age])
		var before := finish_count
		effect.finished.connect(func(): finish_count += 1)
		effect.play()
		check(effect.playing and effect.age == 0,"Play starts an independent finite timeline")
		effect._process(0.1)
		for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
		check(is_equal_approx(effect.age,0.1),"Negative/nonfinite deltas cannot corrupt time")
		effect._process(100)
		effect._process(100)
		check(not effect.playing and finish_count == before+1 and effect.build_commands().is_empty(),"Finite completion emits finished exactly once and clears")
		effect.play()
		effect.seek(0.5)
		effect._process(10)
		check(not effect.playing and is_equal_approx(effect.age,0.5) and finish_count == before+1,"Seek pauses and never emits a completion event")
		for invalid_age in [NAN,INF,-INF,-1.0]:
			effect.seek(invalid_age)
			check(effect.build_commands().is_empty(),"Invalid seek remains dormant: %s" % invalid_age)
		for repeat in range(20): effect.play(); effect._process(effect.config.duration()+1)
		check(finish_count == before+21 and effect.get_child_count() == 0,"Repeated replay completes without accumulating nodes")
		effect.play()
		effect._process(0.4)
		effect.stop()
		effect.stop()
		effect._process(10)
		check(not effect.playing and effect.build_commands().is_empty() and finish_count == before+21,"Stop repeatedly clears without spurious finished signals")
		effect.configure(configured(1-mode))
		effect.play()
		effect._process(0.8)
		check(effect.config.mode == 1-mode and not effect.build_commands().is_empty(),"Reconfigured opposite mode replays on the same independent node")
		effect.free()
	var settings := configured(Config.Mode.LEVEL_UP)
	settings.size = 1.5
	var from_settings := EffectScene.instantiate()
	from_settings.settings = settings
	root.add_child(from_settings)
	from_settings.set_process(false)
	check(from_settings.config != settings and values(from_settings.config) == values(settings),"Inspector settings are deep copied before first ready")
	from_settings.free()

func test_geometry() -> void:
	var effect := EffectScene.instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 72943
	for mode in [Config.Mode.HEAL,Config.Mode.LEVEL_UP]:
		for variant in range(18):
			var config := configured(mode)
			if variant > 0:
				for spec in range_specs(config):
					if spec[0] == "mode": continue
					var candidate: float = spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2]))
					config.set(spec[0],int(round(candidate)) if spec[3] == TYPE_INT else candidate)
				config.seed_value = variant*4127-18000
			effect.configure(config)
			var problem := ""
			for frame in range(161):
				var age: float = effect.config.duration()*frame/160.0
				var commands: Array = effect.build_commands(age)
				problem = geometry_problem(commands)
				if not problem.is_empty(): problem += " at %.9f" % age; break
				if commands != effect.build_commands(age): problem = "Nondeterministic sample"; break
				if frame%20 == 0:
					problem = attachment_problem(commands)
					if not problem.is_empty(): problem += " at %.9f" % age; break
			check(problem.is_empty(),"Finite opaque bounded triangulation for 161 poses in mode %d variant %d: %s" % [mode,variant,problem])
			check(effect.build_commands(effect.config.duration()).is_empty(),"Every sanitized finite configuration clears at its terminal duration")
		for multiplier in [0.4,1.0,2.0]:
			var config := configured(mode)
			config.duration_scale = multiplier
			effect.configure(config)
			var boundaries := [0.0,config.gather_seconds,config.gather_seconds+config.bloom_seconds,config.gather_seconds+config.bloom_seconds+config.sustain_seconds,config.duration()/multiplier-0.04,config.duration()/multiplier]
			var release_at: float = config.gather_seconds+config.bloom_seconds+config.sustain_seconds
			for i in range(3):
				var ribbon_birth: float = config.gather_seconds*0.30+i*config.bloom_seconds*0.10
				boundaries.append(ribbon_birth)
				boundaries.append(ribbon_birth+config.bloom_seconds*1.15)
				boundaries.append(release_at-config.release_seconds*0.12+i*0.025)
			if mode == Config.Mode.HEAL:
				for i in range(config.glyph_count):
					var birth: float = config.gather_seconds+config.bloom_seconds*(0.10+0.09*i)
					var death: float = release_at+config.release_seconds*(0.02+0.025*i)
					for offset in [0.0,0.025,0.035,0.065]: boundaries.append(birth+offset)
					for offset in [0.0,0.035,0.045]: boundaries.append(death+offset)
					boundaries.append(death+config.release_seconds*0.65)
			else:
				for i in range(2):
					boundaries.append(config.gather_seconds+config.bloom_seconds*(0.18+0.13*i))
					boundaries.append(release_at+i*0.045)
					boundaries.append(release_at+i*0.045+config.release_seconds*0.66)
				for i in range(4):
					boundaries.append(config.gather_seconds+config.bloom_seconds*0.50+i*0.023)
					boundaries.append(release_at+config.release_seconds*0.10+i*0.016)
			var problem := ""
			for boundary in boundaries:
				for epsilon in [0.0,0.001,0.00001,0.0000001,0.000000001,0.00000000001]:
					for side in [-1.0,1.0]:
						var age: float = (boundary+side*epsilon)*multiplier
						var current := geometry_problem(effect.build_commands(age))
						if not current.is_empty(): problem = "%s at %.17f" % [current,age]
			check(problem.is_empty(),"Dense phase-boundary geometry at mode %d time multiplier %.2f: %s" % [mode,multiplier,problem])
	effect.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	var lab := LabScene.instantiate()
	var previous_segment := -1
	var seen := {}
	var clear := {}
	var problem := ""
	var clock_correct := true
	var repeats := 0
	var previous_age := -1.0
	for frame in range(Lab.HEAL_CAPTURE_FRAMES):
		var segment: int = frame/360
		var pose: Dictionary = lab.capture_pose(frame)
		var expected_mode: int = Config.Mode.HEAL if segment < 2 else Config.Mode.LEVEL_UP
		var local_frame: int = frame%360
		var expected_age: float = float(local_frame%180)/60.0-0.35 if segment%2 == 0 else float(local_frame)/120.0-0.35
		clock_correct = clock_correct and pose.mode == expected_mode and is_equal_approx(pose.age,expected_age) and pose.speed == (1.0 if segment%2 == 0 else 0.5) and pose.light == (segment%2 == 1) and pose.isolated == (segment == 3)
		if segment != previous_segment:
			previous_segment = segment
			effect.configure(configured(expected_mode))
			seen[segment] = true
		elif pose.age < previous_age: repeats += 1
		previous_age = pose.age
		var commands: Array = effect.build_commands(pose.age)
		var current := geometry_problem(commands)
		if not current.is_empty(): problem = "%s at frame %d" % [current,frame]
		if pose.age > effect.config.duration() and commands.is_empty(): clear[segment] = true
	check(Lab.HEAL_CAPTURE_FRAMES == 1440 and seen.size() == 4,"Capture declares 24 seconds / 1440 frames with both modes at normal and half speed")
	check(clock_correct and repeats == 2,"Actual capture-pose API uses exact normal repeats, half-speed clocks, light/dark and isolate transitions")
	check(problem.is_empty(),"Every exact native viewport-capture pose triangulates: " + problem)
	check(clear.size() == 4,"Each captured mode/speed segment includes complete terminal clearance")
	check(lab.capture_pose(-100) == lab.capture_pose(0) and lab.capture_pose(999999) == lab.capture_pose(1439),"Capture-pose lookup clamps outside the declared frame interval")
	lab.free()
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
	lab.toggle_parameters()
	await process_frame
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			var expected: float = lab.effect.config.get(name)
			check(is_equal_approx(control.value,expected) and is_equal_approx(float(control.get_line_edit().text),expected),"Visible numeric UI shows the exact default without step rounding: " + name)
	lab.toggle_parameters()
	check(lab.effect.config.mode == Config.Mode.HEAL and lab.mode_buttons.size() == 2,"Lab exposes two actual mode controls and defaults to heal")
	key(lab,KEY_2)
	check(lab.effect.config.mode == Config.Mode.LEVEL_UP and is_equal_approx(lab.elapsed,-0.35),"Key 2 switches to level-up and replays")
	lab.step(0.2)
	key(lab,KEY_1,true)
	check(lab.effect.config.mode == Config.Mode.LEVEL_UP and is_equal_approx(lab.elapsed,-0.15),"Echoed mode keys do not interrupt playback")
	key(lab,KEY_1)
	check(lab.effect.config.mode == Config.Mode.HEAL,"Key 1 returns to heal")
	for mode in [Config.Mode.LEVEL_UP,Config.Mode.HEAL]:
		lab.mode_buttons[mode].pressed.emit()
		check(lab.effect.config.mode == mode,"Actual mode-button signal selects %d" % mode)
	lab.step(0.5)
	var paused_age: float = lab.elapsed
	lab.toggle_play()
	lab._process(0.1)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age),"Pause freezes the preview timeline")
	key(lab,KEY_RIGHT)
	check(not lab.playing and is_equal_approx(lab.elapsed,paused_age+1.0/60.0),"Frame step advances one frame while remaining paused")
	key(lab,KEY_R)
	check(lab.playing and is_equal_approx(lab.elapsed,-0.35),"Replay recovers from interrupted playback")
	key(lab,KEY_S)
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter speed changes only the playback clock")
	key(lab,KEY_B)
	key(lab,KEY_B,true)
	key(lab,KEY_E)
	check(lab.light_background and lab.effect_only and not lab._has_host(),"Background/isolate controls work and echoed background input is ignored")
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			control.value = control.max_value
			check(is_equal_approx(float(lab.effect.config.get(name)),control.max_value) and is_equal_approx(lab.elapsed,-0.35) and lab.playing,"Numeric UI updates and replays: " + name)
		elif control is CheckBox:
			control.button_pressed = not control.button_pressed
			check(lab.effect.config.get(name) == control.button_pressed,"Boolean UI updates: " + name)
	for name in lab.color_controls:
		var color := Color(0.17,0.46,0.63,1)
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color and is_equal_approx(lab.elapsed,-0.35),"Palette signal updates and replays: " + name)
	check(values(lab.effect.settings) == source_before,"Live edits preserve the Inspector settings Resource")
	var before := values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	lab.set_color("unsupported",Color.RED)
	check(values(lab.effect.config) == before,"Unknown UI parameter names are ignored")
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and lab.playback_speed == 1 and not lab.light_background and not lab.effect_only,"Reset restores exact component and presentation defaults including heal mode")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(lab.settings_panel.visible and editor.has_focus(),"Visible numeric editor supports focus")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	lab._input(escape)
	check(not lab.settings_panel.visible and not editor.has_focus(),"Escape closes interrupted editing and releases focus")
	lab.toggle_parameters()
	var popup: PopupPanel = lab.color_controls[color_names(lab.effect.config)[0]].get_popup()
	popup.show()
	lab.toggle_parameters()
	check(not lab.settings_panel.visible and not popup.visible,"Panel close explicitly dismisses palette popup")
	var count: int = lab.get_child_count()
	for repeat in range(20):
		lab.set_mode(repeat%2)
		lab.step(0.4)
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == count and lab.playing and is_equal_approx(lab.elapsed,-0.35),"Repeated mode changes and interrupted replay do not accumulate nodes")
	lab.free()

func run() -> void:
	test_config()
	test_parameters()
	test_layers_and_palettes()
	test_intrinsic_motion_and_attachment()
	test_motif_phases()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_HEAL: %d checks, %d failures" % [checks,failures])
	quit(failures)
