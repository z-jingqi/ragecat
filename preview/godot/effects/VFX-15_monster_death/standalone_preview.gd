extends Node2D
const Death=preload("death.gd")
var effects:Array[Node2D]=[]
var clock:=0.0
func label_at(value:String,at:Vector2,size:=22)->void:
 var label:=Label.new();label.text=value;label.position=at;label.add_theme_font_size_override("font_size",size);add_child(label)
func _ready()->void:
 label_at("RAGECAT / STANDALONE DEATH BURST",Vector2(40,30),30)
 label_at("6 bounded fragments · 250 ms · no host image, no ground residue, no gameplay callbacks",Vector2(40,80),21)
 label_at("GAME SCALE / 1× SPEED",Vector2(110,175))
 label_at("3× DETAIL / 0.25× SPEED",Vector2(750,175))
 label_at("Small tan onset star → sparse falling chips → exact clean expiry",Vector2(40,655),22)
 for i in range(2):
  var effect:=Death.new();add_child(effect);effect.position=Vector2(300+i*640,355)
  effect.scale=Vector2.ONE*(1 if i==0 else 3)
  effect.configure({"host_mode":false,"duration":.25,"fragment_count":6,"residue_count":0,"residue_seconds":0,"tint":"b99889","ash_color":"a38b7f"})
  effect.play();effects.append(effect)
func _process(delta:float)->void:
 clock+=delta
 if clock>=1.5:
  clock=fmod(clock,1.5)
  for effect in effects:effect.play()
 for i in range(effects.size()):effects[i].advance(delta*(1 if i==0 else .25))
func _draw()->void:
 draw_rect(Rect2(0,0,1280,720),Color("10212b"))
 for x in range(0,1280,32):draw_line(Vector2(x,120),Vector2(x,625),Color(1,1,1,.035))
 for y in range(120,626,32):draw_line(Vector2(0,y),Vector2(1280,y),Color(1,1,1,.035))
