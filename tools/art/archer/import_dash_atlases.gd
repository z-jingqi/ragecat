extends SceneTree
## Offline, deterministic trimmed-atlas importer for authored dash poses.
## godot --headless --path PROJECT --script THIS -- MANIFEST_JSON OUTPUT_DIR MOTION_TRES
const GUTTER := 2
const MAX_PAGE := 2048
var _data: Dictionary
var _canvas := Vector2i.ZERO
var _pivot := Vector2.ZERO
var _source_dir := ""
var _output := ""
var _raw_bytes := 0
var _edge_pixels := 0

func _initialize() -> void: call_deferred("run")

func _source(path: String) -> String:
	return path if path.is_absolute_path() else _source_dir.path_join(path)

func _depth_pixels(depth: Image, color: Image) -> Image:
	depth.convert(Image.FORMAT_RF)
	var values := depth.get_data().to_float32_array()
	var rgba := color.get_data()
	var packed := PackedByteArray()
	packed.resize(values.size() * 2)
	var span: float = _data.depth_far - _data.depth_near
	assert(span > 0.0)
	for index in values.size():
		var z := values[index]
		if rgba[index * 4 + 3] > 0 and (not is_finite(z) or z <= 0 or z >= 20):
			# Repair only AA-covered background Z, using the nearest real surface.
			# Search rings, stopping once no outside pixel can be nearer.
			var x := index % _canvas.x
			var y := index / _canvas.x
			var best := INF
			var best_z := INF
			for radius in range(1, maxi(_canvas.x, _canvas.y)):
				for dy in range(-radius, radius + 1):
					for dx in range(-radius, radius + 1):
						if absi(dx) != radius and absi(dy) != radius: continue
						var px := x + dx
						var py := y + dy
						if px < 0 or py < 0 or px >= _canvas.x or py >= _canvas.y: continue
						var source_index := py * _canvas.x + px
						var candidate := values[source_index]
						var distance := dx * dx + dy * dy
						if rgba[source_index * 4 + 3] > 0 and is_finite(candidate) and candidate > 0 and candidate < 20 and distance < best:
							best = distance
							best_z = candidate
				if best <= radius * radius: break
			assert(is_finite(best_z), "No surface depth for alpha-covered edge")
			z = best_z
			_edge_pixels += 1
		if rgba[index * 4 + 3] > 0:
			assert(z >= _data.depth_near and z <= _data.depth_far, "Dash Z outside shared layer range")
		var normalized := clampf((z - _data.depth_near) / span, 0.0, 1.0) if is_finite(z) else 1.0
		var encoded := int(round(normalized * 65535.0))
		packed[index * 2] = (encoded >> 8) & 255
		packed[index * 2 + 1] = encoded & 255
	return Image.create_from_data(_canvas.x, _canvas.y, false, Image.FORMAT_RG8, packed)

func _save_texture(pixels: Image, path: String) -> Texture2D:
	var texture := ImageTexture.create_from_image(pixels)
	texture.take_over_path(path)
	assert(ResourceSaver.save(texture, path, ResourceSaver.FLAG_COMPRESS) == OK)
	_raw_bytes += pixels.get_data_size()
	return texture

func _build_library(role: String) -> ArcherPoseLibrary:
	var library := ArcherPoseLibrary.new()
	library.canvas_size = _canvas
	library.pivot = _pivot
	library.packed_depth = true
	library.colors = SpriteFrames.new()
	library.depths = SpriteFrames.new()
	library.colors.remove_animation("default")
	library.depths.remove_animation("default")
	var entries: Array[Dictionary] = []
	var names: Array = _data.clips.keys()
	names.sort()
	for clip in names:
		var definition: Dictionary = _data.clips[clip]
		if definition.role != role and not (role == "guard" and definition.role == "guard_move"): continue
		library.colors.add_animation(clip)
		library.depths.add_animation(clip)
		for index in definition.frames.size():
			var frame: Dictionary = definition.frames[index]
			var color := Image.load_from_file(_source(frame.color))
			assert(color != null and color.get_size() == _canvas)
			color.convert(Image.FORMAT_RGBA8)
			var used := color.get_used_rect()
			assert(used.has_area(), "Empty authored dash frame")
			assert(used.position.x > 0 and used.position.y > 0 and used.end.x < _canvas.x and used.end.y < _canvas.y, "Clipped authored silhouette")
			var box := used.grow(GUTTER).intersection(Rect2i(Vector2i.ZERO, _canvas))
			entries.append({"clip":clip,"index":index,"frame":frame,"box":box})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.box.size.y != b.box.size.y: return a.box.size.y > b.box.size.y
		if a.box.size.x != b.box.size.x: return a.box.size.x > b.box.size.x
		if a.clip != b.clip: return str(a.clip) < str(b.clip)
		return a.index < b.index)
	var pages: Array[Dictionary] = []
	var page: Dictionary = {"entries":[],"width":0,"height":0}
	var x := 0
	var y := 0
	var row_height := 0
	for entry in entries:
		var cell: Vector2i = entry.box.size + Vector2i.ONE * GUTTER * 2
		if x + cell.x > MAX_PAGE:
			x = 0
			y += row_height
			row_height = 0
		if y + cell.y > MAX_PAGE:
			pages.append(page)
			page = {"entries":[],"width":0,"height":0}
			x = 0
			y = 0
			row_height = 0
		entry["at"] = Vector2i(x + GUTTER, y + GUTTER)
		page.entries.append(entry)
		x += cell.x
		row_height = maxi(row_height, cell.y)
		page.width = maxi(page.width, x)
		page.height = maxi(page.height, y + row_height)
	if not page.entries.is_empty(): pages.append(page)
	var mapped: Dictionary = {}
	for page_index in pages.size():
		page = pages[page_index]
		var colors := Image.create(page.width, page.height, false, Image.FORMAT_RGBA8)
		var depths := Image.create(page.width, page.height, false, Image.FORMAT_RG8)
		colors.fill(Color.TRANSPARENT)
		depths.fill(Color.WHITE)
		for entry in page.entries:
			var color := Image.load_from_file(_source(entry.frame.color))
			color.convert(Image.FORMAT_RGBA8)
			var z := Image.load_from_file(_source(entry.frame.depth))
			assert(z != null and z.get_size() == _canvas)
			var depth := _depth_pixels(z, color)
			colors.blit_rect(color, entry.box, entry.at)
			depths.blit_rect(depth, entry.box, entry.at)
		var color_texture := _save_texture(colors, _output.path_join("%s_color_%02d.res" % [role, page_index]))
		var depth_texture := _save_texture(depths, _output.path_join("%s_depth_%02d.res" % [role, page_index]))
		for entry in page.entries:
			var color := AtlasTexture.new()
			color.atlas = color_texture
			color.region = Rect2(Vector2(entry.at), Vector2(entry.box.size))
			color.margin = Rect2(Vector2(entry.box.position), Vector2(_canvas - entry.box.size))
			color.filter_clip = true
			var depth := AtlasTexture.new()
			depth.atlas = depth_texture
			depth.region = color.region
			depth.margin = color.margin
			depth.filter_clip = true
			mapped[str(entry.clip) + ":" + str(entry.index)] = [color,depth]
	for clip in names:
		if not library.colors.has_animation(clip): continue
		var definition: Dictionary = _data.clips[clip]
		if definition.role == "guard_move":
			var source_clip: String = definition.base_clip
			for index in range(int(definition.base_frame_count)):
				var pair: Array = mapped[source_clip + ":" + str(index)]
				library.colors.add_frame(clip,pair[0])
				library.depths.add_frame(clip,pair[1])
		for index in definition.frames.size():
			var pair: Array = mapped[str(clip) + ":" + str(index)]
			library.colors.add_frame(clip,pair[0])
			library.depths.add_frame(clip,pair[1])
		assert(library.validate_clip(clip).is_empty())
	var path := _output.path_join("dash_" + role + ".tres")
	library.take_over_path(path)
	assert(ResourceSaver.save(library,path) == OK)
	assert(library.resource_path == path)
	print("DASH ATLAS ",role,": ",entries.size()," unique frames; ",pages.size()," pages")
	return library

func run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 3,"Pass manifest, atlas output directory, and motion resource path")
	_data = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	_source_dir = args[0].get_base_dir()
	_canvas = Vector2i(_data.canvas_px[0],_data.canvas_px[1])
	_pivot = Vector2(_data.pivot_px[0],_data.pivot_px[1])
	_output = args[1]
	assert(DirAccess.make_dir_recursive_absolute(_output) == OK)
	var motion := ArcherDashMotionDefinition.new()
	motion.normalized_times = PackedFloat32Array(_data.normalized_times)
	motion.body = _build_library("body")
	motion.guard = _build_library("guard")
	for clip in _data.clips:
		var definition: Dictionary = _data.clips[clip]
		var bobs := PackedVector2Array()
		if definition.role == "guard_move":
			for index in range(int(definition.base_frame_count)):
				var bob: Array = _data.clips[definition.base_clip].frames[index].bob
				bobs.append(Vector2(bob[0],bob[1]))
			motion.guard_move_distances[StringName(clip)] = definition.recovery_distance
			motion.guard_move_exit_phases[StringName(clip)] = definition.exit_phase
		for frame in definition.frames: bobs.append(Vector2(frame.bob[0],frame.bob[1]))
		motion.bobs[StringName(clip)] = bobs
		if definition.has("entry_phase"): motion.gait_entry_phases[StringName(clip)] = definition.entry_phase
	motion.take_over_path(args[2])
	assert(ResourceSaver.save(motion,args[2]) == OK)
	assert(motion.resource_path == args[2])
	print("DASH IMPORT COMPLETE: ",_raw_bytes," raw bytes; ",_edge_pixels," repaired depth-only AA pixels")
	quit()
