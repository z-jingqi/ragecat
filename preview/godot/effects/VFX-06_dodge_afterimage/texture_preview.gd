extends Node2D
## Native procedural-only preview. Driver owns movement and the external effect clock.
const Effect := preload("geometry_afterimage.gd")
const Fixture := preload("texture_fixture.gd")
var fx := Effect.new()
var texture := Fixture.make_texture()
var body := Sprite2D.new()
var commands: Array = []
var elapsed := 0.0
var previous_cycle := -1
func _ready() -> void:
	add_child(fx)
	fx.configure({"minimum_distance":12,"opacity":.65,"lifetime":.24,"hold":.025})
	add_child(body);body.texture = texture;body.region_enabled = true
	body.region_rect = Rect2(4,0,4,4);body.scale = Vector2(8,8)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var command := Fixture.command(texture);command.color = Color.WHITE;commands = [command]
	var label := Label.new();label.position = Vector2(26,22)
	label.text = "IMMUTABLE TEXTURE GHOSTS\nSynthetic atlas crop / transparent holes / nearest pixels\nRepeated dash + finite tail. No production artwork."
	add_child(label)
func _process(delta: float) -> void:
	elapsed += delta
	var cycle := int(elapsed/2.0)
	var phase := fmod(elapsed,2.0)
	if cycle != previous_cycle:
		previous_cycle = cycle
		body.position = Vector2(100,190)
		fx.start(Transform2D(0,body.position),commands)
	body.position = Vector2(100+minf(phase/.42,1)*420,190)
	fx.advance(delta,Transform2D(0,body.position),commands)
	if phase >= .42: fx.stop()
