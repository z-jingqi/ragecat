extends Node2D
## Unchanged approved static portrait crop and explicit geometric test enemies.
const HERO=preload("assets/xing_tian.png")
var hero_origin:=Vector2.ZERO
var facing_left:=false
var enemies:Array[Dictionary]=[]
var show_ground_contact:=false
var ground_contact:=Vector2.ZERO
func _draw()->void:
	# Neutral game-sized geometric placeholders, no damage/health or hit animation.
	for enemy in enemies:
		if enemy.position.y<0: draw_enemy(hero_origin+enemy.position,enemy.kind,enemy.hit)
	var ratio:=76.0/2392.0
	var crop:=Rect2(Vector2(445,0)/Vector2(1904,2544)*HERO.get_size(),Vector2(1229,2392)/Vector2(1904,2544)*HERO.get_size())
	var rect:=Rect2(Vector2((445.0-940.0)*ratio,15.0-76.0),Vector2(1229,2392)*ratio)
	draw_set_transform(hero_origin+Vector2(0,8),0,Vector2(1,.45)); draw_circle(Vector2.ZERO,21,Color(0,0,0,.25)); draw_set_transform(Vector2.ZERO)
	draw_set_transform(hero_origin,0,Vector2(-1 if facing_left else 1,1))
	draw_texture_rect_region(HERO,rect,crop)
	draw_set_transform(Vector2.ZERO)
	for enemy in enemies:
		if enemy.position.y>=0: draw_enemy(hero_origin+enemy.position,enemy.kind,enemy.hit)
	if show_ground_contact:
		# Fixed ground point marker only, not a target, hitbox or animated weapon.
		var at:=hero_origin+ground_contact
		for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			draw_line(at+direction*3,at+direction*6,Color("90bac4"),1)

func draw_enemy(at:Vector2,kind:int,active:bool)->void:
	var r:=16.0
	var opacity:=1.0 if active else 0.65
	draw_circle(at+Vector2(0,6),r,Color(0,0,0,.2))
	match kind:
		0: draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,0),at+Vector2(0,r),at+Vector2(-r,0)]),Color("dd7970")*Color(1,1,1,opacity))
		1: draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,r),at+Vector2(0,r*.5),at+Vector2(-r,r)]),Color("e8b66b")*Color(1,1,1,opacity))
		2: draw_rect(Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2),Color("b685ba")*Color(1,1,1,opacity))
	draw_circle(at+Vector2(0,-2),4,Color("502d3c"))
