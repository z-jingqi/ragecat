extends "timed_component.gd"
## Original short, broken ground-pressure ellipse. No collision, shake, scorch or actor effects.
## Inspired by the replicated Explosion ground ellipse and Impact's thinning/dithered ring.
const HeavyProfile=preload("heavy_profile.gd")
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5]
var debris:Array[Dictionary]=[]
## Optional rendering split: -1 far half, +1 near half, 0 complete. Same clock/profile.
var draw_half:=0
func _init()->void: profile=HeavyProfile.new()
func play(origin:=Vector2.ZERO,configuration:Resource=null)->void:
	if not origin.is_finite(): clear(); return
	position=origin; profile=(configuration if configuration is HeavyProfile else HeavyProfile.new()).sanitized()
	elapsed=0; started=true; _rebuild(); _refresh()
func lifetime()->float: return profile.pressure_duration
func _rebuild()->void:
	debris.clear()
	var rng:=RandomNumberGenerator.new(); rng.seed=profile.shape_seed+701
	for i in profile.debris_count:
		var angle:=rng.randf_range(-PI,PI)
		debris.append({"angle":angle,"distance":rng.randf_range(.35,.85),"lift":rng.randf_range(6,14),"size":2 if i%3==0 else 1})
func wave_radius()->float:
	var t:=clampf(elapsed/lifetime(),0,1)
	return profile.pressure_radius*(.13+.87*(1-pow(1-t,3)))
func samples()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if not started or not enabled or not profile.pressure_enabled or elapsed<=0 or elapsed>=lifetime() or profile.pressure_strength<=0 or profile.intensity<=0: return result
	var t:float=elapsed/lifetime()
	var r:=wave_radius()
	var width:float=profile.pressure_thickness*(1-.8*t)
	var grid:float=profile.pixel_size
	var bound:=int(ceil((profile.pressure_radius+profile.pressure_thickness)/grid))
	var ybound:=int(ceil((profile.pressure_radius*profile.pressure_squash+profile.pressure_thickness)/grid))
	for gy in range(-ybound,ybound):
		for gx in range(-bound,bound):
			var point:=Vector2((gx+.5)*grid,(gy+.5)*grid/profile.pressure_squash)
			var distance:=point.length()
			var band:=absf(distance-r)
			var echo:bool=profile.pressure_echo and t>.12 and t<.7 and absf(distance-r*.79)<width*.45
			if band>width and not echo: continue
			var angle:=point.angle()
			var phase:float=angle+float(profile.shape_seed%17)*.11
			# Three broad interrupted lobes, plus uneven small breaks. Never a solid magical aura.
			var lobe:float=sin(phase*3+.4)*.65+sin(phase*7)*.18
			if lobe<-.38+.42*t: continue
			var threshold:float=(BAYER[posmod(gy,4)*4+posmod(gx,4)]+.5)/16.
			if threshold>(1-t)*1.2: continue
			var shade:float=.90 if t<.16 and band<width*.38 else (.68 if t<.45 else .45)
			if echo: shade*=.6
			var color:Color=profile.pressure_color*shade
			if t<.12 and band<width*.25: color=profile.pressure_color.lerp(Color("fff0d5"),.24)
			var strength:float=profile.pressure_strength*profile.intensity
			color=Color(minf(1,color.r*strength),minf(1,color.g*strength),minf(1,color.b*strength),1)
			var x:float=(-gx-1)*grid if profile.facing_left else gx*grid
			result.append({"position":Vector2(x,gy*grid),"color":color,"size":grid})
	# Sparse short-lived grit follows the ellipse, not a second full particle explosion.
	for item in debris:
		if t>.82: continue
		var d:float=profile.pressure_radius*item.distance*(.15+.85*(1-pow(1-t,2)))
		var point:=Vector2(cos(item.angle)*d,sin(item.angle)*d*profile.pressure_squash-item.lift*sin(PI*t))
		point=(point/grid).floor()*grid
		var size:float=item.size*grid
		if profile.facing_left: point.x=-point.x-size
		var color:Color=profile.pressure_color*(.65 if t<.35 else .35)*profile.pressure_strength*profile.intensity
		color=Color(minf(1,color.r),minf(1,color.g),minf(1,color.b),1)
		result.append({"position":point,"color":color,"size":size})
	return result
func _draw()->void:
	for sample in samples():
		if draw_half<0 and sample.position.y>=0: continue
		if draw_half>0 and sample.position.y<0: continue
		draw_rect(Rect2(sample.position,Vector2.ONE*sample.size),sample.color)
