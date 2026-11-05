extends Node2D
var light_background:bool=false
func _draw()->void:
	var bg:Color=Color("d4cebb") if light_background else Color("182525")
	draw_rect(Rect2(0,0,360,240),bg)
	var stone:Color=bg.lightened(.025) if not light_background else bg.darkened(.035)
	for row in 10:
		for col in 15:
			var x:int=col*26+(13 if row%2==1 else 0)-18
			var y:int=row*22+3
			draw_line(Vector2(x,y),Vector2(x+23,y),stone,1)
			draw_line(Vector2(x,y),Vector2(x,y+18),stone,1)
	for i in 36:
		var x:int=(i*79+13)%356; var y:int=(i*53+9)%230
		draw_rect(Rect2(x,y,2 if i%3==0 else 1,1),stone)
	var edge:Color=Color("8c877a") if light_background else Color("39504a")
	for x in [27,327]:
		draw_line(Vector2(x,206),Vector2(x+7,206),edge,1)
		draw_line(Vector2(x,203),Vector2(x,209),edge,1)
		draw_line(Vector2(x+7,203),Vector2(x+7,209),edge,1)
