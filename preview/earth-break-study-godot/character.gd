extends Node2D
## Neutral 30px geometry proxy, not character production artwork.
func _draw()->void:
	draw_colored_polygon(PackedVector2Array([Vector2(-10,-1),Vector2(-5,-4),Vector2(6,-4),Vector2(11,-1),Vector2(6,3),Vector2(-6,3)]),Color(0,0,0,.24))
	draw_rect(Rect2(-5,-6,4,6),Color("222934")); draw_rect(Rect2(2,-6,4,6),Color("222934"))
	draw_colored_polygon(PackedVector2Array([Vector2(-5,-22),Vector2(5,-22),Vector2(8,-6),Vector2(4,-4),Vector2(0,-6),Vector2(-6,-4),Vector2(-8,-6)]),Color("303e52"))
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-21),Vector2(2,-21),Vector2(4,-7),Vector2(-5,-8)]),Color("577d8a"))
	draw_rect(Rect2(-4,-29,8,7),Color("212c3a")); draw_rect(Rect2(-3,-27,6,5),Color("c9b28f"))
	draw_rect(Rect2(-4,-30,8,3),Color("485b65")); draw_rect(Rect2(-5,-27,2,6),Color("485b65"))
	draw_rect(Rect2(-6,-20,2,6),Color("94acaa")); draw_rect(Rect2(5,-20,2,6),Color("94acaa"))
	draw_rect(Rect2(-4,-15,8,2),Color("ba9b5b")); draw_rect(Rect2(-1,-21,2,5),Color("c3c2a9"))
