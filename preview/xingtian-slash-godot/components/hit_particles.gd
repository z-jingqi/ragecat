extends "timed_component.gd"
## Seeded streak/drop primitives, informed by Sprite Fusion blood/sparks and PixelFX.
## No stored animation frames, no actor mutation, no automatic collision or hit timing.
@export var blood := false
var particles: Array[Dictionary] = []

func lifetime() -> float:
	return profile.blood_duration if blood else profile.spark_duration

func _rebuild() -> void:
	particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = profile.shape_seed + (127 if blood else 31)
	var count: int = profile.blood_count if blood else profile.spark_count
	var speed: float = profile.blood_speed if blood else profile.spark_speed
	var direction := deg_to_rad(profile.direction_degrees)
	for i in count:
		var angle := direction + rng.randf_range(-0.85,0.70)
		var velocity := Vector2.from_angle(angle)*speed*rng.randf_range(0.55,1.15)
		velocity.y -= rng.randf_range(5,24)
		if profile.facing_left: velocity.x=-velocity.x
		var life := lifetime()*rng.randf_range(0.60,0.93)
		particles.append({"velocity":velocity,"life":life,"delay":rng.randf_range(0,0.02),"size":2 if blood and i%3==0 else 1,"shade":i%3==0})

func samples() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not started or not enabled or elapsed<=0 or elapsed>=lifetime() or profile.intensity<=0: return result
	if blood and not profile.blood_enabled: return result
	if not blood and not profile.sparks_enabled: return result
	for particle in particles:
		var t: float = elapsed-particle.delay
		if t<=0 or t>=particle.life: continue
		var velocity: Vector2 = particle.velocity
		var drag := 2.0 if blood else 3.2
		var displacement := velocity*((1.0-exp(-drag*t))/drag)
		displacement.y += (85.0 if blood else 45.0)*t*t
		var derivative := velocity*exp(-drag*t)+Vector2(0,(170.0 if blood else 90.0)*t)
		var age_fraction: float=t/particle.life
		var color: Color=profile.blood_color if blood else profile.spark_color
		var shade: Color=profile.blood_shade if blood else profile.shade_color
		if not blood and age_fraction<0.20: color=profile.highlight_color
		elif not blood and age_fraction<0.48: color=profile.body_color
		elif age_fraction>0.68 or particle.shade: color=shade
		color=Color(minf(1,color.r*profile.intensity),minf(1,color.g*profile.intensity),minf(1,color.b*profile.intensity),1)
		shade=Color(minf(1,shade.r*profile.intensity),minf(1,shade.g*profile.intensity),minf(1,shade.b*profile.intensity),1)
		result.append({"position":displacement,"direction":derivative.normalized(),"length":maxf(0.,(3.8 if blood else 5.2)*(1.0-age_fraction)),"size":particle.size if age_fraction<0.65 else 1,"color":color,"shade":shade})
	return result

func filaments() -> Array[Dictionary]:
	# Three tiny roots detach into the existing droplets; no wound, mist or stain.
	var result: Array[Dictionary] = []
	if not blood or not started or not enabled or not profile.blood_enabled or not profile.blood_filaments_enabled or profile.blood_count==0 or profile.intensity<=0: return result
	if elapsed<=0.0 or elapsed>=0.075: return result
	var rng:=RandomNumberGenerator.new(); rng.seed=profile.shape_seed+227
	var count:=mini(3,int(ceil(profile.blood_count/4.0)))
	var head:=1.0-pow(1.0-minf(1.0,elapsed/0.035),3)
	var tail:=clampf((elapsed-0.025)/0.05,0,1)
	for i in count:
		var angle:=deg_to_rad(profile.direction_degrees)+(-0.45+i*0.45)+rng.randf_range(-0.08,0.08)
		var length:=rng.randf_range(7,12)
		for step in range(int(ceil(length*tail)),int(ceil(length*head))):
			var point:=Vector2.from_angle(angle)*float(step)
			if profile.facing_left: point.x=-point.x
			result.append({"position":point,"color":profile.blood_shade if step<length*0.35 else profile.blood_color})
	return result

func _draw() -> void:
	for filament in filaments():
		var color:Color=filament.color
		color=Color(minf(1,color.r*profile.intensity),minf(1,color.g*profile.intensity),minf(1,color.b*profile.intensity),1)
		pixel(filament.position,color,1)
	for particle in samples():
		var pos: Vector2=particle.position
		var direction: Vector2=particle.direction
		for i in range(int(ceil(particle.length)),0,-1):
			pixel(pos-direction*float(i),particle.shade,1)
		pixel(pos,particle.color,particle.size)
		if blood and particle.size>1: pixel(pos+Vector2(-1 if profile.facing_left else 1,1),particle.shade,1)

func pixel(pos: Vector2,color: Color,side:int) -> void:
	var grid: float=profile.pixel_size
	var snapped:Vector2=(pos/grid).floor()*grid
	if profile.facing_left: snapped.x=-(floorf(-pos.x/grid)+side)*grid
	draw_rect(Rect2(snapped,Vector2.ONE*side*grid),color)
