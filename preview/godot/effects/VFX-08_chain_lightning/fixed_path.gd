extends Node2D
## Visual-only chain over caller-owned snapshot points, in this node's local space.
## No targets, hit signals, automatic clock, combat selection or gameplay timing.
const Bolt := preload("../VFX-08_lightning/lightning.gd")
const MAX_POINTS := 129
const MAX_SEGMENT_LENGTH := 2048.0
const DEFAULTS := {
	"duration": 0.18, "jump_interval": 0.09, "width": 1.25,
	"branches": 1, "jitter": 7.0, "seed": 31,
	"core": "f7f3dc", "body": "a4e5ef", "edge": "477aaf",
	"attack": 0.065, "hold": 0.025, "decay": 0.18
}
var age := 0.0
var duration := 0.0
var done := true
var paused := false
var config: Dictionary = {}
var links: Array[Dictionary] = []
var _path := PackedVector2Array()
var _native_duration := 0.0
var _has_replay := false

static func _number(value: Variant, fallback: float, low: float, high: float) -> float:
	if not (value is int or value is float): return fallback
	return clampf(float(value), low, high) if is_finite(float(value)) else fallback

static func sanitized(options: Dictionary) -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	var limits := {
		"duration": Vector2(0.05, 5.0), "jump_interval": Vector2(0.04, 0.4),
		"width": Vector2(1, 3), "branches": Vector2(0, 3),
		"jitter": Vector2(0, 20), "seed": Vector2(0, 65535),
		"attack": Vector2(0.025, 0.08), "hold": Vector2(0.008, 0.12),
		"decay": Vector2(0.03, 0.25)
	}
	for key in limits:
		out[key] = _number(options.get(key, out[key]), out[key], limits[key].x, limits[key].y)
	for key in ["branches", "seed"]: out[key] = int(out[key])
	for key in ["core", "body", "edge"]:
		var value: Variant = options.get(key, out[key])
		var color: Color = Color.from_string(value, Color(out[key])) if value is String else (value if value is Color else Color(out[key]))
		if not (is_finite(color.r) and is_finite(color.g) and is_finite(color.b)): color = Color(DEFAULTS[key])
		out[key] = Color(clampf(color.r, 0, 1), clampf(color.g, 0, 1), clampf(color.b, 0, 1), 1.0)
	return out

func play_path(snapshot: PackedVector2Array, options: Dictionary = {}) -> void:
	reset()
	# Reject unsupported input as a whole. Never reroute, reorder or shorten a path.
	if snapshot.size() < 2 or snapshot.size() > MAX_POINTS: return
	for i in range(snapshot.size()):
		if not snapshot[i].is_finite(): return
		if i > 0 and snapshot[i - 1].distance_to(snapshot[i]) > MAX_SEGMENT_LENGTH: return
	_path = snapshot.duplicate()
	config = sanitized(options)
	duration = config.duration
	var interval: float = maxf(config.jump_interval, config.attack)
	var bolt_duration: float = config.attack + config.hold + config.decay
	_native_duration = interval * (_path.size() - 2) + bolt_duration
	var drawable := false
	for i in range(_path.size() - 1):
		var options_for_bolt := config.duplicate(true)
		options_for_bolt.merge({
			"impact_size": 0, "afterglow": 0, "spark_count": 0, "smoke": false,
			"branch_length": 17, "segment_length": 6, "seed": (config.seed + i * 97) % 65536
		}, true)
		var bolt := Bolt.new()
		bolt.automatic = false
		# The shared renderer has an optional _process; disable even its inert callback.
		bolt.set_process(false)
		add_child(bolt)
		bolt.play(_path[i], _path[i + 1], options_for_bolt)
		bolt.set_process(false)
		var has_length := bolt.active
		drawable = drawable or has_length
		links.append({"bolt": bolt, "start": _path[i], "end": _path[i + 1],
			"delay": interval * i, "options": options_for_bolt, "drawable": has_length, "index": i})
	_has_replay = drawable
	seek(0.0)

func snapshot_points() -> PackedVector2Array:
	return _path.duplicate()

func advance(delta: float) -> void:
	if done or paused or not is_finite(delta) or delta <= 0.0: return
	seek(minf(duration, age + delta))

func seek(seconds: float) -> void:
	if not _has_replay or not is_finite(seconds): return
	age = clampf(seconds, 0.0, duration)
	done = age >= duration
	visible = not done
	var native_age := age * _native_duration / duration
	for link in links:
		var bolt: Node2D = link.bolt
		var local_age: float = maxf(0.0, native_age - link.delay)
		# A backward seek/replay rebuilds the same seeded geometry, not a fresh pattern.
		if link.drawable and (local_age < bolt.age or (not bolt.active and local_age < bolt.duration)):
			bolt.play(link.start, link.end, link.options)
		if link.drawable: bolt.tick(maxf(0.0, local_age - bolt.age))
		bolt.visible = not done and link.drawable and native_age >= link.delay and bolt.active
	queue_redraw()

func replay() -> void:
	if not _has_replay: return
	paused = false
	seek(0.0)

func stop() -> void:
	done = true
	visible = false
	paused = false

func reset() -> void:
	stop()
	age = 0.0
	duration = 0.0
	_has_replay = false
	_native_duration = 0.0
	_path.clear()
	config.clear()
	for link in links:
		if is_instance_valid(link.bolt): link.bolt.free()
	links.clear()
	queue_redraw()

func _draw() -> void:
	if done: return
	var native_age := age * _native_duration / duration
	# Same short four-spoke contact accent as the canonical chain, visual only.
	for link in links:
		if not link.drawable or not link.bolt.visible: continue
		var t: float = native_age - link.delay - config.attack
		if t < 0.0 or t >= 0.1: continue
		var p: Vector2 = link.end.round()
		var rng := RandomNumberGenerator.new()
		rng.seed = config.seed + link.index * 53
		for i in range(4):
			var axis := Vector2.from_angle(i * TAU / 4 + rng.randf_range(-0.3, 0.3))
			var radius := 4 + t * 34
			var a := (p + axis * radius).round() + Vector2(0.5, 0.5)
			var b := (p + axis * (radius + 3 * (1 - t / 0.1))).round() + Vector2(0.5, 0.5)
			draw_line(a, b, config.core if t < 0.04 else config.body, 1, false)
