extends SceneTree
## Geometry/lifecycle contracts; an actual viewport motion review is a separate gate.
const Config = preload("res://scripts/vfx/cel/ice_config.gd")
const EffectScene = preload("res://scenes/vfx/cel/ice.tscn")
const LabScene = preload("res://scenes/vfx_lab/cel/ice_lab.tscn")
const Lab = preload("res://scripts/vfx_lab/cel/ice_lab.gd")
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
	if commands.size() > 512: return "Unbounded active command count: %d" % commands.size()
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
	# A static ice logo that is merely stretched or sheared fails here.
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
	for i in range(samples): result.append(effect.build_commands(effect.config.duration()*i/float(samples),-1))
	return result

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
	check(is_finite(duration) and duration > 0,"Default crystallize/shatter cycle has a positive finite lifetime")
	defaults.duration_scale = 2
	check(is_equal_approx(defaults.duration(),duration*2),"Duration scale includes growth, hold, fracture and full shatter tail")

func test_parameters_and_determinism() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var baseline: Array = sample_cycle(effect)
	check(baseline == sample_cycle(effect),"Same seed and time reconstruct the full crystal cycle exactly")
	seed(92731)
	var expected_rng := randi()
	seed(92731)
	sample_cycle(effect)
	check(randi() == expected_rng,"Drawing never consumes the shared gameplay RNG")
	effect.config.seed_value += 1
	check(baseline != sample_cycle(effect),"Seed varies crystal growth/facets and fracture motion")
	for phase in [0.08,0.30,0.55,0.75,0.90]:
		effect.configure(Config.new())
		var time: float = effect.config.duration()*phase
		var original: Array = effect.build_commands(time,-1)
		effect.config.size = 2
		check(transformed_matches(effect.build_commands(time,-1),original,2,0),"Size transforms every layer at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.direction_degrees = 37
		check(transformed_matches(effect.build_commands(time,-1),original,1,deg_to_rad(37)),"Angle rotates every layer around the same origin at phase %.2f" % phase)
		effect.configure(Config.new())
		effect.config.duration_scale = 2
		check(original == effect.build_commands(time*2,-1),"Duration multiplier preserves normalized geometry at phase %.2f" % phase)
	for spec in range_specs(Config.new()):
		if spec[0] in ["size","direction_degrees","duration_scale"]: continue
		var config := Config.new()
		config.set(spec[0],spec[1])
		effect.configure(config)
		var minimum: Array = sample_cycle(effect)
		config.set(spec[0],spec[2])
		effect.configure(config)
		check(minimum != sample_cycle(effect),"Advertised knob observably changes geometry/timing: " + spec[0])
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
	check(not any_geometry,"Every visible layer may be disabled")
	var colored := Config.new()
	var custom := Color(0.17,0.46,0.63,1)
	for name in color_names(colored): colored.set(name,custom)
	effect.configure(colored)
	var matches := true
	for commands in sample_cycle(effect):
		for command in commands: matches = matches and command.color == custom
	check(matches,"Palette owns every emitted flat color")
	effect.configure(Config.new())
	for time in [10.0,3600.0,86400.0]:
		var commands: Array = effect.build_commands(time,INF)
		check(not commands.is_empty() and geometry_problem(commands).is_empty(),"Long-held ice has finite bounded active geometry at %.0f seconds" % time)
		check(commands == effect.build_commands(time,INF),"Long-held crystal phase is reproducible at %.0f seconds" % time)
	effect.free()

func solids(commands: Array, prefix: String) -> Array:
	var result: Array = []
	for command in commands:
		if String(command.layer).begins_with(prefix): result.append(command)
	return result

func all_points(commands: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for command in commands: result.append_array(command.points)
	return result

func total_area(commands: Array) -> float:
	var result := 0.0
	for command in commands: result += polygon_area(command.points)
	return result

func on_or_in_polygon(point: Vector2, polygon: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(point,polygon): return true
	for i in range(polygon.size()):
		if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point,polygon[i],polygon[(i+1)%polygon.size()])) < 0.0001: return true
	return false

func in_source(point: Vector2, source: Array) -> bool:
	for face in source:
		if on_or_in_polygon(point,face.points): return true
	return false

func same_solid_geometry(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in range(a.size()):
		if a[i].points != b[i].points or a[i].color != b[i].color: return false
	return true

func centroid(polygon: PackedVector2Array) -> Vector2:
	var result := Vector2.ZERO
	for point in polygon: result += point
	return result/maxi(polygon.size(),1)

func test_crystallization() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var config: Resource = effect.config
	var first := solids(effect.build_commands(config.growth_seconds*0.20,INF),"crystal_")
	var second := solids(effect.build_commands(config.growth_seconds*0.70,INF),"crystal_")
	check(not first.is_empty() and not second.is_empty(),"Crystallization shows growing solid planes before the hold phase")
	check(total_area(second) > total_area(first)*1.4,"Crystal material area grows substantially from the grounded seed")
	check(bounds(all_points(second)).position.y < bounds(all_points(first)).position.y-config.height*0.15,"Crystallization advances upward rather than translating an existing full crystal")
	var roots_fixed := true
	for early_face in first:
		if early_face.layer != "crystal_shadow": continue
		for late_face in second:
			if late_face.layer == "crystal_shadow" and late_face.crystal == early_face.crystal:
				roots_fixed = roots_fixed and early_face.points[-1].distance_to(late_face.points[-1]) < 2.0
	check(roots_fixed,"Growth keeps each visible crystal root anchored while its width matures")
	check(affine_residual(all_points(first),all_points(second)) > 0.0001,"Staggered crystal-plane growth differs from a single affine transform of a static cluster")
	var held_a: Array = effect.build_commands(config.growth_seconds+0.04,INF)
	var held_b: Array = effect.build_commands(config.growth_seconds+0.28,INF)
	check(same_solid_geometry(solids(held_a,"crystal_"),solids(held_b,"crystal_")),"Frozen solid planes stay stationary during their held phase")
	var highlight_moves := false
	var highlight_present := false
	var clipped := true
	var surface_count := 0
	var previous: Array = []
	for i in range(20):
		var commands: Array = effect.build_commands(config.growth_seconds+0.01+i*0.061,INF)
		var glints := layer_shapes(commands,"glint")
		highlight_present = highlight_present or not glints.is_empty()
		if i > 0 and not glints.is_empty() and not previous.is_empty(): highlight_moves = highlight_moves or glints != previous
		# Surface sweeps are clipped. The concept also has at most one freely
		# placed symmetric diamond accent per crystal; that is not a surface band.
		var detached_counts := {}
		for command in commands:
			if command.layer != "glint": continue
			var source: Array = []
			for face in solids(commands,"crystal_"):
				if face.get("crystal",-2) == command.get("crystal",-1): source.append(face)
			var inside := true
			for point in command.points: inside = inside and in_source(point,source)
			if inside:
				surface_count += 1
			else:
				var id: int = command.get("crystal",-1)
				detached_counts[id] = int(detached_counts.get(id,0))+1
				var points: PackedVector2Array = command.points
				clipped = clipped and points.size() == 4 and detached_counts[id] <= 1
				if points.size() == 4: clipped = clipped and ((points[0]+points[2])-(points[1]+points[3])).length() < 0.01
		previous = glints
	check(highlight_present and highlight_moves,"Held crystal has locally advancing light rather than a frozen icon")
	check(clipped and surface_count > 0,"Surface glints are clipped to their own planes; only one intentional detached diamond per crystal is allowed")
	config = Config.new()
	config.glint_speed = 0
	effect.configure(config)
	check(layer_shapes(effect.build_commands(0.6,INF),"glint") == layer_shapes(effect.build_commands(1.0,INF),"glint"),"Zero glint speed freezes only the local shimmer clock")
	effect.configure(Config.new())
	var crack_at: float = effect.config.growth_seconds+effect.config.hold_seconds
	var crack_early: Array = effect.build_commands(crack_at+effect.config.crack_seconds*0.2,-1)
	var crack_late: Array = effect.build_commands(crack_at+effect.config.crack_seconds*0.8,-1)
	check(not layer_shapes(crack_early,"crack").is_empty(),"Crack phase contains advancing visible seams before breakup")
	check(layer_area(crack_late,"crack") > layer_area(crack_early,"crack")*1.25,"Fracture seams propagate instead of appearing fully drawn at once")
	check(solids(crack_late,"chunk_").is_empty(),"The initial fracture phase retains a connected source until actual breakup")
	effect.free()

func test_source_bound_shatter() -> void:
	var effect := EffectScene.instantiate()
	for shatter_time in [0.03,0.13,0.40,2.0]:
		effect.configure(Config.new())
		effect.seek(shatter_time,-1,true)
		var before: Array = effect.build_commands()
		var source := solids(before,"crystal_")
		effect.shatter()
		check(same_solid_geometry(source,solids(effect.build_commands(),"crystal_")),"Shatter request preserves exact existing partial crystal at %.2f s" % shatter_time)
		var mid: Array = effect.build_commands(shatter_time+effect.config.crack_seconds*0.75,shatter_time)
		check(same_solid_geometry(source,solids(mid,"crystal_")),"Crack phase freezes its birth snapshot; no further crystallization at %.2f s" % shatter_time)
		var break_time: float = shatter_time+effect.config.crack_seconds
		var birth: Array = effect.build_commands(break_time,shatter_time)
		var chunks := solids(birth,"chunk_")
		check(not chunks.is_empty() or source.is_empty(),"Existing crystal planes become chunks at %.2f s" % shatter_time)
		var contained := true
		for chunk in chunks:
			var source_faces: Array = []
			for face in source:
				if face.get("crystal",-2) == chunk.get("crystal",-1): source_faces.append(face)
			for point in chunk.points: contained = contained and in_source(point,source_faces)
		check(contained,"Every chunk is born inside its actual crystal snapshot at %.2f s" % shatter_time)
		check(is_equal_approx(total_area(chunks),total_area(source)),"Birth preserves source surface area, including early small crystal fragments at %.2f s" % shatter_time)
		var palette_preserved := true
		for chunk in chunks:
			var matched := false
			for face in source:
				if face.color == chunk.color and face.get("crystal",-2) == chunk.get("crystal",-1): matched = true
			palette_preserved = palette_preserved and matched
		check(palette_preserved,"Fracture fragments retain their own source face colors at %.2f s" % shatter_time)
		var later := solids(effect.build_commands(break_time+effect.config.shatter_seconds*0.3,shatter_time),"chunk_")
		check(not same_solid_geometry(chunks,later) or chunks.is_empty(),"Fragments move independently after breakup at %.2f s" % shatter_time)
		check(effect.build_commands(effect.get_end_time(),shatter_time).is_empty(),"Early/held shatter clears at reported terminal time")
	effect.configure(Config.new())
	var shatter_time: float = effect.config.growth_seconds+effect.config.hold_seconds
	var break_time: float = shatter_time+effect.config.crack_seconds
	var first := solids(effect.build_commands(break_time,-1),"chunk_")
	var second := solids(effect.build_commands(break_time+0.24,-1),"chunk_")
	check(affine_residual(all_points(first),all_points(second)) > 0.0001,"A shattered cluster cannot be reproduced by translating/scaling/rotating one frozen image")
	var piece_ids := {}
	for command in first: piece_ids["%s:%s" % [command.get("crystal",-1),command.get("piece",-1)]] = true
	check(piece_ids.size() >= effect.config.crystal_count*2,"Each intact crystal divides into multiple independently driven pieces")
	var rotating := false
	for i in range(mini(first.size(),second.size())):
		var a: PackedVector2Array = first[i].points
		var b: PackedVector2Array = second[i].points
		if a.size() >= 2 and b.size() >= 2:
			rotating = rotating or absf((a[1]-a[0]).angle_to(b[1]-b[0])) > 0.02
	check(rotating,"Faceted fragments turn in flight, not only slide apart")
	# Three equally spaced early centers recover a quadratic trajectory's birth
	# position without calling the renderer's private shard generator.
	var shard_samples: Array = []
	for index in [1,2,3]:
		var sample := {}
		for command in effect.build_commands(break_time+effect.config.shatter_seconds*index*0.01,-1):
			if command.layer == "shard" and command.points.size() == 4:
				sample["%s:%s" % [command.crystal,command.piece]] = {"center":centroid(command.points),"crystal":command.crystal}
		shard_samples.append(sample)
	var recovered := 0
	var shard_origins_valid := true
	var full_source := solids(effect.build_commands(shatter_time,INF),"crystal_")
	for id in shard_samples[0]:
		if not shard_samples[1].has(id) or not shard_samples[2].has(id): continue
		var origin: Vector2 = 3.0*shard_samples[0][id].center-3.0*shard_samples[1][id].center+shard_samples[2][id].center
		var own_faces: Array = []
		for face in full_source:
			if face.crystal == shard_samples[0][id].crystal: own_faces.append(face)
		shard_origins_valid = shard_origins_valid and in_source(origin,own_faces)
		recovered += 1
	check(recovered >= effect.config.crystal_count and shard_origins_valid,"Small flying shard trajectories originate inside their own grown crystal, not an unrelated full-size emitter")
	var late := solids(effect.build_commands(break_time+effect.config.shatter_seconds*0.88,-1),"chunk_")
	check(total_area(late) < total_area(second)*0.65,"Shattered fragments contract before clearing rather than hard-popping intact")
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
	check(effect.build_commands(0.5,NAN).is_empty(),"Invalid explicit shatter time does not poison geometry")
	check(effect.build_commands(0.5,-2).is_empty(),"Unsupported negative shatter override is empty")
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"Normal terminal age equals complete configured lifetime")
	effect.finished.connect(func(): finish_count += 1)
	effect.shatter()
	check(not effect.playing and effect.shatter_at < 0,"Dormant shatter is ignored")
	effect.play()
	effect._process(0.1)
	check(effect.playing and is_equal_approx(effect.age,0.1),"Growth advances after play")
	for invalid_delta in [-1.0,NAN,INF,-INF]: effect._process(invalid_delta)
	check(is_equal_approx(effect.age,0.1),"Negative/nonfinite delta cannot rewind or corrupt growth")
	effect._process(effect.get_end_time()+1)
	effect._process(1)
	check(not effect.playing and finish_count == 1 and effect.build_commands().is_empty(),"Finite cycle clears and emits completion once")
	var completed_shatter: float = effect.shatter_at
	effect.shatter()
	check(effect.shatter_at == completed_shatter and not effect.playing,"Shatter after completion does not restart the tail")
	effect.play(true)
	check(effect.get_end_time() == INF and effect.shatter_at < 0,"Held play resets shatter and has no automatic terminal age")
	effect._process(10)
	check(effect.playing and not effect.build_commands().is_empty() and finish_count == 1,"Held ice stays active beyond the finite default duration")
	effect.shatter()
	var first_shatter: float = effect.shatter_at
	var end_time: float = effect.get_end_time()
	check(is_equal_approx(first_shatter,10) and is_finite(end_time) and end_time > first_shatter,"Shatter records actual absolute time and establishes a finite tail")
	effect._process(0.1)
	effect.shatter()
	check(effect.shatter_at == first_shatter and effect.get_end_time() == end_time,"Repeated shatter cannot refresh or extend the tail")
	effect._process(end_time+1)
	check(not effect.playing and finish_count == 2 and effect.build_commands().is_empty(),"Shattered held ice finishes exactly once")
	for early in [0.04,0.65]:
		effect.seek(early,-1,true)
		var before: Array = effect.build_commands().duplicate(true)
		effect.shatter()
		check(not effect.playing and effect.shatter_at == early,"Shatter preserves pause while recording growth/hold time %.2f" % early)
		check(before == effect.build_commands(),"Shatter does not jump the instantaneous geometry at %.2f" % early)
		var terminal: float = effect.get_end_time()
		check(effect.build_commands(terminal,early).is_empty(),"Early shatter clears by its reported terminal age")
		var frozen_age: float = effect.age
		effect._process(1)
		check(effect.age == frozen_age,"Shattered seek remains manually paused")
	effect.seek(effect.config.duration()-0.1,-1,false)
	var auto_end: float = effect.get_end_time()
	effect.shatter()
	check(effect.get_end_time() == auto_end,"Late shatter cannot restart automatic fragment clearance")
	effect.seek(2.0,1.8,false)
	check(is_equal_approx(effect.get_end_time(),effect.config.duration()),"A late explicit non-held seek shatter is clamped to automatic shatter")
	check(effect.build_commands(1.9,1.8) == effect.build_commands(1.9,-1),"Finite late override cannot render a restarted crystal")
	effect.seek(0.5,0.3,true)
	check(effect.build_commands() == effect.build_commands(0.5,0.3),"Seek reconstructs explicit realtime shatter state")
	check(effect.build_commands(0.5,-1) != effect.build_commands(0.5,0.3),"Explicit -1 overrides node shatter with the finite automatic schedule")
	effect.play()
	check(effect.age == 0 and effect.shatter_at < 0 and is_equal_approx(effect.get_end_time(),effect.config.duration()),"Replay clears previous explicit shatter and held state")
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
	rng.seed = 83129
	for variant in range(16):
		var config := Config.new()
		if variant > 0:
			for spec in range_specs(config):
				var candidate: float = spec[1] if variant == 1 else (spec[2] if variant == 2 else rng.randf_range(spec[1],spec[2]))
				config.set(spec[0],int(round(candidate)) if spec[3] == TYPE_INT else candidate)
			config.seed_value = variant*4127-18000
		effect.configure(config)
		var problem := ""
		for frame in range(121):
			var age: float = effect.config.duration()*frame/120.0
			var commands: Array = effect.build_commands(age,-1)
			problem = geometry_problem(commands)
			if not problem.is_empty(): problem += " at %.9f" % age; break
			if commands != effect.build_commands(age,-1): problem = "Nondeterministic sample"; break
		check(problem.is_empty(),"Finite opaque bounded triangulation for 121 poses in variant %d: %s" % [variant,problem])
		check(effect.build_commands(effect.config.duration(),-1).is_empty(),"Every sanitized finite variant fully clears")
		check(geometry_problem(effect.build_commands(3600,INF)).is_empty(),"Every sanitized variant supports bounded long-held geometry")
	for multiplier in [0.4,1.0,2.0]:
		var config := Config.new()
		config.duration_scale = multiplier
		config.crystal_count = 7
		effect.configure(config)
		var automatic: float = (config.growth_seconds+config.hold_seconds)*multiplier
		for requested in [-1.0,0.0,0.03*multiplier,0.13*multiplier,1.8*multiplier]:
			var actual: float = automatic if requested < 0 else requested
			var terminal: float = actual+(config.crack_seconds+config.shatter_seconds+0.04)*multiplier
			effect.seek(0.1,requested,requested >= 0)
			check(is_equal_approx(effect.get_end_time(),terminal),"End time respects realtime shatter plus scaled crack and fragment tail")
			var boundaries := [0.0,config.growth_seconds*multiplier,actual,actual+config.crack_seconds*multiplier,terminal]
			var problem := ""
			for boundary in boundaries:
				for epsilon in [0.0,0.001,0.00001,0.0000001,0.000000001,0.00000000001]:
					for side in [-1.0,1.0]:
						var age: float = boundary+side*epsilon
						var current := geometry_problem(effect.build_commands(age,requested))
						if not current.is_empty(): problem = "%s at %.17f" % [current,age]
			check(problem.is_empty(),"Dense growth/crack/shatter boundaries at time scale %.2f and shatter %.2f: %s" % [multiplier,requested,problem])
			check(effect.build_commands(terminal,requested).is_empty(),"Every early or held shatter boundary finishes fully empty")
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
	check(not lab.held_crystals and lab.shattered_at < 0 and not lab.floor_host,"Ice preview starts as a finite independent crystal component")
	key(lab,KEY_H)
	key(lab,KEY_H,true)
	check(lab.held_crystals and lab.effect.get_end_time() == INF,"Hold toggle sets held state exactly once and ignores echoed key input")
	lab.step(5)
	check(lab.elapsed > lab.effect.config.duration() and lab.effect.get_end_time() == INF,"Held preview survives beyond the finite automatic breakup")
	key(lab,KEY_SPACE)
	var held_age: float = lab.elapsed
	lab._process(0.1)
	check(not lab.playing and lab.elapsed == held_age,"Pause freezes a held crystal timeline")
	lab.trigger_shatter()
	var first_shatter: float = lab.shattered_at
	var first_end: float = lab.effect.get_end_time()
	check(not lab.playing and first_shatter == held_age and is_finite(first_end),"Manual shatter preserves pause and records the current held age")
	key(lab,KEY_RIGHT)
	lab.trigger_shatter()
	check(lab.shattered_at == first_shatter and lab.effect.get_end_time() == first_end,"Repeated shatter after stepping cannot refresh the tail")
	lab.replay()
	check(lab.playing and lab.held_crystals and lab.shattered_at < 0 and is_equal_approx(lab.elapsed,-0.35),"Replay clears old shatter while preserving hold preference")
	lab.set_hold_crystals(false)
	lab.step(lab.effect.config.duration()+0.1)
	var normal_end: float = lab.effect.get_end_time()
	lab.trigger_shatter()
	check(lab.shattered_at < 0 and lab.effect.get_end_time() == normal_end,"Late finite shatter never resurrects fragments")
	lab.reset_defaults()
	var full_fit: float = lab.fit_scale
	lab.set_hold_crystals(true)
	lab.step(0.40)
	lab.trigger_shatter()
	lab._fit_effect()
	check(is_equal_approx(lab.fit_scale,full_fit),"Early small shatter does not contaminate framing of the next complete growth")
	lab.reset_defaults()
	key(lab,KEY_S)
	lab._process(0.08)
	check(is_equal_approx(lab.elapsed,-0.33),"Quarter playback changes preview time only")
	key(lab,KEY_B)
	key(lab,KEY_E)
	check(lab.light_background and lab.effect_only and lab.status.text.contains("EFFECT ONLY"),"Guide and background controls are independent and accurately labeled")
	key(lab,KEY_E)
	check(not lab.effect_only and not lab.status.text.contains("EFFECT ONLY"),"Guide-visible status is not mislabeled as isolated effect")
	for name in lab.param_controls:
		var control: Control = lab.param_controls[name]
		if control is SpinBox:
			control.value = control.max_value
			check(is_equal_approx(float(lab.effect.config.get(name)),control.max_value) and is_equal_approx(lab.elapsed,-0.35),"Numeric UI validates and replays: " + name)
		elif control is CheckBox:
			control.button_pressed = not control.button_pressed
			check(lab.effect.config.get(name) == control.button_pressed,"Layer UI responds independently: " + name)
	for name in lab.color_controls:
		var color := Color(0.21,0.43,0.67,1)
		lab.color_controls[name].color_changed.emit(color)
		check(lab.effect.config.get(name) == color,"Live palette updates: " + name)
	check(values(lab.effect.settings) == source_before,"UI never mutates the caller/Inspector Resource")
	var before: Dictionary = values(lab.effect.config)
	lab.set_parameter("unsupported",99)
	lab.set_color("unsupported",Color.RED)
	check(values(lab.effect.config) == before,"Unsupported UI fields are ignored")
	lab.set_hold_crystals(true)
	lab.reset_defaults()
	check(values(lab.effect.config) == values(Config.new()) and not lab.held_crystals and lab.shattered_at < 0 and lab.playback_speed == 1 and not lab.effect_only,"Reset restores exact configuration, finite mode and presentation defaults")
	lab.toggle_parameters()
	await process_frame
	var editor: LineEdit = lab.param_controls["size"].get_line_edit()
	editor.grab_focus()
	check(editor.has_focus(),"Numeric editor receives focus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	lab._input(escape)
	check(not editor.has_focus() and not lab.settings_panel.visible,"Escape closes interrupted editing and releases numeric focus")
	lab.toggle_parameters()
	var popup: PopupPanel = lab.color_controls["ridge_color"].get_popup()
	popup.show()
	lab.toggle_parameters()
	check(not popup.visible and not lab.settings_panel.visible,"Panel close explicitly closes its color picker")
	lab.toggle_parameters()
	popup.show()
	lab._input(escape)
	check(not popup.visible and not lab.settings_panel.visible,"Escape dismisses both palette popup and parameter panel")
	var count: int = lab.get_child_count()
	for repeat in range(20):
		lab.set_hold_crystals(true)
		lab.step(0.6)
		lab.trigger_shatter()
		lab.toggle_play()
		lab.replay()
	check(lab.get_child_count() == count and lab.playing and lab.shattered_at < 0,"Repeated held/shattered/interrupted replay never accumulates nodes")
	lab.free()

func test_capture() -> void:
	var effect := EffectScene.instantiate()
	effect.configure(Config.new())
	var elapsed := -0.35
	var shattered_at := -1.0
	var previous_segment := -1
	var seen := {}
	var problem := ""
	var last_finite_cleared := false
	for frame in range(Lab.ICE_CAPTURE_FRAMES):
		var segment: int = frame/360
		if segment != previous_segment:
			previous_segment = segment
			elapsed = -0.35
			shattered_at = -1.0
			seen[segment] = true
		if segment == 0 and elapsed >= effect.config.duration()+0.55: elapsed = -0.35
		elapsed += (1.0 if segment == 0 else 0.5)/60.0
		if segment == 2 and elapsed >= 1.15 and shattered_at < 0: shattered_at = 1.15
		effect.seek(elapsed,shattered_at,segment == 2)
		var current := geometry_problem(effect.build_commands())
		if not current.is_empty(): problem = "%s at frame %d" % [current,frame]
		if segment == 1 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(): last_finite_cleared = true
	check(Lab.ICE_CAPTURE_FRAMES == 1080 and seen.size() == 3,"Capture is the declared 18-second normal/light/held-shatter sequence")
	check(problem.is_empty(),"Every actual capture-clock pose has valid triangulation: " + problem)
	check(last_finite_cleared,"Light-background slow pass includes full finite fragment clearance")
	check(shattered_at == 1.15 and elapsed > effect.get_end_time() and effect.build_commands().is_empty(),"Last held-shatter pass includes complete tail and a blank ending")
	effect.free()

func run() -> void:
	test_config()
	test_crystallization()
	test_source_bound_shatter()
	test_parameters_and_determinism()
	test_lifecycle()
	test_geometry()
	test_capture()
	await test_lab()
	print("CEL_ICE: %d checks, %d failures" % [checks,failures])
	quit(failures)
