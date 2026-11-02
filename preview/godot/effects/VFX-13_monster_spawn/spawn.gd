extends Node2D
## Anchor is the intended host's feet. Optional host must be bound before play.
signal appeared
signal completed
const REVEAL = preload("res://effects/VFX-13_monster_spawn/reveal.gdshader")
var duration := 0.55
var radius := 29.0
var particle_count := 12
var ring_width := 1.0
var reveal_at := 0.35
var reveal_span := 0.28
var seed_value := 13
var palette := [Color("4c7b89"),Color("84d6c1"),Color("e2f6cf")]
var host: Sprite2D
var generation := 0
var age := 0.0
var active := false
var did_appear := false
var knots: Array[Dictionary] = []
var saved_material: Material
var saved_visible := false
var owns_host := false
var reveal_material: ShaderMaterial
func configure(values: Dictionary) -> void:
	# Apply between plays, never re-seed ongoing particles.
	if active: return
	duration=clampf(finite_value(values.get("duration",duration),duration),0.18,2.0)
	radius=clampf(finite_value(values.get("radius",radius),radius),10,56)
	particle_count=clampi(int(finite_value(values.get("particle_count",particle_count),particle_count)),0,32)
	ring_width=clampf(finite_value(values.get("ring_width",ring_width),ring_width),1,3)
	reveal_at=clampf(finite_value(values.get("reveal_at",reveal_at),reveal_at),0.1,0.7)
	reveal_span=clampf(finite_value(values.get("reveal_span",reveal_span),reveal_span),0.08,0.9-reveal_at)
	seed_value=int(finite_value(values.get("seed",seed_value),seed_value))
	if values.has("palette") and values.palette.size()==3:
		palette=[]
		for color in values.palette: palette.append(Color.from_string(str(color),Color("84d6c1")))
func finite_value(value: Variant,fallback: float) -> float:
	var number:=float(value) if value is float or value is int else fallback
	return number if is_finite(number) else fallback
func play() -> void:
	cancel()
	age=0; active=true; did_appear=false; knots.clear()
	var rng:=RandomNumberGenerator.new();rng.seed=seed_value
	for i in range(particle_count):
		knots.append({"angle":rng.randf_range(0,TAU),"delay":rng.randf_range(0,0.2),"travel":rng.randf_range(0.22,0.38),"distance":rng.randf_range(0.8,1.3),"height":rng.randf_range(8,27),"size":rng.randi_range(1,2)})
	if is_instance_valid(host):
		saved_material=host.material;saved_visible=host.visible;owns_host=true
		reveal_material=ShaderMaterial.new();reveal_material.shader=REVEAL
		reveal_material.set_shader_parameter("edge_color",palette[2]);host.material=reveal_material;host.visible=true
	update_host();queue_redraw()
func cancel() -> void:
	generation+=1
	active=false; knots.clear()
	restore_host(false);queue_redraw()
func restore_host(success: bool) -> void:
	if owns_host and is_instance_valid(host):
		if host.material==reveal_material:host.material=saved_material
		host.visible=true if success else saved_visible
	owns_host=false;reveal_material=null
func tick(delta: float) -> void:
	if not active or delta<=0 or not is_finite(delta):return
	var current_generation:=generation
	age=minf(age+delta,duration)
	if not did_appear and age+0.000001>=duration*(reveal_at+reveal_span):
		did_appear=true;appeared.emit()
		if generation!=current_generation:return
	update_host()
	if age+0.000001>=duration:
		active=false;knots.clear();restore_host(true);completed.emit()
	queue_redraw()
func update_host() -> void:
	if owns_host and is_instance_valid(host) and reveal_material:
		reveal_material.set_shader_parameter("progress",clampf((age/duration-reveal_at)/reveal_span,0,1))
func _exit_tree() -> void:restore_host(false)
func stamp(p: Vector2,c: Color,size_px: float=1.0) -> void:
	draw_rect(Rect2(p.round(),Vector2.ONE*size_px),c)
func ring(r: float,width: float,color: Color,phase: float) -> void:
	# Rasterized ellipse, bounded <= 115 x 43 pixels, no AA or smooth fading.
	for y in range(-int(ceil(r*0.35+width)),int(ceil(r*0.35+width))+1):
		for x in range(-int(ceil(r+width)),int(ceil(r+width))+1):
			var p:=Vector2(x,y/0.35)
			if absf(p.length()-r)<width:
				var a:=atan2(p.y,p.x)+PI
				if fposmod(a+phase,PI*0.5)<1.3:stamp(Vector2(x,y),color)
func _draw() -> void:
	if not active:return
	var u:=age/duration
	var size_r:=radius*lerpf(1.0,0.55,clampf(u/0.6,0,1))
	if u<0.7:
		ring(size_r,ring_width,palette[1] if u>0.2 else palette[0],u*0.8)
		if u>0.35 and u<0.58:ring(size_r-3,1,palette[2],u*0.8)
	elif u<0.92:
		var t:=(u-0.7)/0.22
		ring(radius*(0.55+t*0.25),1,palette[0],u*0.8)
	for item in knots:
		var q:float=(u-item.delay)/item.travel
		if q<=0 or q>=1:continue
		var start:=Vector2(cos(item.angle)*radius*item.distance,sin(item.angle)*radius*0.35-5)
		var end:=Vector2(0,-item.height)
		var p:=start.lerp(end,q*q)
		stamp(p,palette[2] if q>0.6 else palette[1],item.size)
		if q>0.35:stamp(p+(start-end).normalized()*2,palette[0])
	# Compact arrival brackets at the feet, not a full-screen flash.
	if u>0.58 and u<0.73:
		for side in [-1,1]:
			stamp(Vector2(side*11,-2),palette[2],2)
			stamp(Vector2(side*14,-1),palette[1])
