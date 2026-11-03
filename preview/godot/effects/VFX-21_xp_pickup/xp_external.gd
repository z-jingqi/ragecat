extends Node2D
## Cosmetic observer only. All positions are local to this fixed effect node.
## The host owns the collectible, movement, collection rules and disposal.
const MAX_SAMPLES := 48
const TRAIL_LENGTH := 17.0
const TRAIL_SECONDS := 0.12
const ARRIVAL_SECONDS := 0.14
const DARK := Color("238477")
const BODY := Color("48d99b")
const LIGHT := Color("d6ffd0")
var samples: Array[Dictionary] = []
var last_position := Vector2.ZERO
var has_sample := false
var collected := false
var arrival_position := Vector2.ZERO
var arrival_age := 0.0
var paused := false

func sample_position(at: Vector2) -> void:
	if paused or collected or not at.is_finite():
		return
	# Store supplied coordinates exactly. Quantization is drawing-only.
	if has_sample and at == last_position:
		return
	if has_sample and at.distance_to(last_position) > TRAIL_LENGTH:
		samples.clear() # Teleports must not leave a connecting streak.
	last_position = at
	has_sample = true
	samples.append({"position": at, "age": 0.0})
	while samples.size() > MAX_SAMPLES:
		samples.pop_front()
	var distance := 0.0
	for i in range(samples.size() - 1, 0, -1):
		distance += (samples[i].position as Vector2).distance_to(samples[i - 1].position)
		if distance > TRAIL_LENGTH:
			for j in range(i):
				samples.pop_front()
			break
	queue_redraw()

func collect(at: Vector2) -> bool:
	if collected or paused or not at.is_finite():
		return false
	collected = true
	arrival_position = at
	arrival_age = 0.0
	samples.clear()
	queue_redraw()
	return true

func tick(dt: float) -> void:
	if paused or not is_finite(dt) or dt <= 0.0:
		return
	for sample in samples:
		sample.age += dt
	samples = samples.filter(func(sample: Dictionary) -> bool: return sample.age < TRAIL_SECONDS)
	if collected:
		arrival_age = minf(ARRIVAL_SECONDS, arrival_age + dt)
	queue_redraw()

func set_paused(value: bool) -> void:
	paused = value

func clear() -> void:
	samples.clear()
	has_sample = false
	last_position = Vector2.ZERO
	collected = false
	arrival_position = Vector2.ZERO
	arrival_age = 0.0
	paused = false
	queue_redraw()

func is_finished() -> bool:
	# A living observed pickup never expires, even if its tail has faded.
	return (collected and arrival_age >= ARRIVAL_SECONDS) or (not has_sample and not collected)

func is_visually_active() -> bool:
	return samples.size() > 1 or (collected and arrival_age < ARRIVAL_SECONDS)

func _pixel_segment(a: Vector2, b: Vector2, color: Color) -> void:
	var delta := b - a
	var steps := maxi(1, int(maxf(absf(delta.x), absf(delta.y))))
	for i in range(steps + 1):
		draw_rect(Rect2((a + delta * float(i) / steps).round(), Vector2.ONE), color)

func _draw() -> void:
	for i in range(1, samples.size()):
		if i % 2 == 0 or i > samples.size() / 2:
			_pixel_segment(samples[i - 1].position, samples[i].position, BODY if i > samples.size() * 0.65 else DARK)
	if collected and arrival_age < ARRIVAL_SECONDS:
		var u := arrival_age / ARRIVAL_SECONDS
		var radius := 2.0 + u * 6.0
		var length := maxf(1.0, 3.0 * (1.0 - u))
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			_pixel_segment(arrival_position + direction * radius, arrival_position + direction * (radius + length), LIGHT if u < 0.5 else BODY)
