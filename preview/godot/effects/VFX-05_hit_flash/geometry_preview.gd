extends Node2D
const State = preload("flash_state.gd")
var fast := State.new()
var slow := State.new()
var elapsed := 0.0
var clock := 0.0
var status: Label
func label_at(text: String,p: Vector2,size := 22) -> Label:
 var label := Label.new(); label.text=text;label.position=p
 label.add_theme_font_size_override("font_size",size);add_child(label);return label
func _ready() -> void:
 get_window().size=Vector2i(1280,720)
 for state in [fast,slow]: state.configure({"duration":.1,"peak":.2,"hold":.018,"color":"#ffffff"});state.trigger()
 label_at("RAGECAT / GEOMETRY HIT FLASH",Vector2(40,28),30)
 label_at("Shared flash curve · 100 ms / peak 20% white · exact host alpha and silhouette",Vector2(40,74),21)
 label_at("NORMAL / 1× SPEED",Vector2(100,170))
 label_at("SLOW / 0.25× SPEED",Vector2(740,170))
 for offset in [0,640]:
  label_at("Base",Vector2(128+offset,350),20)
  label_at("Hit",Vector2(262+offset,350),20)
  label_at("Alpha 50%",Vector2(352+offset,350),20)
 label_at("STATIC LIFECYCLE / base → peak → decay → clear",Vector2(100,440),21)
 for item in [["base",150],["peak",400],["50 ms",650],["100 ms",900]]:label_at(item[0],Vector2(item[1],590),20)
 status=label_at("No material override · caller chooses which body colors to mix · warnings stay unchanged",Vector2(40,663),20)
func _process(delta: float) -> void:
 elapsed+=delta;clock+=delta
 if clock>=1.2:clock=fmod(clock,1.2);fast.trigger();slow.trigger()
 fast.tick(delta);slow.tick(delta*.25);queue_redraw()
func diamond(at: Vector2,color: Color,multiplier := 1.0) -> void:
 draw_colored_polygon(PackedVector2Array([at+Vector2(0,-17)*multiplier,at+Vector2(16,0)*multiplier,at+Vector2(0,17)*multiplier,at+Vector2(-16,0)*multiplier]),color)
func _draw() -> void:
 draw_rect(Rect2(0,0,1280,720),Color("10212b"))
 for x in range(0,1280,32):draw_line(Vector2(x,120),Vector2(x,630),Color(1,1,1,.035))
 for y in range(120,631,32):draw_line(Vector2(0,y),Vector2(1280,y),Color(1,1,1,.035))
 var base := Color("dd7970")
 for i in range(2):
  var state = fast if i==0 else slow
  var origin := Vector2(150+i*640,270)
  diamond(origin,base)
  diamond(origin+Vector2(125,0),state.apply_color(base))
  var transparent := Color(base,.5)
  diamond(origin+Vector2(250,0),state.apply_color(transparent),2)
  # This unrelated warning outline is deliberately outside the color helper.
  draw_arc(origin+Vector2(125,0),55,0,TAU,64,Color("ff8760"),2,false)
 for i in range(4):
  var state := State.new();state.configure({"duration":.1,"peak":.2,"hold":.018,"color":"#ffffff"})
  if i>0:state.trigger();state.tick([0.0,0.0,.05,.1][i])
  diamond(Vector2(180+i*250,535),state.apply_color(base),2)
