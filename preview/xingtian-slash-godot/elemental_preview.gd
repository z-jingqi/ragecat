extends Control
## Three simultaneous design views, same effects at native game size below.
const Profile = preload("elements/element_profile.gd")
const Slash = preload("elements/elemental_slash.gd")
const Fixture = preload("heavy_fixture.gd")
var profiles: Array = []
var effects: Array = []
var fixtures: Array = []
var views: Array = []
var tiles: Array = []
var detail_labels: Array = []
var sliders := {}
var captions := {}
var timeline: HSlider
var status: Label
var pause_button: Button
var speed_button: Button
var mirror_button: CheckButton
var time := 0.
var paused := false
var cleared := false
var speed := 1.
var updating := false
var capture := false
var capture_clock := 0.
var loop_duration := 1.1
var arc_on := true
var attachment_on := true
var debris_on := true

func label_at(text_value: String, point: Vector2, font_size := 16, tint := Color("d6e5ed")) -> Label:
	var label := Label.new(); label.text = text_value; label.position = point
	label.add_theme_font_size_override("font_size", font_size); label.add_theme_color_override("font_color", tint)
	add_child(label); return label
func button_at(text_value: String, point: Vector2, callback: Callable) -> Button:
	var button := Button.new(); button.text = text_value; button.position = point; button.size = Vector2(92,34)
	button.pressed.connect(callback); add_child(button); return button
func check_at(text_value: String, point: Vector2, callback: Callable) -> CheckButton:
	var button := CheckButton.new(); button.text = text_value; button.position = point; button.button_pressed = true
	button.toggled.connect(callback); add_child(button); return button
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label_at("ELEMENTAL SLASHES", Vector2(24,14),28)
	label_at("Fire / lightning / ice  ·  accepted crescent + independent rim attachments",Vector2(24,50),16,Color("8ea7b7"))
	pause_button = button_at("Pause",Vector2(822,20),func(): paused = not paused; pause_button.text = "Resume" if paused else "Pause"; seek_all(time))
	button_at("Replay",Vector2(920,20),replay)
	button_at("Clear",Vector2(1018,20),clear_all)
	speed_button = button_at("Speed 1x",Vector2(1116,20),func(): speed=.25 if speed==1. else 1.; speed_button.text="Speed %.2fx"%speed)
	for i in 3:
		var profile = Profile.new(); profile.element=i; profile.apply_palette(); profiles.append(profile)
		var x := 24 + i*416
		var tint: Color = [Color("ffc47c"),Color("77dbff"),Color("a8eafd")][i]
		label_at(["FIRE  /  curling flame + embers", "LIGHTNING  /  forked blue-white arcs", "ICE  /  faceted edge + fragments"][i],Vector2(x,84),16,tint)
		detail_labels.append(label_at("DETAIL 3x",Vector2(x+8,112),13,Color("7f9aad")))
		for detail in [true,false]:
			var view := SubViewport.new(); view.size=Vector2i(128,96) if detail else Vector2i(384,170)
			view.render_target_update_mode=SubViewport.UPDATE_ALWAYS; view.canvas_item_default_texture_filter=Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
			view.transparent_bg=false; add_child(view); views.append(view)
			var background := ColorRect.new(); background.size=Vector2(view.size); background.color=Color("080f18") if detail else Color("182b33"); view.add_child(background)
			if not detail:
				var fixture = Fixture.new(); fixture.hero_origin=Vector2(192,120); view.add_child(fixture); fixtures.append(fixture)
			var effect = Slash.new(); view.add_child(effect); effects.append(effect)
			var tile := TextureRect.new(); tile.texture=view.get_texture(); tile.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			tile.position=Vector2(x,106 if detail else 438); tile.size=Vector2(384,288) if detail else Vector2(384,170)
			tile.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(tile); tiles.append(tile)
		label_at("1x GAME SCALE  ·  static 76 px character",Vector2(x,410),14,Color("8ea7b7"))
		move_child(detail_labels[-1],get_child_count()-1)
	check_at("Crescent",Vector2(22,622),func(v): arc_on=v; apply_layers())
	check_at("Element rim",Vector2(158,622),func(v): attachment_on=v; apply_layers())
	check_at("Shed particles",Vector2(318,622),func(v): debris_on=v; apply_layers())
	mirror_button=check_at("Mirror",Vector2(502,622),func(v):
		for p in profiles: p.facing_left=v
		for f in fixtures: f.facing_left=v; f.queue_redraw()
		rebuild())
	mirror_button.set_pressed_no_signal(false)
	var settings = [["radius",20.,88.,52.,"Radius"],["thickness",4.,28.,24.,"Blade width"],["edge_reach",3.,25.,15.,"Rim reach"],["attachment_count",0.,12.,6.,"Rim count"],["debris_count",0.,16.,8.,"Particles"]]
	for i in settings.size():
		var spec: Array = settings[i]; var x:=24+i*248
		var caption:=label_at("%s: %d"%[spec[4],spec[3]],Vector2(x,666),14)
		var slider:=HSlider.new(); slider.position=Vector2(x,690); slider.size=Vector2(220,22)
		captions[spec[0]]={"label":caption,"name":spec[4]}
		slider.min_value=spec[1]; slider.max_value=spec[2]; slider.step=1.; slider.value=spec[3]; add_child(slider); sliders[spec[0]]=slider
		slider.value_changed.connect(func(v):
			for p in profiles: p.set(spec[0],v)
			caption.text="%s: %d"%[spec[4],v]; rebuild())
	timeline=HSlider.new(); timeline.position=Vector2(24,732); timeline.size=Vector2(920,24); timeline.min_value=0.; timeline.max_value=loop_duration; timeline.step=.001; add_child(timeline)
	timeline.value_changed.connect(func(v):
		if not updating: paused=true; pause_button.text="Resume"; seek_all(v))
	status=label_at("",Vector2(968,730),15)
	label_at("Visual study only. No damage, collision, hit effects or ground shockwave. Space: pause   R: replay   C: clear",Vector2(24,773),13,Color("78909f"))
	capture=OS.get_cmdline_user_args().has("--element-capture")
	rebuild()

func apply_layers() -> void:
	for effect in effects:
		effect.set_layer_enabled("arc",arc_on); effect.set_layer_enabled("attachment",attachment_on); effect.set_layer_enabled("debris",debris_on)
func rebuild() -> void:
	for i in 3:
		var profile = profiles[i].sanitized(); profiles[i]=profile
		var extent: float = profile.radius + profile.edge_reach * profile.attachment_strength * 1.5
		var compact: bool = profile.radius <= 54. and profile.edge_reach <= 15. and profile.attachment_strength <= 1. and profile.pixel_size <= 1.
		var magnification:=3 if compact else (2 if extent <= 86. and profile.radius <= 78. else 1)
		var view:SubViewport=views[i*2]; view.size=Vector2i(384/magnification,288/magnification)
		view.get_child(0).size=Vector2(view.size)
		detail_labels[i].text="DETAIL %dx"%magnification
		var anchor_x: float = view.size.x * .5 + profile.radius * .15 * (1. if profile.facing_left else -1.)
		effects[i*2].play(Vector2(anchor_x,view.size.y*.68).floor(),profile)
		effects[i*2+1].play(Vector2(192,99),profile)
	for key in sliders:
		sliders[key].set_value_no_signal(profiles[0].get(key))
		captions[key].label.text="%s: %d"%[captions[key].name,profiles[0].get(key)]
	apply_layers()
	if cleared:
		for effect in effects: effect.clear()
	else: seek_all(time)
func seek_all(seconds: float) -> void:
	if not is_finite(seconds): return
	time=clampf(seconds,0,loop_duration)
	if not cleared:
		for effect in effects: effect.seek(maxf(0.,time-.15))
	updating=true; timeline.value=time; updating=false
	status.text=("CLEARED" if cleared else ("PAUSED" if paused else "PLAYING"))+"   %.3f s"%maxf(0.,time-.15)
func clear_all() -> void:
	cleared=true
	for effect in effects: effect.clear()
	seek_all(0.)
func replay() -> void:
	cleared=false; time=0.; rebuild(); paused=false; pause_button.text="Pause"
func _process(delta: float) -> void:
	if capture:
		capture_clock+=delta
		var wanted_speed:=.25 if capture_clock>=4. and capture_clock<8. else 1.
		if speed!=wanted_speed: speed=wanted_speed; speed_button.text="Speed %.2fx"%speed; replay()
		if capture_clock>=8. and not mirror_button.button_pressed: mirror_button.button_pressed=true; replay()
		if capture_clock>=12.: get_tree().quit(); return
	if not paused and not cleared: seek_all(fposmod(time+delta*speed,loop_duration))
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_SPACE: pause_button.pressed.emit()
		elif event.keycode==KEY_R: replay()
		elif event.keycode==KEY_C: clear_all()
