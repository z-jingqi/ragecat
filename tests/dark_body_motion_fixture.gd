extends "res://tests/blender_vfx_motion_fixture.gd"
## Cheap art-direction sample only: actual moving gravity arrow for 2 seconds.
## --capture-dir=/tmp/dark-body-single [--dense] --size=960x600
var dense_sample := false
func _initialize() -> void:
	only_section = "dark"
	dense_sample = "--dense" in OS.get_cmdline_user_args()
	super._initialize()
func reset_section(section: String) -> void:
	await super.reset_section(section)
	arena.bow.enabled = false
	if not dense_sample:
		for index in range(sample_enemies.size() - 1, 0, -1):
			var enemy := sample_enemies[index]
			sample_enemies.remove_at(index)
			enemy.free()
		sample_enemies[0].position = Vector2(680, 400)
		marker.text = "Continuous twisting body | actual moving dark arrow"
	else:
		marker.text = "Continuous body | crowd, enemy orbs and held boss warnings"
		var boss := arena.spawn_enemy("mountainbreaker", Vector2(900, 400)) as Mountainbreaker
		boss.ai_enabled = false
		for at in [Vector2(535, 405), Vector2(700, 440)]:
			var warning := RockWarning.new()
			warning.radius = 44.0
			warning.warning_duration = 5.0
			warning.elapsed = 2.0
			warning.ai_enabled = false
			warning.arena_bounds = arena.bounds
			boss.add_child(warning)
			warning.global_position = at
			warning.queue_redraw()
		for index in range(3):
			var bullet := EnemyBullet.new()
			var config := arena.ranged_definition.duplicate(true) as SpitterDefinition
			config.bullet_speed = 90.0
			config.bullet_range = 1000.0
			bullet.setup(Vector2(710 + index * 55, 345 + index * 40), Vector2.LEFT, config, arena.player)
			bullet.arena_bounds = arena.bounds
			bullet.set_meta("boss_owner_id", boss.get_instance_id())
			arena.enemy_bullets.add_child(bullet)
	arena.bow.shoot()
