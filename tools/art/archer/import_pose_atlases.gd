extends SceneTree
## Offline importer for authored fixed-canvas color/Z exports. Not used at runtime.
## Usage: godot --headless --path PROJECT --script THIS_SCRIPT -- UPPER_JSON BODY_JSON OUTPUT_DIR
const CELL_GUTTER := 2
const MAX_PAGE_SIZE := 2048
var _near := INF
var _far := -INF
var _canvas := Vector2i.ZERO
var _pivot := Vector2.ZERO
var _pages := 0
var _bytes := 0

func _initialize() -> void: call_deferred("run")
func _read_manifest(path: String) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	data["base"] = data.get("asset_root", path.get_base_dir())
	return data
func _depth_path(data: Dictionary, frame: Dictionary) -> String:
	if frame.has("depth"): return str(data.base).path_join(frame.depth)
	var found := ""
	for file in DirAccess.get_files_at(str(data.base).path_join("depth_exr")):
		if file.begins_with(frame.depth_prefix) and file.ends_with(".exr"):
			assert(found.is_empty(), "Ambiguous depth frame")
			found = str(data.base).path_join("depth_exr").path_join(file)
	assert(not found.is_empty(), "Missing depth frame")
	return found
func _depth_image(data: Dictionary, frame: Dictionary) -> Image:
	var image := Image.load_from_file(_depth_path(data, frame))
	assert(image != null and image.get_size() == _canvas)
	image.convert(Image.FORMAT_RF)
	return image
func _scan(data: Dictionary) -> void:
	for clip in data.clips:
		for frame in data.clips[clip].frames:
			var values := _depth_image(data, frame).get_data().to_float32_array()
			for value in values:
				if is_finite(value) and value > 0.0 and value < 20.0:
					_near = minf(_near, value)
					_far = maxf(_far, value)
func _normalized_depth(image: Image) -> Image:
	var values := image.get_data().to_float32_array()
	var span := maxf(_far - _near, 0.001)
	var bytes := PackedByteArray()
	bytes.resize(values.size() * 2)
	for i in range(values.size()):
		var value := clampf((values[i] - _near) / span, 0.0, 1.0) if is_finite(values[i]) else 1.0
		var encoded := int(round(value * 65535.0))
		bytes[i * 2] = (encoded >> 8) & 255
		bytes[i * 2 + 1] = encoded & 255
	return Image.create_from_data(_canvas.x, _canvas.y, false, Image.FORMAT_RG8, bytes)
func _save_texture(image: Image, path: String) -> ImageTexture:
	var texture := ImageTexture.create_from_image(image)
	assert(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS | ResourceSaver.FLAG_CHANGE_PATH) == OK)
	_bytes += image.get_data_size()
	return load(path) as ImageTexture
func _build(data: Dictionary, prefix: String, output: String) -> ArcherPoseLibrary:
	var result := ArcherPoseLibrary.new()
	result.canvas_size = _canvas
	result.pivot = _pivot
	result.packed_depth = true
	result.colors = SpriteFrames.new()
	result.depths = SpriteFrames.new()
	result.colors.remove_animation("default")
	result.depths.remove_animation("default")
	var entries: Array[Dictionary] = []
	for clip in data.clips:
		result.colors.add_animation(clip)
		result.depths.add_animation(clip)
		for frame in data.clips[clip].frames: entries.append({"clip": clip, "frame": frame})
	var cell := _canvas + Vector2i.ONE * CELL_GUTTER * 2
	var columns := MAX_PAGE_SIZE / cell.x
	var rows_per_page := MAX_PAGE_SIZE / cell.y
	var page_capacity := columns * rows_per_page
	for start in range(0, entries.size(), page_capacity):
		var count := mini(page_capacity, entries.size() - start)
		var rows := ceili(float(count) / columns)
		var size := Vector2i(columns * cell.x, rows * cell.y)
		var color_page := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var depth_page := Image.create(size.x, size.y, false, Image.FORMAT_RG8)
		color_page.fill(Color.TRANSPARENT)
		depth_page.fill(Color.WHITE)
		for local_index in range(count):
			var entry: Dictionary = entries[start + local_index]
			var frame: Dictionary = entry.frame
			var color := Image.load_from_file(str(data.base).path_join(frame.color))
			assert(color != null and color.get_size() == _canvas)
			color.convert(Image.FORMAT_RGBA8)
			var depth := _normalized_depth(_depth_image(data, frame))
			var at := Vector2i((local_index % columns) * cell.x, (local_index / columns) * cell.y) + Vector2i.ONE * CELL_GUTTER
			color_page.blit_rect(color, Rect2i(Vector2i.ZERO, _canvas), at)
			depth_page.blit_rect(depth, Rect2i(Vector2i.ZERO, _canvas), at)
		var page_index := start / page_capacity
		var color_texture := _save_texture(color_page, output.path_join("%s_color_%02d.res" % [prefix, page_index]))
		var depth_texture := _save_texture(depth_page, output.path_join("%s_depth_%02d.res" % [prefix, page_index]))
		for local_index in range(count):
			var at := Vector2i((local_index % columns) * cell.x, (local_index / columns) * cell.y) + Vector2i.ONE * CELL_GUTTER
			var color_atlas := AtlasTexture.new()
			color_atlas.atlas = color_texture
			color_atlas.region = Rect2(Vector2(at), Vector2(_canvas))
			var depth_atlas := AtlasTexture.new()
			depth_atlas.atlas = depth_texture
			depth_atlas.region = color_atlas.region
			var clip: String = entries[start + local_index].clip
			result.colors.add_frame(clip, color_atlas)
			result.depths.add_frame(clip, depth_atlas)
		_pages += 1
	for clip in result.colors.get_animation_names(): assert(result.validate_clip(clip).is_empty())
	return result
func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3, "Pass upper manifest, body manifest, and output directory")
	var upper := _read_manifest(args[0])
	var lower := _read_manifest(args[1])
	_canvas = Vector2i(upper.canvas_px[0], upper.canvas_px[1])
	_pivot = Vector2(upper.pivot_px[0], upper.pivot_px[1])
	assert(lower.canvas_px == upper.canvas_px and lower.pivot_px == upper.pivot_px)
	assert(DirAccess.make_dir_recursive_absolute(args[2]) == OK)
	_scan(upper)
	_scan(lower)
	assert(is_finite(_near) and is_finite(_far))
	_near -= 0.05
	_far += 0.05
	var up := _build(upper, "upper", args[2])
	var down := _build(lower, "body", args[2])
	assert(ResourceSaver.save(up, args[2].path_join("upper_poses.tres")) == OK)
	assert(ResourceSaver.save(down, args[2].path_join("body_poses.tres")) == OK)
	print("ARCHER_ATLASES: ",_pages," paired pages; ",_bytes," raw texture bytes; common Z ",_near,"..",_far)
	quit()
