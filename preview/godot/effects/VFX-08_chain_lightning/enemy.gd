extends Node2D
var flash:=0.0
var order:=-1
var base:=Vector2.ZERO
var live:=true
func _draw()->void:
	if not live:return
	var p:=Vector2.ZERO
	draw_rect(Rect2(-6,7,13,3),Color("111f2c"))
	draw_rect(Rect2(-5,-6,11,13),Color("406b72"))
	draw_rect(Rect2(-6,-3,13,7),Color("749a8b") if flash<=0 else Color("def3ee"))
	draw_rect(Rect2(-4,-7,3,3),Color("a0bdaa"));draw_rect(Rect2(2,-7,3,3),Color("a0bdaa"))
	draw_rect(Rect2(-3,-2,2,2),Color("172c36"));draw_rect(Rect2(2,-2,2,2),Color("172c36"))
	if flash>0:
		var r:=8+int((0.13-flash)*22)
		for i in range(4):
			var axis:=Vector2.from_angle(i*PI/2+PI/4)
			draw_line((axis*r).round(),(axis*(r+3)).round(),Color("b5ecf0"),1,false)
	if order>=0:draw_string(ThemeDB.fallback_font,Vector2(-3,-11),str(order+1),HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("e7e1ba"))
