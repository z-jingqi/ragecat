class_name ArcherFeedbackOverlay
extends Node2D
## Existing shield and hit rings stay above the character's textured body.
var actor: PlayerActor
func _process(_delta: float) -> void:
	queue_redraw()
func _draw() -> void:
	if not is_instance_valid(actor) or actor.stats == null: return
	if actor.stats.shields > 0:
		draw_arc(Vector2.ZERO,29,0,TAU,40,Color(0.35,0.8,1,0.65),2,true)
	if actor.impact_left > 0.0 and actor.impact_kind == "hurt":
		var fade := actor.impact_left / actor.stats.hit_feedback_duration
		var color := Color("ff637d")
		color.a = fade
		draw_arc(Vector2.ZERO,31.0+(1.0-fade)*22.0,0,TAU,48,color,4.0,true)
