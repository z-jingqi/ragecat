extends Node2D
const Dash := preload("../VFX-06_dodge_afterimage/geometry_afterimage.gd")
const HeroState := preload("hero_state.gd")
class Host:
	extends Node2D
	var color := Color("78c9cc")
	var facing := Vector2.RIGHT
	var protected := false
	var war := false
	func _draw() -> void:
		draw_circle(Vector2(0,8),21,Color(0,0,0,.25))
		draw_circle(Vector2.ZERO,17,color)
		draw_arc(Vector2.ZERO,22,0,TAU,32,Color("7fe2de") if protected else color,2,false)
		draw_circle(Vector2(-5,-3),2,Color("172d39"));draw_circle(Vector2(5,-3),2,Color("172d39"))
		draw_line(facing*20,facing*28,color,3,false)
		if war:draw_arc(Vector2.ZERO,32,-PI/2,PI,40,Color("d9b480"),3,false)
var dash := Dash.new()
var state := HeroState.new()
var runner := Host.new()
var warrior := Host.new()
var elapsed := 0.0
var paused := false
var dash_on := false
var revived := false
var state_text: Label
func label_at(text: String, at: Vector2, size := 13) -> Label:
	var item := Label.new();item.text=text;item.position=at;item.add_theme_font_size_override("font_size",size);add_child(item);return item
func geometry() -> Array:
	return [{"kind":"circle","center":Vector2.ZERO,"radius":17.0,"color":runner.color},
		{"kind":"circle","center":Vector2(-5,-3),"radius":2.0,"color":Color("172d39")},
		{"kind":"circle","center":Vector2(5,-3),"radius":2.0,"color":Color("172d39")},
		{"kind":"line","from":runner.facing*20,"to":runner.facing*28,"width":3.0,"color":runner.color}]
func _ready() -> void:
	label_at("RAGECAT / DASH + HERO STATE",Vector2(16,14),20)
	label_at("Geometry-host adapter · canonical afterimage / aura / healing",Vector2(16,44),13)
	label_at("DASH / 0.18 s actual motion + 0.16 s fading history",Vector2(24,80))
	label_at("WAR → RETURN / authoritative state + one finite event",Vector2(24,204))
	label_at("No attack animation · no new character art · no gameplay authority",Vector2(16,327),13)
	state_text=label_at("",Vector2(330,264),13)
	add_child(dash);add_child(state);add_child(runner);add_child(warrior)
	runner.z_index=2;warrior.z_index=2
	var x:=390.0
	for title in ["Pause","Replay","Clear"]:
		var button:=Button.new();button.text=title;button.position=Vector2(x,14);button.size=Vector2(72,27);add_child(button)
		button.pressed.connect(func():
			match title:
				"Pause":paused=not paused;dash.set_paused(paused);state.set_paused(paused)
				"Replay":reset()
				"Clear":dash.reset();state.clear();paused=true
		)
		x+=77
	reset()
func reset() -> void:
	elapsed=0;paused=false;dash_on=false;revived=false;dash.reset();state.clear()
	runner.position=Vector2(110,148);warrior.position=Vector2(165,274)
func _process(delta: float) -> void:
	if paused:return
	elapsed+=delta
	if elapsed>=4:reset()
	var motion:=clampf((elapsed-.5)/.18,0,1)
	runner.position=Vector2(110+120*motion,148)
	runner.protected=elapsed>=.5 and elapsed<.6
	if elapsed>=.5 and elapsed<.68:
		if not dash_on:
			dash.start(Transform2D(0,to_global(Vector2(110,148))),geometry());dash_on=true
	elif dash_on:dash.stop()
	dash.advance(delta,runner.global_transform,geometry())
	warrior.position=Vector2(165+sin(elapsed*1.5)*24,274)
	var in_war:=elapsed>=.3 and elapsed<2.4
	state.set_war(in_war,warrior.global_position+Vector2(0,15),elapsed>=1.8)
	warrior.war=in_war;warrior.color=Color("eb9477") if in_war else Color("78c9cc")
	if elapsed>=2.4 and not revived:state.revive(warrior.global_position+Vector2(0,15),1);revived=true
	state.tick(delta)
	state_text.text="WAR / follows real state\nExisting meter stays above" if in_war else ("RETURN / 0.58 s cue\nAfter real revival event" if elapsed<3.0 and revived else "CLEAR / no leftover effect")
	runner.queue_redraw();warrior.queue_redraw();queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,0,640,360),Color("13212c"))
	for y in range(66,320,16):draw_line(Vector2(16,y),Vector2(624,y),Color(1,1,1,.025))
	for x in range(16,625,16):draw_line(Vector2(x,66),Vector2(x,320),Color(1,1,1,.025))
	draw_line(Vector2(16,190),Vector2(624,190),Color("354552"))
