class_name FireballPresentation
extends Sprite2D
@export var definition: FireballVisualDefinition = preload("res://resources/projectiles/enemy_fireball.tres")
var bullet: EnemyBullet
var surface: ShaderMaterial
func _ready() -> void:
	bullet = get_parent() as EnemyBullet
	if bullet == null or bullet.definition == null: return
	if definition == null: definition = preload("res://resources/projectiles/enemy_fireball.tres")
	definition = definition.validated_copy()
	process_physics_priority = 100
	var fill := GradientTexture2D.new()
	fill.gradient = Gradient.new()
	fill.width = 2; fill.height = 2
	texture = fill
	surface = ShaderMaterial.new()
	surface.shader = preload("res://shaders/enemy_fireball.gdshader")
	surface.set_shader_parameter("flame_atlas", definition.texture)
	surface.set_shader_parameter("atlas_grid", Vector2(definition.atlas_grid))
	surface.set_shader_parameter("frame_count", float(definition.frame_count))
	surface.set_shader_parameter("surface_opacity", definition.surface_opacity)
	surface.set_shader_parameter("arena_rect", Vector4(bullet.arena_bounds.position.x, bullet.arena_bounds.position.y, bullet.arena_bounds.size.x, bullet.arena_bounds.size.y))
	material = surface
	rotation = bullet.direction.angle()
	var radius := bullet.definition.bullet_radius
	scale = definition.bounds_in_radii.size * radius * 0.5
	position = definition.bounds_in_radii.get_center().rotated(rotation) * radius
	_physics_process(0.0)
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(bullet) or surface == null: return
	visible = not bullet.consumed
	# Distance-derived playback freezes with pause and disabled AI.
	surface.set_shader_parameter("phase", bullet.traveled / maxf(0.001, bullet.definition.bullet_speed) * definition.frames_per_second)
