extends "component.gd"
## Independent sparse domes -> break -> low splash/ripple. Zero count is a true off.
func count() -> int:
	return mini(48, int(round(profile.bubble_count * profile.detail_scale())))

func _draw() -> void:
	if done: return
	var heat: float = profile.heat_at(age)
	var opacity: float = profile.opacity_at(age)
	if age < profile.opening_time * 0.72 or heat <= 0: return
	for i in range(count()):
		var period: float = profile.bubble_period * lerpf(0.8,1.25,hashf(i,2))
		var t := fposmod(age - profile.opening_time + hashf(i,3) * period, period)
		var life := 0.72
		if t > life: continue
		var center := site(i,6)
		var r: float = profile.bubble_radius * lerpf(0.65,1.15,hashf(i,4))
		var c: Color = profile.bubble_color
		c.a = heat * opacity
		var dark := Color("7a302b"); dark.a = c.a
		var hot := Color("ffb95c"); hot.a = c.a * 0.85
		if t < 0.44:
			var expansion := smoothstep(0.,0.24,t)
			var width := maxi(1,int(ceil(r*expansion)))
			var height := maxi(1,int(ceil(r*0.8*expansion)))
			for offset in raster_grid(Vector2(-width,-height),Vector2(width,1)):
				if pow(offset.x/maxf(1.,width),2.)+pow(offset.y/maxf(1.,height),2.) > 1.2: continue
				pixel(center+offset,dark if offset.x>0 or offset.y>0 else c)
			pixel(center+Vector2(-width+1,-height+1),hot,Vector2(2,1))
		else:
			var pop := (t-0.44)/0.28
			var pop_pixels:Dictionary={}
			for k in range(10):
				var a := TAU*float(k)/10.
				var ring := center+Vector2(cos(a),sin(a)*0.42)*r*(1.+pop)
				var ring_color := c; ring_color.a *= 1.-pop
				pop_pixels[ring.snapped(Vector2.ONE*profile.pixel_size)]=ring_color
			for k in range(3):
				var a := -PI*float(k+1)/4.
				var offset := Vector2(cos(a)*r*2.*pop,sin(a)*r*2.6*sin(pop*PI))
				var splash := hot; splash.a *= 1.-pop
				pop_pixels[(center+offset).snapped(Vector2.ONE*profile.pixel_size)]=splash
			for point in pop_pixels: pixel(point,pop_pixels[point])
