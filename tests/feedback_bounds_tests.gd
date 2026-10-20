extends SceneTree
var failures:=0
var checks:=0
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		push_error("FAIL: "+message)
func _initialize()->void: call_deferred("run")
func within(text:FloatingText,area:Rect2)->bool:
	var rect:=Rect2(text.position+text.label.position,text.label.get_combined_minimum_size())
	return area.encloses(rect)
func run()->void:
	var game:=load("res://scenes/main.tscn").instantiate() as Node
	root.add_child(game)
	game.start_run(true)
	var arena:RageArena=game.arena
	arena.process_mode=Node.PROCESS_MODE_DISABLED
	arena.player.invulnerable=false
	var points:Array[Vector2]=[arena.bounds.position+Vector2(18,18),Vector2(arena.bounds.get_center().x,arena.bounds.position.y+18),arena.bounds.end-Vector2(18,18),Vector2(arena.bounds.get_center().x,arena.bounds.end.y-18)]
	for at in points:
		arena.player.position=at
		arena.player.health_state.invulnerability=0
		arena.stats.shield_capacity=1
		arena.stats.shields=1
		arena.player.receive_hit(10)
		var text:=arena.effects.get_child(arena.effects.get_child_count()-1) as FloatingText
		check(within(text,arena.bounds),"Shield-break caption starts inside arena at "+str(at))
		text._process(0.4)
		check(within(text,arena.bounds),"Shield-break caption floats without entering HUD/outside arena")
		arena.player.health_state.invulnerability=0
		arena.player.receive_hit(10)
		text=arena.effects.get_child(arena.effects.get_child_count()-1) as FloatingText
		text._process(0.4)
		check(within(text,arena.bounds),"HP caption remains inside at top/bottom and corners")
	game.queue_free()
	await process_frame
	print("FEEDBACK BOUNDS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
