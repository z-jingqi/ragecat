extends RefCounted
## Optional practice character only. The charge renderer can omit this context.
static func background(r: Node2D) -> void:
	r.rect(Rect2(0,0,384,160),Color("c6c3b3") if r.bright else Color("131c25"))
	var grid := Color("b8b6a8") if r.bright else Color("1b2832")
	for x in range(0,384,32): r.rect(Rect2(x,0,1,160),grid)
	for y in range(0,160,32): r.rect(Rect2(0,y,384,1),grid)
	r.rect(Rect2(0,133,384,27),Color("a4a598") if r.bright else Color("0d141b"))
	r.rect(Rect2(0,133,384,1),Color("7c897e") if r.bright else Color("314149"))
static func draw_body(r: Node2D, state: Dictionary) -> void:
	var crouch := roundf(state.crouch*5)
	r.rect(Rect2(163,131,58,2),Color("18242e"))
	r.poly([Vector2(180,101),Vector2(203,101),Vector2(216,128),Vector2(206,131),Vector2(192,115),Vector2(176,131),Vector2(166,129)],Color("2b4254"))
	r.rect(Rect2(164,128,14,4),Color("111d29")); r.rect(Rect2(206,128,15,4),Color("111d29"))
	var body := Vector2(0,crouch)
	r.poly([Vector2(179,77)+body,Vector2(191,71)+body,Vector2(205,78)+body,Vector2(207,100)+body,Vector2(179,102)+body,Vector2(173,89)+body],Color("496c82"))
	r.poly([Vector2(180,79)+body,Vector2(188,77)+body,Vector2(186,97)+body,Vector2(179,96)+body],Color("83a2aa"))
	r.poly([Vector2(182,56)+body,Vector2(190,51)+body,Vector2(200,54)+body,Vector2(205,64)+body,Vector2(197,75)+body,Vector2(185,71)+body],Color("9badb0"))
	r.rect(Rect2(Vector2(183,62)+body,Vector2(21,4)),Color("1a2c3d"))
	r.rect(Rect2(Vector2(197,63)+body,Vector2(5,1)),Color("f5e6bf"))
	# Braced elbows and lowered stance: original practice mannequin, not the Knight.
	r.line(Vector2(178,83)+body,Vector2(183,96)+body,Color("83a2aa"),5)
	r.line(Vector2(204,83)+body,Vector2(201,96)+body,Color("83a2aa"),5)
	r.dot(Vector2(185,95)+body,5,Color("c6b18c"))
	r.dot(Vector2(199,95)+body,5,Color("c6b18c"))
