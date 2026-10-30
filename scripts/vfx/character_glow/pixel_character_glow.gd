extends "res://scripts/vfx/shared/pixel_commands.gd"
var behavior=preload("res://scripts/vfx/character_glow/character_glow_behavior.gd").new()
var time:=0.0
var stop_at:=-1.0
var effect_origin:=Vector2(192,132)
var silhouette: Array=[]
func foot_charge(state: Dictionary) -> void:
	var cfg = behavior.config
	var q: float = smoothstep(0.0,0.9,state.charge)
	var energy: float = q*state.opacity*cfg.intensity*cfg.floor_glow
	var breath := 0.96+0.04*sin(time*8.0)
	# Overlapping translucent bands create a soft pixel falloff, not a solid disk.
	for i in range(12):
		var u := float(i)/11.0
		var radii := Vector2(lerpf(84,19,u),lerpf(17,4,u))*(0.6+q*0.4)
		ellipse(effect_origin+Vector2(0,-1),radii,Color(0.02,0.74+u*0.2,0.39,energy*breath*(0.04+u*0.035))*cfg.floor_tint)

func build_foot() -> Array:
	commands=[]
	var state: Dictionary=behavior.sample(time,stop_at)
	if state.active: foot_charge(state)
	return commands
func build_contour(actor: Array, skip_leading_rectangles: int = 0) -> Array:
	commands=[]
	var state: Dictionary=behavior.sample(time,stop_at)
	var energy: float=state.charge*state.opacity*behavior.config.intensity
	# Optional exclusion belongs to the host (the lab excludes its floor shadow).
	var width: float = behavior.config.halo_width
	var tremble := Vector2((1 if floori(time*20)%2==0 else -1) if energy>0.65 and state.charge<0.98 else 0,0)
	if energy>0.02:
		# Merge each scanline once, then dilate it: soft outline follows the body, not a circular aura.
		var rows: Dictionary = {}
		for command in actor.slice(clampi(skip_leading_rectangles,0,actor.size())):
			var box: Rect2=command.rect
			for y in range(int(box.position.y),int(box.end.y)):
				var span: Vector2=rows.get(y,Vector2(1000,-1000))
				rows[y]=Vector2(minf(span.x,box.position.x),maxf(span.y,box.end.x))
		for pad in range(ceili(width),0,-1):
			var expanded: Dictionary = {}
			for y in rows:
				for dy in range(-pad,pad+1):
					var side := floorf(sqrt(maxf(0,pad*pad-dy*dy)))
					var span: Vector2=expanded.get(y+dy,Vector2(1000,-1000))
					expanded[y+dy]=Vector2(minf(span.x,rows[y].x-side),maxf(span.y,rows[y].y+side))
			var alpha: float=energy*(0.055 if pad>2 else 0.18)
			for y in expanded:
				var span: Vector2=expanded[y]
				rect(Rect2(Vector2(span.x,y)+tremble,Vector2(span.y-span.x,1)),Color(behavior.config.contour_color,alpha*behavior.config.contour_color.a))
		for offset in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
			for command in actor.slice(clampi(skip_leading_rectangles,0,actor.size())):
				var box: Rect2=command.rect
				rect(Rect2(box.position+offset+tremble,box.size),Color(behavior.config.rim_color,energy*0.85*behavior.config.rim_color.a))
	for command in actor:
		var box: Rect2=command.rect
		rect(Rect2(box.position+tremble,box.size),command.color.lerp(behavior.config.body_tint,energy*0.04))
	return commands
func build_commands() -> Array:
	var floor_commands:=build_foot().duplicate()
	return floor_commands+build_contour(silhouette)
