extends SceneTree
const Frame = preload("res://scripts/core/sf_frame.gd")
const JS = preload("res://scripts/core/sf_js.gd")
var failures = 0
var checks = 0
var results = []
var skipped = []

func _initialize(): call_deferred("run")

func check(ok, label):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", label)
	return ok

func digest(words):
	var bytes = PackedByteArray()
	bytes.resize(words.size() * 4)
	for i in range(words.size()): bytes.encode_u32(i * 4, words[i])
	var h = HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(bytes)
	return h.finish().hex_encode()

func first_frames(effect):
	var f = Frame.new(32, 20)
	var rows = []
	for tick in range(3):
		if tick: effect.update(1.0 / 60.0)
		f.clear()
		effect.draw(f, "back")
		effect.draw(f, "front")
		rows.append([digest(f.color.data), digest(f.light.data), effect.done()])
	return rows

func run_case(slug):
	var path = "res://scripts/effects/" + slug + ".gd"
	if not FileAccess.file_exists(path):
		skipped.append(slug)
		print("SKIP unavailable effect ", slug)
		return
	var script = load(path)
	if not check(script != null, slug + " load"): return
	var options = {"seed": 7.0, "x": 32.0, "y": 20.0, "ground": 36.0,
		"area": {"x": 0.0, "y": 0.0, "w": 64.0, "h": 40.0}, "vents": [16.0, 32.0, 48.0]}
	var effect = script.new().configure(options.duplicate(true))
	var initial = first_frames(effect)
	var generated = slug != "fog"
	var previous = effect._effect if generated else {}
	var scopes = []
	if generated: JS._collect_scopes(previous, [], scopes)
	effect.stop()
	effect.stop()
	effect.configure(options.duplicate(true))
	var released = true
	if generated:
		released = previous.is_empty() and scopes.all(func(scope): return scope.is_empty())
		check(released, slug + " configure releases old effect and captured scopes")
	check(first_frames(effect) == initial, slug + " reconfigure reproduces 3 initial color/light frames and done state")
	# Clean old scopes in failing-before runs too, so the harness itself does not leak.
	if generated and not released:
		JS.release_scopes(previous)
		previous.clear()
	scopes.clear()
	effect.dispose()
	effect.dispose()
	effect.stop()
	var disposed_done = effect.done()
	check(effect._effect.is_empty() if generated else true, slug + " repeated dispose is safe")
	effect.configure(options.duplicate(true))
	check(first_frames(effect) == initial, slug + " configure after repeated dispose is fresh")
	results.append({"slug":slug,"old_scopes_released":released,"first_frames":initial,"disposed_done":disposed_done})
	effect.dispose()
	effect.dispose()
	effect = null

func run():
	for slug in ["pickup", "sparkle", "rain", "snow", "fog", "embers", "fireflies", "falling-leaves", "bubbles"]:
		run_case(slug)
	JS.clear_property_cache()
	var args = OS.get_cmdline_user_args()
	if not args.is_empty():
		var file = FileAccess.open(args[0], FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"results":results,"skipped":skipped},"  "))
	print("WRAPPER_REUSE checks=", checks, " failures=", failures, " skipped=", skipped.size())
	quit(1 if failures else 0)
