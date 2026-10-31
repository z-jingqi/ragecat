extends "res://scripts/vfx_lab/cel/study_lab.gd"
## Presentation only; modes deliberately share no health or progression logic.
const Heal = preload("res://scripts/vfx/cel/heal.gd")
const HEAL_CAPTURE_FRAMES := 1440
var mode_buttons: Array[Button] = []

func _ready() -> void:
	effect_script = Heal
	floor_host = false
	super._ready()
	mode_buttons.append(_button("Heal [1]",744,64,func(): set_mode(0),138))
	mode_buttons.append(_button("Level up [2]",895,64,func(): set_mode(1),138))
	_update_view()

func set_mode(value: int) -> void:
	effect.config.mode = clampi(value,0,1)
	effect.configure(effect.config)
	_sync_controls()
	_fit_effect()
	replay()

func _update_view() -> void:
	if effect == null: return
	super._update_view()
	var mode := "HEAL" if effect.config.mode == 0 else "LEVEL UP"
	status.text = "%s   /   %s   /   %.2f s   /   %.2f× playback   /   VIEW %.2f×   /   %s" % [mode,"PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,"EFFECT ONLY" if effect_only else "SOURCE GUIDE"]
	pass_label.text = "HEAL  /  FOOT SWEEP → GROWING LEAF RIBBONS → UNFOLDING PLUS GLYPHS → DETACHED TIPS" if effect.config.mode == 0 else "LEVEL UP  /  FOOT SWEEP → OPENING CHEVRONS → FOUR-RAY CREST → ASCENDING TAILS"
	for i in range(mode_buttons.size()): mode_buttons[i].modulate = Color("f7df9a") if i == effect.config.mode else Color.WHITE

func _draw_world() -> void:
	super._draw_world()
	if not effect_only:
		var angle := deg_to_rad(effect.config.direction_degrees)
		var a: Vector2 = Vector2(-80,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		var b: Vector2 = Vector2(80,5).rotated(angle)*effect.config.size*fit_scale+fit_origin
		world.draw_line(a,b,Color("94a49d") if light_background else Color("536878"),1.2,true)

func capture_pose(frame: int) -> Dictionary:
	var bounded := clampi(frame,0,HEAL_CAPTURE_FRAMES-1)
	var segment := bounded/360
	var local_frame := bounded%360
	var slow := segment%2 == 1
	return {"mode":0 if segment < 2 else 1,"age":local_frame/120.0-0.35 if slow else (local_frame%180)/60.0-0.35,"speed":0.5 if slow else 1.0,"light":slow,"isolated":segment == 3}

func _process(delta: float) -> void:
	if effect == null or capture_busy: return
	if not capture_dir.is_empty():
		if capture_frame >= HEAL_CAPTURE_FRAMES: return
		var pose := capture_pose(capture_frame)
		if capture_frame/360 != capture_segment:
			capture_segment = capture_frame/360
			set_mode(pose.mode)
		light_background = pose.light
		effect_only = pose.isolated
		playback_speed = pose.speed
		elapsed = pose.age
		_update_view()
		_capture()
	elif playing:
		step(minf(maxf(delta,0),0.1)*playback_speed)
		if elapsed >= cycle_duration()-0.35: replay()

func _capture() -> void:
	capture_busy = true
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var error := picture.save_png(capture_dir.path_join("frame_%04d.png" % capture_frame))
	if error != OK:
		push_error("Cel heal / level-up capture failed: %s" % error)
		get_tree().quit(1)
		return
	capture_frame += 1
	capture_busy = false
	if capture_frame >= HEAL_CAPTURE_FRAMES: get_tree().quit()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo(): return
	match event.keycode:
		KEY_1: set_mode(0)
		KEY_2: set_mode(1)
		_: super._unhandled_key_input(event)
