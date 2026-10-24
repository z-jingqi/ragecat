extends SceneTree
## Regression coverage for presentation resources and safe missing-data handling.
var checks := 0
var failures := 0
const CLIP := &"east/sample"

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("PRESENTATION AUDIT: " + label)

func make_texture(size := Vector2i(32, 32)) -> ImageTexture:
	var pixels := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	return ImageTexture.create_from_image(pixels)

func make_library() -> ArcherPoseLibrary:
	var value := ArcherPoseLibrary.new()
	value.canvas_size = Vector2i(32, 32)
	value.pivot = Vector2(16, 16)
	value.colors = SpriteFrames.new()
	value.depths = SpriteFrames.new()
	value.colors.add_animation(CLIP)
	value.depths.add_animation(CLIP)
	value.colors.add_frame(CLIP, make_texture())
	value.depths.add_frame(CLIP, make_texture())
	return value

func run() -> void:
	var appearance := ArcherAppearanceDefinition.new()
	appearance.upper = make_library()
	appearance.lower = make_library()
	var view := ArcherLayeredPoseView.new()
	root.add_child(view)
	view.configure(appearance)
	for layer_name in ["upper", "lower"]:
		var library: ArcherPoseLibrary = appearance.get(layer_name)
		for frame_kind in ["colors", "depths"]:
			var frames: SpriteFrames = library.get(frame_kind)
			var original := frames.get_frame_texture(CLIP, 0)
			check(view.show_pose(CLIP, 0.0, CLIP, 0.0) and view._drawable,
				"Valid pose draws before removing " + layer_name + "/" + frame_kind)
			frames.set_frame(CLIP, 0, null)
			check(library.sample(CLIP, 0.0).is_empty(), "Missing frame rejects sample: " + layer_name + "/" + frame_kind)
			check(not view.show_pose(CLIP, 0.0, CLIP, 0.0), "Missing frame rejects display: " + layer_name + "/" + frame_kind)
			check(not view._drawable, "Missing frame clears previous display: " + layer_name + "/" + frame_kind)
			frames.set_frame(CLIP, 0, original)
			check(view.show_pose(CLIP, 0.0, CLIP, 0.0) and view._drawable,
				"Restored frame can draw again: " + layer_name + "/" + frame_kind)
	var original_color := appearance.upper.colors.get_frame_texture(CLIP, 0)
	appearance.upper.colors.set_frame(CLIP, 0, make_texture(Vector2i(16, 16)))
	check(not view.show_pose(CLIP, 0.0, CLIP, 0.0) and not view._drawable, "Wrong fixed-canvas size fails closed")
	appearance.upper.colors.set_frame(CLIP, 0, original_color)
	check(view.show_pose(CLIP, 0.0, CLIP, 0.0), "Valid display restored before missing clip")
	check(not view.show_pose(&"missing", 0.0, CLIP, 0.0) and not view._drawable, "Missing clip clears old display")
	appearance.lower.pivot += Vector2.ONE
	check(not view.show_pose(CLIP, 0.0, CLIP, 0.0) and not view._drawable, "Mismatched pivots fail closed")
	appearance.lower.pivot -= Vector2.ONE
	var atlas := AtlasTexture.new()
	atlas.atlas = make_texture(Vector2i(64, 32))
	atlas.region = Rect2(40, 0, 32, 32)
	appearance.upper.colors.set_frame(CLIP, 0, atlas)
	check(not view.show_pose(CLIP, 0.0, CLIP, 0.0) and not view._drawable, "Out-of-bounds atlas region fails closed")
	atlas.region = Rect2(32, 0, 32, 32)
	check(view.show_pose(CLIP, 0.0, CLIP, 0.0), "Valid atlas subregion draws")
	appearance.upper.colors.set_frame(CLIP, 0, original_color)
	view.configure(null)
	check(not view.show_pose(CLIP, 0.0, CLIP, 0.0) and not view._drawable, "Null appearance clears old display")
	view.free()

	appearance.stride_pixels = 91.0
	appearance.release_duration = 0.041
	appearance.recovery_duration = 0.092
	appearance.draw_duration = 0.203
	var a := appearance.create_pose_clock()
	var b := appearance.create_pose_clock()
	check(a != b and a.stride_distance == 91.0 and b.stride_distance == 91.0, "Clock factory creates independent configured instances")
	a.reset(Vector2.ZERO)
	check(a._release_window == appearance.release_duration and a._recovery_window == appearance.recovery_duration and a._draw_window == appearance.draw_duration,
		"Reset uses authored shot timing rather than hard-coded cached windows")
	a.stride_distance = 7.0
	check(b.stride_distance == 91.0 and appearance.stride_pixels == 91.0, "Changing one clock does not mutate another or its resource")
	appearance.target_confirmation = 0.071
	appearance.target_loss_grace = 0.182
	appearance.raise_duration = 0.153
	appearance.lower_duration = 0.244
	appearance.relax_duration = 0.115
	appearance.draw_follow_duration = 0.086
	appearance.short_enter_interval = 0.217
	appearance.short_exit_interval = 0.308
	appearance.maximum_full_draw_hold = 0.259
	var posture := appearance.create_posture_clock()
	for key in ["target_confirmation", "target_loss_grace", "raise_duration", "lower_duration", "relax_duration", "draw_follow_duration", "short_enter_interval", "short_exit_interval", "maximum_full_draw_hold"]:
		check(posture.get(key) == appearance.get(key), "Posture factory copies " + key)
	posture.reset()
	check(posture.target_confirmation == 0.071 and posture.draw_follow_duration == 0.086, "Posture reset preserves authored configuration")
	print("ISOLATED PRESENTATION AUDIT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
