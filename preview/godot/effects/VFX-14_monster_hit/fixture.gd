extends RefCounted
static func texture(kind:int=0)->ImageTexture:
 var im:=Image.create(24,28,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 var body:=Color("6b9f77") if kind==0 else Color("997aab")
 for y in range(7,24):
  for x in range(4,20):
   if Vector2((x-11.5)/8.0,(y-15.0)/10.0).length()<1.0:im.set_pixel(x,y,body)
 im.fill_rect(Rect2i(4,3,4,8),body);im.fill_rect(Rect2i(16,3,4,8),body)
 im.fill_rect(Rect2i(7,11,3,2),Color("e3e7bd"));im.fill_rect(Rect2i(14,11,3,2),Color("e3e7bd"))
 im.fill_rect(Rect2i(9,17,6,2),Color("34413c"))
 im.fill_rect(Rect2i(5,23,5,3),body.darkened(0.3));im.fill_rect(Rect2i(14,23,5,3),body.darkened(0.3))
 im.set_pixel(11,8,Color(body,0.5))
 return ImageTexture.create_from_image(im)
