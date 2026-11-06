extends SceneTree
const Ice = preload("../modules/ice.gd")
const FX = preload("../components/radial_spikes.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(label)
func _initialize() -> void:
 for t in [0.0, 0.1, 0.3, 0.5, 0.75, 0.76]:
  check(Ice.ground_settle(t) == 0.0, "airborne crystal keeps full geometry at " + str(t))
 check(Ice.ground_settle(.88) > 0.0 and Ice.ground_settle(.88) < 1.0, "ground contact tips shards into ground plane")
 check(Ice.ground_settle(1.0) == 1.0, "resting geometry stays fixed")
 var p: Resource = load("res://presets/ice.tres").clean()
 check(p.rise_time == .07, "rapid emergence preserved")
 check(p.layer_stride() < p.layer_span(), "adjacent layers overlap")
 check(p.residue_lifetime == 3.2, "residue persists for seconds")
 for shape in 3:
  p.shape = shape
  var fx: Node2D = FX.new()
  root.add_child(fx)
  fx.configure(p)
  fx.play(Vector2.ZERO, 17)
  check(not fx.spikes.is_empty(), "ice geometry exists for shape " + str(shape))
  var sample: Array = fx.spikes.duplicate(true)
  fx.seek(.2)
  fx.seek(.1)
  check(fx.spikes == sample, "reverse seek preserves seeded layout")
  fx.clear()
  check(fx.canvases.is_empty(), "clear releases all crystal canvases")
  fx.free()
 print("PASS" if failures == 0 else "FAIL", " ice rigidity: ", checks, " assertions, ", failures, " failures")
 quit(0 if failures == 0 else 1)
