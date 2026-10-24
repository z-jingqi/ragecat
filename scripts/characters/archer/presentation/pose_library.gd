class_name ArcherPoseLibrary
extends Resource
## Standard Godot SpriteFrames hold matching color/depth atlases.
## Clip names and normalized phases are presentation data, never combat events.
@export var colors: SpriteFrames
@export var depths: SpriteFrames
@export var packed_depth := false
@export var canvas_size := Vector2i(128, 128)
@export var pivot := Vector2(64, 64)

func validate_clip(clip: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if colors == null or not colors.has_animation(clip):
		errors.append("Missing color clip: %s" % clip)
		return errors
	if depths == null or not depths.has_animation(clip):
		errors.append("Missing depth clip: %s" % clip)
		return errors
	var count := colors.get_frame_count(clip)
	if count == 0 or depths.get_frame_count(clip) != count:
		errors.append("Color/depth frame count differs: %s" % clip)
		return errors
	for i in range(count):
		for frames in [colors, depths]:
			var texture: Texture2D = frames.get_frame_texture(clip, i)
			if texture == null or texture.get_size() != Vector2(canvas_size):
				errors.append("Inconsistent fixed canvas: %s[%d]" % [clip, i])
	return errors

func sample(clip: StringName, phase: float, looped: bool = false) -> Dictionary:
	if colors == null or depths == null or not colors.has_animation(clip) or not depths.has_animation(clip): return {}
	var count := colors.get_frame_count(clip)
	if count == 0 or depths.get_frame_count(clip) != count: return {}
	var index := int(floor(fposmod(phase, 1.0) * count)) if looped else int(round(clampf(phase, 0.0, 1.0) * (count - 1)))
	var color := _texture_region(colors.get_frame_texture(clip, index))
	var depth := _texture_region(depths.get_frame_texture(clip, index))
	if color.is_empty() or depth.is_empty(): return {}
	return {"index": index, "color": color, "depth": depth, "packed_depth": packed_depth}

func _texture_region(texture: Texture2D) -> Dictionary:
	if texture == null or texture.get_size() != Vector2(canvas_size): return {}
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas == null: return {}
		var size := atlas.atlas.get_size()
		if size.x <= 0 or size.y <= 0 or atlas.region.size != Vector2(canvas_size): return {}
		if not Rect2(Vector2.ZERO, size).encloses(atlas.region): return {}
		return {"texture": atlas.atlas, "region": Vector4(atlas.region.position.x / size.x,
			atlas.region.position.y / size.y, atlas.region.size.x / size.x, atlas.region.size.y / size.y)}
	return {"texture": texture, "region": Vector4(0, 0, 1, 1)}
