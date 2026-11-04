extends "component.gd"
## Impact accent only, no projectile or attack animation.
func _draw() -> void:
	if done: return
	for i in range(profile.spark_count):
		var delay: float = hashf(i,31)*profile.spark_duration*0.15
		var t := age-delay
		if t < 0: continue
		var life: float = (profile.spark_duration-delay)*lerpf(0.6,1.,hashf(i,32))
		if t>life: continue
		var angle := hashf(i,33)*TAU
		var speed: float = profile.spark_speed*lerpf(0.5,1.,hashf(i,34))
		var velocity := Vector2(cos(angle)*speed,sin(angle)*speed*0.5-22.)
		var pos := velocity*t+Vector2(0,55.*t*t)
		var c: Color = profile.spark_color.lerp(profile.lava_red,t/life)
		c.a *= 1.-smoothstep(0.6,1.,t/life)
		pixel_line(pos-velocity.normalized()*2.,pos,c)
