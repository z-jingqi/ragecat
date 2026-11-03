# Official presentation order: additive light, then straight-alpha color; nearest.
# Draw back effects, actor pixels, and front effects into the SAME SFFrame first.
extends Node2D
var _light_sprite: Sprite2D
var _color_sprite: Sprite2D
var _light_texture: ImageTexture
var _color_texture: ImageTexture

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_light_sprite = Sprite2D.new()
	_light_sprite.centered = false
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_light_sprite.material = additive
	add_child(_light_sprite)
	_color_sprite = Sprite2D.new()
	_color_sprite.centered = false
	add_child(_color_sprite)
	scale = Vector2(2.0, 2.0)

func present(frame) -> void:
	assert(is_node_ready(), "Add the canvas to the scene tree before presenting a frame")
	var color_image: Image = frame.color.to_image()
	var light_image: Image = frame.light.to_image()
	if _color_texture == null or _color_texture.get_width() != frame.w or _color_texture.get_height() != frame.h:
		_color_texture = ImageTexture.create_from_image(color_image)
		_light_texture = ImageTexture.create_from_image(light_image)
		_color_sprite.texture = _color_texture
		_light_sprite.texture = _light_texture
	else:
		_color_texture.update(color_image)
		_light_texture.update(light_image)
