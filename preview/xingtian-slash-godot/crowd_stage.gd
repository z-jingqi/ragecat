extends Node2D
## Standalone visual staging, not game combat: scheduled contacts with test enemies.
## Every contact owns a separate unchanged Slash instance so one enemy cannot erase another.
const Profile=preload("components/slash_profile.gd")
const Slash=preload("components/xingtian_slash.gd")
const Arc=preload("components/copper_arc.gd")
const HERO=preload("assets/xing_tian.png")
var profile=Profile.new()
var mode:=0
var clock:=0.0
var blood_enabled:=true
var cleared:=false
var facing_left:=false
var contact_points:Array[Vector2]=[]
var enemies:Array[Dictionary]=[]
var hits:Array[Dictionary]=[]
var strokes:Array[Dictionary]=[]
var hero_origin:=Vector2(360,290)
var arena_size:=Vector2(760,490)
const CUT_ORIGIN=Vector2(0,-18)

func _ready()->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	configure(0)

func configure(value:int)->void:
	mode=clampi(value,0,2); clock=0.0; cleared=false
	for event in hits: event.node.free()
	for event in strokes: event.node.free()
	hits.clear(); strokes.clear(); contact_points.clear(); enemies.clear()
	var count:=3 if mode==0 else 6
	for i in count:
		var progress:=0.20+float(i)/maxf(1,count-1)*0.76
		var angle:=deg_to_rad(profile.sweep_center_degrees-profile.sweep_degrees*0.5+profile.sweep_degrees*progress)
		var point:Vector2=Vector2(cos(angle),sin(angle)*profile.squash)*(profile.radius-profile.thickness*0.3)
		point=point.rotated(deg_to_rad(profile.direction_degrees))
		if facing_left: point.x=-point.x
		contact_points.append(CUT_ORIGIN+point)
		enemies.append({"position":CUT_ORIGIN+point+point.normalized()*13.0,"kind":i%3,"hit":true})
	# Context enemies outside the cut are intentionally untouched.
	for i in range(8):
		var angle:=float(i)*TAU/8.0+0.18
		enemies.append({"position":Vector2(cos(angle)*145,sin(angle)*110+8),"kind":i%3,"hit":false})
	var waves:Array[float]=[0.55,2.15]
	if mode==2: waves.assign([0.45,0.73,1.01,1.29,2.05,2.33,2.61])
	for wave_index in waves.size():
		var wave:float=waves[wave_index]
		var settings=profile.duplicate(); settings.facing_left=facing_left
		var arc=Arc.new(); add_child(arc)
		strokes.append({"time":wave,"node":arc,"profile":settings})
		for i in count:
			var hit_profile=settings.duplicate(); hit_profile.shape_seed=profile.shape_seed+i*7+wave_index*101
			var effect=Slash.new(); add_child(effect); effect.set_layer_enabled("blood",blood_enabled)
			hits.append({"time":wave+profile.onset+(float(i)*0.035 if mode==1 else 0.0),"node":effect,"profile":hit_profile,"contact":contact_points[i],"target":i,"wave":wave_index})
	seek(0)

func set_blood(value:bool)->void:
	blood_enabled=value
	for event in hits: event.node.set_layer_enabled("blood",value)

func set_facing(value:bool)->void:
	var saved:=clock; var was_cleared:=cleared
	facing_left=value; configure(mode)
	if was_cleared: clear()
	else: seek(saved)

func seek(value:float)->void:
	if cleared or not is_finite(value): return
	clock=maxf(0,value)
	for event in strokes:
		var age:float=clock-event.time
		if age<0: event.node.clear()
		else:
			if not event.node.started: event.node.play(hero_origin+CUT_ORIGIN,event.profile)
			event.node.seek(age)
	for event in hits:
		var age:float=clock-event.time
		if age<0: event.node.clear()
		else:
			if not event.node.impact.started: event.node.play_hit(hero_origin+event.contact,event.profile)
			for part in [event.node.impact,event.node.sparks,event.node.blood]: part.seek(age)
	queue_redraw()

func clear()->void:
	cleared=true
	for event in hits: event.node.clear()
	for event in strokes: event.node.clear()
	queue_redraw()

func restart()->void:
	cleared=false; seek(0)

func live_contacts()->int:
	var count:=0
	for event in hits:
		var duration:=0.0
		if event.node.impact.enabled and event.profile.impact_enabled: duration=maxf(duration,event.profile.impact_duration)
		if event.node.sparks.enabled and event.profile.sparks_enabled and event.profile.spark_count>0: duration=maxf(duration,event.profile.spark_duration)
		if event.node.blood.enabled and event.profile.blood_enabled and event.profile.blood_count>0: duration=maxf(duration,event.profile.blood_duration)
		if event.node.impact.started and event.node.impact.elapsed>0 and event.node.impact.elapsed<duration: count+=1
	return count

func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,arena_size),Color("102936"))
	for x in range(0,int(arena_size.x),32): draw_line(Vector2(x,0),Vector2(x,arena_size.y),Color(0.2,0.4,0.45,0.14))
	for y in range(0,int(arena_size.y),32): draw_line(Vector2(0,y),Vector2(arena_size.x,y),Color(0.2,0.4,0.45,0.14))
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

func draw_enemy(at:Vector2,kind:int,active:bool)->void:
	var r:=16.0
	var opacity:=1.0 if active else 0.65
	draw_circle(at+Vector2(0,6),r,Color(0,0,0,.2))
	match kind:
		0: draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,0),at+Vector2(0,r),at+Vector2(-r,0)]),Color("dd7970")*Color(1,1,1,opacity))
		1: draw_colored_polygon(PackedVector2Array([at+Vector2(0,-r),at+Vector2(r,r),at+Vector2(0,r*.5),at+Vector2(-r,r)]),Color("e8b66b")*Color(1,1,1,opacity))
		2: draw_rect(Rect2(at-Vector2.ONE*r,Vector2.ONE*r*2),Color("b685ba")*Color(1,1,1,opacity))
	draw_circle(at+Vector2(0,-2),4,Color("502d3c"))
