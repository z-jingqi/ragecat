extends "component.gd"
## Last optional layer: sparse, low-opacity pixel clusters. Never an opaque screen veil.
func count() -> int:
	return mini(18,int(round(profile.smoke_count*profile.detail_scale())))

func _draw() -> void:
	if done or age < profile.opening_time: return
	var heat: float = profile.heat_at(age)
	if heat <= 0: return
	for i in range(count()):
		var t: float =fposmod(age-profile.opening_time+hashf(i,81)*profile.smoke_period,profile.smoke_period)/profile.smoke_period
		var pos:=site(i,77)+Vector2(sin(t*2.8+float(i))*4.,-t*profile.smoke_height)
		var r: float =2.+t*4.
		var alpha: float = sin(t*PI)*profile.smoke_opacity*heat*profile.opacity_at(age)
		for offset in raster_grid(-Vector2.ONE*r,Vector2.ONE*r):
			var d: float = offset.length()/r
			if d>0.9+0.18*sin(offset.x*2.+offset.y*3.+i): continue
			var color: Color=profile.smoke_color
			color.a=alpha*(1.-d*0.55)
			pixel(pos+offset,color)
