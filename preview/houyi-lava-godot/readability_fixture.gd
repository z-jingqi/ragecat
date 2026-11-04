extends Node2D
## Static depth/readability fixtures only. Not game characters or warnings.
func _draw() -> void:
	var warning_center:=Vector2(39,15)
	for i in range(64):
		if i%8>5: continue
		var a:=TAU*float(i)/64.
		var p:=(warning_center+Vector2(cos(a)*22,sin(a)*13)).round()
		draw_rect(Rect2(p,Vector2(1,1)),Color("d7adcb"))
	for item in [[Vector2(-20,3),Color("9fc2cb")],[Vector2(22,-14),Color("9f93a3")]]:
		var p:Vector2=item[0]
		draw_rect(Rect2(p+Vector2(-5,1),Vector2(12,3)),Color(0.03,0.04,0.05,0.7))
		draw_rect(Rect2(p+Vector2(-5,-14),Vector2(11,16)),Color("10131a"))
		draw_rect(Rect2(p+Vector2(-4,-9),Vector2(9,8)),item[1])
		draw_rect(Rect2(p+Vector2(-3,-15),Vector2(7,6)),Color("d0b79c"))
		draw_rect(Rect2(p+Vector2(-4,-16),Vector2(9,3)),Color("4b4c5b"))
		draw_rect(Rect2(p+Vector2(-4,-1),Vector2(3,4)),Color("737480"))
		draw_rect(Rect2(p+Vector2(2,-1),Vector2(3,4)),Color("737480"))
		draw_rect(Rect2(p+Vector2(-3,-8),Vector2(2,5)),Color("dae1db"))
