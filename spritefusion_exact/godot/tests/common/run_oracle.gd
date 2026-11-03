extends SceneTree
const Frame = preload("res://scripts/core/sf_frame.gd")
const JS = preload("res://scripts/core/sf_js.gd")
var sim_frame = 0
var px = 160.0
var py = 300.0
var hooks = []
var visible = true
var actor_data = PackedInt64Array()
var selected = [0,1,2,3,6,12,24,30,60,90,120,180,240,300,360,480,600,900,1200,1500]

func unpack(v):
	if v is Dictionary:
		if v.has("__f64"): return str(v.__f64).hex_decode().decode_double(0)
		var result = {}
		for k in v: result[k] = unpack(v[k])
		return result
	if v is Array:
		var result = []
		for x in v: result.append(unpack(x))
		return result
	return v

func _initialize():
	call_deferred("run")

func run():
	var args = OS.get_cmdline_user_args()
	if args.size() < 4:
		printerr("Usage: -- fixture-root suite case-id output-dir")
		quit(2)
		return
	var source_root = args[0]
	var suite = args[1]
	var case_id = args[2]
	var output = args[3]
	DirAccess.make_dir_recursive_absolute(output)
	var cases = unpack(JSON.parse_string(FileAccess.get_file_as_string(source_root.path_join(suite).path_join("cases-f64.json"))))
	var c = null
	for candidate in cases:
		if candidate.id == case_id: c = candidate
	if c == null:
		printerr("Missing case ", case_id)
		quit(2)
		return
	var source = load("res://scripts/effects/" + c.slug + ".gd")
	if source == null:
		printerr("Effect failed to load ", c.slug)
		quit(3)
		return
	var bytes = FileAccess.get_file_as_bytes(source_root.path_join(suite).path_join("actor.rgba"))
	actor_data.resize(bytes.size() / 4)
	for i in range(actor_data.size()): actor_data[i] = bytes.decode_u32(i * 4)
	var actor = {"feet": func(): return [px, py], "head": func(): return [px, py - 62.0], "hand": func(): return {"x":px+24.0,"y":py-46.0,"a":0.4 * sin(float(sim_frame)/30.0) if c.get("dynamicActor",false) else 0.0}, "silhouette": func(): return {"x":px/2.0-8.0,"y":py/2.0-32.0,"w":16,"h":32,"data":actor_data}}
	var calls = c.get("calls", [{"at": 0.0}])
	var live = []
	var call_idx = 0
	var f = Frame.new(320, 200, c.get("camera", {}).get("ox", 0), c.get("camera", {}).get("oy", 0))
	var spawn = func(index):
		while index < calls.size() and calls[index].at <= float(sim_frame) / 60.0 + 1e-12:
			var opts = c.options.duplicate(true)
			opts.merge(calls[index].get("options", {}), true)
			opts["shake"] = func(a): emit_hook("shake",[a])
			opts["flash"] = func(a,b = null): emit_hook("flash",[a,b] if b != null else [a])
			opts["darken"] = func(a): emit_hook("darken",[a])
			opts["ripple"] = func(a,b,c0,d,e,f0,g): emit_hook("ripple",[a,b,c0,d,e,f0,g])
			opts["kick"] = func(a,b): emit_hook("kick",[a,b])
			opts["lens"] = func(a): emit_hook("lens",[a])
			opts["cue"] = func(a,b = {}): emit_hook("cue",[a,b])
			if opts.get("actor", null) == true: opts.actor = actor
			live.append(source.new().configure(opts))
			index += 1
		return index
	call_idx = spawn.call(call_idx)
	for n in range(int(c.get("warmup", 0))):
		sim_frame = n + 1
		for fx in live: fx.update(1.0 / 60.0)
		draw_frame(f, live, -1, "")
	sim_frame = 0
	var rows = [draw_frame(f, live, 0, output)]
	var done_frame = null
	for n in range(1, int(c.get("maxFrames", 720)) + 1):
		sim_frame = n
		if c.get("dynamicActor", false):
			px = 160.0 + 2.0 * JS.roundv(12.0 * sin(float(n) / 30.0))
			py = 300.0 - 2.0 * JS.roundv(2.0 * sin(float(n) / 20.0))
		call_idx = spawn.call(call_idx)
		for action in c.get("actions", []):
			if action.frame == n:
				for fx in live: JS.call_method(fx._effect, action.method, action.args)
		if n == c.get("stopFrame", -1):
			for fx in live: fx.stop()
		for fx in live: fx.update(1.0 / 60.0)
		rows.append(draw_frame(f, live, n, output))
		if n % 60 == 0: print(case_id, " frame ", n)
		if call_idx == calls.size() and all_done(live):
			done_frame = n
			break
	var result = {"id": c.id, "slug": c.slug, "frames": rows.size(), "doneFrame": done_frame, "hashes": rows, "hooks": hooks}
	var handle = FileAccess.open(output.path_join("frames.json"), FileAccess.WRITE)
	handle.store_string(JSON.stringify(result, "", true, true))
	handle.close()
	print("RESULT ", c.id, " frames=", rows.size(), " doneFrame=", done_frame)
	for fx in live:
		if fx.has_method("dispose"): fx.dispose()
	live.clear()
	JS._property_names.clear()
	quit()

func emit_hook(hook, arguments):
	hooks.append({"frame":sim_frame,"name":hook,"args":arguments})
	if hook == "cue":
		var cue = arguments[0]
		var data = arguments[1]
		if cue == "move" and data.has("x") and is_finite(data.x): px = data.x
		if cue == "appear":
			if data.has("x") and is_finite(data.x): px = data.x
			if data.has("y") and is_finite(data.y): py = data.y
			visible = true
		if cue == "vanish": visible = false

func all_done(live):
	for fx in live:
		if not fx.done(): return false
	return true

func draw_frame(f, live, number, output):
	var row = {"frame": number, "actor": {"x": px, "y": py, "visible": visible}, "buffers": {}, "nonzero": {}, "done": all_done(live)}
	for layer in ["back", "front"]:
		f.clear()
		for fx in live: fx.draw(f, layer)
		if number < 0: continue
		for channel in ["color", "light"]:
			var data = f.get(channel).data
			var bytes = PackedInt32Array(Array(data)).to_byte_array()
			var hash = HashingContext.new()
			hash.start(HashingContext.HASH_SHA256)
			hash.update(bytes)
			var key = layer + "-" + channel
			row.buffers[key] = hash.finish().hex_encode()
			var nonzero = 0
			for value in data:
				if value != 0: nonzero += 1
			row.nonzero[key] = nonzero
			if number in selected and not output.is_empty():
				var handle = FileAccess.open(output.path_join("%04d-%s.rgba" % [number, key]), FileAccess.WRITE)
				handle.store_buffer(bytes)
				handle.close()
	return row
