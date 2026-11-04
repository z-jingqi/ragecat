extends "timed_component.gd"
## Original compact contact burst, informed by the accepted Impact port's two-beat
## star, detached shards and broken ring. All geometry is sampled on an art-pixel grid.
## Visual only: no hit detection, hit-stop, shake, actor mutation or gameplay events.
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
var spokes:Array[Dictionary]=[]

func lifetime()->float:
	return profile.impact_duration

func _rebuild()->void:
	spokes.clear()
	var rng:=RandomNumberGenerator.new(); rng.seed=profile.shape_seed+419
	for i in range(6):
		var angle:=float(i)*TAU/6.0+rng.randf_range(-0.09,0.09)
		var alignment:=cos(angle)
		spokes.append({"angle":angle,"length":profile.impact_radius*(1.0+0.35*maxf(0,alignment))*rng.randf_range(0.8,1.0),"width":rng.randf_range(1.35,1.85)})

func samples()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if not started or not enabled or not profile.impact_enabled or elapsed<=0 or elapsed>=lifetime() or profile.intensity<=0: return result
	var grid:float=profile.pixel_size
	var bound:=int(ceil(profile.impact_radius*2.5/grid))
	var second:bool=elapsed>profile.impact_core_duration*0.5
	var core:bool=elapsed<=profile.impact_core_duration
	var tail:=clampf((elapsed-profile.impact_core_duration)/(lifetime()-profile.impact_core_duration),0,1)
	var tilt:=deg_to_rad(profile.direction_degrees)
	var palette:Array[Color]=[profile.edge_color,profile.highlight_color,profile.body_color,profile.inner_color,profile.shade_color]
	for gy in range(-bound,bound):
		for gx in range(-bound,bound):
			var point:=Vector2((gx+0.5)*grid,(gy+0.5)*grid).rotated(-tilt)
			var radius:=point.length()
			var tone:=-1
			if core:
				for spoke in spokes:
					var local:Vector2=point.rotated(-spoke.angle)
					var length:float=spoke.length*(1.22 if second else 1.0)
					if local.x<0 or local.x>length: continue
					var width:float=spoke.width*(0.55 if second else 1.0)*(1.0-local.x/length)*minf(1.0,0.45+local.x/2.0)
					var distance:=absf(local.y)
					if distance<=width+(0.32 if second else 0.65):
						var shade:=4 if distance>width else (2 if second else 1)
						if distance<width*0.4 and local.x<length*0.5: shade=1 if second else 0
						tone=shade if tone<0 else mini(tone,shade)
				if radius<=1.7: tone=1 if second else 0
			elif profile.impact_fragments_enabled or profile.impact_ring_enabled:
				var threshold:float=(BAYER[posmod(gy,4)*4+posmod(gx,4)]+0.5)/16.0
				if threshold>pow(1.0-tail,0.65): continue
				if profile.impact_fragments_enabled:
					for i in [0,1,3,5]:
						var spoke:Dictionary=spokes[i]
						var distance:float=spoke.length*(0.68+tail*0.95)
						var difference:=absf(wrapf(point.angle()-spoke.angle,-PI,PI))
						var span:=0.28*(1.0-tail*0.5)
						var width:=1.35*(1.0-tail*0.55)*(1.0-difference/span)
						if difference<span and absf(radius-distance)<maxf(0.25,width): tone=2 if tail<0.35 else (3 if tail<0.7 else 4)
				if profile.impact_ring_enabled:
					var ring_radius:float=profile.impact_radius*(0.45+0.7*(1.0-pow(1.0-tail,3)))
					var a:=point.angle()
					# Two uneven pressure crescents, never a complete magical circle.
					if (absf(a)<0.62 or absf(wrapf(a-PI,-PI,PI))<0.32) and absf(radius-ring_radius)<0.55*(1.0-tail*0.4):
						tone=3 if tail<0.5 else 4
			if tone<0: continue
			var color:Color=palette[tone]
			color=Color(minf(1,color.r*profile.intensity),minf(1,color.g*profile.intensity),minf(1,color.b*profile.intensity),1)
			# Reflect each cell, not just its origin, for exact horizontal mirroring.
			var x:float=(-gx-1)*grid if profile.facing_left else gx*grid
			result.append({"position":Vector2(x,gy*grid),"color":color,"size":grid})
	return result

func _draw()->void:
	for sample in samples(): draw_rect(Rect2(sample.position,Vector2.ONE*sample.size),sample.color)
