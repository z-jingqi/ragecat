extends Node2D
## Independent visual support component; never modifies host state or health.
signal finished
signal phase_changed(phase: String)
const DEFAULTS={"mode":"shield","radius":23.0,"height":29.0,"enter":0.18,"sustain":2.4,"exit":0.28,"intensity":0.60,"particles":12,"rise_speed":26.0,"seed":41,"body":"57b9bb","core":"b8e7cf","edge":"34727e","plus":"45dc58","plus_count":4,"plus_size":2}
const HEAL_PALETTE={"body":"43c957","core":"91e875","edge":"27843a"}
var config:Dictionary=DEFAULTS.duplicate()
var generation=0
var automatic=true
var active=false
var elapsed=0.0
var duration=0.0
var phase="idle"
var anchor=Vector2.ZERO
var host_ref:WeakRef
var host_offset=Vector2.ZERO
var stop_age=-1.0
var broken=false
var impact_age=-1.0
var impact_angle=0.0
var impact_strength=0.0
func _process(dt:float)->void:
	if automatic:tick(dt)
func play(point:Vector2,overrides:Dictionary={},host:Node2D=null,offset:Vector2=Vector2.ZERO)->void:
	clear();config=DEFAULTS.duplicate()
	if overrides.get("mode","shield")=="heal":config.merge(HEAL_PALETTE,true)
	config.merge(overrides,true)
	var limits={"radius":Vector2(8,34),"height":Vector2(12,38),"enter":Vector2(.06,1),"sustain":Vector2(.1,30),"exit":Vector2(.08,1),"intensity":Vector2(0,1),"particles":Vector2(0,32),"rise_speed":Vector2(8,60),"plus_count":Vector2(0,8),"plus_size":Vector2(1,5)}
	for k in limits:
		var v=float(config[k]);config[k]=clampf(v if is_finite(v) else float(DEFAULTS[k]),limits[k].x,limits[k].y)
	config.plus_count=int(config.plus_count);config.plus_size=int(config.plus_size);config.particles=int(config.particles);config.seed=int(config.seed)
	if config.mode not in ["shield","heal"]:config.mode="shield"
	for k in ["core","body","edge","plus"]:
		if not Color.html_is_valid(str(config[k])):config[k]=HEAL_PALETTE.get(k,DEFAULTS[k]) if config.mode=="heal" else DEFAULTS[k]
	anchor=point;host_offset=offset;host_ref=weakref(host) if is_instance_valid(host) else null
	elapsed=0;duration=config.enter+config.sustain+config.exit;active=true;set_phase("enter");queue_redraw()
func set_phase(value:String)->void:
	if phase!=value:phase=value;phase_changed.emit(value)
func clear()->void:
	generation+=1;active=false;elapsed=0;stop_age=-1;broken=false;impact_age=-1;host_ref=null;phase="idle";queue_redraw()
func stop()->void:
	if active and stop_age<0:stop_age=elapsed;set_phase("exit")
func break_shield()->void:
	if active and config.mode=="shield":broken=true;stop()
func hit(direction:Vector2,strength:float=1)->void:
	if active and config.mode=="shield" and stop_age<0:
		impact_angle=direction.angle();impact_age=elapsed;impact_strength=clampf(strength,0,1)
func tick(dt:float)->void:
	if not active or not is_finite(dt) or dt<=0:return
	if host_ref:
		var host=host_ref.get_ref()
		if not is_instance_valid(host):clear();return
		anchor=to_local(host.to_global(host_offset))
	var token=generation
	elapsed+=dt
	if stop_age<0 and elapsed>=config.enter+config.sustain:stop_age=config.enter+config.sustain
	if stop_age>=0:
		set_phase("break" if broken else "exit")
		if not active or token!=generation:return
		if elapsed>=stop_age+config.exit:
			active=false;phase="idle";queue_redraw();finished.emit();return
	elif elapsed>=config.enter:set_phase("sustain")
	queue_redraw()
func rand_slot(i:int)->float:return fposmod(sin(float(i*127+int(config.seed)*19))*43758.5453,1.0)
func color(key:String,scale:float=1)->Color:
	var c=Color(config[key]);c.a=clampf(float(config.intensity)*scale,0,1);return c
func pixel_line(a:Vector2,b:Vector2,c:Color)->void:
	var n=maxi(1,int(ceil(a.distance_to(b))))
	for j in range(n+1):draw_rect(Rect2(a.lerp(b,float(j)/n).round(),Vector2.ONE),c)
func ellipse_point(a:float,r:float,h:float)->Vector2:return Vector2(cos(a)*r,sin(a)*h)
func _draw()->void:
	if not active:return
	var enter=clampf(elapsed/config.enter,0,1)
	var out=clampf((elapsed-stop_age)/config.exit,0,1) if stop_age>=0 else 0.0
	var env=enter*(1-out)
	var center=anchor+Vector2(0,-config.height*.8)
	if config.mode=="shield":
		var radius=float(config.radius)*lerpf(.35,1,sin(enter*PI*.5))
		var height=float(config.height)*lerpf(.35,1,sin(enter*PI*.5))
		for i in range(64):
			var a=TAU*i/64;var b=TAU*(i+1)/64
			var shift=ellipse_point(a,12*out,8*out) if broken else Vector2.ZERO
			if broken and (i%8==0 or out>rand_slot(i)*.7+.3):continue
			var bright=pow(maxf(0,cos(a-elapsed*1.5)),12)
			pixel_line(center+shift+ellipse_point(a,radius,height),center+shift+ellipse_point(b,radius,height),color("core" if bright>.5 else "body",env*(.45+.45*bright)))
		# A few separated reflected arcs, not an opaque filled bubble.
		for i in range(3):
			var a=-2.6+i*.5
			pixel_line(center+ellipse_point(a,radius-2,height-2),center+ellipse_point(a+.16,radius-2,height-2),color("edge",env*.5))
		if impact_age>=0:
			var age=elapsed-impact_age
			if age<.28:
				for i in range(10):
					var a=impact_angle+lerpf(-.45,.45,float(i)/9)*(age/.28+.4)
					pixel_line(center+ellipse_point(a,radius+age*10,height+age*10),center+ellipse_point(a+.04,radius+age*10,height+age*10),color("core",(1-age/.28)*impact_strength*.7*env))
	else:
		for i in range(48):
			var a=TAU*i/48;var b=TAU*(i+1)/48
			pixel_line(anchor+ellipse_point(a,config.radius*enter,config.radius*.22*enter),anchor+ellipse_point(b,config.radius*enter,config.radius*.22*enter),color("edge",env*.45))
		for i in range(config.particles):
			var cycle=(1.5+rand_slot(i+100)*.6)*26.0/config.rise_speed
			var t=fposmod(elapsed+rand_slot(i)*cycle,cycle)/cycle
			var x=(rand_slot(i+20)*2-1)*config.radius*.8+sin(t*4+rand_slot(i)*TAU)*2
			var p=(anchor+Vector2(x,-t*minf(config.rise_speed*cycle,config.height*1.9))).round()
			var fade=sin(t*PI)*env
			draw_rect(Rect2(p,Vector2.ONE),color("core",fade*.7))
		for i in range(config.plus_count):
			var cycle=2.0*26.0/config.rise_speed
			var t=fposmod(elapsed+float(i)*cycle/maxi(1,config.plus_count),cycle)/cycle
			var side=-1 if i%2==0 else 1
			var x=side*config.radius*(.50+.27*rand_slot(i+50))
			var p=(anchor+Vector2(x,-t*config.height*1.7)).round()
			var fade=clampf(t/.12,0,1)*clampf((1-t)/.18,0,1)*env
			draw_plus(p,fade)
func draw_plus(p:Vector2,fade:float)->void:
	# Small auxiliary cross, one logical pixel per arm. No chunky outline.
	var r=int(config.plus_size)
	draw_rect(Rect2(p-Vector2(r,0),Vector2(r*2+1,1)),color("plus",fade*1.5))
	draw_rect(Rect2(p-Vector2(0,r),Vector2(1,r*2+1)),color("plus",fade*1.5))
