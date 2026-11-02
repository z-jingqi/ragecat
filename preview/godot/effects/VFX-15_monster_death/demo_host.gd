extends RefCounted
## Procedural demonstration creature, not production monster art.
static func create_image() -> Image:
 var im:=Image.create(40,44,false,Image.FORMAT_RGBA8);im.fill(Color.TRANSPARENT)
 var outline:=Color("343c53");var base:=Color("728c9c");var lit:=Color("b4c9c7");var dark:=Color("516879")
 for y in 44:
  for x in 40:
   var p:=Vector2(x-19.5,y-23.0)
   var body:bool=absf(p.x)<11 and y>=16 and y<=35
   var head:bool=absf(p.x)<12 and y>=9 and y<=22
   var horn:bool=(x>=7 and x<=11 and y>=4 and y<=13) or (x>=27 and x<=31 and y>=4 and y<=13)
   var arms:bool=(x>=5 and x<=9 or x>=30 and x<=34) and y>=23 and y<=31
   var feet:bool=(x>=9 and x<=16 or x>=23 and x<=30) and y>=34 and y<=39
   if body or head or horn or arms or feet:im.set_pixel(x,y,outline)
 for y in range(10,35):
  for x in range(10,30):
   if im.get_pixel(x,y).a>0:im.set_pixel(x,y,base if x<24 else dark)
 for y in range(11,15):
  for x in range(12,27):im.set_pixel(x,y,lit)
 for x in range(12,17):im.set_pixel(x,18,Color("e8d29a"))
 for x in range(23,28):im.set_pixel(x,18,Color("e8d29a"))
 for x in range(16,24):im.set_pixel(x,24,outline)
 # Two transparent interior gaps deliberately exercise alpha preservation.
 for y in range(28,32):im.set_pixel(19,y,Color.TRANSPARENT);im.set_pixel(20,y,Color.TRANSPARENT)
 return im
