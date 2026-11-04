extends Node2D
var light_background:bool=false
func _draw() -> void:
	var bg=Color("d6d5c7") if light_background else Color("17212b")
	draw_rect(Rect2(0,0,300,260),bg)
	var tile=bg.lightened(.025)
	for y in range(160,260,12):
		for x in range(0,300,16):
			if (x/16+y/12)%2==0: draw_rect(Rect2(x,y,16,12),tile)
	var muted=Color("787f83") if light_background else Color("48515b")
	# Static 28px silhouettes are scale references, not game actors.
	for x in [75,225]:
		draw_rect(Rect2(x-4,192,8,7),muted); draw_rect(Rect2(x-6,200,12,10),muted)
		draw_rect(Rect2(x-5,210,4,10),muted); draw_rect(Rect2(x+1,210,4,10),muted)
		draw_rect(Rect2(x-9,201,3,8),muted); draw_rect(Rect2(x+6,201,3,8),muted)
	draw_line(Vector2(146,218),Vector2(154,218),Color("606268"))
	draw_line(Vector2(150,214),Vector2(150,222),Color("606268"))
