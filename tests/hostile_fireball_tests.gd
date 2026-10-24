extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1;push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node2D.new();root.add_child(world)
	for i in range(8):
		for radius in [6.0, 12.0]:
			var bullet := EnemyBullet.new();bullet.definition=SpitterDefinition.new();bullet.definition.bullet_radius=radius
			bullet.direction=Vector2.RIGHT.rotated(i*TAU/8.0);bullet.position=Vector2(300,300);bullet.arena_bounds=Rect2(0,0,800,800)
			world.add_child(bullet);bullet.set_physics_process(false)
			var visual := bullet.get_node("FireballPresentation") as FireballPresentation;visual.set_physics_process(false)
			check(is_equal_approx(visual.rotation,bullet.direction.angle()),"First-frame flame heading")
			check(visual.position.dot(bullet.direction)<0.0,"Tail canvas lies behind collision center")
			var max_x := visual.position.dot(bullet.direction)+visual.scale.x
			check(is_equal_approx(max_x,visual.definition.bounds_in_radii.end.x*radius),"Atlas padding follows configured bounds; actual flame is verified separately")
			bullet.traveled=100.0;visual._physics_process(.1)
			var before: float = visual.surface.get_shader_parameter("phase")
			visual._physics_process(1.0)
			check(is_equal_approx(before,visual.surface.get_shader_parameter("phase")),"No motion means no extra flame time")
			check(bullet.traveled==100.0 and bullet.position==Vector2(300,300),"Fireball renderer never mutates gameplay")
			bullet.consume();visual._physics_process(.1);check(not visual.visible,"Consumed fireball hidden immediately")
			await process_frame
	var spitter := FileAccess.get_file_as_string("res://scripts/enemies/spitter/spitter.gd").split("func _draw()")[1]
	var boss := FileAccess.get_file_as_string("res://scripts/bosses/beastcaller/beastcaller.gd").split("func _draw()")[1]
	check(not spitter.contains("shot_pending") and not spitter.contains("locked_direction"),"No Spitter fireball telegraph graphics")
	check(not boss.contains('state == "projectile"') and not boss.contains("shot_direction"),"No Boss projectile telegraph graphics")
	check(boss.contains('state == "summon"'),"Summon warning remains")
	var shader := FileAccess.get_file_as_string("res://shaders/enemy_fireball.gdshader")
	check(not shader.contains("TIME"),"Shader cannot animate through paused game")
	world.queue_free();await process_frame
	print("HOSTILE_FIREBALL: %d checks, %d failures"%[checks,failures]);quit(failures)
