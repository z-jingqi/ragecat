class_name FloatingText
extends Node2D
var label := Label.new()
## Explicit metadata supports QA and accessibility without parsing rendered text.
var damage_kind: String = ""
var element_type: String = ""
var critical: bool = false
var displayed_amount: float = 0.0
var popup_label_key: String = ""
@export_range(0.01, 10, 0.01) var life: float = 0.65
@export_range(0, 1000, 1) var rise_speed: float = 32.0
@export_range(0.01, 100, 0.01) var fade_rate: float = 3.0
@export_range(1, 100, 1) var font_size: int = 18
var movement_bounds := Rect2()
var paired_follower: WeakRef
var paired_leader: WeakRef
var pair_offset := Vector2.ZERO
func setup(value: String, color: Color) -> void:
	label.text = value
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_shadow_color",Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x",1)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.add_theme_font_size_override("font_size",font_size)
	label.position=Vector2(-15,-20)
	add_child(label)
func limit_to_area(area: Rect2) -> void:
	movement_bounds = area
	_constrain_to_area()

func _constrain_to_area() -> void:
	if not movement_bounds.has_area(): return
	var text_size := label.get_combined_minimum_size()
	var minimum := movement_bounds.position - label.position
	var maximum := movement_bounds.end - label.position - text_size
	position = position.clamp(minimum, maximum)

func _process(delta: float) -> void:
	life -= delta
	var leader := paired_leader.get_ref() as FloatingText if paired_leader != null else null
	if is_instance_valid(leader):
		position = leader.position + pair_offset
	else:
		position.y -= delta*rise_speed
	_constrain_to_area()
	var follower := paired_follower.get_ref() as FloatingText if paired_follower != null else null
	if is_instance_valid(follower):
		follower.position = position + follower.pair_offset
		follower._constrain_to_area()
	modulate.a = minf(1.0,life*fade_rate)
	if life<=0: queue_free()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_inside_tree(): refresh_language()

func refresh_language() -> void:
	if damage_kind.is_empty(): return
	var caption := UpgradeDefinition.number(displayed_amount)
	if damage_kind == "element": caption = GameLocale.text(popup_label_key if not popup_label_key.is_empty() else "POPUP_" + element_type.to_upper()) + " " + caption
	if critical: caption = GameLocale.text("FEEDBACK_CRIT", [caption])
	label.text = caption
	_constrain_to_area()
