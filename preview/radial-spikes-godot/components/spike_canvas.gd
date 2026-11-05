extends Node2D
var spike:Dictionary={}
var age:float=-1
var profile:Resource
var renderer:Script
func _draw()->void:
	if profile!=null and renderer!=null: renderer.draw_spike(self,spike,age,profile)
