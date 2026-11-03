extends SceneTree
const Effect := preload("geometry_afterimage.gd")
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	assert(value,message)
func pose(at: Vector2) -> Transform2D: return Transform2D(0,at)
func _initialize() -> void:
	var fx := Effect.new();root.add_child(fx)
	var shape := [{"kind":"circle","center":Vector2.ZERO,"radius":17.0,"color":Color("78c9cc")},
		{"kind":"line","from":Vector2(20,0),"to":Vector2(28,0),"width":3.0,"color":Color("78c9cc")}]
	check(not fx.has_method("_process") and not fx.has_method("_physics_process"),"external clock only")
	var counts := []
	for fps in [30,60,144]:
		fx.configure();fx.start(pose(Vector2.ZERO),shape)
		for i in range(fps/5): fx.advance(1.0/fps,pose(Vector2((i+1)*600.0/fps,0)),shape)
		counts.append(fx.snapshots.size())
		check(fx.snapshots.size() <= 6 and fx.accents.size() <= 24,"bounded capacity")
		check(fx.snapshots.size() > 1,"actual trail")
		for snapshot in fx.snapshots:
			check(snapshot.transform.origin.y == 0 and snapshot.transform.origin.x >= 0 and snapshot.transform.origin.x <= 120,"only supplied historical segment")
		fx.stop();fx.advance(.2,pose(Vector2(120,0)),shape)
		check(fx.snapshots.is_empty() and fx.accents.is_empty(),"stop decay")
	fx.configure({"minimum_distance":0,"interval":.025,"lifetime":.2})
	fx.start(pose(Vector2.ZERO),shape);fx.advance(.05,pose(Vector2(30,0)),shape,.5)
	var original: float = fx.snapshots[0].geometry[0].radius
	shape[0].radius = 3.0
	check(fx.snapshots[0].geometry[0].radius == original,"immutable shape history")
	var historical: Transform2D = fx.snapshots[0].transform
	fx.position = Vector2(100,200)
	check(fx.snapshots[0].transform == historical,"effect-parent movement cannot drag history")
	fx.set_paused(true);var before := fx.clock;var count := fx.snapshots.size()
	fx.advance(20,pose(Vector2(10000,0)),shape)
	check(fx.clock == before and fx.snapshots.size() == count,"pause freezes clock and samples")
	fx.set_paused(false);fx.advance(.016,pose(Vector2(500,0)),shape)
	check(fx.snapshots.is_empty() and fx.accents.is_empty(),"teleport clears instead of bridging")
	fx.advance(INF,pose(Vector2.ZERO),shape);fx.advance(-1,pose(Vector2.ZERO),shape)
	check(is_finite(fx.clock),"invalid delta ignored")
	fx.configure({"interval":NAN,"opacity":INF,"max_images":90000,"tint":"bad color"})
	check(fx.config.interval == Effect.DEFAULTS.interval and fx.config.opacity == Effect.DEFAULTS.opacity and fx.config.max_images == 24,"finite bounded configuration")
	fx.start(pose(Vector2.ZERO),shape);fx.advance(90000,pose(Vector2(30,0)),shape)
	check(fx.snapshots.size() <= 24 and fx.accents.size() <= 24,"long stall bounded")
	fx.advance(.1,pose(Vector2(NAN,0)),shape)
	check(not fx.enabled and fx.snapshots.is_empty(),"invalid transform cancels")
	fx.configure();fx.start(pose(Vector2.ZERO),shape)
	for i in range(120): fx.advance(1.0/60,pose(Vector2.ZERO),shape)
	check(fx.snapshots.is_empty() and fx.accents.is_empty(),"stationary poses do not refresh")
	for i in range(1000):
		fx.start(pose(Vector2.ZERO),shape);fx.advance(.05,pose(Vector2(30,0)),shape);fx.reset()
		check(fx.get_child_count() == 0 and fx.snapshots.is_empty() and fx.accents.is_empty(),"reuse without node growth")
	check(fx.clean_geometry([{"kind":"circle","radius":NAN,"color":Color.WHITE},{"kind":"line","from":Vector2.INF}]).is_empty(),"bad shapes ignored")
	fx.free()
	print("GEOMETRY DASH PASS: ",checks," checks; 30/60/144Hz counts=",counts)
	quit()
