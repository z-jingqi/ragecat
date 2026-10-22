class_name DamageFeedbackDefinition
extends Resource
## Presentation tuning. Damage accounting remains atomic and independent.
@export var base_color: Color = Color("e7eeee")
@export var critical_color: Color = Color("ffe395")
@export_range(1, 100, 1) var base_font_size: int = 18
@export_range(1, 100, 1) var critical_font_size: int = 23
@export_range(1, 100, 1) var element_font_size: int = 18
@export_range(1, 100, 1) var element_critical_font_size: int = 21
@export var base_offset := Vector2(-24, -20)
@export var element_offset := Vector2(14, 16)
@export_range(0, 100, 1) var bounds_inset: float = 6.0
