class_name ArenaFollowCamera
extends Camera2D
## Presentation only: world bounds, movement, targeting and damage stay unchanged.
## Explicit centre clamping also supports test arenas smaller than the viewport.
var target: Node2D
var world_bounds := Rect2(0, 0, 1280, 800)
## Decorative overscan only. Never forwarded to movement, AI or projectiles.
var edge_padding: float = 64.0

func _ready() -> void:
	# Physics finishes first; then update canvas BEFORE GravityField's idle
	# capture-rectangle sync (priority 0). This remains active during pause or
	# window resizing without advancing any gameplay state.
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	ignore_rotation = true
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	offset = Vector2.ZERO
	make_current()
	sync_now()

func configure(follow_target: Node2D, bounds: Rect2, magnification: float, padding: float = 64.0) -> void:
	target = follow_target
	world_bounds = bounds
	edge_padding = clampf(padding, 0.0, 96.0) if is_finite(padding) else 64.0
	set_magnification(magnification)

func set_magnification(value: float) -> void:
	var safe_value := clampf(value, 1.0, 3.0) if is_finite(value) else 2.0
	zoom = Vector2.ONE * safe_value
	if is_inside_tree(): sync_now()

static func clamped_center(wanted: Vector2, bounds: Rect2, visible_size: Vector2) -> Vector2:
	var half_visible := visible_size * 0.5
	var center := bounds.get_center()
	if bounds.size.x > visible_size.x:
		center.x = clampf(wanted.x, bounds.position.x + half_visible.x, bounds.end.x - half_visible.x)
	if bounds.size.y > visible_size.y:
		center.y = clampf(wanted.y, bounds.position.y + half_visible.y, bounds.end.y - half_visible.y)
	return center

func sync_now() -> void:
	if not is_inside_tree(): return
	var wanted := target.global_position if is_instance_valid(target) else world_bounds.get_center()
	var visible_size := get_viewport_rect().size / zoom
	global_position = clamped_center(wanted, presentation_bounds(), visible_size)
	# Force the canvas update now, not at a later internal camera callback.
	force_update_scroll()

func presentation_bounds() -> Rect2:
	return world_bounds.grow(edge_padding)

func visible_world_rect() -> Rect2:
	var size := get_viewport_rect().size / zoom
	return Rect2(global_position - size * 0.5, size)

func _process(_delta: float) -> void:
	sync_now()
