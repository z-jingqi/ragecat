extends Node2D
## Composition only. All children are useful independently and have the same API.
const Surface = preload("lava_surface.gd")
const Bubbles = preload("lava_bubbles.gd")
const Flames = preload("short_flames.gd")
const Sparks = preload("impact_sparks.gd")
const Smoke = preload("rising_smoke.gd")
const Profile = preload("lava_profile.gd")
var layers: Dictionary = {}
var layer_enabled := {"lava":true,"bubbles":true,"flames":true,"sparks":true,"smoke":true}
var profile = Profile.new()
var age := 0.0
var done := true
var _started := false

func play(origin: Vector2 = Vector2.ZERO, configuration: Resource = null) -> void:
	if not origin.is_finite(): stop(); return
	position=origin
	profile=(configuration if configuration is Profile else Profile.new()).sanitized()
	if layers.is_empty():
		for pair in [["lava",Surface],["bubbles",Bubbles],["flames",Flames],["sparks",Sparks],["smoke",Smoke]]:
			var node=pair[1].new()
			add_child(node)
			layers[pair[0]]=node
	for key in layers:
		layers[key].play(Vector2.ZERO,profile)
		layers[key].set_enabled(layer_enabled[key])
	_started=true
	seek(0.)

func seek(seconds: float) -> void:
	if not _started or not is_finite(seconds): return
	age=clampf(seconds,0.,profile.total_time())
	done=age>=profile.total_time()
	for node in layers.values(): node.seek(age)

func advance(delta: float) -> void:
	if not done and is_finite(delta) and delta>0: seek(age+delta)

func set_layer_enabled(key: String, value: bool) -> void:
	if not layer_enabled.has(key): return
	layer_enabled[key] = value
	if layers.has(key): layers[key].set_enabled(value)

func stop() -> void:
	_started=false
	done=true
	for node in layers.values(): node.stop()

func clear() -> void:
	stop()
