@static_unload
class_name VfxAtlasRenderer
extends RefCounted
## Stateless animation sampling from the caller's clock. No nodes, timers, RNG,
## combat references, or cached actors. Separate boss budget preserves warnings.
static var library: VfxAtlasLibrary = preload("res://resources/feedback/atlas/library.tres")
static var _frame: int = -1
static var _player_draws: int = 0
static var _boss_draws: int = 0

static func _reserve(boss: bool) -> bool:
	var frame := Engine.get_process_frames()
	if _frame != frame:
		_frame = frame
		_player_draws = 0
		_boss_draws = 0
	if boss:
		if _boss_draws >= maxi(1, library.boss_quad_budget): return false
		_boss_draws += 1
	else:
		if _player_draws >= maxi(1, library.player_quad_budget): return false
		_player_draws += 1
	return true

static func available(key: StringName) -> bool:
	return library != null and library.enabled and library.find_clip(key) != null

static func draw_clip(canvas: CanvasItem, key: StringName, time: float, rect: Rect2, tint: Color = Color.WHITE, boss: bool = false, normalized: bool = false) -> bool:
	if not available(key): return false
	var clip := library.find_clip(key)
	if not normalized and not clip.loop and time >= clip.frames / clip.fps: return true
	if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0: return true
	if not _reserve(boss): return true
	var size := rect.size * clampf(clip.size_multiplier, 0.1, 4.0)
	var destination := Rect2(rect.get_center() - size * 0.5, size)
	tint.a *= clampf(clip.opacity, 0.0, 1.0)
	canvas.draw_texture_rect_region(clip.texture, destination, clip.source_rect(time, normalized), tint, false, true)
	return true

static func draw_ring(canvas: CanvasItem, key: StringName, time: float, radius: float, width: float, tint: Color = Color.WHITE, boss: bool = true) -> bool:
	if not available(key): return false
	if not is_finite(radius) or not is_finite(width) or radius <= 0.0 or width <= 0.0: return true
	if not _reserve(boss): return true
	var clip := library.find_clip(key)
	var src := clip.source_rect(time)
	var atlas_size := clip.texture.get_size()
	var segments := clampi(library.ring_segments, 16, 256)
	var repeat_span := maxf(8.0, library.ring_texture_repeat_length)
	var repeat_count := TAU * radius / repeat_span
	var repeats := clampi(ceili(repeat_count), 1, 128)
	var per_repeat := maxi(1, ceili(float(segments) / repeats))
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var inner := maxf(0.0, radius - width * 0.5)
	var outer := radius + width * 0.5
	# Split exactly at texture-repeat boundaries, then tessellate each repeat.
	# One mesh / draw call, rather than one entire texture and call per segment.
	for repeat_index in range(repeats):
		for segment in range(per_repeat):
			var end_u := minf(1.0, repeat_count - repeat_index)
			var u0 := float(segment) / per_repeat * end_u
			var u1 := float(segment + 1) / per_repeat * end_u
			var a := TAU * (repeat_index + u0) / repeat_count
			var b := TAU * (repeat_index + u1) / repeat_count
			var points := [Vector2.from_angle(a)*inner, Vector2.from_angle(b)*inner, Vector2.from_angle(b)*outer, Vector2.from_angle(a)*outer]
			var tex := [Vector2(u0,0),Vector2(u1,0),Vector2(u1,1),Vector2(u0,1)]
			for corner in [0,1,2,0,2,3]:
				vertices.append(Vector3(points[corner].x, points[corner].y, 0))
				uvs.append((src.position + tex[corner] * src.size) / atlas_size)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	tint.a *= clampf(clip.opacity, 0.0, 1.0)
	# Canvas draw commands retain an RID, not the RefCounted mesh. Keep the
	# current mesh on its owning canvas until its next redraw or node disposal.
	var mesh_frame := Engine.get_process_frames()
	if int(canvas.get_meta(&"vfx_ring_mesh_frame", -1)) != mesh_frame:
		canvas.set_meta(&"vfx_ring_mesh_frame", mesh_frame)
		canvas.set_meta(&"vfx_ring_meshes", [])
	var retained: Array = canvas.get_meta(&"vfx_ring_meshes")
	retained.append(mesh)
	canvas.draw_mesh(mesh, clip.texture, Transform2D.IDENTITY, tint)
	return true

static func setting(key: StringName) -> float:
	# Return a primitive to avoid retaining inherited actor script dependencies
	# through direct static Resource property access in Godot 4.6.
	if library == null: return 0.0
	var value: Variant = library.get(key)
	return maxf(0.0, float(value)) if (value is float or value is int) and is_finite(float(value)) else 0.0

static func color_setting(key: StringName, fallback: Color = Color.WHITE) -> Color:
	if library == null: return fallback
	var value: Variant = library.get(key)
	if value is Color and is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a): return value
	return fallback
