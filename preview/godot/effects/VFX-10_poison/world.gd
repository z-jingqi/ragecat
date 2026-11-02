extends Node2D
var field:Node2D
var moving:=true
var time:=0.0
var hits:=0
var flashes:Dictionary={}
func _ready()->void:
 field=load("res://effects/VFX-10_poison/poison.gd").new();field.automatic=false;add_child(field)
func advance(dt:float)->void:
 time+=dt;field.tick(dt);queue_redraw()
 var x:=100+sin(time*1.6)*65 if moving else 100.0
 hits=1 if field.active and absf(x-100)<field.config.radius else 0
func _draw()->void:
 # Ground ticks stay visible below the cloud, communicating its world footprint.
 for x in range(20,190,20):draw_rect(Rect2(x,99,1,2),Color("46515a"))
 var x:=100+sin(time*1.6)*65 if moving else 100.0
 draw_rect(Rect2(round(x)-3,98,7,5),Color("d2e481") if hits else Color("788189"))
