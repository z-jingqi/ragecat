extends RefCounted
static func texture()->ImageTexture:
 var im:=Image.create(64,40,false,Image.FORMAT_RGBA8)
 for frame in range(2):
  var ox:=frame*32;var dy:=frame
  for s in [[Rect2i(11,6+dy,10,8),"cfb89c"],[Rect2i(10,5+dy,12,3),"687e94"],[Rect2i(9,14+dy,14,13),"65859e"],[Rect2i(11,15+dy,9,9),"96a5ab"],[Rect2i(9,27,5,8),"4b576e"],[Rect2i(18,27,5,8),"4b576e"],[Rect2i(6,15+dy,3,12),"7d92a6"],[Rect2i(24,14-dy*3,3,13),"7d92a6"],[Rect2i(26,4-dy*3,2,13),"b9c7cc"]]:
   var r:Rect2i=s[0];r.position.x+=ox;im.fill_rect(r,Color(s[1]))
  # Actual transparent gap between sword arm and body; irregular silhouette.
  im.set_pixel(ox+15,19+dy,Color.TRANSPARENT)
 return ImageTexture.create_from_image(im)
