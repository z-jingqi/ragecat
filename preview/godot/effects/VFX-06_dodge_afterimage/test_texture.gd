extends SceneTree
const Effect := preload("geometry_afterimage.gd")
const Fixture := preload("texture_fixture.gd")
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var fx := Effect.new();root.add_child(fx)
	var texture := Fixture.make_texture()
	var command := Fixture.command(texture)
	var shapes := [command]
	check(fx.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,"nearest filtering explicit")
	check(fx.clean_geometry(shapes)[0].texture == texture,"cleaning shares resource")
	var bad := []
	for field in ["texture","rect","region","color"]:
		var invalid := command.duplicate();invalid[field] = null;bad.append(invalid)
	for rect in [Rect2(0,0,0,8),Rect2(0,0,-8,8),Rect2(0,0,8,-8),Rect2(0,0,257,8),Rect2(NAN,0,8,8),Rect2(0,0,INF,8)]:
		var invalid := command.duplicate();invalid.rect = rect;bad.append(invalid)
	for rect in [Rect2(0,0,0,4),Rect2(0,0,-4,-4),Rect2(-1,0,4,4),Rect2(7,0,4,4),Rect2(0,7,4,4),Rect2(INF,0,4,4),Rect2(0,0,NAN,4)]:
		var invalid := command.duplicate();invalid.region = rect;bad.append(invalid)
	check(fx.clean_geometry(bad).is_empty(),"invalid texture commands rejected")
	check(fx.clean_geometry([command,{"kind":"circle","radius":4}]).size() == 2,"mixed geometry supported")
	var many := [];many.resize(100);many.fill(command)
	check(fx.clean_geometry(many).size() == Effect.MAX_SHAPES,"texture command cap")
	fx.configure({"minimum_distance":0,"speed_lines":false,"interval":.01,"lifetime":1,"max_images":24})
	fx.start(Transform2D.IDENTITY,shapes)
	for i in range(500): fx.advance(.01,Transform2D(0,Vector2(i*.1,0)),shapes,.5)
	check(fx.snapshots.size() == 24,"snapshot cap under repeated captures")
	for snapshot in fx.snapshots:
		check(snapshot.geometry[0].texture.get_instance_id() == texture.get_instance_id(),"no per-capture texture copies")
		check(snapshot.alpha == .5 and snapshot.geometry[0].color.a == .5,"host and command alpha preserved separately")
	command.rect = Rect2(0,0,1,1);command.region = Rect2(0,0,1,1);command.color = Color.RED;command.texture = Fixture.make_texture()
	shapes.clear()
	check(fx.snapshots[0].geometry[0].rect == Rect2(-16,-16,32,32),"destination metadata isolated")
	check(fx.snapshots[0].geometry[0].region == Rect2(4,0,4,4),"region metadata isolated")
	check(fx.snapshots[0].geometry[0].texture == texture,"caller resource replacement cannot change history")
	var before := fx.clock
	fx.set_paused(true);fx.advance(20,Transform2D.IDENTITY,[])
	check(fx.clock == before and fx.snapshots.size() == 24,"pause freezes texture history")
	fx.set_paused(false);fx.stop();fx.advance(2,fx.previous_transform,[])
	check(fx.snapshots.is_empty(),"texture history expires")
	fx.free()
	print("TEXTURE GEOMETRY PASS: ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
