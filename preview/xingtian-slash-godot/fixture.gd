extends Node2D
## Static original rectangles: scale/readability fixture, not character art or animation.
var target := Vector2(46,-10)
var show_target := true
func _draw() -> void:
	mannequin(Vector2.ZERO,Color("53616c"),Color("81909a"))
	if show_target: mannequin(target,Color("57535b"),Color("9a8b88"))

func mannequin(origin:Vector2,body:Color,edge:Color) -> void:
	draw_rect(Rect2(origin+Vector2(-9,17),Vector2(18,3)),Color("141d27"))
	for rect in [Rect2(-4,-21,8,8),Rect2(-8,-11,16,17),Rect2(-12,-9,4,13),Rect2(8,-9,4,13),Rect2(-7,6,5,13),Rect2(2,6,5,13)]:
		draw_rect(Rect2(rect.position+origin,rect.size),body)
	draw_rect(Rect2(origin+Vector2(-4,-20),Vector2(7,2)),edge)
	draw_rect(Rect2(origin+Vector2(-7,-10),Vector2(3,15)),edge)
	draw_rect(Rect2(origin+Vector2(-6,7),Vector2(2,11)),edge)
