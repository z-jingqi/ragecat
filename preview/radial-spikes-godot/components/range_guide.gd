extends Node2D
const Geometry=preload("geometry.gd")
var profile:Resource
var enabled:bool=true
func _draw()->void:
 if profile==null or not enabled: return
 for contour in Geometry.outlines(profile):
  var points:PackedVector2Array=contour.duplicate()
  if not points.is_empty(): points.append(points[0]); draw_polyline(points,Color(.45,.65,.57,.28),1,false)
