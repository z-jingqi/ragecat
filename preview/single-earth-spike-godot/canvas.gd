extends Node2D
const Stone=preload("stone.gd")
const Contact=preload("contact.gd")
var spike:Dictionary={}
var profile:Resource
var age:float=-1
func _draw()->void:
 if profile!=null:
  Contact.draw_before(self,spike,age,profile)
  Stone.draw_spike(self,spike,age,profile)
  Contact.draw_after(self,spike,age,profile)
