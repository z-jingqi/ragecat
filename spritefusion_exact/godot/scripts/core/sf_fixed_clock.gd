# Each Sprite Fusion update consumes exactly one 60 Hz tick, including random calls.
extends RefCounted
const DT: float = 1.0 / 60.0
# Only absorbs binary64 accumulation error at an exact tick boundary.
const BOUNDARY_EPSILON: float = DT * 1.0e-12
var ticks: int = 0
var accumulator: float = 0.0

func advance(elapsed: float, update: Callable) -> int:
	assert(elapsed >= 0.0 and is_finite(elapsed))
	accumulator += elapsed
	var count: int = int(floor((accumulator + BOUNDARY_EPSILON) / DT))
	# Subtract once: repeated subtraction loses a whole tick on long chunks.
	accumulator -= float(count) * DT
	if absf(accumulator) < BOUNDARY_EPSILON:
		accumulator = 0.0
	for _i in range(count):
		update.call(DT)
		ticks += 1
	return count

func step(update: Callable, count: int = 1) -> void:
	for _i in range(count):
		update.call(DT)
		ticks += 1

func reset() -> void:
	ticks = 0
	accumulator = 0.0
