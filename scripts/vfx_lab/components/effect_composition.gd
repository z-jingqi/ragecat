extends "res://scripts/vfx/shared/pixel_commands.gd"
const Lines=preload("res://scripts/vfx/gathering_lines/pixel_gathering_lines.gd")
const Orb=preload("res://scripts/vfx/pulsing_orb/pixel_pulsing_orb.gd")
const Glow=preload("res://scripts/vfx/character_glow/pixel_character_glow.gd")
const Actor=preload("res://scripts/vfx_lab/components/practice_actor.gd")
var lines=Lines.new()
var orb=Orb.new()
var glow=Glow.new()
var time:=0.0
var stop_at:=-1.0
var bright:=false
var character_mode:=false
var show_lines:=true
var show_orb:=true
var show_glow:=true
func _init() -> void:
 for component in [lines,orb,glow]:
  add_child(component);component.visible=false
func setup(character: bool, configure_defaults: bool=true) -> void:
 character_mode=character
 show_orb=not character
 if not character:
  lines.effect_origin=Vector2(192,80)
  if not configure_defaults:return
  lines.behavior.config.radius=48
  lines.behavior.config.center_offset_y=0
  lines.behavior.config.upper_scale=1
  lines.behavior.config.lower_scale=1
  lines.behavior.config.end_radius=13
func build_commands() -> Array:
 for component in [lines,orb,glow]:
  component.time=time;component.stop_at=stop_at
 commands=[]
 if character_mode:
  Actor.background(self)
  if show_glow: commands.append_array(glow.build_foot())
  if show_lines: commands.append_array(lines.build_commands())
  var earlier:=commands
  commands=[]
  var state: Dictionary=glow.behavior.sample(time,stop_at)
  Actor.draw_body(self,state)
  var actor:=commands
  commands=earlier
  if show_glow: commands.append_array(glow.build_contour(actor,1))
  else: commands.append_array(actor)
 else:
  rect(Rect2(0,0,384,160),Color("b8b9b0") if bright else Color("131c25"))
  if show_lines: commands.append_array(lines.build_commands())
  if show_orb: commands.append_array(orb.build_commands())
 return commands
