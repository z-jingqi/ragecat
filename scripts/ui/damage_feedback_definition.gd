class_name DamageFeedbackDefinition
extends Resource
## Presentation tuning. Damage accounting remains atomic and independent.
@export var base_color: Color = Color("f3eedc")
@export var critical_color: Color = Color("ffd36a")
@export var fire_color: Color = Color("ff956b")
@export var lightning_color: Color = Color("a99aff")
@export var ice_color: Color = Color("83e6ff")
@export var dark_color: Color = Color("ed8bde")
@export_range(1, 100, 1) var base_font_size: int = 18
@export_range(1, 100, 1) var critical_font_size: int = 23
@export_range(1, 100, 1) var element_font_size: int = 18
@export_range(1, 100, 1) var element_critical_font_size: int = 21
@export_range(1, 100, 1) var dot_font_size: int = 14
@export var base_offset := Vector2(-24, -20)
@export var element_offset := Vector2(14, 16)
@export_range(0, 100, 1) var bounds_inset: float = 6.0

func element_color(element: String) -> Color:
	match element:
		"fire": return fire_color
		"lightning": return lightning_color
		"ice": return ice_color
		"dark": return dark_color
		_: return base_color
