# Native reference for the original drawLens scratch image.
# Source geometry follows Sprite Fusion (MIT, Hugo Duprez, 2026).
# Sampling follows the documented Chrome155/Skia CPU image fast path:
# axis-aligned destination edges have no AA, and bilinear weights are 4-bit
# integers with the accumulated 16x16 weighted sum truncated by >>8.
# Acceptance is limited to the separately tested scratch fixtures, not the lens.
extends RefCounted

static func byte_round(value: float) -> int:
 return clampi(int(floor(value + 0.5)),0,255)

static func premultiply(color: int, alpha: int) -> int:
 var product := color*alpha + 128
 return (product + (product >> 8)) >> 8

static func build(source: PackedByteArray, width: int, height: int, cx: float, cy: float, size: int) -> Dictionary:
 assert(source.size() == width*height*4 and size > 0)
 var premultiplied := PackedByteArray()
 var readback := PackedByteArray()
 premultiplied.resize(size*size*4)
 readback.resize(size*size*4)
 var origin_x := cx-float(size)/2.0
 var origin_y := cy-float(size)/2.0
 # Clip the source rectangle to the source image and adjust the destination
 # proportionally. Here source/destination sizes are identical, so scale is1.
 # Non-AA rectangle rasterization rounds both destination edges to pixels.
 var left := maxi(0,int(floor(maxf(0.0,-origin_x)+0.5)))
 var top := maxi(0,int(floor(maxf(0.0,-origin_y)+0.5)))
 var right := mini(size,int(floor(minf(float(size),float(width)-origin_x)+0.5)))
 var bottom := mini(size,int(floor(minf(float(size),float(height)-origin_y)+0.5)))
 for y in range(top,bottom):
  var sy := origin_y+y
  var y0 := int(floor(sy))
  var fy := clampi(int(floor((sy-y0)*16.0)),0,15)
  for x in range(left,right):
   var sx := origin_x+x
   var x0 := int(floor(sx))
   var fx := clampi(int(floor((sx-x0)*16.0)),0,15)
   var sums := [0,0,0,0]
   for dy in range(2):
    var iy := clampi(y0+dy,0,height-1)
    var wy := fy if dy else 16-fy
    for dx in range(2):
     var ix := clampi(x0+dx,0,width-1)
     var weight := wy*(fx if dx else 16-fx)
     if weight==0:continue
     var p := (iy*width+ix)*4
     var alpha := int(source[p+3])
     sums[3] += alpha*weight
     for channel in range(3):
      sums[channel] += premultiply(int(source[p+channel]),alpha)*weight
   var p := (y*size+x)*4
   var alpha_byte: int = sums[3] >> 8
   premultiplied[p+3] = alpha_byte
   readback[p+3] = alpha_byte
   for channel in range(3):
    var value: int = sums[channel] >> 8
    premultiplied[p+channel] = value
    if alpha_byte:readback[p+channel] = byte_round(float(value)*255.0/alpha_byte)
 return {"width":size,"height":size,"rgba":readback,"premultiplied_rgba":premultiplied}
