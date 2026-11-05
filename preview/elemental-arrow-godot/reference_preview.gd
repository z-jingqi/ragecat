extends Node2D
# Native presentation: large design source plus actual game-size movement.
const FX=preload("components/elemental_arrow.gd")
const P=preload("presets/lightning.tres")
var frame=0
var time=0.0
var paused=false
var capture=false
var light=false
var effects=[]
var sizes=[256.0,64.0,96.0,128.0]
var background:ColorRect
var status:Label
func label(text:String,at:Vector2,size:int=18)->Label:
	var l=Label.new(); l.text=text; l.position=at; l.add_theme_font_size_override("font_size",size); add_child(l); return l
func button(text:String,at:Vector2,action:Callable)->void:
	var b=Button.new(); b.text=text; b.position=at; add_child(b); b.pressed.connect(action)
func _ready()->void:
	get_window().size=Vector2i(1280,800)
	capture="--capture" in OS.get_cmdline_user_args()
	background=ColorRect.new(); background.size=Vector2(1280,800); background.color=Color("101119"); add_child(background)
	label("LIGHTNING ARROW / REFERENCE STUDY",Vector2(34,24),28)
	label("Transient arcs • travel, cross, vanish • reference-like peak is brief",Vector2(35,64),17)
	var premult=CanvasItemMaterial.new(); premult.blend_mode=CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	for i in 4:
		var vp=SubViewport.new(); vp.size=Vector2i(320,116) if i==0 else Vector2i(380,200); vp.transparent_bg=true; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; add_child(vp)
		var fx=FX.new(); vp.add_child(fx); var config=P.duplicate(true); config.length=sizes[i]; config.body_style=1; config.lightning.arc_forks=1.4
		fx.play(Vector2(290,58) if i==0 else Vector2(220,100),Vector2.RIGHT,config); effects.append(fx)
		var panel=TextureRect.new(); panel.texture=vp.get_texture(); panel.material=premult; panel.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		panel.position=Vector2(160,115) if i==0 else Vector2(38+(i-1)*412,525)
		panel.size=Vector2(960,348) if i==0 else Vector2(380,200); add_child(panel)
		if i>0: label("%dpx / actual 1x"%sizes[i],Vector2(42+(i-1)*412,487),18)
	status=label("",Vector2(35,728),17)
	button("Replay",Vector2(875,725),replay)
	button("Pause",Vector2(970,725),func(): paused=not paused)
	button("Light / Dark",Vector2(1060,725),toggle_background)
func replay()->void:
	time=0; frame=0; paused=false
	for i in effects.size():
		var fx=effects[i]
		fx.play(Vector2(290,58) if i==0 else Vector2(sizes[i]+24,100),Vector2.RIGHT*120,fx.profile)
func toggle_background()->void:
	light=not light; background.color=Color("d7d2c4") if light else Color("101119")
	for node in get_children():
		if node is Label: node.add_theme_color_override("font_color",Color("19202b") if light else Color("e8e9ec"))
func _process(delta:float)->void:
	if capture: time=float(frame)/60.0
	elif not paused: time+=delta
	var names=["RIGHT", "LEFT", "DIAGONAL", "CURVE", "STATIONARY", "RESTRIKE DETAIL"]
	var phase=int(time/2.0)%6
	for i in 4:
		var fx=effects[i]; var tip=Vector2(290,58); var axis=Vector2.RIGHT
		if i>0:
			var t=fposmod(time,2.0); var u=t/2.0
			match phase:
				0: tip=Vector2(sizes[i]+24+(320-sizes[i])*u,100)
				1: tip=Vector2(350-sizes[i]-(320-sizes[i])*u,100); axis=Vector2.LEFT
				2: tip=Vector2(sizes[i]*.93+20+150*u,116-60*u); axis=Vector2(150,-60).normalized()
				3:
					tip=Vector2(145+160*u,100-20*sin(u*PI*2)); axis=Vector2(160,-40*PI*cos(u*PI*2)).normalized()
				_: tip=Vector2(190+sizes[i]*.5,100)
		# Each pose is attached live; no motion-history particles in this effect.
		fx.advance(0 if paused else delta,tip,axis*120)
		fx.age=time; fx.queue_redraw()
	status.text=names[phase]+"  |  %.2fs  |  sizes remain configurable"%time
	if capture:
		frame+=1
		if frame in [30,90,150,270,390,510,630,690]: save_frame(frame)
		if frame>=720: get_tree().quit()
func save_frame(index:int)->void:
	await RenderingServer.frame_post_draw
	var folder=OS.get_environment("ARROW_CAPTURE_DIR")
	if not folder.is_empty(): get_viewport().get_texture().get_image().save_png(folder.path_join("design-%03d.png"%index))
