extends Node2D
func _draw():
 for x in [880,1110]:
  draw_rect(Rect2(x-19,484,38,76),Color("667985"))
  draw_line(Vector2(x-19,560),Vector2(x+19,560),Color("c2cdd2"),1)
