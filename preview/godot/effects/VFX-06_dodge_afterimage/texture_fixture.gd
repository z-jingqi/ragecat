extends RefCounted
## Synthetic 8x8 atlas; the right-hand 4x4 region is the permitted test portrait.
static func make_texture() -> ImageTexture:
	var image := Image.create(8,8,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,1,0,1))
	for y in range(4):
		for x in range(4):
			image.set_pixel(x+4,y,Color(1,1,1,.5))
	image.set_pixel(5,1,Color.TRANSPARENT)
	image.set_pixel(7,3,Color.TRANSPARENT)
	return ImageTexture.create_from_image(image)

static func command(texture: Texture2D) -> Dictionary:
	return {"kind":"texture","texture":texture,"rect":Rect2(-16,-16,32,32),
		"region":Rect2(4,0,4,4),"color":Color(1,1,1,.5)}
