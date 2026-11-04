# Native CPU Canvas lens presentation. Sprite Fusion MIT, Hugo Duprez 2026.
# All scene pixels are generated procedurally; there are no oracle textures.
# The caller supplies the current opaque scene before effect light/color layers.
extends TextureRect
const Renderer = preload("res://scripts/hosts/sf_canvas_lens_cpu.gd")
const Plan = preload("res://scripts/hosts/sf_lens_plan.gd")
var source_rgba := PackedByteArray()
var source_width := 0
var source_height := 0
var current_lens: Dictionary = {}
var current_plan: Dictionary = {}
var current_rgba := PackedByteArray()
var renderer = Renderer.new()
var _image_texture: ImageTexture

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_source_rgba(bytes: PackedByteArray, width: int, height: int) -> void:
	assert(bytes.size() == width * height * 4)
	source_rgba = bytes
	source_width = width
	source_height = height

func present(lens: Dictionary) -> void:
	current_lens = lens.duplicate(true)
	current_plan = Plan.build_plan(lens)
	visible = not current_plan.is_empty()
	if not visible:
		current_rgba = PackedByteArray()
		return
	assert(not source_rgba.is_empty(), "Supply current scene RGBA before presenting the lens")
	current_rgba = renderer.build(source_rgba, source_width, source_height, lens)
	assert(current_rgba.size() == source_width * source_height * 4)
	var image := Image.create_from_data(source_width, source_height, false, Image.FORMAT_RGBA8, current_rgba)
	if _image_texture == null or _image_texture.get_width() != source_width or _image_texture.get_height() != source_height:
		_image_texture = ImageTexture.create_from_image(image)
		texture = _image_texture
	else:
		_image_texture.update(image)
