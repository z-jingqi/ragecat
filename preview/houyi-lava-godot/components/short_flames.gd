extends "component.gd"
## Deliberately low, sparse heat vents. Height/brightness do not grow with area.
func count() -> int:
	return mini(24,int(round(profile.flame_count*profile.detail_scale())))

func _draw() -> void:
	if done or age < profile.opening_time: return
	var heat: float = profile.heat_at(age)
	if heat <= 0: return
	for i in range(count()):
		var t := fposmod(age + hashf(i,8)*profile.flame_period,profile.flame_period)
		if t > 0.65: continue
		var phase := t/0.65
		var env := sin(phase*PI)
		var height: float = profile.flame_height*env*lerpf(0.55,1.,hashf(i,12))*heat
		var pos := site(i,57)
		var hot: Color = profile.flame_color; hot.a = heat*profile.opacity_at(age)
		var red: Color = profile.lava_red; red.a=hot.a
		for j in range(0,int(height)+1,int(profile.pixel_size)):
			var v := float(j)/maxf(1.,height)
			var shift := roundf(sin(age*9.+v*3.+i)*v*2.)
			pixel(pos+Vector2(shift,-j),hot if j<int(height*0.35) else red,Vector2(2 if v<0.5 else 1,1))
		if phase > 0.45 and phase < 0.8:
			pixel(pos+Vector2(sin(float(i))*3.,-height-3.),hot)
