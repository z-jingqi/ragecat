extends Node2D
## Geometry/countdown is authoritative input. This component never applies damage.
signal activated(area: Dictionary)
signal finished
const DEFAULT_AREA = {"shape":"circle", "radius":42.0, "inner_radius":23.0, "angle_deg":90.0, "length":84.0, "width":28.0, "orientation_deg":0.0, "countdown":1.25}
const DEFAULT_STYLE = {"line_width":1.0, "fill_alpha":0.23, "boundary_color":"f5b65a", "fill_color":"c15b44", "ready_color":"ffe7a3", "hatch_spacing":6, "release":0.14}
var automatic := true
var active := false
var elapsed := 0.0
var area := {}
var style := {}
var duration := 0.0
var fired := false
var host:Node2D
var follow := false
var offset := Vector2.ZERO
var serial := 0
var texture:ImageTexture
var image:Image
func _ready() -> void:
	image=Image.create(128,128,false,Image.FORMAT_RGBA8)
	texture=ImageTexture.create_from_image(image)
	queue_redraw()
func _process(dt:float) -> void:
	if automatic:tick(dt)
func play(anchor:Vector2, authority:Dictionary={}, visuals:Dictionary={}, target:Node2D=null, follow_target:bool=false) -> void:
	serial+=1;elapsed=0;fired=false;active=true;position=anchor;host=target;follow=follow_target
	area=DEFAULT_AREA.duplicate();area.merge(authority,true)
	if not area.shape in ["circle","ring","sector","rectangle"]:area.shape="circle"
	for k in ["radius","length","width","inner_radius","angle_deg","countdown","orientation_deg"]:
		if not is_finite(float(area[k])):area[k]=DEFAULT_AREA[k]
	area.radius=clampf(area.radius,4,54);area.length=clampf(area.length,8,96);area.width=clampf(area.width,4,56)
	area.inner_radius=clampf(area.inner_radius,0,area.radius-2);area.angle_deg=clampf(area.angle_deg,5,360);area.countdown=clampf(area.countdown,0.1,10)
	style=DEFAULT_STYLE.duplicate();style.merge(visuals,true)
	for key in ["line_width","fill_alpha","release","hatch_spacing"]:
		if not is_finite(float(style[key])):style[key]=DEFAULT_STYLE[key]
	for key in ["boundary_color","fill_color","ready_color"]:
		if not Color.html_is_valid(str(style[key])):style[key]=DEFAULT_STYLE[key]
	style.line_width=clampf(float(style.line_width),1,3);style.fill_alpha=clampf(float(style.fill_alpha),0,0.5);style.release=clampf(float(style.release),0,0.4);style.hatch_spacing=clampi(int(style.hatch_spacing),4,12)
	duration=area.countdown+style.release
	offset=anchor-target.position if is_instance_valid(target) else Vector2.ZERO
	_render()
func cancel() -> void:
	serial+=1;active=false;host=null;_render()
func reset() -> void:
	cancel();elapsed=0;fired=false
func tick(dt:float) -> void:
	if not active or dt<=0 or not is_finite(dt):return
	if follow:
		if not is_instance_valid(host):cancel();return
		position=host.position+offset
	elapsed=minf(elapsed+dt,duration)
	var token:=serial
	if not fired and elapsed+0.0000001>=area.countdown:
		fired=true
		var snapshot:=area.duplicate();snapshot["origin"]=position
		activated.emit(snapshot)
		if serial!=token:return
	if elapsed+0.0000001>=duration:
		active=false;host=null;_render();finished.emit();return
	_render()
func _local_point(world:Vector2) -> Vector2:
	return (world-position).rotated(-deg_to_rad(float(area.orientation_deg)))
func contains_world(world:Vector2) -> bool:
	return not area.is_empty() and inside(_local_point(world))
func inside(p:Vector2) -> bool:
	match area.shape:
		"circle":return p.length()<=area.radius+0.0001
		"ring":return p.length()<=area.radius+0.0001 and p.length()>=area.inner_radius-0.0001
		"sector":return p.length()<=area.radius+0.0001 and (p.length()<0.0001 or absf(p.angle())<=deg_to_rad(area.angle_deg*0.5)+0.0001)
		"rectangle":return absf(p.x)<=area.length*0.5+0.0001 and absf(p.y)<=area.width*0.5+0.0001
	return false
func progress_at(p:Vector2) -> float:
	match area.shape:
		"rectangle":return (p.x+area.length*0.5)/area.length
		"ring":return (p.length()-area.inner_radius)/(area.radius-area.inner_radius)
	return p.length()/area.radius
func _render() -> void:
	if not image:return
	image.fill(Color.TRANSPARENT)
	if active:
		var progress:=clampf(elapsed/area.countdown,0,1)
		var exit_amount:=1.0 if not fired else (1.0-clampf((elapsed-area.countdown)/maxf(style.release,0.0001),0,1))
		var rim:=Color(style.boundary_color);var fill:=Color(style.fill_color);var ready:=Color(style.ready_color)
		for y in range(128):
			for x in range(128):
				var local:=Vector2(x-64,y-64).rotated(-deg_to_rad(area.orientation_deg))
				if not inside(local):continue
				var boundary:=false
				for direction in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
					if not inside(local+direction*style.line_width):boundary=true;break
				var c:=Color(fill,style.fill_alpha*0.35)
				if progress_at(local)<=progress:
					c=Color(fill,style.fill_alpha)
					if (x+y)%int(style.hatch_spacing)==0:c=Color(rim,style.fill_alpha+0.14)
				if boundary:c=ready if fired else rim
				c.a*=exit_amount
				image.set_pixel(x,y,c)
	texture.update(image);queue_redraw()
func _draw() -> void:
	if texture:draw_texture(texture,Vector2(-64,-64))
