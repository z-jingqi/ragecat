extends Control
const Composition=preload("res://scripts/vfx_lab/components/effect_composition.gd")
const LineConfig=preload("res://scripts/vfx/gathering_lines/gathering_lines_config.gd")
const OrbConfig=preload("res://scripts/vfx/pulsing_orb/pulsing_orb_config.gd")
const GlowConfig=preload("res://scripts/vfx/character_glow/character_glow_config.gd")
@export var character_mode:=false
@export var gathering_settings: Resource=LineConfig.new()
@export var orb_settings: Resource=OrbConfig.new()
@export var glow_settings: Resource=GlowConfig.new()
var renderer: Node2D
var panel: PanelContainer
var status: Label
var fields: Dictionary={}
var colors: Dictionary={}
var switches: Dictionary={}
var clock:=0.0
var stop_at:=-1.0
var playing:=true
var auto_demo:=true
var looping:=true
var speed:=1.0
var capture_dir:=""
var capture_frame:=0
var capture_busy:=false
func label_at(value: String,at: Vector2,size: int=18) -> Label:
 var node:=Label.new();node.text=value;node.position=at;node.add_theme_font_size_override("font_size",size);add_child(node);return node
func button(value: String,at: Vector2,action: Callable) -> void:
 var node:=Button.new();node.text=value;node.position=at;node.size=Vector2(158,38);node.focus_mode=Control.FOCUS_NONE;node.pressed.connect(action);add_child(node)
func _ready() -> void:
 gathering_settings=gathering_settings.duplicate(true);orb_settings=orb_settings.duplicate(true);glow_settings=glow_settings.duplicate(true)
 var viewport:=SubViewport.new();viewport.size=Vector2i(384,160);viewport.disable_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
 renderer=Composition.new();renderer.lines.behavior.config=gathering_settings;renderer.orb.behavior.config=orb_settings;renderer.glow.behavior.config=glow_settings;renderer.setup(character_mode,false);viewport.add_child(renderer)
 var view:=TextureRect.new();view.texture=viewport.get_texture();view.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;view.position=Vector2(64,152);view.size=Vector2(1152,480);add_child(view)
 label_at("RAGE CAT / COMPOSABLE EFFECT STUDIES",Vector2(64,28),18)
 label_at("GATHERING LINES + "+("CHARACTER GLOW" if character_mode else "PULSING ORB"),Vector2(64,61),28)
 label_at("384 × 160 / 3× NEAREST / ORIGINAL PIXEL COMPONENTS",Vector2(64,108),15)
 for item in [["show_lines","Gathering lines"],["show_orb","Pulsing orb"],["show_glow","Character glow"]]:
  var toggle:=CheckButton.new();toggle.text=item[1];toggle.position=Vector2(64+switches.size()*235,646);toggle.button_pressed=renderer.get(item[0]);toggle.disabled=(item[0]=="show_orb" and character_mode) or (item[0]=="show_glow" and not character_mode);toggle.toggled.connect(func(on): renderer.set(item[0],on));add_child(toggle);switches[item[0]]=toggle
 status=label_at("",Vector2(64,689),16)
 button("Replay [R]",Vector2(64,724),replay);button("Pause [Space]",Vector2(230,724),func():playing=not playing);button("Dissipate [C]",Vector2(396,724),stop_effects);button("Palette [T]",Vector2(562,724),apply_palette);button("Reset defaults",Vector2(728,724),reset_defaults);button("Parameters [P]",Vector2(1000,724),func():panel.visible=not panel.visible)
 build_panel()
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):capture_dir=arg.trim_prefix("--capture-dir=")
 if not capture_dir.is_empty():
  if DisplayServer.get_name()=="headless":push_error("Actual display required for viewport capture");get_tree().quit(1);return
  DirAccess.make_dir_recursive_absolute(capture_dir)
func replay() -> void: clock=0;stop_at=-1;playing=true
func stop_effects() -> void:
 if stop_at<0 and clock>=0.2:stop_at=clock
func sync_fields() -> void:
 for key in fields:fields[key].set_value_no_signal(fields[key].get_meta("resource").get(fields[key].get_meta("property")))
 for key in colors:colors[key].color=colors[key].get_meta("resource").get(colors[key].get_meta("property"))
func copy_defaults(target: Resource,fresh: Resource) -> void:
 for property in fresh.get_property_list():
  if property.usage&PROPERTY_USAGE_SCRIPT_VARIABLE:target.set(property.name,fresh.get(property.name))
func reset_defaults() -> void:
 copy_defaults(gathering_settings,LineConfig.new());copy_defaults(orb_settings,OrbConfig.new());copy_defaults(glow_settings,GlowConfig.new());renderer.setup(character_mode);renderer.show_lines=true;renderer.show_glow=true
 for key in switches:switches[key].set_pressed_no_signal(renderer.get(key))
 sync_fields();replay()
func apply_palette() -> void:
 gathering_settings.main_color=Color("ff8c64");gathering_settings.highlight_color=Color("fff1a8");gathering_settings.glow_color=Color.WHITE
 orb_settings.rim_color=Color("a34b75");orb_settings.body_color=Color("ff976c");orb_settings.inner_color=Color("ffe0a0");orb_settings.core_color=Color("fffbe9")
 glow_settings.floor_tint=Color("ffb069");glow_settings.contour_color=Color("ff8a4a");glow_settings.rim_color=Color("ffe59b");glow_settings.body_tint=Color("ffbe89")
 sync_fields();replay()
func build_panel() -> void:
 panel=PanelContainer.new();panel.position=Vector2(812,152);panel.size=Vector2(405,480);add_child(panel)
 var scroll:=ScrollContainer.new();scroll.custom_minimum_size=Vector2(405,480);panel.add_child(scroll)
 var list:=VBoxContainer.new();list.custom_minimum_size.x=380;scroll.add_child(list)
 for entry in [["Gathering lines",gathering_settings,["main_color","highlight_color","glow_color"]],["Pulsing orb",orb_settings,["rim_color","body_color","inner_color","core_color"]],["Character glow",glow_settings,["floor_tint","contour_color","rim_color","body_tint"]]]:
  var resource: Resource=entry[1]
  var fold:=Button.new();fold.text=entry[0]+" ▾";list.add_child(fold)
  var grid:=GridContainer.new();grid.columns=2;list.add_child(grid);grid.visible=entry[0]=="Gathering lines";fold.pressed.connect(func():grid.visible=not grid.visible)
  for spec in resource.SPECS:
   var label:=Label.new();label.text=spec[1];label.add_theme_font_size_override("font_size",13);grid.add_child(label)
   var input:=SpinBox.new();input.min_value=spec[2];input.max_value=spec[3];input.step=spec[4];input.value=resource.get(spec[0]);input.custom_minimum_size.x=118;input.set_meta("resource",resource);input.set_meta("property",spec[0]);grid.add_child(input)
   fields[entry[0]+"/"+spec[0]]=input
   input.value_changed.connect(func(value):resource.set(spec[0],value);resource.sanitize();sync_fields();replay())
  for property in entry[2]:
   var label:=Label.new();label.text=property.replace("_"," ");label.add_theme_font_size_override("font_size",13);grid.add_child(label)
   var picker:=ColorPickerButton.new();picker.color=resource.get(property);picker.custom_minimum_size=Vector2(118,28);picker.set_meta("resource",resource);picker.set_meta("property",property);grid.add_child(picker);colors[entry[0]+"/"+property]=picker
   picker.color_changed.connect(func(value):resource.set(property,value);resource.sanitize())
 var close:=Button.new();close.text="Close [Esc]";close.pressed.connect(func():panel.hide());list.add_child(close);panel.hide()
func _unhandled_key_input(event: InputEvent) -> void:
 if not event.is_pressed() or event.is_echo():return
 match event.keycode:
  KEY_P:panel.visible=not panel.visible
  KEY_ESCAPE:panel.hide();get_viewport().gui_release_focus()
  KEY_R:replay()
  KEY_C:stop_effects()
  KEY_SPACE:playing=not playing
  KEY_A:auto_demo=not auto_demo;replay()
  KEY_L:looping=not looping
  KEY_B:renderer.bright=not renderer.bright
  KEY_T:apply_palette()
  KEY_RIGHT:playing=false;clock+=1.0/60
func composition_duration() -> float:
 var end:=stop_at
 if renderer.show_lines:end=maxf(end,renderer.lines.behavior.duration(stop_at))
 if character_mode and renderer.show_glow:end=maxf(end,renderer.glow.behavior.duration(stop_at))
 if not character_mode and renderer.show_orb:end=maxf(end,renderer.orb.behavior.duration(stop_at))
 return end
func _process(delta: float) -> void:
 if renderer==null or capture_busy:return
 var stop_time:=1.25 if character_mode else 1.1
 if not capture_dir.is_empty():
  var limit:=360 if character_mode else 720
  if capture_frame>=limit:get_tree().quit();return
  clock=(capture_frame%90)/60.0;stop_at=stop_time
  if capture_frame==180:apply_palette()
  clock=(capture_frame%90)/60.0;stop_at=stop_time
  renderer.bright=capture_frame>=270
  if capture_frame==270:renderer.show_lines=false;switches.show_lines.set_pressed_no_signal(false)
  if capture_frame==315:renderer.show_lines=true;switches.show_lines.set_pressed_no_signal(true)
 elif playing:
  clock+=delta*speed
  if auto_demo and stop_at<0 and clock>=stop_time:stop_at=stop_time
  if stop_at>=0 and clock>=composition_duration():
   if looping:replay()
   else:playing=false
 renderer.time=clock;renderer.stop_at=stop_at;renderer.queue_redraw()
 status.text="%s / %.3fs / %s / %s · A sustain · B backdrop · T palette · → step"%[renderer.lines.behavior.sample(clock,stop_at).phase,clock,"AUTO" if auto_demo else "MANUAL","PLAY" if playing else "PAUSED"]
 if not capture_dir.is_empty():capture_busy=true;call_deferred("save_frame")
func save_frame() -> void:
 await RenderingServer.frame_post_draw
 var error:=get_viewport().get_texture().get_image().save_png(capture_dir.path_join("frame_%04d.png"%capture_frame))
 if error!=OK:push_error("Capture failed");get_tree().quit(1);return
 capture_frame+=1;capture_busy=false
