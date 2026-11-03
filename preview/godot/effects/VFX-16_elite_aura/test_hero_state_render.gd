extends SceneTree
const Effect := preload("hero_state.gd")
func _initialize() -> void: call_deferred("run")
func render(viewport: SubViewport) -> Image:
	await process_frame;await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
func pixels(image: Image) -> int:
	var result := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>0:result+=1
	return result
func run() -> void:
	var viewport := SubViewport.new();viewport.size = Vector2i(128,96);viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var fx := Effect.new();viewport.add_child(fx)
	fx.set_war(true,Vector2(64,64));fx.tick(.4)
	var war := await render(viewport)
	assert(pixels(war)>30,"persistent canonical aura renders")
	assert(war.get_pixel(64,48).a==0,"host center stays clear")
	fx.set_paused(true);fx.tick(99)
	var paused := await render(viewport)
	assert(war.get_data() == paused.get_data(),"pause freezes actual pixels")
	fx.set_paused(false);fx.set_war(false,Vector2.ZERO)
	assert(pixels(await render(viewport))==0,"state cancellation immediately clears")
	assert(fx.revive(Vector2(64,64),1));fx.tick(.18)
	assert(pixels(await render(viewport))>10,"finite canonical heal cue renders")
	fx.tick(.6)
	assert(pixels(await render(viewport))==0,"return leaves no indefinite residue")
	fx.set_war(true,Vector2(64,64));fx.tick(.3);fx.clear()
	assert(pixels(await render(viewport))==0,"clear cancels all states")
	print("HERO STATE NATIVE PASS: visible war and revival, clear center, frozen pause pixels, immediate cancellation, finite cleanup")
	viewport.free();await process_frame;quit()
