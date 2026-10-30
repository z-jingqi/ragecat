extends "res://scripts/vfx_lab/cel/study_lab.gd"
## Generic crystal anchor only; no actor, freeze state, collision or damage.
const Ice = preload("res://scripts/vfx/cel/ice.gd")
const ICE_CAPTURE_FRAMES := 1080
var held_crystals := false
var shattered_at := -1.0
var hold_button: Button
var shatter_button: Button

func _ready() -> void:
	effect_script = Ice
	floor_host = false
	super._ready()
	hold_button = _button("Hold [H]",744,64,func(): set_hold_crystals(not held_crystals),138)
	shatter_button = _button("Shatter [F]",895,64,trigger_shatter,138)
	_update_view()

func set_hold_crystals(value: bool) -> void:
	held_crystals = value
	replay()

func trigger_shatter() -> void:
	if shattered_at >= 0 or elapsed >= effect.get_end_time(): return
	if not held_crystals and elapsed >= (effect.config.growth_seconds+effect.config.hold_seconds)*effect.config.duration_scale: return
	shattered_at = maxf(elapsed,0.0)
	_update_view()

func replay() -> void:
	shattered_at = -1.0
	elapsed = -0.35
	playing = true
	_update_view()

func reset_defaults() -> void:
	held_crystals = false
	shattered_at = -1.0
	super.reset_defaults()

func cycle_duration() -> float:
	var end: float = effect.get_end_time()
	return (end if is_finite(end) else effect.config.duration())+0.9

func _fit_effect() -> void:
	# Explicit finite sampling ignores an interrupted held/early-release state.
	var bounds := Rect2(Vector2(-30,-30),Vector2(60,60))
	for i in range(120):
		for command in effect.build_commands(effect.config.duration()*i/120.0,-1):
			for point in command.points: bounds = bounds.expand(point)
	var width := 720.0 if settings_panel.visible else 1100.0
	fit_scale = minf(1.6,minf(width/maxf(bounds.size.x,1),350/maxf(bounds.size.y,1)))
	var center_x := 395.0 if settings_panel.visible else 592.0
	fit_origin = Vector2(center_x-bounds.get_center().x*fit_scale,390-bounds.end.y*fit_scale)

func _draw_world() -> void:
	super._draw_world()
	if not effect_only:
		# A neutral source guide exists only in the lab; it does not freeze anything.
		var angle := deg_to_rad(effect.config.direction_degrees)
		var a: Vector2 = Vector2(-95,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		var b: Vector2 = Vector2(95,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		world.draw_line(a,b,Color("94a49d") if light_background else Color("536878"),2,true)

func _update_view() -> void:
	if effect == null: return
	effect.seek(elapsed,shattered_at,held_crystals)
	effect.position = fit_origin
	effect.scale = Vector2.ONE*fit_scale
	var mode := "HELD CRYSTALS" if held_crystals else "FINITE CYCLE"
	if shattered_at >= 0: mode += " / FRACTURE %.2f s" % shattered_at
	status.text = "%s    %.2f s    /    %.2f× playback    /    VIEW %.2f×    /    %s" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,mode+(" / EFFECT ONLY" if effect_only else " / SOURCE GUIDE")]
	play_button.text = "Pause [Space]" if playing else "Play [Space]"
	pass_label.text = "STAGGERED CRYSTALLIZATION → LIVING FACETS → CRACK FRONT → SOURCE-BOUND SHATTER"
	if hold_button != null: hold_button.text = "Hold: %s [H]" % ("ON" if held_crystals else "OFF")
	world.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= ICE_CAPTURE_FRAMES: return
		var segment := capture_frame/360
		if segment != capture_segment:
			capture_segment = segment
			light_background = segment == 1
			effect_only = segment == 2
			playback_speed = 1.0 if segment == 0 else 0.5
			held_crystals = segment == 2
			replay()
		if segment == 0 and elapsed >= cycle_duration()-0.35: replay()
		step(playback_speed/60.0)
		if segment == 2 and elapsed >= 1.15 and shattered_at < 0:
			shattered_at = 1.15
			_update_view()
		_capture()
	elif playing:
		step(minf(maxf(delta,0),0.1)*playback_speed)
		if is_finite(effect.get_end_time()) and elapsed >= cycle_duration()-0.35: replay()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel ice capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= ICE_CAPTURE_FRAMES: get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_H: set_hold_crystals(not held_crystals)
		KEY_F: trigger_shatter()
		_: super._unhandled_key_input(event)
