extends SceneTree
## Manual real-renderer pixel contract. No screenshots or logs are written.
## Run without --headless: godot --path . --script tests/projectile_render_checks.gd
var failures := 0
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless":quit(2);return
	root.size=Vector2i(960,600);root.content_scale_size=Vector2i(960,600)
	root.transparent_bg=false;RenderingServer.set_default_clear_color(Color.BLACK)
	var world:=Node2D.new();root.add_child(world)
	var rect:=Rect2(180,140,600,320)
	for i in range(8):
		var shot:=EnemyBullet.new();shot.definition=SpitterDefinition.new();shot.definition.bullet_radius=12
		shot.direction=Vector2.RIGHT.rotated(i*TAU/8);shot.position=Vector2(480,300)+shot.direction*Vector2(295,155);shot.arena_bounds=rect
		world.add_child(shot);shot.set_physics_process(false);shot.ai_enabled=false
		shot.traveled=float(i)*40;shot.get_node("FireballPresentation")._physics_process(0.0)
	await process_frame;await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();var lit:=0;var outside:=0
	for y in range(im.get_height()):
		for x in range(im.get_width()):
			var c:=im.get_pixel(x,y)
			if maxf(c.r,maxf(c.g,c.b)) > .02:
				lit+=1
				if not rect.grow(1).has_point(Vector2(x,y)):outside+=1
	if lit<100 or outside>0:failures+=1
	print("FIREBALL_GPU_CLIP lit=",lit," outside=",outside)
	world.queue_free();await process_frame;quit(failures)
