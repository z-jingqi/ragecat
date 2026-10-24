class_name LightningRibbon
extends RefCounted
## Cached, tapered textured ribbons. Compatibility-safe additive light, no bloom.
static var texture_cache: Dictionary = {}
var ribbon_texture: ImageTexture
static var halo_texture: ImageTexture
var meshes: Array[ArrayMesh] = []
var endpoints := PackedVector2Array()

func prepare_textures(settings: ElementVisualDefinition) -> void:
	var key := str([settings.bolt_corona_color, settings.bolt_sheath_color, settings.bolt_core_width, settings.bolt_glow_width])
	if texture_cache.has(key):
		ribbon_texture = texture_cache[key]
		return
	var ribbon := Image.create(8, 128, false, Image.FORMAT_RGBA8)
	for y in range(128):
		var distance := absf((float(y) + 0.5) / 128.0 * 2.0 - 1.0)
		var corona := exp(-distance * distance * 14.0)
		var hot := exp(-distance * distance * pow(settings.bolt_glow_width / maxf(0.5, settings.bolt_core_width), 2.0) * 4.0)
		var tint := settings.bolt_sheath_color.lerp(settings.bolt_corona_color, corona).lerp(Color("effaff"), hot)
		tint.a = corona * 0.64 + hot * 0.36
		for x in range(8): ribbon.set_pixel(x, y, tint)
	ribbon_texture = ImageTexture.create_from_image(ribbon)
	if texture_cache.size() >= 8: texture_cache.clear()
	texture_cache[key] = ribbon_texture
	var halo := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var distance := Vector2(x - 31.5, y - 31.5).length() / 32.0
			halo.set_pixel(x, y, Color(0.25, 0.45, 1.0, exp(-distance * distance * 7.0) * maxf(0.0, 1.0 - distance)))
	halo_texture = ImageTexture.create_from_image(halo)

func build(points: PackedVector2Array, settings: ElementVisualDefinition) -> void:
	prepare_textures(settings)
	endpoints = points.duplicate()
	meshes.clear()
	for hop in range(points.size() - 1):
		var vertices := PackedVector3Array()
		var uvs := PackedVector2Array()
		var colors := PackedColorArray()
		var path := ElementGeometry.bolt(points[hop], points[hop + 1], settings, hop + 17)
		_append_ribbon(path, settings.bolt_glow_width, 1.0, vertices, uvs, colors)
		for branch in range(settings.bolt_branches):
			var index := clampi(3 + branch * 4, 1, path.size() - 2)
			var axis := (path[index + 1] - path[index]).normalized().rotated((-0.8 if branch % 2 == 0 else 0.9))
			var length := minf(settings.bolt_branch_length, points[hop].distance_to(points[hop + 1]) * 0.24)
			var twig := PackedVector2Array([path[index], path[index] + axis * length * 0.42, path[index] + axis * length * 0.7 + axis.orthogonal() * 1.5, path[index] + axis * length])
			_append_ribbon(twig, settings.bolt_glow_width * 0.32, 0.32, vertices, uvs, colors, true)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		if not vertices.is_empty(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes.append(mesh)

func _append_ribbon(path: PackedVector2Array, width: float, alpha: float, vertices: PackedVector3Array, uvs: PackedVector2Array, colors: PackedColorArray, twig: bool = false) -> void:
	for i in range(path.size() - 1):
		var axis := (path[i + 1] - path[i]).normalized().orthogonal()
		var t := float(i) / maxf(1.0, path.size() - 1)
		var next_t := float(i + 1) / maxf(1.0, path.size() - 1)
		var w0 := width * (lerpf(1.0, 0.12, t) if twig else (0.45 + sin(t * PI) * 0.55))
		var w1 := width * (lerpf(1.0, 0.12, next_t) if twig else (0.45 + sin(next_t * PI) * 0.55))
		var start_normal := axis
		var end_normal := axis
		if i > 0:
			start_normal = ((path[i] - path[i - 1]).normalized().orthogonal() + axis).normalized()
			start_normal /= maxf(0.5, start_normal.dot(axis))
		if i + 2 < path.size():
			end_normal = ((path[i + 2] - path[i + 1]).normalized().orthogonal() + axis).normalized()
			end_normal /= maxf(0.5, end_normal.dot(axis))
		var quad := [path[i] - start_normal * w0, path[i] + start_normal * w0, path[i + 1] - end_normal * w1, path[i + 1] + end_normal * w1]
		var tex := [Vector2(0, 0), Vector2(0, 1), Vector2(1, 0), Vector2(1, 1)]
		for corner in [0, 1, 2, 2, 1, 3]:
			vertices.append(Vector3(quad[corner].x, quad[corner].y, 0))
			uvs.append(tex[corner])
			colors.append(Color(1, 1, 1, alpha))

func draw(canvas: Node2D, progress: float, settings: ElementVisualDefinition, detailed: bool = true) -> void:
	for hop in range(meshes.size()):
		var delay := float(hop) / maxi(1, meshes.size()) * settings.chain_reveal_fraction
		var age := (progress - delay) / maxf(0.01, 1.0 - delay)
		if age < 0.0: continue
		# Initial discharge, a weaker restrike, then a cool filament afterimage.
		var pulse := exp(-age * 8.0) + 0.28 * exp(-pow((age - 0.26) / 0.055, 2.0)) + 0.18 * (1.0 - age)
		canvas.draw_mesh(meshes[hop], ribbon_texture, Transform2D.IDENTITY, Color(1, 1, 1, pulse))
		if not detailed: continue
		var at := endpoints[hop + 1]
		var flash := exp(-age * 12.0)
		var halo_size := settings.bolt_endpoint_radius * 4.0
		canvas.draw_texture_rect(halo_texture, Rect2(at - Vector2.ONE * halo_size, Vector2.ONE * halo_size * 2), false, Color(1, 1, 1, flash * 0.35))
		for i in range(settings.bolt_sparks):
			var axis := Vector2.from_angle(float(i) * TAU / settings.bolt_sparks + hop * 1.7)
			var distance := 3.0 + age * (19.0 + sin(float(i * 7)) * 7.0)
			var tip := at + axis * distance
			var tail := at + axis * maxf(1.0, distance - 7.0 * (1.0 - age))
			canvas.draw_line(tail, tip, Color(0.62, 0.82, 1.0, pow(1.0 - age, 2.0)), 1.1, true)
		# Small asymmetric endpoint filament, not a repeated four-point star.
		var extent := settings.bolt_endpoint_radius * (0.5 + flash * 0.5)
		canvas.draw_line(at - Vector2(extent, extent * 0.3), at + Vector2(extent * 0.7, -extent * 0.5), Color(0.85, 0.95, 1.0, flash), settings.bolt_core_width, true)
