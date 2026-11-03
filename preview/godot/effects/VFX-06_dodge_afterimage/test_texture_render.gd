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
func _initialize() -> void: call_deferred("run")
func render(viewport: SubViewport) -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func run() -> void:
	var viewport := SubViewport.new();viewport.size = Vector2i(96,64);viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var fx := Effect.new();viewport.add_child(fx)
	var texture := Fixture.make_texture()
	var geometry := [Fixture.command(texture)]
	fx.configure({"opacity":.5,"color_mix":0,"speed_lines":false,"hold":.05,"lifetime":.2})
	var pose := Transform2D(0,Vector2(32,32))
	fx.start(pose,geometry);fx.advance(.01,pose,geometry,.5)
	var before := await render(viewport)
	for y in range(64):
		for x in range(96):
			var in_rect := x>=16 and x<48 and y>=16 and y<48
			var in_hole := (x>=24 and x<32 and y>=24 and y<32) or (x>=40 and x<48 and y>=40 and y<48)
			var expected := .0625 if in_rect and not in_hole else 0.0
			check(absf(before.get_pixel(x,y).a-expected)<.006,"nearest source alpha, crop, shape/host alpha and opacity exactly once")
	check(absf(before.get_pixel(20,20).r-before.get_pixel(20,20).g)<.01,"crop excludes green atlas border")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof="): check(before.save_png(arg.trim_prefix("--proof=")) == OK,"save rendered proof")
	fx.position = Vector2(9,5);fx.scale = Vector2(1.5,1.5)
	var moved := await render(viewport)
	check(before.get_data() == moved.get_data(),"texture history stays fixed under parent transform")
	fx.set_paused(true);fx.advance(10,Transform2D(0,Vector2(80,32)),geometry)
	var paused := await render(viewport)
	check(paused.get_data() == before.get_data(),"paused pixels unchanged")
	fx.set_paused(false);fx.stop();fx.advance(.1,pose,geometry)
	var faded := await render(viewport)
	check(faded.get_pixel(20,20).a>0 and faded.get_pixel(20,20).a<before.get_pixel(20,20).a,"texture fades with external time")
	fx.advance(.2,pose,geometry)
	var expired := await render(viewport)
	check(expired.get_used_rect().size == Vector2i.ZERO,"expiry clears all texture pixels")
	fx.configure({"opacity":1,"color_mix":1,"tint":"ff0000","speed_lines":false,"hold":.05,"lifetime":.2})
	fx.start(pose,geometry);fx.advance(.01,pose,geometry)
	var tinted := await render(viewport)
	check(tinted.get_pixel(20,20).r>.9 and tinted.get_pixel(20,20).g<.01,"texture receives canonical tint")
	check(tinted.get_pixel(28,28).a == 0,"tint preserves silhouette hole")
	fx.reset();var cleared := await render(viewport)
	check(cleared.get_used_rect().size == Vector2i.ZERO,"reset clears texture pixels")
	viewport.free();await process_frame
	print("TEXTURE GEOMETRY NATIVE PASS: ",checks," checks; failures=",failures)
	quit(1 if failures else 0)
