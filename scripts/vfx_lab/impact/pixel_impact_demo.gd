extends RefCounted
## Lab-only arrow and mannequin. Reusable hit renderer does not require these.

func background(canvas: Node2D) -> void:
	canvas.rect(Rect2(0, 0, 384, 160), Color("c6c3b3") if canvas.bright else Color("131c25"))
	var grid := Color("b8b6a8") if canvas.bright else Color("1b2832")
	for x in range(0, 384, 16): canvas.line(Vector2(x, 0), Vector2(x, 160), grid)
	for y in range(0, 160, 16): canvas.line(Vector2(0, y), Vector2(384, y), grid)
	canvas.rect(Rect2(0, 121, 384, 39), Color("a4a598") if canvas.bright else Color("0d141b"))
	canvas.line(Vector2(0, 121), Vector2(384, 121), Color("7c897e") if canvas.bright else Color("314149"))
	canvas.set_offset(canvas.hit - Vector2(215,79))
	# Crisp stepped contact shadow, stand and faceted armor plate.
	canvas.rect(Rect2(186, 124, 78, 4), Color(0, 0, 0, 0.22))
	canvas.rect(Rect2(222, 102, 6, 22), Color("574d42"))
	canvas.rect(Rect2(211, 122, 29, 3), Color("86745a"))
	canvas.set_offset(Vector2.ZERO)

func target(canvas: Node2D, state: Dictionary) -> void:
	var recoil: Vector2 = (canvas.behavior.direction * state.recoil).round() + canvas.hit-Vector2(215,79)
	canvas.set_offset(recoil)
	canvas.poly([Vector2(210, 42),Vector2(226, 38),Vector2(244, 45),Vector2(244, 87),Vector2(236, 104),Vector2(224, 112),Vector2(209, 101),Vector2(202, 87),Vector2(202, 53)], Color("0a1019"))
	canvas.poly([Vector2(211, 45),Vector2(226, 41),Vector2(241, 47),Vector2(241, 86),Vector2(234, 102),Vector2(224, 108),Vector2(212, 99),Vector2(205, 86),Vector2(205, 55)], Color("71868f"))
	canvas.poly([Vector2(226, 44),Vector2(237, 49),Vector2(237, 84),Vector2(231, 99),Vector2(226, 103)], Color("344958"))
	canvas.poly([Vector2(209, 57),Vector2(222, 49),Vector2(222, 99),Vector2(215, 94),Vector2(209, 83)], Color("a3b6b4"))
	canvas.rect(Rect2(222, 44, 3, 59), Color("d6ddc8"))
	for p in [Vector2(210, 55),Vector2(236, 53),Vector2(214, 92),Vector2(231, 95)]: canvas.rect(Rect2(p,Vector2(2,2)),Color("e1d2a0"))
	if state.age >= 0.0:
		canvas.line(Vector2(215,79) + Vector2(-5,-2), Vector2(215,79) + Vector2(3,3),Color("253039"),2)
	canvas.set_offset(Vector2.ZERO)

func arrow(canvas: Node2D, state: Dictionary) -> void:
	if canvas.time >= 0.16 and canvas.time < 1.15:
		var tip: Vector2 = canvas.hit - canvas.behavior.direction * lerpf(155.0, 0.0, state.flight)
		if state.age >= 0.0: tip += (canvas.behavior.direction * state.recoil).round()
		var tail: Vector2 = tip - canvas.behavior.direction * 34.0
		canvas.line(tail.round(),tip.round(),Color("b9945b"),2)
		canvas.line((tail+Vector2(0,-1).rotated(canvas.behavior.direction.angle())).round(),(tip-Vector2(5,1).rotated(canvas.behavior.direction.angle())).round(),Color("edcf86"))
		for i in range(3): canvas.line((tail+Vector2(3+i*3,0).rotated(canvas.behavior.direction.angle())).round(),(tail+Vector2(i*3,-4).rotated(canvas.behavior.direction.angle())).round(),Color("a2b8b8"))
		canvas.poly([tip.round(),(tip+Vector2(-7,-3).rotated(canvas.behavior.direction.angle())).round(),(tip+Vector2(-5,2).rotated(canvas.behavior.direction.angle())).round()],Color("e2e9ce"))
		if state.age < 0.0:
			canvas.line((tail-Vector2(18,0).rotated(canvas.behavior.direction.angle())).round(),(tail-Vector2(5,0).rotated(canvas.behavior.direction.angle())).round(), Color("657879"))
