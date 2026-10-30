extends Node2D
## Demo-only prop animation. The reusable effect does not import this script.
const CONTACT := 0.48
const CYCLE := 1.8
var time := 0.0
var bright := false
var show_props := true
var direction_degrees := 0.0
var origin := Vector2(790,386)

func _draw() -> void:
	var backdrop := Color("e9e8df") if bright else Color("293747")
	draw_style_box(_panel(backdrop),Rect2(48,164,1184,446))
	if not show_props: return
	var ground := Color("d4d8d1") if bright else Color("263e44")
	draw_line(Vector2(148,550),Vector2(1132,550),ground,2,true)
	draw_set_transform(Vector2(origin.x+68,545),0,Vector2(1,0.16))
	draw_circle(Vector2.ZERO,105,ground,true,-1,true)
	draw_set_transform(Vector2.ZERO)
	var age := time-CONTACT
	var recoil := 0.0
	if age >= 0.0 and age < 0.3:
		recoil = 11.0*sin(minf(age/0.055,1)*PI/2.0)*pow(1.0-age/0.3,2)
	var incoming := Vector2.RIGHT.rotated(deg_to_rad(direction_degrees))
	var center := origin+Vector2(66,-3)+incoming*recoil
	draw_set_transform(center,0.028*recoil/11.0,Vector2(1.28,1.23))
	# Broad unoutlined shield planes; restrained pale rim is material, not black ink.
	_poly([Vector2(-79,-104),Vector2(5,-141),Vector2(87,-104),Vector2(73,67),Vector2(5,137),Vector2(-68,84)],Color("8ca3bb"))
	_poly([Vector2(-68,-96),Vector2(5,-129),Vector2(76,-96),Vector2(63,62),Vector2(4,122),Vector2(-58,77)],Color("536e8d"))
	_poly([Vector2(5,-129),Vector2(76,-96),Vector2(63,62),Vector2(4,122)],Color("34475f"))
	_poly([Vector2(-68,-96),Vector2(5,-129),Vector2(4,122),Vector2(-58,77)],Color("6685a4"))
	_poly([Vector2(-65,-92),Vector2(-12,-113),Vector2(-43,-26),Vector2(-29,-42),Vector2(-56,76)],Color("91acc4"))
	_poly([Vector2(22,-103),Vector2(46,-88),Vector2(16,96),Vector2(5,114)],Color("4b6481"))
	for p in [Vector2(-60,-87),Vector2(63,-85),Vector2(-49,68),Vector2(52,58)]:
		draw_circle(p,6,Color("33465b"),true,-1,true)
		draw_circle(p+Vector2(-1,-1),4.5,Color("88a3bd"),true,-1,true)
		draw_circle(p+Vector2(-2,-2),2,Color("c3d5df"),true,-1,true)
	draw_set_transform(Vector2.ZERO)
	if time < 0.15: return
	var tip: Vector2
	var angle := incoming.angle()
	if age < 0:
		var u := clampf((time-0.15)/(CONTACT-0.15),0,1)
		var approach_distance := 505.0 if origin.x >= 700.0 else 260.0
		tip = origin-incoming*(1.0-u)*approach_distance
		if u > 0.25:
			for i in range(3):
				var p := tip-incoming*(150+i*31)+Vector2(0,(i-1)*13)
				draw_line(p,p+incoming*(34-i*6),Color("698e95") if bright else Color("37565f"),2-i*0.4,true)
	else:
		if age > 0.42: return
		tip = origin+Vector2(-230*age,-170*age+400*age*age).rotated(angle)
		angle -= age*2.0
	draw_set_transform(tip,angle)
	_poly([Vector2(-218,-3),Vector2(-18,-3),Vector2(-18,3),Vector2(-218,3)],Color("c7a375"))
	_poly([Vector2(-218,0),Vector2(-18,0),Vector2(-18,3),Vector2(-218,3)],Color("99724e"))
	_poly([Vector2(0,0),Vector2(-28,-11),Vector2(-23,0),Vector2(-28,11)],Color("e1e8dc"))
	_poly([Vector2(-216,-3),Vector2(-241,-18),Vector2(-215,-16),Vector2(-192,-3)],Color("e4dfce"))
	_poly([Vector2(-216,3),Vector2(-241,17),Vector2(-215,15),Vector2(-192,3)],Color("b7b8b0"))
	draw_set_transform(Vector2.ZERO)

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)
	var edge := PackedVector2Array(points)
	edge.append(edge[0])
	draw_polyline(edge,color,0.8,true)

func _panel(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	return box
