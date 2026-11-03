extends SceneTree
const JS = preload("res://scripts/core/sf_js.gd")
func bits(n):
 var b = PackedByteArray()
 b.resize(8)
 b.encode_double(0,n)
 return b.hex_encode()
func same(a,b):
 return (is_nan(a) and is_nan(b)) or a==b
func _init():
 var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/common/numeric_cases.json"))
 var failures = 0
 for c in cases:
  var a = c.a.hex_decode().decode_double(0)
  var b = c.b.hex_decode().decode_double(0)
  var actual = [JS.u32(a),JS.i32(a),JS.imul(a,b),JS.ushr(a,b)]
  var expect = [int(c.u),int(c.i),int(c.m),int(c.sh)]
  if actual!=expect or not same(JS.roundv(a),c.round.hex_decode().decode_double(0)) or not same(JS.opmod(a,b),c.rem.hex_decode().decode_double(0)):
   if failures<5: print("Mismatch ", c, " actual ",actual," round ",bits(JS.roundv(a))," rem ",bits(JS.opmod(a,b)))
   failures+=1
 print("Native JS numeric differential: ",cases.size()*6," assertions, ",failures," failures")
 quit(1 if failures else 0)
