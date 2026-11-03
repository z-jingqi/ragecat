extends SceneTree
const Effect := preload("geometry_afterimage.gd")
func _initialize() -> void: call_deferred("run")
func render(viewport: SubViewport) -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	var viewport := SubViewport.new();viewport.size = Vector2i(128,96);viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var fx := Effect.new();viewport.add_child(fx)
	fx.configure({"opacity":.5,"color_mix":0.0,"speed_lines":false,"hold":.05,"lifetime":.2})
	var geometry := [{"kind":"circle","radius":10.0,"color":Color(1,0,0,.5)}]
	fx.start(Transform2D(0,Vector2(32,32)),geometry)
	fx.advance(.01,Transform2D(0,Vector2(32,32)),geometry,.5)
	var before := await render(viewport)
	assert(absf(before.get_pixel(32,32).a-.125)<.01,"shape alpha × host alpha × opacity exactly once")
	assert(before.get_pixel(43,32).a == 0,"no invented halo")
	fx.position = Vector2(21,7);fx.scale = Vector2(1.5,1.5)
	var moved := await render(viewport)
	var changed := 0
	for y in range(96):
		for x in range(128):
			if before.get_pixel(x,y) != moved.get_pixel(x,y):changed += 1
	assert(changed == 0,"world history survives effect translation and scale")
	fx.set_paused(true);fx.advance(10,Transform2D(0,Vector2(90,32)),geometry)
	var paused := await render(viewport)
	assert(paused.get_data() == moved.get_data(),"paused rendered pixels identical")
	fx.set_paused(false);fx.stop();fx.advance(.3,Transform2D(0,Vector2(32,32)),geometry)
	var cleared := await render(viewport)
	for y in range(96):
		for x in range(128):assert(cleared.get_pixel(x,y).a == 0,"tail expiry clears every pixel")
	fx.configure({"opacity":0.0,"line_opacity":.8,"line_lifetime":.1,"minimum_distance":0.0})
	fx.start(Transform2D(0,Vector2(30,50)),geometry)
	fx.advance(.05,Transform2D(0,Vector2(60,50)),geometry)
	var accents := await render(viewport)
	var visible := 0
	for y in range(96):
		for x in range(128):
			if accents.get_pixel(x,y).a > 0:visible += 1
	assert(visible>5,"canonical short speed accents render")
	fx.reset();var reset_image := await render(viewport)
	for y in range(96):
		for x in range(128):assert(reset_image.get_pixel(x,y).a == 0,"reset clears accents")
	print("GEOMETRY DASH NATIVE PASS: alpha, silhouette, world-space history, pause, decay, accents, reset; accent pixels=",visible)
	viewport.free();await process_frame;quit()
