extends SceneTree
## Reusable rendered visual inspection. Outputs only when --output=/tmp/... is
## explicitly supplied; generated images never belong in the repository.
class BurnPreview extends Node2D:
	func _draw() -> void:
		ElementGeometry.draw_burn(self, Vector2.ZERO, 18.0, 1.1, Color("ff9958"), ElementVisualDefinition.new())

var stage: Node2D
func _initialize() -> void:
	call_deferred("run")
func label_at(text: String, at: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	stage.add_child(label)
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.title = "Element feedback visual fixture"
	stage = Node2D.new()
	root.add_child(stage)
	var bg := Polygon2D.new()
	bg.polygon = PackedVector2Array([Vector2.ZERO, Vector2(1280,0), Vector2(1280,720), Vector2(0,720)])
	bg.color = Color("141827")
	stage.add_child(bg)
	label_at("Procedural frost: 0%, 50%, 100% | Shader sprites: original / frozen", Vector2(40,30))
	for i in range(3):
		var actor := EnemyActor.new()
		actor.position = Vector2(140 + i * 150, 150)
		stage.add_child(actor)
		actor.set_physics_process(false)
		var visual := ElementStatusVisual.new()
		visual.setup(actor)
		actor.add_child(visual)
		visual.set_process(false)
		visual.freeze_coverage = float(i) / 2.0
		visual.queue_redraw()
		label_at("%d%%" % (i * 50), actor.position + Vector2(-15, 45))
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(64):
		for x in range(64):
			if Vector2(x-32,y-32).length() < 25:
				image.set_pixel(x,y,Color("a25679") if x % 10 > 2 else Color("59334e"))
	for i in range(2):
		var sprite := Sprite2D.new()
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.position = Vector2(790+i*150,150)
		stage.add_child(sprite)
		if i == 1:
			var holder := ElementStatusVisual.new()
			stage.add_child(holder)
			holder.bind_sprite(sprite)
			holder.freeze_coverage = 1.0
			holder._sync_sprite()
	label_at("Explosion and actual chain endpoints", Vector2(40,280))
	var blast := ElementFlash.new()
	blast.position = Vector2(160,410)
	blast.radius = 90
	blast.remaining = blast.duration * 0.45
	stage.add_child(blast)
	blast.set_process(false)
	var chain := ElementFlash.new()
	chain.kind = "chain"
	chain.color = Color("ffe38a")
	chain.points = PackedVector2Array([Vector2(330,410),Vector2(450,360),Vector2(560,440),Vector2(690,390)])
	chain.remaining = chain.duration * 0.45
	stage.add_child(chain)
	chain.set_process(false)
	for point in chain.points:
		var actor := EnemyActor.new()
		actor.position = point
		stage.add_child(actor)
		actor.set_physics_process(false)
	label_at("Moving-arrow vortex: outer pull / inner damage", Vector2(770,280))
	var field := GravityField.new()
	field.position = Vector2(980,470)
	field.outer_radius = 150
	field.inner_radius = 65
	field.age = 1.2
	stage.add_child(field)
	label_at("Shatter fragments / soft thaw flakes", Vector2(40,570))
	for i in range(2):
		var burst := FeedbackVisual.new()
		burst.position = Vector2(180 + i*250,640)
		burst.kind = "shatter" if i == 0 else "thaw"
		burst.color = Color("bcefff")
		burst.duration = 1.0
		burst.remaining = 0.6
		burst.travel = 40.0 if i == 0 else 5.0
		for k in range(8 if i == 0 else 3): burst.directions.append(Vector2.from_angle(k*TAU/(8 if i == 0 else 3)))
		stage.add_child(burst)
		burst.set_process(false)
	var burning := EnemyActor.new()
	burning.position = Vector2(640,640)
	stage.add_child(burning)
	burning.set_physics_process(false)
	burning.add_child(BurnPreview.new())
	label_at("Burn",Vector2(620,585))
	var alpha_view := SubViewport.new()
	alpha_view.size = Vector2i(32,32)
	alpha_view.transparent_bg = true
	alpha_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(alpha_view)
	var alpha_image := Image.create(32,32,false,Image.FORMAT_RGBA8)
	alpha_image.fill(Color(1,0.3,0.2,0.5))
	var alpha_sprite := Sprite2D.new()
	alpha_sprite.centered = false
	alpha_sprite.texture = ImageTexture.create_from_image(alpha_image)
	alpha_sprite.modulate.a = 0.5
	var alpha_material := ShaderMaterial.new()
	alpha_material.shader = preload("res://shaders/frost_overlay.gdshader")
	alpha_material.set_shader_parameter("freeze_coverage",1.0)
	alpha_sprite.material = alpha_material
	alpha_view.add_child(alpha_sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			var output := argument.trim_prefix("--output=")
			var rendered := root.get_texture().get_image()
			var untouched := rendered.get_pixel(910,120)
			var background := rendered.get_pixel(700,120)
			var alpha_ok := untouched.is_equal_approx(background)
			var half_alpha := alpha_view.get_texture().get_image().get_pixel(16,16).a
			var partial_alpha_ok := absf(half_alpha - 0.25) < 0.01
			print("Rendered half-alpha with half-modulate: %s (expected 0.25)" % half_alpha)
			var shade_ok := not rendered.get_pixel(940,150).is_equal_approx(rendered.get_pixel(790,150))
			print("Rendered shader alpha preserved: %s; frost tint active: %s" % [alpha_ok, shade_ok])
			var error := rendered.save_png(output)
			print("Rendered visual fixture: %s (%s)" % [output, error_string(error)])
			quit(0 if error == OK and alpha_ok and shade_ok and partial_alpha_ok else 1)
