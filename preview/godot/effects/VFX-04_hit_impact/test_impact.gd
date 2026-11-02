extends SceneTree
const Impact = preload("res://effects/VFX-04_hit_impact/impact.gd")
var checks := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		push_error("FAIL: " + message)
		quit(1)
		assert(value, message)

func run_tests() -> void:
	var presets: Array = JSON.parse_string(FileAccess.get_file_as_string("res://effects/VFX-04_hit_impact/presets.json")).presets
	var fx = Impact.new()
	fx.auto_tick = false
	root.add_child(fx)
	check(not fx.active and fx.age == -1.0, "starts clear")
	for preset in presets:
		for fps in [30,60,120]:
			fx.play(Vector2(10.25,11.75), Vector2.RIGHT, preset)
			var ticks := 0
			while fx.active and ticks < 100:
				fx.tick(1.0/float(fps))
				ticks += 1
			check(not fx.active, "finite completion")
			check(is_equal_approx(fx.age,float(preset.duration)), "age ends exactly at duration")
			check(absf(ticks/float(fps)-float(preset.duration)) <= 1.0/float(fps)+0.000001, "completion <= one render interval")
			check(fx.position == Vector2(10,12), "display-only position quantization")
			check(not fx.get_child(0).visible, "complete has no residue")
	fx.play(Vector2.ZERO,Vector2(0,1),presets[0])
	check(is_equal_approx(fx.direction,PI/2), "+Y-up incoming convention")
	fx.tick(0.03)
	fx.paused = true
	var age: float = fx.age
	fx.tick(0.5)
	check(fx.age == age and fx.active, "pause freezes")
	fx.paused = false
	fx.tick(0.02)
	check(is_equal_approx(fx.age,0.05), "resume continues")
	fx.replay()
	check(fx.age == 0.0 and fx.active and not fx.paused, "replay resets time and pause")
	fx.clear()
	check(not fx.active and fx.age == -1 and not fx.get_child(0).visible, "clear immediately hides")
	fx.replay()
	check(fx.active and fx.age == 0, "replay after clear uses last input")
	fx.playback_rate = 0.25
	fx.tick(0.2)
	check(is_equal_approx(fx.age,0.05), "quarter speed seconds")
	fx.playback_rate = 0
	fx.tick(1.0)
	check(is_equal_approx(fx.age,0.05), "zero speed does not advance")
	fx.playback_rate = 1.0
	fx.tick(-2.0)
	fx.tick(NAN)
	fx.tick(INF)
	check(is_equal_approx(fx.age,0.05), "invalid delta ignored")
	fx.play(Vector2.ZERO,Vector2.ZERO,presets[0])
	check(fx.direction == 0.0, "zero direction falls back to +X")
	fx.play(Vector2(NAN,0),Vector2.RIGHT,presets[0])
	check(not fx.active, "invalid contact safely clears")
	var extreme: Dictionary = presets[0].duplicate(true)
	extreme.merge({"size":99,"coreSize":99,"shardCount":999,"shardLength":99,"spreadDegrees":999,"speed":999,"duration":999,"seed":-1,"coreHex":"bad hex"},true)
	var safe: Dictionary = Impact.sanitized(extreme)
	check(safe.size == 2 and safe.coreSize == 12 and safe.shardCount == 8, "size/count caps")
	check(safe.duration == 0.5 and safe.speed == 180 and safe.seed == 4095, "duration/speed/seed caps")
	check(safe.coreHex == "#fff5cf", "invalid color fallback")
	check(Impact.extent_pixels(safe) <= 284, "bounded maximum canvas")
	extreme.merge({"size":NAN,"coreSize":-99,"shardCount":-1,"duration":INF,"speed":-5,"shardLength":-5},true)
	safe = Impact.sanitized(extreme)
	check(safe.size == 1 and safe.duration == 0.2 and safe.coreSize == 2 and safe.shardCount == 0, "NaN and negative bounds")
	fx.play(Vector2.ZERO,Vector2.RIGHT,presets[0])
	var input: Dictionary = presets[0].duplicate(true)
	fx.play(Vector2.ZERO,Vector2.RIGHT,input)
	input.size = 1.9
	check(fx.settings.size == 1.0, "play snapshots mutable input")
	for i in range(1000):
		fx.replay()
		fx.tick(0.02)
		fx.clear()
	check(fx.get_child_count() == 1, "1000 reuse cycles keep one quad/material")
	fx.replay()
	fx.seek(0.1)
	check(fx.age == 0.1 and fx.active, "fixed-time diagnostic seek")
	fx.seek(999)
	check(not fx.active and not fx.get_child(0).visible, "seek past end stays clear")
	fx.free()
	print("PASS: VFX-04 Godot lifecycle/config ",checks," checks; 4 presets × 30/60/120 Hz; 1000 reuse cycles")
	quit(0)
