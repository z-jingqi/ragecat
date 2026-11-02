class_name WeaponTrailHistory
extends RefCounted
## Godot-only input adapter. Owns the sampled world-space history; no engine portability is implied.
const CAPACITY := 64
var lifetime := 0.16
var min_sample_distance := 0.045
var max_samples := 32
var teleport_distance := 3.0
var emitting := true
var clock := 0.0
var count := 0
var head := 0
var teleport_resets := 0
var has_last_pose := false
var last_root := Vector2.ZERO
var last_tip := Vector2.ZERO
var roots := PackedVector2Array()
var tips := PackedVector2Array()
var births := PackedFloat64Array()

func _init() -> void:
	roots.resize(CAPACITY)
	tips.resize(CAPACITY)
	births.resize(CAPACITY)

func sanitize() -> void:
	lifetime = clampf(lifetime if is_finite(lifetime) else 0.16, 0.02, 0.6)
	min_sample_distance = clampf(min_sample_distance if is_finite(min_sample_distance) else 0.045, 0.005, 0.5)
	max_samples = clampi(max_samples, 2, CAPACITY)
	teleport_distance = clampf(teleport_distance if is_finite(teleport_distance) else 3.0, 0.25, 30.0)

func clear() -> void:
	count = 0
	head = 0
	has_last_pose = false

func begin_trail() -> void:
	clear()
	emitting = true

func stop_emission() -> void:
	emitting = false

func index(i: int) -> int:
	return (head + i) % CAPACITY

func drop_oldest() -> void:
	head = (head + 1) % CAPACITY
	count -= 1

func advance(dt: float) -> void:
	if not is_finite(dt) or dt < 0.0:
		return
	sanitize()
	clock += dt
	while count > 0 and (clock - births[head] >= lifetime or count > max_samples):
		drop_oldest()

func submit_pose(root: Vector2, tip: Vector2) -> void:
	if not emitting:
		return
	if not root.is_finite() or not tip.is_finite():
		clear()
		return
	sanitize()
	if has_last_pose:
		var distance := maxf(last_root.distance_to(root), last_tip.distance_to(tip))
		var old_blade := last_tip - last_root
		var new_blade := tip - root
		var flipped := old_blade.length_squared() > 0.00000001 and new_blade.length_squared() > 0.00000001 and old_blade.normalized().dot(new_blade.normalized()) < -0.5
		if distance > teleport_distance or flipped:
			clear()
			teleport_resets += 1
		elif distance < min_sample_distance:
			return # No time refresh on a stationary weapon.
	while count >= max_samples:
		drop_oldest()
	var slot := index(count)
	roots[slot] = root
	tips[slot] = tip
	births[slot] = clock
	count += 1
	has_last_pose = true
	last_root = root
	last_tip = tip

func remaining(i: int) -> float:
	return clampf(1.0 - (clock - births[index(i)]) / lifetime, 0.0, 1.0)
