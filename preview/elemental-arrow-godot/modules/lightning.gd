extends RefCounted
# Midpoint displacement and bright-core/dark-sheath strokes adapted from
# Sprite Fusion lightning (MIT, Copyright (c) 2026 Hugo Duprez). Short re-struck
# surface paths follow PixelFX electrified (MIT, Copyright (c) 2026 Patch and
# Hugo Duprez). Original shaft-local roots; no historic wake or detached sparks.
const D=preload("drawing.gd")
const DARK=Color("3e3978")
const BLUE=Color("597fe6")
const CYAN=Color("70dafa")
const WHITE=Color("e7fcff")
static func arc(from:Vector2,to:Vector2,seed_value:int,jag:float=1.0)->PackedVector2Array:
	var points=PackedVector2Array([from,to]); var off=from.distance_to(to)*.15*jag
	for depth in 3:
		var out=PackedVector2Array([points[0]])
		for i in range(points.size()-1):
			var a=points[i]; var b=points[i+1]; var v=(b-a).normalized()
			var n=Vector2(-v.y,v.x); var d=(D.random01(i+depth*73,seed_value)*2-1)*off
			out.append((a+b)*.5+n*d); out.append(b)
		points=out; off*=.5
	return points
static func stroke(fx:CanvasItem,points:PackedVector2Array,a:Resource,k:float=1.0,white:bool=true)->void:
	for i in range(points.size()-1):
		D.line(fx,points[i],points[i+1],D.tinted(DARK,a,.55*k),2*a.size)
		D.line(fx,points[i],points[i+1],D.tinted(CYAN if white else BLUE,a,.9*k))
		if white and i%3==1: D.line(fx,points[i],points[i+1],D.tinted(WHITE,a,k*.9))
static func back(fx:Node2D,a:Resource)->void:
	# Restrained attached light only. No tail, history lookup, shed sparks or branches.
	var x=-fx.profile.length*.5
	D.glow(fx,D.point(fx.pose,x,0),4.5*a.size,D.tinted(BLUE,a),.26*a.glow)
static func front(fx:Node2D,a:Resource)->void:
	var p=fx.pose; var frame=int(fx.age*14); var l=fx.profile.length
	# One thin re-struck path sits on the shaft, with a short secondary pulse.
	var local_points=arc(Vector2(-7,0),Vector2(-l+7,0),a.seed_value+frame*41,.36*a.size)
	var points=PackedVector2Array()
	for at in local_points:
		at.x=clampf(at.x,-l+6,-6)
		at.y=clampf(at.y,-2.2*a.size,2.2*a.size)
		points.append(D.point(p,at.x,at.y))
	stroke(fx,points,a)
	if frame%6==0:
		var x=-l*.48
		var short_arc=arc(Vector2(x-3,1.5*a.size),Vector2(x+3,-1.3*a.size),frame+a.seed_value,.25)
		var short_world=PackedVector2Array()
		for at in short_arc:
			short_world.append(D.point(p,clampf(at.x,-l+5,-5),clampf(at.y,-2.4*a.size,2.4*a.size)))
		stroke(fx,short_world,a,.5,false)
