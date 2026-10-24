class_name GravityField
extends Node2D
## Arrow-tip effect; enemy physics owns movement and queries membership directly.
var outer_radius: float
var inner_radius: float
var pull_acceleration: float
var pull_speed_cap: float
var pull_damping: float
var contact_grace: float
var damage_per_second: float
var tick_interval: float
var enemies: Node2D
var damage_callback: Callable
var active := true
var age := 0.0
var exposure: Dictionary = {}
var _matter_surface: DarkMatterSurface
var _distortion_pass: Node2D
var _background_copy: BackBufferCopy
var _last_capture_transform := Transform2D.IDENTITY
var _capture_transform_valid := false

class DarkMatterSurface extends Node2D:
	var radius: float = 0.0
	func _draw() -> void:
		if radius > 0.0:
			draw_rect(Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2.0), Color.WHITE)


func _ready() -> void:
	# Lifetime belongs to this arrow, but rendering belongs before arena actors.
	# Each pass copies only its padded local rectangle immediately before its
	# surface; multiple fields never rely on an implicit full-viewport copy.
	_distortion_pass = Node2D.new()
	_distortion_pass.name = "DarkGroundRefraction"
	var ground_host: Node = self
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is RageArena:
			ground_host = ancestor.ground_distortions
			break
		ancestor = ancestor.get_parent()
	ground_host.add_child(_distortion_pass)
	_background_copy = BackBufferCopy.new()
	_background_copy.name = "LocalGroundCopy"
	_background_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	_distortion_pass.add_child(_background_copy)
	_matter_surface = DarkMatterSurface.new()
	_matter_surface.name = "DarkMaterialSurface"
	var surface_material := ShaderMaterial.new()
	surface_material.shader = preload("res://shaders/dark_field_material.gdshader")
	_matter_surface.material = surface_material
	_distortion_pass.add_child(_matter_surface)
	# This callback updates render transforms only, even while game simulation
	# is paused. It never advances field age, exposure, forces or damage.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_notify_transform(true)
	_sync_matter_surface()

func _process(_delta: float) -> void:
	if not active or not is_instance_valid(_background_copy): return
	var to_screen := get_viewport().get_stretch_transform() * get_global_transform_with_canvas()
	if not _capture_transform_valid or not to_screen.is_equal_approx(_last_capture_transform):
		_sync_capture_rect()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_sync_distortion_transform()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		_sync_matter_surface()

func _sync_distortion_transform() -> void:
	if is_instance_valid(_distortion_pass) and is_inside_tree():
		_distortion_pass.global_transform = global_transform
		_sync_capture_rect()

func is_active() -> bool:
	return active and is_inside_tree() and not is_queued_for_deletion()

func configure(stats: CombatStats, container: Node2D, callback: Callable) -> void:
	var config := stats.element_skill.gravity
	outer_radius = stats.gravity_outer_radius
	inner_radius = stats.gravity_inner_radius
	pull_acceleration = stats.gravity_acceleration
	pull_speed_cap = config.pull_speed_cap
	pull_damping = config.pull_damping
	contact_grace = config.contact_grace
	damage_per_second = stats.gravity_dps
	tick_interval = config.tick_interval
	enemies = container
	damage_callback = callback

func attach_enemy(enemy: EnemyActor) -> void:
	if is_active(): enemy.gravity_source = self

func tick(delta: float, previous_tip: Vector2 = Vector2.INF) -> void:
	if not is_active(): return
	age += delta
	if previous_tip == Vector2.INF: previous_tip = global_position
	var live: Dictionary = {}
	for enemy: EnemyActor in enemies.get_children():
		if enemy.is_dead: continue
		attach_enemy(enemy)
		var id := enemy.get_instance_id()
		live[id] = true
		var in_core_time := maxf(0.0, delta) * _inside_fraction(previous_tip, global_position, enemy.global_position)
		var elapsed := float(exposure.get(id, 0.0)) + in_core_time
		# Carry partial exposure through exits. Pay only quanta earned during
		# an in-core part of this step, even if the tip has since passed by.
		# Batch quanta into one packet to bound stalled-frame work.
		if in_core_time > 0.0:
			var ticks := floori((elapsed + 0.000001) / tick_interval)
			if ticks > 0:
				elapsed = maxf(0.0, elapsed - ticks * tick_interval)
				if damage_callback.is_valid(): damage_callback.call(enemy, damage_per_second * tick_interval * ticks, "dark")
		exposure[id] = elapsed

	for id in exposure.keys():
		if not live.has(id): exposure.erase(id)
	queue_redraw()

func deactivate(reset_grace: bool = false) -> void:
	if not active: return
	# Release while the source is still valid so the enemy can capture grace.
	if is_instance_valid(enemies):
		for enemy: EnemyActor in enemies.get_children():
			if enemy.gravity_source == self: enemy.clear_gravity(reset_grace)
	active = false
	if is_instance_valid(_distortion_pass): _distortion_pass.visible = false
	if is_instance_valid(_background_copy): _background_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	if is_instance_valid(_matter_surface): _matter_surface.visible = false
	exposure.clear()

func _exit_tree() -> void:
	deactivate()
	# The ground-layer sibling has no back-reference to the field. Free it now,
	# including both capture and surface, on retire/reset/arena replacement.
	if is_instance_valid(_distortion_pass) and _distortion_pass.get_parent() != self:
		_distortion_pass.free()
	_distortion_pass = null
	_background_copy = null
	_matter_surface = null

func _draw() -> void:
	_sync_matter_surface()

func _sync_matter_surface() -> void:
	if not is_instance_valid(_matter_surface): return
	_sync_distortion_transform()
	var draw_active := active and is_visible_in_tree() and outer_radius > 0.0
	_distortion_pass.visible = draw_active
	_matter_surface.visible = draw_active
	_background_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT if draw_active else BackBufferCopy.COPY_MODE_DISABLED
	_matter_surface.radius = maxf(0.0, outer_radius)
	var pull := clampf(VfxAtlasRenderer.setting(&"dark_refraction_pull"), 0.0, 24.0)
	var swirl := clampf(VfxAtlasRenderer.setting(&"dark_refraction_swirl"), 0.0, 12.0)
	var surface_material := _matter_surface.material as ShaderMaterial
	surface_material.set_shader_parameter("outer_radius", maxf(1.0, outer_radius))
	surface_material.set_shader_parameter("phase", age * clampf(VfxAtlasRenderer.setting(&"dark_refraction_frequency"), 0.0, 2.0))
	surface_material.set_shader_parameter("pull_pixels", pull)
	surface_material.set_shader_parameter("swirl_pixels", swirl)
	surface_material.set_shader_parameter("body_opacity", clampf(VfxAtlasRenderer.setting(&"dark_body_opacity"), 0.0, 1.0))
	surface_material.set_shader_parameter("body_extent", clampf(VfxAtlasRenderer.setting(&"dark_body_extent"), 0.3, 1.0))
	surface_material.set_shader_parameter("body_scale", clampf(VfxAtlasRenderer.setting(&"dark_body_scale"), 2.0, 12.0))
	surface_material.set_shader_parameter("body_shear", clampf(VfxAtlasRenderer.setting(&"dark_body_shear"), 0.0, 6.0))
	surface_material.set_shader_parameter("body_phase", age * clampf(VfxAtlasRenderer.setting(&"dark_body_flow_speed"), 0.0, 3.0))
	surface_material.set_shader_parameter("body_mid_color", VfxAtlasRenderer.color_setting(&"dark_body_mid_color"))
	surface_material.set_shader_parameter("body_edge_color", VfxAtlasRenderer.color_setting(&"dark_body_edge_color"))
	_matter_surface.queue_redraw()

func _sync_capture_rect() -> void:
	if not is_instance_valid(_background_copy): return
	var pull := clampf(VfxAtlasRenderer.setting(&"dark_refraction_pull"), 0.0, 24.0)
	var swirl := clampf(VfxAtlasRenderer.setting(&"dark_refraction_swirl"), 0.0, 12.0)
	var local_rect := Rect2(Vector2.ONE * -outer_radius, Vector2.ONE * outer_radius * 2.0).grow(Vector2(pull, swirl).length())
	# Godot 4.6 Compatibility reads rect in render-target pixels, NOT in the
	# BackBufferCopy's transformed local coordinates. Supply the transformed
	# AABB explicitly, then add a true two-screen-pixel bilinear guard.
	var to_screen := get_viewport().get_stretch_transform() * get_global_transform_with_canvas()
	_last_capture_transform = to_screen
	_capture_transform_valid = true
	var screen_rect: Rect2 = to_screen * local_rect
	screen_rect = screen_rect.grow(2.0)
	var start := screen_rect.position.floor()
	_background_copy.rect = Rect2(start, screen_rect.end.ceil() - start)

func _inside_fraction(start: Vector2, end: Vector2, center: Vector2) -> float:
	var travel := end - start
	var length_squared := travel.length_squared()
	if length_squared <= 0.000001:
		return 1.0 if center.distance_squared_to(end) <= inner_radius * inner_radius else 0.0
	var relative := start - center
	var b := 2.0 * relative.dot(travel)
	var c := relative.length_squared() - inner_radius * inner_radius
	var discriminant := b * b - 4.0 * length_squared * c
	if discriminant < 0.0: return 0.0
	var root := sqrt(discriminant)
	var entry := clampf((-b-root)/(2.0*length_squared), 0.0, 1.0)
	var exit := clampf((-b+root)/(2.0*length_squared), 0.0, 1.0)
	return maxf(0.0, exit-entry)
