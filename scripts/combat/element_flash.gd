class_name ElementFlash
extends Node2D
## Actual gameplay endpoints are supplied by proc dispatch. Cosmetic geometry
## never selects a target, changes blast radius, or recursively creates damage.
var definition: ElementVisualDefinition = preload("res://resources/feedback/element_visuals.tres")
var radius: float = 60.0
var kind: String = "blast"
var points := PackedVector2Array()
var color: Color = Color("ff9958")
var duration: float = 0.25
var remaining: float = 0.25
var lightning: LightningRibbon
var _atlas_impacts: Node2D
static var _cosmetic_serial: int = 0
var _blast_rotation: float = 0.0
var _blast_scale: float = 1.0
var _blast_time_power: float = 1.0

class ChainAtlasImpacts extends Node2D:
	var endpoints := PackedVector2Array()
	var progress: float = 0.0
	var reveal_fraction: float = 0.4
	var radius: float = 24.0
	func _draw() -> void:
		for hop in range(1, endpoints.size()):
			var delay := float(hop - 1) / maxi(1, endpoints.size() - 1) * reveal_fraction
			var age := (progress - delay) / maxf(0.01, 1.0 - delay)
			if age < 0.0: continue
			VfxAtlasRenderer.draw_clip(self, &"lightning_impact", age, Rect2(endpoints[hop] - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), Color.WHITE, false, true)

func _ready() -> void:
	definition = definition.validated_copy()
	if kind == "blast" and points.size() <= 1:
		# Cosmetic serial never consumes the combat random stream.
		_cosmetic_serial = (_cosmetic_serial + 1) % 1000000
		var phase := fposmod(float(_cosmetic_serial) * 0.61803398875, 1.0)
		_blast_rotation = deg_to_rad(definition.fire_explosion_rotation_degrees) * phase
		_blast_scale = 1.0 - clampf(definition.fire_explosion_size_variation, 0.0, 1.0) * fposmod(phase * 3.7, 1.0)
		_blast_time_power = 1.0 + clampf(definition.fire_explosion_timing_variation, 0.0, 0.5) * (phase * 2.0 - 1.0)

func _prepare_lightning() -> void:
	if lightning == null and points.size() > 1:
		lightning = LightningRibbon.new()
		lightning.build(points, definition)
		var additive := CanvasItemMaterial.new()
		additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = additive

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	remaining = maxf(0.0, remaining - delta)
	if points.size() > 1 and VfxAtlasRenderer.available(&"lightning_impact"):
		if _atlas_impacts == null:
			_atlas_impacts = ChainAtlasImpacts.new()
			var normal := CanvasItemMaterial.new()
			normal.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
			_atlas_impacts.material = normal
			add_child(_atlas_impacts)
		_atlas_impacts.visible = presentation_priority() < definition.lightning_detail_limit
		_atlas_impacts.endpoints = points
		_atlas_impacts.progress = 1.0 - remaining / maxf(0.001, duration)
		_atlas_impacts.reveal_fraction = definition.chain_reveal_fraction
		_atlas_impacts.radius = definition.bolt_endpoint_radius * 6.0
		_atlas_impacts.queue_redraw()
	modulate.a = 1.0 if lightning != null or VfxAtlasRenderer.available(&"fire_explosion") else remaining / maxf(0.001, duration)
	queue_redraw()
	if remaining <= 0.0: queue_free()

func _draw() -> void:
	var progress := clampf(1.0 - remaining / maxf(0.001, duration), 0.0, 1.0)
	if points.size() > 1:
		_draw_chain(progress)
		return
	if kind == "chain": return
	draw_set_transform(Vector2.ZERO, _blast_rotation, Vector2.ONE * _blast_scale)
	var drew_atlas := VfxAtlasRenderer.draw_clip(self, &"fire_explosion", pow(progress, _blast_time_power), Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color(1,1,1,definition.fire_explosion_opacity), false, true)
	draw_set_transform(Vector2.ZERO)
	if drew_atlas: return
	# Atlas-off fallback stays compact and asymmetric. No flat blast disk, rim,
	# radial star, or geometry that implies a larger gameplay damage radius.
	var expansion := 1.0 - exp(-progress * 15.0)
	var fade := pow(1.0 - progress, 1.7)
	for i in range(definition.fire_sparks):
		var angle := float(i) * 2.399963
		var travel := radius * expansion * (0.14 + 0.035 * float(i % 5))
		var base := Vector2.from_angle(angle) * travel
		var height := radius * (0.17 + 0.025 * float(i % 3)) * expansion
		var curl := sin(float(i * 7) + progress * 4.0) * height * .24
		var half_width := height * .18
		var tongue := PackedVector2Array([base + Vector2(-half_width,0),base + Vector2(-half_width*.8,-height*.42),base + Vector2(curl,-height),base + Vector2(half_width*.45,-height*.38),base + Vector2(half_width,0)])
		draw_colored_polygon(tongue, Color(color, fade * definition.fire_fallback_ember_opacity))
		if progress < .28:
			draw_line(base, base + Vector2(curl*.25,-height*.35), Color(definition.fire_core_color, (1.0-progress/.28)*definition.fire_burst_opacity), maxf(.6,half_width*.5), true)

func _draw_chain(progress: float) -> void:
	# Presentation saturation never suppresses a combat proc: damage has already
	# resolved independently. Prefer recent chains and omit overlapping old arcs.
	var recent_index := presentation_priority()
	if recent_index >= definition.lightning_visual_limit: return
	_prepare_lightning()
	if lightning != null: lightning.draw(self, progress, definition, recent_index < definition.lightning_detail_limit)

func presentation_priority() -> int:
	return get_parent().get_child_count() - get_index() - 1 if get_parent() != null else 0
