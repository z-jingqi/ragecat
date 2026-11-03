extends Node2D
const Thunder := preload("../VFX-08_chain_lightning/fixed_path.gd")
const ThunderPreset := preload("../VFX-08_chain_lightning/combat_preset.gd")
const Level := preload("../VFX-22_level_up/level_up.gd")
const LevelPreset := preload("../VFX-22_level_up/combat_preset.gd")
var thunder: Array = []
var levels: Array = []
var cycle := -1
var time := 0.0
func _ready():
 get_window().size = Vector2i(1280,720)
 get_window().content_scale_size = Vector2i(1280,720)
 for i in range(2):
  var bolt := Thunder.new(); add_child(bolt); thunder.append(bolt)
  var level := Level.new(); level.automatic = false; add_child(level); levels.append(level)
  if i == 1: level.scale = LevelPreset.DRAW_SCALE
 queue_redraw()
func _process(delta):
 time += delta
 var next := int(time/2)
 if next != cycle:
  cycle = next
  for i in range(2):
   var points := PackedVector2Array()
   for j in range(6): points.append(Vector2(80+j*100,210+i*160))
   thunder[i].play_path(points,{} if i == 0 else ThunderPreset.OPTIONS)
   levels[i].play(Vector2(880+i*230,560)/levels[i].scale,{} if i == 0 else LevelPreset.OPTIONS)
 for item in thunder: item.advance(delta)
 for item in levels: item.tick(delta)
 queue_redraw()
func _draw():
 draw_rect(Rect2(0,0,1280,720),Color("102936"))
 # Effects are child items, so the host masks are separate foreground children.
 for i in range(2):
  var label := "BASELINE / 0.18s, thin path" if i == 0 else "COMBAT PRESET / 0.36s, wider path, longer bright hold"
  draw_string(ThemeDB.fallback_font,Vector2(60,170+i*160),label,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
 draw_string(ThemeDB.fallback_font,Vector2(60,45),"RAGECAT / actual 1280x720 scale / canonical defaults and opt-in readability presets",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color.WHITE)
 draw_string(ThemeDB.fallback_font,Vector2(60,77),"Visual-only paths, no gameplay callbacks; same particle budget, same upgrade lifetime",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b8c5c9"))
 draw_string(ThemeDB.fallback_font,Vector2(800,610),"Baseline",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
 draw_string(ThemeDB.fallback_font,Vector2(1020,610),"Combat preset",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color.WHITE)
 draw_string(ThemeDB.fallback_font,Vector2(800,640),"Grey blocks = 38x76px opaque host masks",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("b8c5c9"))
