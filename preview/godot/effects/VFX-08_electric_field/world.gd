extends Node2D
var field:Node2D
var enemies:Array=[]
var flashes:Dictionary={}
var moving:=true
var time:=0.0
var hits:=0
func _ready()->void:
 field=load("res://effects/VFX-08_electric_field/field.gd").new();field.automatic=false;add_child(field)
 for p in [Vector2(80,45),Vector2(120,72),Vector2(170,50),Vector2(50,65)]:
  var n:=Node2D.new();n.position=p;add_child(n);enemies.append(n)
 field.target_tick.connect(func(t,id,_scheduled):flashes[t.get_instance_id()]=0.09;hits+=1)
func advance(dt:float)->void:
 time+=dt
 if moving:enemies[3].position=Vector2(100+sin(time*2)*62,75)
 for key in flashes:flashes[key]=maxf(0,flashes[key]-dt)
 field.tick(dt);queue_redraw()
func _draw()->void:
 for i in range(enemies.size()):
  var p:Vector2=enemies[i].position.round();var flash:bool=flashes.get(enemies[i].get_instance_id(),0)>0
  var color:=Color("d0bda2") if not flash else Color("f4f0e5")
  draw_rect(Rect2(p+Vector2(-4,-7),Vector2(8,7)),Color("4a535d"));draw_rect(Rect2(p+Vector2(-3,-10),Vector2(6,5)),color)
  draw_rect(Rect2(p+Vector2(-5,1),Vector2(10,2)),Color("38404c"))
