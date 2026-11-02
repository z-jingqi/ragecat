extends RefCounted
## Original procedural 64x72 review knight, no third-party art.
static func poly(im:Image,pts:Array,color:String,ox:int=0,dy:int=0)->void:
 var vertices:=PackedVector2Array()
 for p in pts:vertices.append(Vector2(p[0]+ox,p[1]+dy))
 var c:=Color(color)
 for y in range(im.get_height()):
  for x in range(ox,mini(ox+64,im.get_width())):
   if Geometry2D.is_point_in_polygon(Vector2(x+0.5,y+0.5),vertices):im.set_pixel(x,y,c)
static func texture()->ImageTexture:
 var im:=Image.create(128,72,false,Image.FORMAT_RGBA8)
 for frame in range(2):
  var x:=frame*64;var dy:=frame
  # Asymmetric cloak, separated greaves, sword, layered armor and shield.
  poly(im,[[24,25],[37,28],[38,51],[19,62],[10,58],[17,45],[16,33]],"242a3c",x)
  poly(im,[[22,28],[32,30],[27,49],[14,57],[20,42]],"774253",x)
  poly(im,[[22,30],[25,31],[21,46],[17,50]],"a66567",x)
  poly(im,[[25,46],[33,47],[30,59],[27,68],[17,68],[18,63],[22,60]],"222a36",x)
  poly(im,[[25,49],[30,49],[27,61],[22,64],[21,59]],"71889b",x)
  poly(im,[[26,50],[28,50],[25,61],[23,62]],"aeb8ba",x)
  poly(im,[[33,47],[41,46],[43,58],[49,64],[47,68],[35,67],[34,59]],"202b3a",x)
  poly(im,[[35,49],[39,49],[40,59],[44,63],[37,63]],"62788a",x)
  poly(im,[[36,50],[38,50],[38,59],[41,61],[37,60]],"a0adb2",x)
  poly(im,[[37,29],[43,27],[48,34],[48,44],[42,46],[39,39]],"242e40",x,dy)
  poly(im,[[40,30],[43,30],[45,35],[44,41],[41,39]],"91a6ae",x,dy)
  poly(im,[[44,35],[49,36],[50,41],[47,44],[43,41]],"c79b75",x,dy)
  # Raised sword: solid hilt / narrow metallic blade, creates a clear open arm gap.
  poly(im,[[47,37],[44,35],[56,9],[61,5],[61,12],[50,38]],"26364b",x,dy)
  poly(im,[[47,34],[57,11],[59,9],[59,13],[49,35]],"a4bfc9",x,dy)
  poly(im,[[48,32],[57,12],[58,11],[49,33]],"e0e5d8",x,dy)
  poly(im,[[43,33],[45,31],[52,36],[51,39]],"b3955c",x,dy)
  poly(im,[[46,36],[49,38],[47,43],[44,41]],"6a513f",x,dy)
  # Breastplate retains several distinct value bands under ice.
  poly(im,[[24,25],[34,23],[42,29],[42,42],[37,51],[24,49],[20,39],[20,30]],"242d3c",x,dy)
  poly(im,[[26,27],[33,26],[38,29],[38,40],[33,46],[25,43],[23,34]],"718b9a",x,dy)
  poly(im,[[27,28],[32,27],[33,37],[29,41],[25,37]],"b0bec0",x,dy)
  poly(im,[[34,29],[38,30],[38,39],[34,43],[32,39]],"4e687c",x,dy)
  poly(im,[[24,42],[37,44],[36,49],[25,48]],"a88f62",x,dy)
  poly(im,[[29,43],[33,44],[32,47],[29,46]],"e0c78e",x,dy)
  # Paired unequal pauldrons.
  poly(im,[[20,27],[26,25],[29,29],[25,34],[18,35],[16,31]],"293449",x,dy)
  poly(im,[[20,28],[25,27],[26,29],[23,32],[18,32]],"bac6c8",x,dy)
  poly(im,[[36,25],[40,25],[45,29],[45,32],[39,33],[35,29]],"354357",x,dy)
  poly(im,[[38,26],[41,27],[43,29],[40,30],[37,28]],"a3b6be",x,dy)
  # Helmet with visor, crest and neck shadows.
  poly(im,[[26,12],[34,10],[40,15],[40,22],[35,28],[27,26],[23,21],[23,16]],"222b3a",x,dy)
  poly(im,[[28,13],[34,12],[37,15],[37,21],[33,25],[27,23],[25,19]],"899eaa",x,dy)
  poly(im,[[28,14],[32,13],[33,18],[27,19],[25,18]],"c4ceca",x,dy)
  poly(im,[[27,19],[38,17],[38,20],[28,22]],"26364b",x,dy)
  poly(im,[[29,21],[31,21],[31,24],[29,23]],"afc1c5",x,dy)
  poly(im,[[31,11],[29,6],[31,3],[36,4],[39,8],[36,12]],"703f4e",x,dy)
  poly(im,[[31,7],[32,4],[35,5],[36,8],[34,10]],"b16464",x,dy)
  # Shield blocks only the left arm; angular coat-of-arms and edge thickness.
  poly(im,[[13,33],[22,31],[27,36],[24,50],[18,57],[10,50],[9,39]],"202c3d",x,dy)
  poly(im,[[14,35],[21,33],[24,37],[22,48],[18,53],[12,48],[11,39]],"a88c59",x,dy)
  poly(im,[[15,37],[20,35],[22,38],[20,47],[18,50],[14,46],[13,40]],"385d79",x,dy)
  poly(im,[[16,38],[18,37],[18,46],[16,44]],"aec5ca",x,dy)
 return ImageTexture.create_from_image(im)
