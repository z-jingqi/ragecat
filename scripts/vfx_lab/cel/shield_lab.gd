extends "res://scripts/vfx_lab/cel/study_lab.gd"
## Presentation-only center guide and scripted contacts, never gameplay.
const Shield = preload("res://scripts/vfx/cel/shield.gd")
const SHIELD_CAPTURE_FRAMES := 1080
var held_shield := false
var broken_at := -1.0
var hold_button: Button
var break_button: Button
var manual_timeline := false
var manual_hits: Array = []

func _ready() -> void:
	effect_script = Shield
	floor_host = false
	super._ready()
	hold_button = _button("Hold [H]",744,64,func(): set_hold_shield(not held_shield),138)
	break_button = _button("Break [F]",895,64,trigger_break,138)
	_label("J / 1 hit upper-right  ·  2 hit lower-left",Vector2(48,705),12,Color("94aabd"))
	_update_view()

func set_hold_shield(value: bool) -> void:
	held_shield = value
	replay()

func trigger_break() -> void:
	if elapsed < 0 or broken_at >= 0 or elapsed >= effect.get_end_time(): return
	if not held_shield and elapsed >= (effect.config.spawn_seconds+effect.config.hold_seconds)*effect.config.duration_scale: return
	broken_at = elapsed
	_update_view()

func _demo_hits() -> Array:
	var config = effect.config
	return [{"time":(config.spawn_seconds+config.hold_seconds*0.25)*config.duration_scale,"angle":-35.0,"strength":1.0},{"time":(config.spawn_seconds+config.hold_seconds*0.57)*config.duration_scale,"angle":155.0,"strength":0.85}]

func trigger_hit(angle_degrees: float = -35.0) -> void:
	if effect.hit(angle_degrees,1.0):
		manual_timeline = true
		manual_hits = effect.get_hit_events()
		_update_view()

func replay() -> void:
	manual_timeline = false
	manual_hits.clear()
	broken_at = -1.0
	elapsed = -0.35
	playing = true
	_update_view()

func reset_defaults() -> void:
	held_shield = false
	broken_at = -1.0
	super.reset_defaults()

func cycle_duration() -> float:
	var end: float = effect.get_end_time()
	return (end if is_finite(end) else effect.config.duration())+0.9

func _fit_effect() -> void:
	# Explicit finite sampling ignores an interrupted held/early-release state.
	var saved_hits: Array = effect.get_hit_events()
	effect.set_hit_events(_demo_hits())
	var bounds := Rect2(Vector2(-30,-30),Vector2(60,60))
	for i in range(120):
		for command in effect.build_commands(effect.config.duration()*i/120.0,-1):
			for point in command.points: bounds = bounds.expand(point)
	effect.set_hit_events(saved_hits)
	var width := 720.0 if settings_panel.visible else 1100.0
	fit_scale = minf(1.6,minf(width/maxf(bounds.size.x,1),350/maxf(bounds.size.y,1)))
	var center_x := 395.0 if settings_panel.visible else 592.0
	fit_origin = Vector2(center_x-bounds.get_center().x*fit_scale,390-bounds.end.y*fit_scale)

func _draw_world() -> void:
	super._draw_world()
	if not effect_only:
		# A neutral anchor cross is lab-only. It represents no actor or hitbox.
		var color := Color("94a49d") if light_background else Color("536878")
		world.draw_line(fit_origin+Vector2(-8,0),fit_origin+Vector2(8,0),color,1,true)
		world.draw_line(fit_origin+Vector2(0,-8),fit_origin+Vector2(0,8),color,1,true)

func _update_view() -> void:
	if effect == null: return
	effect.seek(elapsed,broken_at,held_shield)
	effect.set_hit_events(manual_hits if manual_timeline else _demo_hits())
	effect.position = fit_origin
	effect.scale = Vector2.ONE*fit_scale
	var mode := "HELD SHIELD" if held_shield else "FINITE CYCLE"
	if broken_at >= 0: mode += " / BREAK %.2f s" % broken_at
	status.text = "%s    %.2f s    /    %.2f× playback    /    VIEW %.2f×    /    %s" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,mode+(" / EFFECT ONLY" if effect_only else " / CENTER GUIDE")]
	play_button.text = "Pause [Space]" if playing else "Play [Space]"
	pass_label.text = "ARC ASSEMBLY → LOCAL HIT + SURFACE RIPPLE → SOURCE-BOUND SHELL BREAK"
	if hold_button != null: hold_button.text = "Hold: %s [H]" % ("ON" if held_shield else "OFF")
	world.queue_redraw()
	queue_redraw()

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= SHIELD_CAPTURE_FRAMES: return
		var segment := capture_frame/360
		if segment != capture_segment:
			capture_segment = segment
			light_background = segment == 1
			effect_only = segment == 2
			playback_speed = 1.0 if segment == 0 else 0.5
			held_shield = segment == 2
			replay()
		if segment == 0 and elapsed >= cycle_duration()-0.35: replay()
		step(playback_speed/60.0)
		if segment == 2 and elapsed >= 1.75 and broken_at < 0:
			broken_at = 1.75
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
		push_error("Cel shield capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= SHIELD_CAPTURE_FRAMES: get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_H: set_hold_shield(not held_shield)
		KEY_F: trigger_break()
		KEY_J, KEY_1: trigger_hit(-35.0)
		KEY_2: trigger_hit(155.0)
		_: super._unhandled_key_input(event)
