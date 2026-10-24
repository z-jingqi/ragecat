extends SceneTree
## Release gate: a missing direction must fail even though runtime can fall back.
var checks := 0
var failures := 0
var textures: Dictionary = {}
var unique_frames: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("DASH ASSET COVERAGE: " + label)
func inspect_clip(library: ArcherPoseLibrary, clip: StringName, motion: ArcherDashMotionDefinition) -> void:
	if not library.colors.has_animation(clip) or not library.depths.has_animation(clip):
		check(false,"Missing required reviewed clip: " + str(clip))
		return
	check(library.validate_clip(clip).is_empty(),"Fixed logical canvas is valid: " + str(clip))
	check(library.colors.get_frame_count(clip) == 9,"Nine authored dash/recovery states: " + str(clip))
	var bobs: PackedVector2Array = motion.bobs.get(clip,PackedVector2Array())
	check(bobs.size() == 9,"Every frame has its shared body/bow offset: " + str(clip))
	for index in library.colors.get_frame_count(clip):
		var sample := library.sample(clip,float(index)/8.0)
		check(not sample.is_empty(),"Required frame cannot silently fall back: %s[%d]" % [clip,index])
		if sample.is_empty(): continue
		check(sample.color.canvas_region == sample.depth.canvas_region,"Color/depth trim agrees")
		var color: AtlasTexture = library.colors.get_frame_texture(clip,index)
		var depth: AtlasTexture = library.depths.get_frame_texture(clip,index)
		check(color != null and depth != null,"Frames use native reusable atlases")
		if color == null or depth == null: continue
		unique_frames[color.get_instance_id()] = true
		for atlas in [color,depth]:
			check(atlas.atlas != null and atlas.atlas.resource_path.begins_with("res://assets/characters/archer/poses/dash/"),"Atlas references a shipped external resource")
			check(atlas.atlas.get_width() <= 2048 and atlas.atlas.get_height() <= 2048,"Conservative desktop atlas size")
			check(Rect2(Vector2.ZERO,atlas.atlas.get_size()).encloses(atlas.region),"Atlas rectangle remains within texture")
			textures[atlas.atlas.get_instance_id()] = atlas.atlas
func run() -> void:
	var appearance: ArcherAppearanceDefinition = load("res://resources/characters/archer/appearance.tres")
	var motion := appearance.dash_motion
	check(motion != null,"Archer has authored dash motion")
	if motion == null:
		quit(1)
		return
	check(motion.resource_path == "res://resources/characters/archer/dash_motion.tres","No embedded stale motion snapshot")
	check(motion.body.resource_path == "res://assets/characters/archer/poses/dash/dash_body.tres","External body library")
	check(motion.guard.resource_path == "res://assets/characters/archer/poses/dash/dash_guard.tres","External guard library")
	check(motion.body.colors.get_animation_names().size() == 64,"All eight aim by eight travel combinations")
	check(motion.guard.colors.get_animation_names().size() == 16,"Eight guard and eight moving-recovery clips")
	for direction in appearance.direction_names:
		for relative in range(8):
			var clip := StringName(direction + "/dash_" + str(relative))
			inspect_clip(motion.body,clip,motion)
			check(motion.gait_entry_phases.has(clip),"Planted-foot gait entry exists: " + str(clip))
		var guard := StringName(direction + "/guard")
		var moving := StringName(direction + "/guard_move")
		inspect_clip(motion.guard,guard,motion)
		inspect_clip(motion.guard,moving,motion)
		check(motion.guard_move_distances.get(moving,0.0) > 0.0,"Distance-driven recovery is configured")
		check(motion.guard_move_exit_phases.has(moving),"Actual rendered walking exit phase is configured")
		if motion.guard.colors.has_animation(guard) and motion.guard.colors.has_animation(moving):
			for index in range(6):
				check(motion.guard.colors.get_frame_texture(guard,index) == motion.guard.colors.get_frame_texture(moving,index),"Moving recovery shares existing guard frame, no duplicate texture")
	check(unique_frames.size() == 672,"Exactly 672 unique authored color frames")
	var bytes := 0
	for texture in textures.values(): bytes += texture.get_image().get_data_size()
	print("ARCHER DASH ASSETS: %d checks, %d failures; %d unique frames, %d raw texture bytes" % [checks,failures,unique_frames.size(),bytes])
	quit(1 if failures else 0)
