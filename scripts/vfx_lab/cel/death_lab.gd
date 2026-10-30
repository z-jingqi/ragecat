extends "res://scripts/vfx_lab/cel/study_lab.gd"
## Source ownership and intact silhouette live only in this demo host.
const Death = preload("res://scripts/vfx/cel/death.gd")
var source_mode := 0
var source_shapes: Array = []

func _ready() -> void:
	effect_script = Death
	floor_host = false
	super._ready()
	_button("Silhouette [1]",744,64,func(): set_source_mode(0),136)
	_button("Token [2]",895,64,func(): set_source_mode(1),136)
	set_source_mode(0)

func set_source_mode(value: int) -> void:
	source_mode = clampi(value,0,1)
	source_shapes = humanoid_polygons() if source_mode == 0 else token_polygons()
	var accepted: bool = effect.set_source_polygons(source_shapes)
	if not accepted:
		push_error("Death demo source was rejected: %s" % effect.source_error)
	_fit_effect()
	replay()

static func humanoid_polygons() -> Array:
	var body := PackedVector2Array([
		Vector2(-12,-164),Vector2(-35,-158),Vector2(-51,-136),Vector2(-59,-104),Vector2(-74,-85),Vector2(-68,-73),Vector2(-58,-77),Vector2(-44,-95),Vector2(-32,-122),Vector2(-26,-102),Vector2(-29,-76),Vector2(-42,-45),Vector2(-52,-5),Vector2(-31,-5),Vector2(-18,-47),Vector2(-2,-72),Vector2(8,-48),Vector2(21,-5),Vector2(44,-5),Vector2(31,-47),Vector2(23,-78),Vector2(23,-107),Vector2(32,-125),Vector2(43,-100),Vector2(59,-80),Vector2(71,-78),Vector2(76,-91),Vector2(61,-107),Vector2(52,-137),Vector2(34,-159),Vector2(12,-164)
	])
	var head := PackedVector2Array()
	for i in range(28): head.append(Vector2(0,-184)+Vector2(cos(TAU*i/28.0)*17,sin(TAU*i/28.0)*23))
	return [body,head]

static func token_polygons() -> Array:
	return [PackedVector2Array([Vector2(-62,-138),Vector2(-36,-183),Vector2(28,-191),Vector2(66,-142),Vector2(49,-62),Vector2(0,-19),Vector2(-49,-62)])]

func _draw_world() -> void:
	super._draw_world()
	if effect == null or effect_only or elapsed >= 0: return
	var shade: Color = effect.config.source_color
	for polygon in source_shapes:
		var points := PackedVector2Array()
		for point in polygon: points.append(fit_origin+(point*effect.config.size).rotated(deg_to_rad(effect.config.direction_degrees))*fit_scale)
		world.draw_colored_polygon(points,shade)
		var edge: PackedVector2Array = points.duplicate()
		edge.append(edge[0])
		world.draw_polyline(edge,shade,0.8,true)

func _process(delta: float) -> void:
	# Last recorded pass demonstrates the same effect on an unrelated source.
	if not capture_dir.is_empty() and capture_frame == 540 and capture_segment != 2:
		set_source_mode(1)
	super._process(delta)

func _update_view() -> void:
	super._update_view()
	pass_label.text = "SOURCE SNAPSHOT → IVORY FLASH → PEELING FRONT → DRIFTING FRAGMENTS"
	status.text = "%s   %.2f s   /   %.2f× playback   /   VIEW %.2f×   /   %s SOURCE" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,"SILHOUETTE" if source_mode == 0 else "TOKEN"]

func reset_defaults() -> void:
	super.reset_defaults()
	set_source_mode(0)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1: set_source_mode(0); return
		if event.keycode == KEY_2: set_source_mode(1); return
	super._unhandled_key_input(event)
