extends "res://previews/group_three/preview.gd"
# Observation only. The original parent's _process receives the engine's real
# delta unchanged and owns all source-step/warmup/replay semantics.
var process_samples = []
var stage_update_usec = 0
var stage_draw_usec = 0
var stage_present_usec = 0
var observations_active = false
var limit_ticks = 60
var interaction_events = []

class TimedEffect:
	extends RefCounted
	var target
	var observer
	func _init(effect, owner):
		target=effect
		observer=owner
	func update(dt):
		var started=Time.get_ticks_usec()
		target.update(dt)
		observer.stage_update_usec+=Time.get_ticks_usec()-started
	func draw(frame, layer=""):
		target.draw(frame,layer)
	func done(): return target.done()
	func stop(): target.stop()
	func invoke(method,args=[]):
		if target.has_method("invoke"): return target.invoke(method,args)
	func dispose():
		if target.has_method("dispose"): target.dispose()
		target=null
		observer=null

func spawn():
	var old_size=live.size()
	super.spawn()
	for i in range(old_size,live.size()): live[i]=TimedEffect.new(live[i],self)

func draw_buffers():
	var started=Time.get_ticks_usec()
	super.draw_buffers()
	stage_draw_usec+=Time.get_ticks_usec()-started

func present():
	var started=Time.get_ticks_usec()
	super.present()
	stage_present_usec+=Time.get_ticks_usec()-started

func _process(delta):
	if not observations_active: return
	var before_tick=sim_frame
	var before_warmup=warmup_remaining
	stage_update_usec=0
	stage_draw_usec=0
	stage_present_usec=0
	var started=Time.get_ticks_usec()
	super._process(delta)
	var ended=Time.get_ticks_usec()
	if sim_frame!=before_tick or warmup_remaining!=before_warmup:
		process_samples.append({"phase":"warmup" if before_warmup>0 else "measured","source_tick":sim_frame,"warmup_remaining":warmup_remaining,"engine_delta_seconds":delta,"started_usec":started,"ended_usec":ended,"cpu_update_usec":stage_update_usec,"cpu_draw_buffers_usec":stage_draw_usec,"cpu_present_including_image_texture_label_usec":stage_present_usec,"cpu_host_total_usec":ended-started})
	if sim_frame>=limit_ticks: paused=true

func _unhandled_key_input(event):
	# A benchmark is not an interactive preview session. Refuse replay/pause/case
	# changes and mark the receipt contaminated if input was attempted.
	if observations_active and event is InputEventKey and event.pressed and not event.echo:
		interaction_events.append({"keycode":event.keycode,"source_tick":sim_frame,"warmup_remaining":warmup_remaining})
		get_viewport().set_input_as_handled()
