extends RefCounted
# Stable mode router. Earlier implementations are preserved without edits.
const D=preload("drawing.gd")
const Crackle=preload("lightning_crackle.gd")
const Spiral=preload("lightning_spiral.gd")
const Double=preload("lightning_double.gd")
const Reference=preload("lightning_reference.gd")
static func arc(from:Vector2,to:Vector2,seed_value:int,jag:float=1.0)->PackedVector2Array:
	return Crackle.arc(from,to,seed_value,jag)
static func arcs_at(time:float,length:float,width:float,a:Resource)->Array:
	return Reference.arcs_at(time,length,width,a) if a.lightning_mode==3 else Double.arcs_at(time,length,width,a)
static func back(fx:Node2D,a:Resource)->void:
	if a.lightning_mode==3: Reference.draw_side(fx,a,false)
	else: Double.back(fx,a)
static func front(fx:Node2D,a:Resource)->void:
	if a.lightning_mode==3: Reference.draw_side(fx,a,true)
	else: Double.front(fx,a)
