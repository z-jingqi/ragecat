extends SceneTree
## Shipped-resource coverage, not a visual-quality certification. Missing final
## assets fail this suite rather than silently skipping the integration contract.
const APPEARANCE_PATH := "res://resources/characters/archer/appearance.tres"
const ACTOR_PATH := "res://scenes/characters/archer/archer.tscn"
const DIRECTIONS := ["east", "southeast", "south", "southwest", "west", "northwest", "north", "northeast"]
const UPPER_CLIPS := ["carry", "raise", "lower", "lower_loaded", "controlled_undraw", "normal_release", "normal_renock", "normal_draw", "short_release", "short_recover", "short_draw", "hold_relaxed", "hold_relaxed_loaded", "short_undraw"]
const MOVEMENT_CLIPS := ["run_forward", "run_forward_right", "run_right", "run_back_right", "run_back", "run_back_left", "run_left", "run_forward_left"]
const GAIT_FRAMES := 16
var checks := 0
var failures := 0
var upper_frames := 0
var lower_frames := 0
var native_pages: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("ARCHER ASSET COVERAGE: " + label)
	return value

func validate_library(library: ArcherPoseLibrary, label: String) -> bool:
	if not check(library != null, label + " library is present"): return false
	if not check(library.colors != null and library.depths != null, label + " color/depth SpriteFrames are present"): return false
	check(library.canvas_size.x > 0 and library.canvas_size.y > 0, label + " canvas has positive dimensions")
	check(library.pivot.is_finite(), label + " pivot is finite")
	check(library.packed_depth, label + " uses packed depth decoding")
	check(library.colors.get_animation_names() == library.depths.get_animation_names(), label + " color and depth name coverage matches")
	return true

func validate_atlas(texture: Texture2D, library: ArcherPoseLibrary, depth: bool, label: String) -> AtlasTexture:
	if not check(texture is AtlasTexture, label + " is an AtlasTexture, not a loose source image"): return null
	var atlas := texture as AtlasTexture
	check(atlas.get_size() == Vector2(library.canvas_size), label + " uses the common fixed canvas")
	check(atlas.region.size == Vector2(library.canvas_size), label + " region matches the fixed canvas")
	check(atlas.margin == Rect2(), label + " has no per-frame trim margin")
	if not check(atlas.atlas is ImageTexture, label + " references a native ImageTexture page"): return atlas
	var page := atlas.atlas as ImageTexture
	check(page.resource_path.begins_with("res://") and page.resource_path.get_extension() == "res", label + " page is a persisted native .res resource")
	check(Rect2(Vector2.ZERO, page.get_size()).encloses(atlas.region), label + " region lies inside its page")
	var page_key := page.get_instance_id()
	if not native_pages.has(page_key):
		check(page.get_width() > 0 and page.get_height() > 0, label + " page has positive dimensions")
		check(page.get_format() == (Image.FORMAT_RG8 if depth else Image.FORMAT_RGBA8), label + " page uses RG8 packed depth or RGBA8 color")
		native_pages[page_key] = {"depth": depth, "size": page.get_size(), "path": page.resource_path}
	else:
		check(native_pages[page_key].depth == depth, label + " page is not reused as both color and depth")
	return atlas

func validate_clip(library: ArcherPoseLibrary, clip: StringName, expected_count: int = -1, looped: bool = false) -> int:
	if not check(library.colors.has_animation(clip), "Color clip exists: " + String(clip)): return 0
	if not check(library.depths.has_animation(clip), "Depth clip exists: " + String(clip)): return 0
	# Upper-body counts are authored per clip; do not freeze the importer output
	# into a second hard-coded list of expected shooting frame counts.
	var count := library.colors.get_frame_count(clip)
	check(count > 0, "Clip contains frames: " + String(clip))
	check(library.depths.get_frame_count(clip) == count, "Depth frame count matches color: " + String(clip))
	if expected_count >= 0: check(count == expected_count, "Required locomotion frame count: " + String(clip))
	check(library.validate_clip(clip).is_empty(), "Library accepts every frame in " + String(clip))
	for index in range(count):
		var label := "%s[%d]" % [clip, index]
		var color := validate_atlas(library.colors.get_frame_texture(clip, index), library, false, label + " color")
		var depth: AtlasTexture
		if index < library.depths.get_frame_count(clip):
			depth = validate_atlas(library.depths.get_frame_texture(clip, index), library, true, label + " depth")
		if color != null and depth != null:
			check(color.region == depth.region, label + " color/depth regions are registered")
			if color.atlas != null and depth.atlas != null:
				check(color.atlas.get_size() == depth.atlas.get_size(), label + " color/depth page dimensions match")
		var phase := (float(index) + 0.25) / count if looped else float(index) / maxi(1, count - 1)
		var sample := library.sample(clip, phase, looped)
		if check(not sample.is_empty(), label + " is sampleable at its actual phase"):
			check(sample.index == index and sample.packed_depth, label + " selects the correct packed-depth frame")
	return count

func validate_appearance(value: ArcherAppearanceDefinition) -> void:
	check(Array(value.direction_names) == DIRECTIONS, "Eight facing names match the clock's angular ordering")
	check(Array(value.movement_clips) == MOVEMENT_CLIPS, "Eight relative movement names match the clock's angular ordering")
	check(is_finite(value.display_scale) and value.display_scale > 0.0, "Display scale is finite and positive")
	var upper_valid := validate_library(value.upper, "Upper")
	var lower_valid := validate_library(value.lower, "Lower")
	if upper_valid and lower_valid:
		check(value.upper.canvas_size == value.lower.canvas_size, "Both layers share one canvas")
		check(value.upper.pivot == value.lower.pivot, "Both layers share one pivot")
	if upper_valid:
		check(value.upper.colors.get_animation_names().size() == DIRECTIONS.size() * UPPER_CLIPS.size(), "Upper library contains exactly 8 x 14 clips")
	if lower_valid:
		check(value.lower.colors.get_animation_names().size() == DIRECTIONS.size() * (MOVEMENT_CLIPS.size() + 1), "Lower library contains exactly 8 x (8 movement + idle) clips")
	check(value.directional_strides.size() == DIRECTIONS.size() * MOVEMENT_CLIPS.size(), "All 64 directional strides are authored")
	for index in range(value.directional_strides.size()):
		var stride := value.directional_strides[index]
		check(is_finite(stride) and stride > 0.0, "Stride %d is finite and positive" % index)
	check(value.muzzle_positions.size() == DIRECTIONS.size(), "All eight facing muzzle positions are authored")
	for index in range(value.muzzle_positions.size()):
		check(value.muzzle_positions[index].is_finite(), "Muzzle %d is finite" % index)
	for direction in DIRECTIONS:
		if upper_valid:
			for suffix in UPPER_CLIPS:
				upper_frames += validate_clip(value.upper, StringName(direction + "/" + suffix))
		var idle := StringName(direction + "/idle")
		if lower_valid: lower_frames += validate_clip(value.lower, idle, 1)
		check(value.idle_bobs.has(idle), "Idle bob is authored: " + String(idle))
		var idle_bob: Variant = value.idle_bobs.get(idle)
		if check(idle_bob is Vector2, "Idle bob is Vector2: " + String(idle)):
			check(idle_bob.is_finite(), "Idle bob is finite: " + String(idle))
		for movement in MOVEMENT_CLIPS:
			var clip := StringName(direction + "/" + movement)
			var count := validate_clip(value.lower, clip, GAIT_FRAMES, true) if lower_valid else 0
			lower_frames += count
			check(value.gait_bobs.has(clip), "Gait bob track is authored: " + String(clip))
			var bobs: Variant = value.gait_bobs.get(clip)
			if check(bobs is PackedVector2Array, "Gait bob track has the runtime's packed Vector2 type: " + String(clip)):
				check(bobs.size() == count and bobs.size() == GAIT_FRAMES, "Gait bob count matches each actual movement frame: " + String(clip))
				for index in range(bobs.size()):
					check(bobs[index].is_finite(), "%s bob[%d] is finite" % [clip, index])

func validate_default_actor(value: ArcherAppearanceDefinition) -> void:
	if not check(ResourceLoader.exists(ACTOR_PATH), "Default Archer scene exists"): return
	var scene := load(ACTOR_PATH) as PackedScene
	if not check(scene != null, "Default Archer scene loads as PackedScene"): return
	var node := scene.instantiate()
	if check(node is Archer, "Default scene instantiates Archer"):
		var actor := node as Archer
		check(actor.appearance == null, "Default scene does not preload heavy appearance before entering the tree")
		check(actor.appearance_path == APPEARANCE_PATH, "Default scene carries the exact lazy appearance path")
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(actor)
		check(actor.appearance == value, "Entering the tree resolves the exact final appearance resource")
		if actor.appearance != null:
			check(actor.appearance.resource_path == APPEARANCE_PATH, "Resolved appearance points to the shipped resource path")
		check(actor._presentation != null, "Entering the tree builds the optional presentation")
		root.remove_child(actor)
	# Physics stays disabled; this probes real ready/exit wiring without a run,
	# weapon fire, player statistics, or persistence changes.
	node.free()

func run() -> void:
	if check(ResourceLoader.exists(APPEARANCE_PATH), "Final appearance resource exists; incomplete imports must fail"):
		var value := load(APPEARANCE_PATH) as ArcherAppearanceDefinition
		if check(value != null, "Final appearance loads with the expected resource class"):
			validate_appearance(value)
			validate_default_actor(value)
	print("ARCHER ASSET COVERAGE: %d checks, %d failures; %d upper frames, %d lower frames, %d native atlas pages" % [checks, failures, upper_frames, lower_frames, native_pages.size()])
	quit(1 if failures else 0)
