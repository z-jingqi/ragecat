extends Node2D
## Host-scripted visual staging. No gameplay decisions are made by the VFX components.
const Profile=preload("components/slash_profile.gd")
const Heavy=preload("components/heavy_profile.gd")
const Pressure=preload("components/heavy_pressure.gd")
const Arc=preload("components/copper_arc.gd")
const Slash=preload("components/xingtian_slash.gd")
const Fixture=preload("heavy_fixture.gd")
const CUT=Vector2(0,-18)
const GROUND_DELAY=.075 # Preview-only timing, independent of the cleave profile.
# Scripted attack landing point relative to the portrait anchor, not its feet.
var ground_contact_offset:=Vector2(18,7)
var profile=Heavy.new()
var mode:=1
var clock:=0.0
var cleared:=false
var blood_enabled:=true
var wave_enabled:=true
var facing_left:=false
var hero_origin:=Vector2(310,246)
var arena_size:=Vector2(656,430)
var fixture
var events:Array[Dictionary]=[]
var contacts:Array[Vector2]=[]
func _ready()->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	configure(profile,mode)
func configure(value:Resource,scenario:int)->void:
	mode=clampi(scenario,0,3); profile=(value if value is Heavy else Heavy.new()).sanitized()
	for child in get_children(): child.free()
	events.clear(); contacts.clear(); clock=0; cleared=false
	var settings=Profile.new() if mode==0 else profile.duplicate()
	settings.facing_left=facing_left
	var targets:=0 if mode==3 else (6 if mode==2 else 1)
	fixture=Fixture.new(); fixture.hero_origin=hero_origin; fixture.facing_left=facing_left
	fixture.show_ground_contact=mode==3; fixture.ground_contact=ground_origin()-hero_origin
	for i in targets:
		var progress:=.2+float(i)/maxf(1,targets-1)*.76 if targets>1 else .96
		var angle:float=deg_to_rad(settings.sweep_center_degrees-settings.sweep_degrees*.5+settings.sweep_degrees*progress)
		var point:Vector2=Vector2(cos(angle),sin(angle)*settings.squash)*(settings.radius-settings.thickness*.3)
		point=point.rotated(deg_to_rad(settings.direction_degrees))
		if facing_left: point.x=-point.x
		contacts.append(CUT+point)
		fixture.enemies.append({"position":CUT+point+point.normalized()*13,"kind":i%3,"hit":true})
	for i in 7:
		var angle:=float(i)*TAU/7+.2
		fixture.enemies.append({"position":Vector2(cos(angle)*150,sin(angle)*105+8),"kind":i%3,"hit":false})
	# Back halves precede actors; front halves follow actors. No glowing disc covers the feet.
	for start in [.5,1.7]:
		if mode==3:
			var back=Pressure.new(); back.draw_half=-1; add_child(back)
			events.append({"node":back,"time":start+GROUND_DELAY,"type":"pressure","profile":settings,"origin":ground_origin()})
	add_child(fixture)
	for start in [.5,1.7]:
		if mode==3:
			var front=Pressure.new(); front.draw_half=1; add_child(front)
			events.append({"node":front,"time":start+GROUND_DELAY,"type":"pressure","profile":settings,"origin":ground_origin()})
			continue # A ground strike has no blade, contact sparks or blood.
		var arc=Arc.new(); add_child(arc)
		events.append({"node":arc,"time":start,"type":"arc","profile":settings,"origin":hero_origin+CUT})
		for i in targets:
			var hit=Slash.new(); add_child(hit); hit.set_layer_enabled("blood",blood_enabled)
			var p=settings.duplicate(); p.shape_seed+=i*7+int(start*100)
			events.append({"node":hit,"time":start+settings.onset,"type":"hit","profile":p,"origin":hero_origin+contacts[i]})
	seek(0)
func ground_origin()->Vector2: return hero_origin+Vector2(-ground_contact_offset.x if facing_left else ground_contact_offset.x,ground_contact_offset.y)
func set_blood(value:bool)->void:
	blood_enabled=value
	for event in events:
		if event.type=="hit": event.node.set_layer_enabled("blood",value)
func set_wave(value:bool)->void:
	wave_enabled=value
	for event in events:
		if event.type=="pressure": event.node.set_enabled(value)
func set_facing(value:bool)->void:
	var saved:=clock; var was_cleared:=cleared
	facing_left=value; configure(profile,mode)
	if was_cleared: clear()
	else: seek(saved)
func seek(value:float)->void:
	if cleared or not is_finite(value): return
	clock=maxf(0,value)
	for event in events:
		var age:float=clock-event.time
		if age<0: event.node.clear(); continue
		if event.type=="hit":
			if not event.node.impact.started: event.node.play_hit(event.origin,event.profile)
			for part in [event.node.impact,event.node.sparks,event.node.blood]: part.seek(age)
		else:
			if not event.node.started: event.node.play(event.origin,event.profile)
			if event.type=="pressure": event.node.set_enabled(wave_enabled)
			event.node.seek(age)
	queue_redraw()
func clear()->void:
	cleared=true
	for event in events: event.node.clear()
func restart()->void: cleared=false; seek(0)
func _draw()->void:
	draw_rect(Rect2(Vector2.ZERO,arena_size),Color("102936"))
	for x in range(0,int(arena_size.x),32): draw_line(Vector2(x,0),Vector2(x,arena_size.y),Color(.2,.4,.45,.14))
	for y in range(0,int(arena_size.y),32): draw_line(Vector2(0,y),Vector2(arena_size.x,y),Color(.2,.4,.45,.14))
