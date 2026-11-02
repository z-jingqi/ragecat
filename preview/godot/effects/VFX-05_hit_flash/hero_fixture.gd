extends RefCounted
# Original procedural placeholder, not a production character asset.
static func texture() -> ImageTexture:
 var im:=Image.create(24,32,false,Image.FORMAT_RGBA8)
 im.fill(Color.TRANSPARENT)
 var shapes:=[
 [Rect2i(7,4,10,9),"b8c2c6"],[Rect2i(5,7,14,5),"6c8e9d"],
 [Rect2i(8,10,8,5),"d7b18c"],[Rect2i(6,14,12,10),"668fa5"],
 [Rect2i(8,15,8,7),"8cb1bd"],[Rect2i(3,15,3,9),"536a7b"],
 [Rect2i(18,15,3,9),"536a7b"],[Rect2i(7,24,4,6),"424c60"],
 [Rect2i(13,24,4,6),"424c60"],[Rect2i(5,29,6,2),"87979e"],
 [Rect2i(13,29,6,2),"87979e"],[Rect2i(9,5,6,2),"d2d8d7"],
 [Rect2i(6,22,12,2),"344f64"],[Rect2i(11,22,2,2),"d0b780"]]
 for s in shapes: im.fill_rect(s[0],Color(s[1]))
 return ImageTexture.create_from_image(im)
