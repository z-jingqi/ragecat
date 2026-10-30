extends "res://scripts/vfx_lab/cel/study_lab.gd"
## A neutral contact guide is presentation-only; the reusable effect has no host.
const Lightning = preload("res://scripts/vfx/cel/lightning.gd")

func _ready() -> void:
	effect_script = Lightning
	floor_host = false
	super._ready()

func _draw_world() -> void:
	super._draw_world()
	if not effect_only:
		var angle := deg_to_rad(effect.config.direction_degrees)
		var a: Vector2 = Vector2(-125,6).rotated(angle)*effect.config.size*fit_scale+fit_origin
		var b: Vector2 = Vector2(125,6).rotated(angle)*effect.config.size*fit_scale+fit_origin
		world.draw_line(a,b,Color("94a49d") if light_background else Color("536878"),1,true)

func _update_view() -> void:
	super._update_view()
	status.text = "%s    %.2f s    /    %.2f× playback    /    VIEW %.2f×    /    %s" % ["PLAYING" if playing else "PAUSED",maxf(elapsed,0),playback_speed,fit_scale,"EFFECT ONLY" if effect_only else "CONTACT GUIDE"]
	pass_label.text = "DESCENDING LEADER → REROUTED RETURN STROKES + FORKS → BROKEN RESIDUAL ARCS"
