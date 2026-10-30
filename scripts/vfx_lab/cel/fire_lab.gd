extends "res://scripts/vfx_lab/cel/study_lab.gd"
## Generic emitter presentation; no actor, burning status or damage ownership.
const Fire = preload("res://scripts/vfx/cel/fire.gd")
const FIRE_CAPTURE_FRAMES := 1080
var held_sustain := false
var released_at := -1.0
var hold_button: Button
var release_button: Button

func _ready() -> void:
	effect_script = Fire
	floor_host = false
	super._ready()
	hold_button = _button("Hold [H]",744,64,func(): set_hold_sustain(not held_sustain),138)
	release_button = _button("Release [F]",895,64,trigger_release,138)
	_update_view()

func set_hold_sustain(value: bool) -> void:
	held_sustain = value
	replay()

func trigger_release() -> void:
	if released_at >= 0 or elapsed >= effect.get_end_time(): return
	if not held_sustain and elapsed >= (effect.config.ignition_seconds+effect.config.sustain_seconds)*effect.config.duration_scale: return
	released_at = maxf(elapsed,0.0)
	_update_view()

func replay() -> void:
	released_at = -1.0
	elapsed = -0.35
	playing = true
	_update_view()

func reset_defaults() -> void:
	held_sustain = false
	released_at = -1.0
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
		# A small neutral source guide exists only in the lab; it does not burn.
		var angle := deg_to_rad(effect.config.direction_degrees)
		var a: Vector2 = Vector2(-48,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		var b: Vector2 = Vector2(48,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		world.draw_line(a,b,Color("94a49d") if light_background else Color("536878"),2,true)

func _update_view() -> void:
	if effect == null: return
	effect.seek(elapsed,released_at,held_sustain)
	effect.position = fit_origin
	effect.scale = Vector2.ONE*fit_scale
	var mode := "HELD SUSTAIN" if held_sustain else "FINITE BURST"
	if released_at >= 0: mode += " / RELEASE %.2f s" % released_at
	status.text = "%s    %.2f s    /    %.2f× playback    /    VIEW %.2f×    /    %s" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,mode]
	play_button.text = "Pause [Space]" if playing else "Play [Space]"
	pass_label.text = "IGNITION → ADVECTING TONGUES + INNER FLOW → RELEASE → LAST EMBERS"
	if hold_button != null: hold_button.text = "Hold: %s [H]" % ("ON" if held_sustain else "OFF")
	world.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= FIRE_CAPTURE_FRAMES: return
		var segment := capture_frame/360
		if segment != capture_segment:
			capture_segment = segment
			light_background = segment == 1
			effect_only = segment == 2
			playback_speed = 1.0 if segment == 0 else 0.5
			held_sustain = segment == 2
			replay()
		if segment == 0 and elapsed >= cycle_duration()-0.35: replay()
		step(playback_speed/60.0)
		if segment == 2 and elapsed >= 1.5 and released_at < 0:
			released_at = 1.5
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
		push_error("Cel fire capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= FIRE_CAPTURE_FRAMES: get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_H: set_hold_sustain(not held_sustain)
		KEY_F: trigger_release()
		_: super._unhandled_key_input(event)
