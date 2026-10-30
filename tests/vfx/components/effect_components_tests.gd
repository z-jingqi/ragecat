extends SceneTree
const Composition=preload("res://scripts/vfx_lab/components/effect_composition.gd")
const Lines=preload("res://scripts/vfx/gathering_lines/pixel_gathering_lines.gd")
const Orb=preload("res://scripts/vfx/pulsing_orb/pixel_pulsing_orb.gd")
const Glow=preload("res://scripts/vfx/character_glow/pixel_character_glow.gd")
# SHA256 of canonical numeric rectangle/color command arrays captured BEFORE
# modular refactoring, including the complete character demo and old orb core.
# No external baseline files or machine-specific paths are required by this test.
const BASELINE=[
[0.0,-1.0,"6b8475cd52cba65c423afc2b7a3d72349dbaf064d288e106f5cea23fd32b5924","4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"],
[0.2,-1.0,"a5902a7da2eec2031650b2bcc86eb5b295f93636a4d26b700ce227402733ef8f","477464b2ae8ee450c1db0a848e8c68d3b46f9e0b7b2554092a4b4810232b360c"],
[0.35,-1.0,"ceae4dc9373ff0bfb592cdc2846f9f9c93ca13a9dd97a32a199fe40fb4b7b131","cf4e8b5613e8aa31a5287da88d8ca036a87e7489e9c280be982b6ce1376e3608"],
[0.6,-1.0,"d691b9bcd22f5250a7a5fa2c137a9b2d4a2a642284e340e42066567779ffcdd6","b18f44e5ac8cb2dc84f9312091f5e5c52c63c3023011f91f3b9cf5c926da14b6"],
[0.9,-1.0,"52bfcac265cbc0aebd2b66dfd87216ddbce8cbac68801e06672d14c22de55337","6bbfb42f487d7bc0d69caa9b0cedcd8c24960109462b52bcb78df4de7b813635"],
[1.2,-1.0,"fae307027bf20c7b06e32160f23d2711e80ac05e70f74a06e47654b1b0e5097c","cf4e8b5613e8aa31a5287da88d8ca036a87e7489e9c280be982b6ce1376e3608"],
[1.07,1.0,"3b17d314a1fe57afb1fa125ab5636eb7f08baf7e2c90c53171d0a88fa2d332ec","4b9a5f05e313a21154adbbdc72d39342fe06ad38d9842f35ee381852a1df6e5f"],
[1.2,1.0,"6b8475cd52cba65c423afc2b7a3d72349dbaf064d288e106f5cea23fd32b5924","4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945"]]
var checks:=0
var failures:=0
func check(condition:bool,message:String)->void:
 checks+=1
 if not condition: failures+=1;push_error(message)
func fingerprint(commands:Array)->String:
 var encoded:Array=[]
 for c in commands:
  encoded.append({"type":c.type,"rect":[c.rect.position.x,c.rect.position.y,c.rect.size.x,c.rect.size.y],"color":[c.color.r,c.color.g,c.color.b,c.color.a]})
 return JSON.stringify(encoded).sha256_text()
func _initialize()->void: call_deferred("run")
func run()->void:
 var character=Composition.new();character.setup(true)
 var orb_composition=Composition.new();orb_composition.setup(false)
 for frame in BASELINE:
  character.time=frame[0];character.stop_at=frame[1]
  orb_composition.orb.time=frame[0];orb_composition.orb.stop_at=frame[1]
  check(fingerprint(character.build_commands())==frame[2],"Character pre-refactor command baseline t=%s stop=%s"%[frame[0],frame[1]])
  check(fingerprint(orb_composition.orb.build_commands())==frame[3],"Orb pre-refactor command baseline t=%s stop=%s"%[frame[0],frame[1]])
 check(character.lines.get_script()==orb_composition.lines.get_script(),"Both compositions use the exact same line renderer")
 check(character.lines.behavior.get_script()==orb_composition.lines.behavior.get_script(),"Both compositions use shared line behavior")
 check(character.lines.behavior.config!=orb_composition.lines.behavior.config,"Composition instances own independent line settings")
 check(character.lines.behavior.config.center_offset_y==-38 and orb_composition.lines.behavior.config.center_offset_y==0,"Placement adapters independent of line algorithm")
 var components=[Lines.new(),Orb.new(),Glow.new()]
 for component in components:
  var behavior=component.behavior
  check(is_inf(behavior.duration()),"Component holds until explicitly stopped")
  check(behavior.sample(1000).phase=="HOLD","Long-running component sustains")
  check(not behavior.sample(behavior.duration(1),1).active,"Explicit stop cleans component")
  var source=behavior.config.duplicate(true)
  behavior.configure(source)
  source.intensity=0.2
  check(behavior.config.intensity!=source.intensity,"Configure clones caller Resource")
  for spec in behavior.config.SPECS:
   var original=behavior.config.get(spec[0])
   behavior.config.set(spec[0],NAN);behavior.config.sanitize()
   check(is_equal_approx(behavior.config.get(spec[0]),spec[5]),"Nonfinite parameter default: "+spec[0])
   behavior.config.set(spec[0],spec[2]-100);behavior.config.sanitize()
   check(is_equal_approx(behavior.config.get(spec[0]),spec[2]),"Parameter lower clamp: "+spec[0])
   behavior.config.set(spec[0],spec[3]+100);behavior.config.sanitize()
   check(is_equal_approx(behavior.config.get(spec[0]),spec[3]),"Parameter upper clamp: "+spec[0])
   behavior.config.set(spec[0],original)
  var stable:=true;var finite:=true;var bounded:=true
  for frame in range(61):
   component.time=frame/30.0;component.stop_at=1.0
   var commands:Array=component.build_commands().duplicate(true)
   stable=stable and commands==component.build_commands()
   bounded=bounded and commands.size()<10000
   for command in commands:
    finite=finite and command.rect.position.is_finite() and command.rect.size.is_finite() and is_finite(command.color.a)
  check(stable and finite and bounded,"Deterministic finite bounded component commands")
  component.time=behavior.duration(1);check(component.build_commands().is_empty(),"Standalone component disappears after explicit stop")
  check(component.get_child_count()==0,"Component allocates no per-event scene nodes")
  component.free()
 character.time=0.6;character.stop_at=-1
 orb_composition.time=0.6;orb_composition.stop_at=-1
 var old_orb:Array=orb_composition.orb.build_commands().duplicate(true)
 var old_glow:Array=character.glow.build_foot().duplicate(true)
 character.lines.behavior.config.main_color=Color.MAGENTA
 check(character.glow.build_foot()==old_glow and orb_composition.orb.build_commands()==old_orb,"Line palette edits do not leak to glow or orb")
 var line=Lines.new();line.time=0.6
 var original_lines:Array=line.build_commands().duplicate(true)
 line.behavior.config.main_color=Color.MAGENTA
 check(line.build_commands()!=original_lines,"Line color control affects rendering")
 var orb=Orb.new();orb.time=0.6
 var original_orb:Array=orb.build_commands().duplicate(true)
 orb.behavior.config.core_color=Color.RED
 check(orb.build_commands()!=original_orb,"Orb core color independently changes rendering")
 var glow=Glow.new();glow.time=0.6
 var single_rect: Array=[{"rect":Rect2(10,10,4,4),"color":Color.WHITE}]
 check(glow.build_contour(single_rect).size()>1,"Single-rectangle host receives contour and rim")
 check(glow.build_contour(single_rect,1).size()==1,"Explicit host exclusion skips shadow without removing actor")
 var original_glow:Array=glow.build_foot().duplicate(true)
 glow.behavior.config.floor_tint=Color.BLUE
 check(glow.build_foot()!=original_glow,"Glow tint independently changes floor rendering")
 var unique:Dictionary={};var deterministic:=true;var safe:=true
 for i in range(28):
  var event:Dictionary=line.behavior.energy_event(i,0.6)
  deterministic=deterministic and event==line.behavior.energy_event(i,0.6)
  safe=safe and event.life>=0 and event.life<=1 and event.angle>=0 and event.angle<TAU and event.length>=5 and event.length<=20
  unique[str(event.angle)]=true
 check(deterministic and safe and unique.size()>20,"Shared line random events stable, varied and bounded")
 orb_composition.show_lines=false;orb_composition.show_orb=true
 var orb_only:Array=orb_composition.build_commands().duplicate(true)
 orb_composition.show_orb=false
 check(orb_only.size()>orb_composition.build_commands().size(),"Composition independently toggles orb")
 orb_composition.show_lines=true
 check(orb_composition.build_commands().size()>1,"Composition independently toggles shared lines")
 for scene_path in ["res://scenes/vfx_lab/components/orb_composition.tscn","res://scenes/vfx_lab/components/character_composition.tscn"]:
  var lab=load(scene_path).instantiate();root.add_child(lab);lab.set_process(false)
  check(lab.fields.size()==24 and lab.colors.size()==11,"Three component property panels expose independent controls")
  lab.auto_demo=false;lab._process(10)
  check(lab.stop_at<0 and lab.playing,"Manual composition sustains")
  lab.stop_effects();var first_stop:float=lab.stop_at;lab.clock+=0.1;lab.stop_effects()
  check(lab.stop_at==first_stop,"Repeated stop does not reset cleanup")
  lab.fields["Gathering lines/radius"].value=50
  check(lab.gathering_settings.radius==50 and lab.clock==0 and lab.stop_at<0,"Line SpinBox updates Resource and resets presentation")
  var orb_color:Color=lab.orb_settings.body_color
  lab.colors["Gathering lines/main_color"].color_changed.emit(Color.RED)
  check(lab.gathering_settings.main_color==Color.RED and lab.orb_settings.body_color==orb_color,"Color picker signal does not affect another component")
  lab.switches.show_lines.button_pressed=false
  check(not lab.renderer.show_lines,"Component checkbox actually disables line renderer")
  lab.clock=0.6;lab.renderer.time=0.6
  lab.reset_defaults();lab.renderer.time=0.6
  var defaults:Array=lab.renderer.build_commands().duplicate(true)
  lab.apply_palette();lab.renderer.time=0.6
  check(lab.renderer.build_commands()!=defaults,"Alternate palette visibly changes composition")
  lab.reset_defaults();lab.renderer.time=0.6
  check(lab.renderer.build_commands()==defaults,"Reset exactly restores default composed command stream")
  var count:int=lab.get_child_count()
  for i in range(20):lab.apply_palette();lab.reset_defaults()
  check(lab.get_child_count()==count,"Repeated palette/reset does not leak UI nodes")
  if not lab.character_mode:
   lab.orb_settings.dissipate_seconds=1.0;lab.auto_demo=false;lab.looping=false;lab.replay()
   lab.clock=0.6;lab.stop_effects();lab._process(0.6)
   check(lab.playing and lab.clock>0.6,"Preview waits for long orb dissipation instead of stopping early")
   lab._process(1.0)
   check(not lab.playing,"Preview finishes after all active components expire")
  lab.free()
 line.free();orb.free();glow.free();character.free();orb_composition.free()
 print("EFFECT_COMPONENTS: %d checks, %d failures"%[checks,failures]);quit(failures)
