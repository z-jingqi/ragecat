extends SceneTree
const History = preload("path_history.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, title: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(title)
func run() -> void:
	var state := History.new()
	state.configure({"external_lifetime":true,"lifetime":.1})
	state.reset(Vector2.ZERO,Vector2.RIGHT*100)
	for i in range(120): state.tick(1.0/60,Vector2((i+1)*100.0/60,0),Vector2.RIGHT*100)
	check(state.emitting and state.world_position.is_equal_approx(Vector2(200,0)),"external lifetime never hides a living game projectile")
	if failures: quit(1); return
	var Runtime = load("res://effects/VFX-03_physical_projectile/physical_effect.gd")
	check(Runtime != null,"pure physical effect exists")
	if Runtime == null: quit(1); return
	var effect = Runtime.new()
	root.add_child(effect)
	effect.play(Vector2(120,100),Vector2.RIGHT*520,{"lifetime":.1})
	for i in range(120): effect.sample(1.0/60,Vector2(120+(i+1)*520.0/60,100),Vector2.RIGHT*520)
	check(not effect.done and effect.state.emitting,"runtime respects caller lifetime")
	check(effect.state.points.size() <= 128,"runtime history bounded")
	check(effect.view.position == effect.state.world_position.round(),"display follows real world tip")
	var clock: float = effect.state.clock
	effect.advance(1)
	check(effect.state.clock == clock,"manager advance cannot double tick live flight")
	effect.stop()
	check(not effect.state.emitting and not effect.done,"stop hides body but retains tail")
	var tip: Vector2 = effect.state.world_position
	effect.advance(.05)
	check(effect.state.world_position == tip,"tail never continues flight after hit")
	effect.advance(.2)
	check(effect.done,"tail expires under caller clock")
	effect.play(Vector2(10,20),Vector2.DOWN*100)
	check(effect.state.age == 0 and effect.state.points.size() == 1,"replay resets pose and history")
	effect.stop(true)
	check(effect.done,"immediate reset clears")
	effect.free()
	print("PHYSICAL EXTERNAL: %d checks, %d failed" % [checks,failures])
	quit(1 if failures else 0)
