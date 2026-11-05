extends Node2D
const Stone=preload("stone.gd")
var spike:Dictionary={}
var profile:Resource
var age:float=-1
func _draw()->void:
 if profile!=null: Stone.draw_spike(self,spike,age,profile)
