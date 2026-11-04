extends Node2D
var light_background:bool=false
func _draw()->void:
	var bg=Color("d9d5c9") if light_background else Color("17222c")
	draw_rect(Rect2(0,0,380,242),bg)
	var grid=bg.lightened(.025) if not light_background else bg.darkened(.035)
	for y in range(192,242,12):
		for x in range(0,380,20):
			if (x/20+y/12)%2==0: draw_rect(Rect2(x,y,20,12),grid)
	var c=Color("79838b") if light_background else Color("475963")
	for x in [32,348]:
		draw_rect(Rect2(x-3,196,6,7),c); draw_rect(Rect2(x-5,203,10,10),c)
		draw_rect(Rect2(x-5,213,3,13),c); draw_rect(Rect2(x+2,213,3,13),c)
		draw_rect(Rect2(x-8,204,3,8),c); draw_rect(Rect2(x+5,204,3,8),c)
	draw_line(Vector2(20,190),Vector2(360,190),grid)
