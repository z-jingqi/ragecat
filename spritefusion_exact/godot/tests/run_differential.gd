extends SceneTree
const Frame = preload("res://scripts/core/sf_frame.gd")
const JS = preload("res://scripts/core/sf_js.gd")
var sim_frame = 0
var actor_x = 160.0
var actor_y = 300.0
var actor_visible = true
var actor_frozen = false
var actor_data = PackedInt64Array()
var hooks: Array = []
var dynamic_actor = false
var case_id = ""
var output_dir = ""
func unpack(value):
 if value is Dictionary:
  if value.has("__f64"): return str(value.__f64).hex_decode().decode_double(0)
  var result = {}
  for key in value: result[key] = unpack(value[key])
  return result
 if value is Array:
  var result = []
  for item in value: result.append(unpack(item))
  return result
 return value
func emit_hook(name, args):
 hooks.append({"frame":sim_frame,"name":name,"args":args})
func cue(name, data = {}):
 emit_hook("cue",[name,data])
 if name == "move" and data.has("x"): actor_x = data.x
 if name == "appear":
  if data.has("x"): actor_x = data.x
  if data.has("y"): actor_y = data.y
  actor_visible = true
 if name == "vanish": actor_visible = false
 if name == "freeze": actor_frozen = true
 if name == "thaw": actor_frozen = false
func _init():
 var args = OS.get_cmdline_user_args()
 if args.size() < 3:
  printerr("Usage: -- oracle-directory effect-or-case-ids output-directory")
  quit(2)
  return
 var oracle = args[0]
 var filter_id = args[1]
 output_dir = args[2]
 DirAccess.make_dir_recursive_absolute(output_dir)
 var bytes = FileAccess.get_file_as_bytes(oracle + "/actor.rgba")
 actor_data.resize(bytes.size() / 4)
 for i in range(actor_data.size()): actor_data[i] = bytes.decode_u32(i * 4)
 var case_path = oracle + "/cases-f64.json"
 var cases = unpack(JSON.parse_string(FileAccess.get_file_as_string(case_path if FileAccess.file_exists(case_path) else oracle + "/cases.json")))
 var failures = 0
 for item in cases:
  if not filter_id.is_empty() and not item.id in filter_id.split(",") and not item.slug in filter_id.split(","): continue
  if not run_case(item, oracle): failures += 1
 quit(failures)
func run_case(c, oracle):
 case_id = c.id
 sim_frame = 0
 actor_x = 160.0
 actor_y = 300.0
 actor_visible = true
 actor_frozen = false
 hooks.clear()
 dynamic_actor = c.get("dynamicActor", false)
 var actor = {
  "feet":func(): return [actor_x,actor_y],
  "head":func(): return [actor_x,actor_y-62.0],
  "hand":func(): return {"x":actor_x+24.0,"y":actor_y-46.0,"a":0.4*sin(sim_frame/30.0) if dynamic_actor else 0.0},
  "silhouette":func(): return {"x":actor_x/2.0-8.0,"y":actor_y/2.0-32.0,"w":16.0,"h":32.0,"data":actor_data},
 }
 var host = {
  "shake":func(a): emit_hook("shake",[a]),
  "flash":func(a,b): emit_hook("flash",[a,b]),
  "darken":func(a): emit_hook("darken",[a]),
  "ripple":func(a,b,cc,d,e,f,g): emit_hook("ripple",[a,b,cc,d,e,f,g]),
  "kick":func(a,b): emit_hook("kick",[a,b]),
  "lens":func(a): emit_hook("lens",[a]),
  "cue":cue,
 }
 var script = load("res://scripts/effects/" + c.slug + ".gd")
 if script == null:
  printerr("LOAD FAILED ",c.id)
  return false
 var calls = c.get("calls", [{"at":0.0}])
 var live: Array = []
 var spawn_state = {"index":0}
 var spawn = func():
  while spawn_state.index < calls.size() and calls[spawn_state.index].at <= sim_frame/60.0 + 1e-12:
   var opts = c.options.duplicate(true)
   opts.merge(calls[spawn_state.index].get("options",{}),true)
   opts.merge(host,true)
   if opts.get("actor") == true: opts.actor = actor
   live.append(script.new().configure(opts))
   spawn_state.index += 1
 var camera = c.get("camera", {"ox":0.0,"oy":0.0})
 var frame = Frame.new(320,200,camera.ox,camera.oy)
 var reference = JSON.parse_string(FileAccess.get_file_as_string(oracle + "/" + c.id + "/frames.json"))
 # Keep gzip bytes verbatim and close the archive before running the simulation.
 # Individual fixtures take precedence when both storage formats are present.
 var archive_raw = {}
 var archive_path = oracle + "/" + c.id + "/raw.zip"
 if FileAccess.file_exists(archive_path):
  var archive = ZIPReader.new()
  var archive_error = archive.open(archive_path)
  if archive_error != OK:
   printerr("RAW ARCHIVE OPEN FAILED ",archive_path," error=",archive_error)
   return false
  for entry in archive.get_files(): archive_raw[entry] = archive.read_file(entry)
  archive.close()
 spawn.call()
 for n in range(int(c.get("warmup",0))):
  sim_frame = n+1
  for fx in live: fx.update(1.0/60.0)
  for layer in ["back","front"]:
   frame.clear()
   for fx in live: fx.draw(frame,layer)
 sim_frame = 0
 var total_start = Time.get_ticks_msec()
 for row in reference.hashes:
  var n = int(row.frame)
  if n % 60 == 0: print("CHECK ",c.id," frame=",n," elapsed=",(Time.get_ticks_msec()-total_start)/1000.0)
  if n > 0:
   sim_frame = n
   if dynamic_actor and not actor_frozen:
    actor_x = 160.0 + 2.0 * JS.roundv(12.0*sin(n/30.0))
    actor_y = 300.0 - 2.0 * JS.roundv(2.0*sin(n/20.0))
   spawn.call()
   for action in c.get("actions",[]):
    if int(action.frame) == n:
     for fx in live: JS.call_method(fx._effect,action.method,action.args)
   if n == int(c.get("stopFrame",-1)):
    for fx in live: fx.stop()
   for fx in live: fx.update(1.0/60.0)
  if row.has("actor") and (actor_x != row.actor.x or actor_y != row.actor.y or actor_visible != row.actor.visible):
   printerr("ACTOR MISMATCH ",c.id," frame=",n)
   for fx in live: fx.dispose()
   return false
  for layer in ["back","front"]:
   frame.clear()
   for fx in live: fx.draw(frame,layer)
   for channel in ["color","light"]:
    var raw = PackedInt32Array(Array(frame.get(channel).data)).to_byte_array()
    var digest = HashingContext.new()
    digest.start(HashingContext.HASH_SHA256)
    digest.update(raw)
    var got = digest.finish().hex_encode()
    var key = layer + "-" + channel
    var golden_raw_path = oracle + "/" + c.id + "/%04d-" % n + key + ".rgba.gz"
    var golden_gzip = FileAccess.get_file_as_bytes(golden_raw_path) if FileAccess.file_exists(golden_raw_path) else archive_raw.get(golden_raw_path.get_file())
    if golden_gzip != null:
     var expected_raw = golden_gzip.decompress(raw.size(), FileAccess.COMPRESSION_GZIP)
     if raw != expected_raw:
      printerr("RAW BYTE MISMATCH ",c.id," frame=",n," ",key)
      for fx in live: fx.dispose()
      return false
    if got != row.buffers[key]:
     var path = output_dir + "/" + c.id + "-%04d-"%n + key + ".rgba"
     FileAccess.open(path,FileAccess.WRITE).store_buffer(raw)
     printerr("MISMATCH ",c.id," frame=",n," ",key," got=",got," expected=",row.buffers[key]," raw=",path)
     for fx in live: fx.dispose()
     return false
  var is_done = true
  for fx in live: is_done = is_done and fx.done()
  if is_done != row.done:
   printerr("DONE MISMATCH ",c.id," frame=",n)
   for fx in live: fx.dispose()
   return false
 print("PASS ",c.id," ",reference.hashes.size()," frames x 4 buffers byte-identical, done=",reference.doneFrame," elapsed=",(Time.get_ticks_msec()-total_start)/1000.0,"s")
 var report = {"id":c.id,"frames":reference.hashes.size(),"buffers":reference.hashes.size()*4,"doneFrame":reference.doneFrame,"hooks":hooks,"passed":true}
 FileAccess.open(output_dir + "/"+c.id+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"",true,true))
 for fx in live: fx.dispose()
 JS.clear_property_cache()
 return true
